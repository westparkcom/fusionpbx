-- Queue Recipe Processor

-- The default music on hold stream
defaultmoh = "callswitch.westparkcom.com/WPC-Hold"


-- Need some json goodies
json = require "resources.functions.lunajson";
-- Load up the FreeSWITCH API for inline calls
api = freeswitch.API();

-- Event callbacks
con = freeswitch.EventConsumer()
con:bind ('CHANNEL_BRIDGE')
con:bind ('CHANNEL_HANGUP')
con:bind ('CHANNEL_DESTROY')
con:bind ('CHANNEL_EXECUTE_COMPLETE')
con:bind ('CUSTOM', "conference::maintenance")

-- Script stop flag. Gets set to true if we detect a bridge
scriptstop = false

-- load up itas acd api:
require 'itas/acd_api'
acd_init ( 'itas/' )


function currentepoch()
    return os.time(os.date("!*t"))
end

function timereached(epoch, seconds)
    if (currentepoch() - epoch) > seconds then
        return true
    else
        return false
    end
end

function contains(list, x)
    for _, v in pairs(list) do
        if v == x then return true end
    end
    return false
end

function icontains(list, x)
    for i, v in next, list do
        if i == x then return true end
    end
    return false
end

function uuidlog(level, text)
    freeswitch.consoleLog(level, callinfo["call_uuid"] .. ": " .. text)
    return
end

function saytext(data)
    local ttsvoice = data[1]
    local textstr = data[2]
    local wavtoplay = api:executeString('python streamtext voice=' .. ttsvoice .. '|text=' .. textstr)
    api:executeString("uuid_break " .. callinfo["call_uuid"] .. " all")
    api:executeString("uuid_broadcast " .. callinfo["call_uuid"] .. " " .. wavtoplay .. " both")
    waitforplayfinish(wavtoplay)
    return
end

function waitforplayfinish(datatocheck)
    freeswitch.consoleLog("INFO", "Waiting for audio `" .. datatocheck .. "` to finish playing...")
    -- let's check to see if the Application-Data Event Header has our value in it yet, up to 1 second, waiting for up to 1 second to start
    -- TODO FIXME - Add a timeout here to prevent getting stuck (say, 240 seconds?)
    local recfinished = false
    while not recfinished do
        local event = con:pop(1, 1000)
        if event then
            local evt_uuid = event:getHeader('Unique-ID')
            local bridged = getvar("bridge_uuid")
            if (
                ((event:getHeader('Event-Name') == 'CHANNEL_DESTROY') or
                (event:getHeader('Event-Name') == 'CHANNEL_BRIDGE') or
                ((event:getHeader('Event-Name') == 'CUSTOM') and (event:getHeader('Event-Subclass') == 'conference::maintenance') and (event:getHeader('Action') == 'add-member')) or
                (event:getHeader('Event-Name') == 'CHANNEL_HANGUP')) and (
                evt_uuid == callinfo["call_uuid"])) or bridged ~= nil then
                    -- This means the call went elsewhere, we're done here
                    uuidlog("INFO", "Channel disconnected, not looking for audio to finish playing.")
                    api:executeString("uuid_break " .. callinfo["call_uuid"] .. " all")
                    scriptstop = true
                return
            elseif event:getHeader('Event-Name') == 'CHANNEL_EXECUTE_COMPLETE' and evt_uuid == callinfo["call_uuid"] then
                if event:getHeader('Application-Data') == datatocheck then
                    recfinished = true
                end
            end
        end
    end
    uuidlog("INFO", "Audio `" .. datatocheck .. "` finished playing!")
    return
end

function acctprompt(phrase_type, acctcode)
    local Database = require "resources.functions.database";
    local Settings = require "resources.functions.lazy_settings";
    local domain_uuid = getvar("domain_uuid");
    local domain_name = getvar("domain_name");
    local dbh = Database.new('system');
    -- If we're not in emergency mode then send back a vestigial prompt
    if phrase_type == 'EMERG' then
        local settings = Settings.new(dbh, domain_name, domain_uuid);
        local emerg_mode = tonumber(settings:get('recordings', 'emergency_mode', 'numeric')) or 0;
            if emerg_mode == 0 then
                sql_noemerg = "SELECT phrase_uuid FROM v_phrases"
                           .. " WHERE domain_uuid='" .. domain_uuid .. "'"
                           .. " AND phrase_name='disabled-EMERG'";
                disabled_emerg = dbh:first_value(sql_noemerg);
                return disabled_emerg;
            else
                uuidlog('notice', 'Emergency mode ACTIVE!\n');
            end
    end
    local sql = "SELECT phrase_uuid FROM v_phrases"
             .. " WHERE domain_uuid='" .. domain_uuid .. "'"
             .. " AND phrase_name='" .. acctcode .. "-" .. phrase_type .. "'";
    local phrase_name = dbh:first_value(sql);
    if phrase_name then
        return phrase_name;
    else
        local default_sql = "SELECT phrase_uuid FROM v_phrases"
                         .. " WHERE domain_uuid='" .. domain_uuid .. "'"
                         .. " AND phrase_name='default-" .. phrase_type .. "'";
        local default_phrase = dbh:first_value(default_sql);
        if phrase_type == 'NOANSWER' then 
            uuidlog("notice", phrase_type .. " phrase not found for account " .. acctcode .. ", returning default phrase\n");
            return default_phrase;
        else
            return 'nophrase'
        end
    end
end

function playpreanswer(value)
    -- Plays the preanswer greeting
    api:executeString("uuid_break " .. callinfo["call_uuid"] .. " all")
    local phraseuuid = acctprompt("NOANSWER", callinfo["accountcode"])
    api:executeString("uuid_broadcast " .. callinfo["call_uuid"] .. " phrase::" .. phraseuuid .. " both")
    waitforplayfinish(phraseuuid)
    return
end

function playemerg(value)
    -- If system emergency mode is set, play emergency greeting
    api:executeString("uuid_break " .. callinfo["call_uuid"] .. " all")
    local phraseuuid = acctprompt("EMERG", callinfo["accountcode"])
    api:executeString("uuid_broadcast " .. callinfo["call_uuid"] .. " phrase::" .. phraseuuid .. " both")
    waitforplayfinish(phraseuuid)
    return
end

function playprequeue(value)
    -- If system emergency mode is set, play emergency greeting
    api:executeString("uuid_break " .. callinfo["call_uuid"] .. " all")
    local phraseuuid = acctprompt("PREQUEUE", callinfo["accountcode"])
    api:executeString("uuid_broadcast " .. callinfo["call_uuid"] .. " phrase::" .. phraseuuid .. " both")
    waitforplayfinish(phraseuuid)
    return
end

function playesthold(value)
    -- Play estimated hold time in English or Spanish
    -- Get current time, to get more accurate estimated hold
    local enUSprompts = {
        ltthirty = "Your estimated hold time is less than 30 seconds.",
        ltone = "Your estimated hold time is less than a minute.",
        onemin = "Your estimated hold time is about 1 minute.",
        oneormore = "Your estimated hold tim is about XminX minutes."
    }
    local esMXprompts = {
        ltthirty = "Su tiempo de espera estimado es de 30 segundos.",
        ltone = "Su tiempo de espera estimado es menos de un minuto.",
        onemin = "Su tiempo de espera estimado es de aproximadamente un minuto.",
        oneormore = "Su tiempo de espera estimado es de aproximadamente XminX minutos."
    }
    local currtime = currentepoch()
    local lang = value[1]
    local gate = tonumber(value[2])
    local recordcount = tonumber(value[3])
    local retval = acd_gate_estwait(gate, recordcount)
    if retval:sub(1, 3) == "+OK" then
    else
        uuidlog("ERR", "Unable to retrieve hold time: " .. retval)
        return
    end
    local rethold = tonumber(retval:sub(4, -1))
    local esthold = (starttime - currtime) + rethold
    local prompts = {}
    local voice = ""
    local finalprompt = ""
    if lang == "en-US" then
        prompts = enUSprompts
        voice = "Joanna"
    else
        prompts = esMXprompts
        voice = "Mia"
    end
    if esthold <= 30 then
        finalprompt = prompts['ltthirty']
    elseif esthold > 30 and esthold <= 60 then
        finalprompt = prompts['ltone']
    elseif esthold > 60 and esthold <= 120 then
        finalprompt = prompts['onemin']
    else
        holdfloor = tostring(math.floor(esthold/60))
        finalprompt = prompts['oneormore']:gsub("XminX", holdfloor)
    end
    uuidlog("INFO", "Estimated Hold: `" .. tostring(esthold) .. "` seconds")
    api:executeString("uuid_break " .. callinfo["call_uuid"] .. " all")
    saytext({voice, finalprompt})
    --uuidlog("INFO", "Lang: `" .. lang .. "` finalprompt: `" .. finalprompt .. "`")
    --uuidlog("INFO", "Est Hold Returned: `" .. tostring(rethold) .. "` `" .. retval .. "`, Est Hold Calced: `" .. tostring(esthold) .. "` starttime: `" .. tostring(starttime) .. "` currtime: `" .. currtime .. "`")
    return
end

function setwhisper(value)
    -- Sets the whisper phrase for the account
    uuid_setvar(callinfo["call_uuid"], "acd_whisper", "phrase::" ..  acctprompt("WHISPER", callinfo["accountcode"]))
    return
end

function setdidoverride(dnisdata)
    -- Sets the queue-based DID override information
    -- TODO FIXME: dnisoverride format: gate,dnis,gate,dnis???
    dnisoverride = dnisdata[1]
    uuid_setvar(callinfo["call_uuid"], 'acd_did_override', dnisoverride)
    return
end

function newgatecall(gatedata)
    -- Puts call into queue
    -- Set a universal start time, used for estimating hold
    starttime = currentepoch()
    local caller_destination = getvar("caller_destination")
    local gatelist = gatedata[1]
    local priority = gatedata[2]
    local timeadvance = gatedata[3] or "0"
    local apistring = "lua itas/acd.lua call add " .. callinfo["call_uuid"] .. " " .. caller_destination .. " " .. gatelist .. " " .. priority .. " " .. tostring(timeadvance)
    uuidlog("INFO", "Executing `" .. apistring)
    api:executeString(apistring)
    return
end

function addgate(gatedata)
    -- Adds call to an additional gate
    local gate = gatedata[1]
    local priority = gatedata[2]
    acd_call_gate(callinfo["call_uuid"], tonumber(gate), tonumber(priority))
    return
end

function delgate(gatedata)
    -- Removes call from a gate
    gate = gatedata[1]
    acd_call_ungate(callinfo["call_uuid"], gate)
    return
end

function delgatecall(value)
    -- Removes call from queue entirely
    acd_call_del (callinfo["call_uuid"])
end

function setmoh(streamdata)
    -- Sets the music on hold stream name
    streamname = streamdata[1]
    uuid_setvar(callinfo["call_uuid"], "hold_music", "local_stream://" .. streamname)
    return
end

function playmoh(mohdata)
    -- Plays Music on Hold
    local seconds = tonumber(mohdata[1]) or 0
    local tonestring = getvar("hold_music")
    local broadcast = "uuid_broadcast " .. callinfo["call_uuid"] .. " " .. tonestring .. " both"
    api:executeString(broadcast)
    local currepoch = currentepoch()
    local mohfinished = false
    while not mohfinished do
        if (seconds > 0 and timereached(currepoch, seconds)) then
            mohfinished = true
            return
        end
        local event = con:pop(1, 1000)
        if event then
            local evt_uuid = event:getHeader('Unique-ID')
            local bridged = getvar("bridge_uuid")
            if (
                ((event:getHeader('Event-Name') == 'CHANNEL_DESTROY') or 
                (event:getHeader('Event-Name') == 'CHANNEL_BRIDGE') or 
                ((event:getHeader('Event-Name') == 'CUSTOM') and (event:getHeader('Event-Subclass') == 'conference::maintenance') and (event:getHeader('Action') == 'add-member')) or
                (event:getHeader('Event-Name') == 'CHANNEL_HANGUP')) and (
                evt_uuid == callinfo["call_uuid"])) or bridged ~= nil then
                    mofinished = true
                    scriptstop = true
                    api:executeString("uuid_break " .. callinfo["call_uuid"] .. " all")
                    return
            end
        end
    end
    return
end

function playring(ringdata)
    -- Playback ringtone for N number of repeats
    local repeated = tonumber(ringdata[1])
    api:executeString("uuid_break " .. callinfo["call_uuid"] .. " all")
    local tonestring = "tone_stream://%(2000,4000,440,480);loops=" .. tostring(repeated)
    api:executeString("uuid_broadcast " .. callinfo["call_uuid"] .. " " .. tonestring .. " both")
    waitforplayfinish(tonestring)
    return
end

function playtone(tonedata)
    -- Play a tone string to the caller. Refer to https://freeswitch.org/confluence/display/FREESWITCH/Tone_stream for info
    api:executeString("uuid_break " .. callinfo["call_uuid"] .. " all")
    local tonestring = "tone_stream://" .. tonedata[1]
    api:executeString("uuid_broadcast " .. callinfo["call_uuid"] .. " " .. tonestring)
    waitforplayfinish(tonestring)
    return
end

function preanswer(value)
    -- Early media answer of the call
    api:executeString("uuid_preanswer " .. callinfo["call_uuid"])
    return
end

function answer(value)
    -- Full answer of the call
    api:executeString("uuid_answer " .. callinfo["call_uuid"])
    return
end

function runlua(luadata)
    local command = luadata[1]
    api:executeString("lua " .. command)
    return
end

function runpython(pydata)
    -- Run a python command
    local command = pydata[1]
    api:executeString("python " .. command)
    return
end

function senddtmf(digitdata)
    -- Send a DTMF string to the calling party
    local digitstring = digitdata[1]
    api:executeString("uuid_send_dtmf " .. callinfo["call_uuid"] .. " " .. digitstring)
end

function changednis(dnisdata)
    -- Change the DNIS for the call
    local dnis = dnisdata[1]
    acd_call_did(callinfo['call_uuid'], dnis)
end

function changeani(anidata)
    -- Change the ANI for the call
    local ani = anidata[1]
    acd_call_ani(callinfo['call_uuid'], ani)
end

function hangup(hangupdata)
    -- Hangup the call
    local hangupcause = hangupdata[1]
    if hanupcause ~= nil then
        api:executeString("uuid_kill " .. callinfo["call_uuid"] .. " " .. hangupcause)
    else
        api:executeString("uuid_kill " .. callinfo["call_uuid"])
    end
    return
end

function compare_op ( lhs, op, rhs )
    if     op == ">" then  return lhs > rhs
    elseif op == "<" then  return lhs < rhs
    elseif op == ">=" then return lhs >= rhs
    elseif op == "<=" then return lhs <= rhs
    elseif op == "!=" then return lhs ~= rhs
    elseif op == "==" then return lhs == rhs
    end
    error ( 'invalid op `' .. tostring ( op ) .. '`' )
end

function checkif(checkifdata, execcmdiftrue, execcmdiffalse, execvaliftrue, execvaliffalse)
    -- Logical checking to determine what to do for various conditions
    local vartocheck = checkifdata[1]
    local operand = checkifdata[2]
    local valtocheck = checkifdata[3]
    local exec_if_true = {
          command = execcmdiftrue,
          value = execvaliftrue
    }
    local exec_if_false = {
          command = execcmdiffalse,
          value = execvaliffalse
    }


    -- acceptable vartocheck gate-manned, gate-avail, num-calls, time-waiting, ${channel_var}
    local acceptablecond = {}
    acceptablecond["gate-manned"] = {"^%d+$"}
    acceptablecond["gate-avail"] = {"^%d+$"}
    acceptablecond["num-calls-dnis"] = {"^%d+$"}
    acceptablecond["num-calls-ani"] = {"^%d+$"}
    acceptablecond["time-waiting"] = {"^%d+$"}

    -- acceptable numeric operands: ==, >=, >, <=, <, !=
    local numop = {
        "==", 
        "!=", 
        ">=", 
        "<=", 
        "<", 
        ">"
    }
    -- acceptable string/boolean operands: ==, !=
    local stringop = {
        "==",
        "!="
    }

    -- validate the vartocheck
    local varname = nil
    -- if true then we're checking a channel variable
    if string.find(vartocheck, "%${.+}") then
        varname = string.match(vartocheck, "%${(.+)}")
        uuidlog("INFO", "Checking variable `" .. varname .."` " .. operand .. " `" .. valtocheck .. "`")
    elseif not contains(acceptablecond, vartocheck) then
        uuidlog("INFO", "Checking condition `" .. vartocheck .. "` " .. operand .. " `" .. valtocheck .. "`")
    else
        -- If we get here then it's an invalid command
        uuidlog("ERR", "Invalid condition `" .. vartocheck .. "` received!!!")
        return false
    end

    -- validate the operand
    if tonumber(valtocheck) ~= nil then --we're dealing with a number here
        if not contains(numop, operand) then
            uuidlog("ERR", "Operand `" .. operand .. "` invalid for numeric data type")
            return false
        end
        if varname ~= nil then
            varval = getvar(varname)
            if tonumber(varval) then
                varval = tonumber(varval)
            end
        end
    else
        if not contains(stringop, operand) then
            uuidlog("ERR", "Operand `" .. operand .. "` invalid for string/boolean data type")
            return false
        end
    end

    -- validate the value
    local validval = false
    if contains(acceptablecond, valtocheck) then
        for k, v in next, acceptablecond[valtocheck] do
            if string.match(vartocheck, v) then
                validval = true
            end
        end
        if not validval then
            local tableout = ""
            for k, v in pairs(acceptablecond[valtocheck]) do
                tableout = tableout .. "`" .. v .. "`,"
            end
            uuidlog("ERR", "Value `" .. vartocheck .. "` for condition `" .. valtocheck .. "` does not match acceptable pattern " .. tableout)
            return false
        end
    end
    uuidlog("INFO", "vartocheck: `" .. vartocheck .. "` valtocheck: `" .. valtocheck .. "`")
    uuidlog("INFO", "exec_if_true: `" .. exec_if_true["command"] .. "`")
    uuidlog("INFO", "exec_if_false: `" .. exec_if_false["command"] .. "`")
    -- Now that all checks are complete, analyze the condition
    if vartocheck == "gate-manned" then
        local manneddata = acd_gate_agents ( tonumber(valtocheck), false ) -- example: "+OK 42"
        local ismanned = false
        if manneddata:sub(1, 3) == "+OK" then
            local manned_amt = tonumber(manneddata:sub(5, -1)) or 0
            if manned_amt ~= 0 then
                ismanned = true
            end
        end
        if ismanned then
            uuidlog("INFO", "Gate `" .. valtocheck .. "` IS manned!")
            -- If for some reason we want the opposite we'll allow it...
            if operand == "==" then
                exec_command(exec_if_true["command"], exec_if_true["value"])
            else
                exec_command(exec_if_false["command"], exec_if_false["value"])
            end
            return
        else
            uuidlog("INFO", "Gate `" .. valtocheck .. "` IS NOT manned!")
            if operand == "==" then
                exec_command(exec_if_false["command"], exec_if_false["value"])
            else
                exec_command(exec_if_true["command"], exec_if_true["value"])
            end
            return
        end
    elseif vartocheck == "gate-avail" then
        local agentsready = acd_gate_agents ( tonumber(valtocheck), true ) -- example: "+OK 42"
        local isavail = false
        if agentsready:sub(1, 3) == "+OK" then
            local ready_amt = tonumber(agentsready:sub(5, -1)) or 0
            if ready_amt ~= 0 then
                isavail = true
            end
        end
        if isavail then
            uuidlog("INFO", "Gate `" .. valtocheck .. "` HAS available agent(s)!")
            -- If for some reason we want the opposite we'll allow it...
            if operand == "==" then
                exec_command(exec_if_true["command"], exec_if_true["value"])
            else
                exec_command(exec_if_false["command"], exec_if_false["value"])
            end
            return
        else
            uuidlog("INFO", "Gate `" .. valtocheck .. "` DOES NOT HAVE available agent(s)!")
            if operand == "==" then
                exec_command(exec_if_true["command"], exec_if_true["value"])
            else
                exec_command(exec_if_false["command"], exec_if_false["value"])
            end
            return
        end
    elseif vartocheck == "num-calls-dnis" or vartocheck == "num-calls-ani" then
        local limitval = ""
        local limittype = ""
        if vartocheck == "num-calls-dnis" then
            limittype = "dnis"
            limitval = callinfo["dnis"]
        else
            limittype = "ani"
            limitval = callinfo["ani"]
        end
        local curcalls = tonumber(api:executeString("limit_usage hash queuecall-" .. limittype .. " " .. limitval))
        valtocheck = tonumber(valtocheck)
        local matches = compare_op(curcalls, operand, tonumber(valtocheck))
        if matches then
            uuidlog("INFO", limittype .. " limit `" .. limitval .. "`: `" .. curcalls .. "` " .. operand .. " `" .. valtocheck .. "` (threshold exceeded)" )
            exec_command(exec_if_true["command"], exec_if_true["value"])
            return
        else
            uuidlog("INFO", limittype .. " limit `" .. limitval .. "`: `" .. curcalls .. "` " .. operand .. " `" .. valtocheck .. "` (threshold OK)" )
            exec_command(exec_if_false["command"], exec_if_false["value"])
            return
        end
    elseif vartocheck == "time-waiting" then
        local acd_when_created = getvar ( 'acd_when_created' ) -- TODO FIXME: this might need to be variable_acd_when_created
        local timewaiting_seconds = 0 -- default if unknown
        if acd_when_created ~= nil then
            timewaiting_seconds = epoch_from_timestamp ( acd_now() ) - epoch_from_timestamp ( acd_when_created )
        end
        local matches = compare_op(tonumber(timewaiting_seconds), operand, tonumber(valtocheck))
        if matches then
            uuidlog("WARN", "time waiting: `" .. timewaiting .. "` " .. operand .. " `" .. valtocheck .. "` (threshold exceeded)" )
            exec_command(exec_if_true["command"], exec_if_true["value"])
            return
        else
            uuidlog("INFO", "time waiting: `" .. timewaiting .. "` " .. operand .. " `" .. valtocheck .. "` (threshold OK)" )
            exec_command(exec_if_false["command"], exec_if_false["value"])
            return
        end
    else
        -- we're doing a variable comparison if we've arrived here
        fsvar = getvar(varname) or ""
        local matches = compare_op(fsvar, operand, valtocheck)
        if matches then
            uuidlog("INFO", "variable `" .. varname .. "`: `" .. valtocheck ..  "` " .. operand .. " `" .. fsvar .. "` MATCHED" )
            exec_command(exec_if_true["command"], exec_if_true["value"])
            return
        else
            uuidlog("WARN", "variable `" .. varname .. "`: `" .. valtocheck ..  "` " .. operand .. " `" .. fsvar .. "` NOT MATCHED" )
            exec_command(exec_if_false["command"], exec_if_false["value"])
            return
        end
    end
    -- if all else fails...
    exec_command(exec_if_false["command"], exec_if_false["value"])
    return
end

function transfer(destdata)
    -- Transfer to FreeSWITCH destination
    local destination = destdata[1]
    sesssion:execute("transfer", destination)
    return
end

function gotoseq(seqdata)
    -- Given a sequence number, continue execution at that sequence number
    local seqnum = seqdata[1]
    local valid_seqnum = false
    for k, v in ipairs(callinfo["callrecipe"]) do
        if tonumber(seqnum) == tonumber(v["seqnum"]) then
            valid_seqnum = true
            break
        end
    end
    if valid_seqnum == true then
        -- We set the previous sequence number so the next step gets the sequence number we want
        globalseqnum = get_prev_seqnum(seqnum)
    else
        uuidlog("ERR", "Invalid gotoseq sequence number `" .. seqnum .. "`!")
    end
end

function sleep(sleepdata)
    -- Sleep for N seconds
    local currepoch = currentepoch()
    local finished = false
    while not finished do
        if (seconds > 0 and timereached(currepoch, seconds)) then
            mohfinished = true
            return
        end
        local event = con:pop(1, 1000)
        if event then
            local evt_uuid = event:getHeader('Unique-ID')
            if ((event:getHeader('Event-Name') == 'CHANNEL_DESTROY') or (event:getHeader('Event-Name') == 'CHANNEL_BRIDGE') or (event:getHeader('Event-Name') == 'CHANNEL_HANGUP')) and (evt_uuid == callinfo["call_uuid"]) then
                mofinished = true
                return
            end
        end
    end
    return
end

function nullfunc(value)
    -- Don't do anything (useful as a placeholder for checkif)
    return
end

function get_call_data(pilotnumber)
    -- Check to see if the pilot exists
    local defaultroute = '[{"seqnum":10,"command":"answer"},{"seqnum":20,"command":"newgatecall","value":["1","1","0"]},{"seqnum":30,"command":"playpreanswer"},{"seqnum":40,"command":"playmoh","value":["0"]}]'
    local Database = require "resources.functions.database";
    dbh = Database.new('system');
    
    local sql = "SELECT * FROM v_ibr_pilots WHERE domain_uuid=:domain_uuid AND ibr_pilot=:ibr_pilot LIMIT 1"
    local pilotdata = nil
    params = {
        domain_uuid = getvar("domain_uuid"),
        ibr_pilot = pilotnumber
    }
    dbh:query(sql, params, function(row)
        pilotdata = row.ibr_pilot_json
    end);
    if pilotdata == nil then
        uuidlog("ERR", "IBR for pilot `" .. pilotnumber .. "` not found! Returning failsafe instructions!!!")
        return json.decode(defaultroute)
    else
        local validjson, retcode = pcall(json.decode, pilotdata)
        if validjson then
            return json.decode(pilotdata)
        else
            uuidlog("ERR", "IBR for pilot `" .. pilotnumber .. "` contains invalid JSON! Returning failsafe instructions!!!")
            return json.decode(defaultroute)
        end
    end
    --[[local ibrfile = ibrpilotdir .. pilotnumber .. ".json"
    local file = require "resources.functions.file"
    if not file.exists(ibrfile) then
        uuidlog("ERR", "Unable to open file `" .. ibrfile .. "` for reading, terminating call!!!")
        return json.decode('[{"seqnum":10,"command":"hangup"}]')
    end
    local fdata = json.decode(file.read(ibrfile))
    return fdata]]
end

function get_next_seqnum(seqnum)
    -- Given a sequence number, find the next sequence number in the list
    local tmparr = {}
    for k, v in ipairs(callinfo["callrecipe"]) do
        tmparr[#tmparr+1] = tonumber(v["seqnum"])
    end
    -- Arrange the sequence numbers in numeric order
    table.sort(tmparr)
    for _, v in pairs(tmparr) do
        if tonumber(seqnum) < v then
            return v
        end
    end
    return tmparr[#tmparr] -- if we're at the last entry return the last entry again
end

function get_prev_seqnum(seqnum)
    -- Given a sequence number, find the previous sequence number in the list
    local tmparr = {}
    for k, v in ipairs(callinfo["callrecipe"]) do
        tmparr[#tmparr+1] = tonumber(v["seqnum"])
    end
    -- Arrange the sequence numbers in numeric order, reversed
    table.sort(tmparr, function(a, b) return a > b end)
    for _, v in pairs(tmparr) do
        if tonumber(seqnum) > v then
            return v
        end
    end
    return tmparr[#tmparr] -- if we're at the last entry return the last entry again
end

function get_first_seqnum()
    -- Get the lowest sequence number
    local tmparr = {}
    for k, v in ipairs(callinfo["callrecipe"]) do
        tmparr[#tmparr+1] = tonumber(v["seqnum"])
    end
    -- Arrange the sequence numbers in numeric order
    table.sort(tmparr)
    -- return the first seqnum
    return tmparr[1]
end

function seqnum_arrpos(seqnum)
    -- Get the array position for the requested sequence number
    for k, v in ipairs(callinfo["callrecipe"]) do
        if tonumber(v["seqnum"]) == tonumber(seqnum) then
            return k
        end
    end
end

function exec_command(funcname, value)
    local validcommands = {
        "playpreanswer",
        "playemerg",
        "setwhisper",
        "setdidoverride",
        "newgatecall",
        "addgate",
        "delgate",
        "delgatecall",
        "setmoh",
        "playmoh",
        "playring",
        "playtone",
        "playesthold",
        "preanswer",
        "answer",
        "runlua",
        "senddtmf",
        "hangup",
        "runpython",
        "changednis",
        "changeani",
        "gotoseq",
        "sleep",
        "checkif",
        "transfer",
        "nullfunc",
        "playprequeue",
        "saytext"
    }
    if not contains(validcommands, funcname) then
        uuidlog("ERR", "Invalid command received: `" .. funcname .. "`")
    else
        uuidlog("INFO", "Calling function `" .. funcname .. "` with data:`" .. json.encode(value) .. "`")
        -- Lua magic to call a function name from a string
        _G[funcname](value)
    end
    return
end

function exec_command_init(funcname, value, execcmdiftrue, execcmdiffalse, execvaliftrue, execvaliffalse)
    local validcommands = {
        "playpreanswer",
        "playemerg",
        "setwhisper",
        "setdidoverride",
        "newgatecall",
        "addgate",
        "delgate",
        "delgatecall",
        "setmoh",
        "playmoh",
        "playring",
        "playtone",
        "playesthold",
        "preanswer",
        "answer",
        "runlua",
        "senddtmf",
        "hangup",
        "runpython",
        "changednis",
        "changeani",
        "gotoseq",
        "sleep",
        "checkif",
        "transfer",
        "nullfunc",
        "playprequeue",
        "saytext"
    }
    if not contains(validcommands, funcname) then
        uuidlog("ERR", "Invalid command received: `" .. funcname .. "`")
    else
        if funcname ~= "checkif" then
            uuidlog("INFO", "Calling function `" .. funcname .. "` with data:`" .. json.encode(value) .. "`")
            -- Lua magic to call a function name from a string
            _G[funcname](value)
        else
            uuidlog("INFO", "Calling function `" .. funcname .. "` with data:`" .. json.encode(value) .. "` iftrue: `" ..  execcmdiftrue .. "`:`" .. json.encode(execvaliftrue) .. "` iffalse: `" .. execcmdiffalse .. "`:`" .. json.encode(execvaliffalse) .. "`")
            -- Lua magic to call a function name from a string
            _G[funcname](value, execcmdiftrue, execcmdiffalse, execvaliftrue, execvaliffalse)
        end 
    end
    return
end

function getvar(varname)
    vardata = api:executeString("uuid_getvar " .. callinfo["call_uuid"] .. " " .. varname)
    if vardata:sub(1, 4) ~= "-ERR" then
        if vardata == "_undef_" then
            if varname ~= "bridge_uuid" then
                uuidlog("WARN", "UUID `" .. callinfo["call_uuid"] .. "` var `" .. varname .. "` doesn't exist!")
            end
            return nil
        else
            return vardata
        end
    else
        uuidlog("ERR", " no longer active channel!")
        return nil
    end
end

function run_call()
    -- Get the UUID 
    if argv[2] == nil then
        uuidlog("ERR", "No UUID specified. IBR system requires UUID!")
        return
    end
    -- Get call information
    callinfo = {}
    callinfo["call_uuid"] = argv[2]
    freeswitch.consoleLog("INFO", "UUID is `" .. callinfo["call_uuid"] .. "`")
    callinfo["ani"] = getvar("caller_id_number")
    callinfo["dnis"] = getvar("caller_destination")
    callinfo["pilotnumber"] = getvar("pilotnumber")
    if callinfo["pilotnumber"] == nil or callinfo["pilotnumber"] == "" then
        uuidlog("ERR", "No IBR pilot specified! IBR system requires an IBR to execute!")
        return
    end
    callinfo["accountcode"] = getvar("accountcode")
    callinfo["callrecipe"] = get_call_data(callinfo["pilotnumber"])
    -- Set the default MoH
    uuid_setvar(callinfo["call_uuid"], "hold_music", "local_stream://" .. defaultmoh)
    -- Set active call counter counter for ANI and DNIS
    api:executeString("uuid_limit " .. callinfo["call_uuid"] .. " hash queuecall-ani " .. callinfo["ani"] .. " -1")
    api:executeString("uuid_limit " .. callinfo["call_uuid"] .. " hash queuecall-dnis " .. callinfo["dnis"] .. " -1")
    currentstep = seqnum_arrpos(get_first_seqnum()) -- this is the position in the call recipe we are currently executing, starting at 1st sequence number
    local alive = getvar("call_uuid")
    while alive ~= nil do
        globalseqnum = callinfo["callrecipe"][currentstep]["seqnum"]
        local command = callinfo["callrecipe"][currentstep]["command"]
        local value = callinfo["callrecipe"][currentstep]["value"] or {}
        local execcmdiftrue = callinfo["callrecipe"][currentstep]["execcmdiftrue"] or "nullfunc"
        local execcmdiffalse = callinfo["callrecipe"][currentstep]["execcmdiffalse"] or "nullfunc"
        local execvaliftrue = callinfo["callrecipe"][currentstep]["execvalueiftrue"] or {}
        local execvaliffalse = callinfo["callrecipe"][currentstep]["execvalueiffalse"] or {}
        exec_command_init(command, value, execcmdiftrue, execcmdiffalse, execvaliftrue, execvaliffalse)
        -- Get the next step
        currentstep = seqnum_arrpos(get_next_seqnum(globalseqnum))
        -- Check if the call is dead or if it's been bridged, end if so
        alive = getvar("call_uuid")
        local bridged = getvar("bridge_uuid")
        if scriptstop == true or bridged ~= nil then
            uuidlog("INFO", "Call bridged, stopping inbound route processing.")
            alive = nil
        end
    end
    uuidlog("INFO", "Inbound routing complete.")
    return
end


run_call()
