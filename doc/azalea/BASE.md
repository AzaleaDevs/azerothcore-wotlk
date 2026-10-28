# Base Lua de Azalea Core / Azalea Core Lua baseline

## Español

- Core de partida: `e72b2219697d098f861e91d6c52064bfe20644c9`.
- Motor: ALE, repositorio `https://github.com/azerothcore/mod-ale.git`.
- Revisión fijada: `bd74eae623ca63154d3eb49e1d187e872ef13370`.
- Cliente objetivo: WoW 3.3.5a (12340).
- `master` añade documentación, sin personalizaciones de juego.
- Esta rama NO contiene los saludos personalizados del tutorial.

El módulo se instala como repositorio externo en `modules/mod-ale`; su revisión se guarda en
`azalea/modules.lock.json`, no se confía en un `master` móvil. El script no modifica un módulo existente
si está sucio o no coincide con el commit fijado. El core no versiona credenciales ni datos extraídos.

```bash
bash azalea/scripts/bootstrap-ale.sh
cp azalea/docker-compose.lua.example.yml docker-compose.override.yml
mkdir -p lua_scripts
```

Si ya existe un override, fusionar sus opciones manualmente: NO sobrescribir configuración real.
El override de ejemplo habilita la recarga automática de Lua para desarrollo y monta `lua_scripts`.
No conecta automáticamente una carpeta de desarrollo al servidor en producción.

Ejemplo: `azalea/examples/login_example.lua`. Para probarlo, copiarlo a `lua_scripts/` del entorno
de pruebas; registra el evento de login 3 y muestra un saludo. No se instala automáticamente para
evitar mensajes adicionales al servidor. Retirarlo al terminar. No se necesitan cambios de cliente.

La preparación inicial requiere compilar el motor en worldserver. El Dockerfile original incorpora
ccache mediante BuildKit, pero no conserva explícitamente el árbol de objetos de Ninja entre cambios
de código. La compilación incremental persistente y el despliegue se prepararán en el paso 3: aún
no se han implementado ni probado. Un worktree usa un archivo `.git`, mientras que el Dockerfile
original lo monta como directorio: no construir estos worktrees con ese Dockerfile sin adaptarlo.

Una copia nueva también requiere configuración privada, bases de datos y datos extraídos del cliente.
Consultar la documentación de AzerothCore para su instalación; este ejemplo no contiene contraseñas.

## English

Baseline: core `e72b2219697d098f861e91d6c52064bfe20644c9`, ALE
`bd74eae623ca63154d3eb49e1d187e872ef13370`, client WoW 3.3.5a build 12340.
This branch has no custom tutorial greetings. ALE remains an external repository under
`modules/mod-ale`; its exact revision is recorded in `azalea/modules.lock.json`.

Run `bash azalea/scripts/bootstrap-ale.sh`. Copy the sample Compose override only when no local
override exists; otherwise merge its settings manually. Credentials, databases and extracted client
data must be supplied privately. The sample enables development-only Lua autoreload and mounts
`lua_scripts`. Copy `azalea/examples/login_example.lua` into the test server's script directory to
try the login hook, then remove it. No client changes are required.

The bootstrap refuses dirty or mismatched existing modules. A first build must include ALE.
The upstream Dockerfile uses BuildKit ccache but does not explicitly persist the Ninja object tree.
Persistent incremental builds and deployment remain step 3, not yet implemented or validated.
Do not build these worktrees with the original Dockerfile unchanged: their `.git` is a file, while
the original build expects a repository directory. No live deployment is performed by this baseline.
