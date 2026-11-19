# Jardín inteligente

Una pequeña huerta que se comunica: sensores en el jardín, una mascota que
reacciona a sus lecturas y una app Android conectada en tiempo real.

Este repositorio contiene la aplicación Flutter. El firmware ESP32 y el
servicio Go tienen repositorios independientes.

## Qué encontrarás

- Panel de estado, historial y alertas del jardín.
- Mascota 3D interactiva, con modelo y recursos incluidos.
- Lecturas recientes y actualizaciones en vivo mediante Supabase Realtime.
- Reconexión y recuperación de datos al volver a abrir la aplicación.

## Requisitos

- Flutter estable compatible con Dart 3.13.5.
- Android SDK y JDK 21.
- Proyecto Supabase configurado con las vistas y publicación Realtime descritas
  en la documentación del backend.

## Ejecutar en Android

```powershell
Copy-Item .env.example .env
# Completa SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY en .env.
flutter pub get
flutter run
```

La app usa únicamente la clave publicable de Supabase. Nunca pongas claves
secretas, `service_role` ni contraseñas de base de datos en Flutter.

## Compilar APK

```powershell
pwsh -File .\preparar-firma.ps1
flutter build apk --release
```

La firma privada y `android/key.properties` se mantienen fuera de Git. Conserva
una copia segura: se necesita la misma firma para actualizar una instalación.

## Datos y privacidad

La aplicación accede al jardín de demostración `garden-01`, con lectura pública
limitada por las políticas RLS del proyecto. No hay inicio de sesión ni
notificaciones push. Al recuperar conexión o volver a primer plano, la app
actualiza su estado desde Supabase.

## Estructura

- `lib/features/garden/`: panel, historial, alertas y acceso a datos.
- `lib/features/mascot/`: comportamiento y presentación de la mascota.
- `assets/mascot/`: modelo 3D y recursos visuales locales.
- `tools/mascot/`: herramientas para generar el modelo.

## Proyecto universitario

Prototipo académico de Internet de las cosas. Consulta los repositorios
relacionados para ver el firmware y el servicio que conectan los sensores con
esta app.

## Licencia

Licencia MIT. Consulta [LICENSE](LICENSE). El modelo 3D y otros recursos de
terceros pueden tener condiciones propias; revisa sus avisos antes de
redistribuirlos.
