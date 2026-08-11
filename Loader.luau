--[[ =========================================================================
     SYMBIOS HUB · Loader
     One loadstring that auto-detects the game and pulls the right script.
     Distribute THIS file's raw URL; to support a new game just add one line.

       loadstring(game:HttpGet("https://raw.githubusercontent.com/JenwitK/AnimeRoll-Script/refs/heads/main/Loader.luau"))()
     ========================================================================= ]]

local HUB = "SYMBIOS HUB"

-- PlaceId -> raw script URL. Add more games here, one line each.
local Games = {
    -- Roll Anime to Fight!
    [107653945083776] = "https://raw.githubusercontent.com/JenwitK/AnimeRoll-Script/refs/heads/main/RollAnimeHub.luau",
    -- [PLACEID]      = "https://raw.githubusercontent.com/.../YourScript.luau",
}

--------------------------------------------------------------------------------
local StarterGui = game:GetService("StarterGui")
local function notify(text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = HUB, Text = text, Duration = dur or 5 })
    end)
end

local placeId = game.PlaceId
local url = Games[placeId]

if not url then
    notify("Game not supported (Place ID: " .. tostring(placeId) .. ")", 6)
    return warn("[" .. HUB .. "] Unsupported game, PlaceId:", placeId)
end

local ok, res = pcall(function() return game:HttpGet(url) end)
if not (ok and type(res) == "string" and #res > 0) then
    notify("Download failed — check your network / URL.", 6)
    return warn("[" .. HUB .. "] HttpGet failed:", res)
end

local fn, err = loadstring(res)
if not fn then
    notify("Hub script has a syntax error.", 6)
    return warn("[" .. HUB .. "] loadstring error:", err)
end

local ranOk, runErr = pcall(fn)
if not ranOk then
    notify("Hub crashed while starting.", 6)
    return warn("[" .. HUB .. "] runtime error:", runErr)
end
