# Connixia — Encuentros geolocalizados

## 🎯 Descripción del proyecto
Connixia es una aplicación móvil que facilita la creación y participación en eventos o reuniones geolocalizadas. Permite a los usuarios registrarse e iniciar sesión, proponer puntos de encuentro en un mapa (Google Maps), establecer horarios y confirmar asistencia. La app guía a cada participante con la ruta de navegación hasta el punto marcado y, al llegar, permite confirmar la llegada mediante el gesto de sacudir el dispositivo (shake), notificando automáticamente al creador del evento o al resto de asistentes.

El objetivo es promover nuevas amistades y la convivencia, facilitando que cualquier persona encuentre compañía para actividades cuando sus contactos habituales no estén disponibles.

## 🔐 Módulo de Administración
✨ **NUEVO**: La aplicación incluye un **módulo de administración completo** que permite supervisar y moderar la plataforma sin alterar el flujo de usuarios normales.

### Características del Panel Admin:
- 📊 **Dashboard con estadísticas** en tiempo real
- 👥 **Gestión de usuarios**: Ver, buscar, cambiar roles (admin/user), suspender/activar
- 📅 **Gestión de eventos**: Ver, buscar, filtrar y eliminar eventos
- 🔍 **Búsqueda avanzada** por nombre, email o título de evento
- 🛡️ **Control de acceso** basado en roles

**Para más información, consulta:** [ADMIN_MODULE.md](./ADMIN_MODULE.md)

## Objetivos
- Reducir la fricción para organizar y sumarse a reuniones cercanas.
- Ofrecer navegación integrada hasta el punto de encuentro.
- Confirmar la llegada de forma sencilla mediante el sensor de movimiento.
- Mantener un control claro de asistencia y notificaciones.

## Características clave (MVP)
- Gestión de cuentas: registro, inicio de sesión, edición de perfil y baja de cuenta con correo electrónico.
- Eventos geolocalizados: creación de eventos con ubicación en mapa y hora definida.
- Asistencia: los usuarios pueden marcar que asistirán.
- Navegación: visualización de la ruta hacia el punto de encuentro usando servicios de mapas.
- Confirmación de llegada: detección de “shake” para notificar llegada en el destino.
- Notificaciones: aviso al creador y/o asistentes cuando un participante llega.

## Flujos principales
1. Crear evento: ubicación en mapa + fecha/hora + descripción.
2. Unirse a evento: marcar asistencia desde la ficha del evento.
3. Navegar al punto: abrir el mapa embebido y seguir la ruta sugerida.
4. Confirmar llegada: sacudir el dispositivo en el punto marcado para enviar notificación.
5. Gestión de cuenta: editar perfil o solicitar baja de cuenta.

## Público objetivo
- Personas que desean conocer gente nueva, organizar planes y no depender de la disponibilidad de su círculo cercano.

## Tecnologías previstas
- Flutter/Dart (app móvil).
- Firebase Auth (gestión de cuentas).
- Google Maps SDK para Flutter (mapa y rutas).
- Sensores del dispositivo para gesto “shake”.
- Sistema de notificaciones (según plataforma).

## Permisos y privacidad
- Ubicación en primer plano para mostrar el mapa y calcular la ruta.
- Notificaciones para avisos de llegada y cambios de estado.
- No se requiere permiso específico para el gesto “shake” (uso de acelerómetro).

## Alcance y estado
- MVP enfocado en autenticación, creación/unión a eventos, navegación y confirmación de llegada.
- Roadmap: recuperación de contraseña, chat básico por evento, filtros por categoría/distancia, modo oscuro, i18n.

## Características
- Autenticación de usuarios (Firebase Authentication + Google Sign-In).
- Inicio de sesión/registro con Google.
- Validaciones de formularios.
- UI adaptable.
- Soporte de icono de Google con `flutter_svg` o asset local.
- Persistencia y datos en Cloud Firestore.
- Notificaciones push (Firebase Messaging) y notificaciones locales.
- Integración de Google Maps y obtención de la ubicación (google_maps_flutter + geolocator).
- Captura y selección de imágenes, recorte y compresión (image_picker, image_cropper, flutter_image_compress, mime).
- Inicio con icono personalizado (flutter_launcher_icons).
- Manejo de estado con Provider.
- Preferencias locales (shared_preferences) para ajustes/flags.
- Internacionalización/localización (flutter_localizations + intl).
- Variables de entorno (flutter_dotenv) para configurar claves y endpoints.
- Acciones por sacudida del dispositivo (shake).
- Lanzar URLs externas (url_launcher).
- Uso de SVGs (flutter_svg).
- Realizar peticiones HTTP (http).

## Requisitos previos
- Flutter 3.x y Dart 3.x instalados.
- Android Studio (SDK y emulador) / Xcode si compilas para iOS.
- Proyecto de Firebase con Auth habilitado (Email/Password y Google).
- Archivos de configuración:
  - Android: 'android/app/google-services.json'
- En Android, registra SHA\-1 y SHA\-256 en Firebase.

## Dependencias principales
Añade en 'pubspec.yaml':
```yaml
flutter:
  sdk: flutter
flutter_localizations:
  sdk: flutter
cupertino_icons: ^1.0.8
flutter_launcher_icons: ^0.14.4
firebase_core: ^4.2.1
cloud_firestore: ^6.1.0
flutter_dotenv: ^6.0.0
firebase_auth: ^6.1.2
firebase_messaging: ^16.0.4
flutter_local_notifications: ^19.5.0
google_maps_flutter: ^2.14.0
geolocator: ^14.0.2
shake: ^3.0.0
google_sign_in: ^7.2.0
flutter_svg: ^2.2.2 # opcional si usarás SVG del logo de Google
http: ^1.6.0
image_picker: ^1.2.1
mime: ^2.0.0
image_cropper: ^11.0.0
provider: ^6.1.5+1
shared_preferences: ^2.5.3
intl: ^0.20.2
url_launcher: ^6.3.1
flutter_image_compress: ^2.4.0
```

Dev y herramientas relacionadas:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

flutter_lints: ^5.0.0
change_app_package_name: ^1.5.0
```

---

## Configuración de plataforma

### Android
- En 'android/build.gradle' asegura el classpath del Google Services:
```gradle
buildscript {
  dependencies {
    classpath "com.google.gms:google-services:X.Y.Z"
  }
}
```
- En 'android/app/build.gradle' aplica el plugin:
```gradle
plugins {
  id "com.android.application"
  id "com.google.gms.google-services"
}
```
- Verifica 'minSdkVersion' >= 21 en 'android/app/build.gradle'.

### iOS
- En Xcode añade el archivo 'GoogleService-Info.plist' a 'Runner'.
- En 'ios/Runner/Info.plist' configura `CFBundleURLTypes` con `REVERSED_CLIENT_ID` del plist (necesario para Google Sign\-In).
- Ejecuta `cd ios && pod install && cd ..` si es necesario.

## Ejecución
```bash
flutter pub get
flutter run
```

## Estructura de carpetas (resumen)
```
lib/
  controllers/
    auth_controller.dart
  screens/
    sign_in_page.dart
    sign_up_page.dart
  widgets/
    ...
```

## Uso de Google Sign\-In
- Habilita Google en Firebase Auth.
- Coloca el botón "Continuar con Google" en tus pantallas (por ejemplo, en 'lib/screens/sign_up_page.dart').
- Si usas el logo oficial en SVG:
  - Instala `flutter_svg` y usa `SvgPicture.network` con placeholder.
- Alternativa: descarga un PNG en 'assets/google.png' y decláralo en 'pubspec.yaml'.

## Configura Google Maps:
   - Crea un archivo en raiz `.env` e inserta la API key dentro.

## Solución de problemas
- El SVG del logo no se muestra:
  - `Image.network` no renderiza SVG. Usa `flutter_svg` o un PNG local.
- Error de credenciales en Android:
  - Revisa SHA\-1/SHA\-256 en Firebase y vuelve a descargar 'google-services.json'.
- iOS no abre Google:
  - Revisa `CFBundleURLTypes` y `REVERSED_CLIENT_ID` en 'Info.plist'.

## Scripts útiles
```bash
# Formateo y análisis
flutter format .
flutter analyze

# Limpieza de build
flutter clean && flutter pub get
```

## Licencia
Pendiente.
```
