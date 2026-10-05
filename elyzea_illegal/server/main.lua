-- =========================================================
--  ELYZEA ILLÉGAL - DÉMARRAGE, CONNEXIONS, EXPORTS
-- =========================================================
local Loaded = {}   -- [src] = citizenid (pour la dernière connexion à la déconnexion)

CreateThread(function()
    DB.install()
    Cache.load()
    Sync.peds()   -- joueurs déjà connectés (redémarrage de la ressource)
    for _, p in ipairs(GetPlayers()) do
        local src = tonumber(p)
        local cid = Players.cid(src)
        if cid then Loaded[src] = cid Sync.membership(src) end
    end
end)

-- Personnage chargé : le joueur retrouve son groupe, son grade et ses permissions
local function onLoaded(src)
    src = tonumber(src)
    if not src or not Cache.ready then return end
    local cid = Players.cid(src)
    if not cid then return end
    Loaded[src] = cid
    Members.touch(src)
    Sync.membership(src)
    Sync.peds(src)
    Deliveries.resend(src)
end

-- Évènements serveur uniquement (AddEventHandler) : un client ne peut pas les déclencher
local function fromPlayer(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if src then onLoaded(src) end
end
AddEventHandler('QBCore:Server:PlayerLoaded', fromPlayer)
AddEventHandler('qbx_core:server:playerLoaded', fromPlayer)

-- Le client demande son état (démarrage de la ressource, reconnexion…)
RegisterNetEvent('illegal:server:hello', function()
    local src = source
    if not Players.rateLimit(src, 'hello', 3, 10000) then return end
    if not Cache.ready then return end
    Sync.peds(src)
    local cid = Players.cid(src)
    if cid then Loaded[src] = cid end
    Sync.membership(src)
    Deliveries.resend(src)
end)

-- Changement de personnage / déconnexion : on enregistre la dernière connexion
local function onUnload(src)
    local cid = Loaded[src]
    Loaded[src] = nil
    Sessions[src] = nil
    local g = cid and Cache.group(Cache.memberOf[cid])
    if g and g.members[cid] then
        g.members[cid].lastSeen = os.time()
        DB.touchMember(cid, g.members[cid].name)
        Sync.group(g.id)
    end
end
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) if tonumber(src) then onUnload(tonumber(src)) end end)
AddEventHandler('playerDropped', function() onUnload(source) end)

-- ---------------------------------------------------------
--  Exports pour d'autres ressources (lecture seule)
-- ---------------------------------------------------------
-- Groupe d'un joueur : { id, name, label, type, grade, gradeLevel, boss } ou nil
exports('GetPlayerGroup', function(src)
    local g, _, grade = Cache.membership(Players.cid(src))
    if not g then return nil end
    return { id = g.id, name = g.name, label = g.label, type = g.type, grade = grade.name, gradeLabel = grade.label, gradeLevel = grade.level, boss = grade.boss }
end)

exports('HasGroupPermission', function(src, perm)
    local _, _, grade = Cache.membership(Players.cid(src))
    return Cache.hasPerm(grade, perm)
end)

-- Groupes et leurs grades (coffres de l'éditeur de map d'admin_menu : accès « Groupes illégaux »)
exports('GetGroupList', function()
    local list = {}
    for _, g in pairs(Cache.groups) do
        local grades = {}
        for _, gr in ipairs(Cache.sortedGrades(g)) do grades[#grades + 1] = { level = gr.level, label = gr.label } end
        list[#list + 1] = { name = g.name, label = g.label, type = g.type, grades = grades }
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end)
