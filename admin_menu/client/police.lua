-- =========================================================
--  TABLETTE STAFF POLICE - CLIENT
--  Bouton « Ouvrir la tablette staff Police » de l'onglet 🚓 du menu.
-- =========================================================
RegisterNUICallback('police_open', function(_, cb)
    cb('ok')
    local cfg = Config.Police or {}
    if GetResourceState(cfg.staffResource or 'elyzea_police_staff') ~= 'started' then
        return Notify(('La ressource « %s » n\'est pas démarrée.'):format(cfg.staffResource or 'elyzea_police_staff'), 'error')
    end
    CloseMenu()
    Wait(150)
    ExecuteCommand(cfg.command or 'police_staff')
end)
