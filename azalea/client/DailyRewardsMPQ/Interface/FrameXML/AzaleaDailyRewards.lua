--[[
  Azalea Core · Recompensas diarias / Daily rewards  (feature/daily-rewards) · cliente 3.3.5a

  Se carga desde FrameXML.toc (va dentro del MPQ). Ventana con 14 días, botón RECLAMAR,
  botón en el minimapa, /diarias y /daily. Habla con lua_scripts/azalea_daily_rewards.lua
  por mensajes de addon (prefijo AZDR, susurro a uno mismo). El servidor decide el día y el premio.
]]

local PREFIX = "AZDR"
local GOLD = { 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 3000, 5000, 10000, 20000 }
local ORB_ITEM = 43102
local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
local ORB_ICON = GetItemIcon(ORB_ITEM) or "Interface\\Icons\\Spell_Frost_FrozenCore"
local ERRORS = {
  YA = "Ya has reclamado la recompensa de hoy.",
  BOLSA = "No tienes hueco en las bolsas para el Orbe congelado.",
  ORO = "Llevas demasiado oro encima para recibir este premio.",
  DB = "El servidor no ha podido guardar la reclamación. Inténtalo de nuevo.",
}

local state = { streak = 1, claimed = false, secs = 0, at = 0, known = false, waiting = false, sentAt = 0 }
local reminded = false

local function show(region, on) if on then region:Show() else region:Hide() end end

local function send(msg)
  state.waiting = true
  state.sentAt = GetTime()
  SendAddonMessage(PREFIX, msg, "WHISPER", UnitName("player"))
end

local function formatGold(n)
  if n >= 1000 then return string.format("%d.%03d", math.floor(n / 1000), n % 1000) end
  return tostring(n)
end

local function timeLeft()
  local left = math.max(0, state.secs - (GetTime() - state.at))
  local h, m = math.floor(left / 3600), math.floor(left % 3600 / 60)
  if h > 0 then return string.format("%d h %02d min", h, m) end
  return string.format("%d min %02d s", m, math.floor(left % 60))
end

---------------------------------------------------------------- ventana
local f = CreateFrame("Frame", "AzaleaDailyRewardsFrame", UIParent)
f:SetSize(640, 340)
f:SetPoint("CENTER", 0, 60)
f:SetFrameStrata("DIALOG")
f:SetToplevel(true)
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
f:Hide()
tinsert(UISpecialFrames, "AzaleaDailyRewardsFrame") -- Esc la cierra

local header = f:CreateTexture(nil, "ARTWORK")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetSize(360, 64)
header:SetPoint("TOP", 0, 12)
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", header, "TOP", 0, -14)
title:SetText("Recompensas diarias")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local streakText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
streakText:SetPoint("TOP", 0, -34)

-- 14 casillas en dos filas de 7
local slots = {}
for i = 1, 14 do
  local s = CreateFrame("Button", nil, f)
  s:SetSize(76, 96)
  local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
  s:SetPoint("TOPLEFT", 36 + col * 82, -60 - row * 104)

  s.day = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  s.day:SetPoint("TOP", 0, 0)
  s.day:SetText(i == 14 and "Día 14+" or ("Día " .. i))

  s.bg = s:CreateTexture(nil, "BACKGROUND")
  s.bg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  s.bg:SetSize(76, 76)
  s.bg:SetPoint("TOP", 0, -6)

  s.icon = s:CreateTexture(nil, "ARTWORK")
  s.icon:SetSize(42, 42)
  s.icon:SetPoint("TOP", 0, -23)
  s.icon:SetTexture(i == 14 and ORB_ICON or COIN_ICON)

  s.glow = s:CreateTexture(nil, "OVERLAY")
  s.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  s.glow:SetBlendMode("ADD")
  s.glow:SetSize(80, 80)
  s.glow:SetPoint("CENTER", s.icon, "CENTER", 0, 0)
  s.glow:Hide()

  s.check = s:CreateTexture(nil, "OVERLAY")
  s.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  s.check:SetSize(26, 26)
  s.check:SetPoint("BOTTOMRIGHT", s.icon, "BOTTOMRIGHT", 8, -8)
  s.check:Hide()

  s.amount = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  s.amount:SetPoint("TOP", s.icon, "BOTTOM", 0, -6)
  if i == 14 then
    s.amount:SetText("|cff80d0ffOrbe congelado|r")
  else
    s.amount:SetText("|cffffd100" .. formatGold(GOLD[i]) .. " oro|r")
  end

  s:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if i == 14 then
      GameTooltip:SetHyperlink("item:" .. ORB_ITEM)
      GameTooltip:AddLine("Día 14 y siguientes, mientras no se rompa la racha.", 0.5, 0.8, 1, true)
    else
      GameTooltip:SetText("Día " .. i)
      GameTooltip:AddLine(formatGold(GOLD[i]) .. " de oro", 1, 0.82, 0)
    end
    GameTooltip:Show()
  end)
  s:SetScript("OnLeave", function() GameTooltip:Hide() end)
  slots[i] = s
end

local claim = CreateFrame("Button", "AzaleaDailyRewardsClaimButton", f, "UIPanelButtonTemplate")
claim:SetSize(240, 40)
claim:SetPoint("BOTTOM", 0, 40)
claim:SetText("RECLAMAR")
claim:SetNormalFontObject("GameFontNormalLarge")
claim:SetHighlightFontObject("GameFontHighlightLarge")
claim:SetDisabledFontObject("GameFontDisableLarge")
claim:SetScript("OnClick", function(self)
  self:Disable()
  send("CLAIM")
end)

local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
info:SetPoint("TOP", claim, "BOTTOM", 0, -6)

local function refresh()
  if not state.known then
    streakText:SetText("")
    for i = 1, 14 do
      local s = slots[i]
      s.glow:Hide(); s.check:Hide(); s.icon:SetDesaturated(nil); s:SetAlpha(1)
    end
    claim:Disable()
    info:SetText(state.waiting and "Consultando al servidor..." or "|cffff5050Sin respuesta del servidor.|r")
    return
  end
  local shown = math.min(state.streak, 14) -- casilla del día que toca (o del cobrado hoy)
  if state.claimed then
    streakText:SetText(string.format("Racha: |cff00ff00%d %s|r", state.streak, state.streak == 1 and "día" or "días"))
  elseif state.streak > 1 then
    streakText:SetText(string.format("Racha: |cff00ff00%d días|r · hoy toca el día %d", state.streak - 1, state.streak))
  else
    streakText:SetText("Empieza tu racha hoy")
  end
  for i = 1, 14 do
    local s = slots[i]
    local done = i < shown or (i == shown and state.claimed)
    show(s.check, done)
    s.icon:SetDesaturated(done and 1 or nil)
    show(s.glow, i == shown and not state.claimed)
    s:SetAlpha((i > shown) and 0.55 or 1)
  end
  if state.claimed then
    claim:Disable()
    claim:SetText("RECLAMADO")
  else
    claim:SetText("RECLAMAR")
    if state.waiting then claim:Disable() else claim:Enable() end
  end
end

-- cuenta atrás y brillo de la casilla de hoy
local elapsed = 0
f:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  local a = 0.55 + 0.45 * math.sin(GetTime() * 4)
  for i = 1, 14 do if slots[i].glow:IsShown() then slots[i].glow:SetAlpha(a) end end
  if elapsed < 0.25 then return end
  elapsed = 0
  if state.waiting and GetTime() - state.sentAt > 5 then state.waiting = false; refresh() end
  if state.known then
    if state.claimed then
      info:SetText("Siguiente recompensa en " .. timeLeft())
      if state.secs - (GetTime() - state.at) <= 0 then send("STATUS") end
    else
      info:SetText("El día cambia a medianoche (hora de Madrid)")
    end
  end
end)

f:SetScript("OnShow", function()
  PlaySound("igCharacterInfoOpen")
  send("STATUS")
  refresh()
end)
f:SetScript("OnHide", function() PlaySound("igCharacterInfoClose") end)

local function toggle() if f:IsShown() then f:Hide() else f:Show() end end

---------------------------------------------------------------- botón del minimapa
local mm = CreateFrame("Button", "AzaleaDailyRewardsMinimapButton", Minimap)
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
local angle = math.rad(225)
mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local mmIcon = mm:CreateTexture(nil, "BACKGROUND")
mmIcon:SetTexture(COIN_ICON)
mmIcon:SetSize(20, 20)
mmIcon:SetPoint("TOPLEFT", 6, -5)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetSize(53, 53)
mmBorder:SetPoint("TOPLEFT")
local mmGlow = mm:CreateTexture(nil, "OVERLAY")
mmGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
mmGlow:SetBlendMode("ADD")
mmGlow:SetSize(56, 56)
mmGlow:SetPoint("CENTER", mmIcon, "CENTER")
mmGlow:Hide()
mm:SetScript("OnClick", toggle)
mm:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("Recompensas diarias")
  GameTooltip:AddLine(state.known and not state.claimed and "¡Tienes una recompensa pendiente!" or "Clic para abrir", 1, 1, 1)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
mm:SetScript("OnUpdate", function()
  if mmGlow:IsShown() then mmGlow:SetAlpha(0.5 + 0.5 * math.sin(GetTime() * 4)) end
end)

---------------------------------------------------------------- comandos
SLASH_AZALEADAILY1 = "/diarias"
SLASH_AZALEADAILY2 = "/daily"
SlashCmdList["AZALEADAILY"] = toggle

---------------------------------------------------------------- respuestas del servidor
local events = CreateFrame("Frame")
local loginTimer
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event, prefix, msg, _, sender)
  if event == "PLAYER_ENTERING_WORLD" then
    loginTimer = 3 -- se pregunta el estado unos segundos después de entrar
    self:SetScript("OnUpdate", function(frame, dt)
      loginTimer = loginTimer - dt
      if loginTimer <= 0 then frame:SetScript("OnUpdate", nil); send("STATUS") end
    end)
    return
  end
  if prefix ~= PREFIX or sender ~= UnitName("player") then return end
  state.waiting = false
  local kind, a, b, c = strsplit(":", msg)
  if kind == "ST" then
    state.streak, state.claimed = tonumber(a), b == "1"
    state.secs, state.at, state.known = tonumber(c), GetTime(), true
    if not state.claimed and not reminded then
      reminded = true
      DEFAULT_CHAT_FRAME:AddMessage("|cffff3d8b[Azalea]|r ¡Tienes tu recompensa diaria pendiente! Escribe |cffffd100/diarias|r.")
    end
  elseif kind == "OK" then
    state.streak, state.claimed = tonumber(a), true
    state.secs, state.at, state.known = tonumber(b), GetTime(), true
    PlaySound("LOOTWINDOWCOINSOUND")
    local reward = state.streak <= 13 and (formatGold(GOLD[state.streak]) .. " de oro") or "Orbe congelado"
    UIErrorsFrame:AddMessage("¡Recompensa del día " .. state.streak .. ": " .. reward .. "!", 1, 0.82, 0, 1, 5)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff3d8b[Azalea]|r Recompensa diaria del día " .. state.streak .. ": " .. reward .. ".")
  elseif kind == "ER" then
    UIErrorsFrame:AddMessage(ERRORS[a] or "No se ha podido reclamar.", 1, 0.1, 0.1, 1, 5)
    send("STATUS")
  end
  show(mmGlow, state.known and not state.claimed)
  if f:IsShown() then refresh() end
end)
