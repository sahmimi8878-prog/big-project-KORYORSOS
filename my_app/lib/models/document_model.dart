class DocumentModel {
  final int documentId;
  final String docType;
  final String docName;
  final String filePath;
  final String status;
  final String? note;
  final String createdAt;
  final String updatedAt;

  DocumentModel({
    required this.documentId,
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
      docType: json['doc_type']?.toString() ?? '',
      docName: json['doc_name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      note: json['note']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'document_id': documentId,
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