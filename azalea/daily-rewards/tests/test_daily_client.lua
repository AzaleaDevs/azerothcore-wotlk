local frames = {}
local function object()
  local o = { scripts = {}, shown = true }
  return setmetatable(o, { __index = function(_, k)
    if k == 'CreateFontString' or k == 'CreateTexture' then return function()
      local child = object()
      frames[#frames + 1] = child
      return child
    end end
    if k == 'SetScript' then return function(self, event, fn) self.scripts[event] = fn end end
    if k == 'Show' then return function(self) self.shown = true end end
    if k == 'Hide' then return function(self) self.shown = false end end
    if k == 'IsShown' then return function(self) return self.shown end end
    if k == 'Enable' then return function(self) self.enabled = true end end
    if k == 'Disable' then return function(self) self.enabled = false end end
    if k == 'SetText' then return function(self, text) self.text = text end end
    return function() end
  end })
end
function CreateFrame(kind, name, parent, template)
  local frame = object()
  frame.template = template
  frames[#frames + 1] = frame
  return frame
end
UIParent, UISpecialFrames, SlashCmdList = object(), {}, {}
function UnitName() return 'Tester' end
local sent = {}
function SendAddonMessage(prefix, message, channel, target)
  sent[#sent + 1] = { prefix, message, channel, target }
end
dofile(arg[1])
SlashCmdList.AZALEADAILY()
assert(sent[1][2] == 'STATUS')
local eventFrame, buttons
buttons = {}
for _, frame in ipairs(frames) do
  if frame.scripts.OnEvent then eventFrame = frame end
  if frame.template == 'UIPanelButtonTemplate' then buttons[#buttons + 1] = frame end
end
assert(eventFrame and #buttons == 14)
eventFrame.scripts.OnEvent(eventFrame, 'CHAT_MSG_ADDON', 'AZ_DAILY_V1', 'STATE|1|0', 'WHISPER', 'Tester')
assert(buttons[1].enabled and not buttons[2].enabled)
buttons[1].scripts.OnClick()
assert(sent[2][2] == 'CLAIM')
eventFrame.scripts.OnEvent(eventFrame, 'CHAT_MSG_ADDON', 'AZ_DAILY_V1', 'ERROR|money_limit', 'WHISPER', 'Tester')
local found = false
for _, frame in ipairs(frames) do
  if rawget(frame, 'text') and frame.text:find('limite de oro', 1, true) then found = true end
end
assert(found and not buttons[1].enabled)
print('client protocol: status, claim and money-limit feedback ok')
