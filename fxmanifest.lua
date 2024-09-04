fx_version 'bodacious'

game 'gta5'
lua54 'yes'

ui_page_preload "yes"

ui_page("html/index.html")

client_scripts {
    '@vrp/client/Proxy.lua',
    '@vrp/client/Tunnel.lua',
    'client/*.lua',
}

server_scripts {
    '@vrp/lib/utils.lua',
    'server/*.lua',
}

shared_scripts {
    'config.lua',
}


files({
    "html/**/*"
})
