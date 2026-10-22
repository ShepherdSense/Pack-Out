import 'package:path/path.dart' as p;

import 'store.dart';

/// Preset equipment photos for the web sim, as (asset path, label).
/// Item photos in the sim are 'asset://' pseudo-paths into this set —
/// the sim build's pubspec bundles them under assets/sim/gear/; the
/// on-device app never references them.
const simGearPhotos = <(String, String)>[
  ('assets/sim/gear/cooper.jpg', 'Cooper the Aussie'),
  ('assets/sim/gear/radio_tactical.jpg', 'Manpack radio'),
  ('assets/sim/gear/radio_handheld.jpg', 'Handheld radio'),
  ('assets/sim/gear/laser_rangefinder.jpg', 'Laser rangefinder'),
  ('assets/sim/gear/laser_designator.jpg', 'Laser designator'),
  ('assets/sim/gear/thermal_camera.jpg', 'Thermal camera'),
  ('assets/sim/gear/nvg.jpg', 'Night vision goggles'),
  ('assets/sim/gear/impact_driver.jpg', 'Impact driver kit'),
  ('assets/sim/gear/rugged_laptop.jpg', 'Rugged laptop'),
  ('assets/sim/gear/generator.jpg', 'Portable generator'),
  ('assets/sim/gear/battery_pack.jpg', 'Battery packs'),
];

String _asset(String name) => 'asset://assets/sim/gear/$name.jpg';

String _fmtTs(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// In-memory [StoreApi] for the WEB SIM build only. Mirrors [Store]'s
/// semantics exactly — same status derivation, same toggle posting,
/// same correction/audit behavior — over plain lists, seeded with a
/// plausible demo gear room and a little history (two items out, one
/// unmatched flag waiting on staff) so every screen has something to
/// show. Nothing persists: a page refresh resets the demo, which the
/// README's sim section says out loud.
class SimStore implements StoreApi {
  final List<String> _members = [
    'Alex Rivera',
    'Casey Nguyen',
    'Jordan Lee',
    'Maria Santos',
    'Sam Patel',
    'Taylor Brooks',
  ];

  final List<Map<String, Object?>> _items = [];
  final List<Map<String, Object?>> _txs = [];
  int _nextTxId = 1;

  SimStore() {
    void item(String serial, String name, String type, String photo) {
      _items.add({
        'serial': serial,
        'serial_norm': normSerial(serial),
        'name': name,
        'type': type,
        'notes': 'Sim demo item',
        'photo': _asset(photo),
      });
    }

    item('SILV-4471', 'Silvus StreamCaster 4200', 'Radio / Silvus',
        'radio_tactical');
    item('SILV-4472', 'Silvus StreamCaster 4200', 'Radio / Silvus',
        'radio_tactical');
    item('HARR-2093', 'L3Harris Falcon III', 'Radio / L3Harris',
        'radio_handheld');
    item('HARR-1630', 'L3Harris AN/PRC-163', 'Radio / L3Harris',
        'radio_handheld');
    item('LRF-0781', 'Laser Rangefinder PLRF-25', 'Laser',
        'laser_rangefinder');
    item('LD-0330', 'Ground Laser Designator', 'Laser', 'laser_designator');
    item('THM-2210', 'Thermal Camera Hti-301', 'Optics', 'thermal_camera');
    item('NVG-0917', 'Night Vision Goggles PVS-31', 'Optics', 'nvg');
    item('TLS-6102', 'Impact Driver Kit', 'Tools', 'impact_driver');
    item('LAP-3355', 'Rugged Laptop', 'Computing', 'rugged_laptop');
    item('GEN-1180', 'Portable Generator 2kW', 'Power', 'generator');
    item('BAT-7740', 'BB-2590 Battery Pack (x4)', 'Power', 'battery_pack');
    // The boss. Category Dog, sub-category Aussie — checked out more
    // than everything else in the building combined.
    _items.add({
      'serial': 'GOOD-BOY-1',
      'serial_norm': normSerial('GOOD-BOY-1'),
      'name': 'Cooper',
      'type': 'Dog / Aussie',
      'notes': 'Chief Morale Officer. Belly rubs due on return.',
      'photo': _asset('cooper'),
    });

    final now = DateTime.now();
    void tx(DateTime t, String member, String serial, String action,
        {int unmatched = 0}) {
      final it = _byNorm(normSerial(serial));
      _txs.add({
        'id': _nextTxId++,
        'ts': _fmtTs(t),
        'member': member,
        'serial': serial.toUpperCase(),
        'serial_norm': normSerial(serial),
        'item_name': unmatched == 1 ? '' : (it?['name'] as String? ?? ''),
        'action': action,
        'unmatched': unmatched,
        'resolved': 0,
        'photo': '',
        'prev_serial': '',
        'prev_action': '',
      });
    }

    // A little history so the log and board feel lived-in.
    tx(now.subtract(const Duration(days: 1, hours: 5)), 'Maria Santos',
        'THM-2210', 'check_out');
    tx(now.subtract(const Duration(days: 1, hours: 2)), 'Maria Santos',
        'THM-2210', 'check_in');
    tx(now.subtract(const Duration(hours: 26)), 'Alex Rivera', 'TLS-6102',
        'check_out');
    tx(now.subtract(const Duration(hours: 3, minutes: 12)), 'Jordan Lee',
        'SILV-4472', 'check_out');
    // A typo'd serial Sam couldn't match — waiting on staff.
    tx(now.subtract(const Duration(minutes: 47)), 'Sam Patel', 'HARR-2O93',
        'check_out',
        unmatched: 1);
  }

  Map<String, Object?>? _byNorm(String norm) {
    for (final it in _items) {
      if (it['serial_norm'] == norm) return it;
    }
    return null;
  }

  Map<String, Object?>? _lastStateTx(String norm) {
    Map<String, Object?>? last;
    for (final t in _txs) {
      if (t['serial_norm'] == norm && t['unmatched'] == 0) last = t;
    }
    return last;
  }

  @override
  Future<List<String>> members() async => [..._members]..sort();

  @override
  Future<List<Map<String, Object?>>> itemsRaw() async =>
      [for (final it in _items) Map<String, Object?>.from(it)]
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

  @override
  Future<List<Map<String, Object?>>> itemsWithStatus() async {
    final out = <Map<String, Object?>>[];
    for (final it in await itemsRaw()) {
      final last = _lastStateTx(it['serial_norm'] as String);
      if (last != null && last['action'] == 'check_out') {
        it['status'] = 'out';
        it['holder'] = last['member'];
        it['since'] = last['ts'];
      } else {
        it['status'] = 'in';
        it['holder'] = '';
        it['since'] = '';
      }
      out.add(it);
    }
    return out;
  }

  @override
  Future<Map<String, Object?>?> findItem(String serial) async {
    final it = _byNorm(normSerial(serial));
    return it == null ? null : Map<String, Object?>.from(it);
  }

  @override
  Future<PostResult> postTransaction({
    required String member,
    required String serial,
    String photoPath = '',
  }) async {
    if (normSerial(serial).isEmpty) {
      throw ArgumentError('a serial is required to post');
    }
    if (member.trim().isEmpty) {
      throw ArgumentError('a member is required to post');
    }
    final item = _byNorm(normSerial(serial));
    var action = 'check_out';
    if (item != null) {
      final last = _lastStateTx(item['serial_norm'] as String);
      if (last != null && last['action'] == 'check_out') action = 'check_in';
    }
    final id = _nextTxId++;
    _txs.add({
      'id': id,
      'ts': _fmtTs(DateTime.now()),
      'member': member,
      'serial': serial.toUpperCase(),
      'serial_norm': normSerial(serial),
      'item_name': (item?['name'] as String?) ?? '',
      'action': action,
      'unmatched': item == null ? 1 : 0,
      'resolved': 0,
      'photo': photoPath,
      'prev_serial': '',
      'prev_action': '',
    });
    return PostResult(id, action, item == null, (item?['name'] as String?) ?? '');
  }

  @override
  Future<List<Map<String, Object?>>> transactions({int? limit}) async {
    final rows = [for (final t in _txs.reversed) Map<String, Object?>.from(t)];
    return limit == null ? rows : rows.take(limit).toList();
  }

  @override
  Future<int> openFlagCount() async =>
      _txs.where((t) => t['unmatched'] == 1 && t['resolved'] == 0).length;

  @override
  Future<bool> correctTransaction(int id, String serial,
      {String? action}) async {
    if (normSerial(serial).isEmpty) {
      throw ArgumentError('corrected serial must not be blank');
    }
    final t = _txs.where((e) => e['id'] == id).firstOrNull;
    if (t == null) return false;
    final item = _byNorm(normSerial(serial));
    t['prev_serial'] = t['serial'];
    t['prev_action'] = t['action'];
    t['serial'] = serial.toUpperCase();
    t['serial_norm'] = normSerial(serial);
    t['item_name'] = (item?['name'] as String?) ?? '';
    if (action != null) t['action'] = action;
    t['unmatched'] = item == null ? 1 : 0;
    t['resolved'] = item == null ? 0 : 1;
    return item != null;
  }

  @override
  Future<void> resolveTransaction(int id) async {
    final t = _txs.where((e) => e['id'] == id).firstOrNull;
    if (t != null) t['resolved'] = 1;
  }

  @override
  Future<void> upsertItem({
    required String serial,
    required String name,
    String type = '',
    String notes = '',
    String photo = '',
  }) async {
    final norm = normSerial(serial);
    _items.removeWhere((it) => it['serial_norm'] == norm);
    _items.add({
      'serial': serial.toUpperCase(),
      'serial_norm': norm,
      'name': name,
      'type': type,
      'notes': notes,
      'photo': photo,
    });
  }

  @override
  Future<bool> updateItem({
    required String originalNorm,
    required String serial,
    required String name,
    String type = '',
    String notes = '',
    String? photo,
  }) async {
    final newNorm = normSerial(serial);
    if (newNorm != originalNorm && _byNorm(newNorm) != null) return false;
    final it = _byNorm(originalNorm);
    if (it == null) return false;
    it['serial'] = serial.toUpperCase();
    it['serial_norm'] = newNorm;
    it['name'] = name;
    it['type'] = type;
    it['notes'] = notes;
    if (photo != null) it['photo'] = photo;
    return true;
  }

  @override
  Future<void> setItemPhoto(String serialNorm, String photoPath) async {
    final it = _byNorm(serialNorm);
    if (it != null) it['photo'] = photoPath;
  }

  @override
  Future<void> deleteItem(String serialNorm) async {
    _items.removeWhere((it) => it['serial_norm'] == serialNorm);
  }

  @override
  Future<void> addMember(String name) async {
    if (!_members.contains(name)) _members.add(name);
  }

  @override
  Future<void> deleteMember(String name) async {
    _members.remove(name);
  }

  @override
  Future<String> storeItemPhoto(String serialNorm, String srcPath) async =>
      srcPath; // Sim "photos" are preset assets — nothing to copy.

  @override
  Future<String> exportCsv() async {
    final rows = await transactions();
    final buf = StringBuffer(
        'id,time,member,serial,item,action,unmatched,resolved,photo\n');
    for (final r in rows.reversed) {
      String cell(Object? v) {
        var s = csvSafe(v);
        if (s.contains(',') || s.contains('"') || s.contains('\n')) {
          s = '"${s.replaceAll('"', '""')}"';
        }
        return s;
      }

      buf.writeln([
        r['id'],
        r['ts'],
        cell(r['member']),
        cell(r['serial']),
        cell(r['item_name']),
        r['action'],
        r['unmatched'],
        r['resolved'],
        cell(p.basename((r['photo'] as String?) ?? '')),
      ].join(','));
    }
    return buf.toString();
  }
}
