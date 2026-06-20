import 'dart:ui';

class DocumentTypeModel {
  final int id;
  final String name;
  final String code;
  final String category;
  final Color color;
  final bool requiresApproval;
  final bool isRequired;

  DocumentTypeModel({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.color,
    required this.requiresApproval,
    required this.isRequired,
  });

  factory DocumentTypeModel.fromJson(Map<String, dynamic> json) {
    return DocumentTypeModel(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      color: _parseColor(json['color']),
      requiresApproval: json['requires_approval'] == true,
      isRequired: json['is_required'] == true,
    );
  }

  static Color _parseColor(dynamic hexColor) {
    if (hexColor == null || hexColor is! String || hexColor.isEmpty) {
      return const Color(0xFF3B82F6); // Default Blue
    }
    
    String hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }
}
