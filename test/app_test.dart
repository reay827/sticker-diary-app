import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sticker_diary/main.dart';
import 'package:sticker_diary/store.dart';
import 'package:sticker_diary/models.dart';
import 'package:sticker_diary/widgets.dart';
import 'package:sticker_diary/diary_screens.dart';

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
      expect(find.text('오늘은 커피 한 잔.\n작은 행복.'), findsWidgets);
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
  testWidgets(
    'drag and transform one reused sticker without moving the other',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final image = img.Image(width: 20, height: 20, numChannels: 4)
        ..clear(img.ColorRgba8(80, 120, 80, 255));
      await tester.runAsync(
        () => store.addSticker(img.encodePng(image), '컵', DateTime(2026)),
      );
      final id = store.stickers.single.id;
      final diary = Diary.empty()..body = '같은 컵 두 개';
      diary.placements.addAll([
        Placement(id: 'first', stickerId: id, x: .25, y: .5),
        Placement(id: 'second', stickerId: id, x: .75, y: .7),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEditor(store: store, diary: diary),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('first')),
        const Offset(35, -25),
      );
      await tester.pumpAndSettle();
      var draft = tester.widget<DiaryPage>(find.byType(DiaryPage)).diary;
      expect(draft.placements.last.id, 'first');
      expect(draft.placements.last.x, greaterThan(.25));
      expect(draft.placements.last.y, lessThan(.5));
      expect(draft.placements.first.x, .75);
      final sizeTrack = tester.getRect(find.byType(Slider).first);
      await tester.tapAt(
        Offset(sizeTrack.left + sizeTrack.width * .75, sizeTrack.center.dy),
      );
      await tester.pumpAndSettle();
      final angleTrack = tester.getRect(find.byType(Slider).last);
      await tester.tapAt(Offset(angleTrack.center.dx, angleTrack.center.dy));
      await tester.pumpAndSettle();
      draft = tester.widget<DiaryPage>(find.byType(DiaryPage)).diary;
      expect(draft.placements.last.width, greaterThan(.3));
      expect(draft.placements.last.angle, greaterThan(0));
      expect(draft.placements.first.width, .3);
      expect(draft.placements.first.angle, 0);
      await tester.tap(find.text('저장'));
      for (var i = 0; i < 100 && store.diaries.isEmpty; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
      final reopened = DiaryStore(temp);
      await tester.runAsync(reopened.load);
      expect(
        reopened.diaries.single.placements.map((p) => p.toJson()).toList(),
        draft.placements.map((p) => p.toJson()).toList(),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'diary layout toggles show full pages and open the correct diary',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final older = Diary.empty()
        ..date = DateTime(2026, 10, 20)
        ..body = '지난날의 조각';
      final newer = Diary.empty()
        ..date = DateTime(2026, 10, 26)
        ..body = '오늘의 조각';
      await tester.runAsync(() async {
        await store.saveDiary(older);
        await store.saveDiary(newer);
      });
      await tester.pumpWidget(StickerDiaryApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일기장'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing);
      expect(
        tester
            .widgetList<DiaryThumbnail>(find.byType(DiaryThumbnail))
            .map((p) => p.diary.id),
        [newer.id, older.id],
      );
      await tester.tap(find.byTooltip('이미지 모아보기'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(
        tester
            .widgetList<DiaryThumbnail>(find.byType(DiaryThumbnail))
            .map((p) => p.diary.id),
        [newer.id, older.id],
      );
      await tester.tap(find.byKey(ValueKey('diary-preview-${older.id}')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DiaryPage>(find.byType(DiaryPage)).diary.id,
        older.id,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      await tester.tap(find.text('내 스티커'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일기장'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      await tester.tap(find.byTooltip('가로 목록'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing);
      expect(find.text('오늘의 조각'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
