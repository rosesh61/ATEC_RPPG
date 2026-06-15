import 'package:flutter/material.dart';
import '../db/cause_dao.dart';
import '../models/cause_record.dart';
import '../services/shared_api_service.dart';
import '../services/user_session.dart';
import '../utils/constants.dart';
import '../widgets/avatar_widget.dart';

class CauseRecordScreen extends StatefulWidget {
  final int? measurementId;
  const CauseRecordScreen({super.key, this.measurementId});

  @override
  State<CauseRecordScreen> createState() => _CauseRecordScreenState();
}

class _CauseRecordScreenState extends State<CauseRecordScreen> {
  int _step = 0; // 0: 증상 선택, 1: 원인 선택, 2: 완료

  // 선택된 증상/원인 목록
  final Set<String> _selectedSymptoms = {};
  final Set<String> _selectedCauses = {};
  final _customController = TextEditingController();
  bool _isSaving = false;

  static const _symptoms = [
    _Item('😔', '우울함'),
    _Item('😤', '짜증남'),
    _Item('😰', '불안함'),
    _Item('😩', '피곤함'),
    _Item('😖', '답답함'),
    _Item('😶', '무기력함'),
    _Item('🤯', '머리가 아픔'),
    _Item('💤', '잠을 못 잠'),
  ];

  static const _causes = [
    _Item('👥', '대인관계'),
    _Item('💼', '일/업무'),
    _Item('💰', '경제적 문제'),
    _Item('🏠', '가족 문제'),
    _Item('🏥', '건강 문제'),
    _Item('📅', '일정/시간'),
    _Item('🌙', '수면 부족'),
    _Item('🍽️', '식사 불규칙'),
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedSymptoms.isEmpty && _selectedCauses.isEmpty) {
      _showDone();
      return;
    }

    setState(() => _isSaving = true);

    final userId = UserSession.instance.currentUser?.id;
    final symptomText = _selectedSymptoms.join(', ');
    final causeText = _selectedCauses.isNotEmpty
        ? _selectedCauses.join(', ')
        : (_customController.text.trim().isNotEmpty
            ? _customController.text.trim()
            : '미입력');

    final record = CauseRecord(
      userId: userId,
      measurementId: widget.measurementId,
      symptom: symptomText.isNotEmpty ? symptomText : '미입력',
      cause: causeText,
    );
    final recordId = await CauseDao().insert(record);

    // 서버 동기화 (실패해도 로컬 저장은 완료, SyncService가 나중에 재시도)
    final serverId = UserSession.instance.currentUser?.serverId;
    if (serverId != null) {
      final ok = await SharedApiService.instance.saveCause(
        serverId,
        symptom: record.symptom,
        cause: record.cause,
        sessionId: widget.measurementId,
      );
      if (ok) await CauseDao().markSynced(recordId);
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _step = 2;
    });
  }

  void _showDone() {
    setState(() => _step = 2);
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
                _buildAppBar(context),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
            '증상·원인 기록',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // 단계 인디케이터
          if (_step < 2)
            Row(
              children: List.generate(2, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 5),
                width: i == _step ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _step
                      ? AppColors.secondary
                      : AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _step == 0
          ? _buildSymptomStep()
          : _step == 1
              ? _buildCauseStep()
              : _buildDoneStep(),
    );
  }

  Widget _buildSymptomStep() {
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: AvatarWidget(
              size: 90,
              message: '오늘 어떠셨나요?\n해당되는 것을 골라주세요 😊',
              isAnimating: true,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '오늘 어떤 느낌이 드셨나요?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '해당하는 것을 모두 선택해주세요 (여러 개 가능)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: _symptoms
                .map((item) => _buildSelectChip(
                      item,
                      _selectedSymptoms.contains(item.label),
                      () => setState(() {
                        if (_selectedSymptoms.contains(item.label)) {
                          _selectedSymptoms.remove(item.label);
                        } else {
                          _selectedSymptoms.add(item.label);
                        }
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('건너뛰기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    '다음 →',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCauseStep() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: AvatarWidget(
              size: 90,
              message: '어떤 이유가 있으셨나요?\n기록해두면 도움이 돼요 🍃',
              isAnimating: true,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '원인이 있으셨나요?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '해당하는 것을 골라주세요 (여러 개 가능)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: _causes
                .map((item) => _buildSelectChip(
                      item,
                      _selectedCauses.contains(item.label),
                      () => setState(() {
                        if (_selectedCauses.contains(item.label)) {
                          _selectedCauses.remove(item.label);
                        } else {
                          _selectedCauses.add(item.label);
                        }
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // 직접 입력
          const Text(
            '직접 입력',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '다른 이유가 있으면 적어주세요...',
              hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.6),
                  fontSize: 14),
              filled: true,
              fillColor: AppColors.glassWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('← 이전'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryDark,
                          ),
                        )
                      : const Text(
                          '기록 완료',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDoneStep() {
    return Center(
      key: const ValueKey(2),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              '잘 작성해주셨어요!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '기록이 저장됐어요.\n다음에도 꼭 기록해주세요! 😊',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.glassWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.primaryLight, AppColors.primaryDark],
                      ),
                    ),
                    child: const Center(
                        child: Text('🌿', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '기록을 꾸준히 하면\n건강 변화를 더 잘 파악할 수 있어요.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  '확인',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectChip(_Item item, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondary.withOpacity(0.18)
              : AppColors.glassWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.glassBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: selected
                      ? AppColors.secondary
                      : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.secondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBg() {
    return Positioned(
      top: -100,
      left: -100,
      child: Container(
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            AppColors.primaryLight.withOpacity(0.12),
            Colors.transparent,
          ]),
        ),
      ),
    );
  }
}

class _Item {
  final String emoji;
  final String label;
  const _Item(this.emoji, this.label);
}
