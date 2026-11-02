# Rama server / Server branch

## Español

Esta rama es lo que corre en la Raspberry: `base/lua` más las features mergeadas. El flujo para
añadir, desplegar y recuperar features está en `doc/azalea/PROCEDIMIENTO-AZALEA-CORE.md`.

**Estado (2026-11-02):**

| Feature | Estado |
| --- | --- |
| `feature/login-greetings` | Integrada y desplegada. Saludos en Lua y C++ verificados en el juego. |
| `feature/daily-rewards` | Rehecha desde cero (2026-11-02), integrada y desplegada. Lua + SQL (`azalea_daily_rewards_claim`) + MPQ de cliente. Verificada en el juego por el usuario. |

Imágenes desplegadas: revisión `4287d90309c5` (`server-4287d90309c5`). Los commits posteriores de
`server` solo cambian documentación o el MPQ de descarga.

## English

This branch is what runs on the Raspberry: `base/lua` plus merged features. See
`doc/azalea/PROCEDIMIENTO-AZALEA-CORE.md` for the feature, deployment and recovery workflow.

Status (2026-11-02): `feature/login-greetings` and `feature/daily-rewards` (rebuilt from scratch:
Lua + SQL + client MPQ) are integrated, deployed and verified in game. Deployed images are revision
`4287d90309c5`; later `server` commits are documentation or the downloadable MPQ only.
