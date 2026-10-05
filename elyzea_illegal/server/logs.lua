-- =========================================================
--  ELYZEA ILLÉGAL - LOGS CENTRALISÉS
--  Une seule fonction pour tout : console, base de données,
--  onglet Logs du menu staff (+ son Discord) et Discord du module.
--    Log(actor, groupId, action, details)
-- =========================================================
local RECENT_MAX = 30
RecentLogs = {}   -- [groupId] = { {actor, action, details, created}, ... } (plus récent en premier)

function Log(actor, groupId, action, details)
    local who = (type(actor) == 'table' and actor.name) or tostring(actor or 'Système')
    details = tostring(details or '')
    if #details > 500 then details = details:sub(1, 500) end

    print(('^1[ILLEGAL]^7 %s : %s%s'):format(who, action, details ~= '' and (' | ' .. details) or ''))
    DB.insertLog(groupId, who, action, details)

    if groupId then
        local list = RecentLogs[groupId]
        if not list then list = {} RecentLogs[groupId] = list end
        table.insert(list, 1, { actor = who, action = action, details = details, created = os.time() })
        if #list > RECENT_MAX then list[#list] = nil end
    end

    -- Onglet Logs du menu staff (et son webhook Discord)
    local src = type(actor) == 'table' and actor.src or 0
    if GetResourceState(Config.AdminResource) == 'started' then
        pcall(function() exports[Config.AdminResource]:AddLog(src or 0, '[ILLEGAL] ' .. action, ('%s%s'):format(who, details ~= '' and (' · ' .. details) or '')) end)
    end

    if Config.DiscordWebhook ~= '' then
        PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({
            username = 'Logs Illégal',
            embeds = { { title = '[ILLEGAL] ' .. action, description = ('**Par :** %s\n%s'):format(who, details), color = 14697275,
                footer = { text = os.date('%d/%m/%Y %H:%M:%S') } } },
        }), { ['Content-Type'] = 'application/json' })
    end
end
