import 'package:flutter/material.dart';

/// Keep dialog controllers alive through the closing route animation.
class TextControllerScope extends StatefulWidget {
  final List<TextEditingController> controllers;
  final Widget child;
  const TextControllerScope({
    super.key,
    required this.controllers,
    required this.child,
  });
  @override
  State<TextControllerScope> createState() => _TextControllerScopeState();
}

class _TextControllerScopeState extends State<TextControllerScope> {
  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
