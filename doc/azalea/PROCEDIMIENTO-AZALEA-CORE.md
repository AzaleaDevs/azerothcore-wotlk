# Procedimiento de Azalea Core / Azalea Core workflow

Versión 3 (2026-11-01).

## Español

### Ramas

| Rama | Función |
| --- | --- |
| `master` | Core de AzerothCore de referencia. No se trabaja sobre ella. |
| `base/lua` | AzerothCore + ALE fijado. Es el punto de partida de toda feature y el estado al que volver. |
| `feature/<nombre>` | Una rama por tutorial. Muestra a la gente qué código cambia. Se publica siempre. |
| `server` | Lo que corre en la Raspberry: `base/lua` + las features mergeadas. |

ALE es un repositorio externo: `azalea/modules.lock.json` fija su revisión y
`azalea/scripts/bootstrap-ale.sh` la instala y la valida.

**Lo importante de una feature es su diff de código respecto a `base/lua`**
(`git diff origin/base/lua...origin/feature/<nombre>`), que es lo que verá la gente. El número de
commits y su historial no importan, siempre que el diff sea limpio y solo contenga la feature.

**Las features no dependen unas de otras.** Todas parten de `base/lua`. Si una parece necesitar otra,
se avisa antes de empezar y se diseña para que sea independiente.

### Carpetas en la Raspberry

- Instalación activa: `/home/azalea/docker/Warcraft/azerothcore-wotlk`. Contiene `docker-compose.yml`,
  `docker-compose.override.yml`, configuración, datos y `lua_scripts/`. Está en un HEAD separado: **no
  cambiar su rama ni desarrollar en ella**.
- Worktrees: `/home/azalea/docker/Warcraft/branch-worktrees/` (`master`, `base-lua`, `server` y uno
  por feature).
- Contexto de compilación independiente: `/home/azalea/docker/Warcraft/build-contexts/server`.

### Docker compose

Es el `docker-compose.yml` estándar de AzerothCore, igual que en `base/lua`. El
`docker-compose.override.yml` monta `./lua_scripts` en el worldserver y activa
`AC_ALE_AUTO_RELOAD_INTERVAL=1`. Servicios: `ac-database` (MySQL 8.4), `ac-db-import`,
`ac-worldserver`, `ac-authserver` y `ac-client-data-init`.

- **El SQL lo aplica `ac-db-import`, no `ac-database`.** Su imagen copia `data/` al construirse y
  aplica el SQL de `data/sql/updates/pending_db_*/` que lleva dentro; se ejecuta una vez y termina con
  `Exited (0)`. No hace falta reiniciar MySQL: hay que reconstruir la imagen de `db-import` desde
  `server` y lanzarla antes de recrear el worldserver.
- `docker compose up -d --build` en la instalación activa compilaría su HEAD separado, no `server`.
  Por eso se compila desde `server` y las imágenes se etiquetan con los nombres que usa el compose
  (`acore/ac-wotlk-*:master`). Esa etiqueta `master` es solo un nombre de imagen, no la rama.
- El Lua en ejecución se monta desde `lua_scripts/` de la instalación activa, no desde la imagen.
  Con la recarga automática, los cambios se aplican al momento.

### Flujo de una feature

1. **Crear la rama y el worktree** desde la revisión publicada de `base/lua`:

   ```bash
   git -C /home/azalea/docker/Warcraft/branch-worktrees/base-lua fetch origin
   git -C /home/azalea/docker/Warcraft/branch-worktrees/base-lua worktree add \
     -b feature/mi-feature /home/azalea/docker/Warcraft/branch-worktrees/mi-feature origin/base/lua
   cd /home/azalea/docker/Warcraft/branch-worktrees/mi-feature
   bash azalea/scripts/bootstrap-ale.sh
   git push -u origin feature/mi-feature
   ```

2. **Desarrollar** en el worktree, respetando `AGENTS.md` y las instrucciones que referencia. Lua de
   servidor en `lua_scripts/`, C++ si hace falta, SQL solo en `data/sql/updates/pending_db_*/` (ver
   reglas del SQL). Cliente: código en `azalea/client/<Feature>MPQ/`. Publicar la rama.
3. **Validar que se puede probar**, sin tocar el servidor: tests de `azalea/<feature>/tests/`,
   sintaxis de Lua, revisión del SQL y, si hay C++, compilación con la caché. Solo pasa a `server`
   lo que está validado.
4. **Pasar a `server`:**

   ```bash
   cd /home/azalea/docker/Warcraft/branch-worktrees/server
   git fetch origin
   git status --short
   git merge --no-ff origin/feature/mi-feature
   git push origin server
   ```

   No continuar si hay conflictos sin resolver o cambios inesperados.
5. **Desplegar** `server` (ver "Despliegue").
6. **Prueba del usuario en el servidor.** Sin visto bueno no se hace documentación ni guion: se
   corrige en la feature, se valida y se vuelve a pasar a `server` (pasos 3 a 5).
7. **Con el visto bueno:** README en español e inglés (`azalea/<feature>/README.md` y
   `doc/azalea/features/<feature>.md`) y MPQ de descarga si hay cambios de cliente
   (`azalea/<feature>/dist/`, con `.gitattributes` para conservar sus bytes). Se publican en la
   feature y se mergean de nuevo en `server`. Si solo cambian docs o MPQ, no hace falta redesplegar.

### Reglas del SQL de una feature

- Solo en `data/sql/updates/pending_db_<base>/`. Tablas propias con prefijo `azalea_`
  (`azalea_<feature>_…`). No modificar ni borrar tablas del core.
- **Idempotente**, para que relanzarlo no falle ni duplique datos:
  - `CREATE TABLE IF NOT EXISTS`.
  - Columnas o índices nuevos solo tras comprobar en `information_schema` que no existen.
  - Datos con claves explícitas: `DELETE … WHERE` + `INSERT`, o `INSERT … ON DUPLICATE KEY UPDATE`.
- Antes de aplicarlo, comprobar si las tablas ya existen y con qué estructura; después, que se han
  creado y que `ac-db-import` terminó con código 0.
- Cada feature con SQL lleva `azalea/<feature>/sql/uninstall.sql`, fuera de `pending_*` para que no
  se aplique solo, para desactivarla o descartarla.
- **Backup de las tablas afectadas antes de aplicar SQL.** Volver a una imagen anterior no deshace
  el SQL.

### Despliegue

1. Preparar y compilar desde `server`, limpio y con ALE fijado (ver `doc/azalea/BUILD.md`):

   ```bash
   cd /home/azalea/docker/Warcraft/branch-worktrees/server
   bash azalea/scripts/build-server-cache.sh
   ```

2. Construir las imágenes con el commit real y una etiqueta nueva. `db-import` solo es necesaria si
   hay SQL nuevo, pero construirla siempre no hace daño:

   ```bash
   revision=$(git rev-parse HEAD)
   corto=$(git rev-parse --short=12 HEAD)
   contexto=/home/azalea/docker/Warcraft/build-contexts/server
   for target in worldserver authserver db-import; do
     docker buildx build --file "$contexto/apps/docker/Dockerfile" \
       --build-arg "CACHEBUST=$revision" --target "$target" \
       --tag "azalea-core/$target:server-$corto" --load "$contexto"
   done
   docker run --rm --entrypoint /azerothcore/env/dist/bin/worldserver \
     "azalea-core/worldserver:server-$corto" --version
   ```

   El signo `+` en la versión indica que Git detectó diferencias en el contexto de compilación:
   investigarlo antes de atribuir el binario a un commit limpio.
3. Guardar la recuperación: etiquetar las imágenes que corren ahora como
   `azalea-core/<servicio>:pre-<feature>-<fecha>` y anotar sus IDs. Si hay SQL, hacer backup de las
   tablas afectadas. Copiar los scripts Lua activos que se vayan a cambiar.
4. Aplicar el SQL, si lo hay:

   ```bash
   docker tag "azalea-core/db-import:server-$corto" acore/ac-wotlk-db-import:master
   cd /home/azalea/docker/Warcraft/azerothcore-wotlk
   docker compose up --no-deps --no-build --force-recreate \
     --exit-code-from ac-db-import ac-db-import
   ```

   Debe terminar con código 0. Comprobar que las tablas existen.
5. Copiar a `lua_scripts/` de la instalación activa solo los scripts de la feature que vienen de
   `server`. No reemplazar scripts ajenos a la feature.
6. Etiquetar y recrear el worldserver y el authserver:

   ```bash
   docker tag "azalea-core/worldserver:server-$corto" acore/ac-wotlk-worldserver:master
   docker tag "azalea-core/authserver:server-$corto" acore/ac-wotlk-authserver:master
   cd /home/azalea/docker/Warcraft/azerothcore-wotlk
   docker compose up -d --no-deps --no-build ac-worldserver ac-authserver
   ```

   Si cambia la configuración del compose, comprobar antes los nombres con
   `docker compose config --images`.
7. Verificar: imágenes en ejecución, worldserver en `ready`, revisión en los logs, conexión a las tres
   bases, ALE y scripts cargados, sin errores. Anotar commit, IDs de imágenes y resultado. Un
   contenedor `Up` no equivale a mundo listo.

### Recuperación

- **Volver a la versión anterior:** volver a etiquetar las imágenes `pre-<feature>-<fecha>` con los
  nombres del compose, restaurar los scripts Lua copiados y recrear `ac-worldserver` y
  `ac-authserver`. Si hubo SQL, aplicar `uninstall.sql` o restaurar el backup de las tablas.
- **Descartar una feature ya mergeada:** sacar su merge de `server` (revert del merge, o reset del
  commit anterior con force push si se acuerda), aplicar su `uninstall.sql`, quitar sus scripts Lua
  y redesplegar. Hacer antes un backup privado (bundle de git, Lua y volcado de las tablas).
- La recuperación histórica y los respaldos están en `/home/azalea/backups/azalea-core/`. Contienen
  información privada: no publicarlos.

### Instrucción reutilizable

```text
Implementa la feature <nombre y comportamiento> para Azalea Core. Lee AGENTS.md y sus instrucciones.
Crea feature/<nombre> desde base/lua en un worktree separado y publícala; el diff respecto a base/lua
debe mostrar limpio lo que cambia. Debe ser independiente de otras features. El SQL va solo en
pending_db_*, con tablas azalea_, idempotente y con uninstall.sql. Valida que se puede probar,
mergea en server, haz push y despliega (db-import si hay SQL, backup antes, recuperación guardada).
Verifica arranque, bases, ALE y logs, y dame los casos de prueba. Con mi visto bueno, añade README
en español e inglés y el MPQ si hay cambios de cliente, y vuelve a mergear en server.
```

## English

### Branches

`master` is the reference core and is not worked on. `base/lua` is AzerothCore plus pinned ALE: every
feature starts from it. `feature/<name>` holds one tutorial and is always published; what matters is
its code diff against `base/lua` (`git diff origin/base/lua...origin/feature/<name>`), not its commit
history. `server` is what runs on the Raspberry: `base/lua` plus merged features. Features must not
depend on each other.

### Docker compose

The live installation uses the stock AzerothCore `docker-compose.yml` (same as `base/lua`) plus an
override that mounts `./lua_scripts` and sets `AC_ALE_AUTO_RELOAD_INTERVAL=1`. SQL is applied by
`ac-db-import`, whose image bakes in `data/` and runs once: rebuild it from `server` and run it before
recreating the worldserver; MySQL does not need a restart. `docker compose up --build` in the live
folder would build its detached HEAD, not `server`, so images are built from `server` and tagged
with the compose names. Live Lua is mounted from the live `lua_scripts/`.

### Feature flow

Create `feature/<name>` and its worktree from `origin/base/lua`, bootstrap ALE and publish it. Develop
following `AGENTS.md`. Validate without touching the server (tests, Lua syntax, SQL review, C++ cache
build). Merge into `server`, push and deploy. The user tests on the server; without approval, fix on
the feature and repeat. After approval, add the Spanish/English README and the client MPQ if needed,
publish them on the feature and merge into `server` again (no redeploy for docs/MPQ only).

### SQL rules

Only in `pending_db_*`, using `azalea_`-prefixed tables and never altering core tables. SQL must be
idempotent (`CREATE TABLE IF NOT EXISTS`, `information_schema` checks, explicit keys with
`DELETE`+`INSERT` or `ON DUPLICATE KEY UPDATE`). Check tables before and after, ship an
`uninstall.sql` outside `pending_*`, and back up affected tables first: an image rollback does not
undo SQL.

### Deployment and recovery

Run `azalea/scripts/build-server-cache.sh` from `server`, build `worldserver`, `authserver` and
`db-import` images tagged `server-<short>`, and investigate any `+` revision marker. Tag the running
images as `pre-<feature>-<date>`, back up affected tables and Lua, run `ac-db-import` with
`--exit-code-from` when there is SQL, copy only the feature's Lua scripts, then retag and recreate
`ac-worldserver` and `ac-authserver` with `--no-deps --no-build`. Verify readiness, revision,
databases, ALE and logs, and record commit and image IDs.

To roll back, retag the `pre-*` images, restore Lua and recreate the services; undo SQL with
`uninstall.sql` or the table backup. To discard a merged feature, take a private backup, remove its
merge from `server`, apply `uninstall.sql`, remove its Lua and redeploy. Private backups live in
`/home/azalea/backups/azalea-core/` and must never be published.
