import 'package:flutter/material.dart';
import '../../../models/hrm_leave_balance_models.dart';
import '../../../services/hrm_service.dart';

void showCompOffLedgerSheet(
  BuildContext context, {
  required HrmCompOffBalanceItem employee,
  required HrmService hrmService,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CompOffLedgerSheet(
      employee: employee,
      hrmService: hrmService,
    ),
  );
}

class CompOffLedgerSheet extends StatefulWidget {
  final HrmCompOffBalanceItem employee;
  final HrmService hrmService;

  const CompOffLedgerSheet({
    super.key,
    required this.employee,
    required this.hrmService,
  });

  @override
  State<CompOffLedgerSheet> createState() => _CompOffLedgerSheetState();
}

class _CompOffLedgerSheetState extends State<CompOffLedgerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  HrmCompOffDetail? _detail;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final raw = await widget.hrmService.getCompOffDetail(widget.employee.employeeId);
      if (mounted) {
        if (raw != null) {
          setState(() {
            _detail = HrmCompOffDetail.fromJson(raw);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Không tải được chi tiết sổ quỹ nghỉ bù';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Lỗi kết nối máy chủ: $e';
        });
      }
    }
  }

  String _formatNumber(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF0F172A),
                  child: Text(
                    emp.avatarInitials,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              emp.employeeName,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              emp.employeeCode,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Sổ quỹ nghỉ bù · ${emp.department ?? 'Chưa phân phòng ban'}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF021E73)))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFFDC2626)),
                            const SizedBox(height: 8),
                            Text(_errorMessage!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadDetail,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF021E73)),
                              child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Summary metrics banner
                          Container(
                            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Khả dụng', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_formatNumber(_detail?.available ?? emp.available)} ngày',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF021E73),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Đang giữ chỗ', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_formatNumber(_detail?.reserved ?? emp.reserved)} ngày',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Bước dùng', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_formatNumber(_detail?.usageStepDays ?? 0.5)} ngày',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Tab bar
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: const Color(0xFF021E73),
                              unselectedLabelColor: const Color(0xFF64748B),
                              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              indicatorColor: const Color(0xFF021E73),
                              indicatorWeight: 2.5,
                              tabs: [
                                Tab(text: 'Sổ giao dịch (${_detail?.entries.length ?? 0})'),
                                Tab(text: 'Lô còn số dư (${_detail?.lots.length ?? 0})'),
                              ],
                            ),
                          ),

                          // Tab views
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildEntriesList(),
                                _buildLotsList(),
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

  Widget _buildEntriesList() {
    final entries = _detail?.entries ?? [];
    if (entries.isEmpty) {
      return const Center(
        child: Text('Chưa có lịch sử giao dịch quỹ nghỉ bù', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: entries.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = entries[i];
        final isPositive = e.days > 0;
        final color = isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626);
        final prefix = isPositive ? '+' : '';

        String note = e.reason ?? '';
        if (note.isEmpty && e.periodMonth != null) {
          final p = e.periodMonth!;
          final monthStr = p.length >= 7 ? '${p.substring(5, 7)}/${p.substring(0, 4)}' : p;
          note = 'Làm thêm tháng $monthStr${e.excessHours != null ? ': ${_formatNumber(e.excessHours!)} giờ vượt trần' : ''}';
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e.kindLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                  Text(
                    '$prefix${_formatNumber(e.days)} ngày',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
                  ),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.occurredOn,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  if (e.actorName != null && e.actorName!.isNotEmpty)
                    Text(
                      'Bởi: ${e.actorName}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLotsList() {
    final lots = _detail?.lots ?? [];
    if (lots.isEmpty) {
      return const Center(
        child: Text('Không có lô quỹ nghỉ bù nào còn số dư', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: lots.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final lot = lots[i];
        final lotCode = lot.lotId.length >= 8 ? lot.lotId.substring(0, 8).toUpperCase() : lot.lotId.toUpperCase();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.layers_outlined, size: 15, color: Color(0xFF021E73)),
                      const SizedBox(width: 4),
                      Text(
                        'Lô #$lotCode',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Text(
                    'Còn ${_formatNumber(lot.remaining)} / ${_formatNumber(lot.granted)} ngày',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF021E73)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ngày mở: ${lot.openedOn}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  Text(
                    lot.expiresOn != null ? 'Hạn dùng: ${lot.expiresOn}' : 'Không thời hạn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: lot.expiresOn != null ? const Color(0xFFD97706) : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
