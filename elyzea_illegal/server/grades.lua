-- =========================================================
--  ELYZEA ILLÉGAL - GRADES
--  Règles pour un joueur (le staff n'a aucune limite) :
--   - il ne touche qu'aux grades strictement inférieurs au sien ;
--   - il ne crée / place un grade que sous son propre niveau ;
--   - il ne donne que des permissions qu'il possède lui-même ;
--   - seul le staff crée ou modifie un grade « chef » (boss).
--  actor.grade = grade de l'acteur (nil pour le staff)
-- =========================================================
Grades = {}
local U = Illegal.Utils
local MAX_LEVEL = 1000

local function levelTaken(g, level, exceptId)
    for _, gr in pairs(g.grades) do
        if gr.level == level and gr.id ~= exceptId then return gr end
    end
end

local function canTouch(actor, grade)
    if actor.isAdmin then return true end
    return actor.grade and grade.level < actor.grade.level
end

-- Ne garde que les permissions que l'acteur peut donner
local function allowedPerms(actor, perms)
    if actor.isAdmin or (actor.grade and actor.grade.boss) then return perms end
    local out = {}
    for k in pairs(perms) do if actor.grade and actor.grade.perms[k] then out[k] = true end end
    return out
end

local function readGrade(actor, g, data, current)
    local name = U.ident(data.name)
    if not name then return nil, 'Nom de grade invalide : minuscules, chiffres ou _ (ex : lieutenant).' end
    local label = U.text(data.label, 64)
    if not label then return nil, 'Donne un label au grade (ex : Lieutenant).' end
    local level = U.int(data.level, 0, MAX_LEVEL)
    if not level then return nil, ('Niveau invalide (0 à %d).'):format(MAX_LEVEL) end
    if not actor.isAdmin and level >= actor.grade.level then
        return nil, ('Le niveau doit être inférieur au tien (%d).'):format(actor.grade.level)
    end
    for _, gr in pairs(g.grades) do
        if gr.name == name and (not current or gr.id ~= current.id) then return nil, ('Le grade « %s » existe déjà dans ce groupe.'):format(name) end
    end
    local clash = levelTaken(g, level, current and current.id)
    if clash then return nil, ('Le niveau %d est déjà pris par « %s ».'):format(level, clash.label) end

    local boss = current and current.boss or false
    if actor.isAdmin and data.boss ~= nil then boss = data.boss == true end
    local perms = data.perms ~= nil and allowedPerms(actor, U.permSet(data.perms)) or (current and current.perms or {})
    return { name = name, label = label, level = level, boss = boss, perms = perms }
end

function Grades.create(actor, g, data)
    local n = 0
    for _ in pairs(g.grades) do n = n + 1 end
    if n >= 30 then return false, 'Maximum 30 grades par groupe.' end
    local gr, err = readGrade(actor, g, data)
    if not gr then return false, err end
    local id = DB.insertGrade(g.id, gr)
    if not id then return false, 'Erreur de la base de données : grade non créé.' end
    gr.id, gr.groupId = id, g.id
    g.grades[id] = gr
    Log(actor, g.id, 'Grade créé', ('%s : %s (niveau %d)'):format(g.label, gr.label, gr.level))
    Sync.group(g.id)
    return true, ('Grade « %s » créé.'):format(gr.label)
end

function Grades.update(actor, g, gradeId, data)
    local cur = g.grades[tonumber(gradeId) or -1]
    if not cur then return false, 'Grade introuvable.' end
    if not canTouch(actor, cur) then return false, 'Tu ne peux modifier que les grades inférieurs au tien.' end
    local gr, err = readGrade(actor, g, data, cur)
    if not gr then return false, err end
    -- Toujours au moins un grade chef
    if cur.boss and not gr.boss then
        local other = false
        for _, x in pairs(g.grades) do if x.boss and x.id ~= cur.id then other = true end end
        if not other then return false, 'Il faut au moins un grade chef (OG) dans le groupe.' end
    end
    gr.id, gr.groupId = cur.id, g.id
    if DB.updateGrade(gr) == nil then return false, 'Erreur de la base de données.' end
    g.grades[cur.id] = gr
    Log(actor, g.id, 'Grade modifié', ('%s : %s (niveau %d)'):format(g.label, gr.label, gr.level))
    for cid, m in pairs(g.members) do if m.gradeId == cur.id then Sync.player(cid) end end
    Sync.group(g.id)
    return true, ('Grade « %s » enregistré.'):format(gr.label)
end

function Grades.delete(actor, g, gradeId)
    local cur = g.grades[tonumber(gradeId) or -1]
    if not cur then return false, 'Grade introuvable.' end
    if not canTouch(actor, cur) then return false, 'Tu ne peux supprimer que les grades inférieurs au tien.' end
    local sorted = Cache.sortedGrades(g)
    if #sorted <= 1 then return false, 'Un groupe doit garder au moins un grade.' end
    if cur.boss then
        local other = false
        for _, x in pairs(g.grades) do if x.boss and x.id ~= cur.id then other = true end end
        if not other then return false, 'Impossible de supprimer le seul grade chef (OG).' end
    end
    -- Les membres de ce grade passent au grade juste en dessous (sinon le plus bas restant)
    local fallback
    for _, gr in ipairs(sorted) do
        if gr.id ~= cur.id and gr.level < cur.level then fallback = gr end
    end
    if not fallback then for _, gr in ipairs(sorted) do if gr.id ~= cur.id then fallback = gr break end end end

    if not DB.deleteGrade(cur.id, fallback.id) then return false, 'Erreur de la base de données.' end
    g.grades[cur.id] = nil
    local moved = 0
    for cid, m in pairs(g.members) do
        if m.gradeId == cur.id then m.gradeId = fallback.id moved = moved + 1 Sync.player(cid) end
    end
    Log(actor, g.id, 'Grade supprimé', ('%s : %s%s'):format(g.label, cur.label, moved > 0 and (' · %d membre(s) passé(s) %s'):format(moved, fallback.label) or ''))
    Sync.group(g.id)
    return true, ('Grade « %s » supprimé.'):format(cur.label)
end

-- Réorganiser : échange le niveau avec le grade voisin (dir = 1 monter, -1 descendre)
function Grades.move(actor, g, gradeId, dir)
    local cur = g.grades[tonumber(gradeId) or -1]
    if not cur then return false, 'Grade introuvable.' end
    dir = dir == 1 and 1 or -1
    local sorted = Cache.sortedGrades(g)
    local idx
    for i, gr in ipairs(sorted) do if gr.id == cur.id then idx = i end end
    local other = sorted[idx + dir]
    if not other then return false, 'Ce grade est déjà tout en ' .. (dir == 1 and 'haut.' or 'bas.') end
    if not canTouch(actor, cur) or not canTouch(actor, other) then return false, 'Tu ne peux réorganiser que les grades inférieurs au tien.' end
    local oldCur, oldOther = cur.level, other.level
    local target = oldCur == oldOther and oldOther + dir or oldOther   -- niveaux égaux (anciennes données) : on les départage
    cur.level, other.level = target, oldCur
    if not DB.swapGradeLevels(cur, other) then
        cur.level, other.level = oldCur, oldOther
        return false, 'Erreur de la base de données.'
    end
    Log(actor, g.id, 'Grades réorganisés', ('%s : %s ↔ %s'):format(g.label, cur.label, other.label))
    for cid, m in pairs(g.members) do if m.gradeId == cur.id or m.gradeId == other.id then Sync.player(cid) end end
    Sync.group(g.id)
    return true, 'Ordre des grades enregistré.'
end
