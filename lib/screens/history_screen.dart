import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../db/measurement_dao.dart';
import '../db/cause_dao.dart';
import '../models/measurement_record.dart';
import '../models/cause_record.dart';
import '../services/user_session.dart';
import '../utils/constants.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _measureDao = MeasurementDao();
  final _causeDao = CauseDao();

  List<MeasurementRecord> _records = [];
  List<CauseRecord> _causeRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final userId = UserSession.instance.currentUser?.id;
    final records = userId != null
        ? await _measureDao.getByUserId(userId)
        : await _measureDao.getAll();
    final causes = userId != null
        ? await _causeDao.getByUserId(userId)
        : await _causeDao.getAll();
    if (mounted) {
      setState(() {
        _records = records;
        _causeRecords = causes;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecord(int id) async {
    await _measureDao.delete(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildTabBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.secondary))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildMeasurementTab(),
                            _buildTrendTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            '측정 기록',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: AppColors.primaryDark,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '측정 기록'),
          Tab(text: '트렌드'),
        ],
      ),
    );
  }

  // ── 측정 기록 탭 ────────────────────────────────────
  Widget _buildMeasurementTab() {
    if (_records.isEmpty) return _buildEmpty('측정 기록이 없어요', '측정을 완료하면 여기에 기록이 저장돼요');

    final grouped = <String, List<MeasurementRecord>>{};
    for (final r in _records) {
      grouped.putIfAbsent(_dateKey(r.measuredAt), () => []).add(r);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.secondary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: grouped.keys.length,
        itemBuilder: (context, index) {
          final key = grouped.keys.toList()[index];
          final dayRecords = grouped[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(key),
              const SizedBox(height: 8),
              ...dayRecords.map((r) => _buildRecordCard(r)),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(String key) {
    final isToday = key == _dateKey(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        isToday ? '오늘 · $key' : key,
        style: TextStyle(
          color: isToday ? AppColors.secondary : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRecordCard(MeasurementRecord record) {
    final stressColor = _stressColor(record.stressIndex);
    return Dismissible(
      key: Key('rec_${record.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteRecord(record.id!),
      child: GestureDetector(
        onTap: () => _showDetail(context, record),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: stressColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              // 스트레스 레벨 원
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: stressColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    record.stressLevel.replaceAll(' ', '\n'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: stressColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _timeStr(record.measuredAt),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: stressColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '스트레스 ${record.stressLevel}',
                            style: TextStyle(
                              color: stressColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _chip(Icons.favorite,
                            '${record.heartRate.toStringAsFixed(0)} BPM',
                            AppColors.error),
                        const SizedBox(width: 10),
                        _chip(Icons.show_chart,
                            'HRV ${record.hrv.toStringAsFixed(1)} ms',
                            AppColors.primaryLight),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── 트렌드 탭 ─────────────────────────────────────────
  Widget _buildTrendTab() {
    if (_records.isEmpty) {
      return _buildEmpty('트렌드 데이터가 없어요', '측정을 완료하면 트렌드를 확인할 수 있어요');
    }

    final last7 = _records.take(7).toList().reversed.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 요약 카드
          _buildSummaryCards(),
          const SizedBox(height: 20),

          // 스트레스 추이 그래프
          _buildChartCard(
            title: '스트레스 지수 추이',
            emoji: '📈',
            chart: _buildStressChart(last7),
          ),
          const SizedBox(height: 16),

          // HRV 추이 그래프
          _buildChartCard(
            title: 'HRV 추이',
            emoji: '📊',
            chart: _buildHrvChart(last7),
          ),
          const SizedBox(height: 16),

          // 원인 기록
          if (_causeRecords.isNotEmpty) ...[
            _buildCauseList(),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_records.isEmpty) return const SizedBox();
    final latest = _records.first;
    final avgStress = _records.take(7).map((r) => r.stressIndex).reduce((a, b) => a + b) /
        _records.take(7).length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            '최근 스트레스',
            latest.stressIndex.toStringAsFixed(0),
            latest.stressLevel,
            _stressColor(latest.stressIndex),
            '😊',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            '7일 평균',
            avgStress.toStringAsFixed(0),
            '평균 스트레스',
            _stressColor(avgStress),
            '📅',
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, String sub, Color color, String emoji) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1)),
          Text(sub,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String emoji,
    required Widget chart,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 140, child: chart),
        ],
      ),
    );
  }

  Widget _buildStressChart(List<MeasurementRecord> records) {
    if (records.isEmpty) return const SizedBox();
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.glassBorder, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= records.length) return const SizedBox();
                return Text(
                  '${records[i].measuredAt.month}/${records[i].measuredAt.day}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 9),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: records
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.stressIndex))
                .toList(),
            isCurved: true,
            color: AppColors.secondary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.secondary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.secondary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrvChart(List<MeasurementRecord> records) {
    if (records.isEmpty) return const SizedBox();
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.glassBorder, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= records.length) return const SizedBox();
                return Text(
                  '${records[i].measuredAt.month}/${records[i].measuredAt.day}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 9),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: records
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.hrv))
                .toList(),
            isCurved: true,
            color: AppColors.primaryLight,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.primaryLight,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryLight.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCauseList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📋', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                '원인 기록',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._causeRecords.take(5).map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 5, right: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(c.recordedAt),
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11),
                          ),
                          if (c.symptom.isNotEmpty && c.symptom != '미입력')
                            Text('증상: ${c.symptom}',
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    height: 1.5)),
                          if (c.cause.isNotEmpty && c.cause != '미입력')
                            Text('원인: ${c.cause}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmpty(String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 6),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, MeasurementRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _DetailSheet(record: record),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('기록 삭제',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('이 측정 기록을 삭제할까요?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Color _stressColor(double index) {
    if (index < 30) return const Color(0xFF5AAD77); // 낮음
    if (index < 60) return const Color(0xFFA8C45A); // 보통
    if (index < 80) return const Color(0xFFE8B84B); // 높음
    return const Color(0xFFEF5350);                 // 매우 높음
  }

  String _dateKey(DateTime dt) => '${dt.year}년 ${dt.month}월 ${dt.day}일';
  String _timeStr(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _formatDate(DateTime dt) =>
      '${dt.month}/${dt.day} ${_timeStr(dt)}';

  Widget _buildBg() {
    return Positioned(
      top: -80,
      left: -80,
      child: Container(
        width: 350,
        height: 350,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            AppColors.primaryLight.withOpacity(0.1),
            Colors.transparent,
          ]),
        ),
      ),
    );
  }
}

// ── 상세 바텀시트 ───────────────────────────────────────────────────────────

class _DetailSheet extends StatelessWidget {
  final MeasurementRecord record;
  const _DetailSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final stressColor = _stressColor(record.stressIndex);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _formatDateTime(record.measuredAt),
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // 스트레스 시각화 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: stressColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  record.stressLevel,
                  style: TextStyle(
                    color: stressColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: CustomPaint(
                    painter: _MiniStressGradientPainter(record.stressIndex),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Expanded(flex: 30, child: Text('낮음',    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF5AAD77), fontSize: 10, fontWeight: FontWeight.w600))),
                    Expanded(flex: 30, child: Text('보통',    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFA8C45A), fontSize: 10, fontWeight: FontWeight.w600))),
                    Expanded(flex: 20, child: Text('높음',    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFE8B84B), fontSize: 10, fontWeight: FontWeight.w600))),
                    Expanded(flex: 20, child: Text('매우 높음', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFEF5350), fontSize: 10, fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  icon: Icons.favorite,
                  label: '심박수',
                  value: record.heartRate.toStringAsFixed(0),
                  unit: 'BPM',
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoCard(
                  icon: Icons.show_chart,
                  label: '심박변이도',
                  value: record.hrv.toStringAsFixed(1),
                  unit: 'ms · ${record.hrvLevel}',
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '측정 시간: ${record.measurementDuration}초',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                color: color, fontSize: 26, fontWeight: FontWeight.w800, height: 1),
          ),
          Text(unit,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Color _stressColor(double index) {
    if (index < 30) return const Color(0xFF5AAD77); // 낮음
    if (index < 60) return const Color(0xFFA8C45A); // 보통
    if (index < 80) return const Color(0xFFE8B84B); // 높음
    return const Color(0xFFEF5350);                 // 매우 높음
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.year}년 ${dt.month}월 ${dt.day}일 '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _MiniStressGradientPainter extends CustomPainter {
  final double stressIndex;
  const _MiniStressGradientPainter(this.stressIndex);

  @override
  void paint(Canvas canvas, Size size) {
    const barH   = 12.0;
    const triH   = 11.0;
    const barTop = triH + 3.0;

    final barRect  = Rect.fromLTWH(0, barTop, size.width, barH);
    final barRRect = RRect.fromRectAndRadius(barRect, const Radius.circular(barH / 2));

    const gradient = LinearGradient(
      colors: [
        Color(0xFF43A047),
        Color(0xFF8BC34A),
        Color(0xFFFFEB3B),
        Color(0xFFFF9800),
        Color(0xFFF44336),
      ],
      stops: [0.0, 0.30, 0.55, 0.75, 1.0],
    );

    canvas.drawRRect(barRRect, Paint()..shader = gradient.createShader(barRect));

    final ix = (stressIndex / 100).clamp(0.04, 0.96) * size.width;
    final tri = Path()
      ..moveTo(ix, barTop)
      ..lineTo(ix - 7, barTop - triH)
      ..lineTo(ix + 7, barTop - triH)
      ..close();

    canvas.drawPath(tri, Paint()..color = Colors.white);
    canvas.drawPath(tri,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_MiniStressGradientPainter old) => old.stressIndex != stressIndex;
}
