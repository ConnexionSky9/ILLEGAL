-- =========================================================
--  ELYZEA ILLÉGAL - MEMBRES
--  Règles pour un joueur (le staff n'a aucune limite) :
--   - il n'agit que sur les membres de SON groupe, de grade inférieur au sien ;
--   - il ne donne qu'un grade inférieur au sien.
--  Un personnage n'appartient qu'à un seul groupe illégal.
-- =========================================================
Members = {}
local U = Illegal.Utils

local function below(actor, grade)
    if actor.isAdmin then return true end
    return actor.grade ~= nil and grade ~= nil and grade.level < actor.grade.level
end

local function memberLabel(m) return m.name ~= '' and m.name or m.cid end

-- Cible d'un recrutement : ID d'un joueur en ligne, ou citizenid (staff uniquement, même hors ligne)
local function resolveTarget(actor, target)
    local id = U.int(target, 1, 65535)
    if id and GetPlayerName(id) then
        local cid = Players.cid(id)
        if not cid then return nil, 'Ce joueur n\'a pas encore choisi son personnage.' end
        return { cid = cid, name = Players.charName(id), src = id }
    end
    if actor.isAdmin and type(target) == 'string' and target:match('^[%w]+$') and #target <= 50 then
        local ch = DB.findCharacter(target)
        if ch then return { cid = ch.citizenid, name = ch.name, src = Players.bySrcCid(ch.citizenid) } end
        return nil, 'Aucun personnage avec ce citizenid.'
    end
    return nil, 'Joueur introuvable : vérifie l\'ID (il doit être connecté).'
end

function Members.add(actor, g, target, gradeId)
    local t, err = resolveTarget(actor, target)
    if not t then return false, err end
    if Cache.memberOf[t.cid] then
        local other = Cache.group(Cache.memberOf[t.cid])
        return false, ('%s fait déjà partie d\'un groupe illégal%s.'):format(t.name, actor.isAdmin and other and (' (' .. other.label .. ')') or '')
    end
    local grade = gradeId and g.grades[tonumber(gradeId) or -1] or Cache.lowestGrade(g)
    if not grade then return false, 'Grade introuvable.' end
    if not below(actor, grade) then return false, 'Tu ne peux recruter qu\'à un grade inférieur au tien.' end

    if not DB.insertMember(t.cid, g.id, grade.id, t.name) then return false, 'Erreur de la base de données : membre non ajouté.' end
    g.members[t.cid] = { cid = t.cid, groupId = g.id, gradeId = grade.id, name = t.name, joined = os.time(), lastSeen = os.time() }
    Cache.memberOf[t.cid] = g.id

    Log(actor, g.id, 'Recrutement', ('%s a recruté %s dans %s (%s)'):format(actor.name, t.name, g.label, grade.label))
    if t.src then Players.notify(t.src, ('Tu as rejoint %s en tant que %s.'):format(g.label, grade.label), 'success') end
    Sync.player(t.cid)
    Sync.group(g.id)
    return true, ('%s a rejoint %s.'):format(t.name, g.label)
end

function Members.remove(actor, g, cid)
    local m = g.members[cid]
    if not m then return false, 'Ce joueur ne fait pas partie du groupe.' end
    if not actor.isAdmin and cid == actor.cid then return false, 'Utilise « Quitter le groupe » pour partir.' end
    if not below(actor, g.grades[m.gradeId]) then return false, 'Tu ne peux exclure que des membres de grade inférieur au tien.' end
    if DB.deleteMember(cid) == nil then return false, 'Erreur de la base de données.' end
    g.members[cid], Cache.memberOf[cid] = nil, nil

    Log(actor, g.id, 'Exclusion', ('%s a exclu %s de %s'):format(actor.name, memberLabel(m), g.label))
    local src = Players.bySrcCid(cid)
    if src and Missions then Missions.leave(src, 'Tu ne fais plus partie du groupe.') end
    if src then
        Players.notify(src, ('Tu ne fais plus partie de %s.'):format(g.label), 'error')
        if Sessions[src] then Sessions[src] = nil TriggerClientEvent('illegal:client:close', src) end
    end
    Sync.player(cid)
    Sync.group(g.id)
    return true, ('%s a été retiré du groupe.'):format(memberLabel(m))
end

-- Un membre quitte lui-même le groupe (le dernier chef ne peut pas partir)
function Members.leave(actor, g)
    local m = g.members[actor.cid]
    if not m then return false, 'Tu ne fais pas partie de ce groupe.' end
    local grade = g.grades[m.gradeId]
    if grade and grade.boss then
        local otherBoss = false
        for cid, x in pairs(g.members) do
            if cid ~= actor.cid and g.grades[x.gradeId] and g.grades[x.gradeId].boss then otherBoss = true end
        end
        if not otherBoss then return false, 'Tu es le seul chef : nomme un autre chef (staff) avant de partir.' end
    end
    if DB.deleteMember(actor.cid) == nil then return false, 'Erreur de la base de données.' end
    g.members[actor.cid], Cache.memberOf[actor.cid] = nil, nil
    if Missions then Missions.leave(actor.src, 'Tu as quitté le groupe.') end
    Sessions[actor.src] = nil
    TriggerClientEvent('illegal:client:close', actor.src)
    Log(actor, g.id, 'Départ', ('%s a quitté %s'):format(actor.name, g.label))
    Sync.player(actor.cid)
    Sync.group(g.id)
    return true, ('Tu as quitté %s.'):format(g.label)
end

function Members.setGrade(actor, g, cid, gradeId, verb)
    local m = g.members[cid]
    if not m then return false, 'Ce joueur ne fait pas partie du groupe.' end
    local from, to = g.grades[m.gradeId], g.grades[tonumber(gradeId) or -1]
    if not to then return false, 'Grade introuvable.' end
    if from and from.id == to.id then return false, 'Il a déjà ce grade.' end
    if not actor.isAdmin and cid == actor.cid then return false, 'Tu ne peux pas changer ton propre grade.' end
    if not below(actor, from) then return false, 'Tu ne peux agir que sur les membres de grade inférieur au tien.' end
    if not below(actor, to) then return false, 'Tu ne peux donner qu\'un grade inférieur au tien.' end

    if DB.setMemberGrade(cid, to.id) == nil then return false, 'Erreur de la base de données.' end
    m.gradeId = to.id
    verb = verb or ((from and to.level < from.level) and 'rétrogradé' or 'promu')
    Log(actor, g.id, 'Changement de grade', ('%s a %s %s au grade %s (%s)'):format(actor.name, verb, memberLabel(m), to.label, g.label))
    local src = Players.bySrcCid(cid)
    if src then Players.notify(src, ('Ton grade dans %s : %s.'):format(g.label, to.label), 'inform') end
    Sync.player(cid)
    Sync.group(g.id)
    return true, ('%s est maintenant %s.'):format(memberLabel(m), to.label)
end

-- Grade juste au-dessus (dir = 1) ou en dessous (dir = -1)
function Members.step(actor, g, cid, dir)
    local m = g.members[cid]
    if not m then return false, 'Ce joueur ne fait pas partie du groupe.' end
    local sorted = Cache.sortedGrades(g)
    for i, gr in ipairs(sorted) do
        if gr.id == m.gradeId then
            local nxt = sorted[i + dir]
            if not nxt then return false, dir == 1 and 'Il a déjà le grade le plus haut.' or 'Il a déjà le grade le plus bas.' end
            return Members.setGrade(actor, g, cid, nxt.id, dir == 1 and 'promu' or 'rétrogradé')
        end
    end
    return false, 'Grade introuvable.'
end

-- Connexion / déconnexion : dernière connexion et nom du personnage à jour
function Members.touch(src)
    local cid = Players.cid(src)
    local g = cid and Cache.group(Cache.memberOf[cid])
    if not g then return end
    local m = g.members[cid]
    m.lastSeen = os.time()
    m.name = Players.charName(src)
    DB.touchMember(cid, m.name)
end
