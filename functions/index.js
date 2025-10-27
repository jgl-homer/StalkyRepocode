// Archivo: functions/index.js (CÓDIGO COMPLETO)

// 1. 🚀 NUEVAS IMPORTACIONES REQUERIDAS
const { setGlobalOptions } = require("firebase-functions");
const admin = require('firebase-admin'); // Importar el SDK de Admin
const { onSchedule } = require("firebase-functions/v2/scheduler"); // Importar el trigger de programador (scheduler)

// Inicializa el SDK de Admin. Esto da acceso a Firestore, Auth y Messaging.
admin.initializeApp();

// Para cost control, puedes establecer opciones globales.
setGlobalOptions({ maxInstances: 10 });

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