import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class DiaryStore extends ChangeNotifier {
  DiaryStore(this.root);
  final Directory root;
  List<Sticker> _stickers = [];
  List<Diary> _diaries = [];
  bool recoveredFromBackup = false;
  Future<void> _pending = Future.value();
  List<Sticker> get stickers =>
      List.unmodifiable(_stickers.where((s) => s.visible));
  List<Diary> get diaries => List.unmodifiable(
    [..._diaries]..sort((a, b) {
      final day = b.date.compareTo(a.date);
      return day != 0 ? day : b.updatedAt.compareTo(a.updatedAt);
    }),
  );
  Sticker? sticker(String id) {
    for (final s in _stickers) {
      if (s.id == id) return s;
    }
    return null;
  }

  File imageFile(Sticker s) {
    if (!RegExp(r'^[a-zA-Z0-9-]+\.png$').hasMatch(s.fileName)) {
      throw const FormatException('잘못된 이미지 경로');
    }
    return File('${root.path}/images/${s.fileName}');
  }

  static Future<DiaryStore> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final store = DiaryStore(Directory('${dir.path}/sticker_diary'));
    await store.load();
    return store;
  }

  File get _data => File('${root.path}/library.json');
  File get _backup => File('${root.path}/library.backup.json');

  Future<void> load() async {
    await Directory('${root.path}/images').create(recursive: true);
    if (!await _data.exists() && !await _backup.exists()) return;
    try {
      _decode(await _data.readAsString());
    } catch (_) {
      // Never replace damaged data with an empty library.
      _decode(await _backup.readAsString());
      recoveredFromBackup = true;
    }
  }

  void _decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1) throw const FormatException('지원하지 않는 저장 형식');
    final stickers = (j['stickers'] as List)
        .map((s) => Sticker.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
    final diaries = (j['diaries'] as List)
        .map((d) => Diary.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList();
    for (final s in stickers) {
      imageFile(s);
    }
    _stickers = stickers;
    _diaries = diaries;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _commit(List<Sticker> stickers, List<Diary> diaries) async {
    final encoded = jsonEncode({
      'version': 1,
      'stickers': stickers.map((s) => s.toJson()).toList(),
      'diaries': diaries.map((d) => d.toJson()).toList(),
    });
    final temp = File('${_data.path}.tmp');
    await temp.writeAsString(encoded, flush: true);
    if (await _data.exists() && !recoveredFromBackup) {
      await _data.copy(_backup.path);
    }
    await temp.rename(_data.path);
    _stickers = stickers;
    _diaries = diaries;
    recoveredFromBackup = false;
    notifyListeners();
  }

  Future<void> addSticker(Uint8List png, String name, DateTime takenOn) =>
      _enqueue(() async {
        final id = uuid.v4();
        final s = Sticker(
          id: id,
          fileName: '$id.png',
          name: name.trim(),
          takenOn: dateOnly(takenOn),
          createdAt: DateTime.now(),
        );
        final file = imageFile(s);
        await file.writeAsBytes(png, flush: true);
        try {
          await _commit([..._stickers, s], _diaries);
        } catch (_) {
          await file.delete();
          rethrow;
        }
      });
  Future<void> updateSticker(Sticker value) => _enqueue(
    () => _commit(
      _stickers.map((s) => s.id == value.id ? value : s).toList(),
      _diaries,
    ),
  );
  // Keep image records after hiding; existing diary placements and the recovery
  // snapshot must continue to work. Physical cleanup is deferred to backup work.
  Future<void> hideSticker(Sticker value) =>
      updateSticker(value.edit(visible: false));
  Future<void> saveDiary(Diary diary) => _enqueue(() {
    final saved = diary.copy()..updatedAt = DateTime.now();
    return _commit(_stickers, [
      ..._diaries.where((d) => d.id != saved.id),
      saved,
    ]);
  });
  Future<void> deleteDiary(String id) => _enqueue(
    () => _commit(_stickers, _diaries.where((d) => d.id != id).toList()),
  );
}
