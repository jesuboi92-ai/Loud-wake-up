import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'sounds.dart';

/// Hakua, luokkia, esikuuntelua ja omien äänien tuontia. Palauttaa valitun äänen id:n
/// (tai [randomSoundId]).
class SoundPickerPage extends StatefulWidget {
  final String selectedId;

  /// Äänisarjan vaiheisiin kelpaavat vain mukana tulevat äänet (ei omia tiedostoja).
  final bool bundledOnly;
  const SoundPickerPage({super.key, required this.selectedId, this.bundledOnly = false});

  @override
  State<SoundPickerPage> createState() => _SoundPickerPageState();
}

class _SoundPickerPageState extends State<SoundPickerPage> {
  final _player = AudioPlayer();
  String _query = '';
  String? _category;
  String? _playing;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(AlarmSound s) async {
    if (_playing == s.id) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    await _player.setReleaseMode(ReleaseMode.loop);
    try {
      if (s.isCustom) {
        await _player.play(DeviceFileSource(await SoundLibrary.absolutePath(s)), volume: 1.0);
      } else {
        await _player.play(AssetSource(s.previewAsset), volume: 1.0);
      }
      setState(() => _playing = s.id);
    } catch (_) {
      _snack('Äänen toisto epäonnistui.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _import(bool music) async {
    try {
      final s = await SoundLibrary.importSound(music: music);
      if (s == null) {
        if (music) {
          _snack('Ei tuotu. Apple Musicin striimattuja (DRM-suojattuja) kappaleita ei voi '
              'käyttää – vain laitteelle ladatut/ostetut tai omat tiedostot.');
        }
        return;
      }
      setState(() => _category = 'custom');
      _snack('Lisätty: ${s.name}');
    } catch (e) {
      _snack('Tuonti epäonnistui: $e');
    }
  }

  Future<void> _delete(AlarmSound s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Poistetaanko "${s.name}"?'),
        content: const Text('Jos jokin herätys käyttää tätä ääntä, vaihda sen ääni ensin – '
            'muuten herätys voi olla hiljainen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Peru')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Poista')),
        ],
      ),
    );
    if (ok != true) return;
    if (_playing == s.id) await _player.stop();
    await SoundLibrary.removeCustom(s);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final sounds = SoundLibrary.all
        .where((s) => !widget.bundledOnly || !s.isCustom)
        .where((s) => _category == null || s.category == _category)
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
        .toList();
    final showRandom = q.isEmpty && _category == null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Valitse ääni (${SoundLibrary.all.length})'),
        actions: [
          if (!widget.bundledOnly)
            PopupMenuButton<bool>(
            icon: const Icon(Icons.library_add),
            tooltip: 'Lisää oma ääni',
            onSelected: _import,
            itemBuilder: (_) => const [
              PopupMenuItem(value: false, child: Text('📁 Tiedostoista (mp3, m4a, mp4…)')),
              PopupMenuItem(value: true, child: Text('🎵 Apple Musiikista')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Hae äänistä',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _chip('Kaikki', null),
                for (final e in categoryLabels.entries)
                  if (!(widget.bundledOnly && e.key == 'custom')) _chip(e.value, e.key),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sounds.length + (showRandom ? 1 : 0),
              itemBuilder: (context, i) {
                if (showRandom && i == 0) {
                  return ListTile(
                    leading: const Text('🎲', style: TextStyle(fontSize: 28)),
                    title: const Text('Satunnainen ääni joka aamu'),
                    subtitle: Text('Arvotaan kaikista ${SoundLibrary.all.length} äänestä'),
                    selected: widget.selectedId == randomSoundId,
                    onTap: () => Navigator.pop(context, randomSoundId),
                  );
                }
                final s = sounds[showRandom ? i - 1 : i];
                return ListTile(
                  title: Text(s.name),
                  subtitle: Text(categoryLabels[s.category] ?? ''),
                  selected: widget.selectedId == s.id,
                  leading: IconButton(
                    icon: Icon(_playing == s.id ? Icons.stop_circle : Icons.play_circle),
                    onPressed: () => _togglePreview(s),
                  ),
                  trailing: s.isCustom
                      ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(s))
                      : null,
                  onTap: () => Navigator.pop(context, s.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? cat) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: _category == cat,
          onSelected: (_) => setState(() => _category = cat),
        ),
      );
}
