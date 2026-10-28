-- WoW 3.3.5a client. All eligibility and rewards are decided by the server.
BINDING_HEADER_AZALEA_DAILY_REWARDS_HEADER = 'Azalea Core'
BINDING_NAME_AZALEA_DAILY_REWARDS = 'Abrir recompensas diarias'

local PREFIX = 'AZ_DAILY_V1'
local MONEY_ICON = 'Interface\\Icons\\INV_Misc_Coin_01'
local ORB_ICON = 'Interface\\Icons\\Spell_Frost_FrozenCore'
-- Display only: the server is authoritative for actual rewards.
local goldRewards = { 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 3000, 5000, 10000, 20000 }
local state = { day = 1, claimed = false, ready = false, error = nil }
local cells = {}

local frame = CreateFrame('Frame', 'AzaleaDailyRewardsFrame', UIParent)
frame:SetSize(690, 420)
frame:SetPoint('CENTER')
frame:SetFrameStrata('DIALOG')
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag('LeftButton')
frame:SetScript('OnDragStart', frame.StartMoving)
frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
frame:SetBackdrop({ bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
  edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border', tile = true, tileSize = 32,
  edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
frame:Hide()
frame:SetScript('OnShow', function() PlaySound('igMainMenuOpen') end)
frame:SetScript('OnHide', function() PlaySound('igMainMenuClose') end)
table.insert(UISpecialFrames, 'AzaleaDailyRewardsFrame')

local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
title:SetPoint('TOP', 0, -22)
title:SetText('Recompensas diarias')
local subtitle = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
subtitle:SetPoint('TOP', title, 'BOTTOM', 0, -8)
subtitle:SetText('Una recompensa por día · Reinicio a medianoche de España')
local status = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
status:SetPoint('BOTTOM', 0, 31)
status:SetWidth(630)
local close = CreateFrame('Button', nil, frame, 'UIPanelCloseButton')
close:SetPoint('TOPRIGHT', -7, -6)

local function send(message)
  SendAddonMessage(PREFIX, message, 'WHISPER', UnitName('player'))
end

local function refresh()
  for day, cell in ipairs(cells) do
    local available = state.ready and not state.claimed and state.day == day
    if available then cell.button:Enable() else cell.button:Disable() end
    if state.ready and state.day == day then
      cell.label:SetText(day == 14 and 'Día 14+' or ('Día ' .. day))
      cell.label:SetTextColor(1, 0.82, 0)
    else
      cell.label:SetText('Día ' .. day)
      cell.label:SetTextColor(0.8, 0.8, 0.8)
    end
  end
  if state.error then status:SetText(state.error)
  elseif not state.ready then status:SetText('Esperando respuesta del servidor...')
  elseif state.claimed then status:SetText('Ya has reclamado hoy. Vuelve mañana para mantener la racha.')
  else status:SetText(state.day == 14 and 'Día 14: reclama un orbe cada día mientras mantengas la racha.'
    or ('Recompensa disponible: día ' .. state.day .. '.')) end
end

for day = 1, 14 do
  local cell = CreateFrame('Frame', nil, frame)
  local col, row = (day - 1) % 7, math.floor((day - 1) / 7)
  cell:SetSize(88, 145)
  cell:SetPoint('TOPLEFT', 27 + col * 91, -82 - row * 145)
  local label = cell:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  label:SetPoint('TOP', 0, -3)
  local icon = cell:CreateTexture(nil, 'ARTWORK')
  icon:SetSize(48, 48)
  icon:SetPoint('TOP', 0, -25)
  icon:SetTexture(day == 14 and ORB_ICON or MONEY_ICON)
  local reward = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  reward:SetPoint('TOP', icon, 'BOTTOM', 0, -6)
  reward:SetText(day == 14 and 'Orbe congelado' or (goldRewards[day] .. ' oro'))
  local button = CreateFrame('Button', nil, cell, 'UIPanelButtonTemplate')
  button:SetSize(80, 23)
  button:SetPoint('TOP', reward, 'BOTTOM', 0, -8)
  button:SetText('Reclamar')
  button:SetScript('OnClick', function()
    if state.ready and not state.claimed and state.day == day then
      state.ready = false
      refresh()
      send('CLAIM')
    end
  end)
  cells[day] = { label = label, button = button }
end

function AzaleaDailyRewards_Toggle()
  if frame:IsShown() then frame:Hide() else
    frame:Show()
    state.ready, state.error = false, nil
    refresh()
    send('STATUS')
  end
end

SLASH_AZALEADAILY1 = '/diarias'
SLASH_AZALEADAILY2 = '/dailyrewards'
SlashCmdList.AZALEADAILY = AzaleaDailyRewards_Toggle

local minimapButton = CreateFrame('Button', 'AzaleaDailyRewardsMinimap', Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetPoint('TOPLEFT', Minimap, 'TOPLEFT', -3, -40)
minimapButton:SetNormalTexture(MONEY_ICON)
minimapButton:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
minimapButton:SetScript('OnClick', function() AzaleaDailyRewards_Toggle() end)
minimapButton:SetScript('OnEnter', function(self)
  GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
  GameTooltip:SetText('Recompensas diarias')
  GameTooltip:AddLine('Clic para abrir o cerrar', 1, 1, 1)
  GameTooltip:Show()
end)
minimapButton:SetScript('OnLeave', function() GameTooltip:Hide() end)

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('CHAT_MSG_ADDON')
events:SetScript('OnEvent', function(_, event, ...)
  if event == 'PLAYER_LOGIN' then
    -- Do not overwrite an existing binding or a previously chosen addon binding.
    local existingAction = GetBindingAction('SHIFT-F12')
    if not GetBindingKey('CLICK AzaleaDailyRewardsMinimap:LeftButton') and (not existingAction or existingAction == '') then
      SetBinding('SHIFT-F12', 'CLICK AzaleaDailyRewardsMinimap:LeftButton')
      SaveBindings(GetCurrentBindingSet())
    end
    return
  end
  local prefix, message, channel, sender = ...
  if prefix ~= PREFIX or channel ~= 'WHISPER' or not sender then return end
  if Ambiguate and Ambiguate(sender, 'none') ~= UnitName('player') then return end
  if not Ambiguate and sender ~= UnitName('player') then return end
  local day, claimed = message:match('^STATE|(%d+)|([01])$')
  if day then
    day = tonumber(day)
    if day < 1 or day > 14 then return end
    state.day, state.claimed, state.ready, state.error = day, claimed == '1', true, nil
  elseif message:match('^ERROR|') then
    local errorCode = message:sub(7)
    if errorCode == 'money_limit' then
      state.ready, state.error = false, 'Superarias el limite de oro. Reduce tu oro y vuelve a intentarlo.'
    elseif errorCode == 'inventory_full' then
      state.ready, state.error = false, 'No hay espacio para el orbe. Libera una casilla y vuelve a intentarlo.'
    else
      state.ready, state.error = false, 'Servicio no disponible. Vuelve a intentarlo mas tarde.'
    end
  else return end
  refresh()
end)

refresh()
