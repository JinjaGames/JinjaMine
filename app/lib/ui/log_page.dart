import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/miner.dart';
import 'theme.dart';
import 'widgets.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});
  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  bool _onlyApp = false;
  final _q = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context).miner;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        final q = _q.text.toLowerCase();
        final rows = m.logs.reversed.where((e) => (!_onlyApp || e.kind != LogKind.miner) && (q.isEmpty || e.text.toLowerCase().contains(q))).take(1500).toList();
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Section(
            title: 'Günlük',
            icon: Icons.receipt_long,
            subtitle: 'Uygulamanın ve XMRig’in çıktısı. Cüzdan adresi XMRig satırlarında görünebilir; bu herkese açık bir bilgidir.',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 200, child: TextField(controller: _q, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Ara…', prefixIcon: Icon(Icons.search, size: 18)))),
              const SizedBox(width: 8),
              FilterChip(label: const Text('Yalnız uygulama'), selected: _onlyApp, onSelected: (v) => setState(() => _onlyApp = v)),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: m.logs.map((e) => '${clock(e.at)} ${e.text}').join('\n')));
                  snack(context, 'Günlük kopyalandı.');
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Kopyala'),
              ),
            ]),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 210,
              child: rows.isEmpty
                  ? const Text('Henüz kayıt yok.', style: TextStyle(color: Pal.muted))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final e = rows[i];
                        final c = switch (e.kind) {
                          LogKind.ok => Pal.ok,
                          LogKind.warn => Pal.amber,
                          LogKind.error => Pal.bad,
                          LogKind.miner => Pal.muted,
                          LogKind.info => Pal.text,
                        };
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: SelectableText.rich(TextSpan(children: [
                            TextSpan(text: '${clock(e.at)}  ', style: const TextStyle(color: Pal.muted, fontFamily: 'Consolas', fontSize: 12)),
                            TextSpan(text: e.text, style: TextStyle(color: c, fontSize: 12.5, fontFamily: e.kind == LogKind.miner || e.kind == LogKind.ok ? 'Consolas' : null)),
                          ])),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}
