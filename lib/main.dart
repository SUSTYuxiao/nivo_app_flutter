import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/audio_service.dart';
import 'core/services/vip_provider.dart';
import 'core/services/duration_service.dart';
import 'core/services/oss_service.dart';
import 'core/services/transcription_service.dart';
import 'core/services/fluid_audio_service.dart';
import 'core/services/live_activity_service.dart';
import 'core/services/asr/cloud_asr.dart';
import 'core/services/asr/sherpa_asr.dart';
import 'core/services/asr/asr_router.dart';
import 'features/login/login_provider.dart';
import 'features/meeting/meeting_provider.dart';
import 'features/history/history_provider.dart';
import 'features/after_meet/after_meet_provider.dart';
import 'features/settings/settings_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  final authService = AuthService();
  final apiService = ApiService(
    token: Supabase.instance.client.auth.currentSession?.accessToken,
  );
  final audioService = AudioService();
  final cloudAsr = CloudAsr();
  final sherpaAsr = SherpaAsr();
  await sherpaAsr.init();
  settingsProvider.setSherpaAsr(sherpaAsr);
  final asrRouter = AsrRouter(
    cloud: cloudAsr,
    sherpa: sherpaAsr,
    mode: settingsProvider.asrMode,
    useNivoTranscription: settingsProvider.useNivoTranscription,
  );
  settingsProvider.setAsrRouter(asrRouter);

  final durationService = DurationService(apiService: apiService);

  final ossService = OssService(apiService: apiService);
  final transcriptionService = TranscriptionService(
    apiService: apiService,
    ossService: ossService,
  );

  final fluidAudioService = FluidAudioService();
  settingsProvider.setFluidAudioService(fluidAudioService);

  final vipProvider = VipProvider()..init(apiService);

  final loginProvider = LoginProvider()..setAuthService(authService);

  final historyProvider = HistoryProvider();
  final user = authService.currentUser;
  if (user != null) {
    historyProvider.init(apiService: apiService, userId: user.id);
    vipProvider.fetchVipStatus(user.id);
  }

  final liveActivityService = LiveActivityService();

  final meetingProvider = MeetingProvider()
    ..init(
      audioService: audioService,
      asrRouter: asrRouter,
      apiService: apiService,
      durationService: durationService,
      transcriptionService: transcriptionService,
      settingsProvider: settingsProvider,
      historyProvider: historyProvider,
      liveActivityService: liveActivityService,
    );

  if (user != null) {
    meetingProvider.setUserId(user.id);
  }

  final afterMeetProvider = AfterMeetProvider()
    ..init(
      apiService: apiService,
      transcriptionService: transcriptionService,
      fluidAudioService: fluidAudioService,
      settingsProvider: settingsProvider,
      historyProvider: historyProvider,
    );

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<AudioService>.value(value: audioService),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: vipProvider),
        ChangeNotifierProvider.value(value: loginProvider),
        ChangeNotifierProvider.value(value: meetingProvider),
        ChangeNotifierProvider.value(value: historyProvider),
        ChangeNotifierProvider.value(value: afterMeetProvider),
      ],
      child: NivoApp(
        authService: authService,
        apiService: apiService,
      ),
    ),
  );
}
