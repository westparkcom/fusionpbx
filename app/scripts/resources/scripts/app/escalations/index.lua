Database = require "resources.functions.database";
dbh = Database.new('system');
api = freeswitch.API();
require "resources.functions.settings";
settings = settings(domain_uuid)
context = argv[6]
voicemail_message_uuid = argv[5]
voicemail_uuid = argv[4]
domain_name = argv[3]
domain_uuid = argv[2]

function getvmbox()
    local vmdata = {}
    local sql = "SELECT * FROM v_voicemails WHERE domain_uuid = :domain_uuid AND voicemail_uuid = :voicemail_uuid"
    local params = {
        domain_uuid = domain_uuid,
        voicemail_uuid = voicemail_uuid
    }
    dbh:query(sql, params, function(rows)
        vmdata['voicemail_id'] = rows['voicemail_id']
        vmdata['voicemail_password'] = rows['voicemail_password']
    end)
    return vmdata
end

function getmsginfo()
    local msgdata = {}
    local sql = "SELECT * FROM v_voicemail_messages WHERE domain_uuid = :domain_uuid AND voicemail_uuid = :voicemail_uuid AND voicemail_message_uuid = :voicemail_message_uuid"
    local params = {
        domain_uuid = domain_uuid,
        voicemail_uuid = voicemail_uuid,
        voicemail_message_uuid = voicemail_message_uuid
    }
    dbh:query(sql, params, function(rows)
        msgdata['created_epoch'] = rows['created_epoch']
        msgdata['message_status'] = rows['message_status']
    end)
    return msgdata
end

function getescinfo()
    local escdata = {}
    local sql = "SELECT * FROM v_voicemail_escalations WHERE domain_uuid = :domain_uuid AND voicemail_uuid = :voicemail_uuid ORDER BY voicemail_escalation_order"
    local params = {
        domain_uuid = domain_uuid,
        voicemail_uuid = voicemail_uuid,
        voicemail_message_uuid = voicemail_message_uuid
    }
    dbh:query(sql, params, function(row)
        table.insert(
            escdata,
            {
                voicemail_escalation_order = row['voicemail_escalation_order'],
                voicemail_escalation_phonenum = row['voicemail_escalation_phonenum'],
                voicemail_escalation_delay = row['voicemail_escalation_delay']

            }
        )
    end)
    return escdata
end

function originatecall(phonenum)
    local escalations_cidnum = '5553211234'
    if (settings['voicemail']['escalations_cidnum'] ~= nil) then
        escalations_cidnum = settings['voicemail']['escalations_cidnum']['text'];
    end
    origstring ="bgapi originate {return_ring_ready=true,direction=outbound,outbound_caller_id_number=" .. escalations_cidnum .. ",outbound_caller_id_number=" .. escalations_cidnum .. ",outbound_caller_id_name=" .. escalations_cidnum .. ",ignore_early_media=true,call_timeout=60,hangup_after_bridge=true,context=" .. context .. ",domain_name=" .. domain_name ..",domain_uuid=" .. domain_uuid .. "}loopback/" .. phonenum .. "/" .. context .. " '&lua(app.lua vmcallout " .. vmboxinfo['voicemail_id'] .. ")'"
    api:executeString(origstring)
end

function runesc()
    -- Get voicemail box info
    vmboxinfo = getvmbox()

    -- Get escalations info
    escinfo = getescinfo()
    for key, row in pairs(escinfo) do
        local voicemail_escalation_delay = 0
        if row['voicemail_escalation_delay'] then
            voicemail_escalation_delay = tonumber(row['voicemail_escalation_delay'])
        end
        freeswitch.consoleLog("INFO", "Sleeping for " .. tostring(voicemail_escalation_delay) .. " minutes")
        local totms = voicemail_escalation_delay * 60 * 1000
        freeswitch.msleep(totms)
        -- Get voicemail message info
        msginfo = getmsginfo()
        if next(msginfo) == nil then -- message was deleted, cancel callouts
            freeswitch.consoleLog("INFO", "Message callout escalation for mailbox " .. vmboxinfo['voicemail_id'] .. " cancelled, message was deleted.")
            return
        elseif msginfo['message_status'] == 'saved' then -- message was read, cancel callouts
            freeswitch.consoleLog("INFO", "Message callout escalation for mailbox " .. vmboxinfo['voicemail_id'] .. " cancelled, message was marked read.")
            return
        end
        freeswitch.consoleLog("INFO", "Originating callout to " .. row['voicemail_escalation_phonenum'] .. " for mailbox " .. vmboxinfo['voicemail_id'])
        originatecall(row['voicemail_escalation_phonenum'])
    end
end

runesc()
freeswitch.consoleLog("INFO", "VM Callouts finished for box " .. vmboxinfo['voicemail_id'] .. ".")