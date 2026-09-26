import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool create = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { busy = true; error = null; });
    final state = AppScope.of(context);
    try {
      if (create) {
        await state.auth.signUp(email.text, password.text);
      } else {
        await state.auth.signIn(email.text, password.text);
      }
      await state.initialize();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.shell, (route) => false);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) SystemNavigator.pop();
        },
        child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: GoViaLogo()),
                    const SizedBox(height: 42),
                    Text(create ? 'Opprett konto' : 'Velkommen tilbake', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('Planlegg på Desktop. Kjør med Mobile.', textAlign: TextAlign.center, style: TextStyle(color: GoViaColors.muted)),
                    const SizedBox(height: 28),
                    if (!AppConfig.hasSupabase && !AppConfig.devSeed)
                      const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Supabase er ikke konfigurert. Kontroller SUPABASE_URL og SUPABASE_PUBLISHABLE_KEY.'))),
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-post', prefixIcon: Icon(Icons.mail_outline))),
                    const SizedBox(height: 12),
                    TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Passord', prefixIcon: Icon(Icons.lock_outline))),
                    if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: GoViaColors.red))],
                    const SizedBox(height: 18),
                    FilledButton(onPressed: busy || (!AppConfig.hasSupabase && !AppConfig.devSeed) ? null : _submit, child: Text(busy ? 'Vent…' : create ? 'Opprett konto' : 'Logg inn')),
                    TextButton(onPressed: busy ? null : () => setState(() => create = !create), child: Text(create ? 'Har du konto? Logg inn' : 'Ny bruker? Opprett konto')),
                    if (AppConfig.devSeed && !AppConfig.hasSupabase) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(onPressed: () async { await AppScope.of(context).initialize(); if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.shell, (r) => false); }, icon: const Icon(Icons.science_outlined), label: const Text('Fortsett i eksplisitt DEV-seed')),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      );
}
