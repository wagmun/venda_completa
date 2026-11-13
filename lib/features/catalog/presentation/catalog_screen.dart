import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/camera_barcode_scanner_widget.dart';
import '../../../core/widgets/physical_barcode_scanner_listener.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/customer_picker.dart';
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

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja encerrar a sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    await context.read<AuthController>().logout();
    navigator.pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final atualCtrl = TextEditingController();
    final novaCtrl = TextEditingController();
    final confirmaCtrl = TextEditingController();
    final auth = context.read<AuthController>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String? erro;
        bool salvando = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Trocar senha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: atualCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha atual'),
                  ),
                  TextField(
                    controller: novaCtrl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Nova senha (mín. 6)'),
                  ),
                  TextField(
                    controller: confirmaCtrl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirmar nova senha'),
                  ),
                  if (erro != null) ...[
                    const SizedBox(height: 12),
                    Text(erro!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      salvando ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: salvando
                      ? null
                      : () async {
                          if (novaCtrl.text != confirmaCtrl.text) {
                            setDialogState(
                                () => erro = 'As senhas não coincidem.');
                            return;
                          }
                          if (novaCtrl.text.length < 6) {
                            setDialogState(() =>
                                erro = 'A nova senha deve ter ao menos 6 caracteres.');
                            return;
                          }
                          setDialogState(() {
                            salvando = true;
                            erro = null;
                          });
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);
                          final res = await auth.changePassword(
                            senhaAtual: atualCtrl.text,
                            senhaNova: novaCtrl.text,
                          );
                          if (res == null) {
                            navigator.pop();
                            messenger.showSnackBar(const SnackBar(
                                content: Text('Senha alterada com sucesso.')));
                          } else {
                            setDialogState(() {
                              salvando = false;
                              erro = res;
                            });
                          }
                        },
                  child: salvando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
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
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Minhas vendas',
              onPressed: () => Navigator.of(context).pushNamed('/sales'),
            ),
            PopupMenuButton<String>(
              tooltip: 'Conta',
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (value) async {
                if (value == 'senha') {
                  await _showChangePasswordDialog(context);
                } else if (value == 'sair') {
                  await _confirmLogout(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'senha',
                  child: ListTile(
                    leading: Icon(Icons.password),
                    title: Text('Trocar senha'),
                  ),
                ),
                PopupMenuItem(
                  value: 'sair',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Sair'),
                  ),
                ),
              ],
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
            // Barra fixa do cliente (destinatário da NF-e 55). Escolhido uma vez,
            // vale para as vendas; pode trocar a qualquer momento.
            Material(
              color: cartController.hasCustomer
                  ? Colors.green.withValues(alpha: 0.10)
                  : Colors.orange.withValues(alpha: 0.12),
              child: InkWell(
                onTap: () async {
                  await showCustomerPicker(context, cartController);
                  if (context.mounted) setState(() {});
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        cartController.hasCustomer ? Icons.person : Icons.person_off,
                        size: 20,
                        color: cartController.hasCustomer ? Colors.green[800] : Colors.orange[800],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartController.hasCustomer ? 'Cliente' : 'Nenhum cliente selecionado',
                              style: TextStyle(
                                fontSize: 11,
                                color: cartController.hasCustomer ? Colors.green[900] : Colors.orange[900],
                              ),
                            ),
                            Text(
                              cartController.hasCustomer
                                  ? '${cartController.clienteNome}  (${cartController.clienteDoc})'
                                  : 'Toque para selecionar',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await showCustomerPicker(context, cartController);
                          if (context.mounted) setState(() {});
                        },
                        child: Text(cartController.hasCustomer ? 'Trocar' : 'Selecionar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
