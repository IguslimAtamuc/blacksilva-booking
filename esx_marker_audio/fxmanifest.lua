fx_version 'cerulean'
game 'gta5'

author 'BlackSilva'
description 'ESX - Marker cu redare audio MP3 la intrarea in cerc'
version '1.0.0'

shared_script 'config.lua'

client_script 'client.lua'

-- Pagina NUI care reda fisierul MP3
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/audio/*.mp3'
}

dependency 'es_extended'
