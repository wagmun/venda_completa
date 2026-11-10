import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'sales_history_controller.dart';

/// Lista as vendas gravadas no dispositivo, destaca o que está pendente de
/// sincronização e permite sincronizar manualmente e reimprimir o DANFE.
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesHistoryController>().refresh();
    });
  }

  String _data(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SalesHistoryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas vendas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: () => c.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (c.pendingCount > 0)
            Material(
              color: Colors.orange.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${c.pendingCount} venda(s) aguardando sincronização',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      icon: c.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('Sincronizar'),
                      onPressed: c.isSyncing
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final n = await c.syncNow();
                              messenger.showSnackBar(SnackBar(
                                content: Text(n > 0
                                    ? '$n venda(s) sincronizada(s).'
                                    : 'Nada sincronizado (sem conexão?).'),
                              ));
                            },
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: c.isLoading
                ? const Center(child: CircularProgressIndicator())
                : c.sales.isEmpty
                    ? const Center(child: Text('Nenhuma venda registrada.'))
                    : ListView.separated(
                        itemCount: c.sales.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = c.sales[i];
                          return ListTile(
                            leading: Icon(
                              s.sincronizada
                                  ? Icons.cloud_done
                                  : Icons.cloud_queue,
                              color:
                                  s.sincronizada ? Colors.green : Colors.orange,
                            ),
                            title: Text(
                              'R\$ ${s.total.toStringAsFixed(2)}  ·  ${s.totalItens} item(s)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${_data(s.createdAt)}  ·  ${s.paymentMethod}\n'
                              '${s.fiscal != null ? 'NFC-e ${s.fiscal!['serie']}/${s.fiscal!['numero']}  ·  ' : ''}'
                              '${s.sincronizada ? 'Sincronizada' : 'Pendente'}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _detalhe(context, c, s),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _detalhe(
    BuildContext context,
    SalesHistoryController c,
    SaleRecord s,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text('Venda ${_data(s.createdAt)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Chip(
                  avatar: Icon(
                    s.sincronizada ? Icons.cloud_done : Icons.cloud_queue,
                    size: 18,
                    color: s.sincronizada ? Colors.green : Colors.orange,
                  ),
                  label: Text(s.sincronizada
                      ? 'Sincronizada com o servidor'
                      : 'Pendente de sincronização'),
                ),
                if (!s.sincronizada && s.lastError != null) ...[
                  const SizedBox(height: 4),
                  Text('Último erro: ${s.lastError}',
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const Divider(height: 24),
                ...s.items.map((it) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text((it['descricao'] ?? '').toString()),
                      subtitle: Text(
                          '${it['quantidade']} x R\$ ${((it['preco_unitario'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
                      trailing: Text(
                          'R\$ ${((it['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
                    )),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('R\$ ${s.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                if (s.fiscal != null) ...[
                  const SizedBox(height: 8),
                  Text('Chave de acesso:\n${s.fiscal!['chave_acesso']}',
                      style: const TextStyle(fontSize: 12)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Reimprimir DANFE (PDF)'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final pdf = await c.buildDanfePdf(s);
                    if (pdf == null) {
                      messenger.showSnackBar(const SnackBar(
                          content:
                              Text('Venda sem dados fiscais para imprimir.')));
                      return;
                    }
                    await Printing.layoutPdf(
                        onLayout: (_) async => pdf, name: 'DANFE');
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }
}
