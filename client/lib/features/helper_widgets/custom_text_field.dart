import 'package:flutter/material.dart';
import 'package:muzic/core/theme/app_pallete.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({super.key, this.hintText, this.validator, this.keyboardType, this.controller, this.obscureText = false, this.prefixIcon});

  final String? hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final bool obscureText;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Pallete.whiteColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Pallete.subtitleText),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Pallete.subtitleText, size: 20) : null,
        filled: true,
        fillColor: Pallete.cardColor,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Pallete.gradient2, width: 2)),
      ),
      validator: validator,
      keyboardType: keyboardType,
    );
  }
}
