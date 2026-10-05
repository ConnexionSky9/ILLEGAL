fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_illegal'
author 'Elyzea FA'
description 'Elyzea Illégal : gangs, organisations et cartels (grades, membres, argent propre / sale, PNJ, commandes, tablette F5). Administration dans admin_menu › ILLEGAL.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/constants.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/main.lua',
    'client/peds.lua',
    'client/f5.lua',
    'client/tablet.lua',
    'client/deliveries.lua',
    'client/stashes.lua',
    'client/missions/core.lua',
    'client/missions/colis.lua',
    'client/missions/fourgon.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/logs.lua',
    'server/players.lua',
    'server/cache.lua',
    'server/sync.lua',
    'server/groups.lua',
    'server/grades.lua',
    'server/members.lua',
    'server/finances.lua',
    'server/peds.lua',
    'server/orders.lua',
    'server/deliveries.lua',
    'server/stashes.lua',
    'server/missions/core.lua',
    'server/missions/colis.lua',
    'server/missions/fourgon.lua',
    'server/tablet.lua',
    'server/admin.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
}

dependencies { 'qbx_core', 'ox_lib', 'oxmysql' }
