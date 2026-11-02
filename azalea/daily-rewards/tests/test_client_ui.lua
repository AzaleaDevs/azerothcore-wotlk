-- Smoke test for the client window (azalea/client/DailyRewardsMPQ/...): loads it with a minimal fake
-- WoW 3.3.5a API, replays server answers and checks the window state. Run from the repo root:
--   lua5.1 azalea/daily-rewards/tests/test_client_ui.lua
local fails, total = 0, 0
local function check(name, cond)
  total = total + 1
  if not cond then fails = fails + 1; print("FAIL  " .. name) else print("ok    " .. name) end
end

local now, sent, sounds, chat, errors = 100, {}, {}, {}, {}
local frames = {}

-- generic widget: records what matters, accepts any other 3.3.5 method
local Widget = {}
Widget.__index = function(t, k)
  local v = rawget(Widget, k)
  if v then return v end
  return function() end
end
local function new(kind, name)
  local w = setmetatable({ kind = kind, shown = true, scripts = {}, events = {}, text = nil, enabled = true, alpha = 1, desat = false }, Widget)
  if name then _G[name] = w end
  frames[#frames + 1] = w
  return w
end
function Widget:CreateTexture() return new("Texture") end
function Widget:CreateFontString() return new("FontString") end
function Widget:SetScript(k, f) self.scripts[k] = f end
function Widget:GetScript(k) return self.scripts[k] end
function Widget:RegisterEvent(e) self.events[e] = true end
function Widget:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function Widget:Hide() local was = self.shown; self.shown = false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function Widget:IsShown() return self.shown end
function Widget:SetText(t) self.text = t end
function Widget:GetText() return self.text end
function Widget:Enable() self.enabled = true end
function Widget:Disable() self.enabled = false end
function Widget:SetAlpha(a) self.alpha = a end
function Widget:SetDesaturated(d) self.desat = d and true or false end

function CreateFrame(kind, name) local w = new(kind, name); if kind == "Frame" or kind == "Button" then w.shown = true end return w end
UIParent, Minimap, GameTooltip = new("Frame"), new("Frame"), new("Frame")
UIErrorsFrame = { AddMessage = function(_, m) errors[#errors + 1] = m end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
UISpecialFrames, SlashCmdList = {}, {}
tinsert = table.insert
function strsplit(sep, s) local out = {} for p in (s .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = p end return unpack(out) end
function GetTime() return now end
function GetItemIcon() return "Interface\\Icons\\INV_Misc_Frostemblem_01" end
function UnitName() return "Azalea" end
function PlaySound(s) sounds[#sounds + 1] = s end
function SendAddonMessage(prefix, msg, chan, target) sent[#sent + 1] = { prefix, msg, chan, target } end

dofile("azalea/client/DailyRewardsMPQ/Interface/FrameXML/AzaleaDailyRewards.lua")
local f = AzaleaDailyRewardsFrame
local claim = AzaleaDailyRewardsClaimButton
local events
for _, w in ipairs(frames) do if w.events.CHAT_MSG_ADDON then events = w end end
local function server(msg, sender) events.scripts.OnEvent(events, "CHAT_MSG_ADDON", "AZDR", msg, "WHISPER", sender or "Azalea") end
local function tick(dt) now = now + dt; f.scripts.OnUpdate(f, dt) end

check("window starts hidden", not f:IsShown())
check("slash commands", SLASH_AZALEADAILY1 == "/diarias" and SLASH_AZALEADAILY2 == "/daily")
check("Esc closes it", UISpecialFrames[1] == "AzaleaDailyRewardsFrame")

-- login asks for the status after 3 s
events.scripts.OnEvent(events, "PLAYER_ENTERING_WORLD")
events.scripts.OnUpdate(events, 3.1)
check("login sends STATUS", sent[#sent][2] == "STATUS" and sent[#sent][3] == "WHISPER" and sent[#sent][4] == "Azalea")
server("ST:3:0:3600")
check("login reminder in chat", chat[1] and chat[1]:find("/diarias") ~= nil)

-- open: sound + status request
SlashCmdList.AZALEADAILY()
check("opens", f:IsShown())
check("open sound", sounds[#sounds] == "igCharacterInfoOpen")
check("open asks STATUS", sent[#sent][2] == "STATUS")
server("ST:3:0:3600")
check("claim enabled when pending", claim.enabled and claim.text == "RECLAMAR")

-- messages from another player are ignored
server("ST:9:1:10", "Otro")
check("ignores other senders", claim.enabled)

-- claim
claim.scripts.OnClick(claim)
check("click sends CLAIM", sent[#sent][2] == "CLAIM")
check("button locked while waiting", not claim.enabled)
server("OK:3:3600")
check("claimed state", not claim.enabled and claim.text == "RECLAMADO")
check("coin sound", sounds[#sounds] == "LOOTWINDOWCOINSOUND")
check("reward message", errors[#errors]:find("20 de oro") ~= nil)

-- error from the server re-asks the status
server("ER:BOLSA")
check("error message", errors[#errors]:find("bolsas") ~= nil)
check("error re-asks STATUS", sent[#sent][2] == "STATUS")

-- no answer -> message after 5 s
server("ST:14:0:100")
claim.scripts.OnClick(claim)
tick(6)
check("timeout re-enables claim", claim.enabled)

-- close
f:Hide()
check("close sound", sounds[#sounds] == "igCharacterInfoClose")

print(string.format("\n%d/%d passed", total - fails, total))
os.exit(fails == 0 and 0 or 1)
