-- =========================================================
--  Banc de test hors jeu : simule FiveM, Qbox, ox_lib, ox_inventory,
--  admin_menu et la base de données (en mémoire), pour exécuter
--  le vrai code serveur de elyzea_illegal.
-- =========================================================
local M = { clientEvents = {}, notifications = {}, timers = {}, net = {}, local_ = {}, callbacks = {}, exported = {}, prints = {} }

-- ---------- JSON minimal ----------
local function encode(v)
    local t = type(v)
    if t == 'nil' then return 'null' end
    if t == 'boolean' or t == 'number' then return tostring(v) end
    if t == 'string' then return '"' .. v:gsub('[%c"\\]', function(c) return string.format('\\u%04x', c:byte()) end) .. '"' end
    if t == 'table' then
        if next(v) == nil then return '{}' end
        if v[1] ~= nil then
            local out = {}
            for _, x in ipairs(v) do out[#out + 1] = encode(x) end
            return '[' .. table.concat(out, ',') .. ']'
        end
        local out = {}
        for k, x in pairs(v) do out[#out + 1] = encode(tostring(k)) .. ':' .. encode(x) end
        return '{' .. table.concat(out, ',') .. '}'
    end
    return 'null'
end
local function decode(s)
    local i = 1
    local function ws() i = s:find('%S', i) or #s + 1 end
    local val
    local function str()
        local j, out = i + 1, {}
        while true do
            local c = s:sub(j, j)
            if c == '"' then i = j + 1 return table.concat(out) end
            if c == '\\' then
                local n = s:sub(j + 1, j + 1)
                if n == 'u' then out[#out + 1] = string.char(tonumber(s:sub(j + 2, j + 5), 16)) j = j + 6
                else out[#out + 1] = n j = j + 2 end
            else out[#out + 1] = c j = j + 1 end
        end
    end
    function val()
        ws()
        local c = s:sub(i, i)
        if c == '{' then
            local o = {} i = i + 1 ws()
            if s:sub(i, i) == '}' then i = i + 1 return o end
            while true do
                ws() local k = str() ws() i = i + 1
                o[k] = val() ws()
                local d = s:sub(i, i) i = i + 1
                if d == '}' then return o end
            end
        elseif c == '[' then
            local a = {} i = i + 1 ws()
            if s:sub(i, i) == ']' then i = i + 1 return a end
            while true do
                a[#a + 1] = val() ws()
                local d = s:sub(i, i) i = i + 1
                if d == ']' then return a end
            end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
        elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
        elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
        else
            local num = s:match('^-?[%d%.eE+-]+', i)
            i = i + #num
            return tonumber(num)
        end
    end
    return val()
end
json = { encode = encode, decode = decode }

-- ---------- vector3 ----------
local V = {}
V.__index = V
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end

-- ---------- Joueurs ----------
M.players = {}
function M.addPlayer(src, cid, first, last, opts)
    opts = opts or {}
    local p = { name = 'fivem_' .. first, coords = opts.coords or vector3(0, 0, 0), heading = 90.0, items = { black_money = opts.dirty or 0 },
        canCarry = true, staff = opts.staff == true }
    p.qbx = {
        PlayerData = { source = src, citizenid = cid, charinfo = { firstname = first, lastname = last }, money = { cash = opts.cash or 0, bank = 0 } },
        Functions = {
            AddMoney = function(acc, n) p.qbx.PlayerData.money[acc] = (p.qbx.PlayerData.money[acc] or 0) + n return true end,
            RemoveMoney = function(acc, n)
                if (p.qbx.PlayerData.money[acc] or 0) < n then return false end
                p.qbx.PlayerData.money[acc] = p.qbx.PlayerData.money[acc] - n
                return true
            end,
        },
    }
    M.players[src] = p
    return p
end

local resources = {
    qbx_core = {
        GetPlayer = function(_, src) local p = M.players[tonumber(src)] return p and p.qbx end,
        GetPlayerByCitizenId = function(_, cid) for _, p in pairs(M.players) do if p.qbx.PlayerData.citizenid == cid then return p.qbx end end end,
    },
    ox_inventory = {
        GetItemCount = function(_, src, item) return M.players[src].items[item] or 0 end,
        RemoveItem = function(_, src, item, n)
            local p = M.players[src]
            if (p.items[item] or 0) < n then return false end
            p.items[item] = p.items[item] - n
            return true
        end,
        AddItem = function(_, src, item, n)
            local p = M.players[src]
            if not p.canCarry then return false, 'inventory_full' end
            p.items[item] = (p.items[item] or 0) + n
            return true
        end,
        CanCarryItem = function(_, src) return M.players[src].canCarry end,
    },
    admin_menu = {
        HasPermission = function(_, src, perm) local p = M.players[tonumber(src)] return p ~= nil and p.staff and perm == 'illegal_staff' end,
        AddLog = function() end,
    },
}
exports = setmetatable({}, {
    __call = function(_, name, fn) M.exported[name] = fn end,
    __index = function(_, res) return resources[res] end,
})
-- Exports de la ressource testée, appelés comme depuis une autre ressource
M.res = setmetatable({}, { __index = function(_, k) return function(_, ...) return M.exported[k](...) end end })

-- ---------- Natives / runtime ----------
function GetResourceState(res) return (resources[res] or res == 'elyzea_illegal') and 'started' or 'missing' end
function GetCurrentResourceName() return 'elyzea_illegal' end
function GetPlayerName(src) local p = M.players[tonumber(src) or -1] return p and p.name or nil end
function GetPlayers() local t = {} for src in pairs(M.players) do t[#t + 1] = tostring(src) end return t end
function GetPlayerPed(src) return M.players[tonumber(src)] and tonumber(src) or 0 end
function GetEntityCoords(ped) return M.players[ped].coords end
function GetEntityHeading(ped) return M.players[ped].heading end
local timer = 0
function GetGameTimer() timer = timer + 1 return timer end
function M.advance(ms) timer = timer + ms end
function SetTimeout(_, fn) M.timers[#M.timers + 1] = fn end
function M.flush() local t = M.timers M.timers = {} for _, fn in ipairs(t) do fn() end end
function CreateThread(fn) fn() end
function Wait() end
function PerformHttpRequest() end
function LoadResourceFile() return nil end
function RegisterNetEvent(name, fn) if fn then M.net[name] = fn end end
function AddEventHandler(name, fn) M.local_[name] = M.local_[name] or {} table.insert(M.local_[name], fn) end
function TriggerClientEvent(name, target, ...)
    table.insert(M.clientEvents, { name = name, target = target, args = { ... } })
    if name == 'illegal:client:notify' then table.insert(M.notifications, { target = target, msg = ..., kind = select(2, ...) }) end
end
lib = { callback = { register = function(name, fn) M.callbacks[name] = fn end } }

-- Un client déclenche un évènement réseau
function M.fromClient(src, name, ...)
    source = src
    local fn = M.net[name]
    assert(fn, 'évènement inconnu : ' .. name)
    fn(...)
    M.flush()
end

function M.lastNotify(src)
    for i = #M.notifications, 1, -1 do if M.notifications[i].target == src then return M.notifications[i].msg end end
end

function M.lastClientEvent(src, name)
    for i = #M.clientEvents, 1, -1 do
        local e = M.clientEvents[i]
        if e.target == src and e.name == name then return e end
    end
end

local realPrint = print
function print(...) local s = table.concat({ ... }, ' ') table.insert(M.prints, s) if os.getenv('VERBOSE') then realPrint(s) end end
M.print = realPrint
return M
