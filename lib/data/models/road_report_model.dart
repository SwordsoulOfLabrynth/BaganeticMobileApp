import 'package:cloud_firestore/cloud_firestore.dart';

class RoadReport {
  static const String statusActive = 'active';

  final String id;
  final String pagodaId;
  final String pagodaName;
  final String reporterUserId;
  final String category;
  final String severity;
  final String note;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;

  const RoadReport({
    required this.id,
    required this.pagodaId,
    required this.pagodaName,
    required this.reporterUserId,
    required this.category,
    required this.severity,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  bool get isActive =>
      status == statusActive && expiresAt.isAfter(DateTime.now());

  factory RoadReport.fromJson(Map<String, dynamic> json, {String? id}) {
    return RoadReport(
      id: id ?? json['id'] as String? ?? '',
      pagodaId: json['pagodaId'] as String? ?? '',
      pagodaName: json['pagodaName'] as String? ?? '',
      reporterUserId: json['reporterUserId'] as String? ?? '',
      category: json['category'] as String? ?? 'unsafe_lane',
      severity: json['severity'] as String? ?? 'medium',
      note: json['note'] as String? ?? '',
      status: json['status'] as String? ?? statusActive,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      expiresAt: _parseDate(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pagodaId': pagodaId,
      'pagodaName': pagodaName,
      'reporterUserId': reporterUserId,
      'category': category,
      'severity': severity,
      'note': note,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
