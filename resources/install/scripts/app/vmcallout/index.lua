ttsvoice = 'Joanna'

api = freeswitch.API();
vmbox = argv[1]
introPrompt = "This is the Westpark Communications messaging system. There is a new voicemail in mailbox " .. vmbox .. "."

function saytext(textstr)
    return api:executeString('python streamtext voice=' .. ttsvoice .. '|text=' .. textstr);
end

introPromptWav = saytext(introPrompt)

session:setVariable("voicemail_id", vmbox)
session:setVariable("voicemail_action", "check")
session:setVariable("voicemail_profile", "default")


session:execute('playback', introPromptWav)
session:execute('sleep', '500')
session:execute('lua', 'app.lua voicemail')