# Tutorial de recompensas diarias para WoW 3.3.5a

Este tutorial muestra cómo crear una ventana, conectarla mediante Lua a AzerothCore
con ALE y guardar una reclamación por personaje. El cliente se distribuye como
un MPQ. El servidor decide los premios y consulta la base de personajes.

**Estado de las pruebas:** la entrega de 5 de oro y el bloqueo posterior se
confirmaron en juego con el cliente anterior. El MPQ, el atajo de teclado, los
demás días y el orbe siguen pendientes de prueba en juego. El MPQ publicado es
experimental y se preparó para `esES`.

## 1. Qué hace y qué se necesita

Una reclamación por personaje y día natural de Madrid, con horario de verano e
invierno. Los días 1 a 13 entregan 5, 10, 20, 50, 100, 200, 500, 1.000,
2.000, 3.000, 5.000, 10.000 y 20.000 de oro. El día 14 entrega un orbe
congelado, objeto `43102`; se repite cada día consecutivo. Si se pierde un día,
la siguiente reclamación vuelve al día 1. Un premio de oro que el core rechace
por el límite de dinero no consume la reclamación.

Se necesita un cliente WoW 3.3.5a esES, un servidor AzerothCore con ALE activo,
acceso a la base de personajes, y el código de esta rama. Los ejemplos Docker
usan el contenedor `ac-database`, la base `acore_characters` y un usuario root
cuya contraseña está en `MYSQL_ROOT_PASSWORD` dentro del contenedor. Si tu
instalación usa otros nombres o credenciales, adapta los comandos.

## 2. Descargar e instalar el cliente MPQ

[Descargar patch-esES-C.MPQ](dist/patch-esES-C.MPQ). En GitHub abre el enlace
y pulsa el icono de descarga del archivo.

1. Cierra completamente WoW. Comprueba que el cliente usa `esES`; en este equipo
   se puede consultar `WTF/Config.wtf`, línea `SET locale "esES"`.
2. Copia el MPQ a `World of Warcraft 3.3.5a/Data/esES/patch-esES-C.MPQ`.
   Si el archivo ya existe, no lo sobrescribas: selecciona una ranura compatible
   y verifica su prioridad en tu instalación.
3. Si habías instalado el addon `AzaleaDailyRewards`, desactívalo o aparta su
   carpeta de `Interface/AddOns`. No cargues dos versiones a la vez.
4. Inicia el juego y abre la ventana con `/diarias` o el botón del minimapa.

El MPQ sustituye `Interface/FrameXML/FrameXML.toc` y añade el Lua de la ventana.
Puede entrar en conflicto con otros parches que sustituyan ese mismo archivo.
El MPQ proporcionado se construyó a partir del `patch-esES-3.MPQ` de esta
instalación; no se ha verificado en otros clientes, idiomas o combinaciones de
parches. Mayús+F12 tampoco se ha confirmado en esta versión. El MPQ por sí
solo no instala el servidor ni crea la tabla.

## 3. Crear y verificar la tabla de personajes

La migración está en [rev_1793200933290635449.sql](../../data/sql/updates/pending_db_characters/rev_1793200933290635449.sql).
Crea una tabla nueva; no altera las tablas existentes:

```sql
CREATE TABLE IF NOT EXISTS `azalea_daily_reward_claim` (
  `character_guid` INT UNSIGNED NOT NULL,
  `madrid_day` INT NOT NULL,
  `reward_day` TINYINT UNSIGNED NOT NULL,
  `reward_money_copper` INT UNSIGNED NOT NULL DEFAULT 0,
  `reward_item_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `reward_item_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `claimed_at_utc` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`character_guid`, `madrid_day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

La clave primaria impide que un mismo personaje tenga dos registros para el
mismo día de Madrid. `reward_day` guarda la posición de la racha; los campos de
premio y `claimed_at_utc` describen la reclamación. `IF NOT EXISTS` evita crear
otra tabla si ya existe, pero **no comprueba ni corrige un esquema distinto**.

### Ejemplo en la Raspberry con Docker

Trabaja desde la raíz de la rama de la feature. Los siguientes comandos son
para Bash en el servidor, no para PowerShell:

```bash
cd /home/azalea/docker/Warcraft/branch-worktrees/daily-rewards
set -o pipefail

# Copia de seguridad de toda la base de personajes antes de aplicar SQL.
docker exec ac-database sh -c \
  'exec env MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump -uroot --single-transaction --routines --triggers acore_characters' \
  | gzip > "acore_characters-antes-diarias-$(date +%Y%m%d-%H%M%S).sql.gz"

# Aplicar el archivo SQL de la rama a la base de personajes.
docker exec -i ac-database sh -c \
  'exec env MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot acore_characters' \
  < data/sql/updates/pending_db_characters/rev_1793200933290635449.sql

# Comprobar el esquema y el número de reclamaciones.
docker exec ac-database sh -c \
  'exec env MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot acore_characters -e "SHOW CREATE TABLE azalea_daily_reward_claim; SELECT COUNT(*) AS reclamaciones FROM azalea_daily_reward_claim;"'
```

Compara `SHOW CREATE TABLE` con el SQL anterior, sobre todo tipos y clave
primaria. Cero reclamaciones es normal en una instalación nueva; después de una
prueba puede haber filas. Estos comandos no enseñan contraseñas. El respaldo se
guarda en el directorio actual: muévelo a tu ubicación de copias protegida.

Para una instalación MySQL sin Docker, usa las credenciales y el nombre de base
de tu entorno. Ejecuta desde la raíz del repositorio y escribe la contraseña en
el prompt, no en el comando:

```bash
mysql -u TU_USUARIO -p TU_BASE_DE_PERSONAJES \
  < data/sql/updates/pending_db_characters/rev_1793200933290635449.sql
mysql -u TU_USUARIO -p TU_BASE_DE_PERSONAJES \
  -e 'SHOW CREATE TABLE azalea_daily_reward_claim; SELECT COUNT(*) FROM azalea_daily_reward_claim;'
```

**Estado específico de Azalea Core:** la tabla ya se creó manualmente en
`acore_characters`. El actualizador automático estaba desactivado y esta
revisión no figuraba en su historial. Antes de habilitarlo, comprueba el esquema
y coordina cómo registrar o aplicar la migración con la política del servidor.
Volver a ejecutar `CREATE TABLE IF NOT EXISTS` no registra por sí solo la revisión
en el actualizador.

## 4. Instalar el script de servidor

El código es [azalea/server/scripts/azalea_daily_rewards.lua](../server/scripts/azalea_daily_rewards.lua).
ALE debe estar instalado, habilitado y configurado para leer su directorio de
scripts. En Azalea Core se instala con el bootstrap fijado en la rama y el
directorio activo se monta en el contenedor. Desarrolla en el worktree de la
feature; integra el cambio aprobado en `server` antes de desplegarlo.

Ejemplo para esta instalación, después de integrar y revisar la rama `server`:

```bash
cd /home/azalea/docker/Warcraft/branch-worktrees/server
source_file=azalea/server/scripts/azalea_daily_rewards.lua
target=/home/azalea/docker/Warcraft/azerothcore-wotlk/lua_scripts/azalea_daily_rewards.lua
test -f "$source_file"
# No se sobrescribe un script existente: haz una copia y compáralo primero.
test ! -e "$target"
install -m 0644 "$source_file" "$target"
```

ALE tiene recarga automática en esta instalación: copiar el archivo puede
activarlo inmediatamente. Si ya existe una versión, guarda una copia y revisa
las diferencias antes de reemplazarla. Comprueba el log de ALE y prueba en juego.
Modificar solo el Lua y el MPQ no requiere compilar C++; si cambias el core,
sigue el procedimiento de compilación y despliegue de tu servidor.

## 5. Cómo funciona la comunicación

1. Al abrir `/diarias`, el cliente envía `STATUS` al propio personaje con el
   prefijo `AZ_DAILY_V1`.
2. Al pulsar Reclamar, envía `CLAIM`. No envía el importe ni decide el premio.
3. `RegisterServerEvent(30)` en ALE comprueba prefijo, canal, emisor y petición;
   obtiene el día y la racha de `azalea_daily_reward_claim`.
4. El servidor entrega el oro con `ModifyMoney` o el objeto con `AddItem`,
   encola el registro con `CharDBExecute` y responde con `STATE` o `ERROR`.
5. El cliente recibe la respuesta y actualiza el mensaje y las casillas.

## 6. Qué archivos y valores enseñar o cambiar

| Parte | Archivo o dato | Qué se cambia |
| --- | --- | --- |
| Cliente MPQ | [AzaleaDailyRewards.lua](../client/AzaleaDailyRewardsMPQ/AzaleaDailyRewards.lua) | `CreateFrame`, casillas, minimapa, textos, iconos y `/diarias`. |
| Importes visibles | Cliente: `goldRewards` | Cambia el texto que ve el jugador; no altera el premio real. |
| Premio real | [Lua de servidor](../server/scripts/azalea_daily_rewards.lua): `gold_rewards` | Oro de los días 1 a 13. Un oro son 10.000 cobres. |
| Día 14 | Servidor: `DailyRewards.reward` | ID `43102` y cantidad `1`. |
| Comunicación | `PREFIX` en ambos archivos | Prefijo `AZ_DAILY_V1`; debe ser igual en cliente y servidor. |
| Fecha y racha | Servidor: `madrid_day` y `next_reward` | Cálculo del día de Madrid, avance, repetición y reinicio. |
| Base | [Migración](../../data/sql/updates/pending_db_characters/rev_1793200933290635449.sql) | Crea la tabla y su clave por personaje y día. |

Ejemplo: para pasar el día 1 de 5 a 25 de oro, cambia el primer valor de
`gold_rewards` en el servidor y el primer valor de `goldRewards` en el cliente.
El primer cambio decide el premio; el segundo actualiza lo que muestra la
ventana. Prueba los cambios en una instalación de pruebas.

## 7. Reconstruir el MPQ tras editar el cliente

Guardar el Lua en Git **no modifica el MPQ ya creado**. Para empaquetar la nueva
versión se proporciona [build_mpq.py](build_mpq.py), que usa la biblioteca de
[AzaleaCore MPQ Studio](https://github.com/AzaleaDevs/AzaleaCore-MPQ-Studio).
Necesitas Python 3.11 o superior y tener instalado ese proyecto y sus
dependencias. El constructor lee el `FrameXML.toc` de un MPQ que le proporciones,
añade el Lua de esta feature, crea un archivo nuevo y comprueba ambos contenidos.

Si aún no tienes MPQ Studio en este equipo, puedes preparar su entorno en
PowerShell. Omite la clonación si ya tienes la carpeta y no la sobrescribas:

```powershell
git clone https://github.com/AzaleaDevs/AzaleaCore-MPQ-Studio.git 'D:\AzaleaDevs\AzaleaCore-MPQ-Studio'
Set-Location 'D:\AzaleaDevs\AzaleaCore-MPQ-Studio'
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e .
```

También necesitas una copia de la rama de la feature en Windows. Puedes obtenerla
desde GitHub; elige una carpeta que no exista y no sobrescribas tu trabajo:

```powershell
git clone --branch feature/daily-rewards https://github.com/AzaleaDevs/azerothcore-wotlk.git 'D:\AzaleaDevs\azerothcore-daily-tutorial'
Set-Location 'D:\AzaleaDevs\azerothcore-daily-tutorial'
```

Desde la raíz de esa copia, un ejemplo con las rutas de este equipo es:

```powershell
$Python = 'D:\AzaleaDevs\AzaleaCore-MPQ-Studio\.venv\Scripts\python.exe'
$BaseMPQ = 'D:\World of Warcraft 3.3.5a\Data\esES\patch-esES-3.MPQ'
$Salida = 'D:\World of Warcraft 3.3.5a\Prueba MPQ recompensas diarias\mi-parche.MPQ'
& $Python 'azalea\daily-rewards\build_mpq.py' `
  --base-mpq $BaseMPQ `
  --client-lua 'azalea\client\AzaleaDailyRewardsMPQ\AzaleaDailyRewards.lua' `
  --output $Salida
```

La carpeta de salida debe existir y el archivo de salida no debe existir; el
constructor no lo sobrescribe. El MPQ base debe ser el que contiene el
`FrameXML.toc` efectivo de tu cliente y sus parches: **no asumas que siempre
es `patch-esES-3.MPQ`**. Revisa también otros parches que puedan reemplazarlo.
Prueba el MPQ nuevo en un cliente aislado; usa después un nombre compatible en
`Data/esES`. La construcción verificada del ejemplo produjo el SHA-256
`a7e120e1a202550f588f1676132f400f21a94e7476d40ed4f0ea87a3cb813059`.

## 8. Prueba en juego y recuperación

1. Con servidor y tabla activos, inicia el cliente con el MPQ y abre `/diarias`.
2. Anota el dinero de un personaje que no haya reclamado hoy. Pulsa Reclamar en
   día 1: debe recibir 5 de oro y el botón debe quedar bloqueado para ese día.
3. Cierra y vuelve a abrir la ventana; después vuelve a entrar con el personaje
   y comprueba que sigue bloqueado. Repite con otro personaje para verificar que
   el progreso es independiente. Prueba días posteriores y orbe antes de
   presentarlos como verificados.
4. Si la ventana no abre, comprueba ubicación, idioma, prioridad del MPQ y que
   no exista una segunda copia. Si espera al servidor, revisa ALE, la tabla y
   la coincidencia del prefijo. Consulta los registros para errores concretos.

Para desactivar, cierra WoW y retira solo el MPQ de esta feature; conserva una
copia. En el servidor, retira el script aprobado de la carpeta activa y recarga
ALE según tu procedimiento. Conserva la tabla si quieres mantener el progreso.
Borrar filas reinicia la racha y no deshace premios ya entregados; restaurar una
base completa también puede sobrescribir progresos posteriores a la copia.

**Limitación del tutorial:** la entrega en memoria y el registro asíncrono no
son una única transacción. Un fallo o reinicio puede perder o repetir premios.
La memoria de sesión ayuda frente a clics repetidos, pero no garantiza seguridad
ante fallos. Consulta también la [guía de la feature](../../doc/azalea/features/daily-rewards.md);
su sección de cliente describe la versión anterior de addon, no este MPQ.

## English

This tutorial uses an experimental [esES client MPQ](dist/patch-esES-C.MPQ), an
[ALE server script](../server/scripts/azalea_daily_rewards.lua), and the
[characters database migration](../../data/sql/updates/pending_db_characters/rev_1793200933290635449.sql).
The MPQ replaces `FrameXML.toc`, may conflict with other patches, and has not
yet been verified in game. Copy it into `Data/esES` with WoW closed and disable
any previous addon copy. The MPQ alone does not install the server or database.

Back up the characters database, apply the migration using the Docker or MySQL
commands in section 3, and verify `SHOW CREATE TABLE`. `IF NOT EXISTS` does not
repair an incompatible existing schema or record the migration with the SQL
updater. The table was manually created in Azalea Core; its updater was disabled.

Install the reviewed ALE script as in section 4; automatic Lua reload can make
it effective immediately. Customize server `gold_rewards` and the day-14 item,
then update client `goldRewards` to match. Edit the [MPQ client Lua](../client/AzaleaDailyRewardsMPQ/AzaleaDailyRewards.lua)
and rebuild with [build_mpq.py](build_mpq.py) as shown in section 7. Select the
actual effective `FrameXML.toc` from your client; other locales and patch
combinations need separate verification.

First-day delivery was confirmed with the previous client version; test the MPQ,
later days and the repeating orb in game. Reward delivery and asynchronous
claim recording are not atomic; a failure or restart may lose or repeat rewards.
To remove the feature, remove only its client MPQ and ALE script, and retain the
table if progress must be preserved.
