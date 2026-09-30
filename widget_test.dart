import 'package:flutter_test/flutter_test.dart';
import 'package:loud_wake_up/sounds.dart';

void main() {
  test('jokaisella äänellä on uniikki id', () {
    final ids = alarmSounds.map((s) => s.id).toSet();
    expect(ids.length, alarmSounds.length);
  });
}
