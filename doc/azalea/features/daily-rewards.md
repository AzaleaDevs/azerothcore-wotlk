# Recompensas diarias / Daily rewards

## Espanol

**Estado de desarrollo:** tutorial en pruebas; no integrado ni desplegado. El addon
y el script ALE permiten una reclamacion por personaje y dia natural de Madrid,
incluido el cambio de horario. Si se pierde un dia, la racha vuelve al dia 1.
Los dias 1 a 13 entregan 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 3000,
5000, 10000 y 20000 de oro. El dia 14 entrega un orbe congelado (43102), que
se repite cada dia consecutivo. El servidor determina los premios y rechaza el
oro que supere 2147483646 cobres. Si no hay espacio, no reclama el orbe.

### Limites de este tutorial

Se eligio una implementacion sencilla: ALE entrega el premio en memoria y
CharDBExecute registra la reclamacion asincronamente. Ambas acciones NO forman
una transaccion. Un fallo de base de datos, una recarga de Lua o un reinicio
antes de guardar el personaje o registrar la reclamacion puede perder el premio,
perder el registro o permitir una repeticion. No usar como sistema economico
seguro. La cache de la sesion evita los dobles clics durante la escritura pendiente,
pero no sobrevive a una recarga o un reinicio.

### Que modificar

- En azalea/server/scripts/azalea_daily_rewards.lua, modificar la tabla
  gold_rewards para los dias 1 a 13, y el ID 43102 y la cantidad en reward para
  el dia 14. Un oro equivale a 10000 cobres. Este script contiene su copia de
  las reglas de calendario; daily_logic.lua y sus pruebas son la referencia.
- En azalea/client/AzaleaDailyRewards/AzaleaDailyRewards.lua, actualizar tambien
  goldRewards, los iconos y los textos visibles. Son informativos: el servidor
  decide lo que se entrega. El prefijo de comunicacion AZ_DAILY_V1 debe coincidir
  en cliente y servidor.
- La tabla azalea_daily_reward_claim guarda GUID, dia de Madrid, dia de racha,
  premio y hora UTC. La migracion esta en pending_db_characters. Esta tabla se
  creo manualmente vacia en acore_characters; el actualizador no tiene registrada
  la revision. CREATE TABLE IF NOT EXISTS permite repetir la creacion, pero se
  debe coordinar el registro y comprobar el esquema antes de desplegar.

### Instalacion y retirada

Publicar la rama revisada, integrarla en server conforme al procedimiento de
Azalea Core y confirmar el montaje real de scripts ALE. Copiar deliberadamente
solo azalea_daily_rewards.lua a la carpeta de scripts activa, conservando copia
previa y teniendo en cuenta la recarga automatica. Copiar la carpeta
AzaleaDailyRewards a Interface/AddOns del cliente y reiniciar el juego.
No es necesario compilar C++ para este script Lua. Abrir con /diarias; Mayus+F12
se asigna solo si esta libre. La demo /diariasdemo es independiente.

Para retirar, quitar el script activo y el addon y reiniciar o recargar segun
corresponda. Conservar la tabla para mantener el historial; borrar filas o la
tabla reinicia el progreso y no revierte oro ni objetos entregados. Un rollback
de imagen no revierte cambios SQL. No borrar datos sin respaldo.

### Pruebas

test_tutorial_service.lua simula ALE y la base para primer dia, repeticion,
limite, avance, orbe repetible y reinicio de racha. test_daily_logic.lua cubre
calendario y cambio de horario. No son una prueba del cliente ni del servidor
real, ni demuestran seguridad ante fallos. Probar tambien en entorno aislado y
dentro del juego antes del despliegue.

## English

**Development status:** tutorial under test; not integrated or deployed. The
addon and ALE script award one claim per character per Madrid calendar day,
including DST. Missing a day resets the streak. Days 1 to 13 award 5, 10, 20,
50, 100, 200, 500, 1000, 2000, 3000, 5000, 10000 and 20000 gold. Day 14
awards Frozen Orb 43102 and repeats while the streak continues. The server
chooses rewards, rejects gold above 2147483646 copper and rejects an orb if
there is no inventory space.

### Tutorial limitations

ALE changes the player's in-memory reward and CharDBExecute writes the claim
asynchronously. These operations are NOT atomic. A database failure, Lua reload
or restart before the character and claim are saved can lose a reward or claim,
or allow a repeated reward. This is not a crash-safe economy system. The session
cache prevents repeated clicks while the write is pending, but is lost on reload
or restart.

### Customization

Edit gold_rewards and the item ID/count in
azalea/server/scripts/azalea_daily_rewards.lua. One gold is 10000 copper.
The script contains its own calendar rules, with daily_logic.lua as the tested
reference. Update goldRewards, icons and visible text in the client addon too:
the client display is informational and the server chooses the actual reward.
The AZ_DAILY_V1 message prefix must match on both sides.

The pending characters migration creates the claim ledger. Its empty table was
manually created in live acore_characters and the updater has not recorded the
revision. Inspect the schema and coordinate the idempotent migration with the
updater before deployment.

### Install, test and rollback

Review and publish the feature, integrate into server using the Azalea workflow,
check the actual ALE script mount, preserve any previous script and install only
the intended script. ALE auto-reload can apply it immediately. Copy the addon
folder to Interface/AddOns and restart the game. No C++ rebuild is needed for
this Lua script. Open with /diarias; Shift+F12 is assigned only if free.
The /diariasdemo addon is separate.

Remove the active script and addon to disable; retain the table to preserve
history. Deleting rows or the table resets progress but does not undo rewards.
Image rollback does not undo SQL. Back up before deleting data.

The Lua tests simulate ALE and the database, including repeated claims, the
money cap, streaks and the repeating orb. Calendar tests cover DST. They do not
test real client/server behavior or crash safety; test in isolation and in game
before deployment.
