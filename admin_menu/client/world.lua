-- =========================================================
--  MÉTÉO / HEURE / BLACKOUT (synchronisés par le serveur)
--  ⚠ Désactive tout autre script de météo (vSync, qb-weathersync…)
-- =========================================================
local World = nil
local appliedWeather = nil
local transitioning = false

local SNOW = { XMAS = true, SNOWLIGHT = true, BLIZZARD = true }

RegisterNetEvent('adminmenu:syncWorld', function(w)
    World = w
    NetworkOverrideClockTime(w.hour, w.minute, 0)
    PauseClock(w.freeze)

    if appliedWeather ~= w.weather then
        local first = appliedWeather == nil
        appliedWeather = w.weather
        if not first then
            transitioning = true
            ClearOverrideWeather()
            ClearWeatherTypePersist()
            SetWeatherTypeOverTime(w.weather, 15.0)
            Wait(15000)
            transitioning = false
        end
    end
end)

-- Ré-application légère : au changement, puis toutes les 10 s seulement
-- (évite d'écraser la météo chaque seconde)
local lastApplied = ''
CreateThread(function()
    while true do
        if World and not transitioning then
            local sig = ('%s|%s|%s'):format(World.weather, tostring(World.blackout), tostring(World.freeze))
            if sig ~= lastApplied or GetGameTimer() % 10000 < 1000 then
                lastApplied = sig
                SetWeatherTypePersist(World.weather)
                SetWeatherTypeNow(World.weather)
                SetWeatherTypeNowPersist(World.weather)
                local snow = SNOW[World.weather] == true
                SetForceVehicleTrails(snow)
                SetForcePedFootstepsTracks(snow)
                SetArtificialLightsState(World.blackout)
                SetArtificialLightsStateAffectsVehicles(false)
            end
            if World.freeze then NetworkOverrideClockTime(World.hour, World.minute, 0) end
        end
        Wait(1000)
    end
end)
