import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_ui.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.inputFormatters,
    this.enabled = true,
    this.textInputAction,
    this.focusNode,
    this.nextFocusNode,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: AppSpace.xs),
        Semantics(
          textField: true,
          label: label,
          child: RepaintBoundary(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              obscureText: obscureText,
              inputFormatters: inputFormatters,
              textInputAction: textInputAction,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
              ),
              onChanged: onChanged,
              onSubmitted: (v) {
                if (onSubmitted != null) {
                  onSubmitted!(v);
                  return;
                }
                final next = nextFocusNode;
                if (next != null) {
                  FocusScope.of(context).requestFocus(next);
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
