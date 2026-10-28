# Recompensas diarias / Daily rewards

## Español

Ejemplo para WoW 3.3.5a y Azalea Core con una ventana de 14 días. El addon
muestra la interfaz; el servidor ALE valida las peticiones, entrega el premio y
guarda el progreso por personaje. El primer día entrega 5 de oro y ya ha sido
probado en el juego. Los días posteriores y el orbe necesitan pruebas en juego.

### Descargar el addon

Descarga [AzaleaDailyRewards.zip](dist/AzaleaDailyRewards.zip), extrae la carpeta
`AzaleaDailyRewards` en `World of Warcraft 3.3.5a/Interface/AddOns/` y reinicia
el cliente. Actívalo en Accesorios y abre la ventana con `/diarias`.

El ZIP **solo instala el cliente**. Para que entregue premios necesitas además
instalar el script ALE y la tabla de la base de personajes en un servidor
compatible. Sin el servidor el addon esperará una respuesta.

- Código del addon: [azalea/client/AzaleaDailyRewards](../client/AzaleaDailyRewards/).
- Script servidor: [azalea/server/scripts/azalea_daily_rewards.lua](../server/scripts/azalea_daily_rewards.lua).
- Migración de personajes: [rev_1793200933290635449.sql](../../data/sql/updates/pending_db_characters/rev_1793200933290635449.sql).
- Guía de funcionamiento, configuración, instalación y recuperación:
  [documentación completa](../../doc/azalea/features/daily-rewards.md).

Los importes reales se cambian en `gold_rewards` del script de servidor;
`goldRewards` del addon solo cambia el texto visible. El objeto del día 14 se
configura en `DailyRewards.reward`. La fecha usa la medianoche de Madrid,
incluido el cambio de hora.

**Limitación del ejemplo:** la entrega y el registro asíncrono no forman una sola
transacción. Un fallo o reinicio puede perder o repetir una recompensa.

### MPQ

El paquete ZIP es la opción verificada para el addon. Un MPQ no equivale
automáticamente a instalar una carpeta de addon en 3.3.5a; una opción que
modifique la interfaz interna debe evaluarse por separado, comprobar compatibilidad
con otros parches y probarse en un cliente real antes de publicarla como funcional.

## English

A 14-day tutorial feature for WoW 3.3.5a and Azalea Core. The client addon
displays the interface; an ALE server script validates requests, awards rewards
and records per-character progress. The first-day 5-gold claim was confirmed in
game. Later days and the orb still require in-game verification.

[Download the client addon ZIP](dist/AzaleaDailyRewards.zip), extract
`AzaleaDailyRewards` under the client's `Interface/AddOns/`, restart and use
`/diarias`. The ZIP only installs the client: the server script and characters
database table are also required. See the [full documentation](../../doc/azalea/features/daily-rewards.md)
for configuration, installation and rollback.

Reward amounts are authoritative in the server's `gold_rewards`; the addon's
`goldRewards` is display-only. The server uses Europe/Madrid calendar days.
Reward delivery and asynchronous ledger insertion are not atomic, so a failure
or restart can lose or duplicate a reward. An MPQ distribution requires
separate compatibility and in-game verification.
