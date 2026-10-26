import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sticker_diary/main.dart';
import 'package:sticker_diary/store.dart';

void main() {
  late Directory temp;
  late DiaryStore store;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sticker-ui-');
    store = DiaryStore(temp);
    await store.load();
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  testWidgets(
    'register screen requires a real photo and does not invent capture date',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(StickerDiaryApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('첫 스티커 만들기'));
      await tester.pumpAndSettle();
      expect(find.text('새로운 조각 모으기'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('내 스티커 보드에 저장'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('촬영 정보가 없어요. 날짜를 선택해 주세요.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '내 스티커 보드에 저장'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'board opens named sticker, diary text survives saving and reopening',
    (tester) async {
      final image = img.Image(width: 20, height: 20, numChannels: 4)
        ..clear(img.ColorRgba8(80, 120, 80, 255));
      await tester.runAsync(
        () => store.addSticker(
          img.encodePng(image),
          '동네 카페 라떼',
          DateTime(2026, 10, 20),
        ),
      );
      await tester.pumpWidget(StickerDiaryApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('동네 카페 라떼'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 10월 20일 촬영'), findsOneWidget);
      await tester.tap(find.text('일기에 붙이기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('새 일기 쓰기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('글 쓰기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '오늘은 커피 한 잔.\n작은 행복.');
      await tester.tap(find.text('글 입력 완료'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      for (var i = 0; i < 100 && store.diaries.isEmpty; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
      expect(store.diaries.single.body, '오늘은 커피 한 잔.\n작은 행복.');
      expect(store.diaries.single.placements.length, 1);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('일기장'));
      await tester.pumpAndSettle();
      expect(find.text('오늘은 커피 한 잔.\n작은 행복.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unsaved diary prompts before leaving', (tester) async {
    await tester.pumpWidget(StickerDiaryApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기 쓰기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('글 쓰기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '저장 전 내용');
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.text('일기 작성을 나갈까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('저장 전 내용'), findsOneWidget);
  });
}
