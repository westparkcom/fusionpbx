ttsvoice = 'Joanna'

api = freeswitch.API();
vmbox = argv[2]
introPrompt = "This is the Westpark Communications messaging system. There is a new voicemail in mailbox"

function saytext(textstr)
    return api:executeString('python streamtext voice=' .. ttsvoice .. '|text=' .. textstr);
end

introPromptWav = saytext(introPrompt)

session:setVariable("voicemail_id", vmbox)
session:setVariable("voicemail_action", "check")
session:setVariable("voicemail_profile", "default")


session:execute('wait_for_silence', '200 15 10 5000')
session:execute('playback', introPromptWav)
session:execute('sleep', '100')
for c in string.gmatch(vmbox, ".") do
    session:execute('playback', 'digits/' .. tostring(c) .. '.wav')
end
session:execute('sleep', '500')
session:execute('lua', 'app.lua voicemail')
