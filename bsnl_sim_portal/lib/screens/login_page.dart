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
  String? _error;

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
    });
    try {
      await widget.auth.login(_email.text, _password.text);
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
              const Text(
                'Sign in',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Khatushyamji personal account se login karo.',
                style: TextStyle(color: BsnlColors.muted, height: 1.4),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email / Username',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: _hide,
                autofillHints: const [AutofillHints.password],
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
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: BsnlColors.saffron, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Login'),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071A44), Color(0xFF0B3D91), Color(0xFF7C3AED)],
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrandMark(),
          SizedBox(height: 22),
          Text(
            'BSNL Khatushyamji',
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.2),
          ),
          SizedBox(height: 10),
          Text(
            'Personal BSNL Management System — Portal, CBP aur CTOPUP.',
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
                  child: DecoratedBox(
                    decoration: bsnlPageGradient(),
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: BsnlColors.gold,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.cell_tower, color: BsnlColors.navyDark, size: 30),
    );
  }
}
