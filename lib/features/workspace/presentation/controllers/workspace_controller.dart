import 'package:flutter/material.dart';
import '../../../../models/workspace_models.dart';
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

  List<CustomerItem> _customers = [];
  List<CustomerItem> get customers => _customers;

  List<StandaloneTaskItem> _tasks = [];
  List<StandaloneTaskItem> get tasks => _tasks;

  final Map<String, String> _customerMap = {};
  Map<String, String> get customerMap => _customerMap;

  final Map<String, String> _projectMap = {};
  Map<String, String> get projectMap => _projectMap;

  // Bộ lọc Dự án
  String _projectSearch = '';
  String get projectSearch => _projectSearch;

  String _projectStatusFilter = 'ALL';
  String get projectStatusFilter => _projectStatusFilter;

  // Bộ lọc Khách hàng
  String _customerSearch = '';
  String get customerSearch => _customerSearch;

  // Bộ lọc Việc ngoài dự án
  String _taskScope = 'assigned_to_me';
  String get taskScope => _taskScope;

  String _taskStatusFilter = 'ALL';
  String get taskStatusFilter => _taskStatusFilter;

  String _taskSearch = '';
  String get taskSearch => _taskSearch;

  void setTab(int tabIndex) {
    if (_activeTab != tabIndex) {
      _activeTab = tabIndex;
      notifyListeners();
      reloadTab();
    }
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
    if (_taskScope != scope) {
      _taskScope = scope;
      notifyListeners();
      reloadTab();
    }
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

    // 2. My Work
    try {
      final myWork = await _repository.getMyWork(customerMap: _customerMap);
      final myWorkProjects = myWork['projects'] as List<ProjectItem>?;
      if (myWorkProjects != null) {
        _projects = myWorkProjects;
        for (final p in myWorkProjects) {
          _projectMap[p.id] = p.name;
        }
      }
      final standalone = myWork['standaloneTasks'] as List<StandaloneTaskItem>?;
      if (standalone != null) {
        _tasks = standalone;
      }
    } catch (e) {
      debugPrint('[WorkspaceController] load my-work error: $e');
    }

    // 3. Projects Catalog
    if (_projects.isEmpty) {
      try {
        final pList = await _repository.getProjects(customerMap: _customerMap);
        for (final p in pList) {
          _projectMap[p.id] = p.name;
        }
        _projects = pList;
      } catch (e) {
        debugPrint('[WorkspaceController] load projects error: $e');
      }
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

    try {
      if (_activeTab == 0) {
        final myWork = await _repository.getMyWork(customerMap: _customerMap);
        final myWorkProjects = myWork['projects'] as List<ProjectItem>?;
        final standalone = myWork['standaloneTasks'] as List<StandaloneTaskItem>?;
        if (myWorkProjects != null) {
          _projects = myWorkProjects;
        }
        if (standalone != null) {
          _tasks = standalone;
        }
      } else if (_activeTab == 1) {
        final sTasks = await _repository.getStandaloneTasks(scope: _taskScope);
        _tasks = sTasks;
      } else if (_activeTab == 2) {
        final pList = await _repository.getProjects(customerMap: _customerMap);
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
