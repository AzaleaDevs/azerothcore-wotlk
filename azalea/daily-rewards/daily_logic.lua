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
