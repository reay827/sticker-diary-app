import 'dart:io';
import 'dart:ui' show Rect;
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'subject_model.dart';

class PreparedPhoto {
  PreparedPhoto(this.png, this.takenOn);
  final Uint8List png;
  final DateTime? takenOn;
}

class CutoutSubject {
  const CutoutSubject({required this.png, required this.bounds});
  final Uint8List png;

  /// Bounds relative to the original, orientation-corrected photo.
  final Rect bounds;
}

class CutoutResult {
  const CutoutResult({
    required this.combined,
    required this.subjects,
    required this.aspectRatio,
  });
  final Uint8List combined;
  final List<CutoutSubject> subjects;
  final double aspectRatio;
}

CutoutResult prepareCutouts(Map<String, dynamic> payload) {
  final source = img.PngDecoder().startDecode(payload['source'] as Uint8List);
  if (source == null) throw const FormatException('원본 사진을 읽지 못했어요.');
  final subjects = <CutoutSubject>[];
  for (final entry in payload['subjects'] as List) {
    final item = entry as Map;
    final bitmap = item['bitmap'] as Uint8List?;
    if (bitmap == null || bitmap.isEmpty) continue;
    final width = item['width'] as int, height = item['height'] as int;
    if (width <= 0 || height <= 0) continue;
    Uint8List png;
    try {
      png = trimTransparent(bitmap);
    } on FormatException {
      continue;
    }
    final left = ((item['startX'] as int) / source.width).clamp(0.0, 1.0);
    final top = ((item['startY'] as int) / source.height).clamp(0.0, 1.0);
    final right = (((item['startX'] as int) + width) / source.width).clamp(
      left,
      1.0,
    );
    final bottom = (((item['startY'] as int) + height) / source.height).clamp(
      top,
      1.0,
    );
    if (right <= left || bottom <= top) continue;
    subjects.add(
      CutoutSubject(png: png, bounds: Rect.fromLTRB(left, top, right, bottom)),
    );
  }
  subjects.sort((a, b) {
    final y = a.bounds.top.compareTo(b.bounds.top);
    return y == 0 ? a.bounds.left.compareTo(b.bounds.left) : y;
  });
  return CutoutResult(
    combined: trimTransparent(payload['foreground'] as Uint8List),
    subjects: List.unmodifiable(subjects),
    aspectRatio: source.width / source.height,
  );
}

Uint8List cropPhotoRegion(Map<String, dynamic> payload) {
  final photo = img.decodePng(payload['photo'] as Uint8List);
  if (photo == null) throw const FormatException('사진을 읽지 못했어요.');
  final x = ((payload['left'] as double) * photo.width).floor().clamp(
    0,
    photo.width - 1,
  );
  final y = ((payload['top'] as double) * photo.height).floor().clamp(
    0,
    photo.height - 1,
  );
  final right = ((payload['right'] as double) * photo.width).ceil().clamp(
    x + 1,
    photo.width,
  );
  final bottom = ((payload['bottom'] as double) * photo.height).ceil().clamp(
    y + 1,
    photo.height,
  );
  return img.encodePng(
    img.copyCrop(photo, x: x, y: y, width: right - x, height: bottom - y),
  );
}

DateTime? parseExifDate(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2})').firstMatch(value);
  if (match == null) return null;
  final y = int.parse(match[1]!),
      m = int.parse(match[2]!),
      d = int.parse(match[3]!);
  final parsed = DateTime(y, m, d);
  return y >= 1900 && parsed.year == y && parsed.month == m && parsed.day == d
      ? parsed
      : null;
}

Uint8List normalizePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('이 사진 형식을 읽을 수 없어요. JPG 또는 PNG 사진을 선택해 주세요.');
  }
  var image = img.bakeOrientation(decoded);
  if (image.width > 1600 || image.height > 1600) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 1600 : null,
      height: image.height > image.width ? 1600 : null,
    );
  }
  return img.encodePng(image);
}

Uint8List trimTransparent(Uint8List bytes) {
  final image = img.decodePng(bytes);
  if (image == null) throw const FormatException('스티커 이미지를 읽지 못했어요.');
  int left = image.width, top = image.height, right = -1, bottom = -1;
  for (final p in image) {
    if (p.a > 16) {
      if (p.x < left) left = p.x;
      if (p.x > right) right = p.x;
      if (p.y < top) top = p.y;
      if (p.y > bottom) bottom = p.y;
    }
  }
  if (right < left) {
    throw const FormatException('사진에서 대상을 찾지 못했어요. 다른 사진을 골라 주세요.');
  }
  return img.encodePng(
    img.copyCrop(
      image,
      x: left,
      y: top,
      width: right - left + 1,
      height: bottom - top + 1,
    ),
  );
}

class PhotoService {
  final picker = ImagePicker();
  Future<XFile?> pick(ImageSource source) => picker.pickImage(
    source: source,
    maxWidth: 1800,
    maxHeight: 1800,
    imageQuality: 95,
    requestFullMetadata: true,
  );
  Future<PreparedPhoto> prepare(XFile file) async {
    if (await file.length() > 30 * 1024 * 1024) {
      throw const FormatException('사진이 너무 커요. 조금 작은 사진을 선택해 주세요.');
    }
    final bytes = await file.readAsBytes();
    DateTime? takenOn;
    try {
      final tags = await readExifFromBytes(bytes);
      takenOn = parseExifDate(tags['EXIF DateTimeOriginal']?.printable);
    } catch (_) {
      /* Missing metadata is presented as an empty date field. */
    }
    final png = await compute(normalizePhoto, bytes);
    return PreparedPhoto(png, takenOn);
  }

  Future<CutoutResult> removeBackground(
    Uint8List png, {
    ValueChanged<String>? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('자동 오려내기는 안드로이드 앱에서 사용할 수 있어요.');
    }
    await const SubjectModelLoader().ensureReady(onProgress: onProgress);
    onProgress?.call('사진에서 대상을 오려내고 있어요…');
    final dir = await getTemporaryDirectory();
    final input = File('${dir.path}/cutout-${uuid.v4()}.png');
    final segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: true,
        ),
      ),
    );
    try {
      await input.writeAsBytes(png);
      final result = await segmenter
          .processImage(InputImage.fromFilePath(input.path))
          .timeout(const Duration(seconds: 45));
      final foreground = result.foregroundBitmap;
      if (foreground == null || foreground.isEmpty) {
        throw const FormatException('대상을 분리하지 못했어요. 다른 사진으로 다시 시도해 주세요.');
      }
      return await compute(prepareCutouts, {
        'source': png,
        'foreground': foreground,
        'subjects': result.subjects
            .map(
              (subject) => {
                'bitmap': subject.bitmap,
                'startX': subject.startX,
                'startY': subject.startY,
                'width': subject.width,
                'height': subject.height,
              },
            )
            .toList(),
      });
    } finally {
      await segmenter.close();
      if (await input.exists()) await input.delete();
    }
  }
}
