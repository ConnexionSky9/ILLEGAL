-- =========================================================
--  RÉANIMATION DE ZONE : APERÇU AVANT DE VALIDER
--  Un cercle montre la zone autour du staff, les joueurs à terre
--  dedans sont signalés. Molette = rayon, E = réanimer, Retour = annuler
--  (mêmes touches que le mode placement, modifiables).
-- =========================================================
local preview = nil
local STEPS = { 5, 10, 15, 25, 35, 50, 75, 100, 150 }

local function keyToken(cmd)
    return ('~INPUT_%X~'):format((GetHashKey(cmd) | 0x80000000) & 0xFFFFFFFF)
end
local T = {
    confirm = keyToken('+admin_ed_confirm'), cancel = keyToken('+admin_ed_cancel'),
    up = keyToken('+admin_ed_rot_left'), down = keyToken('+admin_ed_rot_right'),
}

function IsZonePreview() return preview ~= nil end
function CancelRevivePreview() preview = nil end

local function closestStep(r)
    local best = 1
    for i, v in ipairs(STEPS) do if math.abs(v - r) < math.abs(STEPS[best] - r) then best = i end end
    return best
end

local function isPedDown(ped)
    return IsEntityDead(ped) or IsPedFatallyInjured(ped) or IsPedDeadOrDying(ped, true)
end

-- Appelé par les touches du mode placement (client/editor.lua)
function ZonePreviewKey(id)
    if not preview then return false end
    if id == 'confirm' then
        TriggerServerEvent('adminmenu:action', 'revive_area', { radius = STEPS[preview.step] })
        preview = nil
    elseif id == 'cancel' then
        preview = nil
        Notify('Réanimation de zone annulée.', 'info')
    elseif id == 'rot_left' then
        preview.step = math.min(preview.step + 1, #STEPS)
    elseif id == 'rot_right' then
        preview.step = math.max(preview.step - 1, 1)
    end
    return true
end

local BLOCK = { 24, 25, 37, 44, 140, 141, 142, 143, 257, 263, 264, 14, 15, 16, 17, 38, 51, 54, 47, 58, 80 }

local function loop()
    local list, total, down, nextScan = {}, 0, 0, 0
    while preview do
        Wait(0)
        if not preview then break end -- validé ou annulé pendant l'attente
        for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end

        local me = PlayerPedId()
        local c = GetEntityCoords(me)
        local r = STEPS[preview.step] + 0.0

        -- On recompte les joueurs 4 fois par seconde seulement
        if GetGameTimer() > nextScan then
            nextScan = GetGameTimer() + 250
            list, total, down = {}, 0, 0
            local r2 = r * r
            for _, pl in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(pl)
                local pc = GetEntityCoords(ped)
                local dx, dy, dz = pc.x - c.x, pc.y - c.y, pc.z - c.z
                if dx * dx + dy * dy + dz * dz <= r2 then
                    total = total + 1
                    if isPedDown(ped) then
                        down = down + 1
                        list[#list + 1] = { ped = ped, name = GetPlayerName(pl), id = GetPlayerServerId(pl) }
                    end
                end
            end
        end

        -- Zone au sol : cylindre translucide + anneau
        DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r * 2.0, r * 2.0, 1.6,
            79, 179, 169, 45, false, false, 2, false, nil, nil, false)
        DrawMarker(25, c.x, c.y, c.z - 0.97, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r * 2.0, r * 2.0, 1.0,
            79, 179, 169, 170, false, false, 2, false, nil, nil, false)

        -- Joueurs à terre dans la zone
        for i = 1, #list do
            local p = list[i]
            if DoesEntityExist(p.ped) then
                local pc = GetEntityCoords(p.ped)
                DrawMarker(2, pc.x, pc.y, pc.z + 1.1, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.35, 0.35, 0.35,
                    224, 67, 59, 220, true, false, 2, true, nil, nil, false)
                DrawText3D(vector3(pc.x, pc.y, pc.z + 1.55), ('~r~À terre~s~ %s [%d]'):format(p.name, p.id), 0.32)
            end
        end

        ShowKeysHud('revive', ('Réanimation de zone : %d m'):format(STEPS[preview.step]), {
            { keys = { EK('rot_left'), EK('rot_right') }, label = 'Changer le rayon' },
            { keys = { EK('confirm') }, label = 'Réanimer les joueurs à terre' },
            { keys = { EK('cancel') }, label = 'Annuler' },
        }, ('%d joueur(s) dans la zone, %d à terre'):format(total, down))
    end
end

function StartRevivePreview(radius)
    if not HasPerm('revive_area') then return end
    if preview then return end
    if IsPlacing() then return Notify('Termine d\'abord le placement en cours.', 'error') end
    preview = { step = closestStep(radius or Config.ReviveAreaRadius) }
    CreateThread(function()
        local ok, err = pcall(loop)
        if HudOwner == 'revive' then HideKeysHud() end
        if not ok then
            print(('^1[AdminMenu] Erreur aperçu réanimation : %s^7'):format(tostring(err)))
            preview = nil
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then preview = nil end
end)
