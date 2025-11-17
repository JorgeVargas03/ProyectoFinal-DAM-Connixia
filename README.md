# ProyectoFinal Connixia

Aplicación Flutter (Android/iOS) para gestión de autenticación con correo/contraseña e inicio de sesión con Google usando Firebase.

## Características
- Autenticación con correo y contraseña (Firebase Auth).
- Inicio de sesión/registro con Google.
- Validaciones de formularios.
- UI adaptable.
- Soporte de icono de Google con `flutter_svg` o asset local.

## Requisitos previos
- Flutter 3.x y Dart 3.x instalados.
- Android Studio (SDK y emulador) / Xcode si compilas para iOS.
- Proyecto de Firebase con Auth habilitado (Email/Password y Google).
- Archivos de configuración:
  - Android: 'android/app/google-services.json'
  - iOS: 'ios/Runner/GoogleService-Info.plist'
- En Android, registra SHA\-1 y SHA\-256 en Firebase.

## Dependencias principales
Añade en 'pubspec.yaml':
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core:
  firebase_auth:
  google_sign_in:
  flutter_svg: # opcional si usarás SVG del logo de Google
```

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
