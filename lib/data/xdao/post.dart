
// Api/getLastPost 的结构
class Post {
  final int id;
  final int resto;
  final String now;
  final String userHash;
  final String name;
  final String email;
  final String title;
  final String content;
  final bool sage;
  final bool admin;
  Post({
    required this.id,
    required this.resto,
    required this.now,
    required this.userHash,
    required this.name,
    required this.email,
    required this.title,
    required this.content,
    required this.sage,
    required this.admin,
  });
  factory Post.fromJson(Map<String, dynamic> json) {
    try {
          return Post(
      id: json['id'] as int,
      resto: json['resto'] as int,
      now: json['now'] as String,
      userHash: json['user_hash'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      sage: json['sage'] as int != 0,
      admin: json['admin'] as int != 0,
    );

    } catch (e) {
      throw ArgumentError('Invalid JSON format');
    }
  }
}
