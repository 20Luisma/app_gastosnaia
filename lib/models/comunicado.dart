import 'dart:convert';

class Comunicado {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Comunicado({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.fileUrl,
    this.fileType,
    this.fileName,
    this.createdAt,
    this.updatedAt,
  });

  factory Comunicado.fromJson(Map<String, dynamic> json) {
    return Comunicado(
      id: json['id'] as String? ?? json['key'] as String? ?? '', // Firebase RTDB key o id
      title: json['title'] as String? ?? '(Sin título)',
      description: json['description'] as String? ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      fileUrl: json['fileUrl'] as String?,
      fileType: json['fileType'] as String?,
      fileName: json['fileName'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'title': title,
      'description': description,
      'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileName': fileName,
    };
    // Sólo incluir id si existe (edición). Para nuevos, PHP genera el uniqid.
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  Comunicado copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? fileUrl,
    String? fileType,
    String? fileName,
  }) {
    return Comunicado(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      fileName: fileName ?? this.fileName,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
    );
  }
}
