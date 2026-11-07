"""Builds JinjaMine_Rehber.docx + .pdf from README.md, SISTEM.md and docs/0*.md (simple Markdown subset)."""
import os
import re

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'JinjaMine_Rehber')
FILES = ['README.md', 'SISTEM.md'] + sorted(f'docs/{f}' for f in os.listdir(os.path.join(ROOT, 'docs')) if re.match(r'0\d_.*\.md$', f))
ORANGE = RGBColor(0xE0, 0x62, 0x0A)

d = Document()
for s in d.sections:
    s.left_margin = s.right_margin = Cm(2)
    s.top_margin = s.bottom_margin = Cm(1.8)
st = d.styles['Normal']
st.font.name = 'Calibri'
st.font.size = Pt(10.5)
for lvl, size in ((1, 17), (2, 13.5), (3, 11.5)):
    h = d.styles[f'Heading {lvl}']
    h.font.color.rgb = ORANGE if lvl < 3 else RGBColor(0x33, 0x33, 0x33)
    h.font.size = Pt(size)
    h.font.name = 'Calibri'


def runs(p, text):
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', lambda m: m.group(1) if m.group(2).endswith('.md') else f'{m.group(1)} ({m.group(2)})', text)
    for part in re.split(r'(\*\*[^*]+\*\*|`[^`]+`|\*[^*\s][^*]*\*)', text):
        if not part:
            continue
        if part.startswith('**'):
            p.add_run(part[2:-2]).bold = True
        elif part.startswith('*') and part.endswith('*') and len(part) > 2:
            p.add_run(part[1:-1]).italic = True
        elif part.startswith('`'):
            r = p.add_run(part[1:-1])
            r.font.name = 'Consolas'
            r.font.size = Pt(9.5)
        else:
            p.add_run(part)


def shade(cell, color):
    tc = cell._tc.get_or_add_tcPr()
    sh = OxmlElement('w:shd')
    sh.set(qn('w:val'), 'clear')
    sh.set(qn('w:color'), 'auto')
    sh.set(qn('w:fill'), color)
    tc.append(sh)


def table(rows):
    rows = [r for r in rows if not re.match(r'^\|[\s:|-]+\|$', r)]
    cells = [[c.strip() for c in r.strip().strip('|').split('|')] for r in rows]
    n = max(len(c) for c in cells)
    t = d.add_table(rows=len(cells), cols=n)
    t.style = 'Table Grid'
    for i, r in enumerate(cells):
        for j in range(n):
            c = t.cell(i, j)
            c.text = ''
            p = c.paragraphs[0]
            runs(p, r[j] if j < len(r) else '')
            for rr in p.runs:
                rr.font.size = Pt(9.5)
                if i == 0:
                    rr.bold = True
            if i == 0:
                shade(c, 'FDE7D6')
    d.add_paragraph()


BLOCK = re.compile(r'^\s*(#{1,3} |\||```|[-*] |\d+[.)] )')


def join_soft_wraps(lines):
    """Markdown wraps long paragraphs/list items over several lines; join them back into one."""
    out, in_code = [], False
    for ln in lines:
        if ln.startswith('```'):
            in_code = not in_code
            out.append(ln)
            continue
        prev = out[-1] if out else ''
        can_join = (not in_code and out and prev.strip() and not prev.startswith(('#', '|', '```')) and ln.strip()
                    and not BLOCK.match(ln))
        if can_join and ln.startswith('> ') and prev.startswith('> '):
            out[-1] = prev.rstrip() + ' ' + ln[2:].strip()
        elif can_join and not ln.startswith('> '):
            out[-1] = prev.rstrip() + ' ' + ln.strip()
        else:
            out.append(ln)
    return out


title = d.add_paragraph()
title.alignment = WD_ALIGN_PARAGRAPH.LEFT
r = title.add_run('JinjaMine — Monero madencilik rehberi')
r.bold = True
r.font.size = Pt(24)
r.font.color.rgb = ORANGE
d.add_paragraph('Kurulum, cüzdan, havuzlar, gerçekçi kazanç, güvenlik ve sorun giderme. Kaynak: Desktop\\JinjaMine klasöründeki belgeler.')

for i, f in enumerate(FILES):
    if i:
        d.add_page_break()
    lines = join_soft_wraps(open(os.path.join(ROOT, f), encoding='utf8').read().splitlines())
    k = 0
    while k < len(lines):
        ln = lines[k]
        if ln.startswith('```'):
            k += 1
            code = []
            while k < len(lines) and not lines[k].startswith('```'):
                code.append(lines[k])
                k += 1
            p = d.add_paragraph()
            rr = p.add_run('\n'.join(code))
            rr.font.name = 'Consolas'
            rr.font.size = Pt(9)
            p.paragraph_format.left_indent = Cm(0.6)
        elif ln.startswith('|'):
            rows = []
            while k < len(lines) and lines[k].startswith('|'):
                rows.append(lines[k])
                k += 1
            table(rows)
            continue
        elif m := re.match(r'^(#{1,3}) (.*)', ln):
            d.add_heading(m.group(2), len(m.group(1)))
        elif ln.startswith('> '):
            p = d.add_paragraph()
            p.paragraph_format.left_indent = Cm(0.6)
            runs(p, ln[2:])
            for rr in p.runs:
                rr.italic = True
        elif m := re.match(r'^(\s*)[-*] (.*)', ln):
            p = d.add_paragraph(style='List Bullet' if not m.group(1) else 'List Bullet 2')
            runs(p, m.group(2))
        elif m := re.match(r'^(\s*)\d+[.)] (.*)', ln):
            p = d.add_paragraph(style='List Bullet' if not m.group(1) else 'List Bullet 2')
            num = re.match(r'^\s*(\d+)', ln).group(1)
            runs(p, f'{num}) {m.group(2)}')
        elif ln.strip():
            runs(d.add_paragraph(), ln.strip())
        k += 1

d.save(OUT + '.docx')
print('docx saved')
try:
    import win32com.client

    w = win32com.client.DispatchEx('Word.Application')
    w.Visible = False
    doc = w.Documents.Open(OUT + '.docx')
    doc.ExportAsFixedFormat(OUT + '.pdf', 17)
    print('pages', doc.ComputeStatistics(2))
    doc.Close(False)
    w.Quit()
except Exception as e:  # Word missing
    print('pdf skipped:', e)
