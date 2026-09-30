import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sounds.dart';

const _dailyKey = 'daily_alarm_ids';
const _randomKey = 'random_alarm_ids';

class AlarmService {
  static Future<Set<int>> _loadIds(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? []).map(int.parse).toSet();
  }

  static Future<void> _saveIds(String key, Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids.map((e) => '$e').toList());
  }

  static Future<Set<int>> dailyIds() => _loadIds(_dailyKey);

  /// Herätykset, joiden ääni arvotaan uudelleen joka kerta kun ne ajastetaan.
  static Future<Set<int>> randomIds() => _loadIds(_randomKey);

  static Future<void> _addTo(String key, int id) async {
    final ids = await _loadIds(key);
    ids.add(id);
    await _saveIds(key, ids);
  }

  static Future<void> _removeFrom(String key, int id) async {
    final ids = await _loadIds(key);
    if (ids.remove(id)) await _saveIds(key, ids);
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
    bool randomSound = false,
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
        // Satunnaisäänen nimeä ei paljasteta etukäteen.
        body: randomSound ? 'Herää! 🎲' : 'Herää! ${sound.name}',
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
    final isRandom = soundId == randomSoundId;
    final sound = isRandom ? pickRandomSound() : soundById(soundId);
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await Alarm.set(
      alarmSettings: build(
        id: id,
        time: nextOccurrence(hour, minute),
        sound: sound,
        randomSound: isRandom,
        label: label,
      ),
    );
    if (daily) await _addTo(_dailyKey, id);
    if (isRandom) await _addTo(_randomKey, id);
  }

  static Future<void> delete(int id) async {
    await Alarm.stop(id);
    await _removeFrom(_dailyKey, id);
    await _removeFrom(_randomKey, id);
  }

  /// Uusi versio herätyksestä: satunnaisherätykselle arvotaan uusi ääni.
  static Future<AlarmSettings> _reroll(AlarmSettings alarm, DateTime when,
      {int? newId}) async {
    final isRandom = (await randomIds()).contains(alarm.id);
    if (!isRandom) return alarm.copyWith(id: newId, dateTime: when);
    final sound = pickRandomSound(except: soundFromAsset(alarm.assetAudioPath));
    return build(
      id: newId ?? alarm.id,
      time: when,
      sound: sound,
      randomSound: true,
      label: alarm.notificationSettings.title,
    );
  }

  /// Pysäyttää soivan hälytyksen; päivittäinen ajastetaan uudelleen huomiseksi
  /// (satunnaisella uudella äänellä, jos ääni on arvottu).
  static Future<void> stopRinging(AlarmSettings alarm) async {
    await Alarm.stop(alarm.id);
    if ((await dailyIds()).contains(alarm.id)) {
      await Alarm.set(
        alarmSettings: await _reroll(
          alarm,
          alarm.dateTime.add(const Duration(days: 1)),
        ),
      );
    } else {
      await _removeFrom(_randomKey, alarm.id);
    }
  }

  static Future<void> snooze(AlarmSettings alarm, {int minutes = 5}) async {
    final wasRandom = (await randomIds()).contains(alarm.id);
    final snoozed = await _reroll(
      alarm,
      DateTime.now().add(Duration(minutes: minutes)),
      newId: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await stopRinging(alarm);
    await Alarm.set(alarmSettings: snoozed);
    if (wasRandom) await _addTo(_randomKey, snoozed.id);
  }
}
