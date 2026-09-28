import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:my_app/models/document_model.dart';
import 'package:my_app/service/document_service.dart';

class DocumentFormScreen extends StatefulWidget {
  /// ส่ง document เข้ามา = โหมดแก้ไข, ไม่ส่ง = โหมดเพิ่มใหม่
  final DocumentModel? document;

  const DocumentFormScreen({super.key, this.document});

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  static const List<String> _docTypes = [
    'สำเนาบัตรประชาชนผู้กู้',
    'สำเนาทะเบียนบ้านผู้กู้',
    'สำเนาบัตรประชาชนผู้ปกครอง/ผู้ค้ำประกัน',
    'หนังสือรับรองรายได้ครอบครัว',
    'รูปถ่ายนักเรียน/นักศึกษา',
    'หนังสือรับรองการเป็นนักศึกษา',
    'สัญญากู้ยืมเงิน (ลงนามแล้ว)',
    'อื่นๆ',
  ];

  late String _selectedType;
  late TextEditingController _nameCtrl;
  late TextEditingController _noteCtrl;
  PlatformFile? _pickedFile;
  bool _submitting = false;

  bool get _isEditing => widget.document != null;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.document?.docType ?? _docTypes.first;
    if (!_docTypes.contains(_selectedType)) _selectedType = 'อื่นๆ';
    _nameCtrl = TextEditingController(text: widget.document?.docName ?? '');
    _noteCtrl = TextEditingController(text: widget.document?.note ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: kIsWeb, // บนเว็บต้องขอ bytes ตรงๆ เพราะ path จะเป็น null เสมอ
    );
    if (result != null) {
      setState(() {
        _pickedFile = result.files.single;
        if (_nameCtrl.text.isEmpty) {
          _nameCtrl.text = _pickedFile!.name;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEditing && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาแนบไฟล์เอกสาร')),
      );
      return;
    }

    setState(() => _submitting = true);

    final result = _isEditing
        ? await DocumentService.updateDocument(
            documentId: widget.document!.documentId,
            docType: _selectedType,
            docName: _nameCtrl.text.trim(),
            note: _noteCtrl.text.trim(),
            file: _pickedFile,
          )
        : await DocumentService.addDocument(
            docType: _selectedType,
            docName: _nameCtrl.text.trim(),
            note: _noteCtrl.text.trim(),
            file: _pickedFile,
          );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage)),
      );
      return;
    }

    Navigator.pop(context, true); // true = สำเร็จ ให้หน้ารายการโหลดใหม่
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xff4B1528),
        title: Text(_isEditing ? 'แก้ไขเอกสาร' : 'เพิ่มเอกสาร'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'ประเภทเอกสาร',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                items: _docTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 18),
              const Text(
                'ชื่อไฟล์ / รายละเอียด',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDecoration(hint: 'เช่น scan_บัตรประชาชน.pdf'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อเอกสาร' : null,
              ),
              const SizedBox(height: 18),
              const Text(
                'แนบไฟล์',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xffDCC3E0)),
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xffFBF8FC),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.upload_file_outlined, color: Color(0xffA3277D)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pickedFile != null
                              ? _pickedFile!.name
                              : (_isEditing
                                  ? 'ไฟล์ปัจจุบัน: ${widget.document!.docName}'
                                  : 'แตะเพื่อเลือกไฟล์'),
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'หมายเหตุ (ถ้ามี)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: _inputDecoration(hint: 'รายละเอียดเพิ่มเติม...'),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffD4537E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('บันทึก'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xffFBF8FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffEFE6F3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffEFE6F3)),
      ),
    );
  }
}