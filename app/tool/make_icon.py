"""Draws the JinjaMine icon in the Jinja family style (dark rounded square, bold white J) with an orange
pickaxe blade crowning the J and a small orange crystal. Writes:
  assets/icon.png (1024, full icon), assets/logo_mark.png (512, mark without background),
  windows/runner/resources/app_icon.ico (16-256).
Run from the app folder:  python tool/make_icon.py
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 4096
BG = (15, 17, 23, 255)
WHITE = (244, 245, 249, 255)
ORANGE = (255, 122, 26, 255)
ORANGE_DARK = (204, 82, 8, 255)
GEM_LIGHT = (255, 190, 110, 255)


def u(v):
    return round(v * S / 512)


def layer():
    return Image.new('L', (S, S), 0)


def draw_mark(with_bg: bool) -> Image.Image:
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    box = layer()
    ImageDraw.Draw(box).rounded_rectangle([0, 0, S - 1, S - 1], radius=u(112), fill=255)
    if with_bg:
        im.paste(BG, (0, 0), box)
        glow = layer()
        ImageDraw.Draw(glow).ellipse([u(150), u(50), u(456), u(250)], fill=90)
        glow = ImageChops.multiply(glow.filter(ImageFilter.GaussianBlur(u(55))), box)
        im.paste((255, 122, 26, 255), (0, 0), glow)

    # --- J ---
    j = layer()
    jd = ImageDraw.Draw(j)
    w = 70
    sx0, sx1 = 268, 338
    jd.rectangle([u(sx0), u(118), u(sx1), u(318)], fill=255)  # stem
    cx, cy, ro, ri = 218, 318, 120, 50
    bowl = layer()
    bd = ImageDraw.Draw(bowl)
    bd.ellipse([u(cx - ro), u(cy - ro), u(cx + ro), u(cy + ro)], fill=255)
    bd.ellipse([u(cx - ri), u(cy - ri), u(cx + ri), u(cy + ri)], fill=0)
    bd.rectangle([0, 0, S, u(cy)], fill=0)
    j = ImageChops.lighter(j, bowl)
    jd = ImageDraw.Draw(j)
    lc = cx - ro + w / 2  # left end centre
    jd.rectangle([u(lc - w / 2), u(cy - 12), u(lc + w / 2), u(cy) + 2], fill=255)
    jd.ellipse([u(lc - w / 2), u(cy - 12 - w / 2), u(lc + w / 2), u(cy - 12 + w / 2)], fill=255)
    im.paste(WHITE, (0, 0), j)

    # --- pickaxe blade: crescent = ellipse A minus ellipse B (B shifted down) -> pointed tips ---
    rx, ry, ay, off = 184, 112, 204, 40
    sxc = (sx0 + sx1) / 2
    blade = layer()
    ImageDraw.Draw(blade).ellipse([u(sxc - rx), u(ay - ry), u(sxc + rx), u(ay + ry)], fill=255)
    cut = layer()
    ImageDraw.Draw(cut).ellipse([u(sxc - rx), u(ay + off - ry), u(sxc + rx), u(ay + off + ry)], fill=255)
    blade = ImageChops.subtract(blade, cut)
    # dark band (socket) where the blade grips the handle
    sock = layer()
    ImageDraw.Draw(sock).rectangle([u(sx0 - 8), 0, u(sx1 + 8), S], fill=255)
    sock = ImageChops.multiply(sock, blade)
    im.paste(ORANGE, (0, 0), blade)
    im.paste(ORANGE_DARK, (0, 0), sock)

    # --- crystal (brilliant cut) bottom-right ---
    d = ImageDraw.Draw(im)
    gx, gy = 410, 392
    tw, bw, th, bh = 36, 52, 18, 44  # table half-width, girdle half-width, crown height, pavilion height
    crown = [(u(gx - tw), u(gy - th)), (u(gx + tw), u(gy - th)), (u(gx + bw), u(gy)), (u(gx - bw), u(gy))]
    pav = [(u(gx - bw), u(gy)), (u(gx + bw), u(gy)), (u(gx), u(gy + bh))]
    d.polygon(crown, fill=GEM_LIGHT)
    d.polygon(pav, fill=ORANGE)
    d.polygon([(u(gx - bw / 3), u(gy)), (u(gx + bw / 3), u(gy)), (u(gx), u(gy + bh))], fill=ORANGE_DARK)
    if not with_bg:
        return im
    return Image.composite(im, Image.new('RGBA', (S, S), (0, 0, 0, 0)), box)


def main():
    root = Path(__file__).resolve().parent.parent
    icon = draw_mark(True).resize((1024, 1024), Image.LANCZOS)
    icon.save(root / 'assets' / 'icon.png')
    draw_mark(False).resize((512, 512), Image.LANCZOS).save(root / 'assets' / 'logo_mark.png')
    icon.save(root / 'windows' / 'runner' / 'resources' / 'app_icon.ico',
              sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print('ok')


if __name__ == '__main__':
    main()
