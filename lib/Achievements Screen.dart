import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late List<Task> _tasks = [];
  late List<Achievement> _achievements = [];
  int _totalCompleted = 0;
  int _totalTasks = 0;
  int _uniqueCategories = 0;

  @override
  void initState() {
    super.initState();
    _loadTasks();
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

    final completedCount = loadedTasks.where((t) => t.isCompleted).length;
    final totalCount = loadedTasks.where((t) => t.text.isNotEmpty).length;
    final categoriesUsed =
        loadedTasks
            .map((t) => t.category)
            .where((cat) => cat.isNotEmpty)
            .toSet()
            .length;

    setState(() {
      _tasks = loadedTasks;
      _totalCompleted = completedCount;
      _totalTasks = totalCount;
      _uniqueCategories = categoriesUsed;
      _achievements = AchievementManager.checkAchievements(
        completedCount: completedCount,
        totalCount: totalCount,
        categoriesUsed: categoriesUsed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double progress =
        _totalTasks > 0 ? _totalCompleted / _totalTasks : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Refresh achievements',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Your Progress',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          icon: Icons.check_circle,
                          value: _totalCompleted,
                          label: 'Completed',
                          color: Colors.green,
                        ),
                        _buildStatItem(
                          icon: Icons.list_alt,
                          value: _totalTasks,
                          label: 'Total Tasks',
                          color: colorScheme.primary,
                        ),
                        _buildStatItem(
                          icon: Icons.category,
                          value: _uniqueCategories,
                          label: 'Categories',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: colorScheme.surfaceVariant,
                      color: colorScheme.primary,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% of tasks completed',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTasks,
              child:
                  _achievements.isEmpty
                      ? Center(
                        child: Text(
                          'No achievements yet!\nComplete tasks to unlock achievements.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _achievements.length,
                        itemBuilder: (context, index) {
                          final achievement = _achievements[index];
                          return _buildAchievementCard(achievement, context);
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildAchievementCard(Achievement achievement, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              achievement.unlocked
                  ? Colors.amber.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color:
                    achievement.unlocked
                        ? Colors.amber.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: achievement.unlocked ? Colors.amber : Colors.grey,
                  width: 2,
                ),
              ),
              child: Icon(
                achievement.icon,
                color: achievement.unlocked ? Colors.amber : Colors.grey,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          achievement.unlocked
                              ? colorScheme.onSurface
                              : Colors.grey,
                    ),
                  ),
                  Text(
                    achievement.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          achievement.unlocked
                              ? colorScheme.onSurface.withOpacity(0.7)
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              achievement.unlocked ? Icons.check_circle : Icons.lock_outline,
              color: achievement.unlocked ? Colors.green : Colors.grey,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
  final String? progressText;

  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    this.unlocked = false,
    this.progressText,
  });
}

class AchievementManager {
  static List<Achievement> checkAchievements({
    required int completedCount,
    required int totalCount,
    required int categoriesUsed,
  }) {
    return [
      Achievement(
        title: 'First Step',
        description: 'Complete your first task',
        icon: Icons.star,
        unlocked: completedCount >= 1,
        progressText: completedCount > 0 ? null : '0/1 completed',
      ),
      Achievement(
        title: 'Task Master',
        description: 'Complete 5 tasks',
        icon: Icons.workspace_premium,
        unlocked: completedCount >= 5,
        progressText:
            completedCount >= 5 ? null : '$completedCount/5 completed',
      ),
      Achievement(
        title: 'Perfect Day',
        description: 'Complete all tasks for the day',
        icon: Icons.verified,
        unlocked: totalCount > 0 && completedCount == totalCount,
        progressText:
            totalCount > 0
                ? '$completedCount/$totalCount completed'
                : 'No tasks yet',
      ),
      Achievement(
        title: 'Variety Seeker',
        description: 'Use all 5 categories',
        icon: Icons.category,
        unlocked: categoriesUsed >= 5,
        progressText:
            categoriesUsed >= 5 ? null : '$categoriesUsed/5 categories used',
      ),
      Achievement(
        title: 'Task Collector',
        description: 'Add 6 tasks',
        icon: Icons.list_alt,
        unlocked: totalCount >= 6,
        progressText: totalCount >= 6 ? null : '$totalCount/6 tasks added',
      ),
      Achievement(
        title: 'Consistent Performer',
        description: 'Complete 3 tasks for 3 days in a row',
        icon: Icons.timelapse,
        unlocked: false, // You'll need to implement streak tracking
        progressText: '0/3 days',
      ),
      Achievement(
        title: 'Early Bird',
        description: 'Complete a task before 8 AM',
        icon: Icons.wb_sunny,
        unlocked: false, // You'll need time tracking
      ),
    ];
  }
}

class Task {
  final String text;
  final bool isCompleted;
  final String category;

  Task(this.text, this.isCompleted, this.category);
}
