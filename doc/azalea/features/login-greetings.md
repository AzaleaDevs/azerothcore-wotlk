# Tutorial: saludos al conectar / Login greetings

## Español

Feature: `feature/login-greetings`. Commit de implementación original:
`d5695da75713e3eff3651cfec3988ecba1a239d6` (se conserva en el historial).

Al conectar un personaje se muestran dos saludos: `Hola <nombre> desde Lua` y
`Hola <nombre> desde C++`. Sirve para comprobar ambos mecanismos de scripting.

### Archivos y requisitos

- `lua_scripts/login_greetings.lua`: evento de login 3, mensaje mediante ALE.
- `src/server/game/Scripting/ScriptDefines/PlayerScript.cpp`: mensaje añadido al hook C++ de login.
- ALE fijado y configuración: ver `doc/azalea/BASE.md`.
- Cliente: **sin modificaciones**, addon, DBC ni parche.
- SQL: **sin migraciones**.

### Instalación y comprobación

Integrar esta rama en `server` mediante merge sin squash. Compilar `server` con ALE y desplegar
la imagen; montar sus scripts Lua. Conectar un personaje y comprobar ambos saludos una sola vez.
El cambio C++ requiere compilación; Lua requiere carga por el motor. No copiar el ejemplo opcional
de la base al despliegue, ya que añadiría otro saludo.

En la revisión del 28/10/2026 el contenedor ya ejecutaba una compilación del commit original.
Durante la reorganización no se recompiló, recargó ni reinició. La comprobación de ambos mensajes
en el juego queda pendiente de conexión del propietario.

### Recuperación

Conservar imagen, scripts y configuración previos. Para retirar la feature, revertir su integración
en `server`, recompilar y desplegar el estado resultante junto con los scripts correspondientes.
No usar un checkout en la carpeta activa para probar: su Lua se monta en Docker con autoreload.
Este tutorial modifica directamente un hook del core; futuras features deberían preferir módulos
cuando resulte adecuado para reducir conflictos con actualizaciones del upstream.

## English

This feature shows `Hola <name> desde Lua` and `Hola <name> desde C++` on player login.
The original implementation commit is preserved: `d5695da75713e3eff3651cfec3988ecba1a239d6`.
Lua changes live in `lua_scripts/login_greetings.lua`; the C++ change is in
`src/server/game/Scripting/ScriptDefines/PlayerScript.cpp`. See `doc/azalea/BASE.md` for pinned ALE.
There are **no client modifications and no SQL migrations**.

Merge into `server` without squash, build with ALE, deploy the image and corresponding scripts,
then log in and verify both messages. Do not deploy the optional baseline example as an extra greeting.
The running container already reported the original feature commit during inspection on 2026-10-28.
This branch reorganization does not rebuild/restart it; in-game verification remains pending.

Rollback requires the previous image, configuration and scripts, or reverting the feature merge and
rebuilding `server`. Never switch branches in the live-mounted script directory for testing.
This example edits a core hook directly; consider modules for future features when appropriate.
