import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/analysis_provider.dart';
import '../models/models.dart';
import './power_quality_analysis_table.dart';
import '../theme/colors.dart';

class ProcessingResultsPanel extends StatefulWidget {
  const ProcessingResultsPanel({super.key});

  @override
  State<ProcessingResultsPanel> createState() => _ProcessingResultsPanelState();
}

class _ProcessingResultsPanelState extends State<ProcessingResultsPanel> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();

    if (!provider.isProcessing && provider.analysisData == null && provider.downloadableFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.query_stats, size: 64, color: AppColors.slate300),
            const SizedBox(height: 12),
            const Text(
              'Chưa có dữ liệu kết quả phân tích',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.slate400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vui lòng chọn lượt thử nghiệm có sẵn hoặc bấm "Bắt đầu phân tích"',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.slate400,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Progress Card
          if (provider.isProcessing)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.slate200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Đang xử lý phân tích...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Quá trình có thể mất từ 10 - 30 giây. Vui lòng giữ ứng dụng mở.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: provider.processingProgress,
                    backgroundColor: AppColors.slate100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(provider.processingProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate800,
                    ),
                  ),
                ],
              ),
            ),

          // 2. Results Data Dashboard
          if (!provider.isProcessing && provider.analysisData != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: PowerQualityAnalysisTable(data: provider.analysisData!),
            ),

          // 3. Downloadable Files Section
          if (!provider.isProcessing && provider.downloadableFiles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.slate200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.file_download_outlined, color: AppColors.amber, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Danh sách file kết quả phân tích',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tải về các báo cáo kết quả và bảng tính Excel đã được xử lý bởi thuật toán.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 80,
                    ),
                    itemCount: provider.downloadableFiles.length,
                    itemBuilder: (context, index) {
                      final file = provider.downloadableFiles[index];
                      return InkWell(
                        onTap: _isDownloading ? null : () => _downloadFile(context, file),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.emerald50,
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                child: const Icon(Icons.description_outlined, color: AppColors.emerald700, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      file.mediaName ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.slate800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      file.mediaType ?? 'Tệp kết quả',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.slate400),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // File download helper using path_provider
  Future<void> _downloadFile(BuildContext context, TestingMedia media) async {
    if (media.mediaUrl == null) return;
    setState(() => _isDownloading = true);
    
    // Show download trigger snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đang tải tệp "${media.mediaName}"...'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final provider = context.read<AnalysisProvider>();
      final bytes = await provider.downloadFile(media.mediaUrl!);
      
      // Get directory to save
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }
      
      directory ??= await getTemporaryDirectory();

      final filePath = '${directory.path}/${media.mediaName ?? "result.xlsx"}';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('Đã tải thành công! Lưu tại: $filePath'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Tải tệp thất bại: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
}
