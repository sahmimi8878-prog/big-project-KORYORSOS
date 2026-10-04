import 'package:flutter/material.dart';
import 'package:my_app/models/document_model.dart';
import 'package:my_app/service/document_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/config/app_config.dart';

// ---------- Theme colors ----------
const kPrimary = Color(0xFF7A4F86);
const kAccent = Color(0xFFB57BBF);
const kIconBg = Color(0xFFFDE0EE);
const kTextMuted = Color(0xFF9A8AA0);

// ---------- Status helper ----------
enum DocStatus { pending, approved, rejected }

extension DocStatusX on DocStatus {
  static DocStatus parse(String s) => switch (s.toLowerCase()) {
        'approved' || 'approve' => DocStatus.approved,
        'rejected' || 'reject' => DocStatus.rejected,
        _ => DocStatus.pending,
      };

  String get label => switch (this) {
        DocStatus.pending => 'รอตรวจสอบ',
        DocStatus.approved => 'อนุมัติแล้ว',
        DocStatus.rejected => 'ไม่อนุมัติ',
      };
  Color get bg => switch (this) {
        DocStatus.pending => const Color(0xFFFFF1D6),
        DocStatus.approved => const Color(0xFFDFF3E4),
        DocStatus.rejected => const Color(0xFFFBE0E0),
      };
  Color get fg => switch (this) {
        DocStatus.pending => const Color(0xFF8A5A12),
        DocStatus.approved => const Color(0xFF1E6B3A),
        DocStatus.rejected => const Color(0xFF8E2A2A),
      };
}

// ---------- Helpers for DocumentModel ----------
extension DocumentModelUi on DocumentModel {
  DocStatus get docStatus => DocStatusX.parse(status);

  IconData get icon {
    final ext = filePath.contains('.') ? filePath.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'jpg' || 'jpeg' || 'png' => Icons.image_rounded,
      _ => Icons.description_rounded,
    };
  }

  String get dateText {
    final d = DateTime.tryParse(createdAt)?.toLocal();
    if (d == null) return '-';
    const m = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    return '${d.day} ${m[d.month - 1]} ${(d.year + 543) % 100}';
  }
}

// ---------- Page: เอกสารของนักศึกษาแต่ละคน ----------
/// หน้ารวมเอกสารของนักศึกษา 1 คน (เจ้าหน้าที่เปิดจากรายชื่อนักศึกษา)
class StudentDocumentsScreen extends StatefulWidget {
  final int userId;
  final String studentName;
  final String? studentCode;

  const StudentDocumentsScreen({
    super.key,
    required this.userId,
    required this.studentName,
    this.studentCode,
  });

  @override
  State<StudentDocumentsScreen> createState() => _StudentDocumentsScreenState();
}

class _StudentDocumentsScreenState extends State<StudentDocumentsScreen> {
  List<DocumentModel> _docs = [];
  bool _loading = true;
  String? _error;
  DocStatus? _filter; // null = all
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await DocumentService.getAllDocuments();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isError) {
        _error = res.errorMessage;
      } else {
        _docs = res.data.where((d) => d.userId == widget.userId).toList();
      }
    });
  }

  List<DocumentModel> get _visible => _docs.where((d) {
        final okStatus = _filter == null || d.docStatus == _filter;
        final q = _query.trim().toLowerCase();
        final okQuery = q.isEmpty ||
            d.docName.toLowerCase().contains(q) ||
            d.docType.toLowerCase().contains(q);
        return okStatus && okQuery;
      }).toList();

  int _count(DocStatus s) => _docs.where((d) => d.docStatus == s).length;

  Future<void> _setStatus(DocumentModel doc, String status) async {
    final res = await DocumentService.updateStatus(doc.documentId, status);
    if (!mounted) return;
    Navigator.pop(context); // ปิด bottom sheet
    if (res.isError) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.errorMessage)));
    } else {
      _load();
    }
  }

  Future<void> _openFile(DocumentModel doc) async {
    try {
      String filePath = doc.filePath.trim();

      // server ของเรา
      const serverUrl = 'http://127.0.0.1:3000';

      String url;

      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        url = filePath;
      } else if (filePath.startsWith('/')) {
        url = '$serverUrl$filePath';
      } else {
        url = '$serverUrl/$filePath';
      }

      debugPrint('================================');
      debugPrint('FILE PATH: $filePath');
      debugPrint('FILE URL : $url');
      debugPrint('================================');

      final uri = Uri.parse(url);

      // เปิดโดยตรง ไม่ใช้ canLaunchUrl
      final result = await launchUrl(
        uri,
        webOnlyWindowName: '_blank',
      );

      debugPrint('OPEN RESULT: $result');

      if (!result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดเอกสารได้')),
        );
      }
    } catch (e) {
      debugPrint('OPEN FILE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิดเอกสารไม่สำเร็จ: $e')),
      );
    }
  }

  void _showDetail(DocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ชื่อประเภทเอกสาร
            Text(
              doc.docType,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kPrimary,
              ),
            ),

            const SizedBox(height: 6),

            // ชื่อไฟล์
            Text(
              doc.docName,
              style: const TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 6),

            // สถานะ + วันที่
            Text(
              'สถานะ: ${doc.docStatus.label} · ${doc.dateText}',
              style: const TextStyle(fontSize: 12, color: kTextMuted),
            ),

            // หมายเหตุ ถ้ามี
            if (doc.note != null && doc.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'หมายเหตุ: ${doc.note}',
                style: const TextStyle(fontSize: 13, color: Colors.redAccent),
              ),
            ],

            const SizedBox(height: 20),

            // ปุ่มเปิดไฟล์
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openFile(doc),
                icon: const Icon(Icons.picture_as_pdf_rounded, color: kAccent),
                label: const Text(
                  'เปิดดูเอกสาร',
                  style: TextStyle(color: kPrimary, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: kAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ข้อความบอกเจ้าหน้าที่
            const Text(
              'กรุณาตรวจสอบเอกสารก่อนเลือกผลการตรวจสอบ',
              style: TextStyle(fontSize: 12, color: kTextMuted),
            ),

            const SizedBox(height: 12),

            // ปุ่มผลการตรวจสอบ
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setStatus(doc, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('ไม่อนุมัติ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setStatus(doc, 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('อนุมัติ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _visible;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8D7F0), Color(0xFFEEF0FF), Color(0xFFFCFCFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kPrimary,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.studentName,
                  style: const TextStyle(
                      color: kPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
              if (widget.studentCode != null)
                Text('รหัสนักศึกษา ${widget.studentCode}',
                    style: const TextStyle(color: kTextMuted, fontSize: 12)),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  _StatCard(label: 'ทั้งหมด', value: '${_docs.length}'),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'รอตรวจสอบ',
                    value: '${_count(DocStatus.pending)}',
                    valueColor: const Color(0xFFB7791F),
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'อนุมัติแล้ว',
                    value: '${_count(DocStatus.approved)}',
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'ไม่อนุมัติ',
                    value: '${_count(DocStatus.rejected)}',
                    valueColor: const Color(0xFF8E2A2A),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อเอกสารหรือประเภท',
                  hintStyle: const TextStyle(color: Color(0xFFA9A0AE), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: kAccent),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                children: [
                  _FilterChip(
                    label: 'ทั้งหมด',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final s in DocStatus.values)
                    _FilterChip(
                      label: s.label,
                      selected: _filter == s,
                      onTap: () => setState(() => _filter = s),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildList(docs)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<DocumentModel> docs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kTextMuted)),
            ),
            TextButton(onPressed: _load, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: kAccent,
      onRefresh: _load,
      child: docs.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('ไม่พบเอกสาร', style: TextStyle(color: kTextMuted))),
            ])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _DocCard(
                doc: docs[i],
                onTap: () => _showDetail(docs[i]),
              ),
            ),
    );
  }
}

// ---------- Page: รายชื่อนักศึกษา ----------
class _StudentGroup {
  final int userId;
  final String name;
  final String? code;
  final List<DocumentModel> docs = [];

  _StudentGroup({required this.userId, required this.name, this.code});

  int get pending => docs.where((d) => d.docStatus == DocStatus.pending).length;
}

class OfficerDocumentScreen extends StatefulWidget {
  const OfficerDocumentScreen({super.key});

  @override
  State<OfficerDocumentScreen> createState() => _OfficerDocumentScreenState();
}

class _OfficerDocumentScreenState extends State<OfficerDocumentScreen> {
  List<_StudentGroup> _students = [];
  int _docCount = 0;
  bool _loading = true;
  String? _error;
  bool _onlyPending = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await DocumentService.getAllDocuments();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isError) {
        _error = res.errorMessage;
        return;
      }
      final map = <int, _StudentGroup>{};
      for (final d in res.data) {
        map
            .putIfAbsent(
              d.userId,
              () => _StudentGroup(
                userId: d.userId,
                name: d.studentName ?? 'ผู้ใช้ #${d.userId}',
                code: d.studentCode,
              ),
            )
            .docs
            .add(d);
      }
      _docCount = res.data.length;
      // คนที่มีเอกสารรอตรวจสอบขึ้นก่อน
      _students = map.values.toList()
        ..sort((a, b) {
          final c = b.pending.compareTo(a.pending);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
    });
  }

  List<_StudentGroup> get _visible => _students.where((s) {
        if (_onlyPending && s.pending == 0) return false;
        final q = _query.trim().toLowerCase();
        return q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            (s.code ?? '').toLowerCase().contains(q);
      }).toList();

  int _countStatus(DocStatus st) => _students.fold(
      0, (sum, s) => sum + s.docs.where((d) => d.docStatus == st).length);

  Future<void> _open(_StudentGroup s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDocumentsScreen(
          userId: s.userId,
          studentName: s.name,
          studentCode: s.code,
        ),
      ),
    );
    if (mounted) _load(); // กลับมาแล้วรีเฟรช เผื่อมีการเปลี่ยนสถานะ
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8D7F0), Color(0xFFEEF0FF), Color(0xFFFCFCFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kPrimary,
          title: const Text('จัดการเอกสาร',
              style: TextStyle(color: kPrimary, fontWeight: FontWeight.w600)),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  _StatCard(label: 'ทั้งหมด', value: '$_docCount'),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'รอตรวจสอบ',
                    value: '${_countStatus(DocStatus.pending)}',
                    valueColor: const Color(0xFFB7791F),
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'อนุมัติแล้ว',
                    value: '${_countStatus(DocStatus.approved)}',
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'ไม่อนุมัติ',
                    value: '${_countStatus(DocStatus.rejected)}',
                    valueColor: const Color(0xFF8E2A2A),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อหรือรหัสนักศึกษา',
                  hintStyle: const TextStyle(color: Color(0xFFA9A0AE), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: kAccent),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                children: [
                  _FilterChip(
                    label: 'ทั้งหมด',
                    selected: !_onlyPending,
                    onTap: () => setState(() => _onlyPending = false),
                  ),
                  _FilterChip(
                    label: 'มีเอกสารรอตรวจสอบ',
                    selected: _onlyPending,
                    onTap: () => setState(() => _onlyPending = true),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('นักศึกษาที่ส่งเอกสาร ${_students.length} คน',
                    style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ),
            ),
            Expanded(child: _buildList(list)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<_StudentGroup> list) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kTextMuted)),
            ),
            TextButton(onPressed: _load, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: kAccent,
      onRefresh: _load,
      child: list.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('ไม่พบนักศึกษา', style: TextStyle(color: kTextMuted))),
            ])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _StudentCard(
                student: list[i],
                onTap: () => _open(list[i]),
              ),
            ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final _StudentGroup student;
  final VoidCallback onTap;

  const _StudentCard({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pending = student.pending;
    final initial = student.name.trim().isEmpty ? '?' : student.name.trim()[0];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: const Color(0x1A7A4F86),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kIconBg,
                child: Text(initial,
                    style: const TextStyle(
                        color: kPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5E3D68),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student.code ?? '-'} · ส่งเอกสาร ${student.docs.length} รายการ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: pending > 0
                            ? DocStatus.pending.bg
                            : DocStatus.approved.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        pending > 0 ? 'รอตรวจสอบ $pending' : 'ตรวจครบแล้ว',
                        style: TextStyle(
                          fontSize: 12,
                          color: pending > 0 ? DocStatus.pending.fg : DocStatus.approved.fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kAccent),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Widgets ----------
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor = kPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, color: kTextMuted)),
            ),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: valueColor)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kAccent : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Colors.white : kPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;

  const _DocCard({
    required this.doc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = doc.docStatus;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: const Color(0x1A7A4F86),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kIconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(doc.icon, color: kAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.docName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5E3D68),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.docType} · ${doc.dateText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: status.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(fontSize: 12, color: status.fg),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kAccent),
            ],
          ),
        ),
      ),
    );
  }
}