local callback, ledger, writes, responses
ledger, writes, responses = {}, 0, {}
local now = 1767222000
os.time = function() return now end
function RegisterServerEvent(id, fn) assert(id == 30); callback = fn end
function CharDBQuery(sql)
  local guid = tonumber(sql:match('character_guid=(%d+)'))
  local claim = ledger[guid]
  return {
    GetUInt32 = function(_, i) return i == 0 and (claim and 1 or 0) or claim.reward end,
    GetInt32 = function() return claim.day end,
  }
end
function CharDBExecute(sql)
  local guid, day, reward = sql:match('VALUES %((%d+),(%-?%d+),(%d+),')
  ledger[tonumber(guid)] = { day = tonumber(day), reward = tonumber(reward) }
  writes = writes + 1
end
local player = { money = 0, items = 0 }
function player:GetGUIDLow() return 17 end
function player:GetCoinage() return self.money end
function player:ModifyMoney(amount) self.money = self.money + amount end
function player:AddItem(id, count) self.items = self.items + count; return newproxy() end
function player:SendAddonMessage(_, msg) responses[#responses + 1] = msg end
dofile(arg[1])
local function request(msg) callback(30, player, 7, 'AZ_DAILY_V1', msg, player); return responses[#responses] end
assert(request('STATUS') == 'STATE|1|0')
assert(request('CLAIM') == 'STATE|1|1' and player.money == 50000 and writes == 1)
assert(request('CLAIM') == 'STATE|1|1' and player.money == 50000 and writes == 1)
now = now + 86400
player.money = 2147483646
assert(request('CLAIM') == 'ERROR|money_limit' and writes == 1)
player.money = 2147483646 - 100000
assert(request('CLAIM') == 'ERROR|money_limit' and writes == 1)
player.money = 0
local realModifyMoney = player.ModifyMoney
player.ModifyMoney = function() end
assert(request('CLAIM') == 'ERROR|money_limit' and writes == 1)
player.ModifyMoney = realModifyMoney
assert(request('CLAIM') == 'STATE|2|1' and player.money == 100000 and writes == 2)
for day = 3, 14 do
  now = now + 86400
  assert(request('CLAIM') == 'STATE|' .. day .. '|1')
end
assert(player.items == 1)
now = now + 86400
assert(request('CLAIM') == 'STATE|14|1' and player.items == 2)
now = now + 172800
assert(request('CLAIM') == 'STATE|1|1')
print('tutorial service: claims, duplicate, cap, streak, orb and reset passed')
