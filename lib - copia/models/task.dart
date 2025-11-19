import 'package:cloud_firestore/cloud_firestore.dart';
enum Priority { baja, media, alta }

class Task {
  final String id;
  final String title;
  final String userId;
  final DateTime dueDate;
  final Priority priority;

  Task({
    required this.id,
    required this.title,
    required this.userId,
    required this.dueDate,
    required this.priority,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'userId': userId,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
