class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String provider;
  final String? accessToken;
  final String? refreshToken;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.provider,
    this.accessToken,
    this.refreshToken,
  });

  String get initials {
    final name = displayName.trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: (j['display_name'] as String?)?.trim().isNotEmpty == true
            ? j['display_name'] as String
            : (j['name'] as String?)?.trim().isNotEmpty == true
                ? j['name'] as String
                : _prefixFromEmail(j['email'] as String),
        photoUrl: j['photo_url'] as String? ?? j['avatar_url'] as String?,
        provider: j['provider'] as String? ?? 'email',
        accessToken: j['access_token'] as String?,
        refreshToken: j['refresh_token'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'photo_url': photoUrl,
        'provider': provider,
      };

  static String _prefixFromEmail(String email) {
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }
}
