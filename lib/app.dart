import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/vip_provider.dart';
import 'core/theme.dart';
import 'features/login/login_page.dart';
import 'features/meeting/meeting_page.dart';
import 'features/meeting/meeting_provider.dart';
import 'features/after_meet/after_meet_page.dart';
import 'features/history/history_page.dart';
import 'features/history/history_provider.dart';
import 'features/settings/settings_page.dart';

class NivoApp extends StatelessWidget {
  final AuthService authService;
  final ApiService apiService;

  const NivoApp({
    super.key,
    required this.authService,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nivo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _AuthGate(
        authService: authService,
        apiService: apiService,
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;

  const _AuthGate({required this.authService, required this.apiService});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.authService.isLoggedIn) {
      return _MainShell(
        authService: widget.authService,
        apiService: widget.apiService,
      );
    }
    return LoginPage(
      onLoginSuccess: () {
        final session = widget.authService.currentSession;
        if (session != null) {
          widget.apiService.updateToken(session.accessToken);
        }
        final user = widget.authService.currentUser;
        if (user != null) {
          context.read<HistoryProvider>().init(
                apiService: widget.apiService,
                userId: user.id,
              );
          context.read<MeetingProvider>().setUserId(user.id);
          context.read<VipProvider>().fetchVipStatus(user.id);
        }
        setState(() {});
      },
    );
  }
}

class _MainShell extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;

  const _MainShell({
    required this.authService,
    required this.apiService,
  });

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final MeetingProvider _meetingProvider;

  @override
  void initState() {
    super.initState();
    _meetingProvider = context.read<MeetingProvider>();
    WidgetsBinding.instance.addObserver(this);
    final user = widget.authService.currentUser;
    if (user != null) {
      context.read<HistoryProvider>().init(
            apiService: widget.apiService,
            userId: user.id,
          );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioRecorder().hasPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _meetingProvider.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _meetingProvider.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      MeetingPage(),
      AfterMeetPage(),
      HistoryPage(),
      SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: '实时会议',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_rounded),
            selectedIcon: Icon(Icons.edit_note_rounded),
            label: '会后整理',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: '历史',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
