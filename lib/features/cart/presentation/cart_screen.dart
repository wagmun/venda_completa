import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../sales/data/printer_discovery_service.dart';
import '../../sales/data/printer_service.dart';
import 'cart_controller.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  /// Mostra a NFC-e já emitida (após confirmar), para visualizar / mostrar ao
  /// cliente. Sai para o catálogo só no "Concluir".
  /// Imprimir DANFE: procura impressoras na rede automaticamente e deixa o
  /// vendedor só TOCAR na impressora encontrada (sem digitar IP).
  void _showPrinterOptions(BuildContext context, CartController controller) {
    showDialog(
      context: context,
      builder: (dc) {
        // Estado persistente entre rebuilds (declarado fora do StatefulBuilder).
        final disco = PrinterDiscoveryService();
        List<DiscoveredPrinter>? encontradas;
        var procurando = false;
        var manual = false;
        final ipCtrl = TextEditingController(text: '192.168.0.100');

        Future<void> imprimir(PrinterConnection conn, {String? host, int? port}) async {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(dc);
          final ok = await controller.printLastDanfe(connection: conn, host: host, port: port);
          messenger.showSnackBar(SnackBar(
            duration: Duration(seconds: ok ? 2 : 5),
            content: Text(ok
                ? 'DANFE enviado para a impressora${host != null ? ' ($host)' : ''}.'
                : 'Falha ao imprimir: ${controller.printerError ?? 'erro desconhecido'}'),
          ));
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            // Varredura automática ao abrir.
            if (encontradas == null && !procurando) {
              procurando = true;
              disco.scan().then((r) => setLocal(() {
                    procurando = false;
                    encontradas = r;
                  }));
            }

            Widget corpo;
            if (procurando) {
              corpo = const Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('Procurando impressoras na rede...')),
              ]);
            } else if (manual) {
              corpo = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Digite o IP da impressora:'),
                const SizedBox(height: 8),
                TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP da impressora', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Imprimir'),
                  onPressed: () => imprimir(PrinterConnection.wifi, host: ipCtrl.text.trim(), port: 9100),
                ),
              ]);
            } else if ((encontradas ?? []).isEmpty) {
              corpo = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Nenhuma impressora encontrada na rede.'),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Procurar de novo'),
                  onPressed: () => setLocal(() { encontradas = null; }),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Inserir IP manualmente'),
                  onPressed: () => setLocal(() => manual = true),
                ),
              ]);
            } else {
              corpo = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Toque na impressora para imprimir:'),
                const SizedBox(height: 4),
                ...encontradas!.map((p) => ListTile(
                      leading: const Icon(Icons.print),
                      title: Text('Impressora'),
                      subtitle: Text('${p.host}:${p.port}'),
                      onTap: () => imprimir(PrinterConnection.wifi, host: p.host, port: p.port),
                    )),
                const Divider(),
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Procurar de novo'),
                  onPressed: () => setLocal(() { encontradas = null; }),
                ),
              ]);
            }

            return AlertDialog(
              title: const Text('Imprimir DANFE'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('Impressora do sistema (PDF)'),
                      onPressed: () async {
                        final pdf = await controller.buildLastDanfePdf();
                        if (!context.mounted) return;
                        Navigator.pop(dc);
                        if (pdf != null) {
                          await Printing.layoutPdf(onLayout: (_) async => pdf, name: 'DANFE');
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text('Para impressora laser/comum (ex.: HP LaserJet).',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Divider(height: 20),
                    const Text('Impressora térmica de rede (cupom):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    corpo,
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Fechar')),
              ],
            );
          },
        );
      },
    );
  }

  void _showNotaEmitida(BuildContext context) {
    final controller = context.read<CartController>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dc) {
        final autorizada = controller.lastSaleAuthorized;
        final statusCor = autorizada ? const Color(0xFF1E7E45) : const Color(0xFFB26A00);
        return AlertDialog(
          title: Text(autorizada
              ? 'NFC-e AUTORIZADA'
              : 'DANFE — pré-nota (não transmitida)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: statusCor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(autorizada ? Icons.check_circle : Icons.schedule, size: 18, color: statusCor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          controller.transmissionStatus.isEmpty
                              ? 'Status indisponível'
                              : controller.transmissionStatus,
                          style: TextStyle(color: statusCor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF5F5F5),
                  child: Text(
                    controller.danfePreview,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (controller.printerAvailable)
              TextButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Imprimir'),
                onPressed: () => _showPrinterOptions(context, controller),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.storefront),
              label: const Text('Concluir'),
              onPressed: () {
                Navigator.pop(dc);
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(); // volta ao catálogo
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    String selectedPayment = 'DINHEIRO';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          // Não sombrear o `context` da tela: ele é usado após fechar este
          // diálogo para mostrar o comprovante e voltar ao catálogo.
          builder: (_, setState) {
            return AlertDialog(
              title: const Text('Finalizar Venda'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecione a Forma de Pagamento:'),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: selectedPayment,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'DINHEIRO', child: Text('Dinheiro')),
                      DropdownMenuItem(value: 'CARTAO_DEBITO', child: Text('Cartão de Débito')),
                      DropdownMenuItem(value: 'CARTAO_CREDITO', child: Text('Cartão de Crédito')),
                      DropdownMenuItem(value: 'PIX', child: Text('PIX (Offline)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedPayment = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await context.read<CartController>().prepareSale(selectedPayment);
                    if (!context.mounted) return;
                    _showDanfePreview(context);
                  },
                  child: const Text('Continuar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Portão de confirmação: mostra a nota ANTES de efetivar. "Cancelar" aborta
  /// sem baixar estoque nem consumir número fiscal; "Confirmar" efetiva + imprime.
  void _showDanfePreview(BuildContext context) {
    final controller = context.read<CartController>();
    final fiscal = controller.pendingFiscal;
    if (fiscal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nada para pré-visualizar.')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (previewContext) {
        return AlertDialog(
          title: const Text('Confira o DANFE antes de emitir'),
          content: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF5F5F5),
              child: Text(
                fiscal.previewText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.3),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.discardSale();
                Navigator.pop(previewContext);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: Text(controller.printerAvailable
                  ? 'Confirmar e imprimir'
                  : 'Confirmar venda'),
              onPressed: () async {
                Navigator.pop(previewContext);
                final ok = await controller.confirmSale();
                if (!context.mounted) return;
                if (ok) {
                  _showNotaEmitida(context); // mostra a nota emitida em tela
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Falha ao concluir a venda.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartController = context.watch<CartController>();
    final items = cartController.items;

    return Scaffold(
      appBar: AppBar(
        title: Text('Carrinho (${cartController.totalItems} itens)'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpar Carrinho',
              onPressed: () => cartController.clearCart(),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Seu carrinho está vazio',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Adicione produtos do catálogo para iniciar a venda.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Text(
                      item.product.descricao,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'UN: R\$ ${item.product.precoVenda.toStringAsFixed(2)} | Subtotal: R\$ ${item.total.toStringAsFixed(2)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => cartController.updateQuantity(item.product.id, -1),
                        ),
                        Text(
                          '${item.quantity}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => cartController.updateQuantity(item.product.id, 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total da Venda:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'R\$ ${cartController.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: cartController.isProcessing
                          ? null
                          : () => _showCheckoutDialog(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: cartController.isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'Finalizar Venda e Baixar Estoque',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
