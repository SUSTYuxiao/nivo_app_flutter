import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivo_app/features/settings/settings_provider.dart';
import 'package:nivo_app/core/constants.dart';

void main() {
  group('SettingsProvider', () {
    test('defaults to cloud ASR mode', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.init();
      expect(provider.asrMode, AsrMode.cloud);
    });

    test('persists ASR mode change', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.init();
      await provider.setAsrMode(AsrMode.local);
      expect(provider.asrMode, AsrMode.local);
    });

    test('persists cloud API base URL', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.init();
      await provider.setCloudApiBaseUrl('https://custom.api.com');
      expect(provider.cloudApiBaseUrl, 'https://custom.api.com');
    });
  });
}
