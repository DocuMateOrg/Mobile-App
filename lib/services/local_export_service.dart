import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalExportService {
  /// Pure-Dart zero-dependency PDF generator that embeds JPEG images and formatted text
  static Future<String?> exportToPdf({
    required String title,
    required String content,
    String? imagePath,
  }) async {
    try {
      Uint8List? jpegBytes;
      if (imagePath != null && File(imagePath).existsSync()) {
        try {
          jpegBytes = await File(imagePath).readAsBytes();
        } catch (e) {
          debugPrint("LocalExportService image read notice: $e");
        }
      }

      final pdfBytes = _buildPdfBytes(
        title: title,
        content: content,
        jpegBytes: jpegBytes,
      );

      final dir = await getTemporaryDirectory();
      final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
      final fileName = '${sanitizedTitle.isEmpty ? "document" : sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      debugPrint("Local PDF export error: $e");
      return null;
    }
  }

  /// Pure-Dart zero-dependency Word (.doc) generator compatible with Word, Google Docs, and WPS
  static Future<String?> exportToWordDoc({
    required String title,
    required String content,
    String? imagePath,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
      final fileName = '${sanitizedTitle.isEmpty ? "document" : sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.doc';
      final file = File('${dir.path}/$fileName');

      final escapedTitle = title.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
      final escapedContent = content
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('\n', '<br/>');

      String imageHtml = '';
      if (imagePath != null && File(imagePath).existsSync()) {
        try {
          final bytes = await File(imagePath).readAsBytes();
          final base64Image = base64Encode(bytes);
          imageHtml = '<div style="text-align: center; margin: 20px 0;"><img src="data:image/jpeg;base64,$base64Image" style="max-width: 500px; max-height: 500px;" /></div>';
        } catch (_) {}
      }

      final docContent = """
<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
<head>
  <meta charset="utf-8">
  <title>$escapedTitle</title>
  <style>
    body { font-family: 'Calibri', Arial, sans-serif; font-size: 11pt; color: #1e293b; line-height: 1.6; margin: 40px; }
    h1 { color: #0056D2; font-size: 20pt; border-bottom: 2px solid #e2e8f0; padding-bottom: 8px; margin-bottom: 20px; }
    .content-box { margin-top: 20px; font-size: 11pt; }
    .footer { margin-top: 30px; font-size: 9pt; color: #64748b; border-top: 1px solid #e2e8f0; padding-top: 8px; }
  </style>
</head>
<body>
  <h1>$escapedTitle</h1>
  $imageHtml
  <div class="content-box">
    $escapedContent
  </div>
  <div class="footer">Exported from DocuMate Digitizer</div>
</body>
</html>
""";

      await file.writeAsString(docContent);
      return file.path;
    } catch (e) {
      debugPrint("Local Word export error: $e");
      return null;
    }
  }

  static Uint8List _buildPdfBytes({
    required String title,
    required String content,
    Uint8List? jpegBytes,
  }) {
    int imageWidth = 800;
    int imageHeight = 600;
    bool hasImage = false;

    if (jpegBytes != null && jpegBytes.length > 10 && jpegBytes[0] == 0xFF && jpegBytes[1] == 0xD8) {
      hasImage = true;
      for (int i = 0; i < jpegBytes.length - 8; i++) {
        if (jpegBytes[i] == 0xFF && (jpegBytes[i + 1] == 0xC0 || jpegBytes[i + 1] == 0xC2)) {
          imageHeight = (jpegBytes[i + 5] << 8) | jpegBytes[i + 6];
          imageWidth = (jpegBytes[i + 7] << 8) | jpegBytes[i + 8];
          break;
        }
      }
    }

    const pageWidth = 595.28;
    const pageHeight = 841.89;
    const margin = 40.0;
    const contentWidth = pageWidth - (margin * 2);

    final buffer = StringBuffer();

    // Top blue accent bar
    buffer.writeln('q');
    buffer.writeln('0.0 0.34 0.82 rg');
    buffer.writeln('$margin 795 $contentWidth 2.5 re f');
    buffer.writeln('Q');

    // Title text
    final cleanTitle = _sanitizeForPdf(title);
    buffer.writeln('BT');
    buffer.writeln('/F1 16 Tf');
    buffer.writeln('0.0 0.34 0.82 rg');
    buffer.writeln('$margin 805 Td');
    buffer.writeln('($cleanTitle) Tj');
    buffer.writeln('ET');

    double currentY = 765.0;

    // Embed scanned image if available
    if (hasImage) {
      double displayWidth = contentWidth;
      double displayHeight = (contentWidth / imageWidth) * imageHeight;
      if (displayHeight > 340) {
        displayHeight = 340;
        displayWidth = (displayHeight / imageHeight) * imageWidth;
      }

      final imageX = margin + (contentWidth - displayWidth) / 2;
      final imageY = currentY - displayHeight;

      buffer.writeln('q');
      buffer.writeln('$displayWidth 0 0 $displayHeight $imageX $imageY cm');
      buffer.writeln('/Im1 Do');
      buffer.writeln('Q');

      currentY = imageY - 24;
    }

    // Extracted Content & Summary text
    if (content.trim().isNotEmpty && currentY > 60) {
      buffer.writeln('BT');
      buffer.writeln('/F1 10 Tf');
      buffer.writeln('0.12 0.16 0.23 rg');
      buffer.writeln('$margin $currentY Td');
      buffer.writeln('14.0 TL');

      final wrappedLines = _wrapText(content, 78);
      for (final line in wrappedLines) {
        if (currentY <= 45) break; // Keep within printable page area
        if (line.isEmpty) {
          buffer.writeln('T*');
          currentY -= 14;
          continue;
        }
        final escaped = _sanitizeForPdf(line);
        buffer.writeln('($escaped) Tj T*');
        currentY -= 14;
      }
      buffer.writeln('ET');
    }

    // Footer
    buffer.writeln('BT');
    buffer.writeln('/F1 8 Tf');
    buffer.writeln('0.4 0.45 0.55 rg');
    buffer.writeln('$margin 25 Td');
    buffer.writeln('(Exported from DocuMate Digitizer) Tj');
    buffer.writeln('ET');

    final contentStreamBytes = utf8.encode(buffer.toString());

    final parts = <List<int>>[];
    final offsets = <int>[];
    int currentOffset = 0;

    void writePart(List<int> bytes) {
      parts.add(bytes);
      currentOffset += bytes.length;
    }

    void writeString(String s) {
      writePart(utf8.encode(s));
    }

    void startObject(int objNum) {
      offsets.add(currentOffset);
      writeString('$objNum 0 obj\n');
    }

    writeString('%PDF-1.4\n');

    startObject(1);
    writeString('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    startObject(2);
    writeString('<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n');

    startObject(3);
    writeString('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageWidth $pageHeight]\n');
    writeString('/Resources << /Font << /F1 4 0 R >> ');
    if (hasImage) {
      writeString('/XObject << /Im1 5 0 R >> ');
    }
    writeString('>>\n');
    writeString('/Contents ${hasImage ? 6 : 5} 0 R >>\nendobj\n');

    startObject(4);
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n');

    int nextObj = 5;
    if (hasImage && jpegBytes != null) {
      startObject(5);
      writeString('<< /Type /XObject /Subtype /Image /Width $imageWidth /Height $imageHeight /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpegBytes.length} >>\nstream\n');
      writePart(jpegBytes);
      writeString('\nendstream\nendobj\n');
      nextObj = 6;
    }

    startObject(nextObj);
    writeString('<< /Length ${contentStreamBytes.length} >>\nstream\n');
    writePart(contentStreamBytes);
    writeString('\nendstream\nendobj\n');

    final xrefOffset = currentOffset;
    writeString('xref\n0 ${nextObj + 1}\n');
    writeString('0000000000 65535 f \n');
    for (final off in offsets) {
      writeString('${off.toString().padLeft(10, '0')} 00000 n \n');
    }

    writeString('trailer\n<< /Size ${nextObj + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n');

    final bb = BytesBuilder();
    for (final p in parts) {
      bb.add(p);
    }
    return bb.toBytes();
  }

  static List<String> _wrapText(String text, int maxChars) {
    final result = <String>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        result.add('');
        continue;
      }
      final words = line.split(RegExp(r'\s+'));
      final currentLine = StringBuffer();
      for (final word in words) {
        if (currentLine.isEmpty) {
          currentLine.write(word);
        } else if (currentLine.length + word.length + 1 <= maxChars) {
          currentLine.write(' $word');
        } else {
          result.add(currentLine.toString());
          currentLine.clear();
          currentLine.write(word);
        }
      }
      if (currentLine.isNotEmpty) {
        result.add(currentLine.toString());
      }
    }
    return result;
  }

  static String _sanitizeForPdf(String text) {
    return text
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('•', '-')
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }
}

