import 'package:flutter/material.dart';

class CreateDeckDialog extends StatefulWidget {
  const CreateDeckDialog({super.key});

  @override
  State<CreateDeckDialog> createState() => _CreateDeckDialogState();
}

class _CreateDeckDialogState extends State<CreateDeckDialog> {
  final TextEditingController _deckNameController = TextEditingController();
  String _errorMessage = '';

  @override
  void dispose() {
    _deckNameController.dispose();
    super.dispose();
  }

  void _onCreatePressed() {
    final input = _deckNameController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập tên bộ Flashcard';
      });
      return;
    }
    Navigator.of(context).pop(input);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo Bộ Flashcard mới'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _deckNameController,
            decoration: InputDecoration(
              hintText: 'Nhập tên bộ Flashcard',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            autofocus: true,
            onChanged: (_) {
              if (_errorMessage.isNotEmpty) {
                setState(() {
                  _errorMessage = '';
                });
              }
            },
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // Return null
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: _onCreatePressed,
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}
