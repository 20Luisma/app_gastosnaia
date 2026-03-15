import 'dart:convert';

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? colorId;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    this.location = '',
    required this.start,
    required this.end,
    this.allDay = false,
    this.colorId,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '(Sin título)',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      start: DateTime.tryParse(json['start']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      end: DateTime.tryParse(json['end']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      allDay: json['allDay'] as bool? ?? false,
      colorId: json['color']?.toString() ?? json['colorId']?.toString(), // 'color' from API, 'colorId' for creation/update
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'allDay': allDay,
      'colorId': colorId,
    };
  }

  /// Create a copy but overriding selected fields. Use this when mutating.
  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    String? colorId,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      start: start ?? this.start,
      end: end ?? this.end,
      allDay: allDay ?? this.allDay,
      colorId: colorId ?? this.colorId,
    );
  }
}
