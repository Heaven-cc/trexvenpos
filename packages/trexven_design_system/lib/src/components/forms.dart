import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';
import '../theme/presentation.dart';

enum TrexvenFieldVariant { standard, search, chat }

Widget _validationMessage(BuildContext context, String message) => Text(
  message,
  style: Theme.of(context).inputDecorationTheme.errorStyle,
  softWrap: true,
);

/// Keeps the field name outside the editable area. Only semantic/functional
/// decoration properties belong here; visual states come from the shared theme.
class TrexvenInputDecoration extends InputDecoration {
  final String? fieldLabel;
  const TrexvenInputDecoration({
    String? labelText,
    super.hintText,
    super.prefixIcon,
    super.suffixIcon,
    super.prefixText,
    super.suffixText,
    super.errorText,
    super.helperText,
    super.counterText,
  }) : fieldLabel = labelText;
}

class TrexvenFieldLabel extends StatelessWidget {
  final String text;
  const TrexvenFieldLabel({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Text(
      text,
      style: TrexvenTypography.label.copyWith(
        color: TrexvenPresentation.isPos(context) ? theme.colorScheme.onSurface
            : isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    );
  }
}

class _FieldFrame extends StatelessWidget {
  final Widget child;
  final String? label;
  final double gap;
  const _FieldFrame({required this.child, this.label, required this.gap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: TrexvenPresentation.gap(context, gap)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          ExcludeSemantics(child: TrexvenFieldLabel(text: label!)),
          const SizedBox(height: TrexvenSpacing.labelGap),
        ],
        Semantics(
          label: label,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: child,
          ),
        ),
      ],
    ),
  );
}

String? _label(
  InputDecoration decoration,
  String? explicit,
  bool show,
  TrexvenFieldVariant variant,
) {
  if (!show || variant != TrexvenFieldVariant.standard) return null;
  return explicit ??
      (decoration is TrexvenInputDecoration
          ? decoration.fieldLabel
          : decoration.labelText) ??
      decoration.hintText;
}

class TrexvenTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final String? label;
  final bool showLabel, autofocus, obscureText, autocorrect, enableSuggestions;
  final bool? enabled;
  final int? maxLines, minLines, maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged, onSubmitted;
  final double gap;
  final TrexvenFieldVariant variant;
  const TrexvenTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const TrexvenInputDecoration(),
    this.label,
    this.showLabel = true,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.gap = TrexvenSpacing.fieldGap,
    this.variant = TrexvenFieldVariant.standard,
  });
  @override
  Widget build(BuildContext context) => _FieldFrame(
    label: _label(decoration, label, showLabel, variant),
    gap: gap,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      style: Theme.of(context).textTheme.bodyLarge,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    ),
  );
}

class TrexvenTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final String? label, initialValue;
  final bool showLabel, autofocus, obscureText, autocorrect, enableSuggestions;
  final bool? enabled;
  final int? maxLines, minLines, maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged, onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final AutovalidateMode? autovalidateMode;
  final double gap;
  final TrexvenFieldVariant variant;
  const TrexvenTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const TrexvenInputDecoration(),
    this.label,
    this.initialValue,
    this.showLabel = true,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.onSaved,
    this.autovalidateMode,
    this.gap = TrexvenSpacing.fieldGap,
    this.variant = TrexvenFieldVariant.standard,
  });
  @override
  Widget build(BuildContext context) => _FieldFrame(
    label: _label(decoration, label, showLabel, variant),
    gap: gap,
    child: TextFormField(
      errorBuilder: decoration.errorText == null ? _validationMessage : null,
      controller: controller,
      focusNode: focusNode,
      initialValue: initialValue,
      decoration: decoration,
      style: Theme.of(context).textTheme.bodyLarge,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
    ),
  );
}

class TrexvenDropdown<T> extends StatelessWidget {
  final T? initialValue, value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final DropdownButtonBuilder? selectedItemBuilder;
  final FormFieldValidator<T>? validator;
  final Widget? hint;
  final String? label;
  final InputDecoration decoration;
  final bool showLabel, rich;
  final double gap;
  const TrexvenDropdown({
    super.key,
    this.initialValue,
    this.value,
    this.items,
    required this.onChanged,
    this.selectedItemBuilder,
    this.validator,
    this.hint,
    this.label,
    this.showLabel = true,
    this.rich = false,
    this.decoration = const TrexvenInputDecoration(),
    this.gap = TrexvenSpacing.fieldGap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _FieldFrame(
      label: _label(decoration, label, showLabel, TrexvenFieldVariant.standard),
      gap: gap,
      child: DropdownButtonFormField<T>(
        errorBuilder: decoration.errorText == null ? _validationMessage : null,
        initialValue: initialValue ?? value,
        isExpanded: true,
        isDense: !rich,
        itemHeight: null,
        style: theme.textTheme.bodyLarge,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        borderRadius: BorderRadius.circular(TrexvenRadii.field),
        dropdownColor: theme.colorScheme.surface,
        decoration: decoration,
        items: items,
        onChanged: onChanged,
        hint: hint,
        selectedItemBuilder: selectedItemBuilder,
        validator: validator,
      ),
    );
  }
}

class TrexvenFormSection extends StatelessWidget {
  final String title;
  final Widget child;
  const TrexvenFormSection({
    super.key,
    required this.title,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TrexvenSpacing.sectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

/// A persistent, accessible field for existing date-picker callbacks.
class TrexvenDateField extends StatelessWidget {
  final String label, value;
  final VoidCallback? onTap;
  const TrexvenDateField({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => _FieldFrame(
    label: label,
    gap: TrexvenSpacing.fieldGap,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(TrexvenRadii.field),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TrexvenRadii.field),
        child: Padding(
          padding: TrexvenSpacing.fieldPadding,
          child: Row(
            children: [
              Expanded(child: Text(value, style: TrexvenTypography.input)),
              const Icon(Icons.calendar_today_outlined, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}
