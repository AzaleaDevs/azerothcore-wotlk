# Recompensas diarias / Daily rewards — trabajo en curso

## Español

**Estado: incompleto. No instalar, integrar en `server` ni usar con personajes reales.**
La interfaz y las reglas puras están preparadas, pero falta implementar y probar el servicio
autoritativo del servidor, persistencia y entrega segura de recompensas. Sin él, el addon solo
mostrará «Esperando respuesta del servidor». No se han modificado el servidor ni el cliente activos.

### Requisitos acordados

- Progreso independiente por personaje, una reclamación por día de calendario de Madrid.
- La medianoche española cambia entre UTC+1 y UTC+2 según horario de verano.
- Días 1–13: dinero, con cantidades provisionales aún por definir. Día 14: un orbe congelado
  (`item_template.entry = 43102`, icono `Spell_Frost_FrozenCore`).
- Si se pierde un día, la siguiente reclamación vuelve al día 1. Tras alcanzar el día 14, se
  reclama otro orbe cada día consecutivo hasta perder la racha.
- Ventana central de 14 casillas con un botón de reclamar por casilla; la lógica y autorización
  de recompensas corresponden exclusivamente al servidor, nunca al addon.
- `Mayús+F12` solo se asigna si no existe ninguna tecla para la acción y esa combinación está
  libre; el jugador puede cambiarla en las asignaciones de teclas. `/diarias` también abre la UI.

### Archivos

- `azalea/client/AzaleaDailyRewards/`: addon cliente 3.3.5a.
- `azalea/daily-rewards/daily_logic.lua`: reglas puras de calendario y racha.
- `azalea/daily-rewards/tests/test_daily_logic.lua`: pruebas de las reglas y cambios de horario.

### Trabajo pendiente antes de instalación

1. Diseñar persistencia por personaje y entrega transaccional/recuperable que impida duplicar o
   perder la recompensa si falla la base, el servidor se reinicia o se repite la petición.
   `SendMail` de ALE confirma su correo en una transacción distinta a la escritura de la racha;
   no usar ambas operaciones como si fueran atómicas. `CharDBExecute` puede ser asíncrono.
2. Implementar la comunicación de addon con el evento de servidor ALE 30, autenticando el emisor
   y usando solo mensajes y datos validados. El servidor deberá decidir día y recompensa.
3. Preparar migración SQL siguiendo `AGENTS.md` y la política de actualizaciones, sin aplicarla
   a la base activa; documentar instalación, rollback y reconciliación de errores.
4. Elegir e implementar importes de dinero configurables y probar límites de dinero/inventario.
5. Verificar cliente 3.3.5a, combinaciones de teclas, doble clic, simultaneidad, reinicios,
   horario de verano, pérdida de día, día 14 repetible y errores de entrega en entorno aislado.
6. Completar documentación en ambos idiomas y publicar la feature únicamente con su estado real.

### Pruebas de reglas ejecutadas

```bash
luac -p azalea/client/AzaleaDailyRewards/AzaleaDailyRewards.lua
luac -p azalea/daily-rewards/daily_logic.lua
lua azalea/daily-rewards/tests/test_daily_logic.lua azalea/daily-rewards/daily_logic.lua
```

Las pruebas puras cubren primer día, misma jornada, avance, día 14 repetido, pérdida de racha,
retroceso del reloj y límites de medianoche/cambios de hora. No prueban el cliente ni la entrega.

## English

**Status: incomplete. Do not install, merge into `server`, or use with live characters.** The
client UI and pure calendar/streak rules exist; the authoritative backend, persistence and safe
reward delivery are not implemented. The addon waits for a server response. No live server or
client files were changed.

Progress is per character and rolls over at Europe/Madrid midnight including DST. Days 1–13
will award configurable money; day 14 awards Frozen Orb item 43102 and repeats while the streak
continues. Missing a day resets the next reward to day 1. Shift+F12 is assigned only when unused;
`/diarias` is an alternative. Amounts remain to be chosen.

Before release, implement an authoritative server handler and persistence with crash-safe,
duplicate-safe delivery. ALE `SendMail` and a separate streak update do not share a transaction;
asynchronous `CharDBExecute` must not be treated as a synchronous commit. Provide migration,
installation, rollback and reconciliation instructions, then test client behavior, concurrent
claims, failures, restarts, calendar boundaries, full inventory and repeated day 14 in isolation.
