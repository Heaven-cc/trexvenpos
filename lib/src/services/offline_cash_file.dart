import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'offline_cash_queue.dart';
import 'package:trexven_operations/src/encrypted_state_native.dart';

Future<OfflineCashQueue> createOfflineCashQueue() async {
  final directory = await getApplicationSupportDirectory();
  final file = File('${directory.path}/trexven_offline_cash_v1.enc');
  return OfflineCashQueue(EncryptedOfflineCashStore(file, () async {
    const storage = FlutterSecureStorage();
    final encoded = await storage.read(key: 'trexven_offline_cash_key_v1');
    if (encoded != null) return SecretKey(base64Decode(encoded));
    if (await file.exists()) throw StateError('Cash encryption key is unavailable. Retain the queue and recover the original device key.');
    final key = await AesGcm.with256bits().newSecretKey();
    await storage.write(key: 'trexven_offline_cash_key_v1', value: base64Encode(await key.extractBytes()));
    return key;
  }));
}

class EncryptedOfflineCashStore implements OfflineCashStore {
  final EncryptedStateFile state;
  EncryptedOfflineCashStore(File file, Future<SecretKey> Function() key):
    state=EncryptedStateFile(file,key,aad:'TREXVEN_OFFLINE_CASH_V1');
  @override
  Future<Map<String,dynamic>> readState()=>state.read();
  @override
  Future<T> mutate<T>(T Function(Map<String,dynamic>) change)=>state.mutate(change);
}
