import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'pending_sale.dart';

Future<PendingSaleStore> createPendingSaleStore() async {
  final directory = await getApplicationSupportDirectory();
  return FilePendingSaleStore(
    File('${directory.path}/trexven_pending_sale_v1.json'),
  );
}

class FilePendingSaleStore
    implements PendingSaleStore, LegacyPaymentUpgradeStore {
  final File file;
  FilePendingSaleStore(this.file);

  @override
  Future<PendingSale?> read() async => await file.exists()
      ? PendingSale.decode(await file.readAsString())
      : null;

  @override
  Future<void> save(PendingSale pending) async {
    if (await file.exists()) throw StateError('A pending sale already exists.');
    await file.parent.create(recursive: true);
    // Flush before rename and before any HTTP request. An incomplete temporary
    // file is never read as a submitted transaction; a corrupt final file fails closed.
    final temporary = File('${file.path}.writing');
    await temporary.writeAsString(jsonEncode(pending.toJson()), flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> upgradePayment(
    PendingSale original,
    PendingSale verified,
  ) async {
    final current = await read();
    final before = original.sale.toJsonWithItems();
    final after = verified.sale.toJsonWithItems()
      ..remove('payments')
      ..remove('shift_id');
    final immutable = Map<String, dynamic>.from(before)..remove('shift_id');
    if (current == null ||
        jsonEncode(current.toJson()) != jsonEncode(original.toJson()) ||
        original.sale.payments != null ||
        verified.sale.payments == null ||
        original.userId != verified.userId ||
        jsonEncode(immutable) != jsonEncode(after))
      throw StateError(
        'Original checkout identity and cart must be preserved.',
      );
    final temporary = File('${file.path}.writing');
    await temporary.writeAsString(jsonEncode(verified.toJson()), flush: true);
    // Atomic replacement: never delete the original journal before the new one
    // is flushed. A failed replacement leaves the original recoverable.
    await temporary.rename(file.path);
  }

  @override
  Future<void> acknowledge(String requestId) async {
    final pending = await read();
    if (pending == null) return;
    if (pending.sale.id != requestId)
      throw StateError('Pending request changed.');
    await file.delete();
  }
}
