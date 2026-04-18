import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivo_app/features/settings/settings_provider.dart';
import 'package:nivo_app/core/constants.dart';

void main() {
  group('SettingsProvider', () {
    test('defaults to auto ASR mode', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.init();
      expect(provider.asrMode, AsrMode.auto);
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

    test('setAsrModelId persists and updates', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.init();

      await provider.setAsrModelId('sherpa-v2');
      expect(provider.asrModelId, 'sherpa-v2');
    });

    test('init round-trip: set values, create new provider, init, verify loaded',
        () async {
      SharedPreferences.setMockInitialValues({});

      // First provider: set values
      final p1 = SettingsProvider();
      await p1.init();
      await p1.setAsrMode(AsrMode.local);
      await p1.setCloudApiBaseUrl('https://round-trip.test');
      await p1.setAsrModelId('model-42');

      // Second provider: should load persisted values
      final p2 = SettingsProvider();
      await p2.init();
      expect(p2.asrMode, AsrMode.local);
      expect(p2.cloudApiBaseUrl, 'https://round-trip.test');
      expect(p2.asrModelId, 'model-42');
    });
  });
}
