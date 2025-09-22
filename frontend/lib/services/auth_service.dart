import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../services/api_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';

  final ApiService _apiService = ApiService();
  User? _currentUser;
  String? _token;

  // シングルトンパターン
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null && _currentUser != null;

  Future<void> initialize() async {
    await _loadUserFromStorage();
  }

  Future<bool> login(String email, String password) async {
    try {
      final request = LoginRequest(email: email, password: password);
      final response = await _apiService.login(request);
      
      await _saveUserToStorage(response.token, response.user);
      _token = response.token;
      _currentUser = response.user;
      _apiService.setToken(response.token);
      
      return true;
    } catch (e) {
      throw Exception('ログインに失敗しました: $e');
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      final request = RegisterRequest(name: name, email: email, password: password);
      await _apiService.register(request);
      
      // 登録後は自動ログインは行わず、ログイン画面に戻る
      return true;
    } catch (e) {
      throw Exception('登録に失敗しました: $e');
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await _apiService.logout();
      }
    } catch (e) {
      // ログアウトAPIエラーは無視（トークンは削除する）
    }
    
    await _clearUserFromStorage();
    _token = null;
    _currentUser = null;
    _apiService.clearToken();
  }

  Future<void> deleteAccount() async {
    try {
      await _apiService.deleteAccount();
      await _clearUserFromStorage();
      _token = null;
      _currentUser = null;
      _apiService.clearToken();
    } catch (e) {
      throw Exception('アカウント削除に失敗しました: $e');
    }
  }

  Future<void> _saveUserToStorage(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_userIdKey, user.id);
    await prefs.setString(_userNameKey, user.name);
    await prefs.setString(_userEmailKey, user.email);
  }

  Future<void> _loadUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getInt(_userIdKey);
    final userName = prefs.getString(_userNameKey);
    final userEmail = prefs.getString(_userEmailKey);

    if (token != null && userId != null && userName != null && userEmail != null) {
      _token = token;
      _currentUser = User(
        id: userId,
        name: userName,
        email: userEmail,
        isLocked: false,
        isAdmin: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _apiService.setToken(token);
    }
  }

  Future<void> _clearUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
  }
}