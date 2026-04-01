import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import 'models/flashcard.dart';
import 'services/shake_detector.dart';
import '../utils/flashcard_haptics.dart';
import 'widgets/flashcard_widget.dart';

void main() {
  runApp(const ShakeShuffleDemoApp());
}

class ShakeShuffleDemoApp extends StatelessWidget {
  const ShakeShuffleDemoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shake to Shuffle Demo',
      home: const ShakeShuffleHome(),
    );
  }
}

class ShakeShuffleHome extends StatefulWidget {
  const ShakeShuffleHome({Key? key}) : super(key: key);

  @override
  State<ShakeShuffleHome> createState() => _ShakeShuffleHomeState();
}

class _ShakeShuffleHomeState extends State<ShakeShuffleHome> with SingleTickerProviderStateMixin {
  late List<Flashcard> _cards;
  late ShakeDetector _shakeDetector;
  late AnimationController _listAnimController;
  int _shakeCount = 0; // gamification counter
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasShuffleSound = false;

  @override
  void initState() {
    super.initState();
    // Sample cards
    _cards = List.generate(
      8,
      (i) => Flashcard(id: 'c$i', front: 'Word ${i + 1}', back: 'Definition ${i + 1}'),
    );

    _shakeDetector = ShakeDetector(
      shakeThresholdGravity: 3.0, // slightly higher to avoid false triggers
      debounceDuration: const Duration(seconds: 1),
      shakeWindow: const Duration(milliseconds: 700),
      shakeCount: 2,
    );
    _shakeDetector.onShake.listen((_) => _onShakeDetected());
    _shakeDetector.startListening();

    _listAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

    // preload optional sound (place a short click in assets or rely on system sound)
    _preloadSound();
  }

  Future<void> _preloadSound() async {
    try {
      // Check asset exists in bundle
      await rootBundle.load('assets/sounds/shuffle.wav');
      _hasShuffleSound = true;
      // Attempt to load an asset sound if provided at assets/sounds/shuffle.wav
      await _audioPlayer.setSourceAsset('assets/sounds/shuffle.wav');
    } catch (_) {
      // ignore if no asset
      _hasShuffleSound = false;
    }
  }

  @override
  void dispose() {
    _shakeDetector.dispose();
    _listAnimController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onShakeDetected() {
    setState(() {
      _shakeCount++;
    });

    FlashcardHaptics.shuffle();

    // Play sound (optional)
    if (_hasShuffleSound) {
      _audioPlayer.play(AssetSource('assets/sounds/shuffle.wav')).catchError((_) {});
    }

    // Shuffle with animation and show snackbar
    _listAnimController.forward(from: 0).then((_) {
      setState(() {
        _cards.shuffle(Random());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cards shuffled!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shake to Shuffle')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Shake your device to shuffle the deck'),
                Chip(label: Text('Shakes: $_shakeCount')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedBuilder(
                animation: _listAnimController,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_listAnimController.value);
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3 / 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) {
                          final rotate = Tween(begin: 0.0, end: pi).animate(animation);
                          return AnimatedBuilder(
                            animation: rotate,
                            child: child,
                            builder: (context, child) {
                              final isUnder = (rotate.value > pi / 2);
                              final tilt = (rotate.value / pi) * 0.02;
                              return Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(rotate.value)
                                  ..multiply(Matrix4.translationValues(isUnder ? -10.0 * tilt : 0.0, 0.0, 0.0)),
                                alignment: Alignment.center,
                                child: Opacity(
                                  opacity: 0.8 + 0.2 * t,
                                  child: child,
                                ),
                              );
                            },
                          );
                        },
                        child: SizedBox(
                          key: ValueKey(card.id),
                          child: FlashcardWidget(card: card),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _onShakeDetected(),
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle (manual)'),
            )
          ],
        ),
      ),
    );
  }
}
