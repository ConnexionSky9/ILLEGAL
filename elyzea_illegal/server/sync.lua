-- =========================================================
--  ELYZEA ILLÉGAL - SYNCHRONISATION
--  Admin / joueur → serveur → base → cache → tablettes ouvertes.
--  Seuls les joueurs concernés reçoivent quelque chose, et les
--  modifications rapprochées d'un même groupe sont regroupées.
-- =========================================================
Sync = {}
Sessions = {}   -- [src] = { groupId, via = 'f5' | 'ped' } : tablette ouverte (onglets : Tablet.tabsOf)

-- Résumé envoyé au client : utilisé par le F5 et l'invite du PNJ (aucune donnée sensible)
function Sync.membershipPayload(src)
    local g, _, grade = Cache.membership(Players.cid(src))
    if not g then return { inGroup = false } end
    return { inGroup = true, groupId = g.id, label = g.label, color = g.color, type = g.type, grade = grade and grade.label or '' }
end

function Sync.membership(src)
    if not src then return end
    TriggerClientEvent('illegal:client:membership', src, Sync.membershipPayload(src))
end

-- Liste publique des PNJ (ce que tout le monde voit déjà en jeu)
function Sync.pedList()
    local list = {}
    for _, g in pairs(Cache.groups) do
        if g.ped then
            list[#list + 1] = { groupId = g.id, label = g.label, model = g.ped.model, x = g.ped.x, y = g.ped.y, z = g.ped.z,
                h = g.ped.h, scenario = g.ped.scenario, version = g.ped.version }
        end
    end
    return list
end

function Sync.peds(target)
    TriggerClientEvent('illegal:client:peds', target or -1, Sync.pedList())
end

-- Rafraîchit les tablettes ouvertes sur un groupe (regroupé sur 150 ms)
local pending = {}
function Sync.group(groupId)
    if not groupId or pending[groupId] then return end
    pending[groupId] = true
    SetTimeout(150, function()
        pending[groupId] = nil
        for src, s in pairs(Sessions) do
            if s.groupId == groupId then Tablet.push(src) end
        end
    end)
end

-- Un joueur a changé de groupe / grade : son F5, son PNJ et sa tablette suivent
function Sync.player(cid)
    local src = cid and Players.bySrcCid(cid)
    if not src then return end
    Sync.membership(src)
    if Sessions[src] then Tablet.push(src) end
end

-- Tous les membres en ligne d'un groupe (ex. groupe renommé)
function Sync.allMembers(g)
    for cid in pairs(g.members) do Sync.player(cid) end
end

AddEventHandler('playerDropped', function() Sessions[source] = nil end)
