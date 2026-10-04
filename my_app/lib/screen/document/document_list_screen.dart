import 'package:flutter/material.dart';
import 'package:my_app/config/app_colors.dart';
import 'package:my_app/models/document_model.dart';
import 'package:my_app/screen/document/document_form_screen.dart';
import 'package:my_app/service/document_service.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  late Future<
      ({
        bool isError,
        List<DocumentModel> data,
        String errorMessage
      })> _futureDocuments;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  void _loadDocuments() {
    _futureDocuments = DocumentService.getDocuments();
  }

  static final List<Color> _iconBgColors = [
    AppColors.cardPurple.withValues(alpha: 0.45),
    AppColors.cardPink.withValues(alpha: 0.35),
    AppColors.cardCream,
    AppColors.chipFull,
  ];

  static const List<Color> _iconFgColors = [
    AppColors.iconPurple,
    AppColors.textOnPink,
    AppColors.textDark,
    AppColors.iconPurple,
  ];

  Color _statusBg(String status) {
    switch (status) {
      case 'approved':
        return AppColors.cardPurple.withValues(alpha: 0.55);
      case 'rejected':
        return AppColors.cardPink.withValues(alpha: 0.40);
      default:
        return AppColors.cardCream;
    }
  }

  Color _statusFg(String status) {
    switch (status) {
      case 'approved':
        return AppColors.iconPurple;
      case 'rejected':
        return AppColors.textOnPink;
      default:
        return const Color(0xffA0674B);
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

  Map<String, int> _countByStatus(List<DocumentModel> docs) {
    final counts = {
      'pending': 0,
      'approved': 0,
      'rejected': 0,
    };

    for (final doc in docs) {
      counts[doc.status] = (counts[doc.status] ?? 0) + 1;
    }

    return counts;
  }

  Widget _buildStatusSummary(List<DocumentModel> docs) {
    final counts = _countByStatus(docs);

    final items = [
      {
        'status': 'pending',
        'label': 'รอตรวจสอบ',
        'count': counts['pending']!,
      },
      {
        'status': 'approved',
        'label': 'อนุมัติแล้ว',
        'count': counts['approved']!,
      },
      {
        'status': 'rejected',
        'label': 'ถูกปฏิเสธ',
        'count': counts['rejected']!,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: items.map((item) {
          final status = item['status'] as String;
          final label = item['label'] as String;
          final count = item['count'] as int;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _statusBg(status),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _statusFg(status),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: _statusFg(status),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _docIcon(String docType) {
    if (docType.contains('บัตรประชาชน')) {
      return Icons.badge_outlined;
    }

    if (docType.contains('ทะเบียนบ้าน')) {
      return Icons.home_outlined;
    }

    if (docType.contains('รายได้')) {
      return Icons.description_outlined;
    }

    if (docType.contains('นักศึกษา')) {
      return Icons.school_outlined;
    }

    if (docType.contains('สัญญา')) {
      return Icons.assignment_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }

  // เพิ่มเอกสาร
  Future<void> _goToAdd() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const DocumentFormScreen(),
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _loadDocuments();
      });

      _showSnack('เพิ่มเอกสารแล้ว');
    }
  }

  // แก้ไขเอกสาร
  Future<void> _goToEdit(DocumentModel doc) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentFormScreen(
          document: doc,
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _loadDocuments();
      });

      _showSnack('แก้ไขเอกสารแล้ว');
    }
  }

  // ลบเอกสาร
  Future<void> _confirmDelete(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('ลบเอกสารนี้?'),
        content: Text(
          'ต้องการลบ "${doc.docName}" ใช่หรือไม่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textOnPink,
            ),
            child: const Text('ลบเอกสาร'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await DocumentService.deleteDocument(
      doc.documentId,
    );

    if (!mounted) return;

    if (result.isError) {
      _showSnack(result.errorMessage);
    } else {
      setState(() {
        _loadDocuments();
      });

      _showSnack('ลบเอกสารแล้ว');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xfff8d7f3),
              Color(0xffeef2ff),
              Colors.white,
            ],
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
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textDark,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'เอกสารของฉัน',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  color: AppColors.iconPurple,
                  onRefresh: () async {
                    setState(() {
                      _loadDocuments();
                    });
                  },
                  child: FutureBuilder<
                      ({
                        bool isError,
                        List<DocumentModel> data,
                        String errorMessage
                      })>(
                    future: _futureDocuments,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.cardPink,
                          ),
                        );
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.isError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                snapshot.data?.errorMessage ??
                                    'เกิดข้อผิดพลาด',
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _loadDocuments();
                                  });
                                },
                                child: const Text('ลองใหม่'),
                              ),
                            ],
                          ),
                        );
                      }

                      final documents = snapshot.data!.data;

                      if (documents.isEmpty) {
                        return const Center(
                          child: Text(
                            'ยังไม่มีเอกสาร',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 15,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          _buildStatusSummary(documents),

                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                4,
                                20,
                                90,
                              ),
                              itemCount: documents.length,
                              itemBuilder: (context, index) {
                                final doc = documents[index];

                                final colorIndex =
                                    index % _iconBgColors.length;

                                return Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 14,
                                  ),
                                  padding:
                                      const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.cardPurple
                                          .withValues(alpha: 0.5),
                                      width: 0.6,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.iconPurple
                                            .withValues(alpha: .10),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration:
                                                BoxDecoration(
                                              color:
                                                  _iconBgColors[
                                                      colorIndex],
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      14),
                                            ),
                                            child: Icon(
                                              _docIcon(doc.docType),
                                              color:
                                                  _iconFgColors[
                                                      colorIndex],
                                              size: 24,
                                            ),
                                          ),

                                          const SizedBox(width: 12),

                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(
                                                  doc.docType,
                                                  style:
                                                      const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: AppColors
                                                        .textDark,
                                                  ),
                                                ),
                                                const SizedBox(
                                                    height: 2),
                                                Text(
                                                  doc.docName,
                                                  style:
                                                      const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .chipFullText,
                                                  ),
                                                  overflow:
                                                      TextOverflow
                                                          .ellipsis,
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
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusBg(
                                                  doc.status),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      20),
                                            ),
                                            child: Text(
                                              _statusLabel(
                                                  doc.status),
                                              style: TextStyle(
                                                color: _statusFg(
                                                    doc.status),
                                                fontWeight:
                                                    FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),

                                          const Spacer(),

                                          // ปุ่มแก้ไข
                                          IconButton(
                                            onPressed: () =>
                                                _goToEdit(doc),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 19,
                                            ),
                                            color:
                                                AppColors.iconPurple,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),

                                          const SizedBox(width: 4),

                                          // ปุ่มลบ
                                          IconButton(
                                            onPressed: () =>
                                                _confirmDelete(doc),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 19,
                                            ),
                                            color:
                                                AppColors.textOnPink,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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
        backgroundColor: AppColors.cardPink,
        onPressed: _goToAdd,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}