import 'dart:io';

import 'package:flutter/services.dart';

class LiveActivityService {
  static const _channel = MethodChannel('com.nivo/live_activity');

  /// 启动 Live Activity
  Future<bool> start({required String meetingId, int elapsedSeconds = 0}) async {
    if (!Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod('start', {
        'meetingId': meetingId,
        'elapsedSeconds': elapsedSeconds,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// 更新状态（暂停/恢复）
  Future<void> update({required bool isPaused, required int elapsedSeconds}) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('update', {
        'isPaused': isPaused,
        'elapsedSeconds': elapsedSeconds,
      });
    } catch (_) {}
  }

  /// 结束 Live Activity
  Future<void> end() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('end');
    } catch (_) {}
  }

  /// 检查是否支持
  Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod('isSupported');
      return result == true;
    } catch (_) {
      return false;
    }
  }
}
