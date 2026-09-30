import 'dart:math';

class AlarmSound {
  final String id;
  final String name;
  const AlarmSound(this.id, this.name);

  String get asset => 'assets/sounds/$id.wav';

  /// Polku audioplayersin AssetSourcelle (ilman assets/-etuliitettä).
  String get previewAsset => 'sounds/$id.wav';
}

const randomSoundId = 'random';

const alarmSounds = <AlarmSound>[
  AlarmSound('mega_mix', '💥 Mega-sekoitus (kaikki yhtä aikaa)'),
  AlarmSound('siren', '🚨 Sireeni'),
  AlarmSound('yelp', '🚓 Poliisin yelp'),
  AlarmSound('air_raid', '🛡️ Ilmahälytys'),
  AlarmSound('klaxon', '📯 Klaksoni'),
  AlarmSound('wobble', '🔊 Jyrisevä wobble'),
  AlarmSound('laser', '👽 Laser-ammunta'),
  AlarmSound('red_alert', '🔴 Punainen hälytys'),
  AlarmSound('eas_tone', '📻 Hätäkuulutusääni'),
  AlarmSound('fire_alarm', '🔥 Palohälytin'),
  AlarmSound('smoke_detector', '🚬 Palovaroitin'),
  AlarmSound('beeps', '⏰ Digitaalipiippaus'),
  AlarmSound('sos', '🆘 SOS-morse'),
  AlarmSound('whistle', '🎺 Pilli'),
  AlarmSound('retro_clock', '🕰️ Retrokello'),
  AlarmSound('bell', '🔔 Kilkatus'),
  AlarmSound('buzzer', '🐝 Surisija'),
  AlarmSound('foghorn', '🚢 Sumutorvi'),
  AlarmSound('aooga', '🚗 Aooga-torvi'),
  AlarmSound('noise_bursts', '📡 Kohinapurskeet'),
  AlarmSound('screaming_saws', '😱 Huutavat sahat'),
  AlarmSound('ambulance', '🚑 Pelastusauto'),
  AlarmSound('two_sirens', '🚨🚨 Kaksoissireeni'),
  AlarmSound('tornado', '🌪️ Tornadohälytys'),
  AlarmSound('train_horn', '🚂 Junan torvi'),
  AlarmSound('reverse_beeper', '🚛 Peruutussummeri'),
  AlarmSound('alien_fm', '🛸 Alien-emoalus'),
  AlarmSound('arcade_chaos', '👾 Arcade-kaaos'),
  AlarmSound('jackhammer', '🔨 Poravasara'),
];

AlarmSound soundById(String id) =>
    alarmSounds.firstWhere((s) => s.id == id, orElse: () => alarmSounds.first);

AlarmSound soundFromAsset(String? asset) {
  final id = (asset ?? '').split('/').last.replaceAll('.wav', '');
  return soundById(id);
}

/// Arpoo äänen; `except` estää saman äänen peräkkäisinä päivinä.
AlarmSound pickRandomSound({AlarmSound? except}) {
  final pool = alarmSounds.where((s) => s.id != except?.id).toList();
  return pool[Random().nextInt(pool.length)];
}
