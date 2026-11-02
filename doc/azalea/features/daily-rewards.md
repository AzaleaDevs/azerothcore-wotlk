# Recompensas diarias / Daily rewards

Feature `feature/daily-rewards` de Azalea Core (AzerothCore 3.3.5a + ALE).

- [Español](#español)
- [English](#english)

## Español

### Qué hace

Cada personaje puede reclamar una recompensa al día desde una ventana propia en el juego.

- **Una reclamación por personaje y día natural de Madrid** (con horario de verano e invierno). El día cambia a medianoche, hora de Madrid.
- **Racha por personaje:** si reclamaste ayer, hoy toca el día siguiente. Si te saltas un día, la racha vuelve al día 1.
- **Premios:**

| Día | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 y siguientes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Oro | 5 | 10 | 20 | 50 | 100 | 200 | 500 | 1.000 | 2.000 | 3.000 | 5.000 | 10.000 | 20.000 | Orbe congelado (`43102`), cada día mientras no se rompa la racha |

- **Ventana:** 14 casillas con el icono de monedas (días 1–13) y el del Orbe congelado (día 14+), el día actual resaltado, los cobrados marcados, botón **RECLAMAR** y cuenta atrás hasta el siguiente día. Suena al abrirse y al cerrarse, y Esc la cierra.
- **Acceso:** `/diarias`, `/daily` o el botón de la moneda en el minimapa, que parpadea cuando hay recompensa pendiente. Al entrar al juego se avisa en el chat.
- **Seguridad:** el servidor decide el día y el premio; el cliente solo pide. Si las bolsas están llenas (orbe) o el oro superaría el máximo del juego, no se entrega nada y la reclamación no se gasta.

### Qué se necesita

- Servidor AzerothCore con **ALE** (`mod-ale`, revisión fijada en `azalea/modules.lock.json`).
- Acceso a la base `acore_characters`.
- Cliente **WoW 3.3.5a**. El MPQ publicado se ha construido para un cliente **esES**.

### Ficheros que toca y por qué

| Capa | Fichero | Para qué |
|---|---|---|
| Servidor · Lua | `lua_scripts/azalea_daily_rewards.lua` | Recibe las peticiones de la ventana, calcula el día de Madrid y la racha, entrega el premio y lo guarda |
| Servidor · SQL | `data/sql/updates/pending_db_characters/rev_1793653450774845854.sql` | Crea la tabla `azalea_daily_rewards_claim` (idempotente) |
| Servidor · SQL | `azalea/daily-rewards/sql/uninstall.sql` | Borra la tabla para desinstalar (fuera de `pending_*`, no se aplica solo) |
| Cliente · UI | `azalea/client/DailyRewardsMPQ/Interface/FrameXML/AzaleaDailyRewards.lua` | La ventana, el botón del minimapa y los comandos |
| Cliente · MPQ | `azalea/client/DailyRewardsMPQ/build_mpq.py` | Construye el MPQ a partir de tu propio `FrameXML.toc` |
| Cliente · MPQ | `azalea/daily-rewards/dist/patch-daily-rewards.MPQ` | El MPQ listo para descargar (esES) |
| Tests | `azalea/daily-rewards/tests/` | Lógica del servidor y ventana con una API de WoW simulada |

**No aplica:** no hay cambios en C++ (no hace falta recompilar el core para la lógica), ni DBC, ni texturas o sonidos nuevos (se usan iconos y sonidos del propio juego).

### Tabla

`acore_characters.azalea_daily_rewards_claim`: una fila por personaje y día de Madrid.

| Columna | Qué guarda |
|---|---|
| `character_guid` | `characters.guid` |
| `madrid_day` | Días desde 1970-01-01 según el calendario de Madrid |
| `streak_day` | Día de la racha (1–13 oro, 14+ orbe) |
| `reward_gold` / `reward_item` | Premio entregado |
| `claimed_at` | Momento de la reclamación |

La clave primaria (`character_guid`, `madrid_day`) impide reclamar dos veces el mismo día.

### Instalación

**Servidor (en este orden):**

1. Haz backup de `acore_characters`.
2. Aplica el SQL. Con Docker, reconstruye la imagen de `ac-db-import` con este código y lánzala; debe terminar con código 0. Sin Docker, ejecuta `rev_1793653450774845854.sql` en `acore_characters`.
3. Comprueba que existe la tabla: `SHOW TABLES FROM acore_characters LIKE 'azalea%';`
4. Copia `lua_scripts/azalea_daily_rewards.lua` a la carpeta de scripts Lua de tu worldserver. Con la recarga automática de ALE se aplica al momento; si no, reinicia el worldserver o usa `.reload ale`.

**Cliente:**

1. [Descarga `patch-daily-rewards.MPQ`](../../../azalea/daily-rewards/dist/patch-daily-rewards.MPQ) (en GitHub, botón de descarga del fichero).
2. Cierra WoW.
3. Cópialo a `Data/<idioma>/` con un nombre de parche libre que cargue **después** del que tiene tu interfaz. Por ejemplo, en esES: `Data/esES/patch-esES-C.MPQ`. No sobrescribas ningún parche existente.
4. Entra al juego y escribe `/diarias`.

El MPQ incluye una copia de `Interface/FrameXML/FrameXML.toc` con una línea añadida (`AzaleaDailyRewards.lua`). Si usas otros parches que también cambien ese fichero, o un cliente en otro idioma, **reconstruye el MPQ** con tu propio `FrameXML.toc` (ver abajo).

### Cómo se comunican cliente y servidor

Con mensajes de addon (prefijo `AZDR`), que el cliente se envía a sí mismo por susurro. ALE los intercepta con el evento de servidor `30` (`ADDON_EVENT_ON_MESSAGE`) y no llegan al chat.

| Sentido | Mensaje | Significado |
|---|---|---|
| Cliente → servidor | `STATUS` | ¿Qué día me toca y lo he cobrado? |
| Cliente → servidor | `CLAIM` | Quiero reclamar |
| Servidor → cliente | `ST:<día>:<cobrado 0/1>:<segundos>` | Estado y segundos hasta el siguiente día |
| Servidor → cliente | `OK:<día>:<segundos>` | Premio entregado |
| Servidor → cliente | `ER:<código>` | `YA` (ya cobrado), `BOLSA` (sin hueco), `ORO` (tope de oro), `DB` (no se pudo guardar) |

El servidor solo atiende susurros de un personaje a sí mismo y calcula siempre el día y el premio; el cliente no puede elegirlos.

### Reconstruir el MPQ

Necesitas Python 3.12 y [AzaleaCore-MPQ-Studio](https://github.com/AzaleaDevs/AzaleaCore-MPQ-Studio).

1. Busca qué MPQ de tu cliente tiene el `Interface\FrameXML\FrameXML.toc` efectivo (el de mayor prioridad). En el cliente de referencia es `Data/esES/patch-esES-3.MPQ`.
2. Ejecuta:

```bash
python azalea/client/DailyRewardsMPQ/build_mpq.py \
  --base-mpq "D:/World of Warcraft 3.3.5a/Data/esES/patch-esES-3.MPQ" \
  --output salida/patch-daily-rewards.MPQ
```

El script no sobrescribe ficheros, comprueba el contenido del MPQ generado y muestra su SHA-256.

### Prueba en el juego

1. Al entrar: aviso en el chat y botón del minimapa parpadeando.
2. `/diarias`: se abre con sonido y brilla el día que toca.
3. **RECLAMAR**: llega el oro (o el orbe), el día queda marcado y el botón pasa a **RECLAMADO** con la cuenta atrás.
4. Volver a reclamar el mismo día no da nada. Otro personaje tiene su propia racha.
5. Para probar la racha sin esperar, con el personaje **fuera del juego** (el servidor guarda su estado mientras está conectado), simula días anteriores:

```sql
-- ayer fue el día 13 -> hoy toca el Orbe congelado
DELETE FROM acore_characters.azalea_daily_rewards_claim WHERE character_guid = <guid>;
INSERT INTO acore_characters.azalea_daily_rewards_claim (character_guid, madrid_day, streak_day, reward_gold)
VALUES (<guid>, <día de hoy - 1>, 13, 20000);
```

`<día de hoy>` es el `madrid_day` que guarda una reclamación hecha hoy.

### Desactivar o desinstalar

1. **Cliente:** borra el MPQ de `Data/<idioma>/`.
2. **Servidor:** quita `azalea_daily_rewards.lua` de los scripts Lua (la ventana dirá «Sin respuesta del servidor»).
3. **Datos (opcional):** haz backup y ejecuta `azalea/daily-rewards/sql/uninstall.sql` en `acore_characters`. Se pierde el historial de rachas.

### Límites conocidos

- Si el servidor se cae justo después de guardar la reclamación y antes de entregar el oro, ese premio se pierde (nunca se duplica). Para el orbe es al revés: se entrega antes de guardar, para no gastar la reclamación con las bolsas llenas.
- El MPQ publicado es para esES. Para otros idiomas, reconstrúyelo.

---

## English

### What it does

Each character can claim one reward per day from its own in-game window.

- **One claim per character per Madrid calendar day** (daylight saving included). The day changes at midnight, Madrid time.
- **Per-character streak:** if you claimed yesterday, today is the next day. Miss a day and the streak goes back to day 1.
- **Rewards:** days 1–13 give 5, 10, 20, 50, 100, 200, 500, 1,000, 2,000, 3,000, 5,000, 10,000 and 20,000 gold. Day 14 and every following day give a Frozen Orb (`43102`) while the streak continues.
- **Window:** 14 slots with the coin icon (days 1–13) and the Frozen Orb icon (day 14+), today highlighted, claimed days checked, a **RECLAMAR** (claim) button and a countdown to the next day. It plays a sound on open and close; Esc closes it.
- **Access:** `/diarias`, `/daily` or the coin button on the minimap, which pulses when a reward is pending. A chat reminder is shown on login.
- **Safety:** the server decides the day and the reward; the client only asks. If the bags are full (orb) or the gold would exceed the game maximum, nothing is given and the claim is not spent.

### Requirements

AzerothCore with **ALE** (`mod-ale`, pinned in `azalea/modules.lock.json`), access to `acore_characters`, and a **WoW 3.3.5a** client. The published MPQ was built for an **esES** client.

### Files and why

| Layer | File | Purpose |
|---|---|---|
| Server · Lua | `lua_scripts/azalea_daily_rewards.lua` | Handles window requests, Madrid day and streak, delivers and records the reward |
| Server · SQL | `data/sql/updates/pending_db_characters/rev_1793653450774845854.sql` | Creates `azalea_daily_rewards_claim` (idempotent) |
| Server · SQL | `azalea/daily-rewards/sql/uninstall.sql` | Drops the table (outside `pending_*`, never applied automatically) |
| Client · UI | `azalea/client/DailyRewardsMPQ/Interface/FrameXML/AzaleaDailyRewards.lua` | Window, minimap button and slash commands |
| Client · MPQ | `azalea/client/DailyRewardsMPQ/build_mpq.py` | Builds the MPQ from your own `FrameXML.toc` |
| Client · MPQ | `azalea/daily-rewards/dist/patch-daily-rewards.MPQ` | Ready-to-download MPQ (esES) |
| Tests | `azalea/daily-rewards/tests/` | Server logic and the window against a fake WoW API |

**Not applicable:** no C++ changes, no DBC, no new textures or sounds (built-in game icons and sounds are used).

### Table

`acore_characters.azalea_daily_rewards_claim`, one row per character and Madrid day: `character_guid`, `madrid_day` (days since 1970-01-01 on the Madrid calendar), `streak_day`, `reward_gold`, `reward_item`, `claimed_at`. The primary key (`character_guid`, `madrid_day`) prevents claiming twice on the same day.

### Installation

**Server, in this order:** back up `acore_characters`; apply the SQL (with Docker, rebuild the `ac-db-import` image from this code and run it, it must exit 0; otherwise run `rev_1793653450774845854.sql` on `acore_characters`); check the table exists; copy `lua_scripts/azalea_daily_rewards.lua` to your worldserver Lua scripts folder (ALE auto-reload applies it at once; otherwise restart or `.reload ale`).

**Client:** [download `patch-daily-rewards.MPQ`](../../../azalea/daily-rewards/dist/patch-daily-rewards.MPQ), close WoW and copy it to `Data/<locale>/` under a free patch name that loads **after** the one holding your UI, e.g. `Data/esES/patch-esES-C.MPQ`. Never overwrite an existing patch. Log in and type `/diarias`.

The MPQ contains a copy of `Interface/FrameXML/FrameXML.toc` with one extra line (`AzaleaDailyRewards.lua`). If other patches also change that file, or your client uses another locale, **rebuild the MPQ** from your own `FrameXML.toc`.

### Client-server communication

Addon messages with prefix `AZDR`, whispered by the client to itself. ALE catches them with server event `30` (`ADDON_EVENT_ON_MESSAGE`) and they never reach the chat. Client → server: `STATUS`, `CLAIM`. Server → client: `ST:<day>:<claimed 0/1>:<seconds>`, `OK:<day>:<seconds>`, `ER:<code>` with `YA` (already claimed), `BOLSA` (no bag space), `ORO` (gold cap), `DB` (could not be saved). The server only accepts self-whispers and always computes the day and reward.

### Rebuilding the MPQ

With Python 3.12 and [AzaleaCore-MPQ-Studio](https://github.com/AzaleaDevs/AzaleaCore-MPQ-Studio), find the MPQ holding your effective `Interface\FrameXML\FrameXML.toc` (on the reference client, `Data/esES/patch-esES-3.MPQ`) and run `build_mpq.py --base-mpq <that MPQ> --output <new file>` as shown in the Spanish section. It never overwrites files, verifies the result and prints its SHA-256.

### In-game test

Log in (chat reminder, pulsing minimap button), open `/diarias` (sound, today's slot glows), press **RECLAMAR** (gold or orb arrives, slot checked, button shows **RECLAMADO** with a countdown). Claiming again the same day gives nothing; another character has its own streak. To test streaks without waiting, log the character **out** and insert past days into the table as in the Spanish SQL example.

### Disabling or uninstalling

Delete the MPQ from the client; remove `azalea_daily_rewards.lua` from the server Lua scripts; optionally back up and run `azalea/daily-rewards/sql/uninstall.sql` (streak history is lost).

### Known limits

If the server crashes right after recording a gold claim and before paying it, that reward is lost (never duplicated). The orb is delivered before recording, so full bags never spend the claim. The published MPQ is esES; rebuild it for other locales.
