import 'dart:io';

import 'package:equipment_station/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  group('serial helpers', () {
    test('normSerial strips and uppercases', () {
      expect(normSerial(' sn-8847 392 '), 'SN8847392');
    });
    test('fuzzyNorm maps look-alikes', () {
      expect(fuzzyNorm('SN8847392'), '5N8847392');
      expect(fuzzyNorm('LAP662O31'), fuzzyNorm('LAP662031'));
    });
    test('levenshtein basics', () {
      expect(levenshtein('ABC', 'ABC'), 0);
      expect(levenshtein('ABC', 'ABD'), 1);
      expect(levenshtein('', 'ABC'), 3);
    });
  });

  group('closestMatches', () {
    final items = <Map<String, Object?>>[
      {'serial': 'SN8847392', 'serial_norm': 'SN8847392', 'name': 'Thermal Camera'},
      {'serial': 'LAP662031', 'serial_norm': 'LAP662031', 'name': 'Rugged Laptop'},
      {'serial': 'RT551902', 'serial_norm': 'RT551902', 'name': 'Two-Way Radio 1'},
    ];
    test('finds look-alike S/5 confusion first', () {
      final m = closestMatches(items, '5N8847392');
      expect(m.isNotEmpty, isTrue);
      expect(m.first['serial'], 'SN8847392');
    });
    test('finds 1/I confusion', () {
      final m = closestMatches(items, 'LAP66203I');
      expect(m.first['serial'], 'LAP662031');
    });
    test('unrelated serial yields nothing', () {
      expect(closestMatches(items, 'ZZZZ9999'), isEmpty);
    });
    test('very short serials do not crash', () {
      expect(() => closestMatches(items, ''), returnsNormally);
      expect(() => closestMatches(items, 'A'), returnsNormally);
      expect(() => closestMatches(items, 'AB'), returnsNormally);
      expect(closestMatches(items, 'A'), isEmpty);
    });
  });

  group('parseType (category / sub-category)', () {
    test('splits category and sub on the first slash', () {
      expect(parseType('Radio / Silvus'), ('Radio', 'Silvus'));
      expect(parseType('Radio/Silvus'), ('Radio', 'Silvus'));
      expect(parseType('Laser / L3 / Harris'), ('Laser', 'L3 / Harris'));
    });
    test('flat, blank, and ragged types stay reachable', () {
      expect(parseType('Tools'), ('Tools', ''));
      expect(parseType(''), ('Other', ''));
      expect(parseType('   '), ('Other', ''));
      expect(parseType(' / Silvus'), ('Other', 'Silvus'));
    });
  });

  group('featured voice rotation', () {
    test('deterministic for a window', () {
      final a = featuredIndex('check_out', 6200);
      final b = featuredIndex('check_out', 6200);
      expect(a, b);
    });
    test('never repeats the previous window over 120 windows', () {
      for (final kind in ['check_out', 'check_in']) {
        var prev = featuredIndex(kind, 6000);
        for (var w = 6001; w <= 6120; w++) {
          final cur = featuredIndex(kind, w);
          expect(cur, isNot(prev), reason: '$kind window $w repeated');
          prev = cur;
        }
      }
    });
    test('featured line is from the pool', () {
      final line = featuredLine('check_in', DateTime(2026, 10, 22));
      expect(voicePools['check_in']!.contains(line), isTrue);
    });
  });

  group('csvSafe', () {
    test('neutralizes formula-leading cells', () {
      expect(csvSafe('=2+5'), "'=2+5");
      expect(csvSafe('@x'), "'@x");
      expect(csvSafe('Alex'), 'Alex');
    });
  });

  group('Store (on-disk, ffi)', () {
    late Directory tmp;
    late Store store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('equip_store_test');
      Store.debugRootOverride = tmp;
      store = Store();
    });

    tearDown(() async {
      Store.debugRootOverride = null;
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<Map<String, Object?>> statusOf(String serialNorm) async {
      final items = await store.itemsWithStatus();
      return items.firstWhere((i) => i['serial_norm'] == serialNorm);
    }

    test('seeds members and items on create', () async {
      expect(await store.members(), contains('Alex Rivera'));
      expect((await store.itemsRaw()).length, seedItems.length);
    });

    test('check-out then check-in derives status and holder', () async {
      final r1 = await store.postTransaction(
          member: 'Alex Rivera', serial: 'SN8847392', photoPath: '');
      expect(r1.action, 'check_out');
      expect(r1.unmatched, isFalse);
      var st = await statusOf('SN8847392');
      expect(st['status'], 'out');
      expect(st['holder'], 'Alex Rivera');

      final r2 = await store.postTransaction(
          member: 'Alex Rivera', serial: 'SN8847392', photoPath: '');
      expect(r2.action, 'check_in');
      st = await statusOf('SN8847392');
      expect(st['status'], 'in');
    });

    test('unmatched post flags and never bears state', () async {
      final r = await store.postTransaction(
          member: 'Sam Patel', serial: 'NOPE12345', photoPath: '');
      expect(r.unmatched, isTrue);
      expect(await store.openFlagCount(), 1);
      final st = await statusOf('SN8847392');
      expect(st['status'], 'in');
    });

    test('blank serial is refused', () async {
      expect(
        () => store.postTransaction(
            member: 'Sam Patel', serial: '  ', photoPath: ''),
        throwsArgumentError,
      );
    });

    test('correction matches, audits, and can flip the action', () async {
      final r = await store.postTransaction(
          member: 'Sam Patel', serial: 'SN884739X', photoPath: '');
      expect(r.unmatched, isTrue);
      final matched = await store.correctTransaction(r.id, 'SN8847392',
          action: 'check_in');
      expect(matched, isTrue);
      final rows = await store.transactions();
      final row = rows.firstWhere((t) => t['id'] == r.id);
      expect(row['serial'], 'SN8847392');
      expect(row['prev_serial'], 'SN884739X');
      expect(row['prev_action'], 'check_out');
      expect(row['action'], 'check_in');
      expect(row['unmatched'], 0);
      final st = await statusOf('SN8847392');
      expect(st['status'], 'in'); // corrected to check_in bears that state
    });

    test('blank correction is refused and changes nothing', () async {
      final r = await store.postTransaction(
          member: 'Sam Patel', serial: 'NOPE12345', photoPath: '');
      expect(() => store.correctTransaction(r.id, ' '), throwsArgumentError);
      final rows = await store.transactions();
      expect(rows.firstWhere((t) => t['id'] == r.id)['serial'], 'NOPE12345');
    });

    test('resolve keeps unmatched=1 and stays out of status', () async {
      final r = await store.postTransaction(
          member: 'Sam Patel', serial: 'NOPE12345', photoPath: '');
      await store.resolveTransaction(r.id);
      expect(await store.openFlagCount(), 0);
      final rows = await store.transactions();
      final row = rows.firstWhere((t) => t['id'] == r.id);
      expect(row['unmatched'], 1);
      expect(row['resolved'], 1);
    });

    test('keyed edit updates in place and rejects serial theft', () async {
      final ok = await store.updateItem(
          originalNorm: 'RT551902',
          serial: 'RT551902',
          name: 'Two-Way Radio One');
      expect(ok, isTrue);
      var items = await store.itemsRaw();
      expect(items.length, seedItems.length);
      expect(items.firstWhere((i) => i['serial_norm'] == 'RT551902')['name'],
          'Two-Way Radio One');

      final renamed = await store.updateItem(
          originalNorm: 'RT551902', serial: 'RT777000', name: 'Radio Renamed');
      expect(renamed, isTrue);
      items = await store.itemsRaw();
      expect(items.length, seedItems.length);
      expect(items.any((i) => i['serial_norm'] == 'RT777000'), isTrue);
      expect(items.any((i) => i['serial_norm'] == 'RT551902'), isFalse);

      final theft = await store.updateItem(
          originalNorm: 'RT777000',
          serial: 'SN8847392',
          name: 'Thermal Camera Clone');
      expect(theft, isFalse);
      items = await store.itemsRaw();
      expect(items.length, seedItems.length);
      expect(
          items.firstWhere((i) => i['serial_norm'] == 'SN8847392')['name'],
          'Thermal Camera');
    });

    test('item photo: store, attach, keep on plain edit, remove on delete',
        () async {
      final src = File(p.join(tmp.path, 'shot.jpg'));
      await src.writeAsBytes([1, 2, 3, 4]);
      final stored = await store.storeItemPhoto('RT551902', src.path);
      expect(await File(stored).exists(), isTrue);
      expect(p.basename(stored), 'RT551902.jpg');

      final ok = await store.updateItem(
          originalNorm: 'RT551902',
          serial: 'RT551902',
          name: 'Two-Way Radio 1',
          photo: stored);
      expect(ok, isTrue);
      var row = (await store.itemsRaw())
          .firstWhere((i) => i['serial_norm'] == 'RT551902');
      expect(row['photo'], stored);

      // An edit that passes no photo keeps the existing portrait.
      await store.updateItem(
          originalNorm: 'RT551902',
          serial: 'RT551902',
          name: 'Radio Renamed');
      row = (await store.itemsRaw())
          .firstWhere((i) => i['serial_norm'] == 'RT551902');
      expect(row['name'], 'Radio Renamed');
      expect(row['photo'], stored);

      // Deleting the item deletes its portrait file too.
      await store.deleteItem('RT551902');
      expect(await File(stored).exists(), isFalse);
    });

    test('renaming a serial moves its portrait; delete then removes it',
        () async {
      final src = File(p.join(tmp.path, 'shot2.jpg'));
      await src.writeAsBytes([9, 9]);
      final stored = await store.storeItemPhoto('GEN009812', src.path);
      await store.setItemPhoto('GEN009812', stored);
      var row = (await store.itemsRaw())
          .firstWhere((i) => i['serial_norm'] == 'GEN009812');
      expect(row['photo'], stored);

      final ok = await store.updateItem(
          originalNorm: 'GEN009812',
          serial: 'GEN777000',
          name: 'Portable Generator');
      expect(ok, isTrue);
      row = (await store.itemsRaw())
          .firstWhere((i) => i['serial_norm'] == 'GEN777000');
      final moved = row['photo'] as String;
      expect(p.basename(moved), 'GEN777000.jpg');
      expect(await File(moved).exists(), isTrue);
      expect(await File(stored).exists(), isFalse);

      await store.deleteItem('GEN777000');
      expect(await File(moved).exists(), isFalse);
    });

    test('v1 database upgrades in place, items gain an empty photo',
        () async {
      // Build a v1-shaped database at the store's own path first.
      final dbPath = p.join(tmp.path, 'equipment.db');
      final raw = await databaseFactoryFfi.openDatabase(dbPath,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (d, v) async {
                await d.execute(
                    'CREATE TABLE members (id INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL)');
                await d.execute(
                    'CREATE TABLE items (serial TEXT PRIMARY KEY, serial_norm TEXT UNIQUE NOT NULL, name TEXT NOT NULL, type TEXT DEFAULT \'\', notes TEXT DEFAULT \'\')');
                await d.execute(
                    'CREATE TABLE transactions (id INTEGER PRIMARY KEY, ts TEXT NOT NULL, member TEXT NOT NULL, serial TEXT NOT NULL, serial_norm TEXT NOT NULL, item_name TEXT DEFAULT \'\', action TEXT NOT NULL, unmatched INTEGER DEFAULT 0, resolved INTEGER DEFAULT 0, photo TEXT DEFAULT \'\', prev_serial TEXT DEFAULT \'\', prev_action TEXT DEFAULT \'\')');
                await d.insert('items', {
                  'serial': 'OLD1',
                  'serial_norm': 'OLD1',
                  'name': 'Legacy Item',
                  'type': '',
                  'notes': '',
                });
              }));
      await raw.close();

      // The store opens it at v2: upgrade runs, data survives, no reseeding.
      final items = await store.itemsRaw();
      expect(items.length, 1);
      expect(items.first['name'], 'Legacy Item');
      expect(items.first['photo'], '');
    });

    test('deleted sample rows stay deleted across reopen', () async {
      for (final m in await store.members()) {
        await store.deleteMember(m);
      }
      expect(await store.members(), isEmpty);
      final reopened = Store();
      expect(await reopened.members(), isEmpty);
    });
  });
}
