class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() {
    return {'username': username, 'password': password};
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
