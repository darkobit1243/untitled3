import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 52,
    this.fullWidth = true,
  }) : _outlined = false;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 52,
    this.fullWidth = true,
  }) : _outlined = true;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final bool fullWidth;
  final bool _outlined;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
          )
        : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));

    final button = _outlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          );

    final sized = SizedBox(height: height, child: button);
    return fullWidth ? SizedBox(width: double.infinity, child: sized) : sized;
  }
}
