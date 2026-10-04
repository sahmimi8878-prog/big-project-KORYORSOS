import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:my_app/models/document_model.dart';
import 'package:my_app/service/document_service.dart';

class DocumentFormScreen extends StatefulWidget {
  final DocumentModel? document;

  const DocumentFormScreen({
    super.key,
    this.document,
  });

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  static const List<String> _docTypes = [
    'สำเนาบัตรประชาชนผู้กู้',
    'สำเนาทะเบียนบ้านผู้กู้',
    'สำเนาบัตรประชาชนผู้ปกครอง/ผู้ค้ำประกัน',
    'หนังสือรับรองรายได้ครอบครัว',
    'รูปถ่ายนักเรียน/นักศึกษา',
    'หนังสือรับรองการเป็นนักศึกษา',
    'สัญญากู้ยืมเงิน (ลงนามแล้ว)',
  ];

  final Map<String, PlatformFile?> _pickedFiles = {};

  bool _submitting = false;

  bool get _isEditMode => widget.document != null;

  @override
  void initState() {
    super.initState();

    // ถ้าเป็นโหมดแก้ไข
    if (widget.document != null) {
      final doc = widget.document!;

      // เก็บข้อมูลเอกสารเดิมไว้
      _pickedFiles[doc.docType] = null;
    }
  }

  // เลือกไฟล์
  Future<void> _pickFile(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'pdf',
      ],
      withData: kIsWeb,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFiles[docType] = result.files.single;
      });
    }
  }

  // ลบไฟล์ที่เลือกใหม่
  void _removeFile(String docType) {
    setState(() {
      _pickedFiles[docType] = null;
    });
  }

  // บันทึก
  Future<void> _submit() async {
    if (_isEditMode) {
      await _updateDocument();
    } else {
      await _addDocuments();
    }
  }

  // =========================
  // เพิ่มเอกสาร
  // =========================
  Future<void> _addDocuments() async {
    final selectedFiles = _pickedFiles.entries
        .where((entry) => entry.value != null)
        .toList();

    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'กรุณาแนบไฟล์เอกสารอย่างน้อย 1 รายการ',
          ),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      for (final entry in selectedFiles) {
        final docType = entry.key;
        final file = entry.value!;

        final result = await DocumentService.addDocument(
          docType: docType,
          docName: file.name,
          note: '',
          file: file,
        );

        if (result.isError) {
          if (!mounted) return;

          setState(() {
            _submitting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'เพิ่ม "$docType" ไม่สำเร็จ\n'
                '${result.errorMessage}',
              ),
            ),
          );

          return;
        }
      }

      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เพิ่มเอกสารเรียบร้อยแล้ว'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
        ),
      );
    }
  }

  // =========================
  // แก้ไขเอกสาร
  // =========================
  Future<void> _updateDocument() async {
    final doc = widget.document!;

    final newFile = _pickedFiles[doc.docType];

    setState(() {
      _submitting = true;
    });

    try {
      final result = await DocumentService.updateDocument(
        documentId: doc.documentId,
        docType: doc.docType,
        docName: newFile?.name ?? doc.docName,
        note: '',
        file: newFile,
      );

      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      if (result.isError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage,
            ),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('แก้ไขเอกสารเรียบร้อยแล้ว'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xff4B1528),
        title: Text(
          _isEditMode
              ? 'แก้ไขเอกสาร'
              : 'เพิ่มเอกสาร',
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _isEditMode
                  ? 'แก้ไขข้อมูลเอกสาร'
                  : 'เอกสารที่ต้องส่ง',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff4B1528),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _isEditMode
                  ? 'สามารถเปลี่ยนไฟล์เอกสารได้ หากไม่เลือกไฟล์ใหม่จะใช้ไฟล์เดิม'
                  : 'เลือกไฟล์ตามประเภทเอกสารที่ต้องการส่ง',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            // =========================
            // โหมดแก้ไข
            // =========================
            if (_isEditMode)
              _buildEditDocument(),

            // =========================
            // โหมดเพิ่ม
            // =========================
            if (!_isEditMode)
              ..._docTypes.map(
                (docType) => _buildAddDocumentItem(
                  docType,
                ),
              ),

            const SizedBox(height: 12),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xffD4537E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isEditMode
                            ? 'บันทึกการแก้ไข'
                            : 'บันทึก',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // รายการเอกสารสำหรับโหมดเพิ่ม
  // =========================================================

  Widget _buildAddDocumentItem(
    String docType,
  ) {
    final file = _pickedFiles[docType];

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffFBF8FC),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffE8D7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            docType,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xff4B1528),
            ),
          ),

          const SizedBox(height: 12),

          if (file == null)
            InkWell(
              onTap: _submitting
                  ? null
                  : () => _pickFile(
                        docType,
                      ),
              borderRadius:
                  BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        const Color(0xffDCC3E0),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.attach_file,
                      color:
                          Color(0xffA3277D),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'แนบไฟล์',
                      style: TextStyle(
                        color:
                            Color(0xffA3277D),
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (file != null)
            _buildSelectedFile(
              docType,
              file.name,
            ),
        ],
      ),
    );
  }

  // =========================================================
  // เอกสารสำหรับโหมดแก้ไข
  // =========================================================

  Widget _buildEditDocument() {
    final doc = widget.document!;

    final newFile =
        _pickedFiles[doc.docType];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffFBF8FC),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffE8D7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'ประเภทเอกสาร',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 6),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Text(
              doc.docType,
              style: const TextStyle(
                fontSize: 15,
                fontWeight:
                    FontWeight.w600,
                color:
                    Color(0xff4B1528),
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'ไฟล์ปัจจุบัน',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 8),

          if (newFile == null)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color:
                      const Color(0xffDCC3E0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .insert_drive_file_outlined,
                    color:
                        Color(0xffA3277D),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      doc.docName,
                      style:
                          const TextStyle(
                        fontSize: 13,
                      ),
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          if (newFile != null)
            _buildSelectedFile(
              doc.docType,
              newFile.name,
            ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _submitting
                  ? null
                  : () => _pickFile(
                        doc.docType,
                      ),
              icon: const Icon(
                Icons.attach_file,
              ),
              label: Text(
                newFile == null
                    ? 'เปลี่ยนไฟล์'
                    : 'เลือกไฟล์ใหม่',
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(
                        0xffA3277D),
                side: const BorderSide(
                  color:
                      Color(0xffDCC3E0),
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                          12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // แสดงไฟล์ที่เลือก
  // =========================================================

  Widget _buildSelectedFile(
    String docType,
    String fileName,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xffDCC3E0),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons
                .insert_drive_file_outlined,
            color: Color(0xffA3277D),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                fontSize: 13,
              ),
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),

          IconButton(
            tooltip: 'เปลี่ยนไฟล์',
            onPressed: _submitting
                ? null
                : () => _pickFile(
                      docType,
                    ),
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: Color(0xffA3277D),
            ),
          ),

          IconButton(
            tooltip: 'ลบไฟล์',
            onPressed: _submitting
                ? null
                : () => _removeFile(
                      docType,
                    ),
            icon: const Icon(
              Icons.close,
              size: 20,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}