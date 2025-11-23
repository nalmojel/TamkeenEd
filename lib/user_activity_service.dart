import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserActivityService {
  static DatabaseReference _getDatabaseReference() {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://tamkeened-8821e-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref();
  }

  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Track document upload
  static Future<void> trackDocumentUpload(
    String documentName,
    String documentId, {
    String category = 'adhd', // default to adhd, can be 'visual' or 'hearing'
  }) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activityRef = dbRef.child('userActivity').child(_currentUserId!);

    // Sanitize document ID
    final sanitizedId = _sanitizeFirebaseKey(documentId);

    // Store document category
    await activityRef.child('documents/$sanitizedId/category').set(category);

    await activityRef
        .child('stats/documentsProcessed')
        .set(ServerValue.increment(1));
    await activityRef
        .child('stats/points')
        .set(ServerValue.increment(10)); // 10 points for uploading

    // Track in recent activities
    await _addRecentActivity(
      'Uploaded document: $documentName',
      'document_upload',
    );
  }

  // Track focus session completion
  static Future<void> trackFocusSession(int durationMinutes) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activityRef = dbRef.child('userActivity').child(_currentUserId!);

    await activityRef
        .child('stats/focusSessions')
        .set(ServerValue.increment(1));
    await activityRef
        .child('stats/studyTimeMinutes')
        .set(ServerValue.increment(durationMinutes));
    await activityRef
        .child('stats/points')
        .set(ServerValue.increment(durationMinutes)); // 1 point per minute

    // Track in recent activities
    await _addRecentActivity(
      'Completed ${durationMinutes}min focus session',
      'focus_session',
    );
  }

  // Helper function to sanitize IDs for Firebase paths
  static String _sanitizeFirebaseKey(String key) {
    // Remove or replace invalid characters: . # $ [ ] /
    // Also encode the key to make it Firebase-safe
    return key
        .replaceAll('/', '_')
        .replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll('\$', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll(' ', '_');
  }

  // Track summary view
  static Future<void> trackSummaryView(
    String documentId,
    String documentName,
  ) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activityRef = dbRef.child('userActivity').child(_currentUserId!);

    // Sanitize document ID for Firebase
    final sanitizedId = _sanitizeFirebaseKey(documentId);

    // Mark document as having summary viewed
    await activityRef.child('documents/$sanitizedId/summaryViewed').set(true);
    await activityRef
        .child('documents/$sanitizedId/documentName')
        .set(documentName);
    await activityRef
        .child('documents/$sanitizedId/lastAccessed')
        .set(DateTime.now().toIso8601String());

    await activityRef
        .child('stats/points')
        .set(ServerValue.increment(5)); // 5 points for reading summary

    // Track in recent activities
    await _addRecentActivity('Viewed summary: $documentName', 'summary_view');
  }

  // Track flashcard progress
  static Future<void> trackFlashcardProgress(
    String documentId,
    String documentName,
    int cardsViewed,
    int totalCards,
  ) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activityRef = dbRef.child('userActivity').child(_currentUserId!);

    // Sanitize document ID for Firebase
    final sanitizedId = _sanitizeFirebaseKey(documentId);

    final progress = totalCards > 0 ? (cardsViewed / totalCards) : 0.0;

    await activityRef.child('documents/$sanitizedId/flashcards').set({
      'viewed': cardsViewed,
      'total': totalCards,
      'progress': progress,
      'documentName': documentName,
      'lastAccessed': DateTime.now().toIso8601String(),
    });

    // Award points based on completion
    if (progress >= 1.0) {
      await activityRef
          .child('stats/points')
          .set(ServerValue.increment(20)); // Bonus for completing all cards
      await _addRecentActivity(
        'Completed all flashcards: $documentName',
        'flashcards_complete',
      );
    }
  }

  // Track visual aid usage
  static Future<void> trackVisualAidUsage(String feature) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activityRef = dbRef.child('userActivity').child(_currentUserId!);

    await activityRef
        .child('stats/visualAidUses')
        .set(ServerValue.increment(1));
    await activityRef
        .child('stats/points')
        .set(ServerValue.increment(2)); // 2 points for using features
  }

  // Track hearing aid usage
  static Future<void> trackHearingAidUsage(String feature) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activityRef = dbRef.child('userActivity').child(_currentUserId!);

    await activityRef
        .child('stats/hearingAidUses')
        .set(ServerValue.increment(1));
    await activityRef
        .child('stats/points')
        .set(ServerValue.increment(2)); // 2 points for using features
  }

  // Track media upload (for hearing aid)
  static Future<void> trackMediaUpload(String mediaName, String mediaId) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activityRef = dbRef.child('userActivity').child(_currentUserId!);

    // Sanitize media ID
    final sanitizedId = _sanitizeFirebaseKey(mediaId);

    // Store document category as hearing
    await activityRef.child('documents/$sanitizedId/category').set('hearing');
    await activityRef
        .child('documents/$sanitizedId/documentName')
        .set(mediaName);

    // Increment document count and hearing aid uses
    await activityRef
        .child('stats/documentsProcessed')
        .set(ServerValue.increment(1));
    await activityRef
        .child('stats/hearingAidUses')
        .set(ServerValue.increment(1));
    await activityRef
        .child('stats/points')
        .set(ServerValue.increment(10)); // 10 points for uploading media

    // Track in recent activities
    await _addRecentActivity('Uploaded media: $mediaName', 'media_upload');
  }

  // Track transcription view (for hearing aid)
  static Future<void> trackTranscriptionView(String mediaName) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activityRef = dbRef.child('userActivity').child(_currentUserId!);

    await activityRef
        .child('stats/hearingAidUses')
        .set(ServerValue.increment(1));
    await activityRef
        .child('stats/points')
        .set(ServerValue.increment(5)); // 5 points for viewing transcription

    // Track in recent activities
    await _addRecentActivity(
      'Viewed transcription: $mediaName',
      'transcription_view',
    );
  }

  // Add recent activity
  static Future<void> _addRecentActivity(String message, String type) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activitiesRef = dbRef
        .child('userActivity')
        .child(_currentUserId!)
        .child('recentActivities');

    final activityData = {
      'message': message,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await activitiesRef.push().set(activityData);
  }

  // Delete document from Firebase
  static Future<void> deleteDocument(String documentId) async {
    if (_currentUserId == null) return;

    final dbRef = _getDatabaseReference();
    final activityRef = dbRef.child('userActivity').child(_currentUserId!);

    // Sanitize document ID for Firebase
    final sanitizedId = _sanitizeFirebaseKey(documentId);

    // Get the document category before deleting
    final docSnapshot = await activityRef.child('documents/$sanitizedId').get();
    String? documentCategory;
    if (docSnapshot.exists) {
      final docData = Map<String, dynamic>.from(docSnapshot.value as Map);
      documentCategory = docData['category'] as String?;
    }

    // Delete document data from Firebase
    await activityRef.child('documents/$sanitizedId').remove();

    // Decrement documents count (don't go below 0)
    final statsSnapshot = await activityRef
        .child('stats/documentsProcessed')
        .get();
    if (statsSnapshot.exists) {
      final currentCount = statsSnapshot.value as int? ?? 0;
      if (currentCount > 0) {
        await activityRef
            .child('stats/documentsProcessed')
            .set(currentCount - 1);
      }
    }

    // Check if there are any remaining documents
    final documentsSnapshot = await activityRef.child('documents').get();
    final hasRemainingDocs =
        documentsSnapshot.exists &&
        (documentsSnapshot.value as Map?)?.isNotEmpty == true;

    // If no documents remain, reset document-related stats to show 0 progress
    if (!hasRemainingDocs) {
      // Reset documents processed to 0
      await activityRef.child('stats/documentsProcessed').set(0);
      // Reset all category usage counts since no documents remain
      await activityRef.child('stats/visualAidUses').set(0);
      await activityRef.child('stats/hearingAidUses').set(0);
    } else if (documentCategory != null) {
      // Check if there are any remaining documents in the same category
      final remainingDocsData = Map<String, dynamic>.from(
        documentsSnapshot.value as Map,
      );

      bool hasCategoryDocs = false;
      for (var docData in remainingDocsData.values) {
        final data = Map<String, dynamic>.from(docData as Map);
        if (data['category'] == documentCategory) {
          hasCategoryDocs = true;
          break;
        }
      }

      // If no documents remain in this category, reset its usage count
      if (!hasCategoryDocs) {
        if (documentCategory == 'visual') {
          await activityRef.child('stats/visualAidUses').set(0);
        } else if (documentCategory == 'hearing') {
          await activityRef.child('stats/hearingAidUses').set(0);
        }
      }
    }

    // Track in recent activities
    await _addRecentActivity('Deleted document', 'document_delete');
  }

  // Get user stats
  static Future<Map<String, dynamic>> getUserStats() async {
    if (_currentUserId == null) {
      return {
        'documentsProcessed': 0,
        'focusSessions': 0,
        'studyTimeMinutes': 0,
        'points': 0,
        'visualAidUses': 0,
        'hearingAidUses': 0,
      };
    }

    final dbRef = _getDatabaseReference();
    final statsRef = dbRef
        .child('userActivity')
        .child(_currentUserId!)
        .child('stats');

    try {
      final snapshot = await statsRef.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return {
          'documentsProcessed': data['documentsProcessed'] ?? 0,
          'focusSessions': data['focusSessions'] ?? 0,
          'studyTimeMinutes': data['studyTimeMinutes'] ?? 0,
          'points': data['points'] ?? 0,
          'visualAidUses': data['visualAidUses'] ?? 0,
          'hearingAidUses': data['hearingAidUses'] ?? 0,
        };
      }
    } catch (e) {
      print('Error getting user stats: $e');
    }

    return {
      'documentsProcessed': 0,
      'focusSessions': 0,
      'studyTimeMinutes': 0,
      'points': 0,
      'visualAidUses': 0,
      'hearingAidUses': 0,
    };
  }

  // Get user documents with progress
  static Future<List<Map<String, dynamic>>> getUserDocumentsProgress() async {
    if (_currentUserId == null) return [];

    final dbRef = _getDatabaseReference();
    final documentsRef = dbRef
        .child('userActivity')
        .child(_currentUserId!)
        .child('documents');

    try {
      final snapshot = await documentsRef.get();
      if (snapshot.exists) {
        final documentsData = Map<String, dynamic>.from(snapshot.value as Map);
        List<Map<String, dynamic>> documents = [];

        documentsData.forEach((docId, docData) {
          final data = Map<String, dynamic>.from(docData as Map);
          documents.add({
            'documentId': docId,
            'documentName': data['documentName'] ?? 'Unknown',
            'summaryViewed': data['summaryViewed'] ?? false,
            'flashcardProgress': data['flashcards']?['progress'] ?? 0.0,
            'flashcardViewed': data['flashcards']?['viewed'] ?? 0,
            'flashcardTotal': data['flashcards']?['total'] ?? 0,
            'lastAccessed':
                data['lastAccessed'] ??
                data['flashcards']?['lastAccessed'] ??
                '',
          });
        });

        // Sort by last accessed
        documents.sort((a, b) {
          final aTime = a['lastAccessed'] as String;
          final bTime = b['lastAccessed'] as String;
          return bTime.compareTo(aTime);
        });

        return documents;
      }
    } catch (e) {
      print('Error getting user documents: $e');
    }

    return [];
  }

  // Get recent activities
  static Future<List<Map<String, dynamic>>> getRecentActivities({
    int limit = 10,
  }) async {
    if (_currentUserId == null) return [];

    final dbRef = _getDatabaseReference();
    final activitiesRef = dbRef
        .child('userActivity')
        .child(_currentUserId!)
        .child('recentActivities');

    try {
      final snapshot = await activitiesRef.limitToLast(limit).get();
      if (snapshot.exists) {
        final activitiesData = Map<String, dynamic>.from(snapshot.value as Map);
        List<Map<String, dynamic>> activities = [];

        activitiesData.forEach((activityId, activityData) {
          final data = Map<String, dynamic>.from(activityData as Map);
          activities.add({
            'id': activityId,
            'message': data['message'] ?? '',
            'type': data['type'] ?? '',
            'timestamp': data['timestamp'] ?? '',
          });
        });

        // Sort by timestamp (newest first)
        activities.sort((a, b) {
          final aTime = a['timestamp'] as String;
          final bTime = b['timestamp'] as String;
          return bTime.compareTo(aTime);
        });

        return activities;
      }
    } catch (e) {
      print('Error getting recent activities: $e');
    }

    return [];
  }

  // Format time ago
  static String formatTimeAgo(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  // Format study time
  static String formatStudyTime(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      }
      return '${hours}h ${remainingMinutes}m';
    }
  }

  // Get feature-specific progress
  static Future<List<Map<String, dynamic>>> getFeatureProgress() async {
    if (_currentUserId == null) return [];

    final stats = await getUserStats();
    final documents = await getUserDocumentsProgress();

    List<Map<String, dynamic>> features = [];

    // ADHD Support Progress
    final adhdDocs = stats['documentsProcessed'] ?? 0;
    final adhdSessions = stats['focusSessions'] ?? 0;
    final adhdStudyTime = stats['studyTimeMinutes'] ?? 0;

    // Show ADHD progress if any activity exists OR if there were previous activities
    if (adhdDocs > 0 || adhdSessions > 0 || documents.isNotEmpty) {
      // Calculate average progress across all documents
      double totalProgress = 0.0;
      int docsWithActivity = 0;

      for (var doc in documents) {
        final summaryViewed = doc['summaryViewed'] ?? false;
        final flashcardProgress = (doc['flashcardProgress'] ?? 0.0) as double;

        // Calculate document progress (30% summary + 70% flashcards)
        double docProgress = 0.0;
        if (summaryViewed) docProgress += 0.3;
        docProgress += flashcardProgress * 0.7;

        if (docProgress > 0) {
          totalProgress += docProgress;
          docsWithActivity++;
        }
      }

      // Average progress across documents with activity
      final progress = docsWithActivity > 0
          ? (totalProgress / docsWithActivity)
          : 0.0;

      // Count how many flashcards viewed across all docs
      int totalFlashcardsViewed = 0;
      int totalFlashcards = 0;
      for (var doc in documents) {
        totalFlashcardsViewed += (doc['flashcardViewed'] ?? 0) as int;
        totalFlashcards += (doc['flashcardTotal'] ?? 0) as int;
      }

      features.add({
        'name': 'ADHD Support',
        'icon': 'psychology',
        'color': 'purple',
        'progress': progress,
        'progressText': totalFlashcards > 0
            ? '$totalFlashcardsViewed/$totalFlashcards flashcards viewed'
            : adhdDocs > 0
            ? '$adhdDocs documents uploaded'
            : 'No documents yet',
        'subtitle':
            '$adhdSessions sessions • ${formatStudyTime(adhdStudyTime)}',
      });
    }

    // Visual Aid Progress
    final visualUses = stats['visualAidUses'] ?? 0;
    // Show Visual Aid if there's any usage OR if there are documents
    if (visualUses > 0 || documents.isNotEmpty) {
      // Progress based on document summaries viewed and TTS usage
      int summariesViewed = 0;
      int totalDocs = documents.length;

      for (var doc in documents) {
        if (doc['summaryViewed'] == true) {
          summariesViewed++;
        }
      }

      // Progress: combination of summaries viewed and usage frequency
      double progress = 0.0;
      if (totalDocs > 0) {
        progress = (summariesViewed / totalDocs) * 0.7; // 70% from summaries
        // Add up to 30% based on usage count (max at 10 uses)
        progress += (visualUses / 10).clamp(0.0, 0.3);
      } else if (visualUses > 0) {
        // Only usage count, no documents
        progress = (visualUses / 10).clamp(0.0, 1.0);
      }
      progress = progress.clamp(0.0, 1.0);

      features.add({
        'name': 'Visual Aid',
        'icon': 'visibility',
        'color': 'blue',
        'progress': progress,
        'progressText': totalDocs > 0
            ? '$summariesViewed/$totalDocs summaries viewed'
            : visualUses > 0
            ? '$visualUses features used'
            : 'No activity yet',
        'subtitle': '$visualUses total uses',
      });
    }

    // Hearing Aid Progress
    final hearingUses = stats['hearingAidUses'] ?? 0;
    if (hearingUses > 0) {
      // Progress based on usage count (progressive scale)
      // 1-3 uses: 0-30%, 4-7 uses: 31-70%, 8+ uses: 71-100%
      double progress = 0.0;
      if (hearingUses <= 3) {
        progress = (hearingUses / 3) * 0.3; // 0-30%
      } else if (hearingUses <= 7) {
        progress = 0.3 + ((hearingUses - 3) / 4) * 0.4; // 31-70%
      } else {
        progress = 0.7 + ((hearingUses - 7) / 10) * 0.3; // 71-100%
        progress = progress.clamp(0.7, 1.0);
      }

      features.add({
        'name': 'Hearing Aid',
        'icon': 'hearing',
        'color': 'green',
        'progress': progress,
        'progressText': '$hearingUses media files processed',
        'subtitle': 'Transcriptions & audio analysis',
      });
    }

    return features;
  }
}
