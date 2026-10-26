import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CutoutException implements Exception {
  const CutoutException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SubjectModelLoader {
  const SubjectModelLoader({
    this.channel = const MethodChannel('haru/subject_model'),
    this.pollInterval = const Duration(seconds: 1),
    this.maxChecks = 120,
    this.timeout = const Duration(minutes: 2),
  });
  final MethodChannel channel;
  final Duration pollInterval, timeout;
  final int maxChecks;

  Future<void> ensureReady({ValueChanged<String>? onProgress}) async {
    final clock = Stopwatch()..start();
    Future<bool> invoke(String method) async {
      final remaining = timeout - clock.elapsed;
      if (remaining <= Duration.zero) throw TimeoutException('model');
      return await channel.invokeMethod<bool>(method).timeout(remaining) ??
          false;
    }

    try {
      onProgress?.call('배경 제거 모델을 확인하고 있어요…');
      if (await invoke('ensureReady')) return;
      onProgress?.call('처음 사용할 모델을 준비하고 있어요.\n인터넷에 연결한 채 잠시 기다려 주세요.');
      for (var i = 0; i < maxChecks; i++) {
        if (clock.elapsed + pollInterval >= timeout) break;
        await Future<void>.delayed(pollInterval);
        if (await invoke('isReady')) return;
      }
      throw const CutoutException(
        '배경 제거 모델이 아직 준비되지 않았어요. 인터넷 연결과 Google Play 서비스를 확인한 뒤 다시 시도해 주세요.',
      );
    } on TimeoutException {
      throw const CutoutException('모델 준비 시간이 길어지고 있어요. 잠시 후 다시 시도해 주세요.');
    } on PlatformException catch (error) {
      debugPrint('Subject model preparation: ${error.code}: ${error.message}');
      throw const CutoutException(
        '이 기기에서 배경 제거 모델을 준비하지 못했어요. 인터넷 연결과 Google Play 서비스를 확인해 주세요. 가상폰에서 계속 실패하면 실제 안드로이드폰에서 확인이 필요해요.',
      );
    } on MissingPluginException {
      throw const CutoutException('모델 준비 기능을 사용하려면 최신 앱으로 업데이트해 주세요.');
    } finally {
      clock.stop();
    }
  }
}
