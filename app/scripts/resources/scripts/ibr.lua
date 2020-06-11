api = freeswitch.API();

if argv[1] == nil then
	freeswitch.consoleLog("ERR", "No UUID set for ibr.lua")
else
	uuid = argv[1]
	api:executeString("luarun app.lua ibr-pilots " .. uuid)
	session:execute("endless_playback", "silence_stream://-1")
end