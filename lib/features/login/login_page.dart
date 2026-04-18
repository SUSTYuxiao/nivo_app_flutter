import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import 'login_provider.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final provider = context.read<LoginProvider>();
    _emailCtrl = TextEditingController(text: provider.defaultEmail);
    _passwordCtrl = TextEditingController(text: provider.defaultPassword);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<LoginProvider>();
    final success = await provider.signIn(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (success && mounted) {
      widget.onLoginSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Consumer<LoginProvider>(
              builder: (context, provider, _) {
                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic_rounded, size: 64, color: AppColors.accent),
                      const SizedBox(height: 12),
                      const Text(
                        'Nivo',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '会议纪要助手',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 48),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: '邮箱',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => provider.validateEmail(v ?? ''),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordCtrl,
                              decoration: const InputDecoration(
                                labelText: '密码',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              validator: (v) => provider.validatePassword(v ?? ''),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (provider.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            provider.errorMessage!,
                            style: const TextStyle(color: AppColors.recording),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: CupertinoButton(
                          onPressed: provider.isLoading ? null : _handleLogin,
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(25),
                          padding: EdgeInsets.zero,
                          child: provider.isLoading
                              ? const CupertinoActivityIndicator(color: Colors.white)
                              : const Text(
                                  '登录',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
