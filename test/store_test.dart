import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sticker_diary/models.dart';
import 'package:sticker_diary/store.dart';
import 'package:sticker_diary/photo_service.dart';

void main() {
  late Directory temp;
  late DiaryStore store;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sticker-test-');
    store = DiaryStore(temp);
    await store.load();
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  final png = img.encodePng(img.Image(width: 5, height: 5, numChannels: 4));

  test(
    'Korean metadata, two independent placements and hidden sticker survive restart',
    () async {
      await store.addSticker(png, '따뜻한 라떼 ☕', DateTime(2026, 10, 1));
      final s = store.stickers.single;
      final diary = Diary.empty()..body = '오늘은 카페에서\n조용히 쉬었다.';
      diary.placements.addAll([
        Placement(
          id: 'p1',
          stickerId: s.id,
          x: .24,
          y: .42,
          width: .22,
          angle: .7,
        ),
        Placement(
          id: 'p2',
          stickerId: s.id,
          x: .75,
          y: .7,
          width: .5,
          angle: 2.1,
        ),
      ]);
      await store.saveDiary(diary);
      await store.hideSticker(s);
      final reopened = DiaryStore(temp);
      await reopened.load();
      expect(reopened.stickers, isEmpty);
      expect(reopened.sticker(s.id)!.name, '따뜻한 라떼 ☕');
      expect(reopened.sticker(s.id)!.takenOn, DateTime(2026, 10, 1));
      expect(
        await reopened.imageFile(reopened.sticker(s.id)!).exists(),
        isTrue,
      );
      expect(
        reopened.diaries.single.toJson(),
        diary.toJson()
          ..['updatedAt'] = reopened.diaries.single.updatedAt.toIso8601String(),
      );
      final copy = reopened.diaries.single.copy();
      copy.placements.first.move(.1, .1);
      expect(copy.placements.last.x, .75);
      expect(reopened.diaries.single.placements.first.x, .24);
    },
  );
  test('concurrent saves preserve both records', () async {
    await Future.wait([
      store.addSticker(png, '컵', DateTime(2026)),
      store.addSticker(png, '꽃', DateTime(2025)),
    ]);
    final reopened = DiaryStore(temp);
    await reopened.load();
    expect(reopened.stickers.map((s) => s.name), ['컵', '꽃']);
  });
  test(
    'failed disk write does not mutate live state or leave new image',
    () async {
      await Directory('${temp.path}/library.json.tmp').create();
      await expectLater(
        store.addSticker(png, '컵', DateTime(2026)),
        throwsA(isA<FileSystemException>()),
      );
      expect(store.stickers, isEmpty);
      expect(await Directory('${temp.path}/images').list().length, 0);
    },
  );
  test(
    'corrupt primary recovers backup and subsequent save remains readable',
    () async {
      await store.addSticker(png, '컵', DateTime(2026));
      await store.addSticker(png, '꽃', DateTime(2026));
      await File('${temp.path}/library.json').writeAsString('{broken');
      final reopened = DiaryStore(temp);
      await reopened.load();
      expect(reopened.recoveredFromBackup, isTrue);
      expect(reopened.stickers.single.name, '컵');
      await reopened.addSticker(png, '책', DateTime(2026));
      final again = DiaryStore(temp);
      await again.load();
      expect(again.stickers.map((s) => s.name), ['컵', '책']);
    },
  );
  test(
    'corrupt primary without backup throws rather than overwriting',
    () async {
      final data = File('${temp.path}/library.json');
      await data.writeAsString('broken');
      await expectLater(store.load(), throwsA(isA<FileSystemException>()));
      expect(await data.readAsString(), 'broken');
    },
  );
  test('transparent PNG is tightly trimmed and alpha preserved', () {
    final image = img.Image(width: 10, height: 10, numChannels: 4);
    image.setPixelRgba(3, 4, 255, 0, 0, 128);
    image.setPixelRgba(5, 6, 0, 255, 0, 255);
    final output = img.decodePng(trimTransparent(img.encodePng(image)))!;
    expect(output.width, 3);
    expect(output.height, 3);
    expect(output.getPixel(0, 0).a, 128);
    expect(output.getPixel(1, 0).a, 0);
    expect(() => trimTransparent(png), throwsFormatException);
  });
  test('EXIF date rejects invalid dates and never guesses missing date', () {
    expect(parseExifDate('2026:10:26 12:01:00'), DateTime(2026, 10, 26));
    expect(parseExifDate('2026:02:31 12:01:00'), isNull);
    expect(parseExifDate(null), isNull);
  });
  test('sticker bounds and size remain usable', () {
    final p = Placement(id: 'p', stickerId: 's');
    p.move(20, -20);
    p.resize(20);
    expect(p.x, .97);
    expect(p.y, .03);
    expect(p.width, .65);
    p.resize(0);
    expect(p.width, .12);
  });
}
