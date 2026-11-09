import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_controller.dart'; // Importa o controller e o AuthState
import 'test_login_picker.dart'; // ⚠️ TESTE — remover antes de produção

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final state = authController.state;

    return Scaffold(
      body: Stack(
        children: [
          Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.storefront, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Venda Completa',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail do Vendedor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 24),
                if (state.errorMessage != null) ...[
                  Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                ElevatedButton(
                  onPressed: state.status == AuthStatus.loading
                      ? null
                      : () async {
                    // Captura o Navigator antes do await (evita usar context após gap async).
                    final navigator = Navigator.of(context);
                    await authController.login(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                    // Ao autenticar com sucesso, avança para o catálogo.
                    if (!mounted) return;
                    if (authController.state.status ==
                        AuthStatus.authenticated) {
                      navigator.pushReplacementNamed('/catalog');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: state.status == AuthStatus.loading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Entrar e Sincronizar'),
                ),
              ],
            ),
          ),
        ),
          ),
          // ===== INÍCIO ÁREA DE TESTE (REMOVER ANTES DE PRODUÇÃO) =====
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: TestLoginPicker(
                onPick: (email, senha) {
                  _emailController.text = email;
                  _passwordController.text = senha;
                },
              ),
            ),
          ),
          // ===== FIM ÁREA DE TESTE =====
        ],
      ),
    );
  }
}
