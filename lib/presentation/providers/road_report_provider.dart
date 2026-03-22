import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firestore_instance.dart';
import '../../core/services/logger.dart';
import '../../data/models/road_report_model.dart';

class RoadReportProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirestoreInstance.instance;

  List<RoadReport> _reports = [];
  bool _isLoading = false;
  String? _currentPagodaId;

  List<RoadReport> get reports => _reports;
  bool get isLoading => _isLoading;

  Future<void> loadReports(String pagodaId) async {
    _currentPagodaId = pagodaId;
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(AppConstants.roadReports)
          .where('pagodaId', isEqualTo: pagodaId)
          .limit(30)
          .get()
          .timeout(const Duration(seconds: 8));

      final parsed =
          snapshot.docs
              .map((doc) => RoadReport.fromJson(doc.data(), id: doc.id))
              .where((report) => report.isActive)
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _reports = parsed;
    } catch (e, stackTrace) {
      Logger.error('Failed to load road reports', e, stackTrace);
      _reports = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitReport(RoadReport report) async {
    try {
      await _firestore
          .collection(AppConstants.roadReports)
          .doc(report.id)
          .set(report.toJson())
          .timeout(const Duration(seconds: 8));

      if (_currentPagodaId == report.pagodaId) {
        _reports = [report, ..._reports]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to submit road report', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      await _firestore
          .collection(AppConstants.roadReports)
          .doc(reportId)
          .delete()
          .timeout(const Duration(seconds: 8));
      _reports = _reports.where((report) => report.id != reportId).toList();
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('Failed to delete road report', e, stackTrace);
      rethrow;
    }
  }
}
