import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'store.dart';
import 'photo_service.dart';
import 'subject_model.dart';
import 'subject_picker.dart';
import 'photo_region_picker.dart';
import 'widgets.dart';
import 'diary_screens.dart';

class StickerForm extends StatefulWidget {
  const StickerForm({
    super.key,
    required this.store,
    this.recovered,
    this.photoService,
  });
  final DiaryStore store;
  final XFile? recovered;
  final PhotoService? photoService;
  @override
  State<StickerForm> createState() => _StickerFormState();
}

class _StickerFormState extends State<StickerForm> {
  late final service = widget.photoService ?? PhotoService();
  final name = TextEditingController();
  Uint8List? original, result;
  Uint8List? fullPhoto;
  CutoutResult? cutouts;
  int? selectedSubject;
  DateTime? takenOn;
  bool busy = false, saving = false, canLeave = false, cutout = false;
  String? error;
  String busyMessage = '사진을 준비하고 있어요…';
  @override
  void initState() {
    super.initState();
    if (widget.recovered != null) _prepare(widget.recovered!);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _prepare(XFile file, {bool camera = false}) async {
    setState(() {
      busy = true;
      busyMessage = '사진을 준비하고 있어요…';
      error = null;
    });
    try {
      final photo = await service.prepare(file);
      if (!mounted) return;
      setState(() {
        original = photo.png;
        fullPhoto = photo.png;
        result = null;
        cutouts = null;
        selectedSubject = null;
        cutout = false;
        takenOn = photo.takenOn ?? (camera ? dateOnly(DateTime.now()) : null);
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = '사진을 읽지 못했어요. JPG·PNG 형식의 다른 사진을 골라 주세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await service.pick(source);
      if (!mounted) return;
      if (file != null) {
        await _prepare(file, camera: source == ImageSource.camera);
      }
    } on PlatformException {
      if (mounted) {
        setState(() => error = '사진을 열지 못했어요. 기기 설정에서 사진 또는 카메라 접근을 확인해 주세요.');
      }
    } catch (_) {
      if (mounted) setState(() => error = '사진 선택에 실패했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final output = await service.removeBackground(
        original!,
        onProgress: (message) {
          if (mounted) setState(() => busyMessage = message);
        },
      );
      if (mounted) {
        setState(() {
          cutouts = output;
          selectedSubject = output.subjects.length == 1 ? 0 : null;
          result = output.subjects.length > 1
              ? null
              : output.subjects.length == 1
              ? output.subjects.single.png
              : output.combined;
          cutout = result != null;
        });
      }
    } catch (failure, stack) {
      debugPrint('Cutout failed: $failure\n$stack');
      if (mounted) {
        setState(
          () => error = failure is CutoutException
              ? failure.message
              : failure is FormatException
              ? failure.message
              : '모델은 준비됐지만 사진을 오려내지 못했어요. 다른 사진을 선택하거나 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _selectSubject(int index) => setState(() {
    selectedSubject = index;
    result = cutouts!.subjects[index].png;
    cutout = true;
    error = null;
  });

  Future<void> _chooseRegion() async {
    final selected = await Navigator.push<Rect>(
      context,
      MaterialPageRoute(builder: (_) => PhotoRegionPicker(photo: fullPhoto!)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      busy = true;
      busyMessage = '선택한 범위를 준비하고 있어요…';
      error = null;
    });
    try {
      final cropped = await compute(cropPhotoRegion, {
        'photo': fullPhoto!,
        'left': selected.left,
        'top': selected.top,
        'right': selected.right,
        'bottom': selected.bottom,
      });
      if (!mounted) return;
      setState(() {
        original = cropped;
        cutouts = null;
        selectedSubject = null;
        result = null;
        cutout = false;
        busy = false;
      });
      await _remove();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '선택한 범위를 처리하지 못했어요. 다시 선택해 주세요.';
        });
      }
    }
  }

  Future<void> _date() async {
    final value = await showDatePicker(
      context: context,
      initialDate: takenOn ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: '사진을 찍은 날짜',
    );
    if (value != null && mounted) setState(() => takenOn = value);
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      tell(context, '스티커 이름을 입력해 주세요.');
      return;
    }
    if (takenOn == null) {
      tell(context, '사진을 찍은 날짜를 선택해 주세요.');
      return;
    }
    if (result == null) {
      tell(context, '자동으로 오려내거나 사진 그대로 사용을 선택해 주세요.');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.addSticker(result!, name.text, takenOn!);
      if (!mounted) return;
      setState(() => canLeave = true);
      tell(context, '내 스티커 보드에 모았어요.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        tell(context, '저장하지 못했어요. 저장 공간을 확인하고 다시 시도해 주세요.');
      }
    }
  }

  Future<void> _leave() async {
    if (busy || saving) {
      tell(context, '진행 중인 작업이 끝나면 나갈 수 있어요.');
      return;
    }
    if (original == null && name.text.isEmpty ||
        await confirm(
          context,
          '스티커 만들기를 나갈까요?',
          '아직 저장하지 않은 사진과 입력 내용이 사라져요.',
          action: '나가기',
        )) {
      if (!mounted) return;
      setState(() => canLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canLeave,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: const Text('새로운 조각 모으기'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const Text(
              '사진 속 좋아하는 것만, 쏙.',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text('사진 선택 → 오려내기 → 이름과 날짜', style: TextStyle(color: muted)),
            const SizedBox(height: 24),
            Container(
              height: 280,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F1E8),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: PaperPattern(checker: true)),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: original == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 46,
                                  color: moss,
                                ),
                                SizedBox(height: 14),
                                Text(
                                  '내 사진을 골라 주세요',
                                  style: TextStyle(color: muted),
                                ),
                              ],
                            )
                          : cutouts != null &&
                                cutouts!.subjects.length > 1 &&
                                result == null
                          ? SubjectPhotoPicker(
                              photo: original!,
                              cutouts: cutouts!,
                              onSelect: busy || saving ? null : _selectSubject,
                            )
                          : Image.memory(
                              result ?? original!,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                  if (busy)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Color(0xCCFAF6ED),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              child: Text(
                                busyMessage,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy || saving
                        ? null
                        : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(original == null ? '사진 선택' : '다른 사진'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: busy || saving
                      ? null
                      : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('촬영'),
                ),
              ],
            ),
            if (original != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: busy || saving ? null : _remove,
                icon: const Icon(Icons.auto_awesome),
                label: Text(cutout ? '다시 자동으로 오려내기' : '자동으로 오려내기'),
              ),
              OutlinedButton.icon(
                onPressed: busy || saving ? null : _chooseRegion,
                icon: const Icon(Icons.crop),
                label: const Text('범위를 선택해서 오려내기'),
              ),
              if (fullPhoto != null && !identical(original, fullPhoto))
                TextButton(
                  onPressed: busy || saving
                      ? null
                      : () => setState(() {
                          original = fullPhoto;
                          result = null;
                          cutouts = null;
                          selectedSubject = null;
                          cutout = false;
                          error = null;
                        }),
                  child: const Text('전체 사진으로 돌아가기'),
                ),
              TextButton(
                onPressed: busy || saving
                    ? null
                    : () => setState(() {
                        result = original;
                        cutouts = null;
                        selectedSubject = null;
                        cutout = false;
                        error = null;
                      }),
                child: const Text('사진 그대로 사용'),
              ),
              Text(
                result == null
                    ? cutouts != null && cutouts!.subjects.length > 1
                          ? '사진의 번호나 아래 대상 카드를 눌러 원하는 것 하나를 골라 주세요.'
                          : '처음에는 배경 제거 모델을 내려받아요. 사진은 기기 안에서 처리해요.'
                    : cutout
                    ? '체크무늬가 보이는 부분은 투명하게 저장돼요. 결과를 확인해 주세요.'
                    : '배경을 포함한 사진 전체가 저장돼요.',
                style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
              if (cutouts != null && cutouts!.subjects.length > 1) ...[
                const SizedBox(height: 18),
                SubjectChoiceStrip(
                  cutouts: cutouts!,
                  selected: selectedSubject,
                  onSelect: busy || saving ? null : _selectSubject,
                ),
              ],
              if (cutouts != null && cutouts!.subjects.length <= 1 && cutout)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '한 묶음을 찾았어요. 원하는 대상이 함께 잡히면 범위를 선택해서 다시 오려내세요.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                  ),
                ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 26),
            TextField(
              controller: name,
              maxLength: 60,
              enabled: !saving && !busy,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '스티커 이름',
                hintText: '예: 오후에 마신 따뜻한 라떼',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.calendar_today_outlined, size: 22),
              title: const Text('사진을 찍은 날짜'),
              subtitle: Text(
                takenOn == null
                    ? '촬영 정보가 없어요. 날짜를 선택해 주세요.'
                    : dateLabel(takenOn!),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: busy || saving ? null : _date,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy || saving || result == null ? null : _save,
              child: Text(saving ? '저장하는 중…' : '내 스티커 보드에 저장'),
            ),
          ],
        ),
      ),
    ),
  );
}

class StickerDetail extends StatefulWidget {
  const StickerDetail({super.key, required this.store, required this.id});
  final DiaryStore store;
  final String id;
  @override
  State<StickerDetail> createState() => _StickerDetailState();
}

class _StickerDetailState extends State<StickerDetail> {
  bool busy = false;
  Future<void> _delete(Sticker s) async {
    if (!await confirm(context, '스티커함에서 삭제할까요?', '이미 일기에 붙인 스티커는 그대로 남아요.')) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.hideSticker(s);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        tell(context, '삭제하지 못했어요. 다시 시도해 주세요.');
      }
    }
  }

  Future<void> _use(Sticker s) async {
    final diary = await showModalBottomSheet<Diary>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('어느 하루에 붙일까요?', style: TextStyle(fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('새 일기 쓰기'),
              onTap: () => Navigator.pop(context, Diary.empty()),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in widget.store.diaries)
                    ListTile(
                      title: Text(dateLabel(d.date)),
                      subtitle: Text(
                        d.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, d.copy()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (diary == null || !mounted) return;
    diary.placements.add(Placement(id: uuid.v4(), stickerId: s.id));
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEditor(
          store: widget.store,
          diary: diary,
          initiallyDirty: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final s = widget.store.sticker(widget.id)!;
      return Scaffold(
        appBar: AppBar(
          title: const Text('내가 모은 조각'),
          actions: [
            IconButton(
              tooltip: '스티커함에서 삭제',
              onPressed: busy ? null : () => _delete(s),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * .4,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: StickerImage(store: widget.store, sticker: s),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                s.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.takenOn == null ? '촬영 날짜 미입력' : '${dateLabel(s.takenOn!)} 촬영',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: busy ? null : () => _use(s),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('일기에 붙이기'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StickerInfoEditor(
                            store: widget.store,
                            sticker: s,
                          ),
                        ),
                      ),
                child: const Text('이름 · 촬영 날짜 수정'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class StickerInfoEditor extends StatefulWidget {
  const StickerInfoEditor({
    super.key,
    required this.store,
    required this.sticker,
  });
  final DiaryStore store;
  final Sticker sticker;
  @override
  State<StickerInfoEditor> createState() => _StickerInfoEditorState();
}

class _StickerInfoEditorState extends State<StickerInfoEditor> {
  late final name = TextEditingController(text: widget.sticker.name);
  late DateTime? takenOn = widget.sticker.takenOn;
  bool busy = false, canLeave = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty || takenOn == null) {
      tell(context, '이름과 촬영 날짜를 입력해 주세요.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.updateSticker(
        widget.sticker.edit(name: name.text.trim(), takenOn: takenOn),
      );
      if (mounted) {
        setState(() => canLeave = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        tell(context, '저장하지 못했어요. 다시 시도해 주세요.');
      }
    }
  }

  Future<void> _leave() async {
    if (busy) return;
    if (name.text == widget.sticker.name && takenOn == widget.sticker.takenOn ||
        await confirm(
          context,
          '수정을 그만할까요?',
          '저장하지 않은 변경 사항이 사라져요.',
          action: '나가기',
        )) {
      if (!mounted) return;
      setState(() => canLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canLeave,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: const Text('조각의 정보'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(
            height: 160,
            child: StickerImage(store: widget.store, sticker: widget.sticker),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            enabled: !busy,
            maxLength: 60,
            decoration: const InputDecoration(labelText: '스티커 이름'),
          ),
          ListTile(
            title: const Text('촬영 날짜'),
            subtitle: Text(takenOn == null ? '날짜 선택' : dateLabel(takenOn!)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: busy
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: takenOn ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && mounted) setState(() => takenOn = date);
                  },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : _save,
            child: Text(busy ? '저장하는 중…' : '저장'),
          ),
        ],
      ),
    ),
  );
}
