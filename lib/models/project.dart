class Project {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String description;
  final String createdAt;

  Project({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'description': description,
      'created_at': createdAt,
    };
  }

  // factory Project.fromMap - NULL kontrolü ekle

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] ?? '', // 🚨 EKLENDİ: Null kontrolü
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      description: map['description'] ?? '',
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }

  Project copyWith({
    String? name,
    String? phone,
    String? address,
    String? description,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}
