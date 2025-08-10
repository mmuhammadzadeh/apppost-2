class Post {
  final int id;
  final String title;
  final String content;

  Post({required this.id, required this.title, required this.content});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
    );
  }
}