import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analysis_provider.dart';
import '../theme/colors.dart';

class ThresholdControlsPanel extends StatelessWidget {
  const ThresholdControlsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();
    final isLocked = provider.isReadingFile;
    final isStartDisabled = provider.isProcessing || provider.isReadingFile || provider.selectedTestingId == null;

    // Field displays map
    final List<Map<String, String>> fields = [
      {'name': 'pstThreshold', 'label': 'Ngưỡng Pst', 'placeholder': '0.8'},
      {'name': 'pltThreshold', 'label': 'Ngưỡng Plt', 'placeholder': '0.6'},
      {'name': 'thdUThreshold', 'label': 'Ngưỡng THD U (%)', 'placeholder': '3.0'},
      {'name': 'tddIThreshold', 'label': 'Ngưỡng TDD I (%)', 'placeholder': '3.0'},
      {'name': 'uThreshold', 'label': 'Ngưỡng U (%)', 'placeholder': '3.0'},
      {'name': 'voltageHarmonicThreshold', 'label': 'Sóng hài áp (%)', 'placeholder': '1.5'},
      {'name': 'currentHarmonicThreshold', 'label': 'Sóng hài dòng (%)', 'placeholder': '2.0'},
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.slate50, AppColors.slate100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CẤU HÌNH NGƯỠNG PHÂN TÍCH',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.amber,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Thiết lập thông số kỹ thuật để chạy thuật toán phân tích kết quả đo.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.slate600,
                ),
              ),
              const SizedBox(height: 16),

              // Voltage Level
              const Text(
                'CẤP ĐIỆN ÁP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: provider.voltageLevel,
                disabledHint: Text(provider.voltageLevel),
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.slate300),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: '22kV', child: Text('22kV', style: TextStyle(color: AppColors.slate800, fontSize: 13))),
                  DropdownMenuItem(value: '110kV', child: Text('110kV', style: TextStyle(color: AppColors.slate800, fontSize: 13))),
                ],
                onChanged: isLocked ? null : (val) {
                  if (val != null) {
                    provider.setVoltageLevel(val);
                  }
                },
              ),

              const SizedBox(height: 16),

              // Dynamic threshold fields
              ...fields.map((f) {
                final key = f['name']!;
                final label = f['label']!;
                final placeholder = f['placeholder']!;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: provider.thresholdValues[key] ?? '',
                        key: ValueKey('${provider.voltageLevel}_$key'), // force rebuild textfield when voltage changes
                        style: const TextStyle(color: AppColors.slate800, fontSize: 13),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: placeholder,
                          fillColor: isLocked ? AppColors.slate100 : Colors.white,
                          filled: true,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.slate300),
                          ),
                        ),
                        onChanged: (val) => provider.updateThreshold(key, val),
                        enabled: !isLocked,
                      ),
                    ],
                  ),
                );
              }),

              // Rated Power Pdm
              const Text(
                'CÔNG SUẤT ĐỊNH MỨC (PDM - W)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: provider.ratedPower,
                      key: ValueKey(provider.ratedPower), // Rebuild if adjust changes it
                      style: const TextStyle(color: AppColors.slate800, fontSize: 13, fontWeight: FontWeight.bold),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '40000000',
                        fillColor: isLocked ? AppColors.slate100 : Colors.white,
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.slate300),
                        ),
                      ),
                      onChanged: provider.setRatedPower,
                      enabled: !isLocked,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.slate300),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16, color: AppColors.slate600),
                          onPressed: isLocked ? null : () => provider.adjustRatedPower(-1000000),
                        ),
                        Container(width: 1, height: 24, color: AppColors.slate300),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: AppColors.slate600),
                          onPressed: isLocked ? null : () => provider.adjustRatedPower(1000000),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isStartDisabled ? null : () => provider.runAnalysis(),
                  icon: provider.isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt, size: 18),
                  label: Text(
                    provider.isProcessing ? 'ĐANG PHÂN TÍCH...' : 'BẮT ĐẦU PHÂN TÍCH',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.slate300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // Feedback messages
              if (provider.processingMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: provider.isSuccessProcessing
                        ? AppColors.emerald50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: provider.isSuccessProcessing
                          ? AppColors.emerald200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        provider.isSuccessProcessing
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: provider.isSuccessProcessing
                            ? AppColors.emerald700
                            : Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.processingMessage!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: provider.isSuccessProcessing
                                ? AppColors.emerald800
                                : Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Locked overlay
          if (isLocked)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.85),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.amber),
                      SizedBox(height: 12),
                      Text(
                        'Đang tải cấu hình bảng...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate800,
                        ),
                      ),
                      Text(
                        'Vui lòng chờ tệp phân tích tải xuống',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
