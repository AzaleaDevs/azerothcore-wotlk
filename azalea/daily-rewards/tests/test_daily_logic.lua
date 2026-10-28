local logic = dofile(arg[1] or 'server/daily_logic.lua')
local function equal(actual, expected, message)
  assert(actual == expected, message .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

local day, claimed = logic.next_reward(nil, 0, 100)
equal(day, 1, 'first claim'); equal(claimed, false, 'first claim availability')
day, claimed = logic.next_reward(100, 1, 100)
equal(day, 1, 'same day'); equal(claimed, true, 'same day only once')
day, claimed = logic.next_reward(100, 13, 101)
equal(day, 14, 'fourteenth day'); equal(claimed, false, 'fourteenth day availability')
day, claimed = logic.next_reward(101, 14, 102)
equal(day, 14, 'repeat final day'); equal(claimed, false, 'repeat final availability')
day, claimed = logic.next_reward(100, 14, 102)
equal(day, 1, 'missed day resets'); equal(claimed, false, 'reset availability')
local error_code
day, claimed, error_code = logic.next_reward(102, 4, 101)
equal(day, nil, 'clock backwards'); equal(error_code, 'clock_moved_backwards', 'clock error')

-- UTC timestamps around Madrid midnight in winter and summer and DST switch days.
equal(logic.madrid_day(1767221999) + 1, logic.madrid_day(1767222000), 'winter midnight')
equal(logic.madrid_day(1782856799) + 1, logic.madrid_day(1782856800), 'summer midnight')
equal(logic.madrid_day(1774745999), logic.madrid_day(1774746000), 'spring clock change same day')
equal(logic.madrid_day(1792899599), logic.madrid_day(1792899600), 'autumn clock change same day')
local expected_gold = { 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 3000, 5000, 10000, 20000 }
for i, gold in ipairs(expected_gold) do
  local kind, amount = logic.reward(i)
  equal(kind, 'money', 'money reward type day ' .. i)
  equal(amount, gold * 10000, 'money reward amount day ' .. i)
end
local kind, item, quantity = logic.reward(14)
equal(kind, 'item', 'final reward type'); equal(item, 43102, 'frozen orb'); equal(quantity, 1, 'orb quantity')
assert(not pcall(logic.reward, 0) and not pcall(logic.reward, 15), 'invalid days rejected')
print('daily reward rules: ok')
