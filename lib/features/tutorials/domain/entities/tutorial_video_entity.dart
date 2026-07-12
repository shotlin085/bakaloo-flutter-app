class TutorialVideoEntity {
  const TutorialVideoEntity({
    required this.id,
    required this.title,
    required this.videoId,
    this.language,
  });

  final String id;
  final String title;
  final String videoId;
  final String? language;

  factory TutorialVideoEntity.fromJson(Map<String, dynamic> json) {
    return TutorialVideoEntity(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      videoId: (json['video_id'] ?? json['videoId'] ?? '').toString(),
      language: (json['language'] as String?)?.trim().isNotEmpty == true
          ? json['language'] as String
          : null,
    );
  }

  String get thumbnailUrl => 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
}
