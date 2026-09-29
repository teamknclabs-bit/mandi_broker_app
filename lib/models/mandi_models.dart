import 'dart:convert';

import 'package:flutter/services.dart';

const String kAppName = 'MANDI TRADE PORTAL';
const String kAppNameHindi = 'मंडी व्यापार पोर्टल';

Uint8List? decodeBase64Image(String? photoBase64) {
  if (photoBase64 == null || photoBase64.isEmpty) return null;
  try {
    final clean =
        photoBase64.contains(',') ? photoBase64.split(',').last : photoBase64;
    return base64Decode(clean);
  } catch (_) {
    return null;
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// =============================================================
// USER ACCOUNT MODEL
// =============================================================
class UserAccount {
  String name;
  String address;
  String mobile;
  String email;
  String password;
  String section;

  UserAccount({
    required this.name,
    required this.address,
    required this.mobile,
    required this.email,
    required this.password,
    required this.section,
  });

  UserAccount copyWith({
    String? name,
    String? address,
    String? mobile,
    String? email,
    String? password,
    String? section,
  }) {
    return UserAccount(
      name: name ?? this.name,
      address: address ?? this.address,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      password: password ?? this.password,
      section: section ?? this.section,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'address': address.trim(),
        'mobile': mobile.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'section': section.trim().toUpperCase(),
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        name: (json['name'] ?? '').toString().trim(),
        address: (json['address'] ?? '').toString().trim(),
        mobile: (json['mobile'] ?? '').toString().trim(),
        email: (json['email'] ?? '').toString().trim().toLowerCase(),
        password: (json['password'] ?? '').toString(),
        section: (json['section'] ?? '').toString().trim().toUpperCase(),
      );
}

// =============================================================
// APP NOTIFICATION MODEL
// =============================================================
class AppNotification {
  final String id;
  final String targetMobile;
  final String title;
  final String message;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.targetMobile,
    required this.title,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetMobile': targetMobile.trim(),
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] ?? '').toString(),
        targetMobile: (json['targetMobile'] ?? '').toString().trim(),
        title: (json['title'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

// =============================================================
// BROKER FIRM PROFILE MODEL
// =============================================================
class BrokerFirmProfileModel {
  String firmName;
  String address;
  String mobile;
  String panNo;
  String licenseNo;
  String email;
  String bankName;
  String accountNo;
  String ifscCode;
  double defaultBuyerDalali;
  double defaultSellerDalali;
  List<String> commonJins;
  String? photoBase64;
  String termsAndConditions;
  String whatsappMessageTemplate;

  BrokerFirmProfileModel({
    this.firmName = '',
    this.address = '',
    this.mobile = '',
    this.panNo = '',
    this.licenseNo = '',
    this.email = '',
    this.bankName = '',
    this.accountNo = '',
    this.ifscCode = '',
    this.defaultBuyerDalali = 0.0,
    this.defaultSellerDalali = 0.0,
    List<String>? commonJins,
    this.photoBase64,
    this.termsAndConditions =
        '1. ALL DISPUTES SUBJECT TO LOCAL MANDI JURISDICTION.\n2. PAYMENT MUST BE CLEARED WITHIN PRESCRIBED TIME.\n3. BROKERAGE / DALALI APPLICABLE AS PER APMC REGULATIONS.',
    this.whatsappMessageTemplate = '',
  }) : commonJins = commonJins ??
            ['JEERA', 'SAUNF', 'ISABGOL', 'CHANA', 'DHANIYA', 'RAYDA', 'WHEAT'];

  BrokerFirmProfileModel copyWith({
    String? firmName,
    String? address,
    String? mobile,
    String? panNo,
    String? licenseNo,
    String? email,
    String? bankName,
    String? accountNo,
    String? ifscCode,
    double? defaultBuyerDalali,
    double? defaultSellerDalali,
    List<String>? commonJins,
    String? photoBase64,
    String? termsAndConditions,
    String? whatsappMessageTemplate,
  }) {
    return BrokerFirmProfileModel(
      firmName: firmName ?? this.firmName,
      address: address ?? this.address,
      mobile: mobile ?? this.mobile,
      panNo: panNo ?? this.panNo,
      licenseNo: licenseNo ?? this.licenseNo,
      email: email ?? this.email,
      bankName: bankName ?? this.bankName,
      accountNo: accountNo ?? this.accountNo,
      ifscCode: ifscCode ?? this.ifscCode,
      defaultBuyerDalali: defaultBuyerDalali ?? this.defaultBuyerDalali,
      defaultSellerDalali: defaultSellerDalali ?? this.defaultSellerDalali,
      commonJins: commonJins ?? List.from(this.commonJins),
      photoBase64: photoBase64 ?? this.photoBase64,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      whatsappMessageTemplate:
          whatsappMessageTemplate ?? this.whatsappMessageTemplate,
    );
  }

  Map<String, dynamic> toJson() => {
        'firmName': firmName.trim(),
        'address': address.trim(),
        'mobile': mobile.trim(),
        'panNo': panNo.trim().toUpperCase(),
        'licenseNo': licenseNo.trim().toUpperCase(),
        'email': email.trim().toLowerCase(),
        'bankName': bankName.trim().toUpperCase(),
        'accountNo': accountNo.trim(),
        'ifscCode': ifscCode.trim().toUpperCase(),
        'defaultBuyerDalali': defaultBuyerDalali,
        'defaultSellerDalali': defaultSellerDalali,
        'commonJins': commonJins,
        'photoBase64': photoBase64,
        'termsAndConditions': termsAndConditions,
        'whatsappMessageTemplate': whatsappMessageTemplate,
      };

  factory BrokerFirmProfileModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return BrokerFirmProfileModel(
      firmName: (json['firmName'] ?? '').toString().trim(),
      address: (json['address'] ?? '').toString().trim(),
      mobile: (json['mobile'] ?? '').toString().trim(),
      panNo: (json['panNo'] ?? '').toString().trim().toUpperCase(),
      licenseNo: (json['licenseNo'] ?? '').toString().trim().toUpperCase(),
      email: (json['email'] ?? '').toString().trim().toLowerCase(),
      bankName: (json['bankName'] ?? '').toString().trim().toUpperCase(),
      accountNo: (json['accountNo'] ?? '').toString().trim(),
      ifscCode: (json['ifscCode'] ?? '').toString().trim().toUpperCase(),
      defaultBuyerDalali: parseDouble(json['defaultBuyerDalali']),
      defaultSellerDalali: parseDouble(json['defaultSellerDalali']),
      commonJins: json['commonJins'] != null
          ? List<String>.from(json['commonJins'])
          : null,
      photoBase64: json['photoBase64']?.toString(),
      termsAndConditions: (json['termsAndConditions'] ?? '').toString(),
      whatsappMessageTemplate:
          (json['whatsappMessageTemplate'] ?? '').toString(),
    );
  }
}

// =============================================================
// MANDI SAUDA MODEL
// =============================================================
class MandiSaudaModel {
  final String id;
  DateTime date;
  String buyer;
  String buyerMobile;
  String seller;
  String sellerMobile;
  String jins;
  int bags;
  double rate;
  double buyerDalaliPerBag;
  double sellerDalaliPerBag;
  bool buyerConfirmed;
  bool sellerConfirmed;
  String brokerFirmName;
  String brokerMobile;
  bool cancelRequested;
  String? cancelRequestedBy;
  String? cancellationReason;

  MandiSaudaModel({
    required this.id,
    required this.date,
    required this.buyer,
    required this.buyerMobile,
    required this.seller,
    required this.sellerMobile,
    required this.jins,
    required this.bags,
    required this.rate,
    required this.buyerDalaliPerBag,
    required this.sellerDalaliPerBag,
    this.buyerConfirmed = false,
    this.sellerConfirmed = false,
    this.brokerFirmName = '',
    this.brokerMobile = '',
    this.cancelRequested = false,
    this.cancelRequestedBy,
    this.cancellationReason,
  });

  double get totalBuyerDalali => bags * buyerDalaliPerBag;
  double get totalSellerDalali => bags * sellerDalaliPerBag;
  double get totalDalaliEarned => totalBuyerDalali + totalSellerDalali;

  MandiSaudaModel copyWith({
    String? id,
    DateTime? date,
    String? buyer,
    String? buyerMobile,
    String? seller,
    String? sellerMobile,
    String? jins,
    int? bags,
    double? rate,
    double? buyerDalaliPerBag,
    double? sellerDalaliPerBag,
    bool? buyerConfirmed,
    bool? sellerConfirmed,
    String? brokerFirmName,
    String? brokerMobile,
    bool? cancelRequested,
    String? cancelRequestedBy,
    String? cancellationReason,
  }) {
    return MandiSaudaModel(
      id: id ?? this.id,
      date: date ?? this.date,
      buyer: buyer ?? this.buyer,
      buyerMobile: buyerMobile ?? this.buyerMobile,
      seller: seller ?? this.seller,
      sellerMobile: sellerMobile ?? this.sellerMobile,
      jins: jins ?? this.jins,
      bags: bags ?? this.bags,
      rate: rate ?? this.rate,
      buyerDalaliPerBag: buyerDalaliPerBag ?? this.buyerDalaliPerBag,
      sellerDalaliPerBag: sellerDalaliPerBag ?? this.sellerDalaliPerBag,
      buyerConfirmed: buyerConfirmed ?? this.buyerConfirmed,
      sellerConfirmed: sellerConfirmed ?? this.sellerConfirmed,
      brokerFirmName: brokerFirmName ?? this.brokerFirmName,
      brokerMobile: brokerMobile ?? this.brokerMobile,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      cancelRequestedBy: cancelRequestedBy ?? this.cancelRequestedBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'buyer': buyer.trim(),
        'buyerMobile': buyerMobile.trim(),
        'seller': seller.trim(),
        'sellerMobile': sellerMobile.trim(),
        'jins': jins.trim().toUpperCase(),
        'bags': bags,
        'rate': rate,
        'buyerDalaliPerBag': buyerDalaliPerBag,
        'sellerDalaliPerBag': sellerDalaliPerBag,
        'buyerConfirmed': buyerConfirmed,
        'sellerConfirmed': sellerConfirmed,
        'brokerFirmName': brokerFirmName.trim(),
        'brokerMobile': brokerMobile.trim(),
        'cancelRequested': cancelRequested,
        'cancelRequestedBy': cancelRequestedBy,
        'cancellationReason': cancellationReason,
      };

  factory MandiSaudaModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return MandiSaudaModel(
      id: (json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
          .toString(),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      buyer: (json['buyer'] ?? '').toString().trim(),
      buyerMobile: (json['buyerMobile'] ?? '').toString().trim(),
      seller: (json['seller'] ?? '').toString().trim(),
      sellerMobile: (json['sellerMobile'] ?? '').toString().trim(),
      jins: (json['jins'] ?? '').toString().trim().toUpperCase(),
      bags: parseInt(json['bags']),
      rate: parseDouble(json['rate']),
      buyerDalaliPerBag: parseDouble(json['buyerDalaliPerBag']),
      sellerDalaliPerBag: parseDouble(json['sellerDalaliPerBag']),
      buyerConfirmed: json['buyerConfirmed'] == true,
      sellerConfirmed: json['sellerConfirmed'] == true,
      brokerFirmName: (json['brokerFirmName'] ?? '').toString().trim(),
      brokerMobile: (json['brokerMobile'] ?? '').toString().trim(),
      cancelRequested: json['cancelRequested'] == true,
      cancelRequestedBy: json['cancelRequestedBy']?.toString(),
      cancellationReason: json['cancellationReason']?.toString(),
    );
  }
}

// =============================================================
// MANDI PARTY MODEL
// =============================================================
class MandiPartyModel {
  String name;
  String mobile;
  String address;
  String type;

  MandiPartyModel({
    required this.name,
    required this.mobile,
    required this.address,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'mobile': mobile.trim(),
        'address': address.trim(),
        'type': type.trim(),
      };

  factory MandiPartyModel.fromJson(Map<String, dynamic> json) =>
      MandiPartyModel(
        name: (json['name'] ?? '').toString().trim(),
        mobile: (json['mobile'] ?? '').toString().trim(),
        address: (json['address'] ?? '').toString().trim(),
        type: (json['type'] ?? 'Buyer').toString().trim(),
      );
}
