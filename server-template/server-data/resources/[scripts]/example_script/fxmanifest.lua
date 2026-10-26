fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Example script that depends on example_core'
version '1.0.0'

-- FXServer starts example_core first. If example_core restarts, static_backend
-- brings this resource back up automatically.
dependency 'example_core'

server_script 'server.lua'
client_script 'client.lua'
