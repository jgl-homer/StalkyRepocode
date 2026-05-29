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
              description: 'El título o descripción breve de la tarea detectada.',
            ),
            'fecha_limite': Schema(
              SchemaType.string,
              description: 'La fecha límite de entrega, preferiblemente en formato AAAA-MM-DD.',
            ),
            'materia': Schema(
              SchemaType.string,
              description: 'La categoría o materia relacionada (Escuela, Trabajo, Pagos, Personal o General).',
            ),
          },
          requiredProperties: ['descripcion'],
        ),
      ),

      // Herramienta 2: Guardar flashcards
      FunctionDeclaration(
        'guardar_flashcards_db',
        'Almacena flashcards de estudio generadas a partir del contenido de la imagen.',
        Schema(
          SchemaType.object,
          properties: {
            'materia': Schema(
              SchemaType.string,
              description: 'La materia o tema de estudio para clasificar este set de flashcards.',
            ),
            'flashcards': Schema(
              SchemaType.array,
              description: 'Lista de flashcards generadas.',
              items: Schema(
                SchemaType.object,
                properties: {
                  'pregunta': Schema(
                    SchemaType.string,
                    description: 'Pregunta o concepto clave para el frente de la tarjeta.',
                  ),
                  'respuesta': Schema(
                    SchemaType.string,
                    description: 'Respuesta, explicación o definición para el reverso de la tarjeta.',
                  ),
                },
                requiredProperties: ['pregunta', 'respuesta'],
              ),
            ),
          },
          requiredProperties: ['flashcards'],
        ),
      ),
    ]),
  ];
}
