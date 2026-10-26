import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_diary/main.dart';
import 'package:sticker_diary/store.dart';

void main() {
  testWidgets('export mobile screen previews', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final temp = await tester.runAsync(
      () => Directory.systemTemp.createTemp('sticker-preview-'),
    );
    final store = DiaryStore(temp!);
    await tester.runAsync(store.load);
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: StickerDiaryApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/previews/$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('sticker-board');
    await tester.tap(find.text('첫 스티커 만들기'));
    await tester.pumpAndSettle();
    await capture('register-sticker');
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기 쓰기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('글 쓰기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '오늘은 동네 카페에서 쉬었다.\n따뜻한 커피 한 잔과 조용한 오후.\n\n이런 작은 순간들을 모아두고 싶다.',
    );
    await tester.tap(find.text('글 입력 완료'));
    await tester.pumpAndSettle();
    await capture('diary-editor');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => temp.delete(recursive: true));
  }, skip: Platform.environment['SAVE_PREVIEWS'] != '1');
}
