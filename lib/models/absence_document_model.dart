class AbsenceDocumentModel {
  final int id;
  final String documentType;
  final String title;
  final String? filePath;
  final String? fileUrl;
  final String startDate;
  final String endDate;
  final String status;
  final String? approvedBy;
  final String? notes;

  AbsenceDocumentModel({
    required this.id,
    required this.documentType,
    required this.title,
    this.filePath,
    this.fileUrl,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.approvedBy,
    this.notes,
  });

  factory AbsenceDocumentModel.fromJson(Map<String, dynamic> json) {
    return AbsenceDocumentModel(
      id: json['id'] ?? 0,
      documentType: json['document_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      filePath: json['file_path']?.toString(),
      fileUrl: json['file_url']?.toString(),
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      approvedBy: json['approved_by']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}