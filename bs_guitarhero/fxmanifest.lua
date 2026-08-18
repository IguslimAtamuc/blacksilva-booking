fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'bs_guitarhero'
author      'BlackSilva'
description 'Rhythm Highway HUD - minijoc de ritm overlay, sincronizat pe melodie, pornit din /e guitar (ESX)'
version     '1.0.0'

shared_script 'config.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/css/fonts.css',
    'html/fonts/*.woff2',
    'html/js/game.js',
    'html/data/ichwill.json',
    'html/audio/ichwill.mp3',
    'html/data/pahare.json',
    'html/audio/pahare.mp3',
}
