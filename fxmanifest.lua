fx_version 'cerulean'
game 'gta5'

shared_script 'shared/config.lua'

server_scripts {
    'server/*.lua'
}

client_scripts {
    'client/*.lua'
}

files ({
    "web/index.html",
    "web/script.js",
    "web/style.css",
})

ui_page 'index.html'