import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:flutter/animation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskScreen extends StatefulWidget {
  final Function(bool) toggleTheme;

  const TaskScreen({super.key, required this.toggleTheme});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> with TickerProviderStateMixin {
  late List<Task> tasks = List.generate(6, (index) => Task('', false, 'General'));
  late AnimationController _diceController;
  final Random _random = Random();
  int? selectedTaskIndex;
  bool isDarkMode = false;
  DiceTheme _currentDiceTheme = DiceTheme.themes[0];
  bool _playSound = true;

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadTasks();
    _loadPreferences();
  }

  @override
  void dispose() {
    _diceController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playSound = prefs.getBool('play_sound') ?? true;
      final themeIndex = prefs.getInt('dice_theme') ?? 0;
      if (themeIndex < DiceTheme.themes.length) {
        _currentDiceTheme = DiceTheme.themes[themeIndex];
      }
    });
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
      await prefs.setString('task_$i', tasks[i].text);
      await prefs.setBool('task_${i}_completed', tasks[i].isCompleted);
      await prefs.setString('task_${i}_category', tasks[i].category);
    }
  }

  void _rollDice() {
    if (tasks.every((task) => task.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one task first!')),
      );
      return;
    }

    setState(() {
      selectedTaskIndex = null;
    });

    _diceController.reset();
    _diceController.forward().then((_) {
      int randomIndex;
      do {
        randomIndex = _random.nextInt(6);
      } while (tasks[randomIndex].text.isEmpty);

      setState(() {
        selectedTaskIndex = randomIndex;
      });
    });
  }

  void _updateTask(int index, String newText) {
    setState(() {
      tasks[index] = Task(newText, tasks[index].isCompleted, tasks[index].category);
    });
    _saveTasks();
  }

  void _updateTaskCategory(int index, String newCategory) {
    setState(() {
      tasks[index] = Task(tasks[index].text, tasks[index].isCompleted, newCategory);
    });
    _saveTasks();
  }

  void _toggleTaskCompletion(int index) {
    setState(() {
      tasks[index] = Task(tasks[index].text, !tasks[index].isCompleted, tasks[index].category);
    });
    _saveTasks();
  }

  void _resetTasks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                tasks = List.generate(6, (index) => Task('', false, 'General'));
                selectedTaskIndex = null;
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> getTaskStats() {
    final completed = tasks.where((t) => t.isCompleted && t.text.isNotEmpty).length;
    final total = tasks.where((t) => t.text.isNotEmpty).length;
    return {
      'completed': completed,
      'total': total,
      'percentage': total > 0 ? (completed / total * 100).round() : 0,
    };
  }

  void _changeDiceTheme() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Dice Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DiceTheme.themes.map((theme) => ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(theme.face, style: const TextStyle(fontSize: 20))),
            ),
            title: Text(theme.name),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('dice_theme', DiceTheme.themes.indexOf(theme));
              setState(() => _currentDiceTheme = theme);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _toggleSound() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playSound = !_playSound;
      prefs.setBool('play_sound', _playSound);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stats = getTaskStats();
    final achievements = AchievementManager.checkAchievements(tasks);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Task Dice',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: () => _showAchievementsDialog(achievements),
          ),
          IconButton(
            icon: Icon(_playSound ? Icons.volume_up : Icons.volume_off),
            onPressed: _toggleSound,
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
              widget.toggleTheme(isDarkMode);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Stats Card
            Card(
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Today\'s Progress',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: stats['total'] > 0 ? stats['completed'] / stats['total'] : 0,
                      backgroundColor: Colors.grey[300],
                      color: colorScheme.primary,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${stats['completed']}/${stats['total']} tasks (${stats['percentage']}%)',
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
              ),
            ),

            // Task List
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...List.generate(6, (index) {
                      return TaskInputField(
                        index: index + 1,
                        initialText: tasks[index].text,
                        isCompleted: tasks[index].isCompleted,
                        category: tasks[index].category,
                        isSelected: selectedTaskIndex == index,
                        onChanged: (text) => _updateTask(index, text),
                        onCategoryChanged: (cat) => _updateTaskCategory(index, cat),
                        onToggleComplete: () => _toggleTaskCompletion(index),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Dice and Actions
            Column(
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _rollDice,
                  child: AnimatedBuilder(
                    animation: _diceController,
                    builder: (context, child) {
                      final angle = _diceController.value * 2 * pi;
                      return Transform.rotate(
                        angle: angle,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _currentDiceTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentDiceTheme.face,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _changeDiceTheme,
                  child: const Text('Change Dice Style'),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _resetTasks,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                  child: const Text('Reset All Tasks'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementsDialog(List<Achievement> achievements) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Achievements'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: achievements.map((a) => ListTile(
              leading: Icon(a.icon,
                  color: a.unlocked ? Colors.amber : Colors.grey),
              title: Text(a.title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: a.unlocked ? Colors.black : Colors.grey)),
              subtitle: Text(a.description),
              trailing: a.unlocked
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.lock, color: Colors.grey),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class TaskInputField extends StatelessWidget {
  final int index;
  final String initialText;
  final bool isCompleted;
  final String category;
  final bool isSelected;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onToggleComplete;

  const TaskInputField({
    super.key,
    required this.index,
    required this.initialText,
    required this.isCompleted,
    required this.category,
    required this.isSelected,
    required this.onChanged,
    required this.onCategoryChanged,
    required this.onToggleComplete,
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withOpacity(0.1)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$index.',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: initialText),
                    onChanged: onChanged,
                    maxLength: 50,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    decoration: InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      hintText: 'Enter task $index',
                      hintStyle: GoogleFonts.poppins(
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: isCompleted
                          ? colorScheme.onSurface.withOpacity(0.5)
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                Checkbox(
                  value: isCompleted,
                  onChanged: (value) => onToggleComplete(),
                  activeColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            DropdownButton<String>(
              value: category,
              isDense: true,
              underline: Container(),
              items: ['Work', 'Personal', 'Health', 'Learning', 'General']
                  .map((cat) => DropdownMenuItem(
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
              ))
                  .toList(),
              onChanged: (value) => onCategoryChanged(value!),
            ),
          ],
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

class DiceTheme {
  final String face;
  final Color color;
  final String name;

  DiceTheme({required this.face, required this.color, required this.name});

  static List<DiceTheme> get themes => [
    DiceTheme(face: '🎲', color: Colors.deepPurple, name: 'Classic'),
    DiceTheme(face: '⚀', color: Colors.red, name: 'Dots'),
    DiceTheme(face: '1️⃣', color: Colors.blue, name: 'Numbers'),
    DiceTheme(face: '🎯', color: Colors.green, name: 'Target'),
  ];
}

class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;

  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    this.unlocked = false,
  });
}

class AchievementManager {
  static List<Achievement> checkAchievements(List<Task> tasks) {
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final streak = 0; // You would load this from SharedPreferences

    return [
      Achievement(
          title: 'First Step',
          description: 'Complete your first task',
          icon: Icons.star,
          unlocked: completedCount >= 1),
      Achievement(
          title: 'Task Master',
          description: 'Complete 5 tasks in one day',
          icon: Icons.workspace_premium,
          unlocked: completedCount >= 5),
      Achievement(
          title: 'Consistency',
          description: '3-day streak',
          icon: Icons.timelapse,
          unlocked: streak >= 3),
      Achievement(
          title: 'Variety',
          description: 'Use all categories',
          icon: Icons.category,
          unlocked: tasks.map((t) => t.category).toSet().length >= 4),
    ];
  }
}


