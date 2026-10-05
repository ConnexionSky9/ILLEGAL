-- =========================================================
--  TABLETTE STAFF EMS - CLIENT
--  Bouton « Ouvrir la tablette staff EMS » de l'onglet 🚑 du menu.
-- =========================================================
RegisterNUICallback('ems_open', function(_, cb)
    cb('ok')
    local cfg = Config.Ems or {}
    if GetResourceState(cfg.staffResource or 'elyzea_ems_staff') ~= 'started' then
        return Notify(('La ressource « %s » n\'est pas démarrée.'):format(cfg.staffResource or 'elyzea_ems_staff'), 'error')
    end
    CloseMenu()
    Wait(150)
    ExecuteCommand(cfg.command or 'ems_staff')
end)
