import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'branding.dart';
import 'pin.dart';
import 'serial_field.dart';
import 'sim_store.dart';
import 'staff.dart';
import 'store.dart';
import 'theme.dart';

// On device: the SQLite store. In the WEB SIM build: the in-memory
// demo store — same interface, same screens, sample data.
final StoreApi store = kPackOutSim ? SimStore() : Store();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A checkout station must not fall asleep mid-shift.
  WakelockPlus.enable().catchError((_) {});
  runApp(const StationApp());
}

class StationApp extends StatelessWidget {
  const StationApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pack Out By Shepherd',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const KioskHome(),
    );
  }
}

// ---------------- Kiosk home: pick your name ----------------

class KioskHome extends StatefulWidget {
  const KioskHome({super.key});
  @override
  State<KioskHome> createState() => _KioskHomeState();
}

class _KioskHomeState extends State<KioskHome> {
  List<String> _members = [];
  int _flags = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await store.members();
    final f = await store.openFlagCount();
    if (!mounted) return;
    setState(() {
      _members = m;
      _flags = f;
      _loading = false;
    });
  }

  Future<void> _staffGate() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockUntil = prefs.getInt('pin_lockout_until') ?? 0;
    if (now < lockUntil) {
      final secs = ((lockUntil - now) / 1000).ceil();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Too many wrong PINs — staff unlock is paused for $secs seconds.')));
      return;
    }
    final storedPin = prefs.getString('staff_pin');
    final pin = storedPin ?? defaultStaffPin;
    if (!mounted) return;
    final entered = await showDialog<String>(
      context: context,
      builder: (_) => const PinDialog(),
    );
    if (entered == null) return;
    if (entered != pin) {
      final fails = (prefs.getInt('pin_fail_count') ?? 0) + 1;
      if (fails >= 5) {
        await prefs.setInt('pin_lockout_until',
            DateTime.now().millisecondsSinceEpoch + 60000);
        await prefs.setInt('pin_fail_count', 0);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Too many wrong PINs — locked for 60 seconds.')));
      } else {
        await prefs.setInt('pin_fail_count', fails);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Wrong PIN.')));
      }
      return;
    }
    await prefs.setInt('pin_fail_count', 0);
    await prefs.setInt('pin_lockout_until', 0);
    if (storedPin == null) {
      // First staff sign-in ever: the default PIN only gets you to the
      // setup — staff mode requires a PIN the crew chose.
      if (!mounted) return;
      final newPin = await showDialog<String>(
        context: context,
        builder: (_) =>
            const ChangePinDialog(title: 'Set your staff PIN'),
      );
      if (newPin == null) return;
      await prefs.setString('staff_pin', newPin);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StaffHome(store: store)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: ShepherdBanner(large: true)),
                  if (_flags > 0)
                    Chip(
                      avatar: const Icon(Icons.flag, size: 16, color: kWarn),
                      label: Text('$_flags to sort'),
                      backgroundColor: kCard,
                      side: BorderSide(color: kWarn.withValues(alpha: 0.35)),
                      labelStyle: const TextStyle(color: kWarn),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _staffGate,
                    icon: const Icon(Icons.admin_panel_settings_outlined,
                        size: 18),
                    label: const Text('Staff'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: kPurple,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Tap your name to check gear out or in',
                  style: TextStyle(color: kDim, fontSize: 16)),
              const SizedBox(height: 18),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _members.isEmpty
                        ? const Center(
                            child: Text('No members yet — staff can add some.',
                                style: TextStyle(color: kDim, fontSize: 17)))
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              mainAxisExtent: 96,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: _members.length,
                            itemBuilder: (_, i) {
                              final name = _members[i];
                              return Material(
                                color: kCard,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              FlowScreen(member: name)),
                                    );
                                    _load();
                                  },
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      child: Text(name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinDialog extends StatefulWidget {
  const PinDialog({super.key});
  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String _pin = '';
  void _tap(String d) {
    if (d == 'clr') {
      setState(() => _pin = '');
    } else if (d == 'del') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else if (_pin.length < 8) {
      setState(() => _pin += d);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCard,
      title: const Text('Staff PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _pin.isEmpty ? '••••' : '●' * _pin.length,
            style: const TextStyle(fontSize: 30, letterSpacing: 6),
          ),
          const SizedBox(height: 14),
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['clr', '0', 'del'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in row)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: SizedBox(
                      width: 64,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => _tap(d),
                        child: Text(d == 'clr'
                            ? 'C'
                            : d == 'del'
                                ? '⌫'
                                : d),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _pin),
            child: const Text('Unlock')),
      ],
    );
  }
}

// ---------------- Member flow: name -> category -> gear -> confirm -> success ----------------

class FlowScreen extends StatefulWidget {
  final String member;
  const FlowScreen({super.key, required this.member});
  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  List<Map<String, Object?>> _items = [];
  bool _loadingItems = true;
  Map<String, Object?>? _item;
  String _status = 'in';
  String _holder = '';
  List<Map<String, Object?>> _candidates = [];
  bool _resolved = false;
  bool _posting = false;
  // Snapshot of exactly what was picked/looked up and displayed. Posting
  // uses the snapshot ONLY — editing the Lookup bar invalidates it, so the
  // screen can never show item A while posting item B (or a blank serial).
  String _resolvedSerial = '';
  int _lookupSeq = 0;
  Timer? _idleTimer;
  final _serialCtl = TextEditingController();

  // Browse path: categories (level 0) -> sub-categories when the picked
  // category has any (level 1) -> the gear itself (level 2). "All gear"
  // jumps straight to level 2 with no category filter.
  String? _cat;
  String? _sub; // null = everything in the category; '' = no sub-type
  int _level = 0;

  static const _idleLimit = Duration(seconds: 90);

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
    _loadItems();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _serialCtl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await store.itemsWithStatus();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loadingItems = false;
    });
  }

  // ----- category helpers (the item "type" text carries the hierarchy) -----

  (String, String) _typeOf(Map<String, Object?> it) =>
      parseType((it['type'] as String?) ?? '');

  List<String> get _categories {
    final seen = <String>{};
    for (final it in _items) {
      seen.add(_typeOf(it).$1);
    }
    return seen.toList()..sort();
  }

  List<String> _subsOf(String cat) {
    final seen = <String>{};
    for (final it in _items) {
      final (c, s) = _typeOf(it);
      if (c == cat && s.isNotEmpty) seen.add(s);
    }
    return seen.toList()..sort();
  }

  List<Map<String, Object?>> _itemsIn(String? cat, [String? sub]) {
    return [
      for (final it in _items)
        if ((cat == null || _typeOf(it).$1 == cat) &&
            (sub == null || _typeOf(it).$2 == sub))
          it,
    ];
  }

  String _coverPhoto(List<Map<String, Object?>> list) {
    for (final it in list) {
      final ph = (it['photo'] as String?) ?? '';
      if (ph.isNotEmpty) return ph;
    }
    return '';
  }

  int _outCount(List<Map<String, Object?>> list) =>
      list.where((i) => i['status'] == 'out').length;

  void _openCategory(String cat) {
    _pokeIdle();
    setState(() {
      _cat = cat;
      _sub = null;
      // No sub-types in this category: straight to the gear.
      _level = _subsOf(cat).isEmpty ? 2 : 1;
    });
  }

  void _openSub(String? sub) {
    _pokeIdle();
    setState(() {
      _sub = sub;
      _level = 2;
    });
  }

  void _goBackLevel() {
    _pokeIdle();
    setState(() {
      if (_level == 2 && _cat != null && _subsOf(_cat!).isNotEmpty) {
        _level = 1;
        _sub = null;
      } else {
        _level = 0;
        _cat = null;
        _sub = null;
      }
    });
  }

  /// Tapping a photo card selects that exact registry item.
  void _selectItem(Map<String, Object?> item) {
    _lookupSeq++;
    _pokeIdle();
    setState(() {
      _serialCtl.text = item['serial'] as String;
      _item = item;
      _status = (item['status'] as String?) ?? 'in';
      _holder = (item['holder'] as String?) ?? '';
      _candidates = [];
      _resolvedSerial = item['serial'] as String;
      _resolved = true;
    });
  }

  Future<void> _lookup() async {
    _pokeIdle();
    final s = _serialCtl.text.trim();
    if (s.isEmpty) return;
    final seq = ++_lookupSeq;
    final item = await store.findItem(s);
    final items = await store.itemsRaw();
    var status = 'in';
    var holder = '';
    if (item != null) {
      final withStatus = await store.itemsWithStatus();
      for (final it in withStatus) {
        if (it['serial_norm'] == item['serial_norm']) {
          status = (it['status'] as String?) ?? 'in';
          holder = (it['holder'] as String?) ?? '';
        }
      }
    }
    // A newer lookup (or an edit, or a card tap) supersedes this one.
    if (!mounted || seq != _lookupSeq) return;
    setState(() {
      _item = item;
      _status = status;
      _holder = holder;
      _candidates = item == null ? closestMatches(items, s) : [];
      _resolvedSerial = s;
      _resolved = true;
    });
  }

  Future<void> _post() async {
    if (_posting || !_resolved || _resolvedSerial.isEmpty) return;
    setState(() => _posting = true);
    try {
      final result = await store.postTransaction(
        member: widget.member,
        serial: _resolvedSerial,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SuccessScreen(member: widget.member, result: result),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not post that — please try again.')));
    }
  }

  // ----- browse cards -----

  Widget _browseCard({
    required String photoPath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemPhotoWide(photoPath: photoPath, height: 104),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 0),
              child: Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kDim, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemGrid(List<Map<String, Object?>> items) {
    if (items.isEmpty) {
      return const Center(
          child: Text('Nothing here yet.',
              style: TextStyle(color: kDim, fontSize: 16)));
    }
    return Listener(
      onPointerDown: (_) => _pokeIdle(),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisExtent: 216,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          final out = it['status'] == 'out';
          return Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _selectItem(it),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ItemPhotoWide(
                      photoPath: (it['photo'] as String?) ?? '', height: 118),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
                    child: Text(it['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                    child: Text('${it['serial']}',
                        style: const TextStyle(color: kDim, fontSize: 12.5)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            size: 10, color: out ? kWarn : kOk),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(out ? 'OUT — ${it['holder']}' : 'IN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, color: kDim)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _browseGrid(List<Widget> cards) {
    return Listener(
      onPointerDown: (_) => _pokeIdle(),
      child: GridView.extent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 188,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: cards,
      ),
    );
  }

  Widget _browser() {
    if (_loadingItems) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(
          child: Text('No gear registered yet — staff can add it.',
              style: TextStyle(color: kDim, fontSize: 17)));
    }
    if (_level == 0) {
      return _browseGrid([
        for (final cat in _categories)
          _browseCard(
            photoPath: _coverPhoto(_itemsIn(cat)),
            title: cat,
            subtitle:
                '${_itemsIn(cat).length} items · ${_outCount(_itemsIn(cat))} out',
            onTap: () => _openCategory(cat),
          ),
        _browseCard(
          photoPath: _coverPhoto(_items),
          title: 'All gear',
          subtitle: '${_items.length} items · ${_outCount(_items)} out',
          onTap: () {
            _pokeIdle();
            setState(() {
              _cat = null;
              _sub = null;
              _level = 2;
            });
          },
        ),
      ]);
    }
    if (_level == 1) {
      final cat = _cat!;
      final subs = _subsOf(cat);
      final general = _itemsIn(cat, '');
      return _browseGrid([
        for (final sub in subs)
          _browseCard(
            photoPath: _coverPhoto(_itemsIn(cat, sub)),
            title: sub,
            subtitle:
                '${_itemsIn(cat, sub).length} items · ${_outCount(_itemsIn(cat, sub))} out',
            onTap: () => _openSub(sub),
          ),
        if (general.isNotEmpty)
          _browseCard(
            photoPath: _coverPhoto(general),
            title: 'General',
            subtitle: '${general.length} items · ${_outCount(general)} out',
            onTap: () => _openSub(''),
          ),
        _browseCard(
          photoPath: _coverPhoto(_itemsIn(cat)),
          title: 'All $cat',
          subtitle:
              '${_itemsIn(cat).length} items · ${_outCount(_itemsIn(cat))} out',
          onTap: () => _openSub(null),
        ),
      ]);
    }
    return _itemGrid(_itemsIn(_cat, _sub));
  }

  String get _crumb {
    if (_level == 0) return 'Categories';
    if (_level == 1) return '$_cat';
    if (_cat == null) return 'All gear';
    if (_sub == null) return '$_cat — all';
    if (_sub == '') return '$_cat — General';
    return '$_cat — $_sub';
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final isOut = _status == 'out';
    return Scaffold(
      appBar: shepherdAppBar(
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: kDim)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Checking gear for ${widget.member}',
                  style: const TextStyle(color: kDim, fontSize: 15)),
              const SizedBox(height: 14),
              const Text('Serial Lookup',
                  style: TextStyle(color: kDim, fontSize: 14)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SerialField(
                      controller: _serialCtl,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700),
                      hintText: 'e.g. SN8847392',
                      onChanged: (_) {
                        // Any manual edit invalidates the displayed
                        // confirmation, synchronously.
                        _lookupSeq++;
                        setState(() {
                          _resolved = false;
                          _item = null;
                          _candidates = [];
                        });
                        _pokeIdle();
                      },
                      onSubmitted: (_) => _lookup(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _lookup,
                    child: const Text('Look up'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_resolved && item != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ItemPhotoWide(
                                  photoPath:
                                      (item['photo'] as String?) ?? '',
                                  height: 190),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] as String,
                                        style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    Text('Serial ${item['serial']}',
                                        style: const TextStyle(
                                            color: kDim, fontSize: 16)),
                                    const SizedBox(height: 10),
                                    Chip(
                                      label: Text(isOut
                                          ? 'OUT — with $_holder'
                                          : 'IN — on the shelf'),
                                      backgroundColor: isOut ? kWarn : kOk,
                                      labelStyle: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        gradientButton(
                          label: isOut ? '✓ CHECK IN' : '✓ CHECK OUT',
                          icon: isOut ? Icons.login : Icons.logout,
                          onPressed: _posting ? null : _post,
                        ),
                      ],
                    ),
                  ),
                )
              else if (_resolved && item == null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Not in the registry',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: kWarn)),
                                const SizedBox(height: 6),
                                Text(
                                    'Serial ${_resolvedSerial.toUpperCase()} will still post, flagged for staff to sort out.',
                                    style: const TextStyle(
                                        color: kDim, fontSize: 16)),
                                if (_candidates.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                      'Closest matches — tap the right one:',
                                      style: TextStyle(color: kDim)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final c in _candidates)
                                        ActionChip(
                                          label: Text(
                                              '${c['serial']} — ${c['name']}'),
                                          onPressed: () {
                                            _serialCtl.text =
                                                c['serial'] as String;
                                            _lookup();
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        gradientButton(
                          label: '⚠ POST AS UNMATCHED',
                          onPressed: _posting ? null : _post,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    if (_level > 0) ...[
                      IconButton(
                        onPressed: _goBackLevel,
                        icon: const Icon(Icons.arrow_back),
                        color: kPurpleLight,
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 2),
                    ],
                    Text(_crumb,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(child: _browser()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Success ----------------

class SuccessScreen extends StatefulWidget {
  final String member;
  final PostResult result;
  const SuccessScreen({super.key, required this.member, required this.result});
  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  Timer? _timer;
  late final AnimationController _pop;
  int _count = 6;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _pop.forward();
    _play();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _count--);
      if (_count <= 0) _done();
    });
  }

  Future<void> _play() async {
    final prefs = await SharedPreferences.getInstance();
    final soundOn = prefs.getBool('sound_on') ?? true;
    if (!soundOn) return;
    final line = featuredLine(widget.result.action);
    try {
      await _player.setVolume(1.0);
      await _player.play(AssetSource('audio/${line.file}'));
    } catch (_) {}
  }

  void _done() {
    _timer?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final out = widget.result.action == 'check_out';
    final line = featuredLine(widget.result.action);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale:
                      CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
                  child:
                      Text(out ? '🤠' : '🎉', style: const TextStyle(fontSize: 96)),
                ),
                const SizedBox(height: 12),
                Text(
                  out ? "You're checked OUT — go get it!" : 'Welcome back!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.member}${widget.result.itemName.isNotEmpty ? ' — ${widget.result.itemName}' : ''}'
                  '${widget.result.unmatched ? ' (flagged for staff)' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kDim, fontSize: 18),
                ),
                const SizedBox(height: 16),
                Text('“${line.text}”',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: kPurpleLight,
                        fontSize: 19,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 30),
                gradientButton(
                  label: 'Done ($_count)',
                  onPressed: _done,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
