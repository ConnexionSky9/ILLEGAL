-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : F5
--  F5 › <Nom du groupe> ouvre la tablette du groupe du joueur.
--  Le nom affiché vient du serveur ; à l'ouverture, le serveur
--  relit lui-même le groupe du joueur.
--  Tu as déjà ton propre menu F5 ? Mets Config.F5.enabled = false
--  et appelle exports.elyzea_illegal:OpenTablet() depuis ton menu
--  (exports.elyzea_illegal:GetGroupLabel() donne le nom à afficher).
-- =========================================================
function OpenGroupTablet()
    if not Membership.inGroup then return Notify('Tu ne fais partie d\'aucun groupe illégal.', 'error') end
    TriggerServerEvent('illegal:server:open', 'f5')
end

local function openF5()
    if IsTabletOpen() or IsNuiFocused() or IsPauseMenuActive() then return end
    if not Membership.inGroup then return end   -- pas de groupe : F5 reste libre pour le reste du serveur
    if Config.F5.mode == 'direct' then return OpenGroupTablet() end
    lib.registerContext({
        id = 'illegal_f5',
        title = 'Menu',
        options = {
            {
                title = Membership.label,
                description = Membership.grade ~= '' and ('Grade : ' .. Membership.grade) or nil,
                icon = 'mask',
                iconColor = Membership.color,
                onSelect = OpenGroupTablet,
            },
        },
    })
    lib.showContext('illegal_f5')
end

if Config.F5.enabled then
    lib.addKeybind({
        name = 'illegal_f5',
        description = 'Menu du groupe illégal',
        defaultKey = Config.F5.key,
        onReleased = openF5,
    })
end

exports('OpenTablet', function()
    if not Membership.inGroup then return false end
    TriggerServerEvent('illegal:server:open', 'export')
    return true
end)
exports('GetGroupLabel', function() return Membership.inGroup and Membership.label or nil end)
exports('IsInGroup', function() return Membership.inGroup == true end)
