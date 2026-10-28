# Azalea Core / AzerothCore

## Español

Servidor basado en [AzerothCore WotLK](https://github.com/azerothcore/azerothcore-wotlk)
y [ALE](https://github.com/azerothcore/mod-ale). Se conserva el crédito, licencia e historial originales.

| Rama | Propósito |
|---|---|
| `master` | Referencia del core original más esta documentación de organización |
| `base/lua` | Base reproducible con ALE fijado, configuración de ejemplo y ejemplo Lua |
| `feature/...` | Desarrollo y documentación de cada tutorial; conservar después del merge |
| `server` | Base Lua más funcionalidades aprobadas; fuente para los despliegues |

Crear cada tutorial independiente desde `base/lua`. Documentar en español e inglés qué hace,
requisitos, instalación, cambios de cliente/servidor, SQL, pruebas y recuperación. Conservar la rama
y una etiqueta de versión final. Integrar en `server` mediante merge sin squash; compilar allí
solo si procede, desplegar y verificar. Si depende de otra feature, declarar y preparar esa dependencia.

Desarrollar fuera del directorio activo: Docker monta los scripts Lua y puede recargarlos.
Una rama fusionada no significa que ya esté desplegada: registrar por separado commit e imagen.
Git no respalda personajes, cuentas ni modificaciones de base de datos. Las copias privadas deben
incluir SQL, configuración, imágenes y recursos de cliente y guardarse fuera de la Raspberry.

La base documentada está en `doc/azalea/BASE.md` (rama `base/lua` y derivadas).
El tutorial de saludos está en `doc/azalea/features/login-greetings.md` (su feature y `server`).
Las instrucciones originales de AzerothCore siguen en `.github/README.md` y en su wiki.

## English

This project builds on AzerothCore WotLK and ALE, preserving upstream authorship, licenses and history.
`master` tracks the reference core plus organizational documentation; `base/lua` provides a pinned,
reproducible Lua baseline; `feature/...` preserves each tutorial; `server` integrates approved features
and supplies deployment sources. `develop` has been renamed to `base/lua`.

Start independent tutorials from `base/lua`. Every feature needs Spanish and English documentation:
behavior, dependencies, installation, client/server changes, SQL, checks and rollback. Preserve its
branch and final release tag. Merge into `server` without squash, build there when needed, deploy and
verify. Declare dependencies on other features explicitly. Keep development away from live-mounted
Lua scripts. Record deployed commits/images separately: a merge does not deploy a container.

Git is not a database or client backup. Keep private off-device backups of databases, configuration,
images and required client resources. See the branch-specific documents referenced above.
