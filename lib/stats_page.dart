import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color bg = const Color(0xFF000000);
    final Color gold = const Color(0xFFD4AF37);
    final Color cardBg = const Color(0xFF1E1E1E);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: Text('No autenticado', style: TextStyle(color: gold))),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Estadísticas',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/logo/icon.png',
            errorBuilder: (_, __, ___) => Icon(Icons.star, color: gold),
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
            return Center(child: CircularProgressIndicator(color: gold));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          final docs = snapshot.data?.docs ?? [];
          final int total = docs.length;

          // Completed / pending counts
          final int completed = docs.where((d) => (d.data() as Map<String, dynamic>)['completed'] == true).length;
          final int pending = total - completed;

          // Score: ratio of completed tasks (0–100)
          final double score = total == 0 ? 0 : (completed / total);
          final int scoreInt = (score * 100).round();

          // Label based on score
          String scoreLabel;
          if (scoreInt >= 80) {
            scoreLabel = 'Excelente';
          } else if (scoreInt >= 60) {
            scoreLabel = 'Bien';
          } else if (scoreInt >= 40) {
            scoreLabel = 'Regular';
          } else if (scoreInt > 0) {
            scoreLabel = 'En progreso';
          } else {
            scoreLabel = 'Sin completar';
          }

          // Category distribution (all tasks)
          final Map<String, int> catTotal = {};
          final Map<String, int> catDone = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final cat = (data['materia'] ?? 'General') as String;
            final done = data['completed'] == true;
            catTotal[cat] = (catTotal[cat] ?? 0) + 1;
            if (done) catDone[cat] = (catDone[cat] ?? 0) + 1;
          }

          // Sort categories by count descending, take top 5
          final sortedCats = catTotal.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topCats = sortedCats.take(5).toList();

          // Today's tasks
          final now = DateTime.now();
          final todayDocs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            if (data['dueDate'] is Timestamp) {
              final date = (data['dueDate'] as Timestamp).toDate();
              return date.year == now.year && date.month == now.month && date.day == now.day;
            }
            return false;
          }).toList();
          final int todayTotal = todayDocs.length;
          final int todayDone = todayDocs.where((d) => (d.data() as Map<String, dynamic>)['completed'] == true).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Circular Score ──────────────────────────────
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: score,
                          strokeWidth: 14,
                          backgroundColor: cardBg,
                          color: gold,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$scoreInt',
                            style: TextStyle(color: gold, fontSize: 64, fontWeight: FontWeight.bold, height: 1.0),
                          ),
                          const Text('/100', style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text(scoreLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Summary Row ─────────────────────────────────
                Row(
                  children: [
                    Expanded(child: _StatCard(label: 'Total', value: '$total', gold: gold, cardBg: cardBg)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'Completadas', value: '$completed', gold: gold, cardBg: cardBg, highlight: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'Pendientes', value: '$pending', gold: gold, cardBg: cardBg)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Today's Progress ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tareas de Hoy', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          Text('$todayDone / $todayTotal', style: TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: todayTotal == 0 ? 0 : todayDone / todayTotal,
                          minHeight: 12,
                          backgroundColor: Colors.black,
                          color: gold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        todayTotal == 0
                            ? 'No hay tareas para hoy'
                            : todayDone == todayTotal
                                ? '✅ ¡Todas las tareas de hoy completadas!'
                                : '${todayTotal - todayDone} tarea(s) pendiente(s) para hoy',
                        style: TextStyle(
                          color: todayDone == todayTotal && todayTotal > 0 ? Colors.greenAccent : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Category Distribution ────────────────────────
                if (topCats.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Distribución por Categoría',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 20),
                        ...topCats.map((entry) {
                          final cat = entry.key;
                          final count = entry.value;
                          final ratio = total == 0 ? 0.0 : count / total;
                          final doneCount = catDone[cat] ?? 0;
                          final color = _catColor(cat, gold);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(cat,
                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    Text('$doneCount/$count',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 8,
                                    backgroundColor: Colors.black,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Color _catColor(String cat, Color gold) {
    final lower = cat.toLowerCase();
    if (lower.contains('escuela')) return Colors.blueAccent;
    if (lower.contains('trabajo')) return Colors.orangeAccent;
    if (lower.contains('pagos')) return Colors.redAccent;
    if (lower.contains('personal')) return Colors.greenAccent;
    return gold;
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color gold;
  final Color cardBg;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.value,
    required this.gold,
    required this.cardBg,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: highlight ? gold.withValues(alpha: 0.12) : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: highlight ? Border.all(color: gold.withValues(alpha: 0.5), width: 1.5) : null,
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: highlight ? gold : Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
