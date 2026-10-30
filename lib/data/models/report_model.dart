import 'package:cloud_firestore/cloud_firestore.dart';

/// Model lưu dữ liệu báo cáo vi phạm (Module 5 - Safety)
class ReportModel {
  final String? id;
  final String reporterId;
  final String reportedId;
  final String reason;
  final String description;
  final String? screenshotUrl;
  final DateTime? createdAt;

  const ReportModel({
    this.id,
    required this.reporterId,
    required this.reportedId,
    required this.reason,
    this.description = '',
    this.screenshotUrl,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'reporter_id': reporterId,
      'reported_id': reportedId,
      'reason': reason,
      'description': description,
      if (screenshotUrl != null) 'screenshot_url': screenshotUrl,
      'created_at': FieldValue.serverTimestamp(),
      'status': 'pending',
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ReportModel(
      id: docId,
      reporterId: map['reporter_id'] as String? ?? '',
      reportedId: map['reported_id'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      description: map['description'] as String? ?? '',
      screenshotUrl: map['screenshot_url'] as String?,
      createdAt: parseDate(map['created_at']),
    );
  }
}

/// Các lý do báo cáo chuẩn
enum ReportReason {
  spam('Spam / Quảng cáo'),
  inappropriate('Nội dung không phù hợp'),
  fake('Hồ sơ giả mạo'),
  harassment('Quấy rối / Bạo lực'),
  underage('Người dùng dưới tuổi vị thành niên'),
  other('Lý do khác');

  final String label;
  const ReportReason(this.label);
}
