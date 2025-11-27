# 🔐 Configuración de Variables de Entorno

## ⚠️ IMPORTANTE: Seguridad de API Keys

Este proyecto usa variables de entorno para proteger información sensible como la API Key de Google Maps.

## 📝 Configuración Inicial

### 1. Crear archivo `.env`

Copia el archivo de ejemplo:

```bash
cp .env.example .env
```

O créalo manualmente con el siguiente contenido:

```env
MAPS_API_KEY=tu_api_key_aqui
```

### 2. Agregar tu API Key

Edita el archivo `.env` y reemplaza `tu_api_key_aqui` con tu API Key real de Google Maps.

```env
MAPS_API_KEY=AIzaSyC...tu_clave_real
```

### 3. Verificar `.gitignore`

Asegúrate de que `.env` esté en tu `.gitignore` (ya está configurado):

```gitignore
# Environment variables - NUNCA SUBIR
.env
```

## 🔒 Archivos y su Propósito

| Archivo | Propósito | ¿Se sube a GitHub? |
|---------|-----------|-------------------|
| `.env` | Contiene API Keys reales | ❌ NO (en .gitignore) |
| `.env.example` | Plantilla para colaboradores | ✅ SÍ |
| `local.properties` | Configuración local de Android | ❌ NO (en .gitignore) |

## 👥 Para Colaboradores

Si clonas este repositorio:

1. Copia `.env.example` a `.env`
2. Solicita las API Keys al administrador del proyecto
3. Completa tu archivo `.env` local
4. **NUNCA** hagas commit del archivo `.env`

## 🛡️ Reglas de Seguridad

### ✅ HACER:
- Mantener `.env` en `.gitignore`
- Usar `dotenv.env['KEY']` para acceder a variables
- Compartir API Keys por canales seguros (no GitHub)
- Mantener `.env.example` actualizado sin valores reales

### ❌ NO HACER:
- Subir `.env` a GitHub
- Hardcodear API Keys en el código
- Compartir API Keys en issues o pull requests
- Usar valores reales en `.env.example`

## 🚀 Uso en el Código

### Cargar variables (main.dart):
```dart
await dotenv.load(fileName: ".env");
```

### Acceder a variables:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

String apiKey = dotenv.env['MAPS_API_KEY'] ?? '';
```

## 🔍 Verificación

Antes de hacer commit, verifica:

```bash
# Ver archivos que se van a subir
git status

# Verificar que .env NO aparezca en la lista
# Si aparece, agrégalo a .gitignore inmediatamente
```

## 📱 Variables Disponibles

| Variable | Descripción | Requerida |
|----------|-------------|-----------|
| `MAPS_API_KEY` | Google Maps API Key | ✅ Sí |

## 🆘 Problemas Comunes

### Error: "MAPS_API_KEY not found"
**Causa**: El archivo `.env` no existe o está mal configurado.
**Solución**: Copia `.env.example` a `.env` y agrega tu API Key.

### La app no carga el mapa
**Causa**: API Key inválida o sin permisos.
**Solución**: Verifica que la API Key tenga habilitados los servicios:
- Maps SDK for Android
- Geocoding API
- Places API (opcional)

### Accidentalmente subí `.env` a GitHub
**Solución URGENTE**:
1. Revoca la API Key en Google Cloud Console
2. Genera una nueva API Key
3. Actualiza tu `.env` local
4. Elimina el archivo del historial de Git:
```bash
git rm --cached .env
git commit -m "Remove .env from repo"
git push
```

## 📚 Recursos

- [Google Cloud Console](https://console.cloud.google.com/)
- [flutter_dotenv Documentation](https://pub.dev/packages/flutter_dotenv)
- [Git Secrets](https://github.com/awslabs/git-secrets)

---

**Recuerda**: La seguridad es responsabilidad de todos. Si detectas una API Key expuesta, repórtalo inmediatamente.
