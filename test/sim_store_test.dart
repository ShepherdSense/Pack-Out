import 'package:equipment_station/sim_store.dart';
import 'package:equipment_station/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SimStore (web sim demo data)', () {
    test('seeds carry the demo gear room, incl. Cooper under Dog / Aussie',
        () async {
      final s = SimStore();
      final items = await s.itemsWithStatus();
      expect(items.length, 13);
      final cooper = items.singleWhere((i) => i['name'] == 'Cooper');
      expect(cooper['type'], 'Dog / Aussie');
      expect(parseType(cooper['type'] as String), ('Dog', 'Aussie'));
      expect((cooper['photo'] as String), startsWith('asset://'));
      // Every seeded item has a photo from the preset set.
      for (final i in items) {
        expect(i['photo'] as String, startsWith('asset://'),
            reason: '${i['name']} should carry a sim photo');
      }
    });

    test('seeded state: two items out, one open unmatched flag', () async {
      final s = SimStore();
      final items = await s.itemsWithStatus();
      final out = items.where((i) => i['status'] == 'out').toList();
      expect(out.length, 2);
      expect(out.map((i) => i['serial']),
          containsAll(['SILV-4472', 'TLS-6102']));
      expect(await s.openFlagCount(), 1);
    });

    test('posting toggles like the real store; unknown serial flags',
        () async {
      final s = SimStore();
      final r1 = await s.postTransaction(member: 'Alex Rivera', serial: 'LRF-0781');
      expect(r1.action, 'check_out');
      expect(r1.unmatched, isFalse);
      final items = await s.itemsWithStatus();
      expect(items.singleWhere((i) => i['serial'] == 'LRF-0781')['status'],
          'out');
      final r2 = await s.postTransaction(member: 'Alex Rivera', serial: 'LRF-0781');
      expect(r2.action, 'check_in');
      final r3 =
          await s.postTransaction(member: 'Alex Rivera', serial: 'NOPE-999');
      expect(r3.unmatched, isTrue);
      expect(await s.openFlagCount(), 2);
    });

    test('Cooper checks out and back in', () async {
      final s = SimStore();
      final r = await s.postTransaction(member: 'Sam Patel', serial: 'GOOD-BOY-1');
      expect(r.action, 'check_out');
      expect(r.itemName, 'Cooper');
      final back =
          await s.postTransaction(member: 'Sam Patel', serial: 'GOOD-BOY-1');
      expect(back.action, 'check_in');
    });

    test('correction resolves the seeded typo flag with audit preserved',
        () async {
      final s = SimStore();
      final txs = await s.transactions();
      final flag = txs.singleWhere((t) => t['unmatched'] == 1);
      final ok = await s.correctTransaction(flag['id'] as int, 'HARR-2093');
      expect(ok, isTrue);
      expect(await s.openFlagCount(), 0);
      final after = (await s.transactions())
          .singleWhere((t) => t['id'] == flag['id']);
      expect(after['serial'], 'HARR-2093');
      expect(after['prev_serial'], 'HARR-2O93');
      expect(after['item_name'], 'L3Harris Falcon III');
    });

    test('registry edits: clash refused, photo set/clear, csv exports',
        () async {
      final s = SimStore();
      final clash = await s.updateItem(
          originalNorm: 'LRF0781',
          serial: 'SILV-4471',
          name: 'Clash');
      expect(clash, isFalse);
      final ok = await s.updateItem(
          originalNorm: 'LRF0781',
          serial: 'LRF-0781',
          name: 'Laser Rangefinder PLRF-25',
          type: 'Laser',
          photo: 'asset://assets/sim/gear/cooper.jpg');
      expect(ok, isTrue);
      final item = await s.findItem('LRF-0781');
      expect(item!['photo'], 'asset://assets/sim/gear/cooper.jpg');
      final csv = await s.exportCsv();
      expect(csv, contains('SILV-4472'));
      expect(csv, contains('Impact Driver Kit'));
    });
  });
}
