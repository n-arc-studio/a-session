import 'package:flutter/material.dart';

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
      home: const HomeScreen(),
    );
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