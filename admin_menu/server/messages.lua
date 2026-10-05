-- =========================================================
--  MESSAGES PRIVÉS (MP STAFF) ET DISCUSSION STAFF
--  * Staff -> joueur : affiché à l'écran du joueur comme un MP du staff.
--  * Joueur -> staff : /r [message] répond au dernier staff qui lui a écrit.
--  * Staff <-> staff : discussion staff (menu rapide ou /sc).
--  Tout est limité en débit et enregistré dans les logs.
-- =========================================================
local AM = AdminMenu
local MC = Config.Messages
local Conversations = {}   -- [joueur] = { staff = id, at = os.time() }

local function clean(msg)
    if type(msg) ~= 'string' then return '' end
    msg = msg:gsub('[%c<>]', ' '):gsub('%s+', ' ')
    return msg:sub(1, MC.maxLength):match('^%s*(.-)%s*$')
end

local function staffCard(src)
    local r = AM.rankOf(src) or {}
    local label = 'Staff'
    if MC.showStaffName then label = AM.pname(src) end
    return { from = label, rank = MC.showRank and (r.label or 'Staff') or nil, color = r.color or '#d9b56a', fromId = src }
end

local function send(target, payload)
    payload.duration = MC.duration
    TriggerClientEvent('adminmenu:pm', target, payload)
end

-- Staff -> joueur
local function staffPm(src, target, message)
    if not AM.isOnline(target) then return AM.notify(src, 'Joueur introuvable.', 'error') end
    if target == src then return AM.notify(src, 'Tu ne peux pas t\'écrire à toi-même.', 'error') end
    message = clean(message)
    if message == '' then return AM.notify(src, 'Écris un message.', 'error') end
    if not AM.rateLimit(src, 'staff_pm', 6, 10000) then return AM.notify(src, 'Doucement : trop de messages d\'un coup.', 'error') end

    local card = staffCard(src)
    card.kind, card.message, card.reply = 'staff', message, MC.commands.reply
    send(target, card)
    Conversations[target] = { staff = src, at = os.time() }
    send(src, { kind = 'sent', to = ('%s [%d]'):format(AM.pname(target), target), message = message, toId = target })
    AM.addLog(src, 'Message privé', ('À %s [%d] : %s'):format(AM.pname(target), target, message))
end

-- Discussion staff
local function staffChat(src, message)
    message = clean(message)
    if message == '' then return AM.notify(src, 'Écris un message.', 'error') end
    if not AM.rateLimit(src, 'staff_chat', 6, 10000) then return AM.notify(src, 'Doucement : trop de messages d\'un coup.', 'error') end
    local card = staffCard(src)
    card.from = AM.pname(src)
    card.rank = (AM.rankOf(src) or {}).label
    card.kind, card.message = 'staffchat', message
    local n = 0
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if AM.hasPerm(id, 'staff_chat') and (not MC.staffChatOnDutyOnly or AM.onDuty(id) or id == src) then
            send(id, card)
            n = n + 1
        end
    end
    AM.addLog(src, 'Message staff', message)
    return n
end

-- ---------------------------------------------------------
--  Actions du menu (permissions + service vérifiés par le dispatcher)
-- ---------------------------------------------------------
AM.Actions.staff_pm = { perm = 'staff_pm', noRefresh = true, fn = function(src, d)
    staffPm(src, tonumber(d.target), d.message)
end }

AM.Actions.staff_chat = { perm = 'staff_chat', noRefresh = true, fn = function(src, d)
    staffChat(src, d.message)
end }

-- ---------------------------------------------------------
--  Commandes
-- ---------------------------------------------------------
local function canStaff(src, perm)
    if not AM.hasPerm(src, perm) then return false end
    if not AM.onDuty(src) then
        AM.notify(src, 'Tu es en mode RP : reprends ton service staff pour ça.', 'error')
        return false
    end
    return true
end

-- /mp [id] [message]
RegisterCommand(MC.commands.pm, function(src, args)
    if src == 0 or not canStaff(src, 'staff_pm') then return end
    local target = tonumber(args[1])
    if not target then return AM.notify(src, ('Utilisation : /%s [id] [message]'):format(MC.commands.pm), 'error') end
    table.remove(args, 1)
    staffPm(src, target, table.concat(args, ' '))
end, false)

-- /sc [message]
RegisterCommand(MC.commands.staffChat, function(src, args)
    if src == 0 or not canStaff(src, 'staff_chat') then return end
    if #args == 0 then return AM.notify(src, ('Utilisation : /%s [message]'):format(MC.commands.staffChat), 'error') end
    staffChat(src, table.concat(args, ' '))
end, false)

-- /r [message] : le joueur répond au dernier staff qui lui a écrit
RegisterCommand(MC.commands.reply, function(src, args)
    if src == 0 then return end
    local conv = Conversations[src]
    if not conv or os.time() - conv.at > MC.replyMinutes * 60 then
        return AM.notify(src, 'Aucun message du staff auquel répondre.', 'error')
    end
    if not AM.isOnline(conv.staff) then
        Conversations[src] = nil
        return AM.notify(src, 'Le membre du staff s\'est déconnecté. Utilise /report si besoin.', 'error')
    end
    local message = clean(table.concat(args, ' '))
    if message == '' then return AM.notify(src, ('Utilisation : /%s [ta réponse]'):format(MC.commands.reply), 'error') end
    if not AM.rateLimit(src, 'pm_reply', 4, 10000) then return AM.notify(src, 'Doucement : trop de messages d\'un coup.', 'error') end

    conv.at = os.time()
    send(conv.staff, { kind = 'reply', from = ('%s [%d]'):format(AM.pname(src), src), fromId = src, message = message, reply = MC.commands.pm })
    send(src, { kind = 'sentReply', message = message })
    AM.addLog(src, 'Réponse à un MP staff', ('À %s [%d] : %s'):format(AM.pname(conv.staff), conv.staff, message))
end, false)

AddEventHandler('playerDropped', function()
    Conversations[source] = nil
end)

-- Suggestions dans le chat
CreateThread(function()
    Wait(2000)
    TriggerClientEvent('chat:addSuggestion', -1, '/' .. MC.commands.reply, 'Répondre au dernier message du staff', { { name = 'message', help = 'Ta réponse' } })
end)
AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(5000, function()
        TriggerClientEvent('chat:addSuggestion', src, '/' .. MC.commands.reply, 'Répondre au dernier message du staff', { { name = 'message', help = 'Ta réponse' } })
    end)
end)
