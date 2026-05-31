import 'package:google_generative_ai/google_generative_ai.dart';

/// Registra las herramientas para Gemini de acuerdo con la guía de integración.
List<Tool> obtenerToolsParaGemini() {
  return [
    Tool(functionDeclarations: [
      // Herramienta 1: Guardar tarea
      FunctionDeclaration(
        'guardar_tarea_db',
        'Persiste una tarea detectada en la imagen de apuntes o pizarrones.',
        Schema(
          SchemaType.object,
          properties: {
            'descripcion': Schema(
              SchemaType.string,
              description:
                  'El título o descripción breve de la tarea detectada.',
            ),
            'fecha_limite': Schema(
              SchemaType.string,
              description:
                  'La fecha límite de entrega, preferiblemente en formato AAAA-MM-DD.',
            ),
            'materia': Schema(
              SchemaType.string,
              description:
                  'La categoría o materia relacionada (Escuela, Trabajo, Pagos, Personal o General).',
            ),
          },
          requiredProperties: ['descripcion'],
        ),
      ),
    ]),
  ];
}
