import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analysis_provider.dart';
import '../widgets/project_testing_sidebar.dart';
import '../widgets/upload_controls_panel.dart';
import '../widgets/threshold_controls_panel.dart';
import '../widgets/processing_results_panel.dart';
import '../theme/colors.dart';

class MainAnalysisScreen extends StatelessWidget {
  const MainAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();
    final isTestingSelected = provider.selectedTestingId != null;

    // Check width for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      drawer: !isDesktop
          ? const Drawer(
              child: ProjectTestingSidebar(),
            )
          : null,
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: AppColors.slate800,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Savina Phân Tích Chất Lượng Điện',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: Row(
        children: [
          // Sidebar on Desktop
          if (isDesktop) const ProjectTestingSidebar(),

          // Main Content Details Pane
          Expanded(
            child: isTestingSelected
                ? Column(
                    children: [
                      // Header bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: AppColors.slate200)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.testings
                                      .firstWhere((t) => t.testingId == provider.selectedTestingId)
                                      .testingName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cấp điện áp: ${provider.voltageLevel} • Công suất định mức: ${provider.ratedPower} W',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Responsive Details grid
                      Expanded(
                        child: screenWidth >= 1200
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left settings column (40% width)
                                  Expanded(
                                    flex: 4,
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        children: [
                                          const UploadControlsPanel(),
                                          const SizedBox(height: 24),
                                          const ThresholdControlsPanel(),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Vertical Divider
                                  Container(width: 1, color: AppColors.slate200),
                                  // Right results column (60% width)
                                  const Expanded(
                                    flex: 6,
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: ProcessingResultsPanel(),
                                    ),
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    const UploadControlsPanel(),
                                    const SizedBox(height: 20),
                                    const ThresholdControlsPanel(),
                                    const SizedBox(height: 20),
                                    const Divider(),
                                    const SizedBox(height: 20),
                                    const ProcessingResultsPanel(),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.dashboard_customize_outlined,
                          size: 72,
                          color: AppColors.slate300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Chào mừng đến với Trình Phân Tích Chất Lượng Điện',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Vui lòng chọn một Dự án & Lượt đo ở cột bên trái để bắt đầu.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.slate600,
                          ),
                        ),
                        if (!isDesktop) ...[
                          const SizedBox(height: 20),
                          Builder(
                            builder: (context) => ElevatedButton(
                              onPressed: () => Scaffold.of(context).openDrawer(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.slate800,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Mở danh sách dự án'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
