import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/task_repository.dart';
import '../models/task.dart';

enum TaskFilter { all, active, done }

/// This Pure function used in UI and in tests.
List<Task> computeVisibleTasks(
  List<Task> tasks,
  TaskFilter filter,
  String query,
) {
  final q = query.trim().toLowerCase();
  Iterable<Task> list = tasks;

  switch (filter) {
    case TaskFilter.active:
      list = list.where((t) => !t.done);
      break;
    case TaskFilter.done:
      list = list.where((t) => t.done);
      break;
    case TaskFilter.all:
      break;
  }

  if (q.isNotEmpty) {
    list = list.where((t) => t.title.toLowerCase().contains(q));
  }

  final sorted = list.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted;
}

class TaskController extends ChangeNotifier {
  TaskController(this._repo);

  final TaskRepository _repo;
  final _uuid = const Uuid();

  final List<Task> _tasks = [];
  TaskFilter _filter = TaskFilter.all;
  String _query = '';

  Timer? _debounce;

  List<Task> get tasks => List.unmodifiable(_tasks);
  TaskFilter get filter => _filter;
  String get query => _query;

  List<Task> get visibleTasks => computeVisibleTasks(_tasks, _filter, _query);

  Future<void> load() async {
    final loaded = await _repo.load();
    _tasks
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<void> _persist() => _repo.save(_tasks);

  /// Add with inline validation in UI 
  Future<void> addTask(String title) async {
    final task = Task(
      id: _uuid.v4(),
      title: title.trim(),
      done: false,
      createdAt: DateTime.now(),
    );
    _tasks.add(task);
    await _persist();
    notifyListeners();
  }

  Future<void> removeTaskById(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> insertTaskAt(Task task, int index) async {
    final clamped = index.clamp(0, _tasks.length);
    _tasks.insert(clamped, task);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleDone(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final current = _tasks[idx];
    _tasks[idx] = current.copyWith(done: !current.done);
    await _persist();
    notifyListeners();
  }

  void setFilter(TaskFilter f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
  }

  /// Debounced search setter – UI calls this on every keystroke.
  void setQueryDebounced(String value, {Duration delay = const Duration(milliseconds: 300)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, () {
      _query = value;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
