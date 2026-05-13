# STAKLY 🗂️

Gestor de tareas premium en tiempo real con Firebase Firestore y PWA. Portado desde Flutter para soporte web total (iOS/Android/Desktop).

## 🚀 Despliegue (Deploy)

Si quieres subir los cambios a la web:
1. Asegúrate de tener instalado [Node.js](https://nodejs.org/).
2. Ejecuta el script **`deploy.bat`** o usa los comandos:

```powershell
# Desplegar hosting y reglas de seguridad
npx firebase deploy --project to-do-taskingcheck
```

## 📱 PWA (iOS / Android)

Para instalar STAKLY en tu móvil como una app nativa:
- **iOS (Safari):** Toca el botón de "Compartir" (cuadrado con flecha) y selecciona **"Añadir a pantalla de inicio"**.
- **Android (Chrome):** Toca los tres puntos y selecciona **"Instalar aplicación"**.

## 📁 Estructura
```
stalkyWeb/
├── index.html       # Estructura PWA
├── style.css        # Diseño Black & Gold Premium
├── app.js           # Lógica (Auth, Firestore, Pomodoro, Stats)
├── sw.js            # Service Worker para modo offline
├── manifest.json    # Configuración de App PWA
├── assets/logo/     # Iconos de la aplicación
└── firestore.rules  # Seguridad por usuario
```

## ⚙️ Características Portadas
- ✅ **Firebase Auth:** Login, Registro y Verificación de email.
- ✅ **Agenda:** Vista por días con filtrado en tiempo real.
- ✅ **Estadísticas:** Anillo de progreso, totales y distribución por categorías.
- ✅ **Pomodoro:** Temporizador de concentración con ciclos de descanso.
- ✅ **Premium UI:** Tema oscuro con acentos dorados idéntico al original.
