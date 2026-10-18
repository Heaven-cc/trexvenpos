import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'durable_state.dart';
export 'durable_state.dart';

Future<DurableState> createOperationState() async {
  final directory = await getApplicationSupportDirectory();
  final file = File('${directory.path}/trexven_operations_v1.enc');
  return EncryptedStateFile(file, () async {
    const storage = FlutterSecureStorage();
    final value = await storage.read(key: 'trexven_operation_key_v1');
    if (value != null) return SecretKey(base64Decode(value));
    if (await file.exists())
      throw StateError(
        'Financial intent key missing. Preserve the original encrypted file.',
      );
    final key = await AesGcm.with256bits().newSecretKey();
    await storage.write(
      key: 'trexven_operation_key_v1',
      value: base64Encode(await key.extractBytes()),
    );
    return key;
  }, aad: 'TREXVEN_OPERATION_V1');
}

class EncryptedStateFile implements DurableState {
  final File file;
  final Future<SecretKey> Function() key;
  final String aad;
  static final Map<String, Future<void>> _locks = {};
  final _cipher = AesGcm.with256bits();
  EncryptedStateFile(this.file, this.key, {required this.aad});
  Future<T> _locked<T>(Future<T> Function() operation) {
    final path = file.absolute.path;
    final next = (_locks[path] ?? Future<void>.value()).then((_) async {
      await file.parent.create(recursive: true);
      final guard = await File('$path.lock').open(mode: FileMode.append);
      await guard.lock(FileLock.exclusive);
      try {
        return await operation();
      } finally {
        await guard.unlock();
        await guard.close();
      }
    });
    _locks[path] = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  Future<Map<String, dynamic>> _read() async {
    if (!await file.exists()) return {'version': 1};
    final box = jsonDecode(await file.readAsString()) as Map;
    if (box['version'] != 1)
      throw StateError('Unknown encrypted state version. Preserve the file.');
    final bytes = await _cipher.decrypt(
      SecretBox(
        base64Decode(box['cipher'] as String),
        nonce: base64Decode(box['nonce'] as String),
        mac: Mac(base64Decode(box['mac'] as String)),
      ),
      secretKey: await key(),
      aad: utf8.encode(aad),
    );
    final state = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(bytes)) as Map,
    );
    if (state['version'] != 1)
      throw StateError('Unknown financial state version.');
    return state;
  }

  @override
  Future<Map<String, dynamic>> read() => _locked(_read);
  @override
  Future<T> mutate<T>(T Function(Map<String, dynamic>) change) =>
      _locked(() async {
        final state = await _read();
        final result = change(state);
        final box = await _cipher.encrypt(
          utf8.encode(jsonEncode(state)),
          secretKey: await key(),
          aad: utf8.encode(aad),
        );
        final temp = File('${file.path}.writing');
        await temp.writeAsString(
          jsonEncode({
            'version': 1,
            'nonce': base64Encode(box.nonce),
            'cipher': base64Encode(box.cipherText),
            'mac': base64Encode(box.mac.bytes),
          }),
          flush: true,
        );
        await temp.rename(file.path);
        return result;
      });
}
