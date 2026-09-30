import 'package:alarm/alarm.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'alarm_service.dart';
import 'sounds.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<AlarmSettings> _alarms = [];
  Set<int> _daily = {};
  Set<int> _random = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final alarms = await Alarm.getAlarms();
    alarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final daily = await AlarmService.dailyIds();
    final random = await AlarmService.randomIds();
    if (mounted) {
      setState(() {
        _alarms = alarms;
        _daily = daily;
        _random = random;
      });
    }
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewAlarmSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loud Wake Up 🚨')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Uusi herätys'),
      ),
      body: _alarms.isEmpty
          ? const Center(child: Text('Ei herätyksiä. Lisää ensimmäinen!'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final a in _alarms)
                  Dismissible(
                    key: ValueKey(a.id),
                    background: Container(color: Colors.red),
                    onDismissed: (_) async {
                      await AlarmService.delete(a.id);
                      _load();
                    },
                    child: ListTile(
                      leading: const Icon(Icons.alarm, size: 32),
                      title: Text(
                        TimeOfDay.fromDateTime(a.dateTime).format(context),
                        style: const TextStyle(fontSize: 32),
                      ),
                      subtitle: Text(
                        '${_random.contains(a.id) ? '🎲 Satunnainen ääni' : soundFromAsset(a.assetAudioPath).name}'
                        '${_daily.contains(a.id) ? ' · joka päivä' : ''}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _NewAlarmSheet extends StatefulWidget {
  const _NewAlarmSheet();

  @override
  State<_NewAlarmSheet> createState() => _NewAlarmSheetState();
}

class _NewAlarmSheetState extends State<_NewAlarmSheet> {
  TimeOfDay _time = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 1)));
  String _soundId = randomSoundId;
  bool _daily = true;
  final _player = AudioPlayer();
  String? _playing;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleSample(AlarmSound s) async {
    if (_playing == s.id) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource(s.previewAsset), volume: 1.0);
    setState(() => _playing = s.id);
  }

  Future<void> _save() async {
    await _player.stop();
    await AlarmService.create(
      hour: _time.hour,
      minute: _time.minute,
      soundId: _soundId,
      daily: _daily,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          ListTile(
            title: Text(_time.format(context), style: const TextStyle(fontSize: 40)),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          ),
          SwitchListTile(
            title: const Text('Toista joka päivä'),
            value: _daily,
            onChanged: (v) => setState(() => _daily = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                RadioListTile<String>(
                  value: randomSoundId,
                  groupValue: _soundId,
                  title: const Text('🎲 Satunnainen ääni joka aamu'),
                  subtitle: const Text('Sovellus arpoo uuden äänen jokaiselle herätykselle'),
                  onChanged: (v) => setState(() => _soundId = v!),
                ),
                for (final s in alarmSounds)
                  RadioListTile<String>(
                    value: s.id,
                    groupValue: _soundId,
                    title: Text(s.name),
                    secondary: IconButton(
                      icon: Icon(_playing == s.id ? Icons.stop_circle : Icons.play_circle),
                      onPressed: () => _toggleSample(s),
                    ),
                    onChanged: (v) => setState(() => _soundId = v!),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Tallenna herätys', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
