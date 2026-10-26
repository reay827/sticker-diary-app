import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';
import 'sticker_screens.dart';
import 'diary_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final DiaryStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  Future<void> _newSticker() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => StickerForm(store: widget.store)));
  void _newDiary() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DiaryEditor(store: widget.store, diary: Diary.empty()),
    ),
  );
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPhoto());
    }
    if (widget.store.recoveredFromBackup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) tell(context, '최근 저장 파일에 문제가 있어 이전 기록으로 복구했어요.');
      });
    }
  }

  Future<void> _recoverPhoto() async {
    try {
      final result = await ImagePicker().retrieveLostData();
      if (!mounted || result.isEmpty) return;
      if (result.files?.isNotEmpty ?? false) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StickerForm(
              store: widget.store,
              recovered: result.files!.first,
            ),
          ),
        );
      } else {
        tell(context, '이전에 선택한 사진을 복원하지 못했어요. 사진을 다시 선택해 주세요.');
      }
    } catch (_) {
      if (mounted) tell(context, '사진 복원을 완료하지 못했어요. 사진을 다시 선택해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text(
          '하루 조각',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            tooltip: '앱 안내',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('내 일상의 작은 수집'),
                content: Text(
                  '사진 속 물건을 모아 나만의 일기를 꾸며보세요.\n\n사진과 기록은 이 기기에 저장돼요. 사진을 배경 제거 서버로 보내지 않아요.\n\n현재 테스트 버전으로, 백업 기능은 아직 없어요. 앱을 삭제하면 기록도 사라질 수 있어요.',
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab == 0 ? '오늘은 어떤 조각을 모았나요?' : '작은 조각들이 하루가 되는 곳',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tab == 0
                      ? '내 스티커 ${widget.store.stickers.length}개 · 밀어서 구경하고, 눌러서 자세히'
                      : '나의 일기 ${widget.store.diaries.length}편',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: tab == 0
                ? StickerBoard(store: widget.store, onAdd: _newSticker)
                : _DiaryList(store: widget.store, onAdd: _newDiary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: moss,
        foregroundColor: Colors.white,
        onPressed: tab == 0 ? _newSticker : _newDiary,
        icon: const Icon(Icons.add),
        label: Text(tab == 0 ? '사진으로 스티커' : '새 일기'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.scatter_plot_outlined),
            label: '내 스티커',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: '일기장',
          ),
        ],
      ),
    ),
  );
}

class StickerBoard extends StatefulWidget {
  const StickerBoard({super.key, required this.store, required this.onAdd});
  final DiaryStore store;
  final VoidCallback onAdd;
  @override
  State<StickerBoard> createState() => _StickerBoardState();
}

class _StickerBoardState extends State<StickerBoard> {
  final transform = TransformationController();
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stickers = widget.store.stickers;
    if (stickers.isEmpty) {
      return CustomPaint(
        painter: const PaperPattern(),
        child: EmptyNote(
          icon: Icons.auto_awesome_outlined,
          title: '내 사진이 스티커가 되는 곳',
          message: '좋아하는 컵, 오늘 먹은 디저트, 작은 물건들.\n사진 속 조각을 하나씩 모아보세요.',
          button: FilledButton.icon(
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('첫 스티커 만들기'),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final columns = math.max(3, (c.maxWidth / 150).floor());
        final width = math.max(c.maxWidth, columns * 155.0 + 40);
        final height = math.max(
          c.maxHeight,
          ((stickers.length / columns).ceil()) * 185.0 + 100,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: transform,
                constrained: false,
                minScale: .5,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(60),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: CustomPaint(
                    painter: const PaperPattern(),
                    child: Stack(
                      children: [
                        for (var i = 0; i < stickers.length; i++)
                          Positioned(
                            left:
                                24 +
                                (i % columns) * 155.0 +
                                (i.isEven ? 0 : 10),
                            top: 24 + (i ~/ columns) * 185.0 + (i % 3) * 9,
                            width: 130,
                            height: 150,
                            child: Semantics(
                              button: true,
                              label: stickers[i].name,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StickerDetail(
                                      store: widget.store,
                                      id: stickers[i].id,
                                    ),
                                  ),
                                ),
                                child: Transform.rotate(
                                  angle: ((i % 5) - 2) * .055,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: StickerImage(
                                          store: widget.store,
                                          sticker: stickers[i],
                                        ),
                                      ),
                                      const SizedBox(height: 9),
                                      Text(
                                        stickers[i].name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: IconButton.filledTonal(
                tooltip: '보드 처음 위치로',
                onPressed: () => transform.value = Matrix4.identity(),
                icon: const Icon(Icons.center_focus_strong, size: 20),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiaryList extends StatelessWidget {
  const _DiaryList({required this.store, required this.onAdd});
  final DiaryStore store;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => store.diaries.isEmpty
      ? EmptyNote(
          icon: Icons.edit_note_outlined,
          title: '첫 번째 하루를 남겨보세요',
          message: '글 몇 줄과 내가 모은 스티커면 충분해요.',
          button: FilledButton(onPressed: onAdd, child: const Text('일기 쓰기')),
        )
      : ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          itemCount: store.diaries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = store.diaries[i];
            return Card(
              elevation: 0,
              color: const Color(0xFFF0EBDD),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                leading: SizedBox(
                  width: 45,
                  child: d.placements.isEmpty
                      ? const Icon(Icons.menu_book_outlined, color: moss)
                      : StickerImage(
                          store: store,
                          sticker: store.sticker(d.placements.first.stickerId),
                        ),
                ),
                title: Text(
                  dateLabel(d.date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    d.body.isEmpty ? '스티커로 남긴 하루' : d.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DiaryView(store: store, id: d.id),
                  ),
                ),
              ),
            );
          },
        );
}
