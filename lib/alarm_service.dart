import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sequence.dart';
import 'sounds.dart';

const _dailyKey = 'daily_alarm_ids';
const _randomKey = 'random_alarm_ids';
const _seqKey = 'sequence_specs'; // "<alarmId>|<json>"

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

  // --- äänisarjat ---------------------------------------------------------

  static Future<Map<int, SequenceSpec>> sequences() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <int, SequenceSpec>{};
    for (final s in prefs.getStringList(_seqKey) ?? <String>[]) {
      final i = s.indexOf('|');
      out[int.parse(s.substring(0, i))] = SequenceSpec.decode(s.substring(i + 1));
    }
    return out;
  }

  static Future<void> _saveSequence(int id, SequenceSpec? spec) async {
    final all = await sequences();
    if (spec == null) {
      all.remove(id);
    } else {
      all[id] = spec;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _seqKey,
      [for (final e in all.entries) '${e.key}|${e.value.encode()}'],
    );
  }

  /// Näytettävä nimi herätyksen äänelle.
  static Future<String> soundLabel(AlarmSettings a) async {
    final seq = (await sequences())[a.id];
    if (seq != null) return '🎼 ${seq.label}';
    if ((await randomIds()).contains(a.id)) return '🎲 Satunnainen ääni';
    return soundFromAsset(a.assetAudioPath).name;
  }

  // --- ajastus ------------------------------------------------------------

  static DateTime nextOccurrence(int hour, int minute) {
    final now = DateTime.now();
    var dt = DateTime(now.year, now.month, now.day, hour, minute);
    if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
    return dt;
  }

  static AlarmSettings build({
    required int id,
    required DateTime time,
    required String audioPath,
    required String body,
    String label = 'Herätys',
  }) {
    return AlarmSettings(
      id: id,
      dateTime: time,
      assetAudioPath: audioPath,
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: true,
      volumeSettings: VolumeSettings.fixed(volume: 1.0, volumeEnforced: true),
      notificationSettings: NotificationSettings(
        title: label,
        body: body,
        stopButton: 'Pysäytä',
      ),
    );
  }

  static Future<void> create({
    required int hour,
    required int minute,
    required String soundId,
    required bool daily,
    SequenceSpec? sequence,
    String label = 'Herätys',
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final time = nextOccurrence(hour, minute);
    late AlarmSettings settings;

    if (sequence != null) {
      final rendered = await SequenceBuilder.render(id, sequence);
      await _saveSequence(id, rendered);
      settings = build(
        id: id,
        time: time,
        audioPath: SequenceBuilder.relPath(id),
        body: 'Herää! 🎼',
        label: label,
      );
    } else {
      final isRandom = soundId == randomSoundId;
      final sound = isRandom ? pickRandomSound() : soundById(soundId);
      settings = build(
        id: id,
        time: time,
        audioPath: sound.alarmPath,
        // Satunnaisäänen nimeä ei paljasteta etukäteen.
        body: isRandom ? 'Herää! 🎲' : 'Herää! ${sound.name}',
        label: label,
      );
      if (isRandom) await _addTo(_randomKey, id);
    }

    await Alarm.set(alarmSettings: settings);
    if (daily) await _addTo(_dailyKey, id);
  }

  static Future<void> delete(int id) async {
    await Alarm.stop(id);
    await _removeFrom(_dailyKey, id);
    await _removeFrom(_randomKey, id);
    if ((await sequences()).containsKey(id)) {
      await _saveSequence(id, null);
      await SequenceBuilder.delete(id);
    }
  }

  /// Uusi versio herätyksestä: satunnaiselle äänelle/sarjalle arvotaan uusi sisältö.
  static Future<AlarmSettings> _reroll(AlarmSettings alarm, DateTime when,
      {int? newId}) async {
    final id = newId ?? alarm.id;

    final seq = (await sequences())[alarm.id];
    if (seq != null) {
      final rendered = await SequenceBuilder.render(id, seq);
      if (newId != null) await _saveSequence(newId, rendered);
      if (newId == null) await _saveSequence(alarm.id, rendered);
      return alarm.copyWith(
        id: id,
        dateTime: when,
        assetAudioPath: SequenceBuilder.relPath(id),
      );
    }

    final isRandom = (await randomIds()).contains(alarm.id);
    if (!isRandom) return alarm.copyWith(id: newId, dateTime: when);
    final sound = pickRandomSound(except: soundFromAsset(alarm.assetAudioPath));
    return build(
      id: id,
      time: when,
      audioPath: sound.alarmPath,
      body: 'Herää! 🎲',
      label: alarm.notificationSettings.title,
    );
  }

  /// Pysäyttää soivan hälytyksen; päivittäinen ajastetaan uudelleen huomiseksi
  /// (satunnaisella uudella äänellä/sarjalla).
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
      if ((await sequences()).containsKey(alarm.id)) {
        // Torkkua varten tiedosto tehdään uudelle id:lle; tämä poistetaan.
        await _saveSequence(alarm.id, null);
        await SequenceBuilder.delete(alarm.id);
      }
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
