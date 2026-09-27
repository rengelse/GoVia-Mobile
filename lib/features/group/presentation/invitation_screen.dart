import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/screen_scaffold.dart';

class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  bool scanning = false;
  bool redeeming = false;
  String? value;
  String? error;
  bool handled = false;

  Future<void> _consume(String code) async {
    if (redeeming || handled) {
      return;
    }
    setState(() {
      redeeming = true;
      scanning = false;
      value = code;
      error = null;
      handled = true;
    });
    try {
      final trip = await AppScope.of(context).redeemDesktopHandoff(code);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${trip.name} er hentet fra Desktop.')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        redeeming = false;
        handled = false;
        error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => GoViaScreen(
        title: 'Hent fra Desktop',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Skann QR-koden på det konkrete turkortet i GoVia Desktop. Koden er kortlivet, kan bare brukes én gang og inneholder ingen innloggingsnøkler.',
              style: TextStyle(color: GoViaColors.muted),
            ),
            const SizedBox(height: 18),
            if (scanning)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 360,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final code = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
                      if (code != null && mounted) {
                        _consume(code);
                      }
                    },
                  ),
                ),
              )
            else
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: GoViaColors.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GoViaColors.border),
                ),
                child: Center(
                  child: redeeming
                      ? const CircularProgressIndicator()
                      : Icon(Icons.qr_code_2_rounded, size: 130, color: value == null ? GoViaColors.muted : GoViaColors.orange),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: redeeming
                  ? null
                  : () => setState(() {
                        scanning = !scanning;
                        handled = false;
                        error = null;
                      }),
              icon: Icon(scanning ? Icons.close : Icons.qr_code_scanner),
              label: Text(scanning ? 'Stopp skanning' : value == null ? 'Skann QR-kode' : 'Skann på nytt'),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(child: Text(error!, style: const TextStyle(color: GoViaColors.muted))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}
