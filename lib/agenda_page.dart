import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({
    super.key,
    this.calendarTutorialKey,
    this.eventsTutorialKey,
  });

  final GlobalKey? calendarTutorialKey;
  final GlobalKey? eventsTutorialKey;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  DateTime _selectedDate = DateTime.now();
  late DateTime _visibleMonth;

  static const Color _bg = Color(0xFF000000);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardBg = Color(0xFF171717);
  static const Color _softCard = Color(0xFF202020);
  static const Color _line = Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Agenda',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/logo/icon.png',
              height: 40,
              width: 40,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.star,
                color: _gold,
              ),
            ),
          ),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text('Inicia sesión para ver tu agenda',
                  style: TextStyle(color: Colors.white70)),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('tasks')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _gold),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error al cargar agenda',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final tasks = snapshot.data?.docs ?? [];
                final tasksByDay = _groupTasksByDay(tasks);
                final selectedTasks =
                    tasksByDay[_dayKey(_selectedDate)] ?? const [];

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CalendarCard(
                              tutorialKey: widget.calendarTutorialKey,
                              visibleMonth: _visibleMonth,
                              selectedDate: _selectedDate,
                              taskDays: tasksByDay.keys.toSet(),
                              onPreviousMonth: () => _changeMonth(-1),
                              onNextMonth: () => _changeMonth(1),
                              onSelectDate: (date) {
                                setState(() {
                                  _selectedDate = date;
                                  _visibleMonth =
                                      DateTime(date.year, date.month);
                                });
                              },
                            ),
                            const SizedBox(height: 18),
                            _EventsSection(
                              tutorialKey: widget.eventsTutorialKey,
                              selectedDate: _selectedDate,
                              tasks: selectedTasks,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + offset);
      if (_selectedDate.year != _visibleMonth.year ||
          _selectedDate.month != _visibleMonth.month) {
        _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month);
      }
    });
  }

  Map<String, List<QueryDocumentSnapshot>> _groupTasksByDay(
    List<QueryDocumentSnapshot> tasks,
  ) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};

    for (final task in tasks) {
      final data = task.data() as Map<String, dynamic>;
      final dueDate = _readDueDate(data['dueDate']);
      if (dueDate == null) continue;

      final key = _dayKey(dueDate);
      grouped.putIfAbsent(key, () => []).add(task);
    }

    for (final list in grouped.values) {
      list.sort((a, b) {
        final aDate =
            _readDueDate((a.data() as Map<String, dynamic>)['dueDate']);
        final bDate =
            _readDueDate((b.data() as Map<String, dynamic>)['dueDate']);
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });
    }

    return grouped;
  }

  DateTime? _readDueDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    this.tutorialKey,
    required this.visibleMonth,
    required this.selectedDate,
    required this.taskDays,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  final GlobalKey? tutorialKey;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Set<String> taskDays;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final days = _buildCalendarDays(visibleMonth);

    return Container(
      key: tutorialKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AgendaPageState._cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AgendaPageState._line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _MonthButton(
                icon: Icons.chevron_left,
                onTap: onPreviousMonth,
              ),
              Expanded(
                child: Text(
                  _monthLabel(visibleMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MonthButton(
                icon: Icons.chevron_right,
                onTap: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              _WeekdayLabel('L'),
              _WeekdayLabel('M'),
              _WeekdayLabel('M'),
              _WeekdayLabel('J'),
              _WeekdayLabel('V'),
              _WeekdayLabel('S'),
              _WeekdayLabel('D'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 6,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final date = days[index];
              final belongsToMonth = date.month == visibleMonth.month;
              final selected = _isSameDay(date, selectedDate);
              final today = _isSameDay(date, DateTime.now());
              final hasTasks = taskDays.contains(_dayKey(date));

              return _CalendarDay(
                date: date,
                belongsToMonth: belongsToMonth,
                selected: selected,
                today: today,
                hasTasks: hasTasks,
                onTap: () => onSelectDate(date),
              );
            },
          ),
        ],
      ),
    );
  }

  List<DateTime> _buildCalendarDays(DateTime month) {
    final first = DateTime(month.year, month.month);
    final firstWeekdayOffset = first.weekday - 1;
    final start = first.subtract(Duration(days: firstWeekdayOffset));
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((firstWeekdayOffset + daysInMonth) / 7).ceil() * 7;

    return List.generate(
        totalCells, (index) => start.add(Duration(days: index)));
  }

  String _monthLabel(DateTime date) {
    return '${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return months[month - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _AgendaPageState._softCard,
          shape: BoxShape.circle,
          border: Border.all(color: _AgendaPageState._line),
        ),
        child: Icon(icon, color: _AgendaPageState._gold),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.belongsToMonth,
    required this.selected,
    required this.today,
    required this.hasTasks,
    required this.onTap,
  });

  final DateTime date;
  final bool belongsToMonth;
  final bool selected;
  final bool today;
  final bool hasTasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? Colors.black
        : belongsToMonth
            ? Colors.white
            : Colors.white24;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? _AgendaPageState._gold : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: today && !selected
              ? Border.all(color: _AgendaPageState._gold.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: hasTasks ? 5 : 0,
              height: hasTasks ? 5 : 0,
              decoration: BoxDecoration(
                color: selected ? Colors.black : _AgendaPageState._gold,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsSection extends StatelessWidget {
  const _EventsSection({
    this.tutorialKey,
    required this.selectedDate,
    required this.tasks,
  });

  final GlobalKey? tutorialKey;
  final DateTime selectedDate;
  final List<QueryDocumentSnapshot> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: tutorialKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eventos del ${selectedDate.day} de ${_monthName(selectedDate.month)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: _AgendaPageState._cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _AgendaPageState._line),
            ),
            child: const Row(
              children: [
                Icon(Icons.event_busy, color: Colors.white38),
                SizedBox(width: 12),
                Text(
                  'No hay eventos este día',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...tasks.map((doc) => _EventTile(task: doc)),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return months[month - 1];
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.task});

  final QueryDocumentSnapshot task;

  @override
  Widget build(BuildContext context) {
    final data = task.data() as Map<String, dynamic>;
    final title = (data['title'] ?? 'Sin título').toString();
    final materia = (data['materia'] ?? 'General').toString();
    final isCompleted = data['completed'] == true;
    final dueDate = _readDueDate(data['dueDate']);
    final time = dueDate == null ? '' : DateFormat('h:mm a').format(dueDate);
    final color = _catColor(materia);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AgendaPageState._cardBg,
        borderRadius: BorderRadius.circular(15),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _AgendaPageState._line),
            ),
            alignment: Alignment.center,
            child: Text(
              time.isEmpty ? '--' : time,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  materia,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isCompleted)
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        ],
      ),
    );
  }

  DateTime? _readDueDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Color _catColor(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('escuela')) return Colors.blueAccent;
    if (lower.contains('trabajo')) return Colors.orangeAccent;
    if (lower.contains('pagos')) return Colors.redAccent;
    if (lower.contains('personal')) return Colors.greenAccent;
    return _AgendaPageState._gold;
  }
}
