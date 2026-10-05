-- =========================================================
--  ELYZEA ILLÉGAL - VALIDATION DES DONNÉES (client + serveur)
--  Toutes les valeurs venant d'un joueur passent par ici côté serveur.
-- =========================================================
Illegal = Illegal or {}
local U = {}
Illegal.Utils = U

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

-- Texte : chaîne, sans caractères de contrôle, longueur bornée. nil si invalide.
function U.text(v, maxLen, allowEmpty)
    if type(v) == 'number' then v = tostring(v) end
    if type(v) ~= 'string' then return allowEmpty and '' or nil end
    v = trim(v:gsub('[%c]', ' '))
    if v == '' and not allowEmpty then return nil end
    if #v > (maxLen or 64) then v = v:sub(1, maxLen or 64) end
    return v
end

-- Identifiant interne : minuscules, chiffres, _ (2 à 32 caractères)
function U.ident(v)
    if type(v) ~= 'string' then return nil end
    v = trim(v):lower()
    if not v:match('^[a-z0-9_]+$') or #v < 2 or #v > 32 then return nil end
    return v
end

-- Entier fini dans [min, max]. nil si invalide (NaN, infini, hors bornes, texte…)
function U.int(v, min, max)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    v = math.floor(v)
    if (min and v < min) or (max and v > max) then return nil end
    return v
end

-- Montant d'argent strictement positif
function U.amount(v)
    return U.int(v, 1, Config.MaxAmount)
end

function U.number(v, min, max)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    if (min and v < min) or (max and v > max) then return nil end
    return v + 0.0
end

function U.color(v)
    if type(v) ~= 'string' then return nil end
    v = trim(v)
    if v:match('^#%x%x%x%x%x%x$') then return v:lower() end
    return nil
end

-- Modèle de PNJ : lettres, chiffres, _
function U.model(v)
    if type(v) ~= 'string' then return nil end
    v = trim(v)
    if not v:match('^[%w_]+$') or #v > 64 then return nil end
    return v
end

function U.typeKey(v)
    for _, t in ipairs(Config.Types) do if t.key == v then return v end end
    return nil
end

function U.typeLabel(v)
    for _, t in ipairs(Config.Types) do if t.key == v then return t.label end end
    return v
end

function U.category(v)
    for _, c in ipairs(Config.OrderCategories) do if c.key == v then return v end end
    return nil
end

-- Liste / table de permissions → ensemble { [perm] = true } ne contenant que des permissions connues
function U.permSet(v)
    local out = {}
    if type(v) ~= 'table' then return out end
    if v[1] ~= nil then
        for _, k in ipairs(v) do if Illegal.PermSet[k] then out[k] = true end end
    else
        for k, on in pairs(v) do if on == true and Illegal.PermSet[k] then out[k] = true end end
    end
    return out
end

function U.tabSet(v, default)
    local out = {}
    if type(v) ~= 'table' then
        for _, t in ipairs(Illegal.Tabs) do out[t.key] = default ~= false end
        return out
    end
    if v[1] ~= nil then
        for _, k in ipairs(v) do if Illegal.TabSet[k] then out[k] = true end end
    else
        for k, on in pairs(v) do if on == true and Illegal.TabSet[k] then out[k] = true end end
    end
    out.home = true
    return out
end

-- Coordonnées : x/y dans la carte, z raisonnable, heading 0-360
function U.coords(v)
    if type(v) ~= 'table' then return nil end
    local x, y, z = U.number(v.x, -10000, 10000), U.number(v.y, -10000, 10000), U.number(v.z, -500, 3000)
    local h = U.number(v.h or v.heading or 0, -720, 720)
    if not x or not y or not z or not h then return nil end
    return { x = x, y = y, z = z, h = h % 360.0 }
end

function U.money(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local neg = s:sub(1, 1) == '-'
    if neg then s = s:sub(2) end
    s = s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
    return (neg and '-' or '') .. s .. ' $'
end
