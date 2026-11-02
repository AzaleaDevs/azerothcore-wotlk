--[[
  Azalea Core · Recompensas diarias / Daily rewards  (feature/daily-rewards)

  Servidor (ALE). La ventana del cliente (MPQ) habla con este script por mensajes de addon:
    cliente -> servidor : "STATUS" | "CLAIM"            (prefijo AZDR, susurro a uno mismo)
    servidor -> cliente : "ST:<dia>:<cobrado>:<seg>"     estado
                          "OK:<dia>:<seg>"               premio entregado
                          "ER:<codigo>"                  YA | BOLSA | ORO | DB

  Reglas: una reclamación por personaje y día natural de Madrid. Si ayer reclamaste, la racha
  sube un día; si te saltaste alguno, vuelve al día 1. Días 1-13 = oro; día 14 y siguientes =
  Orbe congelado (43102), que se repite mientras no se rompa la racha.
  Tabla: acore_characters.azalea_daily_rewards_claim (ver data/sql/updates/pending_db_characters).
]]

local DR = {}

DR.PREFIX = "AZDR"
DR.WHISPER = 7
DR.ORB_ITEM = 43102
DR.GOLD = { 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 3000, 5000, 10000, 20000 }
DR.COPPER_PER_GOLD = 10000
DR.MAX_MONEY = 2147483646 -- MAX_MONEY_AMOUNT del core (0x7FFFFFFF - 1)
DR.TABLE = "azalea_daily_rewards_claim"

---------------------------------------------------------------- calendario de Madrid
-- Días desde 1970-01-01 para una fecha civil (algoritmo de Howard Hinnant).
function DR.daysFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = math.floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

-- Último domingo de un mes de 31 días (marzo y octubre), en días desde 1970.
local function lastSunday(y, m)
  local days = DR.daysFromCivil(y, m, 31)
  local weekday = (days + 4) % 7 -- 0 = domingo (el 1970-01-01 fue jueves)
  return days - weekday
end

-- Desfase de Madrid en segundos para un instante UTC: +2 h en verano (del último domingo de
-- marzo a las 01:00 UTC al último domingo de octubre a las 01:00 UTC), +1 h el resto del año.
function DR.madridOffset(utc)
  local y = tonumber(os.date("!%Y", utc))
  local summerStart = lastSunday(y, 3) * 86400 + 3600
  local summerEnd = lastSunday(y, 10) * 86400 + 3600
  if utc >= summerStart and utc < summerEnd then return 7200 end
  return 3600
end

-- Día natural de Madrid (número de día) y segundos que faltan para el siguiente.
function DR.madridDay(utc)
  local localTime = utc + DR.madridOffset(utc)
  local day = math.floor(localTime / 86400)
  return day, (day + 1) * 86400 - localTime
end

---------------------------------------------------------------- reglas de la racha
-- last = { day = <día Madrid>, streak = <día de racha> } o nil si nunca ha reclamado.
-- Devuelve el día de racha que toca mostrar y si ya está cobrado hoy.
function DR.nextStreak(last, today)
  if not last then return 1, false end
  if last.day == today then return last.streak, true end
  if last.day == today - 1 then return last.streak + 1, false end
  return 1, false
end

-- Premio de un día de racha: { gold = n } o { item = id }.
function DR.reward(streak)
  if streak <= #DR.GOLD then return { gold = DR.GOLD[streak] } end
  return { item = DR.ORB_ITEM }
end

---------------------------------------------------------------- base de datos
local cache = {} -- [guid] = { day, streak }  (evita doble cobro antes de que la BD responda)

local function loadLast(guid)
  if cache[guid] then return cache[guid] end
  local q = CharDBQuery(string.format(
    "SELECT madrid_day, streak_day FROM %s WHERE character_guid = %d ORDER BY madrid_day DESC LIMIT 1",
    DR.TABLE, guid))
  if not q then return nil end
  local last = { day = q:GetInt32(0), streak = q:GetUInt32(1) }
  cache[guid] = last
  return last
end

local function saveClaim(guid, today, streak, reward)
  CharDBQuery(string.format(
    "INSERT INTO %s (character_guid, madrid_day, streak_day, reward_gold, reward_item) VALUES (%d, %d, %d, %d, %d)",
    DR.TABLE, guid, today, streak, reward.gold or 0, reward.item or 0))
  local q = CharDBQuery(string.format(
    "SELECT streak_day FROM %s WHERE character_guid = %d AND madrid_day = %d", DR.TABLE, guid, today))
  return q ~= nil and q:GetUInt32(0) == streak
end

---------------------------------------------------------------- peticiones
function DR.status(player, now)
  local guid = player:GetGUIDLow()
  local today, secs = DR.madridDay(now)
  local streak, claimed = DR.nextStreak(loadLast(guid), today)
  return string.format("ST:%d:%d:%d", streak, claimed and 1 or 0, secs)
end

function DR.claim(player, now)
  local guid = player:GetGUIDLow()
  local today, secs = DR.madridDay(now)
  local streak, claimed = DR.nextStreak(loadLast(guid), today)
  if claimed then return "ER:YA" end

  local reward = DR.reward(streak)
  if reward.gold and player:GetCoinage() + reward.gold * DR.COPPER_PER_GOLD > DR.MAX_MONEY then
    return "ER:ORO"
  end
  -- El orbe se entrega primero: si no cabe en las bolsas, no se gasta la reclamación.
  if reward.item and not player:AddItem(reward.item, 1) then return "ER:BOLSA" end

  cache[guid] = { day = today, streak = streak }
  if not saveClaim(guid, today, streak, reward) then
    cache[guid] = nil
    if reward.item then player:RemoveItem(reward.item, 1) end
    return "ER:DB"
  end
  if reward.gold then player:ModifyMoney(reward.gold * DR.COPPER_PER_GOLD) end
  return string.format("OK:%d:%d", streak, secs)
end

---------------------------------------------------------------- eventos de ALE
if RegisterServerEvent then
  -- 30 = ADDON_EVENT_ON_MESSAGE (event, sender, type, prefix, msg, target)
  RegisterServerEvent(30, function(_, sender, channel, prefix, message, target)
    if prefix ~= DR.PREFIX then return end
    if channel ~= DR.WHISPER or not sender or not target then return false end
    if target:GetGUIDLow() ~= sender:GetGUIDLow() then return false end

    local reply
    if message == "STATUS" then reply = DR.status(sender, os.time())
    elseif message == "CLAIM" then reply = DR.claim(sender, os.time()) end
    if reply then sender:SendAddonMessage(DR.PREFIX, reply, DR.WHISPER, sender) end
    return false -- el susurro no llega al chat
  end)

  -- 4 = PLAYER_EVENT_ON_LOGOUT: liberar la caché del personaje
  RegisterPlayerEvent(4, function(_, player) cache[player:GetGUIDLow()] = nil end)
end

return DR
