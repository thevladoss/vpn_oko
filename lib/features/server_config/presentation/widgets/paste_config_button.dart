import 'package:flutter/material.dart';

class PasteConfigButton extends StatelessWidget {
  const PasteConfigButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(Icons.content_paste_rounded),
      label: const Text('Вставить vless://'),
    );
  }
}
