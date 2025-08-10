class User {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final int isActive;
  final DateTime createdAt;
  final String? token; // این فیلد Nullable است
  final bool? isOnline;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.token, // این فیلد اختیاری است
    this.isOnline,
    this.lastSeen,
  });

  // سازنده برای زمانی که کاربر لاگین می‌شود و توکن دارد
  factory User.fromLoginJson(Map<String, dynamic> json, String token) {
    return User(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json.containsKey('full_name') ? json['full_name'] : '',
      role: json['role'] ?? '',
      isActive: int.tryParse(json['is_active']?.toString() ?? '0') ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      token: token,
      isOnline: json['is_online'] == 1 || json['is_online'] == true,
      lastSeen: DateTime.tryParse(
            (json['last_seen'] ?? json['last_active'])?.toString() ?? '',
          ),
    );
  }

  // سازنده برای لیست کاربران (بدون توکن)
  factory User.fromListJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json.containsKey('full_name') ? json['full_name'] ?? '' : '',
      role: json['role'] ?? '',
      isActive: int.tryParse(json['is_active']?.toString() ?? '0') ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      // token اینجا null می‌ماند
      isOnline: json['is_online'] == 1 || json['is_online'] == true,
      lastSeen: DateTime.tryParse(
            (json['last_seen'] ?? json['last_active'])?.toString() ?? '',
          ),
    );
  }
}

extension UserJson on User {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'token': token,
      'is_online': (isOnline ?? false) ? 1 : 0,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  static User fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json.containsKey('full_name') ? json['full_name'] ?? '' : '',
      role: json['role'] ?? '',
      isActive: int.tryParse(json['is_active']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      token: json['token']?.toString(),
      isOnline: json['is_online'] == 1 || json['is_online'] == true,
      lastSeen: DateTime.tryParse(json['last_seen']?.toString() ?? ''),
    );
  }
}
