class DocumentModel {
  final int documentId;
  final int userId;
  final String? studentCode;
  final String? studentName;
  final String docType;
  final String docName;
  final String filePath;
  final String status;
  final String? note;
  final String createdAt;
  final String updatedAt;

  DocumentModel({
    required this.documentId,
    this.userId = 0,
    this.studentCode,
    this.studentName,
    required this.docType,
    required this.docName,
    required this.filePath,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      documentId: json['document_id'] is int
          ? json['document_id']
          : int.tryParse(json['document_id']?.toString() ?? '') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      studentCode: json['student_code']?.toString(),
      studentName: _fullName(json),
      docType: json['doc_type']?.toString() ?? '',
      docName: json['doc_name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      note: json['note']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  static String? _fullName(Map<String, dynamic> json) {
    final name = [json['prefix'], json['first_name'], json['last_name']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .map((e) => e.toString().trim())
        .join(' ');
    return name.isEmpty ? null : name;
  }

  Map<String, dynamic> toJson() {
    return {
      'document_id': documentId,
      'user_id': userId,
      'doc_type': docType,
      'doc_name': docName,
      'file_path': filePath,
      'status': status,
      'note': note,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  DocumentModel copyWith({
    int? documentId,
    int? userId,
    String? studentCode,
    String? studentName,
    String? docType,
    String? docName,
    String? filePath,
    String? status,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return DocumentModel(
      documentId: documentId ?? this.documentId,
      userId: userId ?? this.userId,
      studentCode: studentCode ?? this.studentCode,
      studentName: studentName ?? this.studentName,
      docType: docType ?? this.docType,
      docName: docName ?? this.docName,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}