class NoticeInfo {
  final String content;
  final int date;
  final bool enable;

  NoticeInfo({required this.content, required this.date, required this.enable});

  factory NoticeInfo.fromJson(Map<String, dynamic> json) {
    return NoticeInfo(
      content: json['content'] as String,
      date: json['date'] as int,
      enable: json['enable'] as bool,
    );
  }
}
