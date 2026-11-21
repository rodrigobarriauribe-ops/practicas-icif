# Prácticas ICIF

Plataforma de gestión de prácticas (Industrial y Profesional) de Ingeniería Civil Informática, USS Sede De la Patagonia. Versión piloto.

Cada persona entra con su correo y un código de un solo uso, sin contraseña:

| Perfil | Qué hace |
|---|---|
| Estudiante | Pide cartas de presentación, completa el formulario de activación y sube su informe. |
| Supervisor/a de empresa | Evalúa con la matriz de la práctica y sube documentos de la empresa. Recibe su acceso cuando se activa la práctica. |
| Docente corrector/a | Revisa el informe, lo devuelve con observaciones o lo califica. |
| Dirección de carrera | Carga personas, emite cartas, activa prácticas, registra seguros, asigna docentes, cierra notas y configura matrices. |

Los permisos los controla la base de datos: cada persona solo puede leer y modificar lo que le corresponde, aunque intente hacerlo fuera de la página.

## Archivos

- `index.html`: la aplicación.
- `config.js`: dirección y clave pública del proyecto de Supabase.
- `supabase.js`: biblioteca oficial de Supabase (versión 2.45.4).
- `supabase/setup.sql`: tablas, permisos y funciones de la base de datos.

## Puesta en marcha

### 1. Base de datos (Supabase)

1. En supabase.com, abre tu proyecto y entra a **SQL Editor → New query**.
2. Copia todo el contenido de `supabase/setup.sql`.
3. Al final del archivo, reemplaza `__DIRECTOR_EMAIL__` y `__DIRECTOR_NOMBRE__` por tu correo y tu nombre. Con ese correo entrarás como Dirección de Carrera.
4. Presiona **Run**. Puedes volver a ejecutarlo más adelante sin perder datos.

### 2. Inicio de sesión por correo

En Supabase → **Authentication**:

1. **URL Configuration**: en *Site URL* pon la dirección de la plataforma (por ejemplo `https://TU_USUARIO.github.io/practicas-icif/`) y agrégala también en *Redirect URLs*.
2. **Email Templates**: en las plantillas *Magic Link* y *Confirm signup*, agrega una línea con el código, por ejemplo: `Tu código de acceso es: {{ .Token }}`. Así la persona puede entrar con el enlace o escribiendo el código.
3. **Correo de envío (importante para el piloto)**: el correo incluido en Supabase sirve solo para pruebas y envía muy pocos mensajes por hora. Antes de abrir la plataforma a estudiantes y empresas, configura un servicio de envío propio en *Authentication → Emails → SMTP Settings* (por ejemplo Resend, Brevo o el correo de un dominio propio).

### 3. Conexión

Edita `config.js` con la **Project URL** y la **clave pública** (*anon* o *publishable*) de Supabase → Project Settings → API. Nunca pongas ahí la clave *service_role* o *secret*.

### 4. Publicación (GitHub Pages)

En el repositorio: **Settings → Pages → Build and deployment → Deploy from a branch → main / (root) → Save**. En uno o dos minutos la plataforma queda en `https://TU_USUARIO.github.io/practicas-icif/`.

### 5. Primer uso

1. Entra con tu correo de Dirección.
2. **Personas**: agrega a los docentes correctores y carga a los estudiantes (puedes pegar filas desde Excel).
3. **Configuración**: escribe el nombre de quien firma las cartas y el correo de contacto, y revisa las matrices y ponderaciones.
4. Haz una prueba completa con correos propios antes de cargar estudiantes reales.

## Datos personales

La plataforma guarda RUT, notas e informes de estudiantes en el proyecto de Supabase. Para el piloto:

- Pide el visto bueno de la Facultad antes de cargar datos reales.
- Mantén privada la contraseña de la base de datos y la cuenta de Supabase.
- Al terminar el piloto, exporta lo necesario y elimina el proyecto, o traspásalo a la universidad.
