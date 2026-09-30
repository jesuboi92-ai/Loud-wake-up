import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'ring_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  runApp(const LoudWakeUpApp());
}

class LoudWakeUpApp extends StatefulWidget {
  const LoudWakeUpApp({super.key});

  @override
  State<LoudWakeUpApp> createState() => _LoudWakeUpAppState();
}

class _LoudWakeUpAppState extends State<LoudWakeUpApp> {
  StreamSubscription<AlarmSet>? _sub;
  bool _ringPageOpen = false;

  @override
  void initState() {
    super.initState();
    _sub = Alarm.ringing.listen(_onRing);
  }

  Future<void> _onRing(AlarmSet set) async {
    if (set.alarms.isEmpty || _ringPageOpen) return;
    _ringPageOpen = true;
    await navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => RingPage(alarm: set.alarms.first)),
    );
    _ringPageOpen = false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loud Wake Up',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
