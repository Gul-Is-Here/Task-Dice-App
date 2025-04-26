import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Home Screen.dart';

class DiceScreen extends StatefulWidget {
  const DiceScreen({super.key});

  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends State<DiceScreen> with TickerProviderStateMixin {
  late AnimationController _diceController;
  late Animation<double> _animation;
  final Random _random = Random();
  int? selectedTaskIndex;
  DiceTheme _currentDiceTheme = DiceTheme.themes[0];
  bool _playSound = true;
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = Tween<double>(begin: 0, end: 6 * pi).animate(
      CurvedAnimation(parent: _diceController, curve: Curves.easeInOutCubic),
    );

    _loadPreferences();
    _loadTasks();
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
    final loadedTasks = <Task>[];
    for (int i = 0; i < 6; i++) {
      final taskText = prefs.getString('task_$i') ?? '';
      if (taskText.isNotEmpty) {
        final isCompleted = prefs.getBool('task_${i}_completed') ?? false;
        final category = prefs.getString('task_${i}_category') ?? 'General';
        loadedTasks.add(Task(taskText, isCompleted, category));
      }
    }
    setState(() {
      tasks = loadedTasks;
    });
  }

  Future<void> _markTaskComplete(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('task_${index}_completed', true);
    await _loadTasks(); // Refresh the task list
  }

  void _rollDice() async {
    // Always load fresh tasks before rolling
    await _loadTasks();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add tasks first from the Home screen!'),
        ),
      );
      return;
    }

    final uncompletedTasks = tasks.where((task) => !task.isCompleted).toList();
    if (uncompletedTasks.isEmpty) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('All Tasks Completed!'),
              content: const Text(
                'You\'ve completed all your tasks! Try adding more tasks.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    setState(() => selectedTaskIndex = null);
    if (_playSound) SystemSound.play(SystemSoundType.click);

    _diceController.reset();
    _diceController.forward().then((_) {
      final randomTask =
          uncompletedTasks[_random.nextInt(uncompletedTasks.length)];
      setState(() {
        selectedTaskIndex = tasks.indexOf(randomTask);
      });
    });
  }

  void _changeDiceTheme() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Dice Style'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    DiceTheme.themes.map((theme) {
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              theme.face,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        title: Text(theme.name),
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setInt(
                            'dice_theme',
                            DiceTheme.themes.indexOf(theme),
                          );
                          setState(() => _currentDiceTheme = theme);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
              ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Dice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Refresh tasks',
          ),
          IconButton(
            icon: Icon(_playSound ? Icons.volume_up : Icons.volume_off),
            onPressed: _toggleSound,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tap the dice to randomly select a task',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _rollDice,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _currentDiceTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _currentDiceTheme.face,
                      style: const TextStyle(fontSize: 50),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (selectedTaskIndex != null)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: colorScheme.primary.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Your random task:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tasks[selectedTaskIndex!].text,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(
                                tasks[selectedTaskIndex!].category,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(tasks[selectedTaskIndex!].category),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await _markTaskComplete(selectedTaskIndex!);
                          setState(() {
                            selectedTaskIndex = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Task marked as complete: ${tasks[selectedTaskIndex!].text}',
                              ),
                            ),
                          );
                        },
                        child: const Text('Mark as Complete'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 30),
            TextButton(
              onPressed: _changeDiceTheme,
              child: const Text('Change Dice Style'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Work':
        return Colors.blue;
      case 'Personal':
        return Colors.green;
      case 'Health':
        return Colors.red;
      case 'Learning':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
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
