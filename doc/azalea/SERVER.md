# Rama server / Server branch

## Español

Esta rama es lo que corre en la Raspberry: `base/lua` más las features mergeadas. El flujo para
añadir, desplegar y recuperar features está en `doc/azalea/PROCEDIMIENTO-AZALEA-CORE.md`.

**Estado (2026-11-01):**

| Feature | Estado |
| --- | --- |
| `feature/login-greetings` | Integrada y desplegada. Saludos en Lua y C++ verificados en el juego. |
| `feature/daily-rewards` | Descartada. Se retiró de `server`, junto con su script Lua y su tabla. |

Imágenes desplegadas: revisión `08a612db1c98` (`server-08a612db1c98`). Los commits posteriores de
`server` solo cambian documentación.

## English

This branch is what runs on the Raspberry: `base/lua` plus merged features. See
`doc/azalea/PROCEDIMIENTO-AZALEA-CORE.md` for the feature, deployment and recovery workflow.

Status (2026-11-01): `feature/login-greetings` is integrated, deployed and verified in game.
`feature/daily-rewards` was discarded and removed from `server` together with its Lua script and
table. Deployed images are revision `08a612db1c98`; later `server` commits are documentation only.
