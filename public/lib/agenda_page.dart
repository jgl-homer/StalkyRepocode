import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  DateTime _selectedDate = DateTime.now();

  final Color _bg = const Color(0xFF000000);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _cardBg = const Color(0xFF1E1E1E);

  List<DateTime> _getWeekDays() {
    final now = DateTime.now();
    return List.generate(7, (index) => now.add(Duration(days: index - 3))); // 3 days before, 3 days after
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Agenda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo/icon.png',
              height: 40,
              width: 40,
              errorBuilder: (_, __, ___) => Icon(Icons.star, color: _gold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Horizontal Day Selector
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekDays.length,
              itemBuilder: (context, index) {
                final date = weekDays[index];
                final isSelected = _isSameDay(date, _selectedDate);
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? _gold : _cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected ? Border.all(color: _gold, width: 2) : Border.all(color: Colors.transparent),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('d').format(date),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // Selected Date Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('MMMM d, yyyy').format(_selectedDate),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Tasks List
          Expanded(
            child: user == null
                ? const Center(child: Text('Please login'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('tasks')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: _gold));
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error', style: TextStyle(color: Colors.red)));
                      }

                      final tasks = snapshot.data?.docs ?? [];
                      final selectedDayTasks = tasks.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['dueDate'] != null && data['dueDate'] is Timestamp) {
                          final dueDate = (data['dueDate'] as Timestamp).toDate();
                          return _isSameDay(dueDate, _selectedDate);
                        }
                        return false;
                      }).toList();

                      if (selectedDayTasks.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 64, color: _gold.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              const Text('No hay eventos este día', style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: selectedDayTasks.length,
                        itemBuilder: (context, index) {
                          final task = selectedDayTasks[index].data() as Map<String, dynamic>;
                          final title = task['title'] ?? 'Sin título';
                          final materia = task['materia'] ?? 'General';
                          final isCompleted = task['completed'] ?? false;
                          
                          Color categoryColor = Colors.grey;
                          if (materia.toLowerCase().contains('escuela')) categoryColor = Colors.blueAccent;
                          else if (materia.toLowerCase().contains('trabajo')) categoryColor = Colors.orangeAccent;
                          else if (materia.toLowerCase().contains('pagos')) categoryColor = Colors.redAccent;
                          else if (materia.toLowerCase().contains('personal')) categoryColor = Colors.greenAccent;
                          else categoryColor = _gold;

                          String timeStr = '';
                          if (task['dueDate'] != null && task['dueDate'] is Timestamp) {
                            timeStr = DateFormat('h:mm a').format((task['dueDate'] as Timestamp).toDate());
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border(left: BorderSide(color: categoryColor, width: 4)),
                            ),
                            child: Row(
                              children: [
                                if (timeStr.isNotEmpty) ...[
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      timeStr,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  Container(width: 1, height: 40, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 10)),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        materia,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
