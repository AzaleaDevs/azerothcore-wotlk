# Compilación de server / Building server

## Español

La instalación activa no se utiliza para desarrollar ni compilar. El script
`azalea/scripts/build-server-cache.sh` solo acepta la rama `server` limpia y crea un clon de
compilación independiente en:

```text
/home/azalea/docker/Warcraft/build-contexts/server
```

El clon resuelve la incompatibilidad entre los worktrees, cuyo `.git` es un archivo, y el
Dockerfile original, que necesita montar un directorio `.git`. Antes de compilar, el script
materializa ALE tanto en el worktree como en el clon y exige la revisión fijada en
`azalea/modules.lock.json`.

BuildKit conserva dos cachés independientes:

- `/ccache`: resultados del compilador.
- `/azerothcore/build`: configuración y objetos de Ninja, con el identificador
  `azalea-acore-ninja` y acceso bloqueado para impedir dos compilaciones simultáneas.

Primera compilación de comprobación, sin crear ni desplegar imágenes de ejecución:

```bash
cd /home/azalea/docker/Warcraft/branch-worktrees/server
AZALEA_CACHEBUST=verification-1 bash azalea/scripts/build-server-cache.sh
```

Segunda pasada para verificar la reutilización de objetos:

```bash
AZALEA_CACHEBUST=verification-2 bash azalea/scripts/build-server-cache.sh
```

Cambiar `CACHEBUST` obliga a ejecutar de nuevo CMake y Ninja, sin eliminar sus cachés. La segunda
pasada debe mostrar que Ninja no recompila objetos que no hayan cambiado. No utilizar `--no-cache`:
invalida las capas de BuildKit y no es necesario para comprobar la caché persistente.

Variables opcionales:

- `AZALEA_BUILD_CONTEXT`: ubicación del clon independiente.
- `AZALEA_BUILD_TARGET`: target del Dockerfile; por defecto `build`.
- `AZALEA_BUILD_OUTPUT`: salida de Buildx; por defecto `type=cacheonly`.
- `AZALEA_CACHEBUST`: valor controlado para volver a ejecutar el paso de compilación.

## English

The live installation is never used for development or builds. The build script only accepts a
clean `server` branch and creates an independent clone at
`/home/azalea/docker/Warcraft/build-contexts/server`. This gives the Dockerfile a real `.git`
directory instead of a worktree gitfile. It materializes and verifies the pinned ALE revision in
both the worktree and build clone before building.

BuildKit persistently caches compiler results at `/ccache` and Ninja's configuration and objects at
`/azerothcore/build` (`azalea-acore-ninja`, locked against concurrent builds). Run the two commands
above with different `AZALEA_CACHEBUST` values to force CMake/Ninja to execute and demonstrate that
unchanged objects are reused. Do not use `--no-cache` for normal builds.
