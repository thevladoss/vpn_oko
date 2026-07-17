import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';

class AddSubscriptionField extends StatefulWidget {
  const AddSubscriptionField({
    required this.onSubmit,
    this.busy = false,
    super.key,
  });

  final ValueChanged<String> onSubmit;
  final bool busy;

  @override
  State<AddSubscriptionField> createState() => _AddSubscriptionFieldState();
}

class _AddSubscriptionFieldState extends State<AddSubscriptionField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    unawaited(HapticFeedback.mediumImpact());
    widget.onSubmit(url);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !widget.busy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Ссылка на подписку',
              prefixIcon: Icon(Icons.link_rounded, color: tones.textSecondary),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (widget.busy)
          const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          IconButton.filledTonal(
            onPressed: _submit,
            tooltip: 'Добавить подписку',
            icon: const Icon(Icons.add_rounded),
          ),
      ],
    );
  }
}
