-- =========================================================
--  COIFFEUR / BARBIER - CLIENT
--  Caméra sur le visage, aperçu au survol, panier, paiement.
--  Optimisé : aucune boucle quand le salon est fermé, seuls les
--  natives de la partie modifiée sont rappelés à chaque survol.
-- =========================================================
local CFG = Config.Barber or {}
local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`
local HEAD_BONE = 31086

BarberOpen = false

local shop             -- données du salon envoyées par le serveur
local gender           -- 'male' | 'female'
local orig, state      -- tête d'origine / tête avec le panier
local preview          -- { key, value } : survol en cours
local inCart = {}
local awaiting = false
local accessories      -- chapeau, lunettes, masque retirés pendant la coupe

local GROUP = {
    hair = 'hair', hair_color = 'hair', hair_highlight = 'hair',
    beard = 'beard', beard_color = 'beard', beard_highlight = 'beard',
    brows = 'brows', brows_color = 'brows',
    chest = 'chest', chest_color = 'chest',
    eyes = 'eyes',
}
local OVERLAY = { beard = 1, brows = 2, chest = 10 }
local STYLE = { beard = true, brows = true, chest = true }

local function copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == 'table' and copy(v) or v end
    return o
end

local function normalize(key, v)
    if STYLE[key] then
        if type(v) ~= 'table' then return nil end
        local o = tonumber(v.o) or 1.0
        return { s = math.floor(tonumber(v.s) or -1), o = math.max(0.0, math.min(1.0, o)) + 0.0 }
    end
    v = tonumber(v)
    return v and math.floor(v) or nil
end

-- ---------------------------------------------------------
--  Lecture / application de la tête
-- ---------------------------------------------------------
local function overlayOf(p, idx)
    local ok, val, _, c1, c2, op = GetPedHeadOverlayData(p, idx)
    if not ok or val == nil or val == 255 then return { s = -1, o = 1.0 }, c1 or 0, c2 or 0 end
    return { s = val, o = math.floor((op or 1.0) * 100 + 0.5) / 100 }, c1 or 0, c2 or 0
end

local function snapshot(p)
    local s = {
        hair = GetPedDrawableVariation(p, 2), hairTex = GetPedTextureVariation(p, 2),
        hair_color = math.max(0, GetPedHairColor(p)), hair_highlight = math.max(0, GetPedHairHighlightColor(p)),
        eyes = math.max(0, GetPedEyeColor(p)),
    }
    s.beard, s.beard_color, s.beard_highlight = overlayOf(p, 1)
    s.brows, s.brows_color = overlayOf(p, 2)
    s.chest, s.chest_color = overlayOf(p, 10)
    return s
end

local function val(key)
    if preview and preview.key == key then return preview.value end
    return state[key]
end

local function applyGroup(g)
    local p = PlayerPedId()
    if g == 'hair' then
        local d = val('hair')
        SetPedComponentVariation(p, 2, d, (orig and d == orig.hair) and orig.hairTex or 0, 0)
        SetPedHairColor(p, val('hair_color'), val('hair_highlight'))
    elseif g == 'eyes' then
        SetPedEyeColor(p, val('eyes'))
    else
        local idx, st = OVERLAY[g], val(g)
        local c1 = val(g .. '_color')
        SetPedHeadOverlay(p, idx, st.s < 0 and 255 or st.s, st.o + 0.0)
        SetPedHeadOverlayColor(p, idx, 1, c1, g == 'beard' and val('beard_highlight') or c1)
    end
end

local function applyAll()
    for _, g in ipairs({ 'hair', 'beard', 'brows', 'chest', 'eyes' }) do applyGroup(g) end
end

-- Tête sauvegardée (mode interne) appliquée sans ouvrir le salon
local function applyLook(look)
    if type(look) ~= 'table' then return end
    local p = PlayerPedId()
    local m = GetEntityModel(p)
    if (look.model == 'female' and m ~= FEMALE) or (look.model ~= 'female' and m ~= MALE) then return end
    local keep = GetPedDrawableVariation(p, 2) == look.hair and GetPedTextureVariation(p, 2) or 0
    SetPedComponentVariation(p, 2, look.hair, keep, 0)
    SetPedHairColor(p, look.hair_color, look.hair_highlight)
    for g, idx in pairs(OVERLAY) do
        local st = look[g]
        if type(st) == 'table' then
            local c1 = look[g .. '_color'] or 0
            SetPedHeadOverlay(p, idx, st.s < 0 and 255 or st.s, (st.o or 1.0) + 0.0)
            SetPedHeadOverlayColor(p, idx, 1, c1, g == 'beard' and (look.beard_highlight or c1) or c1)
        end
    end
    SetPedEyeColor(p, look.eyes)
end

-- ---------------------------------------------------------
--  Accessoires qui cachent les cheveux
-- ---------------------------------------------------------
local function hideAccessories(p)
    if CFG.hideAccessories == false then return end
    accessories = {
        hat = { GetPedPropIndex(p, 0), GetPedPropTextureIndex(p, 0) },
        glasses = { GetPedPropIndex(p, 1), GetPedPropTextureIndex(p, 1) },
        mask = { GetPedDrawableVariation(p, 1), GetPedTextureVariation(p, 1) },
    }
    ClearPedProp(p, 0)
    ClearPedProp(p, 1)
    SetPedComponentVariation(p, 1, 0, 0, 0)
end

local function restoreAccessories()
    if not accessories then return end
    local p, a = PlayerPedId(), accessories
    accessories = nil
    if a.hat[1] >= 0 then SetPedPropIndex(p, 0, a.hat[1], a.hat[2], true) end
    if a.glasses[1] >= 0 then SetPedPropIndex(p, 1, a.glasses[1], a.glasses[2], true) end
    SetPedComponentVariation(p, 1, a.mask[1], a.mask[2], 0)
end

-- ---------------------------------------------------------
--  Caméra
-- ---------------------------------------------------------
local CAMS = {
    head = { dist = 0.95, z = 0.08, look = 0.03, fov = 38.0 },
    face = { dist = 0.62, z = 0.04, look = 0.02, fov = 34.0 },
    eyes = { dist = 0.42, z = 0.07, look = 0.065, fov = 28.0 },
    bust = { dist = 1.70, z = -0.12, look = -0.30, fov = 40.0 },
}
local cam, camMode, zoom, spin = nil, 'head', 1.0, 0
local anchor, fwd, baseHeading, radarWas
local cur = {}

local function camTarget()
    local m = CAMS[camMode] or CAMS.head
    local d = m.dist * zoom
    return anchor.x + fwd.x * d, anchor.y + fwd.y * d, anchor.z + m.z,
           anchor.z + m.look, m.fov
end

local function startCamera(p)
    baseHeading = GetEntityHeading(p)
    local r = math.rad(baseHeading)
    fwd = { x = -math.sin(r), y = math.cos(r) }
    local h = GetPedBoneCoords(p, HEAD_BONE, 0.0, 0.0, 0.0)
    anchor = { x = h.x, y = h.y, z = h.z }
    camMode, zoom, spin = 'head', 1.0, 0

    local x, y, z, lz, fov = camTarget()
    cur = { x = x, y = y, z = z, lz = lz, fov = fov }
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', x, y, z, 0.0, 0.0, 0.0, fov, false, 2)
    PointCamAtCoord(cam, anchor.x, anchor.y, lz)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 600, true, false)
end

local function stopCamera()
    if not cam then return end
    RenderScriptCams(false, true, 500, true, false)
    DestroyCam(cam, false)
    cam = nil
end

-- ---------------------------------------------------------
--  Ouverture / fermeture
-- ---------------------------------------------------------
local hairColors -- palette du jeu (calculée une seule fois)
local function palette()
    if hairColors then return hairColors end
    hairColors = {}
    for i = 0, GetNumHairColors() - 1 do
        local r, g, b = GetPedHairRgbColor(i)
        hairColors[#hairColors + 1] = ('#%02x%02x%02x'):format(r or 0, g or 0, b or 0)
    end
    return hairColors
end

local function closeBarber(revert)
    if not BarberOpen then return end
    BarberOpen = false
    awaiting = false
    if revert and orig then
        state, preview = copy(orig), nil
        applyAll()
    end
    preview = nil
    restoreAccessories()
    stopCamera()
    local p = PlayerPedId()
    if baseHeading then SetEntityHeading(p, baseHeading) end
    FreezeEntityPosition(p, false)
    if radarWas then DisplayRadar(true) end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'barber', open = false })
    shop, inCart = nil, {}
end

local function frameLoop()
    CreateThread(function()
        while BarberOpen do
            HideHudAndRadarThisFrame()
            local p = PlayerPedId()
            if IsEntityDead(p) or IsPedInAnyVehicle(p, false) then closeBarber(true) break end
            local ft = GetFrameTime()
            if spin ~= 0 then SetEntityHeading(p, GetEntityHeading(p) + spin * 110.0 * ft) end
            if cam then
                local x, y, z, lz, fov = camTarget()
                local k = math.min(1.0, ft * 9.0)
                cur.x = cur.x + (x - cur.x) * k
                cur.y = cur.y + (y - cur.y) * k
                cur.z = cur.z + (z - cur.z) * k
                cur.lz = cur.lz + (lz - cur.lz) * k
                cur.fov = cur.fov + (fov - cur.fov) * k
                SetCamCoord(cam, cur.x, cur.y, cur.z)
                PointCamAtCoord(cam, anchor.x, anchor.y, cur.lz)
                SetCamFov(cam, cur.fov)
            end
            Wait(0)
        end
    end)
end

local function labelsFor(list)
    local out = {}
    for k, v in pairs(list or {}) do out[tostring(k)] = v end
    return out
end

RegisterNetEvent('adminmenu:barber:show', function(data)
    if BarberOpen or type(data) ~= 'table' then return end
    if IsStaffMenuOpen and IsStaffMenuOpen() then return end
    local p = PlayerPedId()
    local m = GetEntityModel(p)
    if m ~= MALE and m ~= FEMALE then
        return Notify('Le coiffeur ne peut coiffer qu\'un personnage personnalisé (freemode).', 'error')
    end
    if IsPedInAnyVehicle(p, false) or IsEntityDead(p) then return end

    gender = m == MALE and 'male' or 'female'
    shop = data
    orig = snapshot(p)
    state, preview, inCart = copy(orig), nil, {}

    ClearPedTasks(p)
    FreezeEntityPosition(p, true)
    hideAccessories(p)
    radarWas = not IsRadarHidden()
    DisplayRadar(false)
    startCamera(p)

    BarberOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'barber', open = true,
        shop = data,
        gender = gender,
        counts = {
            hair = GetNumberOfPedDrawableVariations(p, 2),
            beard = GetPedHeadOverlayNum(1),
            brows = GetPedHeadOverlayNum(2),
            chest = GetPedHeadOverlayNum(10),
        },
        colors = palette(),
        current = orig,
        blacklist = (CFG.hairBlacklist or {})[gender] or {},
        customLabels = labelsFor((CFG.customHairLabels or {})[gender]),
        beardTab = gender == 'male' or CFG.beardForFemale == true,
        chestTab = gender == 'male' or CFG.chestForFemale == true,
    })
    frameLoop()
end)

-- ---------------------------------------------------------
--  Callbacks de l'interface
-- ---------------------------------------------------------
RegisterNUICallback('barber_preview', function(d, cb)
    cb('ok')
    if not BarberOpen or awaiting then return end
    local key = d.key
    local v = key and GROUP[key] and d.value ~= nil and normalize(key, d.value) or nil
    local old = preview
    if v == nil then
        preview = nil
        if old then applyGroup(GROUP[old.key]) end
        return
    end
    preview = { key = key, value = v }
    if old and GROUP[old.key] ~= GROUP[key] then applyGroup(GROUP[old.key]) end
    applyGroup(GROUP[key])
end)

RegisterNUICallback('barber_set', function(d, cb)
    cb('ok')
    if not BarberOpen or awaiting or not GROUP[d.key] then return end
    local v = normalize(d.key, d.value)
    if v == nil then return end
    state[d.key] = v
    inCart[d.key] = true
    preview = nil
    applyGroup(GROUP[d.key])
end)

RegisterNUICallback('barber_unset', function(d, cb)
    cb('ok')
    if not BarberOpen or awaiting or not GROUP[d.key] then return end
    state[d.key] = copy({ v = orig[d.key] }).v
    inCart[d.key] = nil
    preview = nil
    applyGroup(GROUP[d.key])
end)

RegisterNUICallback('barber_reset', function(_, cb)
    cb('ok')
    if not BarberOpen or awaiting then return end
    state, preview, inCart = copy(orig), nil, {}
    applyAll()
end)

RegisterNUICallback('barber_close', function(_, cb)
    cb('ok')
    if awaiting then return end
    closeBarber(true)
end)

RegisterNUICallback('barber_rotate', function(d, cb)
    cb('ok')
    if not BarberOpen then return end
    local p = PlayerPedId()
    SetEntityHeading(p, GetEntityHeading(p) + math.max(-45.0, math.min(45.0, tonumber(d.d) or 0.0)))
end)

RegisterNUICallback('barber_spin', function(d, cb)
    cb('ok')
    spin = math.max(-1, math.min(1, math.floor(tonumber(d.dir) or 0)))
end)

RegisterNUICallback('barber_zoom', function(d, cb)
    cb('ok')
    zoom = math.max(0.55, math.min(1.9, zoom + (tonumber(d.d) or 0) * 0.08))
end)

RegisterNUICallback('barber_cam', function(d, cb)
    cb('ok')
    if CAMS[d.mode] then camMode, zoom = d.mode, 1.0 end
end)

RegisterNUICallback('barber_pay', function(d, cb)
    cb('ok')
    if not BarberOpen or awaiting or not shop then return end
    local cart, n = {}, 0
    for key in pairs(inCart) do cart[key] = state[key] n = n + 1 end
    if n == 0 then return SendNUIMessage({ action = 'barber', event = 'payfail', msg = 'Ton panier est vide.' }) end
    local look = copy(state)
    look.hairTex, look.model = nil, gender
    awaiting = true
    TriggerServerEvent('adminmenu:barber:pay', shop.id, cart, look, d.method == 'bank' and 'bank' or 'cash')
    SetTimeout(10000, function()
        if awaiting and BarberOpen then
            awaiting = false
            SendNUIMessage({ action = 'barber', event = 'payfail', msg = 'Le serveur ne répond pas, réessaie.' })
        end
    end)
end)

-- ---------------------------------------------------------
--  Enregistrement de la nouvelle tête
-- ---------------------------------------------------------
local function saveMode()
    local m = CFG.saveMode or 'auto'
    if m ~= 'auto' then return m end
    if GetResourceState('illenium-appearance') == 'started' then return 'illenium' end
    if GetResourceState('esx_skin') == 'started' and GetResourceState('skinchanger') == 'started' then return 'esx' end
    return 'internal'
end

local function saveAppearance(look)
    local mode = saveMode()
    if mode == 'illenium' then
        local ok, app = pcall(function() return exports['illenium-appearance']:getPedAppearance(PlayerPedId()) end)
        if ok and app then TriggerServerEvent('illenium-appearance:server:saveAppearance', app) end
    elseif mode == 'esx' then
        TriggerEvent('skinchanger:getSkin', function(skin)
            if type(skin) ~= 'table' then return end
            skin.hair_1, skin.hair_2 = look.hair, GetPedTextureVariation(PlayerPedId(), 2)
            skin.hair_color_1, skin.hair_color_2 = look.hair_color, look.hair_highlight
            local function ov(prefix, st, c1, c2)
                skin[prefix .. '_1'] = math.max(0, st.s)
                skin[prefix .. '_2'] = st.s < 0 and 0 or math.floor(st.o * 10 + 0.5)
                skin[prefix .. '_3'] = c1
                if c2 then skin[prefix .. '_4'] = c2 end
            end
            ov('beard', look.beard, look.beard_color, look.beard_highlight)
            ov('eyebrows', look.brows, look.brows_color, look.brows_color)
            ov('chest', look.chest, look.chest_color)
            skin.eye_color = look.eyes
            TriggerEvent('skinchanger:loadSkin', skin)
            TriggerServerEvent('esx_skin:save', skin)
        end)
    end
    -- mode 'internal' : déjà enregistré par le serveur lors du paiement
    TriggerEvent('adminmenu:barber:saved', look, mode)
end

RegisterNetEvent('adminmenu:barber:result', function(ok, msg)
    if not BarberOpen then return end
    awaiting = false
    if not ok then
        return SendNUIMessage({ action = 'barber', event = 'payfail', msg = msg or 'Paiement refusé.' })
    end
    preview = nil
    restoreAccessories()            -- remis AVANT l'enregistrement pour ne pas perdre le chapeau
    applyAll()
    local look = copy(state)
    look.hairTex, look.model = nil, gender
    orig = copy(state)              -- la nouvelle tête devient la tête d'origine
    saveAppearance(look)
    SendNUIMessage({ action = 'barber', event = 'paid', msg = msg })
    SetTimeout(900, function() closeBarber(false) end)
    if saveMode() == 'internal' then SavedLook = look end
    Notify(msg or 'Nouvelle tête enregistrée !', 'success')
end)

-- ---------------------------------------------------------
--  Mode interne : la tête est remise à chaque spawn / chargement
-- ---------------------------------------------------------
SavedLook = nil
local reapplyToken = 0

local function reapply(delays)
    if saveMode() ~= 'internal' or not SavedLook then return end
    reapplyToken = reapplyToken + 1
    local token = reapplyToken
    for _, ms in ipairs(delays) do
        SetTimeout(ms, function()
            if token == reapplyToken and not BarberOpen then applyLook(SavedLook) end
        end)
    end
end

RegisterNetEvent('adminmenu:barber:look', function(look)
    SavedLook = look
    reapply({ 0, 2500, 7000 })
end)

local function requestLook()
    if saveMode() ~= 'internal' then return end
    SetTimeout(1500, function() TriggerServerEvent('adminmenu:barber:getLook') end)
end

AddEventHandler('playerSpawned', requestLook)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', requestLook)
RegisterNetEvent('esx:playerLoaded', requestLook)
-- Une ressource de vêtements recharge la peau : on remet la coupe par-dessus
RegisterNetEvent('qb-clothing:client:loadPlayerClothing', function() reapply({ 600, 2000 }) end)
AddEventHandler('skinchanger:modelLoaded', function() reapply({ 600 }) end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() and NetworkIsPlayerActive(PlayerId()) then requestLook() end
end)

-- ---------------------------------------------------------
--  Blips des salons posés dans l'éditeur
-- ---------------------------------------------------------
local blips = {}
function RefreshBarberBlips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    if CFG.enabled == false then return end
    for _, r in ipairs((Editor and Editor.peds) or {}) do
        local bb = r.npc and r.npc.barber
        if bb and bb.blip then
            local b = AddBlipForCoord(r.x + 0.0, r.y + 0.0, r.z + 0.0)
            SetBlipSprite(b, bb.blipSprite or CFG.blipSprite or 71)
            SetBlipColour(b, bb.blipColor or CFG.blipColor or 4)
            SetBlipScale(b, CFG.blipScale or 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(bb.name or 'Coiffeur')
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    if BarberOpen then closeBarber(true) end
end)

exports('IsBarberOpen', function() return BarberOpen end)
