import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class DiaryEditor extends StatefulWidget {
  const DiaryEditor({
    super.key,
    required this.store,
    required this.diary,
    this.initiallyDirty = false,
  });
  final DiaryStore store;
  final Diary diary;
  final bool initiallyDirty;
  @override
  State<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<DiaryEditor> {
  late final Diary draft = widget.diary.copy();
  late final body = TextEditingController(text: draft.body);
  late bool dirty = widget.initiallyDirty;
  bool typing = false, saving = false, canLeave = false;
  String? selected;
  Placement? get active {
    for (final p in draft.placements) {
      if (p.id == selected) return p;
    }
    return null;
  }

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  void _select(String id) => setState(() {
    selected = id;
    final index = draft.placements.indexWhere((p) => p.id == id);
    if (index != draft.placements.length - 1) {
      draft.placements.add(draft.placements.removeAt(index));
      dirty = true;
    }
  });
  Future<void> _add() async {
    if (widget.store.stickers.isEmpty) {
      tell(context, '먼저 내 스티커 화면에서 사진으로 스티커를 만들어 주세요.');
      return;
    }
    final s = await showModalBottomSheet<Sticker>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('하루에 붙일 조각 고르기', style: TextStyle(fontSize: 20)),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: widget.store.stickers.length,
                itemBuilder: (context, i) {
                  final s = widget.store.stickers[i];
                  return Semantics(
                    button: true,
                    label: s.name,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, s),
                      child: Column(
                        children: [
                          Expanded(
                            child: StickerImage(
                              store: widget.store,
                              sticker: s,
                            ),
                          ),
                          Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (s != null && mounted) {
      setState(() {
        final p = Placement(id: uuid.v4(), stickerId: s.id);
        draft.placements.add(p);
        selected = p.id;
        dirty = true;
        typing = false;
        FocusScope.of(context).unfocus();
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    draft.body = body.text;
    if (draft.body.trim().isEmpty && draft.placements.isEmpty) {
      tell(context, '글이나 스티커로 오늘의 조각을 남겨 주세요.');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.saveDiary(draft);
      if (!mounted) return;
      setState(() {
        canLeave = true;
        dirty = false;
      });
      tell(context, '오늘의 조각을 저장했어요.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        tell(context, '일기를 저장하지 못했어요. 저장 공간을 확인하고 다시 시도해 주세요.');
      }
    }
  }

  Future<void> _leave() async {
    if (saving) return;
    if (!dirty ||
        await confirm(
          context,
          '일기 작성을 나갈까요?',
          '저장하지 않은 내용과 스티커 배치가 사라져요.',
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
        title: const Text('하루 남기기'),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: Text(saving ? '저장 중…' : '저장'),
          ),
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: saving,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(dateLabel(draft.date)),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: draft.date,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100),
                        );
                        if (date != null && mounted) {
                          setState(() {
                            draft.date = date;
                            dirty = true;
                          });
                        }
                      },
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        typing = !typing;
                        selected = null;
                        if (!typing) FocusScope.of(context).unfocus();
                      }),
                      icon: Icon(
                        typing ? Icons.check : Icons.edit_outlined,
                        size: 18,
                      ),
                      label: Text(typing ? '글 입력 완료' : '글 쓰기'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 550),
                      child: DiaryPage(
                        store: widget.store,
                        diary: draft,
                        selected: typing ? null : selected,
                        onSelect: typing ? null : _select,
                        onMove: typing
                            ? null
                            : (id, delta) => setState(() {
                                active?.move(delta.dx, delta.dy);
                                dirty = true;
                              }),
                        onBlank: () => setState(() => selected = null),
                        child: typing
                            ? TextField(
                                controller: body,
                                maxLines: null,
                                expands: true,
                                maxLength: 1500,
                                textAlignVertical: TextAlignVertical.top,
                                autofocus: true,
                                onChanged: (value) => setState(() {
                                  draft.body = value;
                                  dirty = true;
                                }),
                                style: TextStyle(
                                  fontSize:
                                      math.min(
                                        MediaQuery.sizeOf(context).width - 36,
                                        550,
                                      ) *
                                      .043,
                                  height: 1.9,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '오늘의 작은 순간을 적어보세요…',
                                  filled: false,
                                  counterText: '',
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              if (active != null && !typing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 40,
                            child: Text('크기', style: TextStyle(color: muted)),
                          ),
                          Expanded(
                            child: Slider(
                              value: active!.width,
                              min: .12,
                              max: .65,
                              onChanged: (v) => setState(() {
                                active!.resize(v);
                                dirty = true;
                              }),
                            ),
                          ),
                          IconButton(
                            tooltip: '선택 스티커 삭제',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() {
                              draft.placements.removeWhere(
                                (p) => p.id == selected,
                              );
                              selected = null;
                              dirty = true;
                            }),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 40,
                            child: Text('회전', style: TextStyle(color: muted)),
                          ),
                          Expanded(
                            child: Slider(
                              value: active!.angle,
                              min: 0,
                              max: math.pi * 2,
                              onChanged: (v) => setState(() {
                                active!.rotate(v);
                                dirty = true;
                              }),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('스티커 붙이기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        typing
                            ? '글 입력 중에는 스티커가 움직이지 않아요.'
                            : '스티커를 눌러 선택하고 끌어보세요.',
                        style: const TextStyle(fontSize: 11, color: muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DiaryView extends StatefulWidget {
  const DiaryView({super.key, required this.store, required this.id});
  final DiaryStore store;
  final String id;
  @override
  State<DiaryView> createState() => _DiaryViewState();
}

class _DiaryViewState extends State<DiaryView> {
  bool busy = false;
  Future<void> _delete() async {
    if (!await confirm(
      context,
      '이 일기를 삭제할까요?',
      '삭제한 일기는 되돌릴 수 없어요. 스티커함의 스티커는 남아요.',
    )) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.deleteDiary(widget.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        tell(context, '삭제하지 못했어요. 다시 시도해 주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final matches = widget.store.diaries.where((d) => d.id == widget.id);
      final diary = matches.isEmpty ? null : matches.first;
      return Scaffold(
        appBar: AppBar(
          title: const Text('나의 하루'),
          actions: [
            IconButton(
              tooltip: '일기 삭제',
              onPressed: busy || diary == null ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: diary == null
            ? const SizedBox.shrink()
            : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: DiaryPage(store: widget.store, diary: diary),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DiaryEditor(
                                      store: widget.store,
                                      diary: diary,
                                    ),
                                  ),
                                ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('이 하루 수정하기'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      );
    },
  );
}
