fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Neon Scripts'
description 'Queue System'
version '1.0.3'

shared_scripts { 
	'config.lua'
}
server_scripts {
	'config.lua',
	'server/*.lua'
}

escrow_ignore {
	'config.lua',
	'server/sv_discord.lua'
}