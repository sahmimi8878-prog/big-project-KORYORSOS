import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserRoleChart extends StatefulWidget {
  const UserRoleChart({super.key});

  @override
  State<UserRoleChart> createState() => _UserRoleChartState();
}

class _UserRoleChartState extends State<UserRoleChart> {
  int students = 0;
  int officers = 0;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('http://127.0.0.1:3000/api/users/count_by_role'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['isError'] == false) {
        int s = 0;
        int o = 0;

        for (final row in result['data']) {
          if (row['role_id'] == 1) s = row['total'];
          if (row['role_id'] == 2) o = row['total'];
        }

        if (!mounted) return;

        setState(() {
          students = s;
          officers = o;
          isLoading = false;
        });
      } else {
        throw Exception(result['errorMessage'] ?? 'โหลดข้อมูลไม่สำเร็จ');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'ไม่สามารถโหลดข้อมูลสรุปผู้ใช้ได้';
      });
    }
  }

  Widget _statTile(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final highest = students > officers ? students : officers;
    final maxY = (highest < 1 ? 1 : highest) * 1.2;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      value == 0 ? 'นักศึกษา' : 'เจ้าหน้าที่',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff765982),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [
              BarChartRodData(
                toY: students.toDouble(),
                color: const Color(0xffeba6d0),
                width: 36,
                borderRadius: BorderRadius.circular(8),
              ),
            ]),
            BarChartGroupData(x: 1, barRods: [
              BarChartRodData(
                toY: officers.toDouble(),
                color: const Color(0xff8B6FA3),
                width: 36,
                borderRadius: BorderRadius.circular(8),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(120, 90, 160, 0.15),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xffb47aaa)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'จำนวนผู้ใช้ตาม Role',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff765982),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: const Color(0xffb47aaa),
                tooltip: 'รีเฟรช',
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (isLoading)
            const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xffeba6d0)),
              ),
            )
          else if (errorMessage.isNotEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                _statTile('นักศึกษา', students, const Color(0xffeba6d0)),
                const SizedBox(width: 12),
                _statTile('เจ้าหน้าที่', officers, const Color(0xff8B6FA3)),
              ],
            ),
            const SizedBox(height: 16),
            _buildChart(),
          ],
        ],
      ),
    );
  }
}