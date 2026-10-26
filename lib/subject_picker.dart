import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'photo_service.dart';
import 'widgets.dart';

class SubjectPhotoPicker extends StatelessWidget {
  const SubjectPhotoPicker({
    super.key,
    required this.photo,
    required this.cutouts,
    required this.onSelect,
  });
  final Uint8List photo;
  final CutoutResult cutouts;
  final ValueChanged<int>? onSelect;
  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: cutouts.aspectRatio,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Positioned.fill(child: Image.memory(photo, fit: BoxFit.fill)),
            for (var i = 0; i < cutouts.subjects.length; i++)
              Positioned(
                left: cutouts.subjects[i].bounds.left * box.maxWidth,
                top: cutouts.subjects[i].bounds.top * box.maxHeight,
                width: cutouts.subjects[i].bounds.width * box.maxWidth,
                height: cutouts.subjects[i].bounds.height * box.maxHeight,
                child: Semantics(
                  button: true,
                  label: '사진에서 대상 ${i + 1} 선택',
                  child: GestureDetector(
                    onTap: onSelect == null ? null : () => onSelect!(i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: moss, width: 2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        color: moss,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class SubjectChoiceStrip extends StatelessWidget {
  const SubjectChoiceStrip({
    super.key,
    required this.cutouts,
    required this.selected,
    required this.onSelect,
  });
  final CutoutResult cutouts;
  final int? selected;
  final ValueChanged<int>? onSelect;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '찾은 대상 ${cutouts.subjects.length}개 · 하나를 골라 주세요',
        style: const TextStyle(color: ink, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cutouts.subjects.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) => Semantics(
            button: true,
            selected: selected == i,
            label: '대상 ${i + 1} 선택',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('subject-choice-$i'),
                borderRadius: BorderRadius.circular(12),
                onTap: onSelect == null ? null : () => onSelect!(i),
                child: Container(
                  width: 88,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected == i ? moss : const Color(0xFFDCD5C5),
                      width: selected == i ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: selected == i ? const Color(0xFFE7EBDD) : null,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.memory(
                          cutouts.subjects[i].png,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '대상 ${i + 1}${selected == i ? ' ✓' : ''}',
                        style: const TextStyle(fontSize: 12, color: ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '선택한 대상만 저장돼요. 서로 붙어 있는 대상은 한 묶음으로 인식될 수 있어요.',
        style: TextStyle(color: muted, fontSize: 12, height: 1.5),
      ),
    ],
  );
}
