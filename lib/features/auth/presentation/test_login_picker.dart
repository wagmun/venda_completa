// =============================================================================
// ⚠️  WIDGET APENAS PARA TESTES — REMOVER ANTES DE PRODUÇÃO ⚠️
//
// Seletor de Empresa × Funcionário que preenche as credenciais de login
// automaticamente, para testar rapidamente combinações. No app final o
// vendedor digita só e-mail/senha e a empresa é resolvida pelo servidor.
//
// Para remover ao final: apague este arquivo e o bloco demarcado em
// login_screen.dart (procure por "ÁREA DE TESTE").
// =============================================================================
import 'package:flutter/material.dart';

/// Credencial de teste (funcionário de uma empresa).
class _TestSeller {
  final String nome;
  final String email;
  const _TestSeller(this.nome, this.email);
}

/// Dados de teste — espelham o seed do backend. Senha de todos: 123456.
const Map<String, List<_TestSeller>> _testData = {
  'Auto Peças Veloz': [
    _TestSeller('João da Silva', 'joao@autopecas.com'),
    _TestSeller('Maria Souza', 'maria@gmail.com'),
  ],
  'Oficina Boa': [
    _TestSeller('Ana Pereira', 'ana@oficinaboa.com'),
  ],
  'Mercado Central': [
    _TestSeller('Vendedor Demo', 'demo@demo.com'),
  ],
};

const String _testPassword = '123456';

class TestLoginPicker extends StatefulWidget {
  /// Chamado ao escolher um funcionário: entrega e-mail e senha para preencher.
  final void Function(String email, String senha) onPick;

  const TestLoginPicker({super.key, required this.onPick});

  @override
  State<TestLoginPicker> createState() => _TestLoginPickerState();
}

class _TestLoginPickerState extends State<TestLoginPicker> {
  String? _empresa;
  String? _email;

  @override
  Widget build(BuildContext context) {
    final funcionarios = _empresa == null ? const <_TestSeller>[] : _testData[_empresa]!;

    return Card(
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.amber.shade700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, size: 16, color: Colors.amber.shade900),
                const SizedBox(width: 4),
                Text('ÁREA DE TESTE',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _empresa,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Empresa',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _testData.keys
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _empresa = v;
                  _email = null;
                }),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _email,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Funcionário',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: funcionarios
                    .map((s) => DropdownMenuItem(
                        value: s.email, child: Text('${s.nome} (${s.email})')))
                    .toList(),
                onChanged: funcionarios.isEmpty
                    ? null
                    : (v) {
                        setState(() => _email = v);
                        if (v != null) widget.onPick(v, _testPassword);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
