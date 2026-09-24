import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/analysis_provider.dart';
import '../models/models.dart';
import '../theme/colors.dart';

class UploadControlsPanel extends StatelessWidget {
  const UploadControlsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();

    // Combine existing and newly selected files
    final List<dynamic> currentFileList = [];
    currentFileList.addAll(provider.existingInputMedia);
    currentFileList.addAll(provider.selectedFiles);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Excel Dropzone Card
        GestureDetector(
          onTap: () => _pickExcelFiles(context),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CustomPaint(
                  painter: DashedBorderPainter(color: AppColors.amber),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          color: AppColors.amber,
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Kéo thả file đo hoặc bấm để chọn',
                          style: TextStyle(
                            color: AppColors.slate700,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Hỗ trợ file Excel (.xlsx), dung lượng tối đa 200MB',
                          style: TextStyle(
                            color: AppColors.slate500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _pickExcelFiles(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Chọn file',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Files List
        if (currentFileList.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: currentFileList.length,
              itemBuilder: (context, index) {
                final item = currentFileList[index];
                final isExisting = item is TestingMedia;
                final fileName = isExisting ? item.mediaName : item.name;
                final fileSizeText = isExisting
                    ? 'Tệp đã tải lên'
                    : _formatFileSize(item.size);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: index == currentFileList.length - 1
                          ? BorderSide.none
                          : const BorderSide(color: AppColors.slate100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: isExisting ? AppColors.emerald : AppColors.slate400,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.slate800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fileSizeText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.slate400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                        onPressed: () {
                          if (isExisting) {
                            provider.removeExistingInputMedia(item);
                          } else {
                            final idx = provider.selectedFiles.indexOf(item);
                            provider.removeExcelFile(idx);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        if (currentFileList.isNotEmpty) const SizedBox(height: 16),

        // Target File Select Dropdown
        if (currentFileList.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHỌN FILE DỮ LIỆU ĐÍCH ĐỂ HIỂN THỊ BẢNG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: provider.targetIndex,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.slate300),
                    ),
                  ),
                  items: List.generate(currentFileList.length, (index) {
                    final item = currentFileList[index];
                    final name = item is TestingMedia ? item.mediaName : item.name;
                    return DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text(
                        'Mục ${index + 1}: $name',
                        style: const TextStyle(fontSize: 13, color: AppColors.slate800),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      provider.setTargetIndex(val);
                      provider.refreshTestingMedia();
                    }
                  },
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Word report template import card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tệp mẫu báo cáo Word',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Sử dụng file mẫu .doc hoặc .docx để tạo xuất báo cáo.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.slate500,
                      ),
                    ),
                    if (provider.wordFile != null || provider.existingWordMedia != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          provider.wordFile?.name ?? provider.existingWordMedia?.mediaName ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emerald700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (provider.wordFile != null || provider.existingWordMedia != null)
                TextButton(
                  onPressed: () => provider.removeWordFile(),
                  child: const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ElevatedButton(
                onPressed: () => _pickWordFile(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald50,
                  foregroundColor: AppColors.emerald700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.emerald200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  provider.wordFile != null || provider.existingWordMedia != null
                      ? 'Thay đổi'
                      : 'Chọn tệp',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Toggle buttons (saveLocal, cleanBeforeAnalysis)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lưu file kết quả về máy',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tự động tải về các tệp Excel phân tích kết quả.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: provider.saveLocal,
                    onChanged: provider.setSaveLocal,
                    activeTrackColor: AppColors.emerald,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Làm sạch trước khi phân tích',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Xóa các kết quả cũ trước khi bắt đầu xử lý.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: provider.cleanBeforeAnalysis,
                    onChanged: provider.setCleanBeforeAnalysis,
                    activeTrackColor: AppColors.emerald,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Pick Excel Files Helper
  Future<void> _pickExcelFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: true,
    );
    if (result != null && context.mounted) {
      context.read<AnalysisProvider>().selectExcelFiles(result.files);
    }
  }

  // Pick Word Report Template Helper
  Future<void> _pickWordFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['doc', 'docx'],
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty && context.mounted) {
      context.read<AnalysisProvider>().selectWordFile(result.files.first);
    }
  }

  // Size formatter
  String _formatFileSize(int size) {
    if (size >= 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (size >= 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '$size B';
  }
}

// Dashed Border Painter for Dropzone
class DashedBorderPainter extends CustomPainter {
  final Color color;

  DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(14),
    ));

    const dashWidth = 8.0;
    const dashSpace = 4.0;
    double distance = 0.0;

    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}
