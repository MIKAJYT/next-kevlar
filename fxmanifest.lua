fx_version 'cerulean'
game 'gta5'

author 'The Next Team | discord.nextextended.com. Forked by MikaJYT'
description 'An advanced kevlar plate system by Next Scripts and forked by MikaJYT to work with jaksam_inventory.'
version '1.0.2'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua'
}

client_scripts {
    'config/cl_functions.lua',
    'src/client.lua'
}

server_scripts {
    'config/sv_functions.lua',
    'src/server.lua'
}

dependency 'ox_inventory'
dependency 'jaksam_inventory'
