# Mi jardín — Flutter

App Android conectada directamente a Supabase. Resumen con mascota 3D local, últimas 60 lecturas y alertas del estado actual.

## Instalar

APK compilado: `dist/mi-jardin-1.1.0.apk` en la copia local del proyecto.
El teléfono necesita Internet; no necesita estar en la red de la laptop.

## Clonar y ejecutar

Requiere Flutter estable compatible con Dart 3.13.5, Android SDK y JDK 21.

```powershell
git clone https://github.com/Jonathan03R/jardin-inteligente-flutter.git
cd jardin-inteligente-flutter
Copy-Item .env.example .env
# Completa SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY en .env.
flutter pub get
flutter run
```

`.env` contiene únicamente URL HTTPS y clave `sb_publishable_...`. Estos valores se incluyen en el APK por diseño.
No pongas contraseñas PostgreSQL, claves secretas ni `service_role` en esta app.

## APK release

Primera compilación, crear firma propia:

```powershell
pwsh -File .\preparar-firma.ps1
flutter build apk --release
```

Resultado: `build/app/outputs/flutter-apk/app-release.apk`.
Conserva copia privada de `android/jardin-release.jks` y `android/key.properties`.
Para actualizar instalaciones existentes desde otra PC, copia esos mismos archivos; no generes otra firma.
Si falta la firma, la compilación release falla en vez de firmarse silenciosamente con una clave de depuración.

## Flujo

1. Resuelve `garden-01` en `public.jardin_dispositivos`.
2. Lee `public.jardin_lecturas`, ordenada por recepción, y escucha `jardin.lecturas` por Realtime.
3. Mezcla eventos y consulta inicial por ID; una respuesta antigua no reemplaza un evento reciente.
4. Reconsulta al reconectar o regresar a primer plano. Conserva la mascota al cambiar pestaña.

No hay sondeo cada 5 segundos, backend local ni MQTT en el teléfono.
Con app cerrada no se reciben notificaciones push; al abrir recupera el estado.
La fecha antigua sigue visible como antigua, aunque el teléfono tenga conexión.

## Seguridad y configuración Supabase

Lectura pública limitada por RLS a `garden-01`; escritura bloqueada para app.
El acceso sin login es para este jardín de demostración. No representa datos privados por usuario.
Necesita las vistas `jardin_dispositivos`, `jardin_lecturas` y la publicación Realtime de `jardin.lecturas` del proyecto completo.
El SQL administrativo se mantiene en el proyecto Go, fuera de este repositorio.

## Código

- `lib/features/garden/garden_repository.dart`: consulta inicial, eventos y reconexión.
- `lib/features/garden/reading.dart`: contrato de lectura.
- `lib/features/garden/garden_page.dart`: ciclo de vida y pantalla.
- `lib/features/mascot/`: animación; GLB incluido en `assets/mascot/`.

Diagnóstico: `flutter analyze`. La prueba en teléfono requiere dispositivo conectado o instalación manual del APK.
