# 📁 Módulo de Administración - Estructura

Este directorio contiene todos los componentes relacionados con el módulo de administración de Connixia.

## 📂 Estructura de Carpetas

```
lib/admin/
├── controllers/
│   └── admin_controller.dart          # Lógica de negocio del módulo admin
├── screens/
│   ├── admin_gate_page.dart           # Verificación de acceso
│   ├── admin_dashboard_page.dart      # Dashboard principal
│   ├── admin_users_page.dart          # Gestión de usuarios
│   └── admin_events_page.dart         # Gestión de eventos
├── utils/
│   └── make_admin_helper.dart         # Helper para configurar primer admin
└── README.md                          # Este archivo
```

## 🎯 Propósito

Esta estructura modular permite:

- **Separación de responsabilidades**: Todo lo relacionado con administración está aislado
- **Fácil mantenimiento**: Los cambios al módulo admin no afectan el resto de la app
- **Escalabilidad**: Fácil expandir o extraer a una aplicación separada
- **Claridad**: La estructura es clara y auto-documentada

## 📝 Descripción de Archivos

### Controllers

#### `admin_controller.dart`
Controlador principal que gestiona:
- Verificación de roles de administrador
- Estadísticas generales del sistema
- Operaciones CRUD para usuarios y eventos
- Búsqueda y filtrado de datos

### Screens

#### `admin_gate_page.dart`
- Punto de entrada al módulo de administración
- Verifica permisos antes de acceder
- Redirige al dashboard si el usuario es admin
- Muestra pantalla de acceso denegado si no tiene permisos

#### `admin_dashboard_page.dart`
- Dashboard principal con estadísticas en tiempo real
- Tarjetas interactivas para navegación
- Vista general del estado del sistema

#### `admin_users_page.dart`
- Lista y gestión de usuarios
- Búsqueda por nombre o email
- Cambio de roles (user ↔ admin)
- Suspensión/activación de cuentas
- Vista de detalles y estadísticas

#### `admin_events_page.dart`
- Lista y gestión de eventos
- Filtros por estado (activos, cancelados, completados)
- Búsqueda por título
- Eliminación de eventos con confirmación
- Vista de información detallada

### Utils

#### `make_admin_helper.dart`
- Script auxiliar para configurar el primer administrador
- Funciones para verificar rol actual
- Herramienta de desarrollo temporal

## 🔗 Integración con la App

El módulo se integra con la app principal a través de:

1. **`lib/screens/profile_page.dart`**
   - Importa: `lib/admin/controllers/admin_controller.dart`
   - Importa: `lib/admin/screens/admin_gate_page.dart`
   - Muestra botón de acceso para usuarios admin

2. **`lib/controllers/auth_controller.dart`**
   - Crea usuarios con `role: 'user'` por defecto
   - Permite que el sistema de roles funcione desde el registro

## 🚀 Cómo Usar

### Para acceder al módulo:
```dart
import 'package:proyectofinal_connixia/admin/screens/admin_gate_page.dart';

// En cualquier parte de tu app:
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const AdminGatePage()),
);
```

### Para verificar si un usuario es admin:
```dart
import 'package:proyectofinal_connixia/admin/controllers/admin_controller.dart';

final adminCtrl = AdminController();
final isAdmin = await adminCtrl.isAdmin();

if (isAdmin) {
  // Usuario tiene permisos de administrador
}
```

## 🔒 Seguridad

- **Verificación en cada acción**: Todas las operaciones verifican permisos
- **Protecciones incorporadas**:
  - No puedes cambiar tu propio rol
  - No puedes suspenderte a ti mismo
  - Confirmación para acciones destructivas
- **Reglas de Firestore**: Ver `firestore.rules.suggested` en la raíz del proyecto

## 📖 Documentación Adicional

- **`ADMIN_MODULE.md`**: Documentación completa del módulo
- **`QUICK_START_ADMIN.md`**: Guía rápida para evaluadores
- **`firestore.rules.suggested`**: Reglas de seguridad recomendadas

## 🔮 Futuras Mejoras

Ideas para expandir el módulo:

1. **Dashboard Avanzado**: Gráficas y métricas en tiempo real
2. **Sistema de Reportes**: Exportación de datos a CSV/PDF
3. **Logs de Auditoría**: Registro de todas las acciones administrativas
4. **Roles Personalizados**: Moderador, super-admin, etc.
5. **Notificaciones Admin**: Alertas de actividad sospechosa
6. **App Web Separada**: Extraer a Flutter Web para uso en desktop

## 💡 Buenas Prácticas

Al trabajar con este módulo:

1. ✅ Siempre verifica permisos antes de operaciones sensibles
2. ✅ Usa `AdminController` para toda la lógica de administración
3. ✅ Mantén los archivos en sus respectivas carpetas
4. ✅ Documenta cambios significativos
5. ✅ Prueba con usuarios admin y no-admin
6. ✅ Usa confirmaciones para acciones destructivas

---

**Última actualización**: Diciembre 2025  
**Versión**: 1.0.0  
**Mantenedor**: Proyecto Connixia - DAM
