import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_api.dart';
import '../../../widgets/booking_date_picker_dialog.dart';

const List<String> _monthNames = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];
const List<String> _monthShort = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];
const List<String> _weekdayNames = [
  'อาทิตย์',
  'จันทร์',
  'อังคาร',
  'พุธ',
  'พฤหัสบดี',
  'ศุกร์',
  'เสาร์',
];
const List<String> _weekdayShort = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

/// สถานที่ยื่นเอกสารและรายละเอียดเริ่มต้นของวันที่เปิดรับใหม่ (ไม่มีช่องให้แก้ในหน้านี้แล้ว)
const String _defaultLocation = 'กองพัฒนานักศึกษา อาคาร 2';
const String _defaultNote = 'กรุณานำเอกสารฉบับจริงมายื่นตามวันและเวลาที่จอง';

const int _maxCapacity = 100;
const int _maxRangeDays = 92; // เลือกช่วงวันที่ได้ไม่เกินกี่วัน

String _fmtTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

int _parseStart(String slot) {
  final p = slot.split(' - ')[0].split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

int _parseEnd(String slot) {
  final p = slot.split(' - ')[1].split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String _thaiShort(DateTime d) =>
    '${d.day} ${_monthShort[d.month - 1]} ${d.year + 543}';

/// รอบเวลา 1 รอบของวัน
class _SlotCfg {
  int start; // นาทีนับจาก 00:00
  int end;
  bool open;
  int capacity;
  int booked; // จำนวนที่จองไปแล้ว (ลบรอบนี้ไม่ได้ถ้า > 0)

  _SlotCfg({
    required this.start,
    required this.end,
    this.open = true,
    this.capacity = 5,
    this.booked = 0,
  });

  _SlotCfg copy() => _SlotCfg(
    start: start,
    end: end,
    open: open,
    capacity: capacity,
    booked: 0,
  );

  String get name => '${_fmtTime(start)} - ${_fmtTime(end)}';
}

/// การตั้งค่าของ 1 วัน
class _DayCfg {
  bool open;
  String location;
  String note;
  List<_SlotCfg> slots;

  _DayCfg({
    this.open = true,
    this.location = _defaultLocation,
    this.note = _defaultNote,
    required this.slots,
  });

  // รอบมาตรฐาน 09:00 - 16:00 ช่วงละ 30 นาที พักเที่ยง 12:00 - 13:00
  factory _DayCfg.defaults() {
    return _DayCfg(
      slots: [
        for (int start = 9 * 60; start < 16 * 60; start += 30)
          if (start < 12 * 60 || start >= 13 * 60)
            _SlotCfg(start: start, end: start + 30),
      ],
    );
  }

  _DayCfg copy() => _DayCfg(
    open: open,
    location: location,
    note: note,
    slots: slots.map((s) => s.copy()).toList(),
  );

  int get openSlots => slots.where((s) => s.open).length;
  int get totalCapacity =>
      slots.where((s) => s.open).fold(0, (a, s) => a + s.capacity);
}

/// หน้าเพิ่มข้อมูลการจอง (เปิดรับการจอง) ของเจ้าหน้าที่
/// 1) เลือกช่วงวันที่เปิดรับการจอง  2) ตั้งสถานที่และรอบเวลาของแต่ละวัน  แล้วบันทึกและเปิดให้จอง
/// ส่ง initialFrom/initialTo เพื่อเปิดมาที่รอบการจองที่มีอยู่ (โหมดแก้ไขรอบ)
class BookingEditScreen extends StatefulWidget {
  const BookingEditScreen({
    super.key,
    this.initialFrom,
    this.initialTo,
    this.embedded = false,
  });

  /// true = ฝังในหน้าจัดการระบบการจอง (ไม่แสดงหัวหน้าและปุ่มย้อนกลับของตัวเอง)
  final bool embedded;

  final DateTime? initialFrom;
  final DateTime? initialTo;

  bool get isEditingRound => initialFrom != null;

  @override
  State<BookingEditScreen> createState() => _BookingEditScreenState();
}

class _BookingEditScreenState extends State<BookingEditScreen> {
  DateTime _from = DateUtils.dateOnly(DateTime.now());
  DateTime _to = DateUtils.dateOnly(DateTime.now());
  DateTime _selected = DateUtils.dateOnly(DateTime.now());

  final Map<DateTime, _DayCfg> _days = {};
  int _bulkCapacity = 5;

  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();

    if (widget.initialFrom != null) {
      _from = DateUtils.dateOnly(widget.initialFrom!);
      _to = DateUtils.dateOnly(widget.initialTo ?? widget.initialFrom!);
      _selected = _from;
    }

    _loadRange();
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<DateTime> get _rangeDays {
    final List<DateTime> list = [];
    for (
      DateTime d = _from;
      !d.isAfter(_to);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      list.add(d);
    }
    return list;
  }

  _DayCfg get _current => _days[_selected]!;

  String _api(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  // โหลดค่าที่เคยตั้งไว้ของช่วงวันที่เลือก วันที่ยังไม่เคยตั้งใช้ค่ามาตรฐาน
  Future<void> _loadRange() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await AppAPI.get(
        '/admin/open-days?from=${_api(_from)}&to=${_api(_to)}',
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (json['isError'] == true) {
        setState(() {
          _errorMessage = (json['errorMessage'] ?? 'โหลดข้อมูลไม่ได้')
              .toString();
          _isLoading = false;
        });
        return;
      }

      final Map<DateTime, _DayCfg> saved = {};
      for (final row in json['data'] as List) {
        final date = DateUtils.dateOnly(
          DateFormat('dd-MM-yyyy').parse(row['date'] as String),
        );

        final String location = (row['location'] ?? '').toString();

        saved[date] = _DayCfg(
          open: row['is_open'] == true,
          location: location,
          note: (row['note'] ?? '').toString(),
          slots: [
            for (final s in row['slots'] as List)
              _SlotCfg(
                start: _parseStart(s['time_slot'] as String),
                end: _parseEnd(s['time_slot'] as String),
                open: s['is_open'] == true,
                capacity: (s['capacity'] as num).toInt(),
                booked: (s['booked'] as num).toInt(),
              ),
          ],
        );
      }

      setState(() {
        final old = Map<DateTime, _DayCfg>.of(_days);
        _days.clear();

        for (final d in _rangeDays) {
          // ที่แก้ค้างอยู่ในหน้าจอ > ที่บันทึกไว้ในระบบ > ค่ามาตรฐาน
          _days[d] = old[d] ?? saved[d] ?? _DayCfg.defaults();
        }

        if (!_days.containsKey(_selected)) _selected = _from;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้';
        _isLoading = false;
      });
    }
  }

  void _selectDay(DateTime d) {
    setState(() {
      _selected = d;
    });
  }

  Future<void> _pickFrom() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showBookingDatePicker(
      context: context,
      initialDate: _from,
      firstDate: _from.isBefore(today) ? _from : today,
      bookedDates: const {},
    );
    if (picked == null) return;

    final from = DateUtils.dateOnly(picked);
    setState(() {
      _from = from;
      if (_to.isBefore(from)) _to = from;
      _selected = from;
    });
    _checkRangeAndLoad();
  }

  Future<void> _pickTo() async {
    final picked = await showBookingDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      bookedDates: const {},
    );
    if (picked == null) return;

    setState(() => _to = DateUtils.dateOnly(picked));
    _checkRangeAndLoad();
  }

  void _checkRangeAndLoad() {
    if (_to.difference(_from).inDays + 1 > _maxRangeDays) {
      _showMessage('เลือกช่วงวันที่ได้ไม่เกิน $_maxRangeDays วัน');
      setState(() => _to = _from.add(const Duration(days: _maxRangeDays - 1)));
    }
    _loadRange();
  }

  // ---------- แก้ไขรอบเวลา ----------
  Future<void> _pickTime(_SlotCfg slot, {required bool isStart}) async {
    final int current = isStart ? slot.start : slot.end;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      final minutes = picked.hour * 60 + picked.minute;
      if (isStart) {
        slot.start = minutes;
        if (slot.end <= slot.start) {
          slot.end = (slot.start + 30).clamp(0, 24 * 60 - 1);
        }
      } else {
        slot.end = minutes;
      }
      _current.slots.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  void _addSlot() {
    setState(() {
      final slots = _current.slots;
      final int start = slots.isEmpty
          ? 9 * 60
          : slots.map((s) => s.end).reduce((a, b) => a > b ? a : b);
      final int end = (start + 30).clamp(0, 24 * 60 - 1);

      slots.add(
        _SlotCfg(
          start: start.clamp(0, 24 * 60 - 31),
          end: end,
          capacity: _bulkCapacity,
        ),
      );
      slots.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  void _removeSlot(_SlotCfg slot) {
    setState(() => _current.slots.remove(slot));
  }

  void _applyBulk() {
    setState(() {
      for (final s in _current.slots) {
        s.capacity = _bulkCapacity;
      }
    });
  }

  void _applyToAllDays() {
    setState(() {
      for (final d in _days.keys) {
        if (d != _selected) _days[d] = _current.copy();
      }
    });
    _showMessage('ใช้ค่านี้กับทุกวันในช่วงที่เลือกแล้ว (ยังไม่ได้บันทึก)');
  }

  // ---------- บันทึก ----------
  String? _validate() {
    for (final entry in _days.entries) {
      final day = entry.value;
      final label = _thaiShort(entry.key);

      if (day.open && day.slots.isEmpty) {
        return 'วันที่ $label เปิดรับแล้วต้องมีอย่างน้อย 1 รอบเวลา';
      }

      final sorted = [...day.slots]..sort((a, b) => a.start.compareTo(b.start));
      for (int i = 0; i < sorted.length; i++) {
        if (sorted[i].end <= sorted[i].start) {
          return 'วันที่ $label รอบ ${sorted[i].name} เวลาไม่ถูกต้อง';
        }
        if (i > 0 && sorted[i].start < sorted[i - 1].end) {
          return 'วันที่ $label รอบ ${sorted[i - 1].name} ซ้อนกับ ${sorted[i].name}';
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await AppAPI.post('/admin/open-days', {
        'days': [
          for (final d in _rangeDays)
            {
              'date': _api(d),
              'is_open': _days[d]!.open,
              'location': _days[d]!.location.trim(),
              'note': _days[d]!.note.trim(),
              'slots': [
                for (final s in _days[d]!.slots)
                  {
                    'time_slot': s.name,
                    'capacity': s.capacity,
                    'is_open': s.open,
                  },
              ],
            },
        ],
      });
      final json = jsonDecode(response.body);

      if (!mounted) return;

      if (json['isError'] == true) {
        _showMessage((json['errorMessage'] ?? 'บันทึกไม่สำเร็จ').toString());
        return;
      }

      _days.clear(); // โหลดค่าที่บันทึกแล้วกลับมาแสดง
      await _loadRange();
      if (mounted) _showMessage('บันทึกและเปิดให้จองเรียบร้อย');
    } catch (e) {
      if (mounted) _showMessage('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.embedded) _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? Center(child: Text(_errorMessage))
                  // ทุกส่วนเรียงลงมาในคอลัมน์เดียว ปุ่มบันทึกอยู่ล่างสุด
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildStep1(),
                        const SizedBox(height: 16),
                        _buildStep2(),
                        const SizedBox(height: 16),
                        _buildSaveCard(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          ),
          Expanded(
            child: Text(
              widget.isEditingRound ? 'แก้ไขรอบการจอง' : 'เพิ่มข้อมูลการจอง',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _stepBadge(String number) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xff3d2c6b),
        shape: BoxShape.circle,
      ),
      child: Text(
        number,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------- ขั้นที่ 1: เลือกช่วงวันที่ ----------
  Widget _buildStep1() {
    final days = _rangeDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stepBadge('1'),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'เลือกช่วงวันที่ที่จะเปิดรับการจอง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dateField('เริ่มเปิดรับ', _from, _pickFrom),
              _dateField('วันสุดท้ายที่เปิด', _to, _pickTo),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'รวม ${days.length} วัน',
            style: const TextStyle(fontSize: 12, color: AppColors.iconPurple),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days.map(_dayChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _thaiShort(value),
                      style: const TextStyle(color: AppColors.textDark),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.cardPink,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayChip(DateTime d) {
    final cfg = _days[d];
    final bool isSelected = d == _selected;
    final bool isOpen = cfg?.open ?? true;

    return InkWell(
      onTap: () => _selectDay(d),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xff3d2c6b)
              : (isOpen ? AppColors.gradientStart : AppColors.chipFull),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              _weekdayShort[d.weekday % 7],
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : AppColors.iconPurple,
              ),
            ),
            Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
            Text(
              _monthShort[d.month - 1],
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : AppColors.iconPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- ขั้นที่ 2: ตั้งค่ารอบเวลาของวัน ----------
  Widget _buildStep2() {
    final day = _current;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stepBadge('2'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'วัน${_weekdayNames[_selected.weekday % 7]}ที่ ${_selected.day} ${_monthNames[_selected.month - 1]} ${_selected.year + 543}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      day.open ? 'พร้อมเปิดจอง' : 'ปิดรับวันนี้',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: day.open
                            ? const Color(0xff1a8f4d)
                            : AppColors.chipFullText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Switch(
                      value: day.open,
                      activeThumbColor: AppColors.cardPink,
                      onChanged: (v) => setState(() => day.open = v),
                    ),
                    const Text(
                      'เปิดรับวันนี้',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          _buildSlotsHeader(day),
          const SizedBox(height: 12),
          _buildSlotTable(day),
        ],
      ),
    );
  }

  Widget _buildSlotsHeader(_DayCfg day) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รอบเวลา',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            Text(
              'เปิดอยู่ ${day.openSlots} จาก ${day.slots.length} รอบ รับได้รวม ${day.totalCapacity} คน',
              style: const TextStyle(fontSize: 13, color: AppColors.iconPurple),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ทุกรอบ',
                    style: TextStyle(fontSize: 12, color: AppColors.iconPurple),
                  ),
                  const SizedBox(width: 6),
                  _stepper(
                    value: _bulkCapacity,
                    onChanged: (v) => setState(() => _bulkCapacity = v),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _applyBulk,
                    child: const Text(
                      'ใช้',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardPink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _applyToAllDays,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('ใช้ค่านี้กับทุกวัน'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.iconPurple,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlotTable(_DayCfg day) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff7f5ff),
        border: Border.all(color: const Color(0xffe6e1f7)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'ช่วงเวลา',
                    style: TextStyle(fontSize: 12, color: AppColors.iconPurple),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'เปิดให้จอง',
                    style: TextStyle(fontSize: 12, color: AppColors.iconPurple),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'จำนวนคนต่อรอบ',
                    style: TextStyle(fontSize: 12, color: AppColors.iconPurple),
                  ),
                ),
                SizedBox(width: 40),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < day.slots.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  if (_showBreak(day) && i == _breakIndex(day)) ...[
                    _buildBreakRow(),
                    const Divider(height: 1),
                  ],
                  _buildSlotRow(day.slots[i]),
                ],
                if (day.slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'ยังไม่มีรอบเวลา กดเพิ่มรอบเวลาด้านล่าง',
                      style: TextStyle(color: AppColors.iconPurple),
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextButton.icon(
                    onPressed: _addSlot,
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.cardPink,
                    ),
                    label: const Text(
                      'เพิ่มรอบเวลา',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardPink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // แสดงแถว "พักเที่ยง 12:00 - 13:00" ถ้าไม่มีรอบเวลาคาบเกี่ยวช่วงนี้ และมีรอบทั้งก่อนและหลัง
  bool _showBreak(_DayCfg day) {
    const int breakStart = 12 * 60;
    const int breakEnd = 13 * 60;

    final bool overlaps = day.slots.any(
      (s) => s.start < breakEnd && breakStart < s.end,
    );
    final bool hasBefore = day.slots.any((s) => s.end <= breakStart);
    final bool hasAfter = day.slots.any((s) => s.start >= breakEnd);

    return !overlaps && hasBefore && hasAfter;
  }

  // ตำแหน่งที่แถวพักเที่ยงแทรก (รอบแรกที่เริ่มหลังพักเที่ยง)
  int _breakIndex(_DayCfg day) =>
      day.slots.indexWhere((s) => s.start >= 13 * 60);

  Widget _buildBreakRow() {
    return Opacity(
      opacity: 0.5,
      child: Container(
        color: const Color(0xfffafafa),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: const Row(
          children: [
            Icon(Icons.restaurant_rounded, size: 18, color: Colors.grey),
            SizedBox(width: 10),
            Text(
              '12:00 - 13:00',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(width: 12),
            Text('พักเที่ยง', style: TextStyle(color: Colors.grey)),
            Spacer(),
            Text(
              'ไม่เปิดรับจอง',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotRow(_SlotCfg s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  child: _timeBox(s.start, () => _pickTime(s, isStart: true)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(
                  child: _timeBox(s.end, () => _pickTime(s, isStart: false)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Switch(
                  value: s.open,
                  activeThumbColor: AppColors.cardPink,
                  onChanged: (v) => setState(() => s.open = v),
                ),
                Flexible(
                  child: Text(
                    s.open ? 'เปิด' : 'ปิด',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: s.open
                          ? AppColors.textDark
                          : AppColors.chipFullText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepper(
                  value: s.capacity,
                  onChanged: (v) => setState(() => s.capacity = v),
                ),
                if (s.booked > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'จองแล้ว ${s.booked} คน',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.iconPurple,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: s.booked > 0 ? 'มีผู้จองแล้ว ลบไม่ได้' : 'ลบรอบนี้',
              onPressed: s.booked > 0 ? null : () => _removeSlot(s),
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(int minutes, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _fmtTime(minutes),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const Icon(Icons.access_time_rounded, size: 17, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ปุ่ม − [ตัวเลข] + จำนวนคน 0 - 100
  Widget _stepper({required int value, required ValueChanged<int> onChanged}) {
    Widget button(IconData icon, VoidCallback? onTap) {
      return InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? Colors.grey.shade400 : AppColors.textDark,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove, value > 0 ? () => onChanged(value - 1) : null),
          Container(
            width: 44,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xff3d2c6b),
              ),
            ),
          ),
          button(
            Icons.add,
            value < _maxCapacity ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  // ---------- สรุปด้านขวา ----------
  // ---------- การ์ดบันทึก ----------
  Widget _buildSaveCard() {
    final openDays = _days.values.where((d) => d.open).toList();
    final int total = openDays.fold(0, (a, d) => a + d.totalCapacity);
    final String range = _from == _to
        ? _thaiShort(_from)
        : '${_from.day} ${_monthShort[_from.month - 1]} ถึง ${_thaiShort(_to)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'บันทึกและเปิดให้จอง',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$range เปิดรับ ${openDays.length} วัน รวม ${NumberFormat('#,###').format(total)} คน',
            style: const TextStyle(fontSize: 13, color: AppColors.iconPurple),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffe8388f),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'บันทึกและเปิดให้จอง',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({double radius = 24}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: AppColors.cardPink.withValues(alpha: 0.18),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
