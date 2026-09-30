import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'sounds.dart';

/// Äänisarja: vaiheet soivat peräkkäin [secs] sekuntia kukin ja koko sarja toistuu.
/// Vaihe on äänen id tai [randomSoundId] (arvotaan joka kerta uudelleen).
class SequenceSpec {
  final List<String> stages;
  final int secs;
  final String label;
  const SequenceSpec(this.stages, this.secs, [this.label = '']);

  bool get hasRandom => stages.contains(randomSoundId);

  SequenceSpec withLabel(String l) => SequenceSpec(stages, secs, l);

  Map<String, dynamic> toJson() => {'stages': stages, 'secs': secs, 'label': label};

  factory SequenceSpec.fromJson(Map<String, dynamic> j) => SequenceSpec(
        (j['stages'] as List).cast<String>(),
        j['secs'] as int,
        (j['label'] as String?) ?? '',
      );

  String encode() => jsonEncode(toJson());
  static SequenceSpec decode(String s) =>
      SequenceSpec.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class SequenceBuilder {
  static const _sr = 22050;
  static const dir = 'sequences';

  static String relPath(int alarmId) => '$dir/seq_$alarmId.wav';

  /// Kokoaa sarjan yhdeksi WAV-tiedostoksi Documents/sequences-kansioon.
  /// Vain mukana tulevat äänet kelpaavat (omat mp3:t eivät).
  static Future<SequenceSpec> render(int alarmId, SequenceSpec spec) async {
    final pool = SoundLibrary.all.where((s) => !s.isCustom).toList();
    final chosen = <AlarmSound>[];
    for (final st in spec.stages) {
      if (st == randomSoundId) {
        final options = pool.where((s) => !chosen.contains(s)).toList();
        chosen.add(options[Random().nextInt(options.length)]);
      } else {
        chosen.add(SoundLibrary.byId(st));
      }
    }

    final perStage = spec.secs * _sr;
    final out = Int16List(perStage * chosen.length);
    const fade = _sr ~/ 200; // 5 ms
    for (var i = 0; i < chosen.length; i++) {
      final pcm = await _loadPcm(chosen[i]);
      final base = i * perStage;
      for (var j = 0; j < perStage; j++) {
        var v = pcm[j % pcm.length].toDouble();
        if (j < fade) v *= j / fade;
        if (j >= perStage - fade) v *= (perStage - j) / fade;
        out[base + j] = v.round();
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, relPath(alarmId)));
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(_wav(out), flush: true);
    return spec.withLabel(chosen.map((s) => s.name).join(' → '));
  }

  static Future<void> delete(int alarmId) async {
    final docs = await getApplicationDocumentsDirectory();
    final f = File(p.join(docs.path, relPath(alarmId)));
    if (f.existsSync()) await f.delete();
  }

  static Future<Int16List> _loadPcm(AlarmSound s) async {
    final data = await rootBundle.load(s.alarmPath);
    var rate = _sr;
    var o = 12;
    while (o + 8 <= data.lengthInBytes) {
      final id = String.fromCharCodes(data.buffer.asUint8List(data.offsetInBytes + o, 4));
      final size = data.getUint32(o + 4, Endian.little);
      if (id == 'fmt ') rate = data.getUint32(o + 12, Endian.little);
      if (id == 'data') {
        final n = size ~/ 2;
        final src = Int16List(n);
        for (var k = 0; k < n; k++) {
          src[k] = data.getInt16(o + 8 + k * 2, Endian.little);
        }
        return rate == _sr ? src : _resample(src, rate);
      }
      o += 8 + size + (size & 1);
    }
    throw StateError('WAV-dataa ei löytynyt: ${s.id}');
  }

  static Int16List _resample(Int16List src, int rate) {
    final ratio = rate / _sr;
    final n = (src.length / ratio).floor();
    final dst = Int16List(n);
    for (var i = 0; i < n; i++) {
      final pos = i * ratio;
      final i0 = pos.floor();
      final i1 = min(i0 + 1, src.length - 1);
      final f = pos - i0;
      dst[i] = (src[i0] * (1 - f) + src[i1] * f).round();
    }
    return dst;
  }

  static Uint8List _wav(Int16List pcm) {
    final bytes = pcm.length * 2;
    final b = ByteData(44 + bytes);
    void tag(int off, String s) {
      for (var i = 0; i < 4; i++) {
        b.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    b.setUint32(4, 36 + bytes, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, _sr, Endian.little);
    b.setUint32(28, _sr * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    b.setUint32(40, bytes, Endian.little);
    for (var i = 0; i < pcm.length; i++) {
      b.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return b.buffer.asUint8List();
  }
}
