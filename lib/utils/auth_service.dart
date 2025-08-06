import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Buat instance dari secure storage
  final _storage = const FlutterSecureStorage();
  final _tokenKey = 'auth_token'; // Kunci untuk menyimpan token

  // fake login
  Future<String?> login(String username, String password) async {
    // delay dikit biar kaya login asli
    await Future.delayed(const Duration(milliseconds: 1500));

    // nantinya logic disini digantikan dengan logic auth yang sebenarnya
    if (username.isNotEmpty && password == 'password') {
      final mockToken = 'mock_token_for_${username}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Simpan token ke secure storage
      await saveToken(mockToken);
      
      return mockToken;
    } else {
      // Kembalikan null jika login gagal
      return null;
    }
  }

  // Fungsi untuk menyimpan token
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Fungsi untuk mendapatkan token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // logout (menghapus token)
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  // Fungsi untuk memeriksa apakah pengguna sudah login
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
