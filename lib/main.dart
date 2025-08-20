import 'package:flutter/material.dart';
import 'data/task_repository.dart';
import 'models/task.dart';
import 'state/task_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketTasksApp());
}

class PocketTasksApp extends StatefulWidget {
  const PocketTasksApp({super.key});

  @override
  State<PocketTasksApp> createState() => _PocketTasksAppState();
}

class _PocketTasksAppState extends State<PocketTasksApp> {
  late final TaskController controller;

  @override
  void initState() {
    super.initState();
    controller = TaskController(TaskRepository());
    controller.load(); // fire and forget; UI shows empty until loaded
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'PocketTasks',
          themeMode: ThemeMode.system,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color.fromARGB(255, 129, 10, 203),
            brightness: Brightness.light,
            snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed:  const Color.fromARGB(255, 68, 6, 107),
            brightness: Brightness.dark,
            snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
          ),
          home: PocketTasksHome(controller: controller),
        );
      },
    );
  }
}

class PocketTasksHome extends StatefulWidget {
  const PocketTasksHome({super.key, required this.controller});
  final TaskController controller;

  @override
  State<PocketTasksHome> createState() => _PocketTasksHomeState();
}

class _PocketTasksHomeState extends State<PocketTasksHome> {
  final _formKey = GlobalKey<FormState>();
  final _addController = TextEditingController();
  final _searchController = TextEditingController();

  // Keep last actions for undo
  ({Task task, int index})? _lastDeleted;
  Task? _lastToggledBefore;

  @override
  void initState() {
    super.initState();

    // Wire search field to debounced controller setter
    _searchController.addListener(() {
      widget.controller.setQueryDebounced(_searchController.text);
    });
  }

  @override
  void dispose() {
    _addController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showUndoSnackBar({
    required String message,
    required VoidCallback onUndo,
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Undo', onPressed: onUndo),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _handleToggle(Task t) async {
    _lastToggledBefore = t;
    await widget.controller.toggleDone(t.id);

    _showUndoSnackBar(
      message: t.done ? 'Marked as active' : 'Marked as done',
      onUndo: () async {
        // Revert to previous state
        await widget.controller.toggleDone(t.id);
      },
    );
  }

  Future<void> _handleDelete(Task t, int index) async {
    _lastDeleted = (task: t, index: index);
    await widget.controller.removeTaskById(t.id);

    _showUndoSnackBar(
      message: 'Task deleted',
      onUndo: () async {
        final last = _lastDeleted;
        if (last == null) return;
        await widget.controller.insertTaskAt(last.task, last.index);
        _lastDeleted = null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final tasks = c.visibleTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketTasks'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Add Task Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _addController,
                      decoration: const InputDecoration(
                        labelText: 'Add a new task',
                        hintText: 'e.g. Buy milk',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Title can’t be empty';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submitAdd(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _submitAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tasks',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Wrap(
              spacing: 8,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: c.filter == TaskFilter.all,
                  onSelected: () => c.setFilter(TaskFilter.all),
                ),
                _FilterChip(
                  label: 'Active',
                  selected: c.filter == TaskFilter.active,
                  onSelected: () => c.setFilter(TaskFilter.active),
                ),
                _FilterChip(
                  label: 'Done',
                  selected: c.filter == TaskFilter.done,
                  onSelected: () => c.setFilter(TaskFilter.done),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Task list
          Expanded(
            child: tasks.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    key: const PageStorageKey('task-list'),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final t = tasks[index];
                      return Dismissible(
                        key: ValueKey('dismiss-${t.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        onDismissed: (_) => _handleDelete(t, index),
                        child: ListTile(
                          key: ValueKey(t.id),
                          leading: AnimatedScale(
                            scale: t.done ? 1.0 : 0.9,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              t.done ? Icons.check_circle : Icons.radio_button_unchecked,
                            ),
                          ),
                          title: Text(
                            t.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              decoration: t.done ? TextDecoration.lineThrough : null,
                              fontStyle: t.done ? FontStyle.italic : null,
                            ),
                          ),
                          subtitle: Text(
                            _formatRelative(t.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => _handleToggle(t),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAdd() async {
    if (!_formKey.currentState!.validate()) return;
    final title = _addController.text.trim();
    await widget.controller.addTask(title);
    _addController.clear();
  }

  String _formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No tasks yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Add your first task above.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
