import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudSyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ensures the client has an active Firebase Auth session before read/write operations.
  static Future<void> ensureAuthSession() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      debugPrint('FirebaseAuth session init error: $e');
    }
  }

  /// Listens to live changes on the current user's document in Firestore.
  /// Emits `true` immediately when `is_locked == true` or `account_status == 'locked'`.
  static Stream<bool> streamAccountLockStatus(String section, String mobile) {
    final docId = '${section.trim().toUpperCase()}_${mobile.trim()}';
    return _db.collection('users').doc(docId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() ?? {};
      return data['is_locked'] == true ||
          data['is_blocked'] == true ||
          data['account_status'] == 'locked' ||
          data['account_status'] == 'suspended';
    });
  }

  // =============================================================
  // 1. USER ACCOUNTS & AUTH STATE (users collection)
  // =============================================================

  /// Saves or updates user registration details with subscription and admin lock flags.
  static Future<void> saveAccount(Map<String, dynamic> accountData) async {
    try {
      await ensureAuthSession();

      final String mobile = (accountData['mobile'] ?? '').toString().trim();
      final String section =
          (accountData['section'] ?? 'DEFAULT').toString().trim().toUpperCase();
      if (mobile.isEmpty) return;

      final String docId = '${section}_$mobile';

      await _db.collection('users').doc(docId).set({
        'name': accountData['name'] ?? '',
        'mobile': mobile,
        'email': (accountData['email'] ?? '').toString().trim().toLowerCase(),
        'address': accountData['address'] ?? '',
        'password': accountData['password'] ?? '',
        'section': section,
        // Status, Lock & Subscription Controls
        'is_locked': false, // Toggle to true in Firebase to lock
        'lock_reason':
            'subscription_due', // 'subscription_due' | 'manual_lock' | 'suspended'
        'account_status': 'active', // 'active' | 'locked' | 'suspended'
        'is_blocked': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));

      debugPrint(
          '✅ CloudSync: Registered user account saved under users/$docId');
    } catch (e) {
      debugPrint('❌ CloudSync saveAccount error: $e');
      rethrow;
    }
  }

  /// Searches for an account by mobile or email address.
  static Future<Map<String, dynamic>?> getAccountByIdentifier(
      String identifier) async {
    try {
      await ensureAuthSession();
      final clean = identifier.trim().toLowerCase();

      // 1. Direct query by mobile
      final queryByMobile = await _db
          .collection('users')
          .where('mobile', isEqualTo: clean)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));

      if (queryByMobile.docs.isNotEmpty) {
        return queryByMobile.docs.first.data();
      }

      // 2. Query fallback by email
      final queryByEmail = await _db
          .collection('users')
          .where('email', isEqualTo: clean)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));

      if (queryByEmail.docs.isNotEmpty) {
        return queryByEmail.docs.first.data();
      }
    } catch (e) {
      debugPrint('CloudSyncService getAccountByIdentifier lookup error: $e');
    }
    return null;
  }

  // =============================================================
  // ACCOUNT PURGE, LOCK & DELETION HANDLERS
  // =============================================================

  /// Remotely locks or unlocks a user account with an optional reason.
  static Future<void> setLockStatus({
    required String section,
    required String mobile,
    required bool isLocked,
    String reason = 'subscription_due',
  }) async {
    final docId = '${section.toUpperCase()}_${mobile.trim()}';
    await _db.collection('users').doc(docId).update({
      'is_locked': isLocked,
      'is_blocked': isLocked,
      'lock_reason': reason,
      'account_status': isLocked ? 'locked' : 'active',
      'updated_at': FieldValue.serverTimestamp(),
    });
    debugPrint(
        '🔒 Account $docId lock updated: is_locked=$isLocked, reason=$reason');
  }

  /// Deletes an account document by mobile number across sections.
  static Future<void> deleteAccount(String mobile, {String? section}) async {
    try {
      await ensureAuthSession();
      final clean = mobile.trim();
      if (clean.isEmpty) return;

      if (section != null && section.isNotEmpty) {
        final docId = '${section.toUpperCase()}_$clean';
        await _db
            .collection('users')
            .doc(docId)
            .delete()
            .timeout(const Duration(seconds: 6));
      } else {
        final query = await _db
            .collection('users')
            .where('mobile', isEqualTo: clean)
            .get();
        for (var doc in query.docs) {
          await doc.reference.delete();
        }
      }
      debugPrint('CloudSyncService: Deleted account for $clean');
    } catch (e) {
      debugPrint('CloudSyncService deleteAccount error: $e');
    }
  }

  /// Completely deletes all traces of a user (profile, broker details, and party phonebook).
  static Future<void> purgeUserAccount(String mobile, {String? section}) async {
    try {
      await ensureAuthSession();
      final cleanMobile = mobile.trim();
      if (cleanMobile.isEmpty) return;

      final batch = _db.batch();

      // 1. Delete user document(s)
      if (section != null && section.isNotEmpty) {
        final userRef = _db
            .collection('users')
            .doc('${section.toUpperCase()}_$cleanMobile');
        batch.delete(userRef);
      } else {
        final userDocs = await _db
            .collection('users')
            .where('mobile', isEqualTo: cleanMobile)
            .get();
        for (var doc in userDocs.docs) {
          batch.delete(doc.reference);
        }
      }

      // 2. Delete broker profile if present
      final brokerRef = _db.collection('broker_profiles').doc(cleanMobile);
      batch.delete(brokerRef);

      // 3. Delete master party phonebook entry if present
      final partyRef = _db.collection('parties').doc(cleanMobile);
      batch.delete(partyRef);

      await batch.commit().timeout(const Duration(seconds: 8));
      debugPrint(
          'CloudSyncService: Successfully purged user account data for $cleanMobile');
    } catch (e) {
      debugPrint('CloudSyncService purgeUserAccount error: $e');
    }
  }

  /// Admin Delete User Profile and Associated Records
  static Future<void> deleteUserAccount({
    required String section,
    required String mobile,
  }) async {
    await purgeUserAccount(mobile, section: section);
  }

  /// Updates user profile details, migrates all linked data across Firebase collections,
  /// deletes the old mobile/gmail documents, and guarantees zero duplicate accounts.
  static Future<void> updateProfile({
    required String section,
    required String oldMobile,
    required String newMobile,
    required String oldEmail,
    required String newEmail,
    required String newName,
    required String address,
  }) async {
    try {
      await ensureAuthSession();

      final cleanOldMob = oldMobile.trim();
      final cleanNewMob = newMobile.trim();
      final cleanOldEmail = oldEmail.trim().toLowerCase();
      final cleanNewEmail = newEmail.trim().toLowerCase();
      final cleanSection = section.trim().toUpperCase();

      final oldDocId = '${cleanSection}_$cleanOldMob';
      final newDocId = '${cleanSection}_$cleanNewMob';

      // 1. DUPLICATE CHECK: Verify new mobile or new email isn't already taken by someone else
      if (cleanNewMob != cleanOldMob) {
        final existingMobileDoc =
            await _db.collection('users').doc(newDocId).get();
        if (existingMobileDoc.exists) {
          throw Exception(
              'Mobile number $cleanNewMob is already registered in the $cleanSection section!');
        }
      }

      if (cleanNewEmail.isNotEmpty && cleanNewEmail != cleanOldEmail) {
        final emailQuery = await _db
            .collection('users')
            .where('email', isEqualTo: cleanNewEmail)
            .limit(1)
            .get();
        if (emailQuery.docs.isNotEmpty &&
            emailQuery.docs.first.id != oldDocId) {
          throw Exception(
              'Email $cleanNewEmail is already associated with another account!');
        }
      }

      // 2. FETCH ORIGINAL DATA (Password, Account Status, Timestamps, etc.)
      final oldDocSnapshot = await _db.collection('users').doc(oldDocId).get();
      final oldData = oldDocSnapshot.data() ?? {};

      final batch = _db.batch();

      // 3. ATOMIC WRITE & DELETE
      if (cleanNewMob != cleanOldMob) {
        // Create new document with all credentials preserved
        final newDocRef = _db.collection('users').doc(newDocId);
        batch.set(
            newDocRef,
            {
              ...oldData,
              'name': newName.trim(),
              'mobile': cleanNewMob,
              'email': cleanNewEmail,
              'address': address.trim(),
              'section': cleanSection,
              'account_status': oldData['account_status'] ?? 'active',
              'is_locked': oldData['is_locked'] ?? false,
              'is_blocked': oldData['is_blocked'] ?? false,
              'updated_at': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        // DELETE old document immediately - old mobile & old gmail cannot sign in
        final oldDocRef = _db.collection('users').doc(oldDocId);
        batch.delete(oldDocRef);

        // Migrate broker profile if applicable
        if (cleanSection == 'BROKER') {
          final oldBrokerRef =
              _db.collection('broker_profiles').doc(cleanOldMob);
          final newBrokerRef =
              _db.collection('broker_profiles').doc(cleanNewMob);
          final brokerSnap = await oldBrokerRef.get();
          if (brokerSnap.exists) {
            batch.set(
                newBrokerRef,
                {
                  ...brokerSnap.data()!,
                  'firmName': newName.trim(),
                  'mobile': cleanNewMob,
                  'email': cleanNewEmail,
                  'address': address.trim(),
                  'updated_at': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true));
            batch.delete(oldBrokerRef);
          }
        }
      } else {
        // Mobile remained same, only Gmail/Name/Address changed
        final docRef = _db.collection('users').doc(oldDocId);
        batch.set(
            docRef,
            {
              'name': newName.trim(),
              'email': cleanNewEmail,
              'address': address.trim(),
              'updated_at': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        if (cleanSection == 'BROKER') {
          final brokerRef = _db.collection('broker_profiles').doc(cleanOldMob);
          batch.set(
              brokerRef,
              {
                'firmName': newName.trim(),
                'email': cleanNewEmail,
                'address': address.trim(),
                'updated_at': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }
      }

      await batch.commit().timeout(const Duration(seconds: 10));

      // 4. MIGRATE ALL SAUDA TRANSACTIONS ACROSS COLLECTIONS
      if (cleanNewMob != cleanOldMob) {
        await _transferAllAssociatedSaudas(
          oldMobile: cleanOldMob,
          newMobile: cleanNewMob,
          newName: newName.trim(),
          section: cleanSection,
        );
      }

      debugPrint(
          '✅ CloudSync: Profile migrated cleanly to $newDocId. Old credentials wiped.');
    } catch (e) {
      debugPrint('❌ CloudSync updateProfile error: $e');
      rethrow;
    }
  }

  /// Helper to ensure all transaction records reflect the new mobile number across roles
  static Future<void> _transferAllAssociatedSaudas({
    required String oldMobile,
    required String newMobile,
    required String newName,
    required String section,
  }) async {
    try {
      final saudaBatch = _db.batch();
      bool hasUpdates = false;

      if (section == 'BROKER') {
        final query = await _db
            .collection('saudas')
            .where('brokerMobile', isEqualTo: oldMobile)
            .get();
        for (var doc in query.docs) {
          saudaBatch.update(doc.reference, {
            'brokerMobile': newMobile,
            'brokerFirmName': newName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          hasUpdates = true;
        }
      } else if (section == 'BUYER') {
        final query = await _db
            .collection('saudas')
            .where('buyerMobile', isEqualTo: oldMobile)
            .get();
        for (var doc in query.docs) {
          saudaBatch.update(doc.reference, {
            'buyerMobile': newMobile,
            'buyer': newName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          hasUpdates = true;
        }
      } else if (section == 'SELLER') {
        final query = await _db
            .collection('saudas')
            .where('sellerMobile', isEqualTo: oldMobile)
            .get();
        for (var doc in query.docs) {
          saudaBatch.update(doc.reference, {
            'sellerMobile': newMobile,
            'seller': newName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await saudaBatch.commit();
        debugPrint('🚚 CloudSync: Migrated all sauda records to $newMobile');
      }
    } catch (e) {
      debugPrint('❌ CloudSync _transferAllAssociatedSaudas error: $e');
    }
  }

  // =============================================================
  // 2. SAUDA DEALS (saudas collection)
  // =============================================================

  static Future<void> bookSauda(Map<String, dynamic> saudaData) async {
    try {
      await ensureAuthSession();
      final String saudaId =
          (saudaData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
              .toString();

      await _db.collection('saudas').doc(saudaId).set({
        ...saudaData,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
      debugPrint('✅ CloudSync: Sauda saved under saudas/$saudaId');
    } catch (e) {
      debugPrint('CloudSyncService bookSauda error: $e');
    }
  }

  static Future<void> updateSauda(
      String saudaId, Map<String, dynamic> saudaData) async {
    try {
      await ensureAuthSession();
      await _db.collection('saudas').doc(saudaId.trim()).set({
        ...saudaData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('CloudSyncService updateSauda error: $e');
    }
  }

  static Future<void> deleteSauda(String saudaId) async {
    try {
      await ensureAuthSession();
      await _db
          .collection('saudas')
          .doc(saudaId.trim())
          .delete()
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('CloudSyncService deleteSauda error: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> streamBrokerSaudas(
      String brokerMobile) {
    return _db
        .collection('saudas')
        .where('brokerMobile', isEqualTo: brokerMobile.trim())
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  static Stream<List<Map<String, dynamic>>> streamBuyerSaudas(
      String buyerMobile) {
    return _db
        .collection('saudas')
        .where('buyerMobile', isEqualTo: buyerMobile.trim())
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  static Stream<List<Map<String, dynamic>>> streamSellerSaudas(
      String sellerMobile) {
    return _db
        .collection('saudas')
        .where('sellerMobile', isEqualTo: sellerMobile.trim())
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // =============================================================
  // 3. MASTER PARTY LEDGER (parties collection)
  // =============================================================

  static Future<void> saveParty(Map<String, dynamic> partyData) async {
    try {
      await ensureAuthSession();
      final String mobile = partyData['mobile'].toString().trim();
      await _db
          .collection('parties')
          .doc(mobile)
          .set(partyData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('CloudSyncService saveParty error: $e');
    }
  }

  static Future<void> deleteParty(String mobile) async {
    try {
      await ensureAuthSession();
      await _db
          .collection('parties')
          .doc(mobile.trim())
          .delete()
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('CloudSyncService deleteParty error: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> streamParties() {
    return _db
        .collection('parties')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // =============================================================
  // 4. BROKER BUSINESS PROFILE (broker_profiles collection)
  // =============================================================

  static Future<void> saveBrokerProfile(
    String brokerMobile,
    Map<String, dynamic> profileData,
  ) async {
    try {
      await ensureAuthSession();
      await _db
          .collection('broker_profiles')
          .doc(brokerMobile.trim())
          .set(profileData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('CloudSyncService saveBrokerProfile error: $e');
    }
  }

  static Future<Map<String, dynamic>?> getBrokerProfile(
      String brokerMobile) async {
    try {
      await ensureAuthSession();
      final doc = await _db
          .collection('broker_profiles')
          .doc(brokerMobile.trim())
          .get()
          .timeout(const Duration(seconds: 6));
      return doc.data();
    } catch (e) {
      debugPrint('CloudSyncService getBrokerProfile error: $e');
      return null;
    }
  }

  // =============================================================
  // 5. NOTIFICATIONS (notifications collection)
  // =============================================================

  static Future<void> sendNotification({
    required String targetMobile,
    required String title,
    required String message,
  }) async {
    try {
      await ensureAuthSession();
      final String notifId = DateTime.now().millisecondsSinceEpoch.toString();
      await _db.collection('notifications').doc(notifId).set({
        'id': notifId,
        'targetMobile': targetMobile.trim(),
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      debugPrint(
          '✅ CloudSync: Notification saved under notifications/$notifId');
    } catch (e) {
      debugPrint('CloudSyncService sendNotification error: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> streamNotifications(String mobile) {
    return _db
        .collection('notifications')
        .where('targetMobile', isEqualTo: mobile.trim())
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  static Future<void> clearNotifications(String mobile) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('targetMobile', isEqualTo: mobile.trim())
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('CloudSyncService clearNotifications error: $e');
    }
  }

  // =============================================================
  // 6. DYNAMIC REMOTE FEATURE SWITCHES (app_config collection)
  // =============================================================

  static Stream<Map<String, dynamic>> streamServiceSwitches() {
    return _db
        .collection('app_config')
        .doc('services')
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }
}
