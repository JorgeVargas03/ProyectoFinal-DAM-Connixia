# Módulo de Administración - Connixia

## 📋 Descripción

El módulo de administración de Connixia es un sistema completo de gestión que permite a los administradores supervisar y moderar la plataforma sin alterar el flujo normal de los usuarios.

## ✨ Características

### 📊 Dashboard Principal
- Vista general con estadísticas en tiempo real
- Contador de usuarios totales
- Contador de eventos activos y totales
- Contador de notificaciones
- Accesos rápidos a gestión de usuarios y eventos

### 👥 Gestión de Usuarios
- **Visualización**: Lista completa de usuarios registrados con Stream en tiempo real
- **Búsqueda**: Buscar usuarios por nombre o email
- **Roles**: Cambiar rol de usuario entre `user` y `admin`
- **Moderación**: Suspender/activar usuarios
- **Detalles**: Ver estadísticas de cada usuario:
  - Eventos creados
  - Eventos participados
  - Número de contactos
  - Fecha de registro

### 📅 Gestión de Eventos
- **Visualización**: Lista completa de eventos con Stream en tiempo real
- **Búsqueda**: Buscar eventos por título
- **Filtros**: Filtrar por estado (Todos, Activos, Cancelados, Completados)
- **Moderación**: Eliminar eventos problemáticos
- **Detalles**: Ver información completa:
  - Creador del evento
  - Número de participantes
  - Estado y privacidad
  - Fecha de creación
  - Acceso directo a la vista de detalle del evento

## 🔐 Sistema de Roles

### Roles Disponibles
- **`user`** (por defecto): Usuario normal con acceso estándar a la app
- **`admin`**: Usuario con acceso al panel de administración

### Estructura en Firestore
Cada documento de usuario en la colección `users` tiene un campo `role`:

```json
{
  "uid": "abc123",
  "email": "usuario@ejemplo.com",
  "displayName": "Usuario Ejemplo",
  "role": "user",  // o "admin"
  "createdAt": "timestamp",
  ...
}
```

## 🚀 Cómo Activar el Módulo de Administración

### Paso 1: Asignar el Primer Administrador

Como los nuevos usuarios se crean con rol `user` por defecto, necesitas asignar manualmente el primer administrador desde Firebase Console:

1. Abre [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Ve a **Firestore Database**
4. Navega a la colección `users`
5. Busca el documento del usuario que quieres hacer administrador
6. Agrega o edita el campo `role` con el valor `"admin"`

**Opción alternativa usando código temporal:**

Puedes agregar este código temporal en tu app para hacer admin a tu usuario:

```dart
// SOLO PARA USO TEMPORAL - ELIMINAR DESPUÉS
Future<void> makeCurrentUserAdmin() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'role': 'admin'});
    print('Usuario convertido en admin');
  }
}
```

### Paso 2: Acceder al Panel de Administración

Una vez que un usuario tiene el rol `admin`:

1. Abre la app
2. Ve a **Mi Cuenta** (pestaña de perfil)
3. Verás un botón naranja **"Panel de Administración"**
4. Toca el botón para acceder al dashboard

### Paso 3: Gestionar Otros Administradores

Desde el panel de administración, puedes:

1. Ir a **Gestión de Usuarios**
2. Buscar o seleccionar el usuario deseado
3. Expandir la tarjeta del usuario
4. Presionar **"Hacer Admin"** para otorgar permisos
5. Presionar **"Quitar Admin"** para revocar permisos

## 🛡️ Seguridad

### Protecciones Implementadas
- ✅ Verificación de rol en cada acción administrativa
- ✅ Los usuarios no pueden cambiar su propio rol
- ✅ Los administradores no pueden suspenderse a sí mismos
- ✅ Confirmación obligatoria para acciones destructivas
- ✅ Mensajes de error claros para permisos insuficientes

### Recomendaciones de Seguridad

⚠️ **IMPORTANTE**: Este módulo está diseñado para ser usado dentro de la app. Para mayor seguridad en producción, considera:

1. **Reglas de Firestore Security**: Agrega reglas de seguridad para proteger operaciones administrativas:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Función auxiliar para verificar si es admin
    function isAdmin() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Proteger colección de usuarios
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth.uid == userId || isAdmin();
      allow delete: if isAdmin();
    }
    
    // Proteger eventos
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if isAdmin() || 
                      get(/databases/$(database)/documents/events/$(eventId)).data.creatorId == request.auth.uid;
    }
    
    // Otras reglas...
  }
}
```

2. **Cloud Functions**: Para operaciones críticas, usa Cloud Functions que validen el rol en el backend
3. **Auditoría**: Implementa logging de acciones administrativas
4. **Límites**: Establece límites de rate limiting para prevenir abuso

## 📱 Flujo de Usuario Normal (Sin Cambios)

El módulo de administración **NO afecta** el flujo normal de usuarios:

- ✅ Los usuarios regulares no ven el botón de administración
- ✅ Si intentan acceder directamente, son rechazados
- ✅ Todas las funcionalidades existentes siguen funcionando igual
- ✅ No hay cambios en la UI para usuarios no-admin
- ✅ No hay impacto en el rendimiento de la app

## 🗂️ Archivos Agregados

```
lib/
  controllers/
    admin_controller.dart          # Lógica de administración
  screens/
    admin_gate_page.dart           # Verificación de acceso
    admin_dashboard_page.dart      # Dashboard principal
    admin_users_page.dart          # Gestión de usuarios
    admin_events_page.dart         # Gestión de eventos
```

## 🔧 Modificaciones en Archivos Existentes

- `lib/controllers/auth_controller.dart`: Agregado campo `role: 'user'` por defecto
- `lib/screens/profile_page.dart`: Agregado botón de acceso al panel admin (solo visible para admins)

## 📊 Estadísticas Disponibles

### Globales (Dashboard)
- Total de usuarios registrados
- Eventos activos
- Total de eventos históricos
- Total de notificaciones

### Por Usuario
- Eventos creados
- Eventos a los que ha asistido
- Número de contactos

### Por Evento
- Número de participantes
- Estado actual
- Fecha de creación
- Creador del evento

## 🎯 Casos de Uso

### 1. Moderar Contenido Inapropiado
Si un evento contiene contenido ofensivo:
1. Ve a Gestión de Eventos
2. Busca o encuentra el evento
3. Presiona "Eliminar"
4. Confirma la acción

### 2. Suspender Usuario Problemático
Si un usuario está causando problemas:
1. Ve a Gestión de Usuarios
2. Busca el usuario
3. Presiona "Suspender"
4. El usuario quedará marcado como suspendido

### 3. Asignar Moderador
Para dar permisos de administración a un moderador:
1. Ve a Gestión de Usuarios
2. Busca el usuario
3. Presiona "Hacer Admin"
4. El usuario ahora tendrá acceso al panel

### 4. Revisar Actividad
Para ver la actividad de un usuario:
1. Ve a Gestión de Usuarios
2. Encuentra el usuario
3. Presiona "Ver Detalles"
4. Revisa sus estadísticas

## 🚧 Limitaciones Actuales

- No hay sistema de auditoría (logs de acciones)
- No hay recuperación de elementos eliminados
- La búsqueda de usuarios/eventos es básica (sin filtros avanzados)
- No hay estadísticas de tiempo real con gráficas
- No hay notificaciones push para administradores

## 🔮 Mejoras Futuras Sugeridas

1. **Panel Web Separado**: Crear una aplicación web dedicada con Flutter Web
2. **Dashboard Avanzado**: Gráficas interactivas de actividad
3. **Sistema de Reportes**: Permitir a usuarios reportar contenido
4. **Logs de Auditoría**: Registrar todas las acciones administrativas
5. **Notificaciones Admin**: Alertas de actividad sospechosa
6. **Exportación de Datos**: Exportar reportes en CSV/PDF
7. **Roles Personalizados**: Crear roles como moderador, super-admin, etc.
8. **Programación de Acciones**: Suspensiones temporales automáticas

## ⚡ Rendimiento

- Uso de Streams para datos en tiempo real
- Límite de 50-100 documentos por consulta para evitar sobrecarga
- Búsquedas optimizadas con índices de Firestore
- Carga diferida de detalles de usuario

## 🐛 Solución de Problemas

### "Acceso Denegado" aunque soy admin
- Verifica que el campo `role` en Firestore sea exactamente `"admin"`
- Cierra sesión y vuelve a iniciar sesión
- Revisa que no haya errores en la consola

### No puedo eliminar un evento
- Verifica tu conexión a internet
- Asegúrate de que el evento existe en Firestore
- Revisa los permisos de Firestore Security Rules

### El botón de admin no aparece
- Espera unos segundos a que cargue el estado
- Verifica que el rol esté bien configurado en Firestore
- Reinicia la aplicación

## 📝 Notas Finales

Este módulo cumple con el requisito de tu profesor de tener un **módulo de administración** sin crear una app separada. Todo está integrado en la misma aplicación pero de forma que no interfiere con el flujo normal de usuarios.

**Para presentación al profesor:**
- Muestra cómo acceder al panel (usuario con rol admin)
- Demuestra las funcionalidades de gestión
- Explica la seguridad (verificación de roles)
- Menciona que se puede separar en una Web App si lo desea

---

Desarrollado como parte del Proyecto Final DAM - Connixia
