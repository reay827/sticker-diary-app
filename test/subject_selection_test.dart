import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sticker_diary/photo_service.dart';
import 'package:sticker_diary/sticker_screens.dart';
import 'package:sticker_diary/store.dart';
import 'package:sticker_diary/subject_picker.dart';
import 'package:sticker_diary/photo_region_picker.dart';

Map<String, dynamic> fixture() {
  final red = img.Image(width: 3, height: 6, numChannels: 4)
    ..clear(img.ColorRgba8(240, 20, 20, 255));
  final blue = img.Image(width: 4, height: 6, numChannels: 4)
    ..clear(img.ColorRgba8(20, 30, 240, 255));
  final full = img.Image(width: 20, height: 10, numChannels: 4);
  img.compositeImage(full, red, dstX: 2, dstY: 2);
  img.compositeImage(full, blue, dstX: 14, dstY: 2);
  final png = img.encodePng(full);
  return {
    'source': png,
    'foreground': png,
    'subjects': [
      {
        'bitmap': img.encodePng(blue),
        'startX': 14,
        'startY': 2,
        'width': 4,
        'height': 6,
      },
      {
        'bitmap': img.encodePng(red),
        'startX': 2,
        'startY': 2,
        'width': 3,
        'height': 6,
      },
    ],
  };
}

class FakeMultiPhotoService extends PhotoService {
  FakeMultiPhotoService(this.payload);
  final Map<String, dynamic> payload;
  @override
  Future<XFile?> pick(ImageSource source) async => XFile('fixture.png');
  @override
  Future<PreparedPhoto> prepare(XFile file) async =>
      PreparedPhoto(payload['source'] as Uint8List, DateTime(2026, 10, 27));
  @override
  Future<CutoutResult> removeBackground(
    Uint8List png, {
    ValueChanged<String>? onProgress,
  }) async => prepareCutouts(payload);
}

void main() {
  test('a selected region excludes the other object before segmentation', () {
    final image = img.decodePng(
      cropPhotoRegion({
        'photo': fixture()['source'],
        'left': .6,
        'top': 0.0,
        'right': 1.0,
        'bottom': 1.0,
      }),
    )!;
    expect(image.width, 8);
    expect(image.height, 10);
    expect(image.getPixel(2, 2).b, 240);
    expect(image.where((p) => p.r == 240 && p.a > 0), isEmpty);
  });
  testWidgets('photo range drag returns original photo coordinates', (
    tester,
  ) async {
    Rect? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                chosen = await Navigator.push<Rect>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoRegionPicker(
                      photo: fixture()['source'] as Uint8List,
                    ),
                  ),
                );
              },
              child: const Text('범위'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('범위'));
    await tester.pumpAndSettle();
    final canvas = tester.getRect(
      find.byKey(const ValueKey('photo-region-canvas')),
    );
    await tester.dragFrom(
      Offset(canvas.left + canvas.width * .6, canvas.top + canvas.height * .1),
      Offset(canvas.width * .35, canvas.height * .8),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 범위에서 오려내기'));
    await tester.pumpAndSettle();
    expect(chosen!.left, closeTo(.6, .01));
    expect(chosen!.right, closeTo(.95, .01));
    expect(chosen!.top, closeTo(.1, .01));
    expect(chosen!.bottom, closeTo(.9, .01));
  });
  test(
    'individual bitmaps stay separate and bounds use original photo size',
    () {
      final result = prepareCutouts(fixture());
      expect(result.subjects.length, 2);
      expect(result.aspectRatio, 2);
      expect(
        result.subjects.first.bounds,
        const Rect.fromLTRB(.1, .2, .25, .8),
      );
      expect(img.decodePng(result.subjects.first.png)!.width, 3);
      expect(img.decodePng(result.subjects.last.png)!.getPixel(0, 0).b, 240);
      expect(img.decodePng(result.combined)!.width, 16);
    },
  );
  test('missing or empty individual results preserve combined fallback', () {
    final data = fixture();
    data['subjects'] = [
      {'bitmap': null, 'startX': 0, 'startY': 0, 'width': 3, 'height': 3},
    ];
    final result = prepareCutouts(data);
    expect(result.subjects, isEmpty);
    expect(img.decodePng(result.combined)!.height, 6);
  });
  testWidgets(
    'choosing one subject saves only its pixels and allows switching',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final temp = await tester.runAsync(
        () => Directory.systemTemp.createTemp('subject-choice-'),
      );
      final store = DiaryStore(temp!);
      await tester.runAsync(store.load);
      addTearDown(() async {
        await temp.delete(recursive: true);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: StickerForm(
            store: store,
            photoService: FakeMultiPhotoService(fixture()),
          ),
        ),
      );
      await tester.tap(find.text('사진 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('자동으로 오려내기'));
      await tester.pumpAndSettle();
      expect(find.byType(SubjectPhotoPicker), findsOneWidget);
      expect(find.text('찾은 대상 2개 · 하나를 골라 주세요'), findsOneWidget);
      final vertical = find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('subject-choice-0')),
        140,
        scrollable: vertical,
      );
      await tester.tap(find.byKey(const ValueKey('subject-choice-0')));
      await tester.pumpAndSettle();
      expect(find.text('대상 1 ✓'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('subject-choice-1')));
      await tester.pumpAndSettle();
      expect(find.text('대상 2 ✓'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        160,
        scrollable: vertical,
      );
      await tester.enterText(find.byType(TextField), '파란 물건 하나');
      await tester.scrollUntilVisible(
        find.text('내 스티커 보드에 저장'),
        160,
        scrollable: vertical,
      );
      await tester.tap(find.text('내 스티커 보드에 저장'));
      for (var i = 0; i < 100 && store.stickers.isEmpty; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
      expect(store.stickers.single.name, '파란 물건 하나');
      final saved = await tester.runAsync(
        () => store.imageFile(store.stickers.single).readAsBytes(),
      );
      final image = img.decodePng(saved!)!;
      expect(image.width, 4);
      expect(image.height, 6);
      expect(image.getPixel(0, 0).b, 240);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
