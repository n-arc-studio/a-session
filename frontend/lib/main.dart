import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/forgot_password_screen.dart';

void main() {
  runApp(const ASessionApp());
}

class ASessionApp extends StatelessWidget {
  const ASessionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A-Session',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/otp-verification': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return OtpVerificationScreen(
            email: args?['email'] ?? '',
            purpose: args?['purpose'] ?? 'verify',
            onSuccess: () => Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            ),
          );
        },
        '/reset-password': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return PasswordResetScreen(
            email: args?['email'] ?? '',
            code: args?['code'] ?? '',
          );
        },
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _authService.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _authService.isLoggedIn
        ? const HomeScreen()
        : const LoginScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    SheetMusicScreen(),
    AudioPlaybackScreen(),
    MemberManagementScreen(),
    ScheduleScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A-Session'),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: '楽譜',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_arrow),
            label: '再生',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'メンバー',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'スケジュール',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class SheetMusicScreen extends StatelessWidget {
  const SheetMusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('楽譜一覧画面'),
    );
  }
}

class AudioPlaybackScreen extends StatelessWidget {
  const AudioPlaybackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('音源再生画面'),
    );
  }
}

class MemberManagementScreen extends StatelessWidget {
  const MemberManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('メンバー管理画面'),
    );
  }
}

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('スケジュール画面'),
    );
  }
}