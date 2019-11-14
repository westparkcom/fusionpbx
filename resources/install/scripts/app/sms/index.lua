function send_msg(thinqacct, thinqcreds, smsto, smsfrom, smsmsge)
    local smsmsg = string.gsub(smsmsge, "\n", "\\n")
    local json = require "resources.functions.lunajson"
    local send_sms_cmd = [[curl --location --request POST "https://api.thinq.com/account/]] .. thinqacct .. [[/product/origination/sms/send" --header "Authorization: Basic ]] .. thinqcreds .. [[" --header "Content-Type: application/json" --data "{\"from_did\":\"]] .. smsfrom .. [[\",\"to_did\":\"]] .. smsto .. [[\",\"message\":\"]] .. smsmsg .. [[\"}"]]
    local handle = io.popen(send_sms_cmd)
    local send_sms_result = handle:read("*a")
    handle:close();
    local sms_json = json.decode(send_sms_result);
    local sms_retcode = sms_json["code"] or 200;
    if sms_retcode ~= 200 then
        freeswitch.consoleLog('err', "Unable to send voicemail SMS: " .. send_sms_result);
        return false
    else
        return true
    end
end

Database = require "resources.functions.database";
dbh = Database.new('system');
require "resources.functions.settings";

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
if (settings['voicemail']['sms_thinq_acct'] ~= nil) then
    sms_thinq_acct = settings['voicemail']['sms_thinq_acct']['text'];
else
    freeswitch.consoleLog("err", "No sms_thinq_acct set, aborting SMS send\n");
    return "exit";
end

if (settings['voicemail']['sms_thinq_username'] ~= nil) then
    sms_thinq_username = settings['voicemail']['sms_thinq_username']['text'];
else
    freeswitch.consoleLog("err", "No sms_thinq_username set, aborting SMS send\n");
    return "exit";
end

if (settings['voicemail']['sms_thinq_token'] ~= nil) then
    sms_thinq_token = settings['voicemail']['sms_thinq_token']['text'];
else
    freeswitch.consoleLog("err", "No sms_thinq_token set, aborting SMS send\n");
    return "exit";
end
local cred_text = sms_thinq_username .. ":" .. sms_thinq_token;
local thinq_creds = base64.encode(cred_text);
send_msg(sms_thinq_acct, thinq_creds, sms_to, sms_from, sms_msg)
