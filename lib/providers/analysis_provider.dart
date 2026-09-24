import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AnalysisProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Projects & Testings
  List<Project> _projects = [];
  List<Testing> _testings = [];
  bool _loadingProjects = false;
  bool _loadingTestings = false;
  int? _selectedProjectId;
  int? _selectedTestingId;

  List<Project> get projects => _projects;
  List<Testing> get testings => _testings;
  bool get loadingProjects => _loadingProjects;
  bool get loadingTestings => _loadingTestings;
  int? get selectedProjectId => _selectedProjectId;
  int? get selectedTestingId => _selectedTestingId;

  // Selected Files
  List<PlatformFile> _selectedFiles = [];
  PlatformFile? _wordFile;
  int _targetIndex = 1;

  List<PlatformFile> get selectedFiles => _selectedFiles;
  PlatformFile? get wordFile => _wordFile;
  int get targetIndex => _targetIndex;

  // Existing media items from the selected testing
  List<TestingMedia> _existingInputMedia = [];
  TestingMedia? _existingWordMedia;
  List<TestingMedia> _downloadableFiles = [];

  List<TestingMedia> get existingInputMedia => _existingInputMedia;
  TestingMedia? get existingWordMedia => _existingWordMedia;
  List<TestingMedia> get downloadableFiles => _downloadableFiles;

  // Threshold Configuration
  String _voltageLevel = '110kV';
  String _ratedPower = '40000000';
  final Map<String, String> _thresholdValues = {
    'pstThreshold': '0.8',
    'pltThreshold': '0.6',
    'thdUThreshold': '3.0',
    'tddIThreshold': '3.0',
    'uThreshold': '3.0',
    'voltageHarmonicThreshold': '1.5',
    'currentHarmonicThreshold': '2.0',
  };

  String get voltageLevel => _voltageLevel;
  String get ratedPower => _ratedPower;
  Map<String, String> get thresholdValues => _thresholdValues;

  // Toggles
  bool _saveLocal = false;
  bool _cleanBeforeAnalysis = true;

  bool get saveLocal => _saveLocal;
  bool get cleanBeforeAnalysis => _cleanBeforeAnalysis;

  // Analysis State
  bool _isProcessing = false;
  bool _isReadingFile = false;
  double _processingProgress = 0.0;
  String? _uploadMessage;
  String? _processingMessage;
  String? _wordImportMessage;
  bool _isSuccessUpload = false;
  bool _isSuccessProcessing = false;

  bool get isProcessing => _isProcessing;
  bool get isReadingFile => _isReadingFile;
  double get processingProgress => _processingProgress;
  String? get uploadMessage => _uploadMessage;
  String? get processingMessage => _processingMessage;
  String? get wordImportMessage => _wordImportMessage;
  bool get isSuccessUpload => _isSuccessUpload;
  bool get isSuccessProcessing => _isSuccessProcessing;

  PowerQualityAnalysisDataset? _analysisData;
  PowerQualityAnalysisDataset? get analysisData => _analysisData;

  // Search/Filters
  String _projectSearchQuery = '';
  String _testingSearchQuery = '';

  String get projectSearchQuery => _projectSearchQuery;
  String get testingSearchQuery => _testingSearchQuery;

  // Setup defaults based on voltage
  void setVoltageLevel(String val) {
    _voltageLevel = val;
    if (_voltageLevel == '110kV') {
      _thresholdValues['pstThreshold'] = '0.8';
      _thresholdValues['pltThreshold'] = '0.6';
      _thresholdValues['thdUThreshold'] = '3.0';
      _thresholdValues['tddIThreshold'] = '3.0';
      _thresholdValues['uThreshold'] = '3.0';
      _thresholdValues['voltageHarmonicThreshold'] = '1.5';
      _thresholdValues['currentHarmonicThreshold'] = '2.0';
    } else {
      // 22kV
      _thresholdValues['pstThreshold'] = '1.0';
      _thresholdValues['pltThreshold'] = '0.8';
      _thresholdValues['thdUThreshold'] = '5.0';
      _thresholdValues['tddIThreshold'] = '5.0';
      _thresholdValues['uThreshold'] = '3.0';
      _thresholdValues['voltageHarmonicThreshold'] = '3.0';
      _thresholdValues['currentHarmonicThreshold'] = '4.0';
    }
    notifyListeners();
  }

  void setRatedPower(String val) {
    _ratedPower = val.replaceAll(RegExp(r'\D'), '');
    notifyListeners();
  }

  void adjustRatedPower(int delta) {
    int current = int.tryParse(_ratedPower) ?? 0;
    int next = current + delta;
    if (next < 0) next = 0;
    _ratedPower = next.toString();
    notifyListeners();
  }

  void updateThreshold(String key, String value) {
    _thresholdValues[key] = value;
    notifyListeners();
  }

  void setSaveLocal(bool val) {
    _saveLocal = val;
    notifyListeners();
  }

  void setCleanBeforeAnalysis(bool val) {
    _cleanBeforeAnalysis = val;
    notifyListeners();
  }

  void setTargetIndex(int index) {
    _targetIndex = index;
    notifyListeners();
  }

  void setProjectSearchQuery(String val) {
    _projectSearchQuery = val;
    notifyListeners();
  }

  void setTestingSearchQuery(String val) {
    _testingSearchQuery = val;
    notifyListeners();
  }

  void removeExistingInputMedia(TestingMedia item) {
    _existingInputMedia.remove(item);
    notifyListeners();
  }

  void removeExistingWordMedia() {
    _existingWordMedia = null;
    notifyListeners();
  }

  // File Picker Handlers
  void selectExcelFiles(List<PlatformFile> files) {
    _selectedFiles.addAll(files);
    _uploadMessage = 'Đã chọn ${files.length} file Excel.';
    _isSuccessUpload = true;
    notifyListeners();
  }

  void removeExcelFile(int index) {
    _selectedFiles.removeAt(index);
    if (_selectedFiles.isEmpty) {
      _uploadMessage = null;
    }
    notifyListeners();
  }

  void selectWordFile(PlatformFile file) {
    _wordFile = file;
    _wordImportMessage = 'Mẫu báo cáo Word đã sẵn sàng: ${file.name}';
    notifyListeners();
  }

  void removeWordFile() {
    _wordFile = null;
    _wordImportMessage = null;
    notifyListeners();
  }

  // Load Projects
  Future<void> fetchProjects() async {
    _loadingProjects = true;
    notifyListeners();
    try {
      _projects = await _apiService.getProjects();
    } catch (e) {
      _projects = [];
    } finally {
      _loadingProjects = false;
      notifyListeners();
    }
  }

  // Select Project & load its testings
  Future<void> selectProject(int projectId) async {
    _selectedProjectId = projectId;
    _selectedTestingId = null;
    _testings = [];
    _analysisData = null;
    _downloadableFiles = [];
    _existingInputMedia = [];
    _existingWordMedia = null;
    _loadingTestings = true;
    notifyListeners();
    try {
      _testings = await _apiService.getTestingsByProject(projectId);
    } catch (e) {
      _testings = [];
    } finally {
      _loadingTestings = false;
      notifyListeners();
    }
  }

  // Add / Edit / Delete Projects
  Future<void> addProject(String name, String? address, String? description) async {
    try {
      final p = Project(projectName: name, projectAddress: address, projectDescription: description);
      await _apiService.createProject(p);
      await fetchProjects();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProject(int id, String name, String? address, String? description) async {
    try {
      final p = Project(projectName: name, projectAddress: address, projectDescription: description);
      await _apiService.updateProject(id, p);
      await fetchProjects();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProject(int id) async {
    try {
      await _apiService.deleteProject(id);
      if (_selectedProjectId == id) {
        _selectedProjectId = null;
        _selectedTestingId = null;
        _testings = [];
        _analysisData = null;
      }
      await fetchProjects();
    } catch (e) {
      rethrow;
    }
  }

  // Select Testing
  Future<void> selectTesting(int testingId) async {
    _selectedTestingId = testingId;
    _analysisData = null;
    _downloadableFiles = [];
    _existingInputMedia = [];
    _existingWordMedia = null;
    _isReadingFile = true;
    notifyListeners();
    try {
      await refreshTestingMedia();
    } catch (e) {
      _processingMessage = 'Không thể tải dữ liệu lượt thử nghiệm.';
    } finally {
      _isReadingFile = false;
      notifyListeners();
    }
  }

  // Add / Edit / Delete Testings
  Future<void> addTesting(String name) async {
    if (_selectedProjectId == null) return;
    try {
      final t = Testing(testingName: name, testingStatus: 'pending', projectId: _selectedProjectId!);
      await _apiService.createTesting(t);
      await selectProject(_selectedProjectId!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTesting(int id, String name) async {
    try {
      await _apiService.updateTesting(id, name);
      if (_selectedProjectId != null) {
        await selectProject(_selectedProjectId!);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTesting(int id) async {
    try {
      await _apiService.deleteTesting(id);
      if (_selectedTestingId == id) {
        _selectedTestingId = null;
        _analysisData = null;
        _downloadableFiles = [];
      }
      if (_selectedProjectId != null) {
        await selectProject(_selectedProjectId!);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Reload testing media details
  Future<void> refreshTestingMedia() async {
    if (_selectedTestingId == null) return;
    final details = await _apiService.getTestingDetails(_selectedTestingId!);
    
    // Scrape existing input media
    _existingInputMedia = details.media.where((m) {
      final name = m.mediaName?.toLowerCase() ?? '';
      return name.contains('input') && (name.contains('excel') || name.contains('.xlsx'));
    }).toList();

    // Scrape word media
    final wordList = details.media.where((m) {
      final name = m.mediaName?.toLowerCase() ?? '';
      return name.contains('input') && (name.contains('.doc') || name.contains('.docx'));
    }).toList();
    _existingWordMedia = wordList.isNotEmpty ? wordList.first : null;

    // Filter output media files for target download
    _downloadableFiles = details.media.where((m) {
      final name = m.mediaName?.toLowerCase() ?? '';
      return name.contains('_${_targetIndex}') || name.contains('_target${_targetIndex}');
    }).toList();

    // Attempt to download and parse the main analysis Excel output file
    final analysisMedia = _findAnalysisExcelMedia(details.media);
    if (analysisMedia != null && analysisMedia.mediaUrl != null) {
      final bytes = await _apiService.downloadFile(analysisMedia.mediaUrl!);
      _analysisData = PowerQualityAnalysisDataset.fromExcelBytes(bytes);
    } else {
      _analysisData = null;
    }
    notifyListeners();
  }

  TestingMedia? _findAnalysisExcelMedia(List<TestingMedia> media) {
    final candidates = media.where((m) {
      final url = m.mediaUrl ?? '';
      final name = m.mediaName ?? '';
      final excelHint = RegExp(r'(excel|\.xlsx?)', caseSensitive: false);
      return url.isNotEmpty && (excelHint.hasMatch(name) || excelHint.hasMatch(url) || m.mediaType == 'documents');
    }).toList();
    if (candidates.isEmpty) return null;

    // Sort to prioritize output files
    candidates.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;
      final nameA = a.mediaName ?? '';
      final nameB = b.mediaName ?? '';
      if (nameA.toLowerCase().contains('output')) scoreA += 10;
      if (nameB.toLowerCase().contains('output')) scoreB += 10;
      return scoreB.compareTo(scoreA);
    });

    return candidates.first;
  }

  // Main Processing Flow
  Future<void> runAnalysis() async {
    if (_selectedTestingId == null) {
      _processingMessage = 'Vui lòng chọn lượt thử nghiệm trước khi chạy.';
      _isSuccessProcessing = false;
      notifyListeners();
      return;
    }
    if (_selectedFiles.isEmpty && _existingInputMedia.isEmpty) {
      _processingMessage = 'Vui lòng tải lên ít nhất một file Excel dữ liệu.';
      _isSuccessProcessing = false;
      notifyListeners();
      return;
    }

    _isProcessing = true;
    _processingMessage = null;
    _processingProgress = 0.0;
    notifyListeners();

    // Start UI mock progress ticker
    Timer? progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_processingProgress < 0.9) {
        _processingProgress += 0.03;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });

    try {
      // 1. Prepare data files
      final List<MultipartFile> dioFiles = [];
      for (var f in _selectedFiles) {
        if (f.path != null) {
          final file = File(f.path!);
          dioFiles.add(await MultipartFile.fromFile(
            file.path,
            filename: f.name,
          ));
        }
      }

      // If there are existing media files and we did not select new files, Next.js downloads the files and re-uploads them.
      // In Flutter, if selectedFiles is empty, the BE already has the media files under the testing, so we pass empty dataFiles list or let backend fetch them.
      // Next.js: download existing media and append them as files. Let's do the same to match Next.js logic!
      if (dioFiles.isEmpty) {
        for (var media in _existingInputMedia) {
          if (media.mediaUrl != null) {
            final bytes = await _apiService.downloadFile(media.mediaUrl!);
            dioFiles.add(MultipartFile.fromBytes(
              bytes,
              filename: media.mediaName ?? 'input.xlsx',
            ));
          }
        }
      }

      MultipartFile? reportFile;
      if (_wordFile != null && _wordFile!.path != null) {
        reportFile = await MultipartFile.fromFile(
          _wordFile!.path!,
          filename: _wordFile!.name,
        );
      }

      // 2. Fire the processing trigger
      await _apiService.startAnalysis(
        voltage: _voltageLevel,
        dataFiles: dioFiles,
        testingId: _selectedTestingId!,
        pdm: _ratedPower,
        targetIndex: _targetIndex,
        thresholdOptions: _thresholdValues,
        reportFile: reportFile,
      );

      // 3. Poll testing status until complete
      progressTimer.cancel();
      _processingProgress = 0.9;
      _processingMessage = 'Đang phân tích và kiểm tra tiến trình...';
      notifyListeners();

      bool passed = false;
      int attempts = 0;
      while (attempts < 30) {
        attempts++;
        final details = await _apiService.getTestingDetails(_selectedTestingId!);
        if (details.testingStatus == 'passed') {
          passed = true;
          break;
        } else if (details.testingStatus == 'failed') {
          break;
        }
        await Future.delayed(const Duration(seconds: 4));
      }

      if (passed) {
        _processingProgress = 1.0;
        _processingMessage = 'Hoàn thành phân tích thành công!';
        _isSuccessProcessing = true;
        await refreshTestingMedia();
      } else {
        _processingProgress = 0.0;
        _processingMessage = 'Quá trình phân tích thất bại hoặc hết thời gian chờ.';
        _isSuccessProcessing = false;
      }
    } catch (e) {
      _processingProgress = 0.0;
      _processingMessage = 'Lỗi hệ thống: ${e.toString()}';
      _isSuccessProcessing = false;
    } finally {
      progressTimer.cancel();
      _isProcessing = false;
      _selectedFiles = [];
      _wordFile = null;
      notifyListeners();
    }
  }

  Future<List<int>> downloadFile(String url) async {
    return await _apiService.downloadFile(url);
  }
}
