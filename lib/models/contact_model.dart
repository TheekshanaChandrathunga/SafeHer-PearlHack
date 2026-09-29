class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final String? fcmToken; // populated if the contact also uses SafeHer

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    this.fcmToken,
  });

  factory EmergencyContact.fromMap(String id, Map<String, dynamic> map) {
    return EmergencyContact(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relationship: map['relationship'] ?? 'Contact',
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'fcmToken': fcmToken,
      };
}
