@echo off
echo ============================================
echo   STAKLY — Deploy a Firebase Hosting
echo ============================================
echo.

REM Verificar que firebase-tools esté disponible
npx firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Firebase CLI no encontrado. Instala con: npm install -g firebase-tools
    pause
    exit /b 1
)

echo [1/3] Iniciando sesion en Firebase...
npx firebase login

echo.
echo [2/3] Desplegando Firestore rules y Hosting...
npx firebase deploy --project to-do-taskingcheck

echo.
echo ============================================
echo  DEPLOY COMPLETADO
echo  Tu app esta en: https://to-do-taskingcheck.web.app
echo ============================================
echo.
pause
|