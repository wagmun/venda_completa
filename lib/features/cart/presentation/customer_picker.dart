import 'package:flutter/material.dart';
import 'cart_controller.dart';

/// Diálogo de seleção do cliente (destinatário da NF-e 55): lista os contatos
/// do Bling + opção de digitar um novo. Grava a escolha no [controller].
Future<void> showCustomerPicker(
    BuildContext context, CartController controller) async {
  final buscaCtrl = TextEditingController();
  final novoNomeCtrl = TextEditingController();
  final novoDocCtrl = TextEditingController();
  List<Map<String, dynamic>>? clientes;
  var carregando = false;
  var modoNovo = false;

  await showDialog<void>(
    context: context,
    builder: (dc) {
      return StatefulBuilder(builder: (ctx, setLocal) {
        Future<void> buscar() async {
          setLocal(() => carregando = true);
          final r = await controller.fetchCustomers(q: buscaCtrl.text.trim());
          setLocal(() {
            carregando = false;
            clientes = r;
          });
        }

        if (clientes == null && !carregando) buscar();

        Widget corpo;
        if (modoNovo) {
          corpo = Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: novoNomeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nome do cliente', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: novoDocCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'CPF/CNPJ (só números)', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              TextButton(onPressed: () => setLocal(() => modoNovo = false), child: const Text('Voltar')),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  final nome = novoNomeCtrl.text.trim();
                  final doc = novoDocCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                  if (nome.isEmpty || doc.length < 11) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Informe nome e um CPF/CNPJ válido.')));
                    return;
                  }
                  controller.setCustomer(nome: nome, doc: doc);
                  Navigator.pop(dc);
                },
                child: const Text('Usar este cliente'),
              ),
            ]),
          ]);
        } else if (carregando) {
          corpo = const Padding(
              padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        } else {
          final lista = clientes ?? const [];
          corpo = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: TextField(
                controller: buscaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Buscar por nome/CNPJ', isDense: true, border: OutlineInputBorder()),
                onSubmitted: (_) => buscar(),
              )),
              IconButton(icon: const Icon(Icons.search), onPressed: buscar),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 240, width: 320,
              child: lista.isEmpty
                  ? const Center(child: Text('Nenhum cliente encontrado.'))
                  : ListView(children: lista.map((c) => ListTile(
                        dense: true,
                        title: Text((c['nome'] ?? '').toString()),
                        subtitle: Text((c['numero_documento'] ?? '').toString()),
                        onTap: () {
                          controller.setCustomer(
                            nome: (c['nome'] ?? '').toString(),
                            doc: (c['numero_documento'] ?? '').toString(),
                          );
                          Navigator.pop(dc);
                        },
                      )).toList()),
            ),
            TextButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Novo cliente (digitar)'),
              onPressed: () => setLocal(() => modoNovo = true),
            ),
          ]);
        }

        return AlertDialog(
          title: const Text('Selecionar cliente'),
          content: corpo,
          actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Fechar'))],
        );
      });
    },
  );
}
