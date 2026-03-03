import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/feedback_model.dart';
import '../../data/datasources/local_datasource.dart';
import '../../core/services/firestore_instance.dart';
import '../../core/services/logger.dart';

class FeedbackProvider extends ChangeNotifier {
  final DatabaseService _db;
  final FirebaseFirestore _firestore = FirestoreInstance.instance;

  List<PagodaFeedback> _feedbacks = [];
  bool _isLoading = false;
  String? _currentPagodaId;

  FeedbackProvider(this._db);

  List<PagodaFeedback> get feedbacks => _feedbacks;
  bool get isLoading => _isLoading;

  double get averageRating {
    if (_feedbacks.isEmpty) return 0;
    final sum = _feedbacks.fold<int>(0, (sum, f) => sum + f.rating);
    return sum / _feedbacks.length;
  }

  int get feedbackCount => _feedbacks.length;

  /// Load feedbacks for a specific pagoda from Firestore, falling back to
  /// local cache.
  Future<void> loadFeedbacks(String pagodaId) async {
    _currentPagodaId = pagodaId;
    _isLoading = true;
    notifyListeners();

    try {
      // Try Firestore first
      final snapshot = await _firestore
          .collection('feedbacks')
          .where('pagodaId', isEqualTo: pagodaId)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 8));

      _feedbacks = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return PagodaFeedback.fromJson(data);
      }).toList();

      // Cache locally, but do not fail remote read if local storage is
      // unavailable (e.g. web runtime).
      for (final feedback in _feedbacks) {
        try {
          await _db.insertFeedback(feedback);
        } catch (_) {}
      }
    } catch (e) {
      Logger.error('Failed to load feedbacks from Firestore, using local', e);
      // Fallback to local
      try {
        _feedbacks = await _db.getFeedbacksForPagoda(pagodaId);
      } catch (localError) {
        Logger.error('Failed to load local feedbacks', localError);
        _feedbacks = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit feedback to Firestore and cache locally.
  Future<void> submitFeedback(PagodaFeedback feedback) async {
    try {
      // Upload to Firestore
      await _firestore
          .collection('feedbacks')
          .doc(feedback.id)
          .set(feedback.toJson())
          .timeout(const Duration(seconds: 8));

      // Cache locally
      try {
        await _db.insertFeedback(feedback);
      } catch (_) {}

      // Refresh list if same pagoda
      if (_currentPagodaId == feedback.pagodaId) {
        _feedbacks.insert(0, feedback);
        notifyListeners();
      }
    } catch (e) {
      Logger.error('Failed to submit feedback', e);
      // Still cache locally even if Firestore fails.
      var cachedLocally = false;
      try {
        await _db.insertFeedback(feedback);
        cachedLocally = true;
        if (_currentPagodaId == feedback.pagodaId) {
          _feedbacks.insert(0, feedback);
          notifyListeners();
        }
      } catch (_) {
        cachedLocally = false;
      }

      // Consider it successful if we could at least persist locally.
      if (!cachedLocally) {
        rethrow;
      }
    }
  }

  /// Delete feedback from Firestore and local cache.
  Future<void> deleteFeedback(String feedbackId) async {
    try {
      await _firestore
          .collection('feedbacks')
          .doc(feedbackId)
          .delete()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      Logger.error('Failed to delete feedback from Firestore', e);
    }

    try {
      await _db.deleteFeedback(feedbackId);
    } catch (e) {
      Logger.error('Failed to delete local feedback', e);
    }

    _feedbacks.removeWhere((f) => f.id == feedbackId);
    notifyListeners();
  }
}
