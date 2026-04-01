import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../utils/app_colors.dart';

class DictionaryPopup extends StatefulWidget {
  const DictionaryPopup({
    super.key,
    required this.word,
    required this.pronunciation,
    required this.meaning,
    required this.onSave,
    required this.offset,
    this.audioUrl = '',
  });

  final String word;
  final String pronunciation;
  final String meaning;
  final String audioUrl;
  final VoidCallback onSave;
  final Offset offset;

  @override
  State<DictionaryPopup> createState() => _DictionaryPopupState();
}

class _DictionaryPopupState extends State<DictionaryPopup> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPronunciation() async {
    try {
      if (widget.audioUrl.isNotEmpty) {
        if (_isPlaying) {
          await _audioPlayer.stop();
        } else {
          await _audioPlayer.setUrl(widget.audioUrl);
          await _audioPlayer.play();
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void _openDictionary() {
    // TODO: Open full dictionary detail
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      // Center horizontally, position near top of screen
      left: 16,
      right: 16,
      top: screenSize.height * 0.15,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Word & Pronunciation
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Word
                  Text(
                    widget.word,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepPurple, // Màu 1
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Speaker Icon
                  if (widget.audioUrl.isNotEmpty)
                    GestureDetector(
                      onTap: _playPronunciation,
                      child: Icon(
                        _isPlaying ? Icons.volume_down : Icons.volume_up,
                        size: 22,
                        color: AppColors.deepPurple,
                      ),
                    ),
                  const SizedBox(width: 8),

                  // Pronunciation
                  if (widget.pronunciation.isNotEmpty)
                    Expanded(
                      child: Text(
                        widget.pronunciation,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Meaning Label
              Text(
                'Nghĩa của từ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Meaning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lavender.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.meaning,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF231A3D),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_add, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Lưu vào Sổ từ / Flashcard',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
