# Recompensas diarias para WoW 3.3.5a

Ejemplo de una ventana de recompensas para Azalea Core. La versión de cliente se
distribuye como un **MPQ**, sin instalar una carpeta en `Interface/AddOns`.
El código de cliente, el script ALE de servidor y la migración SQL quedan en esta
rama para poder estudiarlos y modificarlos.

## Descargar el MPQ para esES

**Estado: experimental y pendiente de prueba en el juego.**
[Descargar patch-esES-C.MPQ](dist/patch-esES-C.MPQ).

1. Cierra WoW y comprueba que tu cliente utiliza `esES`.
2. Copia el archivo a `World of Warcraft 3.3.5a/Data/esES/`.
3. Si ya existe un archivo con ese nombre, no lo sobrescribas. Coordina un nombre
   y una prioridad de parche compatibles con tu instalación.
4. Si instalaste previamente el addon `AzaleaDailyRewards`, desactívalo o retira
   su carpeta de `Interface/AddOns` para no cargar dos copias.
5. Abre el juego y usa `/diarias` o el botón junto al minimapa.

Este parche se construyó a partir de `FrameXML.toc` de un cliente esES 3.3.5a
y carga el Lua desde `Interface/FrameXML`. Al sustituir ese índice de interfaz,
puede entrar en conflicto con otros parches que también lo modifiquen. La
compatibilidad con otras instalaciones, idiomas y parches no está confirmada.
El atajo Mayús+F12 en esta versión del MPQ está pendiente de prueba en juego.

**El MPQ solo instala el cliente.** Para que funcione la entrega se necesita
también el script ALE y la tabla de personajes en el servidor.

## Código del cliente

- [Lua exacto incluido en el MPQ](../client/AzaleaDailyRewardsMPQ/AzaleaDailyRewards.lua):
  crea la ventana de 14 casillas, el botón del minimapa, `/diarias` y los mensajes
  que intercambia con el servidor.
- `goldRewards` controla los importes visibles; `MONEY_ICON` y `ORB_ICON`, los
  iconos. Cambiar solo estos datos no modifica el premio real.
- `AZ_DAILY_V1` es el prefijo de comunicación y debe coincidir con el servidor.
- La carpeta [AzaleaDailyRewards](../client/AzaleaDailyRewards/) conserva la
  versión anterior como código de referencia. No es necesario instalarla para
  probar el MPQ y no debe cargarse a la vez.

## Código del servidor y base de datos

- [Script ALE de servidor](../server/scripts/azalea_daily_rewards.lua): valida la
  petición, calcula el día de Madrid, entrega la recompensa y registra la
  reclamación. Cambia `gold_rewards` para los días 1 a 13; cambia el ID y la
  cantidad en `DailyRewards.reward` para el día 14. Un oro son 10.000 cobres.
- [Migración SQL](../../data/sql/updates/pending_db_characters/rev_1793200933290635449.sql):
  crea `azalea_daily_reward_claim` en la base de personajes. La clave combina
  personaje y día natural de Madrid. Guarda día de racha, premio y hora UTC.
- En Azalea Core la tabla ya se creó manualmente. El actualizador automático está
  desactivado y la revisión no figuraba registrada; coordina la migración con el
  actualizador antes de activarlo. No se modifica ninguna tabla existente.
- [Guía completa](../../doc/azalea/features/daily-rewards.md): reglas, pruebas,
  instalación, limitaciones y recuperación. Su sección de instalación del addon
  describe la versión anterior; para el cliente MPQ sigue este README.

La entrega y el registro asíncrono no son una sola transacción. Un fallo o
reinicio puede perder o repetir la recompensa. El día 1 se confirmó con la
versión anterior de cliente; el MPQ y los días siguientes requieren prueba real.

## English

The experimental [esES MPQ download](dist/patch-esES-C.MPQ) loads the client UI
from `FrameXML`; no addon folder is required. Close the game, copy it into
`Data/esES`, avoid overwriting an existing patch and disable any previous addon
copy. This MPQ replaces a client UI index and can conflict with other patches;
other locales and the keyboard shortcut have not been verified. It is not yet
confirmed in game.

The [exact client Lua](../client/AzaleaDailyRewardsMPQ/AzaleaDailyRewards.lua)
is published for inspection. The [ALE server script](../server/scripts/azalea_daily_rewards.lua)
authoritatively chooses and grants rewards. The [SQL migration](../../data/sql/updates/pending_db_characters/rev_1793200933290635449.sql)
creates the per-character, per-Madrid-day claim table. The table already exists
in Azalea Core and the updater is disabled; coordinate the migration before
enabling it. Delivery and asynchronous claim recording are not atomic.
