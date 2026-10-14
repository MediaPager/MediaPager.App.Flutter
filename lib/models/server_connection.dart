class ServerConnection {
  const ServerConnection({
    required this.id,
    required this.nickname,
    required this.url,
    required this.username,
  });

  final String id;
  final String nickname;
  final String url;
  final String username;

  factory ServerConnection.fromJson(Map<String, dynamic> json) {
    return ServerConnection(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      url: json['url'] as String,
      username: json['username'] as String,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'nickname': nickname,
    'url': url,
    'username': username,
  };

  ServerConnection copyWith({String? nickname, String? url, String? username}) {
    return ServerConnection(
      id: id,
      nickname: nickname ?? this.nickname,
      url: url ?? this.url,
      username: username ?? this.username,
    );
  }
}
