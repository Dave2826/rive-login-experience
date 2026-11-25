class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() {
    return {'username': username, 'password': password};
  }
}

/// Petición de inicio de sesión con el ID Token emitido por Firebase.
///
/// La app no envía identidad ni rol: el backend verifica el token y decide
/// la identidad y los permisos.
class FirebaseLoginRequest {
  final String idToken;

  const FirebaseLoginRequest({required this.idToken});

  Map<String, dynamic> toJson() {
    return {'idToken': idToken};
  }
}

class AuthResponse {
  final String token;

  const AuthResponse({required this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(token: json['token'] as String? ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'token': token};
  }
}
