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
];

AlarmSound soundById(String id) =>
    alarmSounds.firstWhere((s) => s.id == id, orElse: () => alarmSounds.first);

AlarmSound soundFromAsset(String asset) {
  final id = asset.split('/').last.replaceAll('.wav', '');
  return soundById(id);
}

AlarmSound pickRandomSound() => alarmSounds[Random().nextInt(alarmSounds.length)];
