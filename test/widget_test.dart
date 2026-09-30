import 'package:flutter_test/flutter_test.dart';
import 'package:loud_wake_up/sequence.dart';
import 'package:loud_wake_up/sounds.dart';

void main() {
  test('jokaisella äänellä on uniikki id', () {
    final ids = SoundLibrary.all.map((s) => s.id).toSet();
    expect(ids.length, SoundLibrary.all.length);
  });

  test('äänisarjan spec säilyy JSON-muodossa', () {
    final spec = SequenceSpec(['siren', randomSoundId, 'klaxon'], 20, 'a → b → c');
    final back = SequenceSpec.decode(spec.encode());
    expect(back.stages, spec.stages);
    expect(back.secs, 20);
    expect(back.hasRandom, isTrue);
  });
}
