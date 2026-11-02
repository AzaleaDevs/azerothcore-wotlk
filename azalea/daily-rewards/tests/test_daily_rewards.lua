-- Tests for lua_scripts/azalea_daily_rewards.lua (run from the repo root):  lua5.1 azalea/daily-rewards/tests/test_daily_rewards.lua
-- Uses a fake player and a fake character database, so it needs no server.
local fails, total = 0, 0
local function check(name, cond)
  total = total + 1
  if not cond then fails = fails + 1; print("FAIL  " .. name) else print("ok    " .. name) end
end

---------------------------------------------------------------- fake database
local rows = {}
local dbDown = false
local function result(values) return { GetInt32 = function(_, i) return values[i + 1] end, GetUInt32 = function(_, i) return values[i + 1] end } end
function CharDBQuery(sql)
  if dbDown and sql:match("^INSERT") then return nil end
  local g, d, s, gold, item = sql:match("VALUES %((%d+), (%-?%d+), (%d+), (%d+), (%d+)%)")
  if g then
    local key = g .. ":" .. d
    if not rows[key] then rows[key] = { guid = tonumber(g), day = tonumber(d), streak = tonumber(s), gold = tonumber(gold), item = tonumber(item) } end
    return nil
  end
  g, d = sql:match("character_guid = (%d+) AND madrid_day = (%-?%d+)")
  if g then local r = rows[g .. ":" .. d]; return r and result({ r.streak }) end
  g = sql:match("character_guid = (%d+) ORDER BY")
  if g then
    local best
    for _, r in pairs(rows) do if r.guid == tonumber(g) and (not best or r.day > best.day) then best = r end end
    return best and result({ best.day, best.streak })
  end
  error("unexpected SQL: " .. sql)
end

local DR = dofile("lua_scripts/azalea_daily_rewards.lua")

local function newPlayer(guid, opts)
  opts = opts or {}
  local p = { guid = guid, money = opts.money or 0, items = 0, bagsFull = opts.bagsFull }
  function p:GetGUIDLow() return self.guid end
  function p:GetCoinage() return self.money end
  function p:ModifyMoney(v) self.money = self.money + v end
  function p:AddItem(id, n) if self.bagsFull then return nil end self.items = self.items + n; return {} end
  function p:RemoveItem(id, n) self.items = self.items - n end
  return p
end

---------------------------------------------------------------- calendar
local function utc(y, m, d, h, mi) return DR.daysFromCivil(y, m, d) * 86400 + (h or 0) * 3600 + (mi or 0) * 60 end
check("daysFromCivil epoch", DR.daysFromCivil(1970, 1, 1) == 0)
check("daysFromCivil 2000-01-01", DR.daysFromCivil(2000, 1, 1) == 10957)
check("daysFromCivil 2026-11-02", DR.daysFromCivil(2026, 11, 2) == 20759)
check("daysFromCivil matches os.date", os.date("!%Y-%m-%d", DR.daysFromCivil(2028, 2, 29) * 86400) == "2028-02-29")
check("winter offset +1h", DR.madridOffset(utc(2026, 1, 15, 12)) == 3600)
check("summer offset +2h", DR.madridOffset(utc(2026, 7, 15, 12)) == 7200)
-- 2026: summer time from Sun 29 March 01:00 UTC to Sun 25 October 01:00 UTC
check("before DST start", DR.madridOffset(utc(2026, 3, 29, 0, 59)) == 3600)
check("at DST start", DR.madridOffset(utc(2026, 3, 29, 1, 0)) == 7200)
check("before DST end", DR.madridOffset(utc(2026, 10, 25, 0, 59)) == 7200)
check("at DST end", DR.madridOffset(utc(2026, 10, 25, 1, 0)) == 3600)
-- Madrid midnight in winter is 23:00 UTC of the previous day
local d1 = DR.madridDay(utc(2026, 11, 2, 22, 59))
local d2, left = DR.madridDay(utc(2026, 11, 2, 23, 0))
check("winter midnight changes day", d2 == d1 + 1)
check("seconds to next day at midnight", left == 86400)
local s1 = DR.madridDay(utc(2026, 7, 1, 21, 59))
local s2 = DR.madridDay(utc(2026, 7, 1, 22, 0))
check("summer midnight is 22:00 UTC", s2 == s1 + 1)

---------------------------------------------------------------- streak rules
check("first claim is day 1", select(1, DR.nextStreak(nil, 100)) == 1)
local st, cl = DR.nextStreak({ day = 100, streak = 3 }, 100)
check("same day = claimed", st == 3 and cl)
st, cl = DR.nextStreak({ day = 99, streak = 3 }, 100)
check("yesterday -> +1", st == 4 and not cl)
st = DR.nextStreak({ day = 97, streak = 9 }, 100)
check("missed day -> back to 1", st == 1)
check("rewards day 1", DR.reward(1).gold == 5)
check("rewards day 13", DR.reward(13).gold == 20000)
check("rewards day 14 orb", DR.reward(14).item == 43102)
check("rewards day 30 orb", DR.reward(30).item == 43102)

---------------------------------------------------------------- claim flow
local T = utc(2026, 11, 2, 12)
local p = newPlayer(1)
check("status before claim", DR.status(p, T):match("^ST:1:0:") ~= nil)
check("claim day 1", DR.claim(p, T):match("^OK:1:") ~= nil)
check("got 5 gold", p.money == 5 * 10000)
check("second claim same day refused", DR.claim(p, T + 60) == "ER:YA")
check("no double gold", p.money == 5 * 10000)
check("status after claim", DR.status(p, T):match("^ST:1:1:") ~= nil)
check("next day -> day 2", DR.claim(p, T + 86400):match("^OK:2:") ~= nil)
check("got 10 more gold", p.money == 15 * 10000)
check("skip a day -> day 1 again", DR.claim(p, T + 3 * 86400):match("^OK:1:") ~= nil)

-- orb from day 14, and full bags do not spend the claim
local q = newPlayer(2, { bagsFull = true })
local today = DR.madridDay(T)
rows["2:" .. (today - 1)] = { guid = 2, day = today - 1, streak = 13, gold = 20000, item = 0 }
check("full bags refused", DR.claim(q, T) == "ER:BOLSA")
check("claim not spent", DR.status(q, T):match("^ST:14:0:") ~= nil)
q.bagsFull = false
check("orb delivered", DR.claim(q, T):match("^OK:14:") ~= nil and q.items == 1)
check("orb repeats on day 15", DR.claim(q, T + 86400):match("^OK:15:") ~= nil and q.items == 2)

-- gold cap
local r = newPlayer(3, { money = DR.MAX_MONEY - 10000 })
check("gold cap refused", DR.claim(r, T) == "ER:ORO")
check("cap does not spend claim", DR.status(r, T):match("^ST:1:0:") ~= nil)

-- database failure gives nothing back and keeps the claim available
dbDown = true
local s = newPlayer(4)
check("db failure reported", DR.claim(s, T) == "ER:DB")
check("db failure gives no gold", s.money == 0)
dbDown = false
check("retry after db failure works", DR.claim(s, T):match("^OK:1:") ~= nil)

print(string.format("\n%d/%d passed", total - fails, total))
os.exit(fails == 0 and 0 or 1)
