import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage/local_storage.dart';

class DownloadedInvoiceItem {
  final String invoiceNumber;
  final String orderNumber;
  final DateTime downloadedDate;
  final String fileName;
  final String filePath;
  final int? dealerUserId;

  const DownloadedInvoiceItem({
    required this.invoiceNumber,
    required this.orderNumber,
    required this.downloadedDate,
    required this.fileName,
    required this.filePath,
    this.dealerUserId,
  });

  bool get fileExists {
    if (filePath.isEmpty) return false;
    try {
      return File(filePath).existsSync();
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
        'invoiceNumber': invoiceNumber,
        'orderNumber': orderNumber,
        'downloadedDate': downloadedDate.toIso8601String(),
        'fileName': fileName,
        'filePath': filePath,
        'dealerUserId': dealerUserId,
      };

  factory DownloadedInvoiceItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['downloadedDate'].toString());
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return DownloadedInvoiceItem(
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      downloadedDate: parsedDate,
      fileName: json['fileName']?.toString() ?? '',
      filePath: json['filePath']?.toString() ?? '',
      dealerUserId: json['dealerUserId'] as int?,
    );
  }
}

class DownloadedInvoicesService {
  static const String _keyPrefix = 'downloaded_invoices_';

  /// Resolves the storage key scoped to the active Dealer user
  static Future<String> _getStorageKey({int? overrideUserId}) async {
    if (overrideUserId != null) {
      return '$_keyPrefix$overrideUserId';
    }
    try {
      final user = await LocalStorage.getUserData();
      final uid = user['id'] ?? 'default';
      return '$_keyPrefix$uid';
    } catch (_) {
      return '${_keyPrefix}default';
    }
  }

  /// Records a newly downloaded invoice into local persistent storage
  static Future<void> recordDownload({
    required String invoiceNumber,
    required String orderNumber,
    required String fileName,
    required String filePath,
    int? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getStorageKey(overrideUserId: userId);

      final existingList = await getDownloadedInvoices(userId: userId);

      // Remove existing item with same invoiceNumber to update it with latest path/date
      existingList.removeWhere((item) => item.invoiceNumber == invoiceNumber);

      final newItem = DownloadedInvoiceItem(
        invoiceNumber: invoiceNumber,
        orderNumber: orderNumber,
        downloadedDate: DateTime.now(),
        fileName: fileName,
        filePath: filePath,
        dealerUserId: userId,
      );

      existingList.insert(0, newItem);

      final jsonString = jsonEncode(existingList.map((e) => e.toJson()).toList());
      await prefs.setString(key, jsonString);
      debugPrint('[DownloadedInvoicesService] Recorded invoice $invoiceNumber to $key');
    } catch (e) {
      debugPrint('[DownloadedInvoicesService] Error recording download: $e');
    }
  }

  /// Retrieves the list of downloaded invoices for the authenticated Dealer
  static Future<List<DownloadedInvoiceItem>> getDownloadedInvoices({int? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getStorageKey(overrideUserId: userId);
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) return [];

      final List decoded = jsonDecode(raw);
      return decoded
          .map((item) => DownloadedInvoiceItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('[DownloadedInvoicesService] Error loading downloaded invoices: $e');
      return [];
    }
  }

  /// Removes an invoice reference from persistent storage
  static Future<void> removeInvoice(String invoiceNumber, {int? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getStorageKey(overrideUserId: userId);
      final existingList = await getDownloadedInvoices(userId: userId);
      existingList.removeWhere((item) => item.invoiceNumber == invoiceNumber);

      final jsonString = jsonEncode(existingList.map((e) => e.toJson()).toList());
      await prefs.setString(key, jsonString);
    } catch (e) {
      debugPrint('[DownloadedInvoicesService] Error removing invoice: $e');
    }
  }

  /// Clears all downloaded invoice references for testing
  @visibleForTesting
  static Future<void> clearAll({int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey(overrideUserId: userId);
    await prefs.remove(key);
  }
}
