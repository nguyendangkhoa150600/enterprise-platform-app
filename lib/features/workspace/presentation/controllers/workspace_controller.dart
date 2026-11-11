import 'package:flutter/material.dart';
import '../../../../models/workspace_models.dart';
import '../../../../utils/user_resolver.dart';
import '../../domain/repositories/i_workspace_repository.dart';
import '../../data/repositories/workspace_repository_impl.dart';

/// Controller quản lý toàn bộ State & Logic cho phân hệ Workspace
/// Tuân thủ nguyên tắc SRP, tách biệt hoàn toàn UI khỏi data fetching
class WorkspaceController extends ChangeNotifier {
  final IWorkspaceRepository _repository;

  WorkspaceController({
    IWorkspaceRepository? repository,
    int initialTab = 0,
  })  : _repository = repository ?? WorkspaceRepositoryImpl(),
        _activeTab = initialTab;

  int _activeTab;
  int get activeTab => _activeTab;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Dữ liệu hiển thị (100% dữ liệu thật từ Server)
  List<ProjectItem> _projects = [];
  List<ProjectItem> get projects => _projects;

  List<ProjectItem> _myWorkProjects = [];
  List<ProjectItem> get myWorkProjects => _myWorkProjects;

  List<CustomerItem> _customers = [];
  List<CustomerItem> get customers => _customers;

  List<StandaloneTaskItem> _tasks = [];
  List<StandaloneTaskItem> get tasks => _tasks;

  final Map<String, String> _customerMap = {};
  Map<String, String> get customerMap => _customerMap;

  final Map<String, String> _projectMap = {};
  Map<String, String> get projectMap => _projectMap;

  // Bộ lọc Dự án (Đồng bộ 1:1 với Web)
  String _projectSearch = '';
  String get projectSearch => _projectSearch;

  String _projectStatusFilter = 'ALL';
  String get projectStatusFilter => _projectStatusFilter;

  String _archivedFilter = 'exclude'; // 'exclude' (Đang làm - 194 dự án) | 'only' (Lưu trữ - 486 dự án)
  String get archivedFilter => _archivedFilter;

  String _projectGroupFilter = 'ALL';
  String get projectGroupFilter => _projectGroupFilter;

  String _projectSort = 'name'; // 'name' | 'code' | 'recent'
  String get projectSort => _projectSort;

  // Bộ lọc Khách hàng
  String _customerSearch = '';
  String get customerSearch => _customerSearch;

  // Bộ lọc Công việc khác (Đồng bộ 1:1 với Web)
  String _taskScope = 'assigned_to_me';
  String get taskScope => _taskScope;

  String _taskStatusFilter = 'open'; // Mặc định Web là 'Đang mở'
  String get taskStatusFilter => _taskStatusFilter;

  String _taskSearch = '';
  String get taskSearch => _taskSearch;

  String _taskSort = 'recent'; // 'recent' | 'dueDate' | 'priority' | 'title'
  String get taskSort => _taskSort;

  void setTaskSort(String sort) {
    _taskSort = sort;
    notifyListeners();
  }

  void setTab(int tabIndex) {
    if (_activeTab != tabIndex) {
      _activeTab = tabIndex;
      notifyListeners();
      reloadTab();
    }
  }

  void setArchivedFilter(String filter) {
    if (_archivedFilter != filter) {
      _archivedFilter = filter;
      _projectSearch = '';
      _projectStatusFilter = 'ALL';
      _projectGroupFilter = 'ALL';
      notifyListeners();
      reloadTab();
    }
  }

  void setProjectGroupFilter(String group) {
    _projectGroupFilter = group;
    notifyListeners();
  }

  void setProjectSort(String sort) {
    _projectSort = sort;
    notifyListeners();
  }

  void setProjectSearch(String query) {
    _projectSearch = query;
    notifyListeners();
  }

  void setProjectStatusFilter(String status) {
    _projectStatusFilter = status;
    notifyListeners();
  }

  void setCustomerSearch(String query) {
    _customerSearch = query;
    notifyListeners();
  }

  void setTaskScope(String scope) {
    _taskScope = scope;
    notifyListeners();
    reloadTab();
  }

  void setTaskStatusFilter(String status) {
    _taskStatusFilter = status;
    notifyListeners();
  }

  void setTaskSearch(String query) {
    _taskSearch = query;
    notifyListeners();
  }

  Future<void> loadAllData() async {
    _isLoading = true;
    notifyListeners();

    // Preload user names for 1:1 display (Phụ trách, Người giao)
    await UserResolver.ensureLoaded();

    // 1. Customers
    try {
      final custList = await _repository.getCustomers();
      _customerMap.clear();
      for (final c in custList) {
        _customerMap[c.id] = c.name;
      }
      _customers = custList;
    } catch (e) {
      debugPrint('[WorkspaceController] load customers error: $e');
    }

    // 2. My Work (Tab 0)
    try {
      final myWork = await _repository.getMyWork(customerMap: _customerMap);
      final myWorkList = myWork['projects'] as List<ProjectItem>?;
      if (myWorkList != null) {
        _myWorkProjects = myWorkList;
      }
      final standalone = myWork['standaloneTasks'] as List<StandaloneTaskItem>?;
      if (standalone != null) {
        _tasks = standalone;
      }
    } catch (e) {
      debugPrint('[WorkspaceController] load my-work error: $e');
    }

    // 3. Projects Catalog (Tab 2 - 100% dữ liệu thật từ Server)
    try {
      final pList = await _repository.getProjects(
        customerMap: _customerMap,
        archived: _archivedFilter,
      );
      for (final p in pList) {
        _projectMap[p.id] = p.name;
      }
      _projects = pList;
    } catch (e) {
      debugPrint('[WorkspaceController] load projects catalog error: $e');
    }

    // 4. Standalone Tasks
    try {
      final sTasks = await _repository.getStandaloneTasks(scope: _taskScope);
      if (sTasks.isNotEmpty) {
        _tasks = sTasks;
      }
    } catch (e) {
      debugPrint('[WorkspaceController] load tasks error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> reloadTab() async {
    _isLoading = true;
    notifyListeners();

    if (!UserResolver.hasLoaded) {
      await UserResolver.ensureLoaded();
    }

    try {
      if (_activeTab == 0) {
        final myWork = await _repository.getMyWork(customerMap: _customerMap);
        final myWorkList = myWork['projects'] as List<ProjectItem>?;
        final standalone = myWork['standaloneTasks'] as List<StandaloneTaskItem>?;
        if (myWorkList != null) {
          _myWorkProjects = myWorkList;
        }
        if (standalone != null) {
          _tasks = standalone;
        }
      } else if (_activeTab == 1) {
        final sTasks = await _repository.getStandaloneTasks(scope: _taskScope);
        _tasks = sTasks;
      } else if (_activeTab == 2) {
        final pList = await _repository.getProjects(
          customerMap: _customerMap,
          archived: _archivedFilter,
        );
        for (final p in pList) {
          _projectMap[p.id] = p.name;
        }
        _projects = pList;
      } else if (_activeTab == 3) {
        final custList = await _repository.getCustomers(query: _customerSearch);
        _customers = custList;
      }
    } catch (e) {
      debugPrint('[WorkspaceController] reloadTab error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
