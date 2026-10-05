-- Test du pont admin_menu/server/illegal.lua (lua5.4 tests/bridge.lua)
local passed, failed = 0, 0
local function check(c, l) if c then passed = passed + 1 else failed = failed + 1 print('  ✗ ' .. l) end end

local files = { meta = {} }
Storage = { load = function(n, d) return files[n] or d end, save = function(n, d) files[n] = d end }
Config = { Illegal = { resource = 'elyzea_illegal' } }
local notes, state = {}, 'started'
local perms = { [1] = { illegal_staff = true }, [2] = {} }
local calls = {}
local illegalMember = { [5] = { name = 'bloods', gradeLevel = 50 } }
exports = setmetatable({}, { __index = function() return {
    AdminAction = function(_, src, name, data) calls[#calls + 1] = { src, name, data } return true, 'ok ' .. name end,
    AdminData = function(_, src) return { available = true, for_src = src } end,
    GetGroupList = function() return { { name = 'bloods', label = 'Bloods', grades = { { level = 10, label = 'Recrue' }, { level = 100, label = 'OG' } } },
        { name = 'ballas', label = 'Ballas illégal', grades = {} } } end,
    GetPlayerGroup = function(_, src) return illegalMember[src] end,
} end })
-- Éditeur de map existant (simulé) : gangs Qbox et contrôle d'accès des coffres
local qbxGang = { [6] = { 'ballas', 2 }, [7] = { 'ballas', 1 } }
local baseList = { { name = 'ballas', label = 'Ballas', grades = { { level = 0, label = 'Recrue' } } } }
local function newBridge()
    Bridge = { GetGangs = function() return baseList end, GetGang = function(src) local g = qbxGang[src] if g then return g[1], g[2] end end }
    StashAccess = function(src, st)
        if not st.gangs or #st.gangs == 0 then return true end
        local gang, grade = Bridge.GetGang(src)
        for _, g in ipairs(st.gangs) do if gang == g.gang and (grade or 0) >= (g.grade or 0) then return true end end
        return false
    end
end
function GetResourceState() return state end
local function setup()
    newBridge()
    AdminMenu = { Actions = {}, DataHooks = {}, Ranks = { superadmin = { perms = {} }, moderateur = { perms = {} } },
        hasPerm = function(src, p) return perms[src][p] == true end, notify = function(src, m, t) notes[#notes + 1] = { src, m, t } end }
    dofile('admin_menu/server/illegal.lua')
end

setup()
check(AdminMenu.Actions.illegal and AdminMenu.Actions.illegal.perm == 'illegal_staff', 'action « illegal » protégée par illegal_staff')
check(AdminMenu.Ranks.superadmin.perms.illegal_staff == true and not AdminMenu.Ranks.moderateur.perms.illegal_staff, 'permission donnée au SuperAdmin uniquement')
check(files.meta.illegal_v1 == true and files.ranks ~= nil, 'migration enregistrée')
-- Le staff retire ensuite la permission : la migration ne la remet pas
files.ranks.superadmin.perms.illegal_staff = nil
setup()
check(AdminMenu.Ranks.superadmin.perms.illegal_staff == nil, 'migration exécutée une seule fois')

AdminMenu.Actions.illegal.fn(1, { name = 'createGroup', data = { name = 'x' } })
check(calls[1][1] == 1 and calls[1][2] == 'createGroup' and calls[1][3].name == 'x', 'action transmise à elyzea_illegal')
check(notes[#notes][2] == 'ok createGroup' and notes[#notes][3] == 'success', 'message de retour affiché')
local d = {}
AdminMenu.DataHooks[1](1, d)
check(d.illegal and d.illegal.for_src == 1, 'données ajoutées pour un staff autorisé')
local d2 = {}
AdminMenu.DataHooks[1](2, d2)
check(d2.illegal == nil, 'aucune donnée sans la permission')
state = 'stopped'
local d3 = {}
AdminMenu.DataHooks[1](1, d3)
check(d3.illegal and d3.illegal.available == false, 'ressource arrêtée : message dédié')
AdminMenu.Actions.illegal.fn(1, { name = 'x' })
check(notes[#notes][3] == 'error', 'ressource arrêtée : action refusée proprement')
-- Coffres
state = 'started'
local gangs = Bridge.GetGangs()
local names = {}
for _, g in ipairs(gangs) do names[g.name] = g end
check(names.bloods and names.bloods.label == 'Bloods (Illégal)' and #names.bloods.grades == 2, 'groupe ILLEGAL proposé dans les coffres avec ses grades')
check(names.ballas and names.ballas.label == 'Ballas', 'gang Qbox du même nom prioritaire (pas de doublon)')
check(#baseList == 1, 'liste Qbox en cache non modifiée')
local stash = { gangs = { { gang = 'bloods', grade = 40 } } }
check(StashAccess(5, stash) == true, 'membre Bloods (niveau 50) ouvre un coffre « Bloods 40+ »')
check(StashAccess(5, { gangs = { { gang = 'bloods', grade = 60 } } }) == false, 'grade insuffisant : refusé')
check(StashAccess(6, stash) == false, 'membre d\'un autre gang : refusé')
check(StashAccess(6, { gangs = { { gang = 'ballas', grade = 2 } } }) == true, 'accès gang Qbox inchangé')
check(StashAccess(7, { gangs = { { gang = 'ballas', grade = 2 } } }) == false, 'refus gang Qbox inchangé')
check(StashAccess(8, { gangs = {} }) == true, 'coffre ouvert à tous inchangé')
check(select(1, Bridge.GetGang(5)) == 'bloods' and select(1, Bridge.GetGang(6)) == 'ballas', 'GetGang : gang Qbox, sinon groupe ILLEGAL')
state = 'stopped'
check(#Bridge.GetGangs() == 1 and StashAccess(5, stash) == false, 'ressource arrêtée : comportement d\'origine')

print(('%d réussis, %d échoués'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
