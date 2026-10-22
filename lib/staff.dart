import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'branding.dart';
import 'capture.dart';
import 'pin.dart';
import 'sim_capture.dart';
import 'serial_field.dart';
import 'store.dart';
import 'theme.dart';

class StaffHome extends StatefulWidget {
  final StoreApi store;
  const StaffHome({super.key, required this.store});
  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  int _tab = 0;
  Timer? _idleTimer;

  // Staff mode sits on a member-facing tablet: it locks itself after a few
  // idle minutes instead of staying open until someone remembers Lock.
  static const _idleLimit = Duration(minutes: 3);

  void _pokeIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleLimit, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void initState() {
    super.initState();
    _pokeIdle();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BoardPage(store: widget.store),
      LogPage(store: widget.store),
      RegistryPage(store: widget.store),
      RosterPage(store: widget.store),
      SettingsPage(store: widget.store),
    ];
    return Listener(
      onPointerDown: (_) => _pokeIdle(),
      child: Scaffold(
        appBar: shepherdAppBar(
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Lock', style: TextStyle(color: kDim)),
            ),
          ],
        ),
        body: pages[_tab],
        bottomNavigationBar: NavigationBar(
          backgroundColor: kCard,
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            _pokeIdle();
            setState(() => _tab = i);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard), label: 'Board'),
            NavigationDestination(icon: Icon(Icons.list_alt), label: 'Log'),
            NavigationDestination(
                icon: Icon(Icons.inventory_2), label: 'Registry'),
            NavigationDestination(icon: Icon(Icons.people), label: 'Roster'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ---------------- Board ----------------

class BoardPage extends StatelessWidget {
  final StoreApi store;
  const BoardPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: store.itemsWithStatus(),
      builder: (_, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text('Something went wrong loading the board.',
                style: TextStyle(color: kDim, fontSize: 16)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        final out = items.where((i) => i['status'] == 'out').toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                _stat('Total', '${items.length}'),
                _stat('Out', '${out.length}', kWarn),
                _stat('In', '${items.length - out.length}', kOk),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Out right now',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (out.isEmpty)
              const Text('Nothing out right now.',
                  style: TextStyle(color: kDim, fontSize: 16)),
            for (final i in out)
              Card(
                child: ListTile(
                  title: Text(i['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${i['serial']} · with ${i['holder']} · since ${i['since']}'),
                  leading: ItemPhoto(
                      photoPath: (i['photo'] as String?) ?? '', size: 46),
                ),
              ),
            const SizedBox(height: 18),
            const Text('Voice lines right now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Out: “${featuredLine('check_out').text}”',
                style: const TextStyle(color: kDim)),
            Text('In: “${featuredLine('check_in').text}”',
                style: const TextStyle(color: kDim)),
            Text(
                'New lines ${nextRotation().toIso8601String().substring(0, 10)} · rotates every 3 days',
                style: const TextStyle(color: kDim)),
          ],
        );
      },
    );
  }

  Widget _stat(String label, String value, [Color color = kText]) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(color: kDim)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Log ----------------

class LogPage extends StatefulWidget {
  final StoreApi store;
  const LogPage({super.key, required this.store});
  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  String _q = '';
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.store.transactions();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _correct(Map<String, Object?> t) async {
    final serialCtl = TextEditingController(text: t['serial'] as String);
    var action = t['action'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Correct this transaction'),
        content: StatefulBuilder(
          builder: (_, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SerialField(
                controller: serialCtl,
                labelText: 'Correct serial',
                onChanged: (_) => setLocal(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Counts as:', style: TextStyle(color: kDim)),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('Check OUT'),
                    selected: action == 'check_out',
                    onSelected: (_) => setLocal(() => action = 'check_out'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Check IN'),
                    selected: action == 'check_in',
                    onSelected: (_) => setLocal(() => action = 'check_in'),
                  ),
                ],
              ),
              if ((t['prev_serial'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('Previously: ${t['prev_serial']}',
                      style: const TextStyle(color: kDim, fontSize: 13)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save correction')),
        ],
      ),
    );
    if (ok != true) return;
    if (serialCtl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A correction needs a serial — nothing changed.')));
      return;
    }
    bool matched;
    try {
      matched = await widget.store.correctTransaction(
          t['id'] as int, serialCtl.text.trim(),
          action: action);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That correction could not be saved.')));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(matched
          ? 'Corrected and matched to the registry.'
          : 'Saved — still not in the registry, stays flagged.'),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final shown = _rows.where((r) {
      if (q.isEmpty) return true;
      return '${r['member']} ${r['serial']} ${r['item_name']}'
          .toLowerCase()
          .contains(q);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: TextField(
            decoration: const InputDecoration(
                hintText: '🔎 Search — name, serial, item…'),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : shown.isEmpty
                  ? const Center(
                      child: Text('Nothing matches.',
                          style: TextStyle(color: kDim)))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final t = shown[i];
                        final unmatched = (t['unmatched'] as int) == 1;
                        final resolved = (t['resolved'] as int) == 1;
                        final photo = (t['photo'] as String?) ?? '';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          child: ListTile(
                            // Sim tx photos are asset paths (ItemPhoto
                            // handles them); the File branch is device-only
                            // and never evaluated in the web build, where
                            // dart:io would throw.
                            leading: photo.startsWith('asset://')
                                ? ItemPhoto(
                                    photoPath: photo, size: 52, radius: 8)
                                : !kPackOutSim &&
                                        photo.isNotEmpty &&
                                        File(photo).existsSync()
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(File(photo),
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover),
                                      )
                                    : const Icon(Icons.receipt_long,
                                        color: kDim, size: 34),
                            title: Text(
                                '${t['member']} — ${t['item_name'] ?? ''}'
                                    .trim(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${t['ts']} · ${t['serial']}'
                                '${unmatched && !resolved ? ' · UNMATCHED' : resolved && unmatched ? ' · resolved' : resolved ? ' · corrected' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(
                                      (t['action'] == 'check_out')
                                          ? 'OUT'
                                          : 'IN'),
                                  backgroundColor:
                                      t['action'] == 'check_out' ? kWarn : kOk,
                                  labelStyle: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'correct') _correct(t);
                                    if (v == 'resolve') {
                                      await widget.store
                                          .resolveTransaction(t['id'] as int);
                                      _load();
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: 'correct',
                                        child: Text('Correct serial…')),
                                    if (unmatched && !resolved)
                                      const PopupMenuItem(
                                          value: 'resolve',
                                          child: Text('Resolve flag')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ---------------- Registry ----------------

class RegistryPage extends StatefulWidget {
  final StoreApi store;
  const RegistryPage({super.key, required this.store});
  @override
  State<RegistryPage> createState() => _RegistryPageState();
}

class _RegistryPageState extends State<RegistryPage> {
  List<Map<String, Object?>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.store.itemsWithStatus();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _edit({Map<String, Object?>? item}) async {
    final serialCtl =
        TextEditingController(text: (item?['serial'] as String?) ?? '');
    final nameCtl = TextEditingController(text: (item?['name'] as String?) ?? '');
    final typeCtl = TextEditingController(text: (item?['type'] as String?) ?? '');
    final notesCtl =
        TextEditingController(text: (item?['notes'] as String?) ?? '');
    final existingPhoto = (item?['photo'] as String?) ?? '';
    // A fresh shot waiting to be saved with the item. Until Save, it lives
    // at the camera's temp path; cancelling the form discards it.
    String? pendingShot;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: Text(item == null ? 'Register equipment' : 'Edit equipment'),
        content: StatefulBuilder(
          builder: (_, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ItemPhotoWide(
                      photoPath: pendingShot ?? existingPhoto, height: 150),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final capTitle =
                          'Photograph ${nameCtl.text.trim().isEmpty ? 'the equipment' : nameCtl.text.trim()}';
                      final shot = await Navigator.of(context)
                          .push<String>(
                        MaterialPageRoute(
                            builder: (_) => kPackOutSim
                                ? SimCaptureScreen(title: capTitle)
                                : CapturePhotoScreen(title: capTitle)),
                      );
                      if (shot != null) setLocal(() => pendingShot = shot);
                    },
                    icon: const Icon(Icons.photo_camera),
                    label: Text(pendingShot != null || existingPhoto.isNotEmpty
                        ? 'Retake photo'
                        : 'Take photo'),
                  ),
                ),
                const SizedBox(height: 12),
                SerialField(
                    controller: serialCtl, labelText: 'Serial number'),
                const SizedBox(height: 10),
                TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(labelText: 'Item name')),
                const SizedBox(height: 10),
                TextField(
                    controller: typeCtl,
                    decoration: const InputDecoration(
                        labelText: 'Category / Sub-category (optional)',
                        hintText: 'e.g. Radio / Silvus')),
                const SizedBox(height: 10),
                TextField(
                    controller: notesCtl,
                    decoration:
                        const InputDecoration(labelText: 'Notes (optional)')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    if (serialCtl.text.trim().isEmpty || nameCtl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serial and name are both needed.')));
      return;
    }
    // Save order matters: write the ITEM first and only touch photo files
    // once that write is known to have succeeded. Storing the photo first
    // would overwrite the portrait of whatever item already owns the
    // target filename when the item write then refuses (serial clash) —
    // while the UI claims nothing changed.
    final serial = serialCtl.text.trim();
    final shot = pendingShot;
    try {
      if (item == null) {
        // Registering must never silently REPLACE an existing item (its
        // row AND its portrait). Refuse duplicates; staff edits instead.
        final existing = await widget.store.findItem(serial);
        if (existing != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'That serial is already registered as “${existing['name']}” — nothing changed. Edit it from the list instead.')));
          return;
        }
        await widget.store.upsertItem(
          serial: serial,
          name: nameCtl.text.trim(),
          type: typeCtl.text.trim(),
          notes: notesCtl.text.trim(),
        );
      } else {
        // Edit keyed by the ORIGINAL serial — never an insert, never a
        // REPLACE that could delete a different item.
        final updated = await widget.store.updateItem(
          originalNorm: item['serial_norm'] as String,
          serial: serial,
          name: nameCtl.text.trim(),
          type: typeCtl.text.trim(),
          notes: notesCtl.text.trim(),
        );
        if (!updated) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'That serial already belongs to another item — nothing changed.')));
          return;
        }
      }
      // The item write landed. NOW the portrait can be stored safely
      // under its (possibly new) serial and attached to the row.
      if (shot != null) {
        final norm = normSerial(serial);
        final stored = await widget.store.storeItemPhoto(norm, shot);
        await widget.store.setItemPhoto(norm, stored);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That could not be saved — please try again.')));
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: gradientButton(
            label: 'Register equipment',
            icon: Icons.add_a_photo,
            fontSize: 18,
            onPressed: () => _edit(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final it = _items[i];
                    final out = it['status'] == 'out';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      child: ListTile(
                        leading: ItemPhoto(
                            photoPath: (it['photo'] as String?) ?? '',
                            size: 46),
                        title: Text(it['name'] as String,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${it['serial']} · ${it['type']}${out ? ' · OUT with ${it['holder']}' : ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: kDim),
                              onPressed: () => _edit(item: it),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: kRed),
                              onPressed: () async {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: kCard,
                                    title: const Text('Remove item?'),
                                    content: Text(
                                        'Remove ${it['serial']} from the registry? History stays in the log.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel')),
                                      FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Remove')),
                                    ],
                                  ),
                                );
                                if (yes == true) {
                                  await widget.store.deleteItem(
                                      it['serial_norm'] as String);
                                  _load();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------- Roster ----------------

class RosterPage extends StatefulWidget {
  final StoreApi store;
  const RosterPage({super.key, required this.store});
  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  List<String> _members = [];
  final _ctl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await widget.store.members();
    if (!mounted) return;
    setState(() => _members = m);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  decoration: const InputDecoration(hintText: 'Full name'),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () async {
                  final n = _ctl.text.trim();
                  if (n.isEmpty) return;
                  await widget.store.addMember(n);
                  _ctl.clear();
                  _load();
                },
                child: const Text('Add member'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in _members)
                      Chip(
                        label: Text(m, style: const TextStyle(fontSize: 16)),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: kCard,
                              title: const Text('Remove member?'),
                              content: Text(
                                  'Remove $m from the roster? Their history stays in the log.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Remove')),
                              ],
                            ),
                          );
                          if (yes != true) return;
                          await widget.store.deleteMember(m);
                          _load();
                        },
                        backgroundColor: kCard,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Settings ----------------

class SettingsPage extends StatefulWidget {
  final StoreApi store;
  const SettingsPage({super.key, required this.store});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _sound = true;
  bool _camFront = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) async {
      final front = await preferredCamFront();
      if (!mounted) return;
      setState(() {
        _sound = p.getBool('sound_on') ?? true;
        _camFront = front;
        _loaded = true;
      });
    });
  }

  Future<void> _exportCsv() async {
    try {
      final csv = await widget.store.exportCsv();
      if (kPackOutSim) {
        // Browsers have no temp file to hand a share sheet — share the
        // bytes directly (lands as a download/share of the CSV).
        await Share.shareXFiles(
          [
            XFile.fromData(Uint8List.fromList(utf8.encode(csv)),
                name: 'equipment-log.csv', mimeType: 'text/csv'),
          ],
          subject: 'Equipment checkout log (CSV)',
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final f = File(p.join(dir.path, 'equipment-log.csv'));
      await f.writeAsString(csv);
      await Share.shareXFiles([XFile(f.path)],
          subject: 'Equipment checkout log (CSV)');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed — try again.')));
    }
  }

  Future<void> _changePin() async {
    final v = await showDialog<String>(
      context: context,
      builder: (_) => const ChangePinDialog(),
    );
    if (v == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_pin', v);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Staff PIN changed.')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          title: const Text('Southern voice on success'),
          subtitle: const Text('Plays from the tablet speakers, loud.'),
          value: _sound,
          activeThumbColor: kPurple,
          onChanged: (v) async {
            setState(() => _sound = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('sound_on', v);
          },
        ),
        const Divider(color: Color(0xFF3A3560)),
        const ListTile(
          title: Text('Camera for equipment photos'),
          subtitle: Text(
              'Either camera works — you can also flip right on the photo screen. The choice sticks.'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: false,
                  icon: Icon(Icons.camera_rear),
                  label: Text('Back camera')),
              ButtonSegment(
                  value: true,
                  icon: Icon(Icons.camera_front),
                  label: Text('Front camera')),
            ],
            selected: {_camFront},
            onSelectionChanged: (s) async {
              setState(() => _camFront = s.first);
              await saveCamFront(s.first);
            },
          ),
        ),
        const Divider(color: Color(0xFF3A3560)),
        ListTile(
          title: const Text('Export log as CSV'),
          subtitle: const Text(
              'Share the transaction log as a spreadsheet file.'),
          trailing: const Icon(Icons.ios_share, color: kPurpleLight),
          onTap: _exportCsv,
        ),
        ListTile(
          title: const Text('Change staff PIN'),
          subtitle: const Text('The PIN that opens this staff mode.'),
          trailing: const Icon(Icons.pin, color: kPurpleLight),
          onTap: _changePin,
        ),
        const SizedBox(height: 16),
        const Text(
          'About this station\nEverything lives on this tablet: registry, roster, log, and the equipment photos. Checkout works with no network at all. The CSV export is a copy of the log — the photos themselves stay on the tablet, so treat the tablet as the record and export the log on a rhythm.',
          style: TextStyle(color: kDim, height: 1.5),
        ),
      ],
    );
  }
}
