import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({
    super.key,
    this.summaryTutorialKey,
    this.kpiTutorialKey,
  });

  final GlobalKey? summaryTutorialKey;
  final GlobalKey? kpiTutorialKey;

  static const Color _bg = Color(0xFF000000);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardBg = Color(0xFF171717);
  static const Color _softCard = Color(0xFF202020);
  static const Color _line = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text('No autenticado', style: TextStyle(color: _gold)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Estadísticas',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'assets/logo/icon.png',
            errorBuilder: (_, __, ___) => const Icon(Icons.star, color: _gold),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final stats = _buildStats(docs);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderSummary(
                  key: summaryTutorialKey,
                  stats: stats,
                ),
                const SizedBox(height: 16),
                _KpiGrid(
                  key: kpiTutorialKey,
                  stats: stats,
                ),
                const SizedBox(height: 16),
                _WeeklyProductivityCard(days: stats.weekDays),
                const SizedBox(height: 16),
                _TodayCard(stats: stats),
                const SizedBox(height: 16),
                _CategoryCard(categories: stats.categories, total: stats.total),
              ],
            ),
          );
        },
      ),
    );
  }

  _StatsData _buildStats(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    int completed = 0;
    int todayTotal = 0;
    int todayDone = 0;
    final Map<String, _CategoryStats> categories = {};
    final Map<DateTime, _DayStats> week = {
      for (int i = 0; i < 7; i++)
        weekStart.add(Duration(days: i)): _DayStats(
          date: weekStart.add(Duration(days: i)),
        ),
    };

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final done = data['completed'] == true;
      final category = (data['materia'] ?? 'General').toString().trim();
      final safeCategory = category.isEmpty ? 'General' : category;
      final dueDate = _readDueDate(data['dueDate']);

      if (done) completed++;

      final catStats = categories.putIfAbsent(
        safeCategory,
        () => _CategoryStats(label: safeCategory),
      );
      catStats.total++;
      if (done) catStats.completed++;

      if (dueDate != null) {
        final day = DateTime(dueDate.year, dueDate.month, dueDate.day);
        if (day == today) {
          todayTotal++;
          if (done) todayDone++;
        }

        final weekDay = week[day];
        if (weekDay != null) {
          weekDay.total++;
          if (done) weekDay.completed++;
        }
      }
    }

    final sortedCategories = categories.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final total = docs.length;
    final pending = total - completed;
    final productivity = total == 0 ? 0 : completed / total;

    return _StatsData(
      total: total,
      completed: completed,
      pending: pending,
      productivity: productivity.toDouble(),
      todayTotal: todayTotal,
      todayDone: todayDone,
      weekDays: week.values.toList(),
      categories: sortedCategories.take(6).toList(),
    );
  }

  DateTime? _readDueDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary({super.key, required this.stats});

  final _StatsData stats;

  @override
  Widget build(BuildContext context) {
    final score = (stats.productivity * 100).round();
    final label = switch (score) {
      >= 80 => 'Ritmo excelente',
      >= 60 => 'Buen avance',
      >= 35 => 'En progreso',
      > 0 => 'Arrancando',
      _ => 'Sin actividad',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: StatsPage._cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StatsPage._gold.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen de productividad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: StatsPage._gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: StatsPage._gold.withValues(alpha: 0.45)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$score%',
              style: const TextStyle(
                color: StatsPage._gold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({super.key, required this.stats});

  final _StatsData stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.95,
      children: [
        _StatCard(label: 'Total', value: '${stats.total}', icon: Icons.list),
        _StatCard(
          label: 'Completadas',
          value: '${stats.completed}',
          icon: Icons.check_circle_outline,
          highlight: true,
        ),
        _StatCard(
          label: 'Pendientes',
          value: '${stats.pending}',
          icon: Icons.pending_actions,
        ),
        _StatCard(
          label: 'Productividad',
          value: '${(stats.productivity * 100).round()}%',
          icon: Icons.trending_up,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? StatsPage._gold.withValues(alpha: 0.12)
            : StatsPage._softCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? StatsPage._gold.withValues(alpha: 0.45)
              : StatsPage._line,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: highlight ? StatsPage._gold : Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: highlight ? StatsPage._gold : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyProductivityCard extends StatelessWidget {
  const _WeeklyProductivityCard({required this.days});

  final List<_DayStats> days;

  @override
  Widget build(BuildContext context) {
    final maxTasks = days.fold<int>(
      1,
      (max, day) => day.total > max ? day.total : max,
    );

    return _DashboardCard(
      title: 'Productividad semanal',
      trailing: const Icon(Icons.bar_chart, color: StatsPage._gold),
      child: SizedBox(
        height: 154,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: days.map((day) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _DayBar(day: day, maxTasks: maxTasks),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.day, required this.maxTasks});

  final _DayStats day;
  final int maxTasks;

  @override
  Widget build(BuildContext context) {
    final totalRatio = day.total == 0 ? 0.0 : day.total / maxTasks;
    final doneRatio = day.total == 0 ? 0.0 : day.completed / day.total;
    final totalHeight = 88 * totalRatio.clamp(0.0, 1.0);
    final doneHeight = totalHeight * doneRatio.clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${day.completed}/${day.total}',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        const SizedBox(height: 8),
        Container(
          width: 22,
          height: 92,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: StatsPage._line),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 22,
                height: totalHeight < 4 && day.total > 0 ? 4 : totalHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 22,
                height: doneHeight < 4 && day.completed > 0 ? 4 : doneHeight,
                decoration: BoxDecoration(
                  color: StatsPage._gold,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _weekdayLabel(day.date),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return labels[date.weekday - 1];
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.stats});

  final _StatsData stats;

  @override
  Widget build(BuildContext context) {
    if (stats.todayTotal == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: StatsPage._softCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: StatsPage._line),
        ),
        child: const Row(
          children: [
            Icon(Icons.today, color: Colors.white38, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sin tareas programadas para hoy',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final progress = stats.todayDone / stats.todayTotal;

    return _DashboardCard(
      title: 'Tareas de hoy',
      trailing: Text(
        '${stats.todayDone}/${stats.todayTotal}',
        style: const TextStyle(
          color: StatsPage._gold,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ThinProgressBar(value: progress, color: StatsPage._gold),
          const SizedBox(height: 10),
          Text(
            stats.todayDone == stats.todayTotal
                ? 'Todo lo de hoy está completo.'
                : '${stats.todayTotal - stats.todayDone} pendiente(s) para hoy.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.categories, required this.total});

  final List<_CategoryStats> categories;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return _DashboardCard(
      title: 'Distribución por categoría',
      child: Column(
        children: categories.map((category) {
          final ratio = total == 0 ? 0.0 : category.total / total;
          final color = _catColor(category.label);

          return Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _ThinProgressBar(value: ratio, color: color)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${category.completed}/${category.total}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _catColor(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('escuela')) return Colors.blueAccent;
    if (lower.contains('trabajo')) return Colors.orangeAccent;
    if (lower.contains('pagos')) return Colors.redAccent;
    if (lower.contains('personal')) return Colors.greenAccent;
    return StatsPage._gold;
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StatsPage._cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StatsPage._line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ThinProgressBar extends StatelessWidget {
  const _ThinProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 7,
        backgroundColor: Colors.black,
        color: color,
      ),
    );
  }
}

class _StatsData {
  const _StatsData({
    required this.total,
    required this.completed,
    required this.pending,
    required this.productivity,
    required this.todayTotal,
    required this.todayDone,
    required this.weekDays,
    required this.categories,
  });

  final int total;
  final int completed;
  final int pending;
  final double productivity;
  final int todayTotal;
  final int todayDone;
  final List<_DayStats> weekDays;
  final List<_CategoryStats> categories;
}

class _DayStats {
  _DayStats({required this.date});

  final DateTime date;
  int total = 0;
  int completed = 0;
}

class _CategoryStats {
  _CategoryStats({required this.label});

  final String label;
  int total = 0;
  int completed = 0;
}
