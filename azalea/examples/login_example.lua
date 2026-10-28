-- Optional example / Ejemplo opcional: not deployed automatically.
local function OnLogin(event, player)
    player:SendBroadcastMessage("Azalea Core: ALE funciona / ALE is working")
end

RegisterPlayerEvent(3, OnLogin)
