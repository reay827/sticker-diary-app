import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_diary/subject_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('haru/subject_model');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('already downloaded model does not request polling', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
    await const SubjectModelLoader().ensureReady();
    expect(calls, ['ensureReady']);
  });
  test('queued download must wait for actual model availability', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return calls.length >= 3;
    });
    final progress = <String>[];
    await const SubjectModelLoader(
      pollInterval: Duration.zero,
    ).ensureReady(onProgress: progress.add);
    expect(calls, ['ensureReady', 'isReady', 'isReady']);
    expect(progress.last, contains('모델을 준비'));
  });
  test(
    'unavailable model stops with actionable message rather than processing image',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      await expectLater(
        const SubjectModelLoader(
          pollInterval: Duration.zero,
          maxChecks: 2,
        ).ensureReady(),
        throwsA(
          isA<CutoutException>().having(
            (e) => e.message,
            'message',
            contains('아직 준비되지'),
          ),
        ),
      );
    },
  );
  test(
    'download failure is distinguished from image processing failure',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(
          code: 'MODEL_DOWNLOAD_FAILED',
          message: 'unavailable',
        ),
      );
      await expectLater(
        const SubjectModelLoader().ensureReady(),
        throwsA(
          isA<CutoutException>().having(
            (e) => e.message,
            'message',
            contains('모델을 준비하지 못'),
          ),
        ),
      );
    },
  );
}
