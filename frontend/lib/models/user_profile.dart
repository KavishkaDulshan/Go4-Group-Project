class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };
}
