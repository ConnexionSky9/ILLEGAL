-- =========================================================
--  TENUES DE SERVICE - CLIENT (tous les joueurs)
--  En service avec un métier qui a une tenue pour son grade :
--  on garde ses vêtements, on enfile la tenue. Fin de service,
--  changement de métier ou de grade sans tenue : on rend les vêtements.
-- =========================================================
local CFG = Config.Uniforms or {}
local COMPS = CFG.components or { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS = CFG.props or { 0, 1, 2, 6, 7 }

local Uniforms = {}
local wearing = false      -- tenue de service sur le dos
local civilian = nil       -- vêtements du joueur avant la tenue
local preview = nil        -- vêtements avant un essai (staff)
local lastKey = nil
local ready = false

local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`

local function gender()
    local m = GetEntityModel(PlayerPedId())
    if m == MALE then return 'male' elseif m == FEMALE then return 'female' end
end

local function snapshot()
    local ped = PlayerPedId()
    local o = { c = {}, p = {} }
    for _, c in ipairs(COMPS) do o.c[tostring(c)] = { GetPedDrawableVariation(ped, c), GetPedTextureVariation(ped, c) } end
    for _, p in ipairs(PROPS) do o.p[tostring(p)] = { GetPedPropIndex(ped, p), GetPedPropTextureIndex(ped, p) } end
    return o
end

local function apply(o)
    local ped = PlayerPedId()
    for k, v in pairs(o.c or {}) do SetPedComponentVariation(ped, tonumber(k), v[1], v[2], 0) end
    for k, v in pairs(o.p or {}) do
        if v[1] == -1 then ClearPedProp(ped, tonumber(k)) else SetPedPropIndex(ped, tonumber(k), v[1], v[2], true) end
    end
end

-- Tenue du grade, sinon celle du grade inférieur le plus proche
local function findOutfit(job, grade, g)
    local j = Uniforms[job]
    if not j or not g then return nil end
    for lvl = grade, 0, -1 do
        local e = j[tostring(lvl)]
        if e and e[g] then return e[g] end
    end
end

local function reloadSkin()
    if GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:reloadSkin')
    elseif GetResourceState('qb-clothing') == 'started' then
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
    elseif GetResourceState('esx_skin') == 'started' or GetResourceState('skinchanger') == 'started' then
        TriggerEvent('esx_skin:getLastSkin', function(skin) if skin then TriggerEvent('skinchanger:loadSkin', skin) end end)
    end
end

-- Vêtements civils sauvegardés sur le PC du joueur (par personnage) : survivent à un crash ou un redémarrage
local function charKey()
    local ok, cid = pcall(function()
        if GetResourceState('qbx_core') == 'started' then return (exports.qbx_core:GetPlayerData() or {}).citizenid end
        if GetResourceState('qb-core') == 'started' then return (exports['qb-core']:GetCoreObject().Functions.GetPlayerData() or {}).citizenid end
        if GetResourceState('es_extended') == 'started' then return (exports.es_extended:getSharedObject().GetPlayerData() or {}).identifier end
    end)
    return 'uniform_civilian_' .. tostring(ok and cid or 'default')
end

local function storeCivilian(o)
    if o then SetResourceKvp(charKey(), json.encode(o)) else DeleteResourceKvp(charKey()) end
end

local function storedCivilian()
    local raw = GetResourceKvpString(charKey())
    return raw and json.decode(raw) or nil
end

local function takeOff()
    local o = civilian or storedCivilian()
    if o then apply(o) else reloadSkin() end
    wearing, civilian = false, nil
    storeCivilian(nil)
end

-- Métier du joueur : nom, grade, en service
local function currentJob()
    local ok, name, grade, duty = pcall(function()
        if GetResourceState('qbx_core') == 'started' then
            local j = (exports.qbx_core:GetPlayerData() or {}).job
            if j then return j.name, (j.grade and j.grade.level) or 0, j.onduty == true end
        elseif GetResourceState('qb-core') == 'started' then
            local j = (exports['qb-core']:GetCoreObject().Functions.GetPlayerData() or {}).job
            if j then return j.name, (type(j.grade) == 'table' and j.grade.level) or 0, j.onduty == true end
        elseif GetResourceState('es_extended') == 'started' then
            local j = (exports.es_extended:getSharedObject().GetPlayerData() or {}).job
            if j then return j.name, tonumber(j.grade) or 0, true end
        end
    end)
    if ok then return name, grade or 0, duty end
end

local function check(force)
    if not ready or CFG.enabled == false then return end
    if preview then return end -- le staff essaie une tenue : on ne touche à rien
    local name, grade, duty = currentJob()
    if not name then return end
    local g = gender()
    local key = ('%s|%s|%s|%s'):format(name, grade, tostring(duty), g or '-')
    if key == lastKey and not force then return end
    lastKey = key

    local outfit = duty and findOutfit(name, grade, g)
    if outfit then
        if not wearing then
            -- Si une tenue civile est déjà sauvegardée (reconnexion en service), on la garde
            civilian = storedCivilian() or snapshot()
            storeCivilian(civilian)
        end
        apply(outfit)
        if not wearing and CFG.notify ~= false then Notify('Tenue de service enfilée.', 'info') end
        wearing = true
    elseif wearing then
        takeOff()
        if CFG.notify ~= false then Notify('Tu as remis tes vêtements.', 'info') end
    elseif not duty and storedCivilian() then
        -- Déconnecté ou crash pendant le service : on rend les vêtements à la prochaine vérification
        takeOff()
    end
end

RegisterNetEvent('adminmenu:uniforms', function(data)
    Uniforms = type(data) == 'table' and data or {}
    check(true)
end)

-- Réagit tout de suite aux changements de service / métier, et vérifie régulièrement
for _, ev in ipairs({ 'QBCore:Client:SetDuty', 'QBCore:Client:OnJobUpdate', 'esx:setJob' }) do
    RegisterNetEvent(ev, function() SetTimeout(300, function() check() end) end)
end

CreateThread(function()
    while true do
        Wait(2000)
        check()
    end
end)

-- On attend que l'apparence du personnage soit chargée avant de mémoriser ses vêtements
local function becomeReady(delay)
    SetTimeout(delay, function()
        ready = true
        lastKey = nil
        check(true)
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    ready, wearing, civilian, lastKey = false, false, nil, nil
    becomeReady(8000)
end)
RegisterNetEvent('esx:playerLoaded', function() becomeReady(8000) end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    TriggerServerEvent('adminmenu:uniforms:request')
    if NetworkIsPlayerActive(PlayerId()) then becomeReady(3000) end
end)

-- ---------------------------------------------------------
--  Outils du staff (onglets EMS / Police et tablettes staff des métiers)
-- ---------------------------------------------------------
local function captureOutfit()
    local g = gender()
    if not g then return nil, 'Ton personnage doit être un personnage homme ou femme du jeu (freemode).' end
    return { gender = g, outfit = snapshot() }
end

local function tryUniform(job, grade)
    local g = gender()
    local e = Uniforms[tostring(job)] and Uniforms[tostring(job)][tostring(grade)]
    local o = e and g and e[g]
    if not o then return false, ('Aucune tenue %s pour ce grade.'):format(g == 'female' and 'femme' or 'homme') end
    if not preview then preview = snapshot() end
    apply(o)
    return true
end

local function untryUniform()
    if preview then apply(preview) preview = nil end
    lastKey = nil
    return true
end

exports('CaptureOutfit', captureOutfit)
exports('TryUniform', tryUniform)
exports('UntryUniform', untryUniform)
exports('IsTryingUniform', function() return preview ~= nil end)
RegisterNUICallback('uniform_capture', function(_, cb)
    local r, err = captureOutfit()
    cb(r or { error = err })
end)

RegisterNUICallback('uniform_try', function(body, cb)
    local ok, err = tryUniform(body.job, body.grade)
    cb(ok and { ok = true } or { error = err })
end)

RegisterNUICallback('uniform_untry', function(_, cb)
    untryUniform()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and (wearing or preview) then
        if preview then apply(preview) elseif civilian then apply(civilian) end
    end
end)
