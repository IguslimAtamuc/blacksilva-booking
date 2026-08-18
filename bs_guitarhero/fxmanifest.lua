fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'bs_guitarhero'
author      'BlackSilva'
description 'Rhythm Highway HUD - joc de ritm sincronizat cu melodia, pornit din emote-ul de chitara (ESX)'
version     '1.0.0'

shared_script 'config.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/game.js',
    'html/data/faint.json',
    'html/audio/faint.mp3',
}
