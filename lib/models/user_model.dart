class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? race;
  final String role; // 'admin' or 'user'
  final DateTime createdAt;
  final bool? isEmailVerified;
  final bool? isPhoneVerified;
  final bool? isICVerified;
  final bool? isLicenseVerified;
  final String? photoUrl;

  /// For user: all fields required. For admin: only fullName, email, role, uid, createdAt required.
  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.race,
    required this.role,
    required this.createdAt,
    this.isEmailVerified,
    this.isPhoneVerified,
    this.isICVerified,
    this.isLicenseVerified,
    this.photoUrl,
  });

  /// Named constructor for admin
  factory UserModel.admin({
    required String uid,
    required String fullName,
    required String email,
    required String role,
    required DateTime createdAt,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName,
      email: email,
      phone: null,
      dateOfBirth: null,
      gender: null,
      race: null,
      role: role,
      createdAt: createdAt,
      isEmailVerified: null,
      isPhoneVerified: null,
      isICVerified: null,
      isLicenseVerified: null,
      photoUrl: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'race': race,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      if (isEmailVerified != null) 'isEmailVerified': isEmailVerified,
      if (isPhoneVerified != null) 'isPhoneVerified': isPhoneVerified,
      if (isICVerified != null) 'isICVerified': isICVerified,
      if (isLicenseVerified != null) 'isLicenseVerified': isLicenseVerified,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      dateOfBirth: map['dateOfBirth'] != null ? DateTime.tryParse(map['dateOfBirth']) : null,
      gender: map['gender'],
      race: map['race'],
      role: map['role'] ?? 'user',
      createdAt: DateTime.parse(map['createdAt']),
      isEmailVerified: map.containsKey('isEmailVerified') ? map['isEmailVerified'] : null,
      isPhoneVerified: map.containsKey('isPhoneVerified') ? map['isPhoneVerified'] : null,
      isICVerified: map.containsKey('isICVerified') ? map['isICVerified'] : null,
      isLicenseVerified: map.containsKey('isLicenseVerified') ? map['isLicenseVerified'] : null,
      photoUrl: map['photoUrl'],
    );
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? race,
    String? role,
    DateTime? createdAt,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    bool? isICVerified,
    bool? isLicenseVerified,
    String? photoUrl,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      race: race ?? this.race,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isICVerified: isICVerified ?? this.isICVerified,
      isLicenseVerified: isLicenseVerified ?? this.isLicenseVerified,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
} 