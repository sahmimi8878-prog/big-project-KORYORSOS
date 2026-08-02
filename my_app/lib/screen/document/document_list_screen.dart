import 'package:flutter/material.dart';
import 'package:my_app/models/document_model.dart';
import 'package:my_app/screen/document/document_form_screen.dart';
import 'package:my_app/service/document_service.dart';
 
class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});
 
  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}
 
class _DocumentListScreenState extends State<DocumentListScreen> {
  late Future<({bool isError, List<DocumentModel> data, String errorMessage})>
      _futureDocuments;
 
  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }
 
  void _loadDocuments() {
    _futureDocuments = DocumentService.getDocuments();
  }
 
  static const List<Color> _iconBgColors = [
    Color(0xffF4C0D1),
    Color(0xffCECBF6),
    Color(0xff9FE1CB),
    Color(0xfffac775),
  ];
  static const List<Color> _iconFgColors = [
    Color(0xff72243E),
    Color(0xff3C3489),
    Color(0xff085041),
    Color(0xff633806),
  ];
 
  Color _statusBg(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xffC0DD97);
      case 'rejected':
        return const Color(0xffF09595);
      default:
        return const Color(0xffFAC775);
    }
  }
 
  Color _statusFg(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xff173404);
      case 'rejected':
        return const Color(0xff501313);
      default:
        return const Color(0xff412402);
    }
  }
 
  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'อนุมัติแล้ว';
      case 'rejected':
        return 'ถูกปฏิเสธ';
      default:
        return 'รอตรวจสอบ';
    }
  }
 
  IconData _docIcon(String docType) {
    if (docType.contains('บัตรประชาชน')) return Icons.badge_outlined;
    if (docType.contains('รายได้')) return Icons.description_outlined;
    if (docType.contains('นักศึกษา')) return Icons.school_outlined;
    return Icons.insert_drive_file_outlined;
  }
 
  Future<void> _goToAdd() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DocumentFormScreen()),
    );
    if (saved == true && mounted) {
      setState(() => _loadDocuments());
      _showSnack('เพิ่มเอกสารแล้ว');
    }
  }
 
  Future<void> _goToEdit(DocumentModel doc) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DocumentFormScreen(document: doc)),
    );
    if (saved == true && mounted) {
      setState(() => _loadDocuments());
      _showSnack('บันทึกการแก้ไขแล้ว');
    }
  }
 
  Future<void> _confirmDelete(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('ลบเอกสารนี้?'),
        content: Text('ต้องการลบ "${doc.docName}" ใช่หรือไม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xffC02C2C)),
            child: const Text('ลบเอกสาร'),
          ),
        ],
      ),
    );
 
    if (confirmed != true) return;
 
    final result = await DocumentService.deleteDocument(doc.documentId);
    if (!mounted) return;
 
    if (result.isError) {
      _showSnack(result.errorMessage);
    } else {
      setState(() => _loadDocuments());
      _showSnack('ลบเอกสารแล้ว');
    }
  }
 
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xfff8d7f3), Color(0xffeef2ff), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xff4B1528)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "เอกสารของฉัน",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff4B1528),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _loadDocuments();
                    });
                  },
                  child: FutureBuilder<
                      ({bool isError, List<DocumentModel> data, String errorMessage})>(
                    future: _futureDocuments,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xffD4537E),
                          ),
                        );
                      }
 
                      if (!snapshot.hasData || snapshot.data!.isError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                snapshot.data?.errorMessage ?? "เกิดข้อผิดพลาด",
                                style: const TextStyle(color: Color(0xff5F5E5A)),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _loadDocuments();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xffD4537E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text("ลองใหม่"),
                              ),
                            ],
                          ),
                        );
                      }
 
                      final documents = snapshot.data!.data;
 
                      if (documents.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_outlined,
                                  size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                "ยังไม่มีเอกสาร",
                                style: TextStyle(
                                  color: Color(0xff5F5E5A),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
 
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                        itemCount: documents.length,
                        itemBuilder: (context, index) {
                          final doc = documents[index];
                          final colorIndex = index % _iconBgColors.length;
 
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xffF4C0D1),
                                width: 0.6,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.pink.withValues(alpha: .06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: _iconBgColors[colorIndex],
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        _docIcon(doc.docType),
                                        color: _iconFgColors[colorIndex],
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc.docType,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xff2C2C2A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            doc.docName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xff5F5E5A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _statusBg(doc.status),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _statusLabel(doc.status),
                                        style: TextStyle(
                                          color: _statusFg(doc.status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () => _goToEdit(doc),
                                      icon: const Icon(Icons.edit_outlined, size: 19),
                                      color: const Color(0xff8A5F7D),
                                      visualDensity: VisualDensity.compact,
                                      style: IconButton.styleFrom(
                                        backgroundColor: const Color(0xffF4EEF7),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _confirmDelete(doc),
                                      icon: const Icon(Icons.delete_outline, size: 19),
                                      color: const Color(0xffD24444),
                                      visualDensity: VisualDensity.compact,
                                      style: IconButton.styleFrom(
                                        backgroundColor: const Color(0xffFDECEB),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xffD4537E),
        onPressed: _goToAdd,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
 