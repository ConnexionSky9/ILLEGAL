fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'admin_menu'
author 'Elyzea FA'
description 'Menu administrateur complet (standalone) - noclip 3e personne, grades, permissions, sanctions, véhicules, météo'
version '1.10.0'

shared_script 'config.lua'

client_scripts {
    'client/main.lua',
    'client/noclip.lua',
    'client/spectate.lua',
    'client/vehicles.lua',
    'client/world.lua',
    'client/wallhack.lua',
    'client/editor.lua',
    'client/revive.lua',
    'client/zones.lua',
    'client/doors.lua',
    'client/jail.lua',
    'client/transform.lua',
    'client/gofast.lua',
    'client/zombies.lua',
    'client/quick.lua',
    'client/ems.lua',
    'client/police.lua',
    'client/uniforms.lua',
    'client/minimap.lua',
    'client/mapicons.lua',
    'client/garage.lua',
    'client/drops.lua',
}

server_scripts {
    'server/storage.lua',
    'server/main.lua',
    'server/bridge.lua',
    'server/editor.lua',
    'server/gofast.lua',
    'server/zombies.lua',
    'server/zombies_loot.lua',
    'server/messages.lua',
    'server/ems.lua',
    'server/police.lua',
    'server/jobtools.lua',
    'server/lscustom.lua',
    'server/concess.lua',
    'server/map.lua',
    'server/drops.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/catalog.js',
    'html/gofast.js',
    'html/zombies.js',
    'html/quick.js',
    'html/ems.js',
    'html/police.js',
    'html/jobtools.js',
    'html/lscustom.js',
    'html/concess.js',
    'html/map.js',
    'html/stashes.js',
    'html/drops.js',
    'html/logo.png',
}
