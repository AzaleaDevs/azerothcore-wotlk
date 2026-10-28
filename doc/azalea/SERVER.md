# Rama server / Server branch

## Español

Esta rama integra la base Lua y las features aceptadas. Inicialmente incluye `feature/login-greetings`,
con sus saludos de Lua y C++. La reorganización añade documentación y configuración reproducible,
sin modificar el comportamiento del código de saludos.

**Estado tras los pasos 1 y 2:** ramas preparadas; Docker sigue ejecutando su imagen previa basada
en `d5695da75713`. Todavía NO se ha compilado ni desplegado esta rama. La preparación de caché,
compilación y despliegue corresponde a los siguientes pasos autorizados por separado.

Mantener la carpeta activa hasta preparar el despliegue separado. Los worktrees de desarrollo no
son despliegues. Registrar el commit y la imagen de cada publicación, y respaldar las bases antes
de migraciones. Validar los saludos dentro del juego después del despliegue.

## English

This branch integrates the pinned Lua baseline and accepted features, initially login greetings.
Steps 1 and 2 only prepare branches and documentation. Docker still runs the prior image built
from `d5695da75713`; this branch has NOT been built or deployed yet. Persistent build caches and
deployment are separate next steps. Worktrees are not deployments. Record commit/image per release,
back up databases before migrations, and verify both greetings in game after deployment.
