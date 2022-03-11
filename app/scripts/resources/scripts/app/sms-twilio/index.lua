function split(s, sep)
    local fields = {}
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function send_msg(twiliosid, twilioapisid, twiliotoken, smsto, smsfrom, smsmsg)
    local json = require "resources.functions.lunajson"
    local send_sms_cmd = 'curl -X POST --data-urlencode "Body=' .. smsmsg .. '" --data-urlencode "From=' .. smsfrom .. '" --data-urlencode "To=+' .. smsto .. '" "https://api.twilio.com/2010-04-01/Accounts/' .. twiliosid .. '/Messages.json" -u "' .. twilioapisid .. ':' .. twiliotoken .. '"'
    local handle = io.popen(send_sms_cmd)
    local send_sms_result = handle:read("*a")
    handle:close();
    local sms_json = json.decode(send_sms_result);
    local sms_retcode = sms_json["status"] or 'sent';
    if sms_retcode == 'sent' or sms_retcode == 'queued' then
        freeswitch.consoleLog('info', 'Message sent! SID: ' .. sms_json["sid"])
		return true
    else
        freeswitch.consoleLog('err', "Unable to send voicemail SMS: " .. send_sms_result);
        return false
    end
end

Database = require "resources.functions.database";
dbh = Database.new('system');
require "resources.functions.settings";
require "resources.functions.base64";

local direction = argv[2] -- Seems this isn't used...
local to_uri = split(argv[3], "@")
local sms_to = to_uri[1]
local domain_name = to_uri[2]
local sms_from = argv[4]
local sms_body = argv[5]

local domain_uuid = ""
local sql = "SELECT domain_uuid FROM v_domains WHERE domain_name = :domain_name"
local params = {
    domain_name = domain_name
}
dbh:query(sql, params, function(rows)
    domain_uuid = rows["domain_uuid"]
end)

settings = settings(domain_uuid)
if (settings['voicemail']['sms_twilio_sid'] ~= nil) then
    sms_twilio_sid = settings['voicemail']['sms_twilio_sid']['text'];
else
    freeswitch.consoleLog("err", "No sms_twilio_sid set, aborting SMS send\n");
    return "exit";
end

if (settings['voicemail']['sms_twilio_api_sid'] ~= nil) then
    sms_twilio_api_sid = settings['voicemail']['sms_twilio_api_sid']['text'];
else
    freeswitch.consoleLog("err", "No sms_twilio_api_sid set, aborting SMS send\n");
    return "exit";
end

if (settings['voicemail']['sms_twilio_token'] ~= nil) then
    sms_twilio_token = settings['voicemail']['sms_twilio_token']['text'];
else
    freeswitch.consoleLog("err", "No sms_twilio_token set, aborting SMS send\n");
    return "exit";
end

send_msg(sms_twilio_sid, sms_twilio_api_sid, sms_twilio_token, sms_to, sms_from, sms_body)
