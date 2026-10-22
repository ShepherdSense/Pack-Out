import 'package:flutter/material.dart';

import 'theme.dart';

/// The PIN the station ships with. It only gets a member of staff as far as
/// the forced first-run PIN setup — staff mode itself requires a PIN the
/// crew chose.
const defaultStaffPin = '2468';

bool validPin(String v) =>
    v.length >= 4 && v.length <= 8 && int.tryParse(v) != null;

/// Dialog that collects a NEW staff PIN with a confirmation field (a typo
/// must not lock staff out of the only management UI). Pops with the new
/// PIN, or null when cancelled.
class ChangePinDialog extends StatefulWidget {
  final String title;
  const ChangePinDialog({super.key, this.title = 'Change staff PIN'});
  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _save() {
    final v = _a.text.trim();
    if (!validPin(v)) {
      setState(() => _error = 'PIN must be 4–8 digits.');
      return;
    }
    if (v != _b.text.trim()) {
      setState(() => _error = 'The two entries do not match.');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCard,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _a,
            keyboardType: TextInputType.number,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New PIN (4–8 digits)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _b,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Type it again'),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: kWarn)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save PIN')),
      ],
    );
  }
}
