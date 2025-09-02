import 'package:flutter/material.dart';

class NameDialog extends StatefulWidget {
  final String initial;
  const NameDialog({super.key, required this.initial});

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nome Rider'),
      content: TextField(
        controller: _c,
        decoration: const InputDecoration(labelText: 'Inserisci nome'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('OK')),
      ],
    );
  }
}
