import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Achievements Screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Task> tasks = List.generate(
    6,
    (index) => Task('', false, 'General'),
  );
  final TextEditingController _newTaskController = TextEditingController();
  String _newTaskCategory = 'General';
  bool _hasShownCompletionPopup = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _newTaskController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (int i = 0; i < 6; i++) {
        final taskText = prefs.getString('task_$i') ?? '';
        final isCompleted = prefs.getBool('task_${i}_completed') ?? false;
        final category = prefs.getString('task_${i}_category') ?? 'General';
        tasks[i] = Task(taskText, isCompleted, category);
      }
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i].text.isEmpty) {
        await prefs.remove('task_$i');
        await prefs.remove('task_${i}_completed');
        await prefs.remove('task_${i}_category');
      } else {
        await prefs.setString('task_$i', tasks[i].text);
        await prefs.setBool('task_${i}_completed', tasks[i].isCompleted);
        await prefs.setString('task_${i}_category', tasks[i].category);
      }
    }
  }

  void _addNewTask() {
    if (_newTaskController.text.trim().isEmpty) return;

    int availableIndex = tasks.indexWhere(
      (task) => task.text.isEmpty || task.isCompleted,
    );

    if (availableIndex == -1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum tasks reached!')));
      return;
    }

    setState(() {
      tasks[availableIndex] = Task(
        _newTaskController.text.trim(),
        false,
        _newTaskCategory,
      );
    });

    _saveTasks();
    _newTaskController.clear();
    Navigator.pop(context);
  }

  void _updateTask(int index, String newText) {
    setState(() {
      tasks[index] = Task(
        newText,
        tasks[index].isCompleted,
        tasks[index].category,
      );
    });
    _saveTasks();
  }

  void _updateTaskCategory(int index, String newCategory) {
    setState(() {
      tasks[index] = Task(
        tasks[index].text,
        tasks[index].isCompleted,
        newCategory,
      );
    });
    _saveTasks();
  }

  void _toggleTaskCompletion(int index) {
    setState(() {
      tasks[index] = Task(
        tasks[index].text,
        !tasks[index].isCompleted,
        tasks[index].category,
      );
    });
    _saveTasks().then((_) {
      _checkForCompletion();
    });
  }

  void _deleteTask(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('task_$index');
    await prefs.remove('task_${index}_completed');
    await prefs.remove('task_${index}_category');

    setState(() {
      tasks[index] = Task('', false, 'General');
    });
  }

  void _resetTasks() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset All Tasks'),
            content: const Text('Are you sure you want to clear all tasks?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final prefs = await SharedPreferences.getInstance();
                  for (int i = 0; i < tasks.length; i++) {
                    await prefs.remove('task_$i');
                    await prefs.remove('task_${i}_completed');
                    await prefs.remove('task_${i}_category');
                  }
                  setState(() {
                    tasks = List.generate(
                      6,
                      (index) => Task('', false, 'General'),
                    );
                    _hasShownCompletionPopup = false;
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
    );
  }

  void _checkForCompletion() {
    final stats = getTaskStats();
    if (stats['completed'] == stats['total'] &&
        stats['total'] > 0 &&
        !_hasShownCompletionPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Congratulations!'),
                content: const Text(
                  'You\'ve completed all your tasks! Check your achievements.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementsScreen(),
                        ),
                      );
                    },
                    child: const Text('See Achievements'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
        );
      });
      setState(() {
        _hasShownCompletionPopup = true;
      });
    }
  }

  Map<String, dynamic> getTaskStats() {
    final completed =
        tasks.where((t) => t.isCompleted && t.text.isNotEmpty).length;
    final total = tasks.where((t) => t.text.isNotEmpty).length;
    return {
      'completed': completed,
      'total': total,
      'percentage': total > 0 ? (completed / total * 100).round() : 0,
    };
  }

  Widget _buildEmptyTaskCard(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Text(
              '${index + 1}.',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Empty slot - tap + to add task',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadTasks();
    final colorScheme = Theme.of(context).colorScheme;
    final stats = getTaskStats();
    final hasAnyTasks = tasks.any((task) => task.text.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _resetTasks,
            tooltip: 'Reset All Tasks',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Task Progress',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value:
                          stats['total'] > 0
                              ? stats['completed'] / stats['total']
                              : 0,
                      backgroundColor: colorScheme.surfaceVariant,
                      color: colorScheme.primary,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${stats['completed']}/${stats['total']} tasks (${stats['percentage']}%)',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child:
                  hasAnyTasks
                      ? ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          return tasks[index].text.isEmpty
                              ? _buildEmptyTaskCard(index)
                              : TaskCard(
                                task: tasks[index],
                                index: index + 1,
                                onChanged: (text) => _updateTask(index, text),
                                onCategoryChanged:
                                    (cat) => _updateTaskCategory(index, cat),
                                onToggleComplete:
                                    () => _toggleTaskCompletion(index),
                                onDelete: () => _deleteTask(index),
                              );
                        },
                      )
                      : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 64,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks yet!',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _showAddTaskDialog(),
                              child: const Text('Add Your First Task'),
                            ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _newTaskController,
                  decoration: const InputDecoration(
                    labelText: 'Task Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 50,
                  onSubmitted: (_) => _addNewTask(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _newTaskCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      ['General', 'Work', 'Personal', 'Health', 'Learning']
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _newTaskCategory = value;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _addNewTask,
                child: const Text('Add Task'),
              ),
            ],
          ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final int index;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.index,
    required this.onChanged,
    required this.onCategoryChanged,
    required this.onToggleComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColors = {
      'Work': Colors.blue,
      'Personal': Colors.green,
      'Health': Colors.red,
      'Learning': Colors.purple,
      'General': Colors.grey,
    };

    return Container(
      height: 120,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$index.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: task.text),
                      onChanged: onChanged,
                      maxLength: 50,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: 'Edit task...',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        decoration:
                            task.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                        color:
                            task.isCompleted
                                ? colorScheme.onSurface.withOpacity(0.5)
                                : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    color: colorScheme.error,
                  ),
                  Checkbox(
                    value: task.isCompleted,
                    onChanged: (value) => onToggleComplete(),
                    activeColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              DropdownButton<String>(
                value: task.category,
                isDense: true,
                underline: Container(),
                items:
                    ['Work', 'Personal', 'Health', 'Learning', 'General']
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: categoryColors[cat],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(cat),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => onCategoryChanged(value!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Task {
  final String text;
  final bool isCompleted;
  final String category;

  Task(this.text, this.isCompleted, this.category);
}
