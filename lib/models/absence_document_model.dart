import 'dart:ui';

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
  final String? rejectedBy;
  final String? decisionNotes;
  final String? decidedAt;
  final String? notes;
  final Color? color;

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
    this.rejectedBy,
    this.decisionNotes,
    this.decidedAt,
    this.notes,
    this.color,
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
      rejectedBy: json['rejected_by']?.toString(),
      decisionNotes: json['decision_notes']?.toString(),
      decidedAt: json['decided_at']?.toString(),
      notes: json['notes']?.toString(),
      color: _parseColor(json['color']),
    );
  }

  static Color? _parseColor(dynamic hexColor) {
    if (hexColor == null || hexColor is! String || hexColor.isEmpty) {
      return null;
    }

    String hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }
}