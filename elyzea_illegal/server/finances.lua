-- =========================================================
--  ELYZEA ILLÉGAL - FINANCES
--  Deux comptes strictement séparés : « clean » (argent propre)
--  et « dirty » (argent sale). Aucune fonction ne les mélange.
--
--  Anti-duplication :
--   - un verrou par groupe : une seule opération d'argent à la fois ;
--   - la base refuse tout retrait qui rendrait le solde négatif
--     (UPDATE … WHERE solde >= montant) ;
--   - l'argent du joueur est retiré AVANT d'être crédité au groupe,
--     et le groupe est débité AVANT de payer le joueur ;
--     en cas d'échec, l'étape précédente est annulée.
-- =========================================================
Finances = {}
local U = Illegal.Utils
local Locks = {}

local function validAccount(a) return a == 'clean' or a == 'dirty' end

function Finances.lock(groupId)
    if Locks[groupId] then return false end
    Locks[groupId] = true
    return true
end
function Finances.unlock(groupId) Locks[groupId] = nil end

-- Écrit l'historique (base + cache) après un mouvement réussi
local function record(g, actor, account, typ, signed, before, reason)
    local tx = { account = account, type = typ, amount = signed, before = before, after = g.finance[account],
        actor = actor.name, actorCid = actor.cid, reason = reason or '' }
    tx.id = DB.insertTransaction(g.id, tx)
    tx.created = os.time()
    Cache.pushTransaction(g, tx)
end

-- Crédit / débit du compte du groupe (sans toucher au joueur). À appeler sous verrou.
function Finances.credit(g, account, amount)
    if not DB.addBalance(g.id, account, amount) then return false end
    g.finance[account] = g.finance[account] + amount
    return true
end

function Finances.debit(g, account, amount)
    if g.finance[account] < amount then return false end
    if not DB.removeBalance(g.id, account, amount) then return false end
    g.finance[account] = g.finance[account] - amount
    return true
end

-- ---------------------------------------------------------
--  Joueur : dépôt / retrait avec son propre argent
-- ---------------------------------------------------------
function Finances.deposit(actor, g, account, amount)
    if not validAccount(account) then return false, 'Compte invalide.' end
    amount = U.amount(amount)
    if not amount then return false, 'Montant invalide.' end
    if not Finances.lock(g.id) then return false, 'Une opération est déjà en cours, réessaie.' end

    local before = g.finance[account]
    if not Players.removeMoney(actor.src, account, amount, 'illegal-deposit') then
        Finances.unlock(g.id)
        return false, ('Tu n\'as pas %s en %s.'):format(U.money(amount), account == 'clean' and 'argent propre' or 'argent sale')
    end
    if not Finances.credit(g, account, amount) then
        Players.addMoney(actor.src, account, amount, 'illegal-deposit-refund')   -- remboursement
        Finances.unlock(g.id)
        return false, 'Erreur de la base de données : dépôt annulé et remboursé.'
    end
    record(g, actor, account, 'deposit', amount, before)
    Finances.unlock(g.id)

    Log(actor, g.id, 'Dépôt', ('%s a déposé %s d\'%s dans %s (%s → %s)'):format(actor.name, U.money(amount), Illegal.Accounts[account]:lower(),
        g.label, U.money(before), U.money(g.finance[account])))
    Sync.group(g.id)
    return true, ('%s déposés.'):format(U.money(amount))
end

function Finances.withdraw(actor, g, account, amount)
    if not validAccount(account) then return false, 'Compte invalide.' end
    amount = U.amount(amount)
    if not amount then return false, 'Montant invalide.' end
    if not Finances.lock(g.id) then return false, 'Une opération est déjà en cours, réessaie.' end

    local before = g.finance[account]
    if before < amount then
        Finances.unlock(g.id)
        return false, ('Solde insuffisant : %s disponibles.'):format(U.money(before))
    end
    if not Finances.debit(g, account, amount) then
        Finances.unlock(g.id)
        return false, 'Solde insuffisant.'
    end
    if not Players.addMoney(actor.src, account, amount, 'illegal-withdraw') then
        Finances.credit(g, account, amount)   -- le joueur n'a rien reçu : on remet l'argent au groupe
        Finances.unlock(g.id)
        return false, 'Tu ne peux pas recevoir cet argent (inventaire plein ?). Retrait annulé.'
    end
    record(g, actor, account, 'withdraw', -amount, before)
    Finances.unlock(g.id)

    Log(actor, g.id, 'Retrait', ('%s a retiré %s d\'%s de %s (%s → %s)'):format(actor.name, U.money(amount), Illegal.Accounts[account]:lower(),
        g.label, U.money(before), U.money(g.finance[account])))
    Sync.group(g.id)
    return true, ('%s retirés.'):format(U.money(amount))
end

-- ---------------------------------------------------------
--  Staff : ajout / retrait direct (sans argent du joueur)
-- ---------------------------------------------------------
function Finances.adminAdjust(actor, g, account, amount, add, reason)
    if not validAccount(account) then return false, 'Compte invalide.' end
    amount = U.amount(amount)
    if not amount then return false, 'Montant invalide.' end
    reason = U.text(reason, 200, true)
    if not Finances.lock(g.id) then return false, 'Une opération est déjà en cours, réessaie.' end
    local before = g.finance[account]
    local ok = add and Finances.credit(g, account, amount) or (not add and Finances.debit(g, account, amount))
    if not ok then
        Finances.unlock(g.id)
        return false, add and 'Erreur de la base de données.' or ('Solde insuffisant : %s disponibles.'):format(U.money(before))
    end
    record(g, actor, account, add and 'admin_add' or 'admin_remove', add and amount or -amount, before, reason)
    Finances.unlock(g.id)

    Log(actor, g.id, add and 'Ajout d\'argent (staff)' or 'Retrait d\'argent (staff)', ('%s %s %s d\'%s %s %s (%s → %s)%s'):format(
        actor.name, add and 'a ajouté' or 'a retiré', U.money(amount), Illegal.Accounts[account]:lower(), add and 'à' or 'de', g.label,
        U.money(before), U.money(g.finance[account]), reason ~= '' and (' · ' .. reason) or ''))
    Sync.group(g.id)
    return true, ('%s %s.'):format(U.money(amount), add and 'ajoutés' or 'retirés')
end

-- Paiement d'une commande validée (débit sous verrou + historique)
function Finances.payOrder(actor, g, account, amount, label)
    if not validAccount(account) then return false, 'Compte invalide.' end
    if not Finances.lock(g.id) then return false, 'Une opération est déjà en cours, réessaie.' end
    local before = g.finance[account]
    if amount > 0 and not Finances.debit(g, account, amount) then
        Finances.unlock(g.id)
        return false, ('Solde insuffisant en %s : %s disponibles.'):format(Illegal.Accounts[account]:lower(), U.money(before))
    end
    if amount > 0 then record(g, actor, account, 'order', -amount, before, label) end
    Finances.unlock(g.id)
    return true
end

-- Remboursement (validation de commande annulée après paiement)
function Finances.refundOrder(actor, g, account, amount, label)
    if amount <= 0 then return end
    local before = g.finance[account]
    if Finances.credit(g, account, amount) then record(g, actor, account, 'order', amount, before, 'Remboursement : ' .. tostring(label)) end
end

-- Historique paginé (onglet Finances, bouton « Plus ancien »)
function Finances.history(g, beforeId)
    beforeId = U.int(beforeId, 1)
    if not beforeId then return Cache.transactions(g) end
    local out = {}
    for _, r in ipairs(DB.transactionsPage(g.id, beforeId, 50)) do
        out[#out + 1] = { id = r.id, account = r.account, type = r.type, amount = tonumber(r.amount), before = tonumber(r.balance_before),
            after = tonumber(r.balance_after), actor = r.actor, reason = r.reason, created = r.created }
    end
    return out
end
