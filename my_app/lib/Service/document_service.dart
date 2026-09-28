import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/config/app_config.dart';
import 'package:my_app/models/document_model.dart';

class DocumentService {
  // TODO: ปรับ path ให้ตรงกับ backend จริง เช่น '${AppConfig.baseUrl}/api/documents'
  static String get _baseUrl => AppConfig.documents;

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// ดึงรายการเอกสารทั้งหมด
  static Future<({bool isError, List<DocumentModel> data, String errorMessage})>
      getDocuments() async {
    try {
      final headers = await _authHeaders();
      print('[DocumentService] headers: $headers'); // DEBUG
      final res = await http.get(Uri.parse(_baseUrl), headers: headers);
      print('[DocumentService] status: ${res.statusCode}'); // DEBUG
      print('[DocumentService] body: ${res.body}'); // DEBUG

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List list = decoded is List ? decoded : (decoded['data'] ?? []);
        final docs = list.map((e) => DocumentModel.fromJson(e)).toList();
        return (isError: false, data: docs, errorMessage: '');
      }
      return (
        isError: true,
        data: <DocumentModel>[],
        errorMessage: 'โหลดเอกสารไม่สำเร็จ (${res.statusCode})',
      );
    } catch (e) {
      return (
        isError: true,
        data: <DocumentModel>[],
        errorMessage: 'เกิดข้อผิดพลาด: $e',
      );
    }
  }

  /// เพิ่มเอกสารใหม่ พร้อมไฟล์แนบ
  static Future<({bool isError, DocumentModel? data, String errorMessage})>
      addDocument({
    required String docType,
    required String docName,
    String? note,
    PlatformFile? file,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields['doc_type'] = docType;
      request.fields['doc_name'] = docName;
      if (note != null) request.fields['note'] = note;
      if (file != null) {
        if (kIsWeb) {
          // บนเว็บไม่มี path จริง ต้องส่งเป็น bytes
          request.files.add(
            http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
          );
        } else {
          request.files.add(await http.MultipartFile.fromPath('file', file.path!));
        }
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] ?? decoded;
        return (isError: false, data: DocumentModel.fromJson(data), errorMessage: '');
      }
      return (
        isError: true,
        data: null,
        errorMessage: 'เพิ่มเอกสารไม่สำเร็จ (${res.statusCode})',
      );
    } catch (e) {
      return (isError: true, data: null, errorMessage: 'เกิดข้อผิดพลาด: $e');
    }
  }

  /// แก้ไขเอกสารที่มีอยู่ (ไฟล์เป็น optional หากไม่แนบใหม่จะคงไฟล์เดิมไว้)
  static Future<({bool isError, DocumentModel? data, String errorMessage})>
      updateDocument({
    required int documentId,
    required String docType,
    required String docName,
    String? note,
    PlatformFile? file,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      // ใช้ multipart + _method=PUT (รูปแบบ Laravel) หากแนบไฟล์ใหม่
      // ถ้า backend เป็น Node/Express อาจต้องเปลี่ยนเป็น http.MultipartRequest('PUT', ...) โดยตรง
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/$documentId'),
      );
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields['doc_type'] = docType;
      request.fields['doc_name'] = docName;
      request.fields['_method'] = 'PUT';
      if (note != null) request.fields['note'] = note;
      if (file != null) {
        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
          );
        } else {
          request.files.add(await http.MultipartFile.fromPath('file', file.path!));
        }
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] ?? decoded;
        return (isError: false, data: DocumentModel.fromJson(data), errorMessage: '');
      }
      return (
        isError: true,
        data: null,
        errorMessage: 'แก้ไขเอกสารไม่สำเร็จ (${res.statusCode})',
      );
    } catch (e) {
      return (isError: true, data: null, errorMessage: 'เกิดข้อผิดพลาด: $e');
    }
  }

  /// ลบเอกสาร
  static Future<({bool isError, String errorMessage})> deleteDocument(
    int documentId,
  ) async {
    try {
      final headers = await _authHeaders();
      final res = await http.delete(
        Uri.parse('$_baseUrl/$documentId'),
        headers: headers,
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        return (isError: false, errorMessage: '');
      }
      return (isError: true, errorMessage: 'ลบเอกสารไม่สำเร็จ (${res.statusCode})');
    } catch (e) {
      return (isError: true, errorMessage: 'เกิดข้อผิดพลาด: $e');
    }
  }
}