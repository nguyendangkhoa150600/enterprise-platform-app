import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analysis_provider.dart';
import '../models/models.dart';
import '../theme/colors.dart';

class ProjectTestingSidebar extends StatefulWidget {
  const ProjectTestingSidebar({super.key});

  @override
  State<ProjectTestingSidebar> createState() => _ProjectTestingSidebarState();
}

class _ProjectTestingSidebarState extends State<ProjectTestingSidebar> {
  final TextEditingController _projectSearchController = TextEditingController();
  final TextEditingController _testingSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalysisProvider>().fetchProjects();
    });
  }

  @override
  void dispose() {
    _projectSearchController.dispose();
    _testingSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: AppColors.slate800,
        border: Border(
          right: BorderSide(
            color: AppColors.slate700,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.slate700),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppColors.amber, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Savina Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.slate400),
                  onPressed: () => provider.fetchProjects(),
                  tooltip: 'Tải lại',
                ),
              ],
            ),
          ),

          // Projects Section
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DỰ ÁN',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showAddProjectDialog(context),
                        child: const Row(
                          children: [
                            Icon(Icons.add, color: AppColors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Thêm mới',
                              style: TextStyle(
                                color: AppColors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _projectSearchController,
                    onChanged: provider.setProjectSearchQuery,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm dự án...',
                      hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: AppColors.slate400, size: 18),
                      isDense: true,
                      fillColor: AppColors.slate900,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.slate700),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.amber),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: provider.loadingProjects
                      ? const Center(child: CircularProgressIndicator(color: AppColors.amber))
                      : ListView.builder(
                          itemCount: provider.projects
                              .where((p) => p.projectName
                                  .toLowerCase()
                                  .contains(provider.projectSearchQuery.toLowerCase()))
                              .length,
                          itemBuilder: (context, index) {
                            final filtered = provider.projects
                                .where((p) => p.projectName
                                    .toLowerCase()
                                    .contains(provider.projectSearchQuery.toLowerCase()))
                                .toList();
                            final project = filtered[index];
                            final isSelected = provider.selectedProjectId == project.projectId;

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.amber.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  project.projectName,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.amber : AppColors.slate200,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13.5,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: AppColors.amber, size: 16),
                                            onPressed: () => _showEditProjectDialog(context, project),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                            onPressed: () => _showDeleteProjectDialog(context, project),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      )
                                    : null,
                                onTap: () {
                                  if (project.projectId != null) {
                                    provider.selectProject(project.projectId!);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.slate700, height: 1),

          // Testings Section
          Expanded(
            flex: 5,
            child: provider.selectedProjectId == null
                ? const Center(
                    child: Text(
                      'Chọn dự án để xem các lượt đo',
                      style: TextStyle(color: AppColors.slate400, fontSize: 13),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'LƯỢT ĐO THỬ NGHIỆM',
                              style: TextStyle(
                                color: AppColors.emeraldAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showAddTestingDialog(context),
                              child: const Row(
                                children: [
                                  Icon(Icons.add, color: AppColors.emeraldAccent, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Thêm mới',
                                    style: TextStyle(
                                      color: AppColors.emeraldAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _testingSearchController,
                          onChanged: provider.setTestingSearchQuery,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm lượt đo...',
                            hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, color: AppColors.slate400, size: 18),
                            isDense: true,
                            fillColor: AppColors.slate900,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.slate700),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.emeraldAccent),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: provider.loadingTestings
                            ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldAccent))
                            : ListView.builder(
                                itemCount: provider.testings
                                    .where((t) => t.testingName
                                        .toLowerCase()
                                        .contains(provider.testingSearchQuery.toLowerCase()))
                                    .length,
                                itemBuilder: (context, index) {
                                  final filtered = provider.testings
                                      .where((t) => t.testingName
                                          .toLowerCase()
                                          .contains(provider.testingSearchQuery.toLowerCase()))
                                      .toList();
                                  final testing = filtered[index];
                                  final isSelected = provider.selectedTestingId == testing.testingId;

                                  // Status Badge Colors
                                  Color statusColor = Colors.grey;
                                  if (testing.testingStatus == 'passed') {
                                    statusColor = AppColors.emerald;
                                  } else if (testing.testingStatus == 'failed') {
                                    statusColor = AppColors.rose;
                                  }

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.emeraldAccent.withOpacity(0.1) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              testing.testingName,
                                              style: TextStyle(
                                                color: isSelected ? AppColors.emeraldAccent : AppColors.slate200,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: isSelected
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: AppColors.emeraldAccent, size: 16),
                                                  onPressed: () => _showEditTestingDialog(context, testing),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: AppColors.roseAccent, size: 16),
                                                  onPressed: () => _showDeleteTestingDialog(context, testing),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ],
                                            )
                                          : null,
                                      onTap: () {
                                        if (testing.testingId != null) {
                                          provider.selectTesting(testing.testingId!);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Dialogs
  void _showAddProjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm dự án mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên dự án *')),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Địa chỉ')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Mô tả ngắn')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await context.read<AnalysisProvider>().addProject(
                      nameController.text,
                      addressController.text.isEmpty ? null : addressController.text,
                      descController.text.isEmpty ? null : descController.text,
                    );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Tạo mới'),
          ),
        ],
      ),
    );
  }

  void _showEditProjectDialog(BuildContext context, Project project) {
    final nameController = TextEditingController(text: project.projectName);
    final addressController = TextEditingController(text: project.projectAddress ?? '');
    final descController = TextEditingController(text: project.projectDescription ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật dự án'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên dự án *')),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Địa chỉ')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Mô tả')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && project.projectId != null) {
                await context.read<AnalysisProvider>().updateProject(
                      project.projectId!,
                      nameController.text,
                      addressController.text.isEmpty ? null : addressController.text,
                      descController.text.isEmpty ? null : descController.text,
                    );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteProjectDialog(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa dự án "${project.projectName}" không? Toàn bộ dữ liệu liên quan sẽ bị xóa sạch.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (project.projectId != null) {
                await context.read<AnalysisProvider>().deleteProject(project.projectId!);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddTestingDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm lượt đo mới'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Tên lượt đo * (ví dụ: Đo tần số định kỳ Lần 1)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await context.read<AnalysisProvider>().addTesting(nameController.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Tạo mới'),
          ),
        ],
      ),
    );
  }

  void _showEditTestingDialog(BuildContext context, Testing testing) {
    final nameController = TextEditingController(text: testing.testingName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật lượt đo'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Tên lượt đo *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && testing.testingId != null) {
                await context.read<AnalysisProvider>().updateTesting(testing.testingId!, nameController.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTestingDialog(BuildContext context, Testing testing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa lượt đo "${testing.testingName}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (testing.testingId != null) {
                await context.read<AnalysisProvider>().deleteTesting(testing.testingId!);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
