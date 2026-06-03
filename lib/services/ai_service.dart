import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class AIService {
  // ── API Key interna fija ──────────────────────────────────────────────────
  static const String _configAsset = 'assets/.stalky/runtime_config.json';
  static const String _signalField = 'STALKY_SIGNAL';
  static const List<String> _modelFallbacks = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-flash-latest',
  ];

  // ── Fallback Local para Base de Datos Offline (SharedPreferences) ─────────────────

  static Future<void> saveOfflineTask(
      String userId, Map<String, dynamic> task) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'offline_tasks_$userId';
      final currentList = prefs.getStringList(key) ?? [];
      currentList.add(jsonEncode(task));
      await prefs.setStringList(key, currentList);
      debugPrint(
          '[ASISTENTE_IA] [LOCAL_FALLBACK] Tarea guardada localmente con éxito en SharedPreferences.');
    } catch (e) {
      debugPrint(
          '[ASISTENTE_IA] [LOCAL_FALLBACK_ERROR] Error al guardar tarea localmente: $e');
    }
  }

  // ── Punto de entrada público ──────────────────────────────────────────────

  /// Analiza la imagen con Gemini y devuelve tareas detectadas para revision.
  /// Usa auto-fallback entre modelos si hay saturación o error temporal.
  Future<Map<String, dynamic>> processNotesImage({
    required Uint8List imageBytes,
    required String userId,
  }) async {
    final geminiResponse = await _callGemini(
      contents: [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'Analiza la imagen de una pizarra, libreta o apunte. Detecta tareas, actividades o proyectos pendientes. Devuelve SOLO JSON valido con esta forma: {"tasksDetected":[{"title":"...","materia":"Escuela|Trabajo|Pagos|Personal|General"}],"logs":["..."]}. Si no hay tareas, usa tasksDetected vacio y explica brevemente en logs.'
            },
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Encode(imageBytes),
              }
            },
          ],
        }
      ],
    );
    final parsed = jsonDecode(_extractJsonObject(_geminiText(geminiResponse)))
        as Map<String, dynamic>;

    return {
      'success': true,
      'textResponse': '',
      'tasksDetected': List<Map<String, dynamic>>.from(
        (parsed['tasksDetected'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      'logs': List<String>.from(parsed['logs'] as List? ?? const []),
    };
  }

  Future<Map<String, dynamic>> saveDetectedTask({
    required String userId,
    required String title,
    required String materia,
    required String note,
    required DateTime dueDate,
  }) async {
    try {
      return await _saveTaskToDB(
        userId: userId,
        descripcion: title,
        materia: materia,
        note: note,
        dueDate: dueDate,
      );
    } catch (dbError) {
      debugPrint(
          '[ASISTENTE_IA] [FIRESTORE_ERROR] Error al guardar tarea en Firestore: $dbError');

      final localId =
          'local_task_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}';
      final localTask = {
        'id': localId,
        'title': title,
        'materia': _classifyCategory(materia),
        'description': note.isNotEmpty
            ? note
            : 'Generado por el Asistente IA a partir de apuntes (Local Fallback).',
        'priority': 'media',
        'dueDate': dueDate.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'completed': false,
        'reminderLevel': ReminderLevel.normal.firestoreValue,
        'subtasks': [],
        'isOffline': true,
      };

      await saveOfflineTask(userId, localTask);
      try {
        if (dueDate.isAfter(DateTime.now())) {
          await NotificationService().scheduleTaskReminders(
            userId: userId,
            taskId: localId,
            title: title,
            dueDate: dueDate,
            level: ReminderLevel.normal,
          );
        }
      } catch (_) {}

      return {
        'id': localId,
        'title': title,
        'materia': localTask['materia'],
        'dueDate': dueDate,
        'isOffline': true,
      };
    }
  }

  Future<Map<String, dynamic>> processVoiceReminder({
    required String transcript,
    required String userId,
  }) async {
    final parsed = await _parseVoiceReminder(transcript);
    final dueDate = parsed['dueDate'] as DateTime?;

    if (dueDate == null) {
      throw Exception(
        'No detecte fecha y hora claras. Di algo como: "recuérdame entregar matemáticas mañana a las 6 pm".',
      );
    }

    if (!dueDate.isAfter(DateTime.now())) {
      throw Exception('La fecha y hora detectadas estan en el pasado.');
    }

    return saveDetectedTask(
      userId: userId,
      title: parsed['title']?.toString() ?? transcript,
      materia: parsed['materia']?.toString() ?? 'General',
      note: parsed['note']?.toString() ?? 'Creado por dictado con IA.',
      dueDate: dueDate,
    );
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<String> _loadSignal() async {
    final raw = await rootBundle.loadString(_configAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final signal = decoded[_signalField]?.toString().trim() ?? '';
    if (signal.isEmpty) {
      throw Exception(
          'Falta configuracion local de IA. Revisa $_configAsset y el campo $_signalField.');
    }
    return signal;
  }

  Future<Map<String, dynamic>> _callGemini({
    required List<Map<String, dynamic>> contents,
  }) async {
    final signal = await _loadSignal();
    String? lastError;

    for (final modelName in _modelFallbacks) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$signal',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': contents}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      lastError = '${response.statusCode}: ${response.body}';
      if (![403, 429, 503].contains(response.statusCode)) {
        break;
      }
    }

    throw Exception('No se pudo llamar a IA: $lastError');
  }

  String _geminiText(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    final content = candidates?.isNotEmpty == true
        ? (candidates!.first as Map<String, dynamic>)['content'] as Map?
        : null;
    final parts = content?['parts'] as List? ?? const [];
    return parts
        .map((part) => (part as Map)['text']?.toString() ?? '')
        .join()
        .trim();
  }

  String _extractJsonObject(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return cleaned.substring(start, end + 1);
    }
    return cleaned;
  }

  Future<Map<String, dynamic>> _parseVoiceReminder(String transcript) async {
    final now = DateTime.now();
    final geminiResponse = await _callGemini(
      contents: [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'Fecha y hora actual local: ${now.toIso8601String()}.\nDictado: "$transcript"\n\nDevuelve SOLO JSON valido con: title, materia, note, dueDateIso. materia debe ser Escuela, Trabajo, Pagos, Personal o General. Si falta fecha u hora clara, dueDateIso debe ser null. Resuelve fechas relativas usando la fecha actual.'
            }
          ],
        }
      ],
    );
    final decoded = jsonDecode(_extractJsonObject(_geminiText(geminiResponse)))
        as Map<String, dynamic>;
    final dueDateText = decoded['dueDateIso']?.toString();
    final dueDate = dueDateText == null || dueDateText.trim().isEmpty
        ? null
        : DateTime.tryParse(dueDateText);

    return {
      'title': decoded['title']?.toString().trim().isNotEmpty == true
          ? decoded['title'].toString().trim()
          : transcript.trim(),
      'materia': decoded['materia']?.toString() ?? 'General',
      'note': decoded['note']?.toString() ?? 'Creado por dictado con IA.',
      'dueDate': dueDate,
    };
  }

  Future<Map<String, dynamic>> _saveTaskToDB({
    required String userId,
    required String descripcion,
    required String materia,
    required String note,
    required DateTime dueDate,
  }) async {
    final String category = _classifyCategory(materia);
    final String description = note.isNotEmpty
        ? note
        : 'Generado por el Asistente IA a partir de apuntes.';

    debugPrint(
        '[ASISTENTE_IA] [FIRESTORE_WRITE] Intentando guardar tarea: "$descripcion" para usuario: $userId');

    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .add({
      'title': descripcion,
      'materia': category,
      'description': description,
      'priority': 'media',
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.now(),
      'completed': false,
      'reminderLevel': ReminderLevel.normal.firestoreValue,
      'subtasks': [],
    });

    debugPrint(
        '[ASISTENTE_IA] [FIRESTORE_WRITE] Tarea guardada con éxito en Firestore. ID: ${docRef.id}');

    // Programar notificación local
    try {
      if (dueDate.isAfter(DateTime.now())) {
        await NotificationService().scheduleTaskReminders(
          userId: userId,
          taskId: docRef.id,
          title: descripcion,
          dueDate: dueDate,
          level: ReminderLevel.normal,
        );
      }
    } catch (_) {}

    return {
      'id': docRef.id,
      'title': descripcion,
      'materia': category,
      'dueDate': dueDate
    };
  }

  String _classifyCategory(String materia) {
    final m = materia.trim().toLowerCase();
    if (m.contains('trabajo') ||
        m.contains('oficina') ||
        m.contains('laboral')) {
      return 'Trabajo';
    }
    if (m.contains('pago') || m.contains('tarjeta') || m.contains('dinero')) {
      return 'Pagos';
    }
    if (m.contains('personal') || m.contains('casa') || m.contains('salud')) {
      return 'Personal';
    }
    return 'Escuela'; // Default para materias académicas
  }
}
