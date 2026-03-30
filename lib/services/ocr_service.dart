import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service dùng Google ML Kit Text Recognition để bóc tách chữ từ ảnh.
///
/// Chạy hoàn toàn on-device — không cần internet, không cần API key.
/// Hỗ trợ Latin (Tiếng Anh, Tiếng Việt có dấu) qua [TextRecognitionScript.latin].
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();
  factory OcrService() => instance;

  /// Bóc tách toàn bộ chữ từ ảnh tại [imagePath].
  ///
  /// Trả về chuỗi text đã nhận diện, hoặc chuỗi rỗng nếu không tìm thấy chữ.
  /// Ném exception nếu file không tồn tại hoặc ML Kit gặp lỗi.
  Future<String> extractText(String imagePath) async {
    // Bước 1: Tạo InputImage từ đường dẫn file ảnh.
    final InputImage inputImage = InputImage.fromFilePath(imagePath);

    // Bước 2: Khởi tạo TextRecognizer với script Latin (EN + VI).
    final TextRecognizer textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      // Bước 3: Gọi ML Kit xử lý ảnh.
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // Bước 4: Sắp xếp các Block theo vị trí Y (trên → dưới) rồi
      // ghép từng Line để giữ đúng thứ tự đọc của văn bản.
      //
      // Lý do phải sort: ML Kit không đảm bảo thứ tự trả về các Block
      // khớp với thứ tự đọc thật sự trên trang.
      final List<TextBlock> sortedBlocks =
          List<TextBlock>.from(recognizedText.blocks)
            ..sort(
              (TextBlock a, TextBlock b) =>
                  a.boundingBox.top.compareTo(b.boundingBox.top),
            );

      final StringBuffer buffer = StringBuffer();
      for (final TextBlock block in sortedBlocks) {
        // Sắp xếp Line trong mỗi Block theo Y (phòng trường hợp cột lệch).
        final List<TextLine> sortedLines = List<TextLine>.from(block.lines)
          ..sort(
            (TextLine a, TextLine b) =>
                a.boundingBox.top.compareTo(b.boundingBox.top),
          );

        for (final TextLine line in sortedLines) {
          buffer.writeln(line.text);
        }

        // Dòng trống giữa các đoạn (block) để phân biệt đoạn văn.
        buffer.writeln();
      }

      // Bỏ khoảng trắng/newline thừa ở đầu + cuối.
      return buffer.toString().trim();
    } finally {
      // Bước 5: Đóng recognizer để giải phóng tài nguyên native.
      await textRecognizer.close();
    }
  }
}