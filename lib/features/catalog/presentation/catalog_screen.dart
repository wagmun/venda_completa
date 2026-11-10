import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/camera_barcode_scanner_widget.dart';
import '../../../core/widgets/physical_barcode_scanner_listener.dart';
import '../../cart/presentation/cart_controller.dart';
import 'catalog_controller.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({Key? key}) : super(key: key);

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  final _physicalScanner = PhysicalBarcodeScannerListener();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogController>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openCameraScanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SizedBox(
          height: 400,
          child: Column(
            children: [
              AppBar(
                title: const Text('Escanear Código de Barras'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(bottomSheetContext),
                  ),
                ],
              ),
              Expanded(
                child: CameraBarcodeScannerWidget(
                  onEanScanned: (ean) {
                    Navigator.pop(bottomSheetContext);
                    _searchController.text = ean;
                    context.read<CatalogController>().searchProducts(ean);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Seletor de quantidade na própria tela (diálogo sobreposto, sem navegar).
  /// Define a quantidade e adiciona o produto ao carrinho numa única ação.
  void _showQuantityDialog(
    BuildContext context,
    dynamic product,
    CartController cartController,
    int estoqueMax,
  ) {
    int quantidade = 1;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final subtotal = product.precoVenda * quantidade;
            return AlertDialog(
              title: Text(product.descricao),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('R\$ ${product.precoVenda.toStringAsFixed(2)} / UN  •  Estoque: $estoqueMax'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: quantidade > 1
                            ? () => setDialogState(() => quantidade--)
                            : null,
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '$quantidade',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: quantidade < estoqueMax
                            ? () => setDialogState(() => quantidade++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subtotal: R\$ ${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Adicionar'),
                  onPressed: () {
                    cartController.addProduct(product, quantity: quantidade);
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          duration: const Duration(milliseconds: 900),
                          content: Text('$quantidade x ${product.descricao} adicionado(s)'),
                        ),
                      );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogController = context.watch<CatalogController>();
    final cartController = context.watch<CartController>();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        _physicalScanner.handleKeyEvent(event, (scannedEan) {
          _searchController.text = scannedEan;
          context.read<CatalogController>().searchProducts(scannedEan);
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catálogo de Produtos'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar catálogo',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await catalogController.refreshFromServer();
                messenger.showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Catálogo atualizado.'
                      : 'Não foi possível atualizar (sem servidor?).'),
                ));
              },
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Abrir Câmera',
              onPressed: () => _openCameraScanner(context),
            ),
            IconButton(
              tooltip: 'Abrir Carrinho',
              icon: Badge(
                isLabelVisible: cartController.totalItems > 0,
                label: Text('${cartController.totalItems}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              onPressed: () async {
                await Navigator.of(context).pushNamed('/cart');
                // Ao voltar do carrinho (ex.: após uma venda), recarrega o
                // catálogo para refletir a baixa de estoque.
                if (context.mounted) {
                  context.read<CatalogController>().loadProducts();
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar por Nome, SKU ou EAN',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      catalogController.loadProducts();
                    },
                  )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (query) {
                  catalogController.searchProducts(query);
                },
              ),
            ),
            Expanded(
              child: catalogController.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : catalogController.products.isEmpty
                  ? const Center(
                child: Text('Nenhum produto encontrado.'),
              )
                  : ListView.builder(
                itemCount: catalogController.products.length,
                itemBuilder: (context, index) {
                  final product = catalogController.products[index];
                  // Cálculo do estoque líquido disponível
                  final estoqueDisponivel = product.qtdFisica - product.qtdReservada;
                  // Limite de venda: cota offline (se definida) ou o estoque.
                  final limiteVenda =
                      product.cotaOffline > 0 ? product.cotaOffline : estoqueDisponivel;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 4.0,
                    ),
                    child: ListTile(
                      onTap: limiteVenda > 0
                          ? () => _showQuantityDialog(
                                context,
                                product,
                                cartController,
                                limiteVenda.floor(),
                              )
                          : null,
                      leading: CircleAvatar(
                        child: Text(
                          product.unidadeMedida,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(
                        product.descricao,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'SKU: ${product.sku} | EAN: ${product.codigoEan}\nNCM: ${product.ncm}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${product.precoVenda.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'Estoque: ${estoqueDisponivel.toStringAsFixed(0)} UN',
                            style: TextStyle(
                              fontSize: 12,
                              color: estoqueDisponivel > 0
                                  ? Colors.grey[700]
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
