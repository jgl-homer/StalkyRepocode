import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tools_registry.dart';
import 'notification_service.dart';

class AIService {
  // ── API Key interna fija ──────────────────────────────────────────────────
  static const String _apiKeyFromEnv = String.fromEnvironment('GEMINI_API_KEY');

  // Modelos en orden de preferencia
  static const List<String> _modelFallbacks = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-flash-latest',
  ];

  // ── Instrucción de sistema ────────────────────────────────────────────────
  static Content get _systemInstruction => Content.system(
        'Eres un asistente educativo para preparatoria. '
        'Cuando recibas la foto de un apunte o pizarrón: '
        'si detectas una tarea pendiente, llama a `guardar_tarea_db`. '
        'Ignora cualquier material que no sea una tarea.',
      );

  // ── Fallback Local para Base de Datos Offline (SharedPreferences) ─────────────────

  static Future<void> saveOfflineTask(
      String userId, Map<String, dynamic> task) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'offline_tasks_$userId';
      final currentList = prefs.getStringList(key) ?? [];
      currentList.add(jsonEncode(task));
      await prefs.setStringList(key, currentList);
      print(
          '[ASISTENTE_IA] [LOCAL_FALLBACK] Tarea guardada localmente con éxito en SharedPreferences.');
    } catch (e) {
      print(
          '[ASISTENTE_IA] [LOCAL_FALLBACK_ERROR] Error al guardar tarea localmente: $e');
    }
  }

  // ── Punto de entrada público ──────────────────────────────────────────────

  /// Analiza la imagen con Gemini y persiste los resultados en Firestore.
  /// Usa auto-fallback entre modelos si hay saturación o error temporal.
  Future<Map<String, dynamic>> processNotesImage({
    required Uint8List imageBytes,
    required String userId,
  }) async {
    print(
        '[ASISTENTE_IA] [INICIO] Procesando apunte. Imagen recibida: ${imageBytes.length} bytes.');

    // Garantizar que hay un usuario autenticado (puede ser anónimo)
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print(
          '[ASISTENTE_IA] [AUTH] No hay usuario activo. Intentando login anónimo...');
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        currentUser = cred.user;
        print(
            '[ASISTENTE_IA] [AUTH] Login anónimo exitoso. Nuevo UID: ${currentUser?.uid}');
      } catch (authError) {
        print(
            '[ASISTENTE_IA] [AUTH ERROR] Error en inicio de sesión anónimo: $authError');
      }
    } else {
      print(
          '[ASISTENTE_IA] [AUTH] Usuario activo detectado. UID: ${currentUser.uid}, Anónimo: ${currentUser.isAnonymous}');
    }

    final activeUid = currentUser?.uid ?? userId;
    print('[ASISTENTE_IA] [AUTH] UID activo para operaciones: $activeUid');

    final content = _buildContent(imageBytes);
    final apiKey = await _loadApiKey();
    GenerateContentResponse? response;
    String? lastError;
    var sawAccessDenied = false;
    var sawQuotaError = false;

    // Intentar cada modelo en cascada
    for (final modelName in _modelFallbacks) {
      print(
          '[ASISTENTE_IA] [GEMINI_LLAMADA] Enviando apunte a Gemini usando modelo: $modelName');
      final stopwatch = Stopwatch()..start();
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          tools: obtenerToolsParaGemini(),
          systemInstruction: _systemInstruction,
        );
        response = await model.generateContent(content);
        stopwatch.stop();
        print(
            '[ASISTENTE_IA] [GEMINI_LLAMADA] Respuesta recibida de Gemini en ${stopwatch.elapsedMilliseconds} ms.');
        break; // éxito
      } catch (e) {
        stopwatch.stop();
        lastError = e.toString();
        print(
            '[ASISTENTE_IA] [GEMINI_ERROR] Error al llamar modelo $modelName en ${stopwatch.elapsedMilliseconds} ms: $e');
        final s = lastError.toLowerCase();
        sawAccessDenied =
            sawAccessDenied || s.contains('403') || s.contains('denied access');
        sawQuotaError =
            sawQuotaError || s.contains('429') || s.contains('quota');
        // Solo reintenta con siguiente modelo en errores de disponibilidad/cuota
        if (s.contains('503') ||
            s.contains('unavailable') ||
            s.contains('demand') ||
            s.contains('429') ||
            s.contains('quota') ||
            s.contains('exhausted') ||
            s.contains('403') ||
            s.contains('denied access')) {
          print(
              '[ASISTENTE_IA] [GEMINI_REINTENTO] El modelo $modelName está saturado/sin cuota, reintentando con el siguiente de la lista.');
          continue;
        }
        rethrow; // Error definitivo (403, 400, etc.)
      }
    }

    if (response == null) {
      if (sawAccessDenied) {
        throw Exception(
          'El proyecto de Google AI no tiene acceso para generar contenido con Gemini. '
          'Crea una API key nueva en otro proyecto o revisa acceso, facturación y límites. '
          'Último error: $lastError',
        );
      }

      if (sawQuotaError) {
        throw Exception(
          'La API key de Gemini no tiene cuota disponible en este momento. '
          'Revisa los límites/cuota del proyecto o prueba con una API key nueva. '
          'Último error: $lastError',
        );
      }

      throw Exception(
        'No se pudo obtener respuesta de Gemini con ningún modelo. '
        'Último error: $lastError',
      );
    }

    return _processResponse(response, activeUid);
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<String> _loadApiKey() async {
    if (_apiKeyFromEnv.trim().isNotEmpty) {
      return _apiKeyFromEnv.trim();
    }

    try {
      final rawSecrets = await rootBundle.loadString('secrets.json');
      final decoded = jsonDecode(rawSecrets) as Map<String, dynamic>;
      final apiKey = decoded['GEMINI_API_KEY']?.toString().trim() ?? '';

      if (apiKey.isNotEmpty) {
        return apiKey;
      }
    } catch (e) {
      print('[ASISTENTE_IA] [API_KEY_ERROR] No se pudo leer secrets.json: $e');
    }

    throw Exception(
      'Falta GEMINI_API_KEY. Define la clave con --dart-define=GEMINI_API_KEY=... '
      'o crea secrets.json con esa propiedad.',
    );
  }

  List<Content> _buildContent(Uint8List imageBytes) {
    return [
      Content.multi([
        DataPart('image/jpeg', imageBytes),
        TextPart(
          'Analiza con detalle la imagen de esta pizarra, libreta o apunte. '
          'Identifica cualquier tarea, asignación o proyecto pendiente. '
          'Llama a la herramienta `guardar_tarea_db` si encuentras una tarea. '
          'Ignora cualquier material que no sea una tarea.',
        ),
      ]),
    ];
  }

  Future<Map<String, dynamic>> _processResponse(
    GenerateContentResponse response,
    String userId,
  ) async {
    final List<Map<String, dynamic>> tasksSaved = [];
    final List<String> logs = [];

    print(
        '[ASISTENTE_IA] [GEMINI_PARSE] Procesando calls a herramientas en la respuesta de Gemini. Total llamadas de función: ${response.functionCalls.length}');

    for (final call in response.functionCalls) {
      print(
          '[ASISTENTE_IA] [GEMINI_PARSE] Llamada detectada: ${call.name} con argumentos: ${call.args}');
      if (call.name == 'guardar_tarea_db') {
        final descripcion =
            call.args['descripcion']?.toString() ?? 'Nueva tarea';
        final fechaLimiteStr = call.args['fecha_limite']?.toString();
        final materia = call.args['materia']?.toString() ?? 'General';

        try {
          final taskData = await _saveTaskToDB(
            userId: userId,
            descripcion: descripcion,
            fechaLimiteStr: fechaLimiteStr,
            materia: materia,
          );
          tasksSaved.add(taskData);
          logs.add(
              '📝 Tarea guardada: "$descripcion" (${taskData['materia']})');
        } catch (dbError) {
          print(
              '[ASISTENTE_IA] [FIRESTORE_ERROR] Error al guardar tarea en Firestore: $dbError');

          // Crear objeto de fallback local
          final localId =
              'local_task_${DateTime.now().millisecondsSinceEpoch}_${descripcion.hashCode.abs()}';
          final DateTime dueDate = _parseDueDate(fechaLimiteStr);
          final localTask = {
            'id': localId,
            'title': descripcion,
            'materia': _classifyCategory(materia),
            'description':
                'Generado por el Asistente IA a partir de apuntes (Local Fallback).',
            'priority': 'media',
            'dueDate': dueDate.toIso8601String(),
            'createdAt': DateTime.now().toIso8601String(),
            'completed': false,
            'subtasks': [],
            'isOffline': true,
          };

          await saveOfflineTask(userId, localTask);

          final uiTaskData = {
            'id': localId,
            'title': descripcion,
            'materia': localTask['materia'],
            'dueDate': dueDate,
            'isOffline': true,
          };
          tasksSaved.add(uiTaskData);
          logs.add('⚠️ Tarea guardada localmente (Error en la nube: $dbError)');
        }
      }
    }

    final textResponse = response.text ?? '';
    if (tasksSaved.isEmpty && textResponse.isNotEmpty) {
      logs.add(
          'ℹ️ Gemini analizó la imagen pero no detectó una tarea explícita.');
    }

    return {
      'success': true,
      'textResponse': textResponse,
      'tasksSaved': tasksSaved,
      'logs': logs,
    };
  }

  Future<Map<String, dynamic>> _saveTaskToDB({
    required String userId,
    required String descripcion,
    required String? fechaLimiteStr,
    required String materia,
  }) async {
    final String category = _classifyCategory(materia);
    final DateTime dueDate = _parseDueDate(fechaLimiteStr);

    print(
        '[ASISTENTE_IA] [FIRESTORE_WRITE] Intentando guardar tarea: "$descripcion" para usuario: $userId');

    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .add({
      'title': descripcion,
      'materia': category,
      'description': 'Generado por el Asistente IA a partir de apuntes.',
      'priority': 'media',
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.now(),
      'completed': false,
      'subtasks': [],
    });

    print(
        '[ASISTENTE_IA] [FIRESTORE_WRITE] Tarea guardada con éxito en Firestore. ID: ${docRef.id}');

    // Programar notificación local
    try {
      if (dueDate.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          docRef.id.hashCode.abs() % 100000,
          'Recordatorio IA: $descripcion',
          'Tarea de $category detectada en tus apuntes.',
          dueDate,
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

  DateTime _parseDueDate(String? fechaLimiteStr) {
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));
    if (fechaLimiteStr != null && fechaLimiteStr.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(fechaLimiteStr);
      if (parsed != null) {
        dueDate = parsed.isBefore(DateTime.now())
            ? parsed.add(const Duration(days: 365))
            : parsed;
      }
    }
    if (dueDate.hour == 0 && dueDate.minute == 0) {
      dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day, 18, 0);
    }
    return dueDate;
  }

  String _classifyCategory(String materia) {
    final m = materia.trim().toLowerCase();
    if (m.contains('trabajo') || m.contains('oficina') || m.contains('laboral'))
      return 'Trabajo';
    if (m.contains('pago') || m.contains('tarjeta') || m.contains('dinero'))
      return 'Pagos';
    if (m.contains('personal') || m.contains('casa') || m.contains('salud'))
      return 'Personal';
    return 'Escuela'; // Default para materias académicas
  }
}
