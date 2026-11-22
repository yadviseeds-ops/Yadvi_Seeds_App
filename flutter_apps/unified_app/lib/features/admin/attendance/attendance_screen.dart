import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/providers/admin_provider.dart';
import 'package:unified_app/models/attendance_model.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttendanceForSelectedDate();
    });
  }

  String _formatDateQuery(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateDisplay(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;

    if (isToday) {
      return 'Today ($day $month $year)';
    }
    return '$day $month $year';
  }

  void _loadAttendanceForSelectedDate() {
    final queryDate = _formatDateQuery(_selectedDate);
    Provider.of<AdminProvider>(context, listen: false).fetchAttendance(date: queryDate);
  }

  void _changeDate(int dayDelta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: dayDelta));
    });
    _loadAttendanceForSelectedDate();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAttendanceForSelectedDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final attendanceList = adminProvider.attendance;
    final isLoading = adminProvider.isLoadingAttendance;
    final error = adminProvider.attendanceError;

    final presentCount = attendanceList.where((a) => a.status.toLowerCase() == 'present').length;
    final absentCount = attendanceList.where((a) => a.status.toLowerCase() == 'absent').length;
    final totalCount = attendanceList.length;

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Force Attendance'),
        backgroundColor: const Color(0xFF083C28),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Attendance',
            onPressed: _loadAttendanceForSelectedDate,
          ),
        ],
      ),
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // Date Selector Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous Day',
                  onPressed: () => _changeDate(-1),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateDisplay(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next Day',
                  onPressed: () => _changeDate(1),
                ),
                if (!isToday) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedDate = DateTime.now());
                      _loadAttendanceForSelectedDate();
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppTheme.primaryGreen,
                    ),
                    child: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),

          // Attendance Summary Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Total Force', totalCount.toString(), Colors.black87),
                  _buildSummaryDivider(),
                  _buildSummaryItem('Present', presentCount.toString(), Colors.green.shade800),
                  _buildSummaryDivider(),
                  _buildSummaryItem('Absent', absentCount.toString(), Colors.red.shade800),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // Main Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadAttendanceForSelectedDate(),
              color: AppTheme.primaryGreen,
              child: _buildAttendanceList(isLoading, error, attendanceList),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildAttendanceList(bool isLoading, String? error, List<AttendanceModel> list) {
    if (isLoading && list.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                onPressed: _loadAttendanceForSelectedDate,
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'No Field Executives found in roster',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final att = list[i];
        final isPresent = att.status.toLowerCase() == 'present';

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            att.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                att.employeeCode.isNotEmpty ? 'Code: ${att.employeeCode}' : 'Field Executive',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                              if (att.phone != null && att.phone!.isNotEmpty) ...[
                                const Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                                Icon(Icons.phone, size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 2),
                                Text(
                                  '+91 ${att.phone}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPresent ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPresent ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPresent ? 'PRESENT' : 'ABSENT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                if (isPresent) ...[
                  Row(
                    children: [
                      const Icon(Icons.photo_camera_outlined, size: 15, color: AppTheme.primaryGreen),
                      const SizedBox(width: 6),
                      Text(
                        att.checkInTime != null
                            ? 'Visit proof uploaded: ${_formatTime(att.checkInTime!)}'
                            : 'Visit proof uploaded today',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)),
                      ),
                    ],
                  ),
                  if (att.checkInLocation != null && att.checkInLocation!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Location: ${att.checkInLocation}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ] else ...[
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'No visit proof photo uploaded on this date',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    // Format to 12-hour AM/PM
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
