local logic = (function()
-- Pure daily-reward rules. Timestamps are UTC seconds; the day boundary is Europe/Madrid.
local DailyRewards = {}

-- Gold amounts for days 1?13; day 14 is one Frozen Orb (item 43102).
local gold_rewards = { 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 3000, 5000, 10000, 20000 }
function DailyRewards.reward(day)
  assert(type(day) == 'number' and day == math.floor(day) and day >= 1 and day <= 14, 'invalid reward day')
  if day == 14 then return 'item', 43102, 1 end
  return 'money', gold_rewards[day] * 10000 -- copper
end

local function day_number(year, month, day)
  if month <= 2 then year = year - 1 end
  local era = math.floor(year / 400)
  local yoe = year - era * 400
  local shifted_month = month + (month > 2 and -3 or 9)
  local doy = math.floor((153 * shifted_month + 2) / 5) + day - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

local function last_sunday(year, month)
  local last_day = 31
  local weekday = (day_number(year, month, last_day) + 4) % 7 -- Sunday = 0
  return last_day - weekday
end

function DailyRewards.madrid_day(timestamp)
  assert(type(timestamp) == 'number', 'timestamp must be numeric')
  local utc = os.date('!*t', timestamp)
  local start = day_number(utc.year, 3, last_sunday(utc.year, 3)) * 86400 + 3600
  local finish = day_number(utc.year, 10, last_sunday(utc.year, 10)) * 86400 + 3600
  local offset = timestamp >= start and timestamp < finish and 7200 or 3600
  return math.floor((timestamp + offset) / 86400)
end

-- `last_day` is a Madrid calendar-day number, not an elapsed 24-hour period.
function DailyRewards.next_reward(last_day, streak, today)
  if last_day == nil then return 1, false end
  assert(type(last_day) == 'number' and type(streak) == 'number' and type(today) == 'number')
  if last_day > today then return nil, false, 'clock_moved_backwards' end
  if last_day == today then return math.min(math.max(streak, 1), 14), true end
  if today - last_day == 1 then return math.min(math.max(streak, 0) + 1, 14), false end
  return 1, false
end

return DailyRewards
end)()

local PREFIX = 'AZ_DAILY_V1'
local WHISPER = 7
local MAX_MONEY = 2147483646
-- Prevent repeated requests while the asynchronous database write is pending.
local sessionClaims = {}

local function readLast(guid)
  local q = CharDBQuery(string.format(
    'SELECT COUNT(*), COALESCE(MAX(madrid_day), 0), ' ..
    'COALESCE((SELECT reward_day FROM azalea_daily_reward_claim ' ..
    'WHERE character_guid=%u ORDER BY madrid_day DESC LIMIT 1), 0) ' ..
    'FROM azalea_daily_reward_claim WHERE character_guid=%u', guid, guid))
  if not q then return nil, nil, false end
  if q:GetUInt32(0) == 0 then return nil, 0, true end
  return q:GetInt32(1), q:GetUInt32(2), true
end

local function reply(player, message)
  player:SendAddonMessage(PREFIX, message, WHISPER, player)
end

RegisterServerEvent(30, function(_, player, channel, prefix, message, target)
  if prefix ~= PREFIX then return end
  if channel ~= WHISPER or not player or not target then return false end
  local guid = player:GetGUIDLow()
  if guid ~= target:GetGUIDLow() or (message ~= 'STATUS' and message ~= 'CLAIM') then return false end

  local now = os.time()
  local today = logic.madrid_day(now)
  local last, previous, ok = readLast(guid)
  if not ok then reply(player, 'ERROR|unavailable'); return false end
  local cached = sessionClaims[guid]
  if cached and (not last or cached.day > last) then last, previous = cached.day, cached.reward end
  local day, claimed, err = logic.next_reward(last, previous, today)
  if err then reply(player, 'ERROR|' .. err); return false end
  if message == 'CLAIM' and not claimed then
    local kind, amount, count = logic.reward(day)
    if kind == 'money' then
      local before = player:GetCoinage()
      if before + amount >= MAX_MONEY then
        reply(player, 'ERROR|money_limit')
        return false
      end
      player:ModifyMoney(amount)
      if player:GetCoinage() ~= before + amount then
        reply(player, 'ERROR|money_limit')
        return false
      end
    else
      local item = player:AddItem(amount, count)
      if type(item) ~= 'userdata' then reply(player, 'ERROR|inventory_full'); return false end
    end
    -- Tutorial simplification: this asynchronous write is not atomic with the reward.
    sessionClaims[guid] = { day = today, reward = day }
    local money = kind == 'money' and amount or 0
    local item = kind == 'item' and amount or 0
    local quantity = kind == 'item' and count or 0
    CharDBExecute(string.format(
      'INSERT INTO azalea_daily_reward_claim ' ..
      '(character_guid,madrid_day,reward_day,reward_money_copper,reward_item_id,reward_item_count,claimed_at_utc) ' ..
      'VALUES (%u,%d,%u,%u,%u,%u,%u)', guid, today, day, money, item, quantity, now))
    claimed = true
  end
  reply(player, 'STATE|' .. day .. '|' .. (claimed and '1' or '0'))
  return false
end)
