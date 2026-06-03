// Archivo: functions/index.js (CÓDIGO COMPLETO)

// 1. 🚀 NUEVAS IMPORTACIONES REQUERIDAS
const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require('firebase-admin'); // Importar el SDK de Admin
const { onSchedule } = require("firebase-functions/v2/scheduler"); // Importar el trigger de programador (scheduler)

// Inicializa el SDK de Admin. Esto da acceso a Firestore, Auth y Messaging.
admin.initializeApp();

// Para cost control, puedes establecer opciones globales.
setGlobalOptions({ maxInstances: 10 });

const geminiApiKey = defineSecret("GEMINI_API_KEY");

async function verifyFirebaseUser(request) {
    const header = request.get("authorization") || "";
    const match = header.match(/^Bearer (.+)$/);
    if (!match) {
        throw new Error("missing-auth-token");
    }
    return admin.auth().verifyIdToken(match[1]);
}

function sendCors(response) {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
}

async function callGemini({ apiKey, body }) {
    const models = [
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "gemini-2.0-flash",
        "gemini-flash-latest",
    ];
    let lastError = "";

    for (const model of models) {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
        const geminiResponse = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body),
        });
        const text = await geminiResponse.text();

        if (geminiResponse.ok) {
            return JSON.parse(text);
        }

        lastError = `${geminiResponse.status}: ${text}`;
        if (![403, 429, 503].includes(geminiResponse.status)) {
            break;
        }
    }

    throw new Error(lastError || "Gemini request failed");
}

function extractJsonObject(text) {
    const cleaned = String(text || "")
        .replace(/^```json\s*/gm, "")
        .replace(/^```\s*/gm, "")
        .replace(/\s*```$/gm, "")
        .trim();
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start >= 0 && end > start) {
        return cleaned.slice(start, end + 1);
    }
    return cleaned;
}

function geminiText(response) {
    return response?.candidates?.[0]?.content?.parts
        ?.map((part) => part.text || "")
        .join("")
        .trim() || "";
}

exports.analyzeNotesWithGemini = onRequest({ secrets: [geminiApiKey] }, async (request, response) => {
    sendCors(response);
    if (request.method === "OPTIONS") {
        response.status(204).send("");
        return;
    }
    if (request.method !== "POST") {
        response.status(405).json({ error: "method-not-allowed" });
        return;
    }

    try {
        await verifyFirebaseUser(request);
        const imageBase64 = request.body?.imageBase64;
        if (!imageBase64 || typeof imageBase64 !== "string") {
            response.status(400).json({ error: "missing-image" });
            return;
        }

        const geminiResponse = await callGemini({
            apiKey: geminiApiKey.value(),
            body: {
                contents: [{
                    role: "user",
                    parts: [
                        {
                            text:
                                "Analiza la imagen de una pizarra, libreta o apunte. " +
                                "Detecta tareas, actividades o proyectos pendientes. " +
                                "Devuelve SOLO JSON valido con esta forma: " +
                                "{\"tasksDetected\":[{\"title\":\"...\",\"materia\":\"Escuela|Trabajo|Pagos|Personal|General\"}],\"logs\":[\"...\"]}. " +
                                "Si no hay tareas, usa tasksDetected vacio y explica brevemente en logs.",
                        },
                        {
                            inline_data: {
                                mime_type: request.body?.mimeType || "image/jpeg",
                                data: imageBase64,
                            },
                        },
                    ],
                }],
            },
        });

        const parsed = JSON.parse(extractJsonObject(geminiText(geminiResponse)));
        response.json({
            success: true,
            textResponse: "",
            tasksDetected: Array.isArray(parsed.tasksDetected) ? parsed.tasksDetected : [],
            logs: Array.isArray(parsed.logs) ? parsed.logs : [],
        });
    } catch (error) {
        console.error("analyzeNotesWithGemini failed", error);
        response.status(500).json({ error: "gemini-analysis-failed" });
    }
});

exports.parseVoiceReminderWithGemini = onRequest({ secrets: [geminiApiKey] }, async (request, response) => {
    sendCors(response);
    if (request.method === "OPTIONS") {
        response.status(204).send("");
        return;
    }
    if (request.method !== "POST") {
        response.status(405).json({ error: "method-not-allowed" });
        return;
    }

    try {
        await verifyFirebaseUser(request);
        const transcript = String(request.body?.transcript || "").trim();
        const nowIso = String(request.body?.nowIso || new Date().toISOString());
        if (!transcript) {
            response.status(400).json({ error: "missing-transcript" });
            return;
        }

        const geminiResponse = await callGemini({
            apiKey: geminiApiKey.value(),
            body: {
                contents: [{
                    role: "user",
                    parts: [{
                        text:
                            `Fecha y hora actual local: ${nowIso}.\n` +
                            `Dictado: "${transcript}"\n\n` +
                            "Devuelve SOLO JSON valido con: title, materia, note, dueDateIso. " +
                            "materia debe ser Escuela, Trabajo, Pagos, Personal o General. " +
                            "Si falta fecha u hora clara, dueDateIso debe ser null. " +
                            "Resuelve fechas relativas usando la fecha actual.",
                    }],
                }],
            },
        });

        response.json(JSON.parse(extractJsonObject(geminiText(geminiResponse))));
    } catch (error) {
        console.error("parseVoiceReminderWithGemini failed", error);
        response.status(500).json({ error: "gemini-voice-parse-failed" });
    }
});

/**
 * 🔔 FUNCIÓN CLOUD: scheduleTaskReminders
 * Se ejecuta cada 5 minutos para revisar tareas próximas a vencer y enviar notificaciones Push (FCM).
 *
 * Utiliza la API V2: onSchedule().
 */
exports.scheduleTaskReminders = onSchedule('every 5 minutes', async (context) => {
    const firestore = admin.firestore();
    const messaging = admin.messaging();

    // El contexto de esta función de Node.js es la zona horaria del servidor (UTC)
    const now = admin.firestore.Timestamp.now();

    // Definimos un rango: Tareas que vencen en la próxima hora (60 minutos)
    const oneHourFromNow = new Date(now.toDate().getTime() + 60 * 60 * 1000);

    console.log('Iniciando revisión de tareas. Límite de vencimiento:', oneHourFromNow.toISOString());

    // 1. CONSULTA: Buscar tareas no completadas que vencen pronto
    // Requiere un índice compuesto en Firestore si falla.
    const snapshot = await firestore.collectionGroup('tasks')
        .where('completed', '==', false)
        .where('dueDate', '<=', admin.firestore.Timestamp.fromDate(oneHourFromNow))
        .get();

    if (snapshot.empty) {
        return console.log('No hay tareas próximas a vencer en la siguiente hora.');
    }

    const tokensToNotify = {};

    // 2. PROCESAR: Obtener el token de FCM de cada usuario con una tarea
    for (const doc of snapshot.docs) {
        const task = doc.data();
        // El userId es el ID de la colección 'users'
        const userId = doc.ref.parent.parent.id;

        const userDoc = await firestore.collection('users').doc(userId).get();
        const fcmToken = userDoc.data()?.fcmToken; // Lee el token guardado por Flutter

        if (fcmToken) {
            // Agrupamos tareas por el token del dispositivo
            if (!tokensToNotify[fcmToken]) {
                tokensToNotify[fcmToken] = [];
            }
            tokensToNotify[fcmToken].push(task.title);
        }
    }

    // 3. ENVÍO: Mandar la notificación push
    const messagePromises = Object.keys(tokensToNotify).map(fcmToken => {
        const numTasks = tokensToNotify[fcmToken].length;
        const bodyMessage = numTasks === 1
            ? `Tu tarea "${tokensToNotify[fcmToken][0]}" está próxima a vencer.`
            : `Tienes ${numTasks} tareas próximas a vencer, incluyendo "${tokensToNotify[fcmToken][0]}".`;

        const message = {
            notification: {
                title: '🚨 Recordatorio de Tarea',
                body: bodyMessage,
            },
            token: fcmToken,
        };
        // Usa el SDK de Messaging para enviar
        return messaging.send(message);
    });

    await Promise.all(messagePromises);
    console.log(`Notificaciones enviadas a ${Object.keys(tokensToNotify).length} dispositivos.`);
    return null;
});

// Puedes dejar comentadas las funciones de ejemplo como 'helloWorld' si quieres
// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
