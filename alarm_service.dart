import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sounds.dart';

const _dailyKey = 'daily_alarm_ids';

class AlarmService {
  static Future<Set<int>> dailyIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_dailyKey) ?? []).map(int.parse).toSet();
  }

  static Future<void> _saveDaily(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dailyKey, ids.map((e) => '$e').toList());
  }

  static DateTime nextOccurrence(int hour, int minute) {
    final now = DateTime.now();
    var dt = DateTime(now.year, now.month, now.day, hour, minute);
    if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
    return dt;
  }

  static AlarmSettings build({
    required int id,
    required DateTime time,
    required AlarmSound sound,
    String label = 'Herätys',
  }) {
    return AlarmSettings(
      id: id,
      dateTime: time,
      assetAudioPath: sound.asset,
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: true,
      volumeSettings: VolumeSettings.fixed(volume: 1.0, volumeEnforced: true),
      notificationSettings: NotificationSettings(
        title: label,
        body: 'Herää! ${sound.name}',
        stopButton: 'Pysäytä',
      ),
    );
  }

  static Future<void> create({
    required int hour,
    required int minute,
    required String soundId,
    required bool daily,
    String label = 'Herätys',
  }) async {
    final sound = soundId == randomSoundId ? pickRandomSound() : soundById(soundId);
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await Alarm.set(
      alarmSettings: build(
        id: id,
        time: nextOccurrence(hour, minute),
        sound: sound,
        label: label,
      ),
    );
    if (daily) {
      final ids = await dailyIds();
      ids.add(id);
      await _saveDaily(ids);
    }
  }

  static Future<void> delete(int id) async {
    await Alarm.stop(id);
    final ids = await dailyIds();
    if (ids.remove(id)) await _saveDaily(ids);
  }

  /// Pysäyttää soivan hälytyksen; päivittäinen ajastetaan uudelleen huomiseksi.
  static Future<void> stopRinging(AlarmSettings alarm) async {
    await Alarm.stop(alarm.id);
    final ids = await dailyIds();
    if (ids.contains(alarm.id)) {
      await Alarm.set(
        alarmSettings: alarm.copyWith(
          dateTime: alarm.dateTime.add(const Duration(days: 1)),
        ),
      );
    }
  }

  static Future<void> snooze(AlarmSettings alarm, {int minutes = 5}) async {
    await stopRinging(alarm);
    await Alarm.set(
      alarmSettings: alarm.copyWith(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        dateTime: DateTime.now().add(Duration(minutes: minutes)),
      ),
    );
  }
}
