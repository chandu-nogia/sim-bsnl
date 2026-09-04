import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  bool _forgot = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_forgot) {
        final msg = await widget.auth.api.forgotPassword(widget.auth.apiBase, _email.text);
        setState(() => _info = msg);
      } else {
        await widget.auth.login(_email.text, _password.text);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _forgot ? 'Reset request' : 'Sign in',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
              ),
              const SizedBox(height: 6),
              Text(
                _forgot
                    ? 'Admin ko request chali jayegi. Naya password admin set karega.'
                    : 'Admin ya employee account se continue karo.',
                style: const TextStyle(color: BsnlColors.muted, height: 1.4),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email / Login ID',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              if (!_forgot) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _hide,
                  onSubmitted: (_) => _busy ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hide = !_hide),
                      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: BsnlColors.saffron, fontWeight: FontWeight.w700)),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_info!, style: const TextStyle(color: BsnlColors.success, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_forgot ? 'Send request' : 'Login'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _forgot = !_forgot;
                  _error = null;
                  _info = null;
                }),
                child: Text(_forgot ? 'Back to login' : 'Forgot password?'),
              ),
            ],
          ),
        ),
      ),
    );

    final brand = Container(
      width: wide ? 420 : double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: const BoxDecoration(
        color: BsnlColors.navyDark,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: BsnlColors.gold,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.cell_tower, color: BsnlColors.navyDark, size: 30),
          ),
          const SizedBox(height: 22),
          const Text(
            'BSNL Management',
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 10),
          const Text(
            'Location-wise Portal, CBC and C-TopUp. Har shop ka data alag aur safe.',
            style: TextStyle(color: Color(0xFFD7DEEA), fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                brand,
                Expanded(
                  child: ColoredBox(
                    color: BsnlColors.page,
                    child: Center(child: Padding(padding: const EdgeInsets.all(24), child: form)),
                  ),
                ),
              ],
            )
          : ColoredBox(
              color: BsnlColors.page,
              child: ListView(
                children: [
                  SizedBox(height: 220, child: brand),
                  Padding(padding: const EdgeInsets.all(20), child: form),
                ],
              ),
            ),
    );
  }
}
