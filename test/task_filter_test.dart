import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_tasks/models/task.dart';
import 'package:pocket_tasks/state/task_controller.dart';

void main() {
  group('computeVisibleTasks', () {
    final now = DateTime(2025, 1, 1);

    final tasks = <Task>[
      Task(id: '1', title: 'Buy milk', done: false, createdAt: now),
      Task(id: '2', title: 'Email boss', done: true, createdAt: now.add(const Duration(minutes: 1))),
      Task(id: '3', title: 'Book flight', done: false, createdAt: now.add(const Duration(minutes: 2))),
      Task(id: '4', title: 'Milk the cow', done: true, createdAt: now.add(const Duration(minutes: 3))),
    ];

    test('All filter returns all, newest first', () {
      final result = computeVisibleTasks(tasks, TaskFilter.all, '');
      expect(result.length, 4);
      expect(result.first.id, '4'); // newest first
      expect(result.last.id, '1');
    });

    test('Active filter returns only not done', () {
      final result = computeVisibleTasks(tasks, TaskFilter.active, '');
      expect(result.length, 2);
      expect(result.every((t) => !t.done), true);
    });

    test('Done filter returns only done', () {
      final result = computeVisibleTasks(tasks, TaskFilter.done, '');
      expect(result.length, 2);
      expect(result.every((t) => t.done), true);
    });

    test('Query filters by title (case-insensitive, contains)', () {
      final result = computeVisibleTasks(tasks, TaskFilter.all, 'milk');
      // "Buy milk" and "Milk the cow"
      expect(result.map((t) => t.id), containsAll(['1', '4']));
      expect(result.length, 2);
    });

    test('Query + Active filter combined', () {
      final result = computeVisibleTasks(tasks, TaskFilter.active, 'book');
      expect(result.length, 1);
      expect(result.first.id, '3');
    });
  });
}
