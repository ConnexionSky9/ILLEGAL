-- Stockage simple en fichiers JSON dans /data (aucune base de données requise)
Storage = {}
local RES = GetCurrentResourceName()

function Storage.load(name, default)
    local raw = LoadResourceFile(RES, ('data/%s.json'):format(name))
    if not raw or raw == '' then return default end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    print(('^1[AdminMenu] Fichier data/%s.json illisible, valeurs par défaut utilisées.^7'):format(name))
    return default
end

function Storage.save(name, data)
    local ok = SaveResourceFile(RES, ('data/%s.json'):format(name), json.encode(data, { indent = true }), -1)
    if not ok then
        print(('^1[AdminMenu] Impossible d\'écrire data/%s.json (le dossier data existe-t-il ?)^7'):format(name))
    end
end

-- Sauvegarde différée : plusieurs modifications rapprochées (ex. poser
-- 30 plants à la suite) = une seule écriture disque.
local pending = {}
function Storage.saveLater(name, data, delay)
    if pending[name] then pending[name].data = data return end
    pending[name] = { data = data }
    SetTimeout(delay or 1500, function()
        local p = pending[name]
        pending[name] = nil
        if p then Storage.save(name, p.data) end
    end)
end

function Storage.flush()
    for name, p in pairs(pending) do Storage.save(name, p.data) end
    pending = {}
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Storage.flush() end
end)
