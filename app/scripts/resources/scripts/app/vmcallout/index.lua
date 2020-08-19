ttsvoice = 'Joanna'
Database = require "resources.functions.database";
dbh = Database.new('system');
require "resources.functions.settings";
settings = settings(domain_uuid);
company_name = ''
if (settings['voicemail']['company_name']['text'] ~= nil) then
    company_name = settings['voicemail']['company_name']['text']
end

api = freeswitch.API();
vmbox = argv[2]
introPrompt = "This is the " .. company_name .. " messaging system. There is a new voicemail for account"
middlePrompt = "Mailbox number"

function saytext(textstr)
    return api:executeString('python streamtext voice=' .. ttsvoice .. '|text=' .. textstr);
end

introPromptWav = saytext(introPrompt)
middlePromptWav = saytext(middlePrompt)

vmacct = vmbox:sub(2, 5)
if vmbox:len() > 5 then
    boxnum = tostring(tonumber(vmbox:sub(6, 7)))
else
    boxnum = '0'
end

session:setVariable("voicemail_id", vmbox)
session:setVariable("voicemail_action", "check")
session:setVariable("voicemail_profile", "default")


session:execute('wait_for_silence', '200 15 10 4000')
session:execute('playback', introPromptWav)
session:execute('sleep', '100')
for c in string.gmatch(vmacct, ".") do
    session:execute('playback', 'digits/' .. tostring(c) .. '.wav')
end
session:execute('sleep', '100')
session:execute('playback', middlePromptWav)
session:execute('sleep', '100')
i = 0
for c in string.gmatch(boxnum) do
    if boxnum:len() > 1 and i == 0 then
        session:execute('playback', 'digits/' .. tostring(c) .. '0.wav')
    else
        session:execute('playback', 'digits/' .. tostring(c) .. '.wav')
    end
    i = i + 1
end
session:execute('sleep', '500')
session:execute('lua', 'app.lua voicemail')
