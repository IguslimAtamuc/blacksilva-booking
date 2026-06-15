fx_version 'cerulean'
game 'gta5'

description 'BlackSilva Missions System (ESX)'
version '1.0.0'
author 'BlackSilva'

lua54 'yes'

shared_script 'config.lua'

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}

dependency 'es_extended'
