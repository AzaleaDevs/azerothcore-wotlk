local PLAYER_EVENT_ON_LOGIN = 3

local function OnPlayerLogin(event, player)
    player:SendBroadcastMessage(
        "Hola " .. player:GetName() .. " desde Lua"
    )
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnPlayerLogin)