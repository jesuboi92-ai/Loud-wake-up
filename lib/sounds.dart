import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const randomSoundId = 'random';
const _customKey = 'custom_sounds';
const _customDir = 'custom_sounds';

const categoryLabels = <String, String>{
  'custom': '🎵 Omat',
  'classic': '⭐ Valitut',
  'voice': '😱 Huudot & karjunta',
  'scrape': '🪟 Raapivat & kirskuvat',
  'animal': '🐓 Eläimet',
  'impact': '💥 Räjähdykset & särky',
  'machine': '⚙️ Koneet & hälyttimet',
  'music': '🎺 Soittimet',
  'sirens': '🚨 Sireenit',
  'beeps': '⏰ Piippaukset',
  'heavy': '🔊 Raskaat',
  'weird': '👽 Oudot',
  'bells': '🔔 Kellot',
};

class AlarmSound {
  final String id;
  final String name;
  final String category;

  /// Omilla äänillä tiedostonimi Documents/custom_sounds-kansiossa.
  final String? customFile;

  const AlarmSound(this.id, this.name, {this.category = 'classic', this.customFile});

  bool get isCustom => customFile != null;

  /// Polku, jonka alarm-paketti saa. iOS:llä ei-`assets/`-polut luetaan
  /// Documents-kansiosta, joten suhteellinen polku kestää myös päivitykset.
  String get alarmPath => isCustom ? '$_customDir/$customFile' : 'assets/sounds/$id.wav';

  /// Polku audioplayersin AssetSourcelle (ilman assets/-etuliitettä).
  String get previewAsset => 'sounds/$id.wav';
}

const _classic = <AlarmSound>[
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

/// Kaikki äänet: valitut + generoidut variantit + käyttäjän omat.
class SoundLibrary {
  static List<AlarmSound> _builtIn = List.of(_classic);
  static List<AlarmSound> _custom = [];

  static List<AlarmSound> get all => [..._custom, ..._builtIn];
  static List<AlarmSound> get custom => _custom;

  static Future<void> load() async {
    _builtIn = List.of(_classic);
    for (final file in const ['characters.json', 'variants.json']) {
      try {
        final raw = await rootBundle.loadString('assets/sounds/$file');
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _builtIn.addAll([
          for (final m in list)
            AlarmSound(m['id'] as String, m['name'] as String,
                category: m['category'] as String),
        ]);
      } catch (_) {
        // Puuttuva lista ei estä sovellusta käynnistymästä.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_customKey) ?? [];
    final docs = await getApplicationDocumentsDirectory();
    _custom = [
      for (final s in stored)
        if (File(p.join(docs.path, _customDir, (jsonDecode(s) as Map)['file'] as String))
            .existsSync())
          AlarmSound((jsonDecode(s) as Map)['id'] as String,
              (jsonDecode(s) as Map)['name'] as String,
              category: 'custom', customFile: (jsonDecode(s) as Map)['file'] as String),
    ];
  }

  static AlarmSound byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => _classic.first);

  static AlarmSound byPath(String? path) =>
      all.firstWhere((s) => s.alarmPath == path, orElse: () => _classic.first);

  static Future<String> absolutePath(AlarmSound s) async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, _customDir, s.customFile!);
  }

  /// Tuo oman äänen. [music]=true avaa Musiikki-kirjaston, muuten Tiedostot-sovelluksen.
  /// Palauttaa null, jos valinta peruttiin tai tiedostoa ei saatu (esim. DRM-suojattu).
  static Future<AlarmSound?> importSound({required bool music}) async {
    final res = await FilePicker.platform.pickFiles(
      type: music ? FileType.audio : FileType.custom,
      allowedExtensions:
          music ? null : ['mp3', 'm4a', 'aac', 'wav', 'aiff', 'caf', 'mp4', 'mov'],
    );
    final src = res?.files.single.path;
    if (src == null) return null;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _customDir))..createSync(recursive: true);
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final file = '$id${p.extension(src).toLowerCase()}';
    await File(src).copy(p.join(dir.path, file));

    final sound = AlarmSound(id, p.basenameWithoutExtension(src),
        category: 'custom', customFile: file);
    _custom = [sound, ..._custom];
    await _saveCustom();
    return sound;
  }

  static Future<void> removeCustom(AlarmSound s) async {
    if (!s.isCustom) return;
    final f = File(await absolutePath(s));
    if (f.existsSync()) await f.delete();
    _custom = _custom.where((c) => c.id != s.id).toList();
    await _saveCustom();
  }

  static Future<void> _saveCustom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customKey, [
      for (final c in _custom)
        jsonEncode({'id': c.id, 'name': c.name, 'file': c.customFile}),
    ]);
  }
}

AlarmSound soundById(String id) => SoundLibrary.byId(id);

AlarmSound soundFromAsset(String? path) => SoundLibrary.byPath(path);

/// Arpoo äänen koko kirjastosta; `except` estää saman äänen peräkkäisinä päivinä.
AlarmSound pickRandomSound({AlarmSound? except}) {
  final pool = SoundLibrary.all.where((s) => s.id != except?.id).toList();
  return pool[Random().nextInt(pool.length)];
}
