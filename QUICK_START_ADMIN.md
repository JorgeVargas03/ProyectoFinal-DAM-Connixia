# 🎓 Guía Rápida para Evaluación - Módulo de Administración

## Para el Profesor/Evaluador

Este documento explica cómo revisar el módulo de administración de Connixia para validar el cumplimiento del requisito del proyecto.

---

## ✅ Requisito Cumplido

**Requisito:** *"Debe contener un módulo de administración o programar una APP por separado para ello. También puede ser Web."*

**Solución Implementada:** Módulo de administración integrado en la aplicación móvil, accesible solo para usuarios con rol de administrador.

---

## 🚀 Cómo Probar el Módulo (Método Rápido)

### Opción 1: Usar Usuario Admin Pre-configurado

Si el desarrollador ya configuró un usuario admin:

1. Solicita las credenciales del usuario administrador
2. Inicia sesión con esas credenciales
3. Ve a la pestaña **"Mi Cuenta"**
4. Verás un botón naranja **"Panel de Administración"**
5. Accede al panel y explora las funcionalidades

### Opción 2: Configurar un Usuario Admin Manualmente

1. **Inicia sesión** con cualquier cuenta en la app
2. Abre **Firebase Console** → Firestore Database
3. Busca la colección `users`
4. Encuentra el documento del usuario con el que iniciaste sesión
5. Edita el documento y agrega/modifica el campo:
   ```
   Campo: role
   Valor: admin
   ```
6. Cierra y vuelve a abrir la app
7. Ve a **"Mi Cuenta"** → verás el botón **"Panel de Administración"**

### Opción 3: Usar Script de Configuración

El proyecto incluye un archivo helper: `lib/utils/make_admin_helper.dart`

El desarrollador puede agregar temporalmente este código para convertir al usuario actual en admin.

---

## 🎯 Funcionalidades a Evaluar

### 1. Dashboard Principal ✅
- **Ubicación:** Panel de Administración → Pantalla inicial
- **Verifica:**
  - ✓ Estadísticas generales (usuarios, eventos, notificaciones)
  - ✓ Tarjetas interactivas que navegan a secciones
  - ✓ Botón de refresco para actualizar datos

### 2. Gestión de Usuarios ✅
- **Ubicación:** Dashboard → "Gestionar Usuarios"
- **Verifica:**
  - ✓ Lista completa de usuarios con datos básicos
  - ✓ Búsqueda por nombre o email
  - ✓ Información detallada de cada usuario
  - ✓ Cambio de rol (Usuario ↔ Administrador)
  - ✓ Suspensión/Activación de usuarios
  - ✓ Vista de estadísticas (eventos creados, participados)

**Prueba sugerida:**
1. Busca un usuario por email
2. Expande su tarjeta
3. Intenta cambiar su rol a "admin"
4. Verifica que aparezca la insignia "ADMIN"

### 3. Gestión de Eventos ✅
- **Ubicación:** Dashboard → "Gestionar Eventos"
- **Verifica:**
  - ✓ Lista de todos los eventos
  - ✓ Filtros por estado (Activos, Cancelados, Completados)
  - ✓ Búsqueda por título
  - ✓ Información detallada (creador, participantes, fecha)
  - ✓ Eliminación de eventos con confirmación
  - ✓ Acceso directo a vista de detalle del evento

**Prueba sugerida:**
1. Filtra por "Eventos Activos"
2. Expande un evento
3. Observa la información del creador
4. Intenta eliminar un evento (con confirmación)

### 4. Seguridad y Permisos ✅
- **Verifica:**
  - ✓ Usuarios sin rol admin NO ven el botón de acceso
  - ✓ Acceso directo sin permisos muestra pantalla de "Acceso Denegado"
  - ✓ No se puede cambiar el rol propio
  - ✓ No se puede suspender la cuenta propia
  - ✓ Confirmaciones para acciones destructivas

**Prueba sugerida:**
1. Crea dos cuentas de usuario
2. Haz admin solo a una
3. Intenta acceder al panel con ambas
4. La cuenta sin admin debe ser rechazada

---

## 📋 Criterios de Evaluación Sugeridos

| Criterio | Cumple | Observaciones |
|----------|--------|---------------|
| Existe módulo de administración | ☐ Sí ☐ No | |
| Acceso restringido por roles | ☐ Sí ☐ No | |
| Dashboard con estadísticas | ☐ Sí ☐ No | |
| Gestión de usuarios | ☐ Sí ☐ No | |
| Gestión de eventos | ☐ Sí ☐ No | |
| Búsqueda funcional | ☐ Sí ☐ No | |
| Confirmaciones de seguridad | ☐ Sí ☐ No | |
| No altera flujo de usuarios | ☐ Sí ☐ No | |
| Documentación completa | ☐ Sí ☐ No | |

---

## 📂 Archivos Relacionados

Para revisar el código fuente del módulo:

```
lib/
  controllers/
    admin_controller.dart        # Lógica de administración
    auth_controller.dart         # Modificado: agrega campo 'role'
  
  screens/
    admin_gate_page.dart         # Control de acceso
    admin_dashboard_page.dart    # Dashboard principal
    admin_users_page.dart        # Gestión de usuarios
    admin_events_page.dart       # Gestión de eventos
    profile_page.dart            # Modificado: botón de acceso admin

  utils/
    make_admin_helper.dart       # Helper para configuración inicial

Documentación:
  ADMIN_MODULE.md               # Documentación completa del módulo
  firestore.rules.suggested     # Reglas de seguridad sugeridas
  QUICK_START_ADMIN.md          # Este archivo
```

---

## 🔒 Aspectos de Seguridad Implementados

1. **Verificación de Rol:** Cada acción verifica permisos en el backend (Firestore)
2. **Protecciones:**
   - No puedes cambiar tu propio rol
   - No puedes suspenderte a ti mismo
   - Confirmación para acciones destructivas
3. **Recomendaciones Incluidas:** Reglas de Firestore Security en `firestore.rules.suggested`

---

## 💡 Puntos Destacables para la Evaluación

1. **Integración sin Fricción:** El módulo está integrado pero no afecta a usuarios normales
2. **Escalabilidad:** Fácil extender a una app web separada con Flutter Web
3. **Separación de Responsabilidades:** Controlador dedicado para lógica admin
4. **UI Consistente:** Usa el mismo diseño y tema que el resto de la app
5. **Tiempo Real:** Usa Streams de Firestore para datos actualizados

---

## 🎬 Guía de Demostración (5 minutos)

### Minuto 1: Acceso
- Mostrar pantalla de perfil (usuario normal: sin botón admin)
- Iniciar sesión como admin
- Mostrar botón naranja de "Panel de Administración"

### Minuto 2: Dashboard
- Mostrar estadísticas en tiempo real
- Explicar las tarjetas interactivas
- Refrescar estadísticas

### Minuto 3: Gestión de Usuarios
- Buscar un usuario específico
- Mostrar detalles (eventos creados, participados)
- Cambiar rol de usuario a admin
- Mostrar opción de suspensión

### Minuto 4: Gestión de Eventos
- Aplicar filtros (Activos, Cancelados)
- Buscar un evento por título
- Mostrar información del creador
- Explicar opción de eliminación

### Minuto 5: Seguridad
- Intentar acceder con usuario no-admin
- Mostrar pantalla de "Acceso Denegado"
- Explicar verificaciones de permisos

---

## 📞 Preguntas Frecuentes

**P: ¿Por qué no es una app separada?**
R: El requisito permitía módulo integrado o app separada. Se eligió integrado por eficiencia y porque comparte la misma base de datos. Es fácil extraer a Flutter Web si se requiere.

**P: ¿Es seguro?**
R: Sí. Incluye verificación de roles en cada operación y recomendaciones de Firestore Security Rules para reforzar seguridad en producción.

**P: ¿Se puede acceder desde web?**
R: Actualmente es móvil. Con Flutter Web, el mismo código puede compilarse a una aplicación web sin cambios significativos.

**P: ¿Qué pasa si borro un evento?**
R: Se elimina permanentemente incluyendo mensajes, asistencias y datos relacionados. Por eso requiere confirmación.

---

## ✅ Checklist Final para el Desarrollador

Antes de la presentación, verifica:

- [ ] Al menos un usuario tiene rol 'admin' en Firestore
- [ ] Puedes acceder al panel de administración
- [ ] Las estadísticas se muestran correctamente
- [ ] La búsqueda de usuarios funciona
- [ ] La búsqueda de eventos funciona
- [ ] Los filtros de eventos funcionan
- [ ] Puedes cambiar roles de usuario
- [ ] La eliminación de eventos funciona
- [ ] Un usuario sin admin no puede acceder
- [ ] Has leído ADMIN_MODULE.md

---

**Tiempo estimado de revisión:** 10-15 minutos
**Complejidad:** Media
**Estado:** ✅ Completo y funcional

---

*Última actualización: Diciembre 2025*
*Proyecto: Connixia - Encuentros Geolocalizados*
*Módulo: Administración*
