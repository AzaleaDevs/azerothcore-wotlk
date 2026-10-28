# Procedimiento de Azalea Core / Azalea Core workflow

## Español

### Ramas y carpetas

`master` conserva el core de referencia; `base/lua` añade la integración reproducible de ALE;
`feature/<nombre>` contiene cada tutorial con sus commits y documentación; `server` reúne la base
y las features aprobadas. Cada feature se conserva y publica para que pueda consultarse por separado.
ALE es un repositorio externo: `azalea/modules.lock.json` fija su revisión y
`azalea/scripts/bootstrap-ale.sh` instala y valida esa revisión.

La instalación activa `/home/azalea/docker/Warcraft/azerothcore-wotlk` contiene la configuración,
datos y scripts montados por Docker. No cambiar su rama ni usarla para desarrollar. Los worktrees
están en `/home/azalea/docker/Warcraft/branch-worktrees/`; el contexto independiente de compilación
está en `/home/azalea/docker/Warcraft/build-contexts/server`.

### Crear y desarrollar una feature

1. Comprobar el estado Git, actualizar las referencias y partir de la revisión publicada de
   `base/lua`. Crear una rama y un worktree con un nombre concreto, sin sobrescribir carpetas:

   ```bash
   git -C /home/azalea/docker/Warcraft/branch-worktrees/base-lua fetch origin
   git -C /home/azalea/docker/Warcraft/branch-worktrees/base-lua status --short
   git -C /home/azalea/docker/Warcraft/branch-worktrees/base-lua worktree add \
     -b feature/mi-feature /home/azalea/docker/Warcraft/branch-worktrees/mi-feature origin/base/lua
   cd /home/azalea/docker/Warcraft/branch-worktrees/mi-feature
   bash azalea/scripts/bootstrap-ale.sh
   ```

2. Desarrollar y probar la funcionalidad en su worktree, respetando `AGENTS.md` y las instrucciones
   que referencia. No publicar credenciales, configuraciones privadas ni datos de las bases.
3. Documentar en español e inglés: funcionamiento, instalación, cambios de cliente y servidor,
   SQL y su orden, pruebas, compatibilidad, dependencias y recuperación. Indicar expresamente
   cuando no hay cambios de cliente o SQL. Explicar cómo desactivar o revertir la feature y las
   consecuencias para datos existentes.
4. Revisar cambios, ejecutar las pruebas pertinentes, registrar sus resultados y crear commits.
   Publicar y conservar la rama `feature/mi-feature` y sus commits.

Si una feature depende de otra, documentar la dependencia y los commits concretos. Desarrollarla
sobre la rama dependiente cuando sea necesario y no presentarla como independiente. Integrar primero
la dependencia aprobada en `server`; después fusionar la feature dependiente y resolver conflictos.
No retirar las ramas ni reescribir su historial publicado sin coordinación.

### Integración, compilación y despliegue

1. Verificar que la feature está aprobada, documentada y probada, y que `server` está limpio.
   En el worktree `server`, actualizar sus referencias y fusionar la rama aprobada:

   ```bash
   cd /home/azalea/docker/Warcraft/branch-worktrees/server
   git fetch origin
   git status --short
   git merge --no-ff origin/feature/mi-feature
   ```

   Revisar el resultado, resolver conflictos, probar de nuevo y publicar `server` cuando proceda.
   No continuar si hay cambios inesperados o pruebas fallidas.
2. Examinar SQL y cambios de cliente. Si hay migraciones o datos incompatibles, preparar un respaldo
   reciente y un plan específico de reversión antes de aplicarlos. Volver a una imagen antigua no
   deshace migraciones. Coordinar el reinicio con quienes usen el servidor.
3. Preparar y compilar desde `server`, limpio y con ALE fijado:

   ```bash
   cd /home/azalea/docker/Warcraft/branch-worktrees/server
   bash azalea/scripts/build-server-cache.sh
   ```

   El script prepara el clon independiente y compila con BuildKit, ccache y objetos Ninja
   persistentes. La salida predeterminada es `cacheonly`: **no crea imágenes de ejecución**.
   Las cachés pueden ser eliminadas por Docker; si falta una, la siguiente compilación reconstruye
   lo necesario. Evitar `--no-cache` salvo diagnóstico justificado. Véase `doc/azalea/BUILD.md`.
4. Construir las imágenes desde el contexto preparado, usando el commit real y una etiqueta nueva:

   ```bash
   revision=$(git rev-parse HEAD)
   corto=$(git rev-parse --short=12 HEAD)
   contexto=/home/azalea/docker/Warcraft/build-contexts/server
   docker buildx build --file "$contexto/apps/docker/Dockerfile" \
     --build-arg "CACHEBUST=$revision" --target worldserver \
     --tag "azalea-core/worldserver:server-$corto" --load "$contexto"
   docker buildx build --file "$contexto/apps/docker/Dockerfile" \
     --build-arg "CACHEBUST=$revision" --target authserver \
     --tag "azalea-core/authserver:server-$corto" --load "$contexto"
   docker run --rm --entrypoint /azerothcore/env/dist/bin/worldserver \
     "azalea-core/worldserver:server-$corto" --version
   docker run --rm --entrypoint /azerothcore/env/dist/bin/authserver \
     "azalea-core/authserver:server-$corto" --version
   ```

   Confirmar revisión y rama de ambos binarios, IDs de imágenes y módulo ALE. El signo `+` de
   la versión indica que Git detectó diferencias en el contexto de compilación: investigar su
   causa antes de atribuir el binario a un commit limpio. No asumir que `--version` basta para
   certificar todo el contenido.
5. El Lua en ejecución se monta desde la instalación activa, no desde la imagen ni automáticamente
   desde `server`. Comparar los scripts activos con los aprobados, preservar una copia y aplicar
   deliberadamente los cambios necesarios. La recarga automática puede hacerlos efectivos de
   inmediato: coordinar este paso y prever la reversión. No reemplazar scripts ajenos a la feature.
6. Registrar los IDs y etiquetas actuales, conservar etiquetas de recuperación y comprobar que
   apuntan a las imágenes correctas. Con las imágenes y scripts verificados, etiquetar las nuevas
   imágenes con los nombres que utiliza Compose y recrear solo los servicios necesarios:

   ```bash
   docker tag "azalea-core/worldserver:server-$corto" acore/ac-wotlk-worldserver:master
   docker tag "azalea-core/authserver:server-$corto" acore/ac-wotlk-authserver:master
   cd /home/azalea/docker/Warcraft/azerothcore-wotlk
   docker compose up -d --no-deps --no-build ac-worldserver ac-authserver
   ```

   La etiqueta `master` de estas imágenes es la que usa el Compose actual; no significa que se
   compile desde la rama Git `master`. Evitar `--build` en la instalación activa. Si la configuración
   de Compose cambia, comprobar primero los nombres reales con `docker compose config --images`.
7. Comprobar imágenes realmente ejecutadas, arranque completo y revisión en logs, conexiones a
   las tres bases, ALE y scripts, puertos y errores. Probar en el juego los comportamientos afectados
   y anotar resultado, fecha, commit e IDs de imágenes. Un contenedor `Up` no equivale a mundo listo.

### Recuperación

Para volver a la versión anterior, identificar sus etiquetas e IDs registrados, revisar scripts y
configuración, y volver a etiquetar las imágenes anteriores con los nombres que usa Compose antes
de recrear los servicios. Verificar que arrancan y probar dentro del juego. Si hubo SQL o cambios de
datos, evaluar su compatibilidad y el plan de recuperación específico antes de volver atrás. La
recuperación histórica está documentada en
`/home/azalea/backups/azalea-core/pre-branches-20261028/RECUPERACION.md`; contiene información privada.

### Instrucción reutilizable para Codex

```text
Implementa la feature <nombre y comportamiento> para Azalea Core. Lee AGENTS.md y sus
instrucciones aplicables. Crea una rama feature/<nombre> desde base/lua y un worktree separado;
conserva sus commits. ALE se instala desde el lock y el bootstrap del repositorio. Indica cualquier
dependencia de otra feature antes de integrarla. Desarrolla y prueba sin modificar la instalación
activa. Documenta en español e inglés funcionamiento, instalación, cambios de cliente y servidor,
SQL, dependencias, pruebas y recuperación, indicando lo que no aplica. Revisa y publica la rama.
Tras mi aprobación, fusiona en server, compila con la caché preparada, verifica imagen y scripts,
despliega conservando recuperación y comprueba arranque, bases, ALE y comportamiento. Indica el
commit, las imágenes, las pruebas realizadas y lo que debo comprobar en el juego.
```

## English

### Branches and development

`master` is the reference core; `base/lua` provides the pinned, reproducible ALE integration;
`feature/<name>` preserves each tutorial's changes and commits; `server` contains approved features.
Keep feature branches published. ALE is external: install and verify the revision in
`azalea/modules.lock.json` with `bash azalea/scripts/bootstrap-ale.sh`.

Create a separate worktree and feature branch from the published `origin/base/lua` as shown above.
Read `AGENTS.md` and its referenced instructions, develop and test there, and do not use the live
installation for development. Document behavior, installation, client and server changes, SQL,
dependencies, tests, compatibility and recovery in both languages; explicitly mark non-applicable
items. Never commit secrets or private database data.

For dependent features, record the prerequisite and its commits. Develop on that feature when
necessary, merge approved prerequisites into `server` first, and preserve both branch histories.

### Release and recovery

Review and test the approved feature, merge it into a clean `server` worktree, resolve conflicts,
test again and publish. Review SQL and client implications; make a current backup and a specific
rollback plan before migrations when needed. Build with `azalea/scripts/build-server-cache.sh`;
its default output only populates the cache. Build and tag the worldserver and authserver runtime
images using the commands above and verify their revisions and IDs. Investigate a `+` revision
marker before claiming a clean build.

Docker mounts Lua scripts from the live installation; compare, back up and deliberately update
the approved scripts, accounting for automatic reload. Preserve previous images and record their
IDs. Tag the new images with the names used by the active Compose configuration, then recreate
only worldserver/authserver with `--no-deps --no-build`. Verify full startup, revision, databases,
ALE, logs, and in-game behavior. Record commit, image IDs and test results.

For rollback, restore the recorded prior image tags and appropriate scripts/configuration, recreate
the services and verify them. Image rollback does not undo SQL migrations. Consult the private
recovery document at the Raspberry backup path above when database recovery is required.

### Reusable Codex request

```text
Implement <feature and behavior> for Azalea Core. Read AGENTS.md and applicable instructions.
Create feature/<name> from base/lua in a separate worktree, preserve its commits, and install ALE
using the pinned lock and bootstrap. Identify feature dependencies. Develop and test without editing
the live installation. Document behavior, installation, client/server changes, SQL, dependencies,
tests and recovery in Spanish and English, including non-applicable items. Review and publish the
feature branch. After my approval, merge into server, build with the prepared cache, verify images
and mounted scripts, deploy with rollback preserved, and check startup, databases, ALE and behavior.
Report the commit, images, tests and anything I must verify in game.
```
