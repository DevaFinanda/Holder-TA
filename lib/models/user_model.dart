class UserModel {
  final String id;
  final String name;
  final String email;
  final String nik;
  final String? photoUrl;
  final String? phone;
  final String? address;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.nik,
    this.photoUrl,
    this.phone,
    this.address,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      nik: json['nik'] ?? '',
      photoUrl: json['photo_url'],
      phone: json['phone'],
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'nik': nik,
      'photo_url': photoUrl,
      'phone': phone,
      'address': address,
    };
  }

  String get initials {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String get firstName {
    return name.split(' ').first;
  }
}
