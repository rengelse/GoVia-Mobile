import 'package:flutter/material.dart';
import '../theme/govia_theme.dart';

class GoViaScreen extends StatelessWidget {
  const GoViaScreen({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 24),
    this.scroll = true,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final EdgeInsets padding;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(subtitle!, style: const TextStyle(color: GoViaColors.muted))),
          if (scroll) Expanded(child: SingleChildScrollView(child: child)) else Expanded(child: child),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: GoViaColors.bg,
        surfaceTintColor: Colors.transparent,
        actions: actions,
      ),
      body: SafeArea(top: false, child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}
