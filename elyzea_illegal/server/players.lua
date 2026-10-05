-- =========================================================
--  ELYZEA ILLÉGAL - JOUEURS (Qbox), ARGENT DU JOUEUR, ANTI-SPAM
-- =========================================================
Players = {}

function Players.get(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- citizenid du personnage joué : toujours relu sur Qbox (jamais envoyé par le client)
function Players.cid(src)
    local p = Players.get(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

function Players.charName(src)
    local p = Players.get(src)
    local ci = p and p.PlayerData and p.PlayerData.charinfo
    if ci and (ci.firstname or ci.lastname) then
        return (((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''))
    end
    return GetPlayerName(src) or ('#' .. tostring(src))
end

function Players.bySrcCid(cid)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(cid) end)
    if ok and p and p.PlayerData then return p.PlayerData.source end
    return nil
end

function Players.notify(src, msg, kind)
    if not src or src == 0 then print('[ILLEGAL] ' .. tostring(msg)) return end
    TriggerClientEvent('illegal:client:notify', src, msg, kind or 'inform')
end

-- Acteur d'une action (sert aux logs et à l'historique)
function Players.actor(src, isAdmin)
    return { src = src, cid = Players.cid(src), name = Players.charName(src), isAdmin = isAdmin == true,
        staffName = GetPlayerName(src) }
end

-- ---------------------------------------------------------
--  Anti-spam : n actions par fenêtre et par joueur
-- ---------------------------------------------------------
local Buckets = {}
function Players.rateLimit(src, key, max, windowMs)
    local now = GetGameTimer()
    local b = Buckets[src]
    if not b then b = {} Buckets[src] = b end
    local e = b[key]
    if not e or now - e.t > windowMs then e = { t = now, n = 0 } b[key] = e end
    e.n = e.n + 1
    return e.n <= max
end
AddEventHandler('playerDropped', function() Buckets[source] = nil end)

-- ---------------------------------------------------------
--  Argent du joueur
--  Propre : compte Qbox. Sale : objet ox_inventory ou compte Qbox.
--  Chaque fonction renvoie true seulement si l'opération a réellement eu lieu.
-- ---------------------------------------------------------
local function dirtyIsItem() return Config.DirtyMoney.type == 'item' end

function Players.getMoney(src, account)
    local p = Players.get(src)
    if not p then return 0 end
    if account == 'clean' then
        return tonumber(p.PlayerData.money and p.PlayerData.money[Config.CleanMoney.account]) or 0
    end
    if dirtyIsItem() then
        local ok, n = pcall(function() return exports.ox_inventory:GetItemCount(src, Config.DirtyMoney.item) end)
        return ok and tonumber(n) or 0
    end
    return tonumber(p.PlayerData.money and p.PlayerData.money[Config.DirtyMoney.account]) or 0
end

function Players.removeMoney(src, account, amount, reason)
    local p = Players.get(src)
    if not p then return false end
    if Players.getMoney(src, account) < amount then return false end
    if account == 'clean' then
        return p.Functions.RemoveMoney(Config.CleanMoney.account, amount, reason) == true
    end
    if dirtyIsItem() then
        local ok, res = pcall(function() return exports.ox_inventory:RemoveItem(src, Config.DirtyMoney.item, amount) end)
        return ok and res == true
    end
    return p.Functions.RemoveMoney(Config.DirtyMoney.account, amount, reason) == true
end

function Players.addMoney(src, account, amount, reason)
    local p = Players.get(src)
    if not p then return false end
    if account == 'clean' then
        return p.Functions.AddMoney(Config.CleanMoney.account, amount, reason) == true
    end
    if dirtyIsItem() then
        local okCarry, can = pcall(function() return exports.ox_inventory:CanCarryItem(src, Config.DirtyMoney.item, amount) end)
        if okCarry and can == false then return false end
        local ok, res = pcall(function() return exports.ox_inventory:AddItem(src, Config.DirtyMoney.item, amount) end)
        return ok and res == true
    end
    return p.Functions.AddMoney(Config.DirtyMoney.account, amount, reason) == true
end

-- Objet d'une commande livrée
function Players.giveItem(src, item, count)
    if GetResourceState('ox_inventory') ~= 'started' then return false end
    local okCarry, can = pcall(function() return exports.ox_inventory:CanCarryItem(src, item, count) end)
    if okCarry and can == false then return false end
    local ok, res = pcall(function() return exports.ox_inventory:AddItem(src, item, count) end)
    return ok and res == true
end

-- ---------------------------------------------------------
--  Permission staff (système existant de admin_menu)
-- ---------------------------------------------------------
function Players.isStaff(src)
    if GetResourceState(Config.AdminResource) ~= 'started' then return false end
    local ok, res = pcall(function() return exports[Config.AdminResource]:HasPermission(src, Config.AdminPermission) end)
    return ok and res == true
end
