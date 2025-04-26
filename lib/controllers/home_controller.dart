import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Task {
  String text;
  bool isCompleted;
  String category;

  Task(this.text, this.isCompleted, this.category);

  Task copyWith({String? text, bool? isCompleted, String? category}) {
    return Task(
      text ?? this.text,
      isCompleted ?? this.isCompleted,
      category ?? this.category,
    );
  }
}

class HomeController extends GetxController {
  RxList<Task> tasks =
      List.generate(6, (index) => Task('', false, 'General')).obs;
  RxBool hasShownCompletionPopup = false.obs;

  final categories = ['General', 'Work', 'Personal', 'Health', 'Learning'].obs;

  @override
  void onInit() {
    super.onInit();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    List<Task> loadedTasks = List.generate(6, (index) {
      final text = prefs.getString('task_$index') ?? '';
      final completed = prefs.getBool('task_${index}_completed') ?? false;
      final category = prefs.getString('task_${index}_category') ?? 'General';
      return Task(text, completed, category);
    });

    tasks.value = loadedTasks;
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < tasks.length; i++) {
      await prefs.setString('task_$i', tasks[i].text);
      await prefs.setBool('task_${i}_completed', tasks[i].isCompleted);
      await prefs.setString('task_${i}_category', tasks[i].category);
    }
  }

  void addTask(String text, String category) {
    int emptyIndex = tasks.indexWhere((t) => t.text.isEmpty);
    if (emptyIndex == -1) {
      Get.snackbar('Error', 'Maximum tasks reached!');
      return;
    }
    tasks[emptyIndex] = Task(text, false, category);
    _saveTasks();
    checkCompletion();
  }

  void updateTask(int index, String text) {
    tasks[index] = tasks[index].copyWith(text: text);
    _saveTasks();
  }

  void updateCategory(int index, String category) {
    tasks[index] = tasks[index].copyWith(category: category);
    _saveTasks();
  }

  void toggleCompletion(int index) {
    tasks[index] = tasks[index].copyWith(
      isCompleted: !tasks[index].isCompleted,
    );
    _saveTasks();
    checkCompletion();
  }

  void deleteTask(int index) {
    tasks[index] = Task('', false, 'General');
    _saveTasks();
  }

  void resetTasks() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < tasks.length; i++) {
      await prefs.remove('task_$i');
      await prefs.remove('task_${i}_completed');
      await prefs.remove('task_${i}_category');
    }
    tasks.value = List.generate(6, (index) => Task('', false, 'General'));
    hasShownCompletionPopup.value = false;
  }

  void checkCompletion() {
    final completed =
        tasks.where((t) => t.isCompleted && t.text.isNotEmpty).length;
    final total = tasks.where((t) => t.text.isNotEmpty).length;

    if (completed == total && total > 0 && !hasShownCompletionPopup.value) {
      hasShownCompletionPopup.value = true;
      Future.delayed(Duration.zero, () {
        Get.dialog(
          AlertDialog(
            title: const Text('Congratulations!'),
            content: const Text('You\'ve completed all your tasks!'),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed(
                    '/achievements',
                  ); // Make sure Achievements route is set
                },
                child: const Text('See Achievements'),
              ),
              TextButton(onPressed: Get.back, child: const Text('Dismiss')),
            ],
          ),
        );
      });
    }
  }

  Map<String, dynamic> get stats {
    final completed =
        tasks.where((t) => t.isCompleted && t.text.isNotEmpty).length;
    final total = tasks.where((t) => t.text.isNotEmpty).length;
    return {
      'completed': completed,
      'total': total,
      'percentage': total > 0 ? (completed / total * 100).round() : 0,
    };
  }
}
