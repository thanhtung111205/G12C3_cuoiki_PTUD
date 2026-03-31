import 'package:flutter/material.dart';
import 'translation_service.dart';
import 'translation_viewmodel.dart';
import 'context_translation_widget.dart';

class TranslationDemoScreen extends StatelessWidget {
  const TranslationDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Using a fake translation endpoint that echoes back for demo. Replace endpoint with real one.
    // Use MyMemory public API for demo translation (GET-based)
    // final service = TranslationService(endpoint: 'https://api.mymemory.translated.net/get');
    // final vm = TranslationViewModel(service: service);

    // For quick offline testing use the mock service. Change to real service when ready.
    // final service = TranslationService(endpoint: 'https://api.mymemory.translated.net/get');
    // final vm = TranslationViewModel(service: service);
    // Use MyMemory public API for translation in demo.
    final service = TranslationService(endpoint: 'https://api.mymemory.translated.net/get');
    final vm = TranslationViewModel(service: service);

    final sample = '''
 Flutter empowers developers to build beautiful apps. The quick brown fox jumps over the lazy dog.
 Idioms like "break the ice" are tricky to translate word-by-word. Knowing context helps.
 ''';

    return Scaffold(
      appBar: AppBar(title: const Text('Dịch theo ngữ cảnh (Demo)')),
      body: Column(
        children: [
          Expanded(child: ContextTranslationWidget(text: sample, viewModel: vm)),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text('Nhấn giữ để chọn nhiều từ/đoạn và chọn "Dịch" để xem nghĩa tiếng Việt.'),
          )
        ],
      ),
    );
  }
}
