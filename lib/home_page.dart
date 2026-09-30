import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import 'alarm_service.dart';
import 'sequence.dart';
import 'sound_picker_page.dart';
import 'sounds.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<AlarmSettings> _alarms = [];
  Set<int> _daily = {};
  final Map<int, String> _labels = {};

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
    final labels = <int, String>{
      for (final a in alarms) a.id: await AlarmService.soundLabel(a),
    };
    if (mounted) {
      setState(() {
        _alarms = alarms;
        _daily = daily;
        _labels
          ..clear()
          ..addAll(labels);
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
                        '${_labels[a.id] ?? ''}'
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

  bool _sequence = false;
  int _secs = 20;
  final List<String> _stages = [randomSoundId, randomSoundId, randomSoundId];

  String _nameOf(String id) =>
      id == randomSoundId ? '🎲 Satunnainen' : soundById(id).name;

  Future<void> _pickSound() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => SoundPickerPage(selectedId: _soundId)),
    );
    if (id != null) setState(() => _soundId = id);
  }

  Future<void> _pickStage(int i) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SoundPickerPage(selectedId: _stages[i], bundledOnly: true),
      ),
    );
    if (id != null) setState(() => _stages[i] = id);
  }

  void _setStageCount(int n) {
    setState(() {
      while (_stages.length < n) {
        _stages.add(randomSoundId);
      }
      while (_stages.length > n) {
        _stages.removeLast();
      }
    });
  }

  Future<void> _save() async {
    await AlarmService.create(
      hour: _time.hour,
      minute: _time.minute,
      soundId: _soundId,
      daily: _daily,
      sequence: _sequence ? SequenceSpec(List.of(_stages), _secs) : null,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
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
                SwitchListTile(
                  title: const Text('🎼 Äänisarja'),
                  subtitle: const Text('Ääni vaihtuu kesken herätyksen'),
                  value: _sequence,
                  onChanged: (v) => setState(() => _sequence = v),
                ),
                if (!_sequence)
                  ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(_nameOf(_soundId)),
                    subtitle: const Text('Valitse ääni'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickSound,
                  )
                else ...[
                  ListTile(
                    title: Text('Vaiheita: ${_stages.length}'),
                    subtitle: Slider(
                      value: _stages.length.toDouble(),
                      min: 2,
                      max: 5,
                      divisions: 3,
                      label: '${_stages.length}',
                      onChanged: (v) => _setStageCount(v.round()),
                    ),
                  ),
                  ListTile(
                    title: Text('Yhden vaiheen kesto: $_secs s'),
                    subtitle: Slider(
                      value: _secs.toDouble(),
                      min: 10,
                      max: 45,
                      divisions: 7,
                      label: '$_secs s',
                      onChanged: (v) => setState(() => _secs = v.round()),
                    ),
                  ),
                  for (var i = 0; i < _stages.length; i++)
                    ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(_nameOf(_stages[i])),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickStage(i),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'Satunnaiset vaiheet arvotaan uudelleen joka aamu. '
                      'Sarja toistuu alusta, jos et pysäytä herätystä. '
                      'Sarjaan kelpaavat vain sovelluksen omat äänet.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
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
