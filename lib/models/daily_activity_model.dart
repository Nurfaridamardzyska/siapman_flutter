class DailyActivityModel {
  final int id;
  final String activityDate;
  final String startTime;
  final String endTime;
  final String title;
  final String description;
  final String status;

  DailyActivityModel({
    required this.id,
    required this.activityDate,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.description,
    required this.status,
  });

  factory DailyActivityModel.fromJson(Map<String, dynamic> json) {
    return DailyActivityModel(
      id: json['id'] as int,
      activityDate: json['activity_date'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }
}
