class FaultReportModel {
  final int id;
  final String title;
  final String? description;
  final String status;
  final String? handledBy;
  final String reportDate;
  final String? evidencePath;
  final String? evidenceUrl;
  final String? type; // 'user_report' or 'admin_report'

  FaultReportModel({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.handledBy,
    required this.reportDate,
    this.evidencePath,
    this.evidenceUrl,
    this.type,
  });

  factory FaultReportModel.fromJson(Map<String, dynamic> json) {
    return FaultReportModel(
      id: json['id'] ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? '',
      handledBy: json['handled_by']?.toString(),
      reportDate: json['report_date']?.toString() ?? '',
      evidencePath: json['evidence_path']?.toString(),
      evidenceUrl: json['evidence_url']?.toString(),
      type: json['type']?.toString(),
    );
  }
}