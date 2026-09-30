import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import 'alarm_service.dart';
import 'sounds.dart';

class RingPage extends StatelessWidget {
  final AlarmSettings alarm;
  const RingPage({super.key, required this.alarm});

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay.fromDateTime(alarm.dateTime).format(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text('HERÄÄ!',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                Text(t, style: const TextStyle(fontSize: 72)),
                Text(soundFromAsset(alarm.assetAudioPath).name,
                    style: const TextStyle(fontSize: 18)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.all(24)),
                    onPressed: () async {
                      await AlarmService.snooze(alarm);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Torkku 5 min', style: TextStyle(fontSize: 22)),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(28),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                    ),
                    onPressed: () async {
                      await AlarmService.stopRinging(alarm);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('PYSÄYTÄ',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
