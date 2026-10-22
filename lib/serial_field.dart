import 'package:flutter/material.dart';

import 'theme.dart';

/// A serial-number entry field that opens on the NUMBER PAD by default —
/// most serial entry is digits — with a one-tap switch to the full
/// keyboard for the letters (the ABC / dialpad button in the field).
/// Used by the Lookup bar, the registry form, and staff corrections.
class SerialField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  const SerialField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  State<SerialField> createState() => _SerialFieldState();
}

class _SerialFieldState extends State<SerialField> {
  bool _fullKeyboard = false;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _toggleKeyboard() {
    setState(() => _fullKeyboard = !_fullKeyboard);
    // Changing keyboardType alone doesn't reopen the IME with the new
    // layout — bounce focus so Android shows the requested keyboard.
    _focus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      style: widget.style,
      autofocus: widget.autofocus,
      keyboardType:
          _fullKeyboard ? TextInputType.text : TextInputType.number,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        suffixIcon: IconButton(
          icon: Icon(_fullKeyboard ? Icons.dialpad : Icons.abc,
              color: kPurpleLight),
          tooltip: _fullKeyboard
              ? 'Switch to number pad'
              : 'Switch to full keyboard',
          onPressed: _toggleKeyboard,
        ),
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
