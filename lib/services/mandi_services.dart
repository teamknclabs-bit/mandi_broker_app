import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/mandi_models.dart';

// =============================================================
// 1. LOCAL PERSISTENT STORAGE SERVICE
// =============================================================
class StorageService {
  static SharedPreferences? _prefs;

  /// Initializes persistent storage on app startup.
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Saves a string key-value pair to persistent storage.
  static void save(String key, String value) {
    if (_prefs == null) {
      SharedPreferences.getInstance().then((p) => p.setString(key, value));
    } else {
      _prefs?.setString(key, value);
    }
  }

  /// Reads a string value from persistent storage.
  static String? get(String key) {
    return _prefs?.getString(key);
  }

  /// Removes a key from persistent storage.
  static void remove(String key) {
    if (_prefs == null) {
      SharedPreferences.getInstance().then((p) => p.remove(key));
    } else {
      _prefs?.remove(key);
    }
  }
}

// =============================================================
// 2. ACCOUNT MANAGEMENT SERVICE
// =============================================================
class AccountService {
  /// Fetches all registered accounts stored in local memory.
  static List<UserAccount> getAllAccounts() {
    final raw = StorageService.get('mandi_registered_accounts');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List list = jsonDecode(raw);
        return list.map((e) => UserAccount.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error parsing registered accounts: $e');
      }
    }
    return [];
  }

  /// Saves accounts list to local storage.
  static void saveAccounts(List<UserAccount> accounts) {
    final data = jsonEncode(accounts.map((a) => a.toJson()).toList());
    StorageService.save('mandi_registered_accounts', data);
  }

  /// Finds an existing user account by mobile or email address.
  static UserAccount? findExistingAccount(String identifier) {
    final accounts = getAllAccounts();
    final clean = identifier.trim().toLowerCase();
    for (var acc in accounts) {
      if (acc.mobile.trim() == clean ||
          acc.email.trim().toLowerCase() == clean) {
        return acc;
      }
    }
    return null;
  }

  /// Returns accounts belonging to a specific portal section.
  static List<UserAccount> getAccountsBySection(String section) {
    final targetSection = section.trim().toUpperCase();
    return getAllAccounts()
        .where((a) => a.section.trim().toUpperCase() == targetSection)
        .toList();
  }

  /// Retrieves the active logged-in user for a specific portal section.
  static UserAccount? getSessionUser(String section) {
    final sessionIdentifier = StorageService.get('session_$section');
    if (sessionIdentifier == null || sessionIdentifier.toString().isEmpty) {
      return null;
    }
    final clean = sessionIdentifier.toString().trim().toLowerCase();
    final accounts = getAllAccounts();
    final targetSection = section.trim().toUpperCase();

    try {
      return accounts.firstWhere(
        (a) =>
            a.section.trim().toUpperCase() == targetSection &&
            (a.mobile.trim() == clean || a.email.trim().toLowerCase() == clean),
      );
    } catch (_) {
      return null;
    }
  }

  /// Updates or inserts an account in local storage.
  static void updateAccount(UserAccount updated) {
    final accounts = getAllAccounts();
    final index = accounts.indexWhere(
      (a) =>
          a.section.trim().toUpperCase() ==
              updated.section.trim().toUpperCase() &&
          (a.mobile.trim() == updated.mobile.trim() ||
              (a.email.isNotEmpty &&
                  a.email.trim().toLowerCase() ==
                      updated.email.trim().toLowerCase())),
    );
    if (index != -1) {
      accounts[index] = updated;
    } else {
      accounts.add(updated);
    }
    saveAccounts(accounts);
  }

  /// Removes user from local persistent memory.
  static void removeAccount({required String mobile, required String section}) {
    final accounts = getAllAccounts();
    final targetSection = section.trim().toUpperCase();
    final cleanMobile = mobile.trim();

    accounts.removeWhere(
      (a) =>
          a.mobile.trim() == cleanMobile &&
          a.section.trim().toUpperCase() == targetSection,
    );
    saveAccounts(accounts);
  }

  /// Migrates user account when contact numbers or email addresses are altered.
  static void updateAccountWithOldCredentials({
    required String oldMobile,
    required String oldEmail,
    required UserAccount updatedAccount,
  }) {
    final accounts = getAllAccounts();
    final cleanOldMobile = oldMobile.trim();
    final cleanOldEmail = oldEmail.trim().toLowerCase();
    final targetSection = updatedAccount.section.trim().toUpperCase();

    // Find the record using the old identifiers
    final index = accounts.indexWhere(
      (a) =>
          a.section.trim().toUpperCase() == targetSection &&
          (a.mobile.trim() == cleanOldMobile ||
              (cleanOldEmail.isNotEmpty &&
                  a.email.trim().toLowerCase() == cleanOldEmail)),
    );

    if (index != -1) {
      accounts[index] = updatedAccount;
    } else {
      // Clean up any duplicates with the new credentials
      accounts.removeWhere(
        (a) =>
            a.section.trim().toUpperCase() == targetSection &&
            (a.mobile.trim() == updatedAccount.mobile.trim() ||
                (updatedAccount.email.isNotEmpty &&
                    a.email.trim().toLowerCase() ==
                        updatedAccount.email.trim().toLowerCase())),
      );
      accounts.add(updatedAccount);
    }

    saveAccounts(accounts);
  }
}

// =============================================================
// 3. LOCAL NOTIFICATION SERVICE
// =============================================================
class NotificationService {
  /// Loads all notifications from local storage.
  static List<AppNotification> getAllNotifications() {
    final raw = StorageService.get('mandi_notifications');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List list = jsonDecode(raw);
        return list.map((e) => AppNotification.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error parsing notifications: $e');
      }
    }
    return [];
  }

  /// Appends an in-app notification.
  static void addNotification({
    required String targetMobile,
    required String title,
    required String message,
  }) {
    final list = getAllNotifications();
    list.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetMobile: targetMobile.trim(),
        title: title.trim(),
        message: message.trim(),
        timestamp: DateTime.now(),
      ),
    );
    StorageService.save(
      'mandi_notifications',
      jsonEncode(list.map((n) => n.toJson()).toList()),
    );
  }

  /// Returns unread/active notifications targeted to a phone number.
  static List<AppNotification> getForMobile(String mobile) {
    final cleanMobile = mobile.trim();
    return getAllNotifications()
        .where((n) => n.targetMobile.trim() == cleanMobile)
        .toList();
  }

  /// Clears notifications targeted to a specific phone number.
  static void clearForMobile(String mobile) {
    final cleanMobile = mobile.trim();
    final list = getAllNotifications();
    list.removeWhere((n) => n.targetMobile.trim() == cleanMobile);
    StorageService.save(
      'mandi_notifications',
      jsonEncode(list.map((n) => n.toJson()).toList()),
    );
  }
}

// =============================================================
// 4. WHATSAPP TRANSACTION MESSAGING SERVICE
// =============================================================
class WhatsAppService {
  /// Generates the default deal confirmation template.
  static String getDefaultTemplate() {
    return '''
🌾 *{appName} - (TRADE CONFIRMATION)* 🌾
-----------------------------------
*{partyName}* ({roleText}),
आपका सौदा ब्रोकर द्वारा दर्ज कर लिया गया है:

📅 *Date:* {dateStr}
📦 *Jins:* {jins}
⚖️ *Bags/Weight:* {bags}
💰 *Rate:* ₹{rate}
🏢 *To:* {oppParty}
-----------------------------------
📋 *ब्रोकर फर्म:* {brokerFirmName}
📞 *संपर्क:* {brokerMobile}

_कृपया अपने पोर्टल में लॉगिन कर सौदे की पुष्टि (Confirm) करें।_
''';
  }

  /// Robust multi-tier URL dispatcher for WhatsApp & WhatsApp Business
  static Future<bool> _launchWhatsAppUrl({
    required String cleanMobile,
    required String message,
  }) async {
    final encodedText = Uri.encodeComponent(message);

    // Primary: Direct native app intent (bypasses browser redirects)
    final nativeUri =
        Uri.parse('whatsapp://send?phone=$cleanMobile&text=$encodedText');

    // Secondary: Official WhatsApp universal API endpoint
    final apiUri = Uri.parse(
        'https://api.whatsapp.com/send?phone=$cleanMobile&text=$encodedText');

    // Fallback: Standard shortlink
    final waMeUri = Uri.parse('https://wa.me/$cleanMobile?text=$encodedText');

    try {
      // 1. Try native intent first
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }

      // 2. Try official API intent
      if (await canLaunchUrl(apiUri)) {
        return await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      }

      // 3. Try standard wa.me redirect
      if (await canLaunchUrl(waMeUri)) {
        return await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      }

      // 4. Force launch without pre-check (handles strict Android 11+ permission delays)
      return await launchUrl(nativeUri,
          mode: LaunchMode.externalNonBrowserApplication);
    } catch (e) {
      debugPrint(
          'WhatsApp primary dispatch failed ($e), attempting web fallback...');
      try {
        return await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      } catch (err) {
        debugPrint('WhatsApp final dispatch error: $err');
        return false;
      }
    }
  }

  /// Dispatches the trade confirmation message via WhatsApp.
  static Future<void> sendSaudaAlert({
    required String recipientMobile,
    required String role,
    required MandiSaudaModel sauda,
    required String brokerFirmName,
    required String brokerMobile,
  }) async {
    String cleanMobile = recipientMobile.replaceAll(RegExp(r'\D'), '');
    if (cleanMobile.length == 10) cleanMobile = '91$cleanMobile';

    if (cleanMobile.isEmpty) {
      debugPrint('WhatsAppService: Invalid or empty recipient mobile number');
      return;
    }

    final partyName = role == 'BUYER' ? sauda.buyer : sauda.seller;
    final roleText = role == 'BUYER' ? 'खरीदार (Buyer)' : 'विक्रेता (Seller)';
    final dateStr =
        '${sauda.date.day.toString().padLeft(2, '0')}/${sauda.date.month.toString().padLeft(2, '0')}/${sauda.date.year}';

    String template = getDefaultTemplate();
    final rawProfile = StorageService.get('mandi_profile');
    if (rawProfile != null && rawProfile.isNotEmpty) {
      try {
        final profile = BrokerFirmProfileModel.fromJson(jsonDecode(rawProfile));
        if (profile.whatsappMessageTemplate.trim().isNotEmpty) {
          template = profile.whatsappMessageTemplate;
        }
      } catch (_) {}
    }

    final message = template
        .replaceAll('{appName}', kAppName)
        .replaceAll('{partyName}', partyName)
        .replaceAll('{roleText}', roleText)
        .replaceAll('{dateStr}', dateStr)
        .replaceAll('{jins}', sauda.jins)
        .replaceAll('{bags}', sauda.bags.toString())
        .replaceAll('{rate}', sauda.rate.toStringAsFixed(0))
        .replaceAll('{oppParty}', role == 'BUYER' ? sauda.seller : sauda.buyer)
        .replaceAll(
          '{brokerFirmName}',
          brokerFirmName.isNotEmpty ? brokerFirmName : 'MANDI BROKER',
        )
        .replaceAll('{brokerMobile}', brokerMobile);

    await _launchWhatsAppUrl(cleanMobile: cleanMobile, message: message);
  }

  /// Dispatches a cancellation/deletion notice via WhatsApp.
  static Future<void> sendDeletionNotice({
    required String recipientMobile,
    required String recipientName,
    required MandiSaudaModel sauda,
    required String brokerFirmName,
  }) async {
    String cleanMobile = recipientMobile.replaceAll(RegExp(r'\D'), '');
    if (cleanMobile.length == 10) cleanMobile = '91$cleanMobile';

    if (cleanMobile.isEmpty) {
      debugPrint(
          'WhatsAppService: Invalid or empty recipient mobile number for deletion notice');
      return;
    }

    final dateStr =
        '${sauda.date.day.toString().padLeft(2, '0')}/${sauda.date.month.toString().padLeft(2, '0')}/${sauda.date.year}';
    final message = '''
⚠️ *$kAppName - सौदा विलोपन सूचना (SAUDA DELETED)* ⚠️
-----------------------------------
*$recipientName*,
ब्रोकर द्वारा निम्न सौदा बही से हटा (Delete) दिया गया है:

📅 *दिनांक:* $dateStr
📦 *जिंस:* ${sauda.jins}
⚖️ *बोरी:* ${sauda.bags}
💰 *भाव:* ₹${sauda.rate.toStringAsFixed(0)}
-----------------------------------
ब्रोकर फर्म: $brokerFirmName
''';

    await _launchWhatsAppUrl(cleanMobile: cleanMobile, message: message);
  }
}

// =============================================================
// 5. STORAGE & DIALOG HELPERS
// =============================================================

/// Updates a trade record directly in local storage.
void updateSaudaInStorage(MandiSaudaModel updated) {
  final raw = StorageService.get('mandi_saudas');
  if (raw != null && raw.isNotEmpty) {
    try {
      final List list = jsonDecode(raw);
      final all = list.map((e) => MandiSaudaModel.fromJson(e)).toList();
      final index = all.indexWhere((s) => s.id == updated.id);
      if (index != -1) {
        all[index] = updated;
        StorageService.save(
          'mandi_saudas',
          jsonEncode(all.map((s) => s.toJson()).toList()),
        );
      }
    } catch (e) {
      debugPrint('Error updating sauda in local storage: $e');
    }
  }
}

/// Displays an in-app notifications modal dialog.
void showNotificationDialog(BuildContext context, String userMobile) {
  final notifications = NotificationService.getForMobile(userMobile);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                NotificationService.clearForMobile(userMobile);
                Navigator.pop(ctx);
              },
              child: const Text(
                'Clear All',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: notifications.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No notifications right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      n.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      '${n.message}\n${n.timestamp.day.toString().padLeft(2, '0')}/${n.timestamp.month.toString().padLeft(2, '0')}/${n.timestamp.year} ${n.timestamp.hour.toString().padLeft(2, '0')}:${n.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );
}

// =============================================================
// APP UPDATE SERVICE (FIRESTORE VERSION CHECK)
// =============================================================
class AppUpdateService {
  // Current hardcoded app version matching pubspec.yaml
  static const String currentVersion = '1.0.0';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_control')
          .get();

      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final String latestVersion = data['latest_version'] ?? currentVersion;
      final bool forceUpdate = data['force_update'] ?? false;
      final String downloadUrl = data['download_url'] ?? '';
      final String releaseNotes = data['release_notes'] ??
          'A new update is available with improvements.';

      if (_isUpdateAvailable(currentVersion, latestVersion) &&
          context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: !forceUpdate,
          builder: (ctx) => PopScope(
            canPop: !forceUpdate,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.system_update_rounded, color: Color(0xFF0F766E)),
                  SizedBox(width: 8),
                  Text('Update Available',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'A new version ($latestVersion) of Mandi Trade Portal is ready to install.'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      releaseNotes,
                      style:
                          TextStyle(color: Colors.grey.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
              actions: [
                if (!forceUpdate)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Later'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (downloadUrl.isNotEmpty) {
                      final uri = Uri.parse(downloadUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: const Text('Update Now'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('App update check error: $e');
    }
  }

  static bool _isUpdateAvailable(String current, String latest) {
    List<int> currParts =
        current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> latestParts =
        latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int curr = i < currParts.length ? currParts[i] : 0;
      int lat = i < latestParts.length ? latestParts[i] : 0;
      if (lat > curr) return true;
      if (lat < curr) return false;
    }
    return false;
  }
}
