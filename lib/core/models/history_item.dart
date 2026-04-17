class HistoryItem {
  final String id;
  final String title;
  final String userId;
  final String? email;
  final String industry;
  final String outputType;
  final String result;
  final String input;
  final int createTime;
  final int? updateTime;

  HistoryItem({
    required this.id,
    required this.title,
    required this.userId,
    this.email,
    required this.industry,
    required this.outputType,
    required this.result,
    required this.input,
    required this.createTime,
    this.updateTime,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      userId: json['userId'] as String,
      email: json['email'] as String?,
      industry: json['industry'] as String? ?? '',
      outputType: json['outputType'] as String? ?? '',
      result: json['result'] as String? ?? '',
      input: json['input'] as String? ?? '',
      createTime: json['createTime'] as int,
      updateTime: json['updateTime'] as int?,
    );
  }
}
