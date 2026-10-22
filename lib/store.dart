import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// ---------- Serial helpers (ported 1:1 from the Windows edition's server.py) ----------

String normSerial(String s) =>
    s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

const _lookalike = {
  'O': '0',
  'Q': '0',
  'I': '1',
  'L': '1',
  'S': '5',
  'B': '8',
  'Z': '2',
  'G': '6',
};

String fuzzyNorm(String s) {
  final n = normSerial(s);
  final buf = StringBuffer();
  for (final ch in n.split('')) {
    buf.write(_lookalike[ch] ?? ch);
  }
  return buf.toString();
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = <int>[i];
    for (var j = 1; j <= b.length; j++) {
      cur.add([
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      ].reduce((x, y) => x < y ? x : y));
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Exact-lookalike matches first, then small edit distance (0/O, 1/I…).
/// Powers the "closest matches" suggestions when a typed serial misses.
List<Map<String, Object?>> closestMatches(
  List<Map<String, Object?>> items,
  String serial, {
  int limit = 5,
}) {
  if (serial.isEmpty) return [];
  final fn = fuzzyNorm(serial);
  final n = normSerial(serial);
  final scored = <(int, Map<String, Object?>)>[];
  for (final it in items) {
    final inorm = it['serial_norm'] as String;
    final ifn = fuzzyNorm(inorm);
    int score;
    if (inorm == n) {
      score = 0;
    } else if (ifn == fn) {
      score = 1;
    } else {
      final d = levenshtein(fn, ifn);
      var prefixLen = fn.length - 2 < 3 ? 3 : fn.length - 2;
      if (prefixLen > fn.length) prefixLen = fn.length;
      if (d > 2 && !ifn.startsWith(fn.substring(0, prefixLen))) continue;
      score = 10 + d;
    }
    scored.add((score, it));
  }
  scored.sort((a, b) => a.$1.compareTo(b.$1));
  return scored.take(limit).map((e) => e.$2).toList();
}

/// The registry "type" text carries the station's browse hierarchy:
/// "Category" or "Category / Sub-category" (e.g. "Radio / Silvus").
/// Splits on the FIRST slash; a blank type files under "Other" so no
/// item is ever unreachable from the category browser.
(String, String) parseType(String type) {
  final t = type.trim();
  if (t.isEmpty) return ('Other', '');
  final i = t.indexOf('/');
  if (i < 0) return (t, '');
  final cat = t.substring(0, i).trim();
  final sub = t.substring(i + 1).trim();
  return (cat.isEmpty ? 'Other' : cat, sub);
}

String csvSafe(Object? v) {
  final s = '${v ?? ''}';
  if (s.isNotEmpty && '=+-@'.contains(s[0])) return "'$s";
  return s;
}

// ---------- Voice pools + featured rotation (ported from server.py) ----------

class VoiceLine {
  final String file;
  final String text;
  const VoiceLine(this.file, this.text);
}

const voicePools = <String, List<VoiceLine>>{
  'check_out': [
    VoiceLine('checkout.mp3',
        'Hell yeah brother, now get out there and do somethin awesome!!!'),
    VoiceLine('checkout_2.mp3',
        "That's what I'm talkin' about — go make it happen, brother!"),
    VoiceLine(
        'checkout_3.mp3', "Somebody's fixin' to get some work DONE today!"),
    VoiceLine('checkout_4.mp3', "Go on then! Show 'em how it's done!"),
    VoiceLine('checkout_5.mp3',
        "Well butter my biscuit, somebody's clockin' in to do WORK!"),
    VoiceLine('checkout_6.mp3',
        "Brother, you know what time it is? It's time to lock the fuck in... I said it's time to lock the FUCK INNNNNNN!!!"),
  ],
  'check_in': [
    VoiceLine('checkin.mp3', "My man!!! I knew you'd be back!"),
    VoiceLine('checkin_2.mp3', "There he is! Knew you couldn't stay away!"),
    VoiceLine(
        'checkin_3.mp3', 'Welcome back, brother — and right on time!'),
    VoiceLine('checkin_4.mp3',
        'My man! Brought her back safe, just like I knew you would!'),
    VoiceLine(
        'checkin_5.mp3', 'Lord have mercy, look who rolled back in!'),
  ],
};

const rotateDays = 3;
final _featuredCache = <String, Map<int, int>>{};

int _hashIdx(String kind, int window, int n) {
  final digest = sha256.convert(utf8.encode('equip-voice:$kind:$window'));
  final b = digest.bytes;
  return ((b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]) % n;
}

int featuredIndex(String kind, int window) {
  final cache = _featuredCache.putIfAbsent(kind, () => {});
  if (cache.containsKey(window)) return cache[window]!;
  final n = voicePools[kind]!.length;
  var start = cache.isEmpty ? 0 : cache.keys.reduce((a, b) => a > b ? a : b) + 1;
  int? prev = cache[start - 1];
  for (var w = start; w <= window; w++) {
    var idx = _hashIdx(kind, w, n);
    if (prev != null && idx == prev) idx = (idx + 1) % n;
    cache[w] = idx;
    prev = idx;
  }
  return cache[window]!;
}

int currentWindow([DateTime? now]) {
  final t = now ?? DateTime.now();
  final today = DateTime.utc(t.year, t.month, t.day);
  return today.difference(DateTime.utc(1970, 1, 1)).inDays ~/ rotateDays;
}

VoiceLine featuredLine(String kind, [DateTime? now]) =>
    voicePools[kind]![featuredIndex(kind, currentWindow(now))];

DateTime nextRotation([DateTime? now]) {
  final w = currentWindow(now);
  return DateTime.utc(1970, 1, 1).add(Duration(days: (w + 1) * rotateDays));
}

// ---------- Store ----------

const seedMembers = ['Alex Rivera', 'Jordan Lee', 'Maria Santos', 'Sam Patel'];
const seedItems = <(String, String, String, String)>[
  ('SN8847392', 'Thermal Camera', 'Optics', 'Sample item - replace with your real gear'),
  ('RT551902', 'Two-Way Radio 1', 'Radio / Silvus', 'Sample item - replace with your real gear'),
  ('TBX104477', 'Impact Driver Kit', 'Tools', 'Sample item - replace with your real gear'),
  ('LAP662031', 'Rugged Laptop', 'Computing', 'Sample item - replace with your real gear'),
  ('GEN009812', 'Portable Generator', 'Power', 'Sample item - replace with your real gear'),
];

class PostResult {
  final int id;
  final String action; // check_out | check_in
  final bool unmatched;
  final String itemName;
  const PostResult(this.id, this.action, this.unmatched, this.itemName);
}

class Store {
  Database? _db;
  Directory? _photosDir;
  Directory? _itemPhotosDir;

  /// Test hook: when set, the database and photos live under this directory
  /// instead of the app's documents directory.
  static Directory? debugRootOverride;

  /// Transaction evidence photos (v1 era serial-plate shots, kept for the
  /// history they belong to).
  Directory get photosDir => _photosDir!;

  /// One portrait photo per registry item — the item's icon everywhere.
  Directory get itemPhotosDir => _itemPhotosDir!;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final docs =
        debugRootOverride ?? await getApplicationDocumentsDirectory();
    _photosDir = Directory(p.join(docs.path, 'photos'));
    await _photosDir!.create(recursive: true);
    _itemPhotosDir = Directory(p.join(docs.path, 'item_photos'));
    await _itemPhotosDir!.create(recursive: true);
    _db = await openDatabase(
      p.join(docs.path, 'equipment.db'),
      // v2: items gain a photo column (the item's portrait/icon). Existing
      // installs upgrade in place — registry, roster, log, and settings
      // all carry over; the column just starts empty.
      version: 2,
      onCreate: (d, v) async {
        await d.execute(
            'CREATE TABLE members (id INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL)');
        await d.execute(
            'CREATE TABLE items (serial TEXT PRIMARY KEY, serial_norm TEXT UNIQUE NOT NULL, name TEXT NOT NULL, type TEXT DEFAULT \'\', notes TEXT DEFAULT \'\', photo TEXT DEFAULT \'\')');
        await d.execute(
            'CREATE TABLE transactions (id INTEGER PRIMARY KEY, ts TEXT NOT NULL, member TEXT NOT NULL, serial TEXT NOT NULL, serial_norm TEXT NOT NULL, item_name TEXT DEFAULT \'\', action TEXT NOT NULL, unmatched INTEGER DEFAULT 0, resolved INTEGER DEFAULT 0, photo TEXT DEFAULT \'\', prev_serial TEXT DEFAULT \'\', prev_action TEXT DEFAULT \'\')');
        // Seed exactly once, at database creation — never resurrect sample
        // rows that staff deliberately deleted later.
        await _seed(d);
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await d.execute(
              'ALTER TABLE items ADD COLUMN photo TEXT DEFAULT \'\'');
        }
      },
    );
    return _db!;
  }

  /// Copy a freshly captured photo into the item-photo store, named by the
  /// item's normalized serial (a retake overwrites the previous portrait).
  /// Returns the stored path to save on the item row.
  Future<String> storeItemPhoto(String serialNorm, String srcPath) async {
    await db; // ensures the directories exist
    final dest = File(p.join(_itemPhotosDir!.path, '$serialNorm.jpg'));
    await File(srcPath).copy(dest.path);
    return dest.path;
  }

  Future<void> _seed(Database d) async {
    final mc = Sqflite.firstIntValue(
        await d.rawQuery('SELECT COUNT(*) c FROM members'));
    if (mc == 0) {
      for (final m in seedMembers) {
        await d.insert('members', {'name': m},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    final ic = Sqflite.firstIntValue(
        await d.rawQuery('SELECT COUNT(*) c FROM items'));
    if (ic == 0) {
      for (final (s, n, t, no) in seedItems) {
        await d.insert(
            'items',
            {
              'serial': s,
              'serial_norm': normSerial(s),
              'name': n,
              'type': t,
              'notes': no,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<List<String>> members() async {
    final d = await db;
    final rows = await d.query('members', orderBy: 'name');
    return [for (final r in rows) r['name'] as String];
  }

  Future<List<Map<String, Object?>>> itemsRaw() async {
    final d = await db;
    return d.query('items', orderBy: 'name');
  }

  /// Items with derived status: latest state-bearing (unmatched=0) transaction.
  Future<List<Map<String, Object?>>> itemsWithStatus() async {
    final d = await db;
    final items = await itemsRaw();
    final out = <Map<String, Object?>>[];
    for (final it in items) {
      final m = Map<String, Object?>.from(it);
      final last = await d.query('transactions',
          where: 'serial_norm=? AND unmatched=0',
          whereArgs: [it['serial_norm']],
          orderBy: 'id DESC',
          limit: 1);
      if (last.isNotEmpty && last.first['action'] == 'check_out') {
        m['status'] = 'out';
        m['holder'] = last.first['member'];
        m['since'] = last.first['ts'];
      } else {
        m['status'] = 'in';
        m['holder'] = '';
        m['since'] = '';
      }
      out.add(m);
    }
    return out;
  }

  Future<Map<String, Object?>?> findItem(String serial) async {
    final d = await db;
    final rows = await d.query('items',
        where: 'serial_norm=?', whereArgs: [normSerial(serial)], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

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
    final d = await db;
    final item = await findItem(serial);
    var action = 'check_out';
    if (item != null) {
      final last = await d.query('transactions',
          where: 'serial_norm=? AND unmatched=0',
          whereArgs: [item['serial_norm']],
          orderBy: 'id DESC',
          limit: 1);
      if (last.isNotEmpty && last.first['action'] == 'check_out') {
        action = 'check_in';
      }
    }
    final ts = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final tsStr =
        '${ts.year}-${two(ts.month)}-${two(ts.day)} ${two(ts.hour)}:${two(ts.minute)}:${two(ts.second)}';
    final id = await d.insert('transactions', {
      'ts': tsStr,
      'member': member,
      'serial': serial.toUpperCase(),
      'serial_norm': normSerial(serial),
      'item_name': (item?['name'] as String?) ?? '',
      'action': action,
      'unmatched': item == null ? 1 : 0,
      'photo': photoPath,
    });
    return PostResult(id, action, item == null, (item?['name'] as String?) ?? '');
  }

  Future<List<Map<String, Object?>>> transactions({int? limit}) async {
    final d = await db;
    return d.query('transactions', orderBy: 'id DESC', limit: limit);
  }

  Future<int> openFlagCount() async {
    final d = await db;
    return Sqflite.firstIntValue(await d.rawQuery(
            'SELECT COUNT(*) c FROM transactions WHERE unmatched=1 AND resolved=0')) ??
        0;
  }

  /// Staff correction: set the true serial (and optionally the true action),
  /// preserving the original values for audit. Returns true if now matched.
  Future<bool> correctTransaction(int id, String serial, {String? action}) async {
    if (normSerial(serial).isEmpty) {
      throw ArgumentError('corrected serial must not be blank');
    }
    final d = await db;
    final rows = await d.query('transactions', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return false;
    final old = rows.first;
    final item = await findItem(serial);
    await d.update(
        'transactions',
        {
          'serial': serial.toUpperCase(),
          'serial_norm': normSerial(serial),
          'item_name': (item?['name'] as String?) ?? '',
          'action': action ?? old['action'],
          'unmatched': item == null ? 1 : 0,
          'resolved': item == null ? 0 : 1,
          'prev_serial': old['serial'],
          'prev_action': old['action'],
        },
        where: 'id=?',
        whereArgs: [id]);
    return item != null;
  }

  /// Close the flag WITHOUT making the row state-bearing (unmatched stays 1).
  Future<void> resolveTransaction(int id) async {
    final d = await db;
    await d.update('transactions', {'resolved': 1},
        where: 'id=?', whereArgs: [id]);
  }

  Future<void> upsertItem({
    required String serial,
    required String name,
    String type = '',
    String notes = '',
    String photo = '',
  }) async {
    final d = await db;
    await d.insert(
        'items',
        {
          'serial': serial.toUpperCase(),
          'serial_norm': normSerial(serial),
          'name': name,
          'type': type,
          'notes': notes,
          'photo': photo,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update the item registered under [originalNorm], keyed by that original
  /// normalized serial (an edit must never duplicate the row or REPLACE away
  /// a different item). Returns false when a DIFFERENT item already owns the
  /// new serial — the caller surfaces the conflict and nothing changes.
  Future<bool> updateItem({
    required String originalNorm,
    required String serial,
    required String name,
    String type = '',
    String notes = '',
    String? photo,
  }) async {
    final d = await db;
    final newNorm = normSerial(serial);
    if (newNorm != originalNorm) {
      final clash = await findItem(serial);
      if (clash != null) return false;
    }
    // Portrait files are named by normalized serial. If this edit renames
    // the serial and no new portrait is being set, MOVE the existing file
    // to the new name — otherwise the row would keep pointing at the old
    // name while deleteItem() cleans up by the new one, orphaning it.
    var effectivePhoto = photo;
    if (photo == null && newNorm != originalNorm) {
      final rows = await d.query('items',
          where: 'serial_norm=?', whereArgs: [originalNorm], limit: 1);
      final existing = rows.isEmpty ? '' : (rows.first['photo'] as String?) ?? '';
      final expectedOld = p.join(_itemPhotosDir!.path, '$originalNorm.jpg');
      if (existing == expectedOld) {
        try {
          final oldFile = File(expectedOld);
          if (await oldFile.exists()) {
            final newPath = p.join(_itemPhotosDir!.path, '$newNorm.jpg');
            await oldFile.rename(newPath);
            effectivePhoto = newPath;
          }
        } catch (_) {
          // The rename of the file failed (storage hiccup); leave the
          // stored path as-is rather than fail the whole edit.
        }
      }
    }
    await d.update(
        'items',
        {
          'serial': serial.toUpperCase(),
          'serial_norm': newNorm,
          'name': name,
          'type': type,
          'notes': notes,
          // A null photo means "no new portrait this edit" — keep the old
          // one. A retake passes the freshly stored path.
          'photo': ?effectivePhoto,
        },
        where: 'serial_norm=?',
        whereArgs: [originalNorm]);
    return true;
  }

  /// Attach an already-stored portrait path to an item row. The registry
  /// save flow writes the item first and only touches photo files once
  /// the item write is known to have succeeded.
  Future<void> setItemPhoto(String serialNorm, String photoPath) async {
    final d = await db;
    await d.update('items', {'photo': photoPath},
        where: 'serial_norm=?', whereArgs: [serialNorm]);
  }

  Future<void> deleteItem(String serialNorm) async {
    final d = await db;
    await d.delete('items', where: 'serial_norm=?', whereArgs: [serialNorm]);
    // The portrait goes with the item; history in the log is unaffected.
    try {
      final f = File(p.join(_itemPhotosDir!.path, '$serialNorm.jpg'));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> addMember(String name) async {
    final d = await db;
    await d.insert('members', {'name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> deleteMember(String name) async {
    final d = await db;
    await d.delete('members', where: 'name=?', whereArgs: [name]);
  }

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
