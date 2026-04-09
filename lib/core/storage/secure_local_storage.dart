import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Хранит сессионные токены Supabase в зашифрованном хранилище.
/// Android: EncryptedSharedPreferences / Keystore
/// iOS: Keychain
class SecureLocalStorage extends LocalStorage {
  static const _key = 'supabase_session';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  const SecureLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() async =>
      _storage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) async =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() async =>
      _storage.delete(key: _key);
}
