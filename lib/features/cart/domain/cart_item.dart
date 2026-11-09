import 'package:venda_completa/core/database/app_database.dart';

class CartItem {
  final LocalInventoryData product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get total => product.precoVenda * quantity;

  CartItem copyWith({
    LocalInventoryData? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'sku': product.sku,
      'codigo_ean': product.codigoEan,
      'descricao': product.descricao,
      'ncm': product.ncm,
      'unidade_medida': product.unidadeMedida,
      'preco_unitario': product.precoVenda,
      'quantidade': quantity,
      'total': total,
    };
  }
}
