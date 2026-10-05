-- =========================================================
--  Objets du MenuStaff Elyzea FA pour ox_inventory (Qbox)
--  Copie ces lignes dans : ox_inventory/data/items.lua
--  (à l'intérieur du grand "return { ... }", n'importe où)
--  Si un objet existe déjà chez toi (ex : lockpick), ne le recopie pas.
--  Les armes (WEAPON_PISTOL…) existent déjà dans ox_inventory.
-- =========================================================

    -- Drogues : matières premières (récoltes)
    ['weed_leaf']       = { label = 'Feuille de weed',        weight = 20,  stack = true, close = true },
    ['coca_leaf']       = { label = 'Feuille de coca',        weight = 20,  stack = true, close = true },
    ['magic_mushroom']  = { label = 'Champignon',             weight = 20,  stack = true, close = true },
    ['meth_chemicals']  = { label = 'Produits chimiques',     weight = 250, stack = true, close = true },

    -- Drogues : produits finis (ateliers)
    ['weed_pouch']      = { label = 'Pochon de weed',         weight = 50,  stack = true, close = true },
    ['cocaine']         = { label = 'Cocaïne',                weight = 50,  stack = true, close = true },
    ['meth']            = { label = 'Méthamphétamine',        weight = 50,  stack = true, close = true },
    ['dried_mushroom']  = { label = 'Champignons séchés',     weight = 30,  stack = true, close = true },

    -- Armes : matériaux (fouilles)
    ['metal_scrap']     = { label = 'Ferraille',              weight = 200, stack = true, close = true },
    ['gun_parts_light'] = { label = "Pièces d'armes légères", weight = 300, stack = true, close = true },
    ['gun_parts_medium']= { label = "Pièces d'armes moyennes",weight = 500, stack = true, close = true },
    ['gun_parts_heavy'] = { label = "Pièces d'armes lourdes", weight = 800, stack = true, close = true },

    -- Outils de fouille
    ['crowbar']         = { label = 'Pied-de-biche',          weight = 1500, stack = false, close = true },
    -- ['lockpick']     = { label = 'Crochet',                weight = 160,  stack = true,  close = true }, -- déjà présent dans ox_inventory
