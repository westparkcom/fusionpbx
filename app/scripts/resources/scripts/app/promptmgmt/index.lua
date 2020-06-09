--
--	FusionPBX
--	Version: MPL 1.1
--
--	The contents of this file are subject to the Mozilla Public License Version
--	1.1 (the "License"); you may not use this file except in compliance with
--	the License. You may obtain a copy of the License at
--	http://www.mozilla.org/MPL/
--
--	Software distributed under the License is distributed on an "AS IS" basis,
--	WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
--	for the specific language governing rights and limitations under the
--	License.
--
--	The Original Code is FusionPBX
--
--	The Initial Developer of the Original Code is
--	Mark J Crane <markjcrane@fusionpbx.com>
--	Copyright (C) 2010
--	the Initial Developer. All Rights Reserved.
--
--	Contributor(s):
--	Mark J Crane <markjcrane@fusionpbx.com>
--	Josh Patten <jpatten@westparkcom.net>

-----------------PUT THIS STUFF IN DEFAULT VARIABLE SECTION
vm_prefix = '3'; --Voicemail
ivr_prefix = '5'; --IVR
ttsvoice = 'Matthew'; --text to speech voice
-----------------------------------------------------------



--set the variables
	max_tries = 3;
	digit_timeout = 3000;
	sounds_dir = "";
	recordings_dir = "";
	file_name = "";
	recording_number = "";
	recording_slots = "";
	recording_prefix = "";
	
	greetingTypes = {
		IVR = 'IVR',
		PREANSWER = 'pre-answer',
		PREQUEUE = 'pre-queue',
		WHISPER = 'whisper',
		EMERG = 'emergency announcement'
	};
	
	greetings = {
		pleaseEnterPIN = "Please enter your PIN Number.",
		pleaseEnterAcct = "Please enter the account number you wish to manage.",
		invalidAuth = "Your PIN number or account was incorrect. Goodbye.",
		checkAdminAcct = "Please enter the administrative account code",
		recordMainMenu = "To manage pre-answer prompts, press 1. To manage IVR prompts, press 2. To manage voicemail greetings, press 3. To manage whisper prompts, press 4. To manage pre-queue prompts, press 5. To manage emergency prompts, press 6. To manage account recordings, press 7.",
		recordChoiceMainInvalid = "You have entered an invalid selection. Please try again.",
		recordChoiceMainFinal = "You have entered an invalid selection too many times. Goodbye.",
		noVMBoxFound = "There were no voicemail boxes found for this account.",
		defaultVMBox = "To manage the account default mailbox greetings, press 0.",
		selectVMBox = "To manage mailbox greetings, enter the mailbox number from 1 to 99. To hear a list of mailboxes, press star star. To return to the main menu, press star.",
		selectVMGreet = "To manage a greeting, enter the greeting number from 1 to 99.",
		VMGreetOptions = "To listen to this greeting, press 1, to record this greeting, press 2. To set this greeting as the active voicemail greeting for this mailbox, press 3. To return to the main menu, press star.",
		VMNotExist = "This voicemail greeting has not yet been recorded.",
		VMRecordGreeting = "After the tone record the voicemail greeting. When done press pound.",
		VMRecordOptions = "To listen to this greeting, press 1. To accept this greeting, press 2. To try again, press 3. To cancel, press star.",
		VMRecordSuccess = "Greeting recorded successfully.",
		VMActiveGreetingSet = "Active greeting set successfully.",
		phraseNone = {
			"There were no ",
			" prompts found for this account. Please contact your system administrator to add prompts."
		},
		phraseChoice = {
			"To manage ",
			" prompts, enter the prompt number from 1 to 999. To hear a list of ",
			" prompts, press star star. To return to the main menu, press star."
		},
		noPhraseFound = {
			" phrase number ",
			"is not set up. Please contact your system administrator to enable this prompt."
		},
		phraseModifyPrompt = {
			"To listen to information about ",
			" prompt ",
			", press 1. To set or change a recording for ",
			" prompt ",
			", press 2. To cancel, press star."
		},
		phraseNoModify = "This phrase cannot be modified as it has custom programming enabled. Please contact your system administrator for more details.",
		phraseNoMatch = "There were no matching recordings for this prompt. Please inform your system administrator of this issue.",
		phraseRecNotFound = 'Recording not found. Please set a recording for this prompt.',
		phraseRecChoose = 'Please enter the recording number from 1 to 9999 you wish to set for this prompt. For a list of recordings, press star star. To cancel, press star.',
		phraseRecSet = {
			'Recording number ',
			' set successfully for ',
			' phrase number ',
			'.'
		},
		phraseDefault = " the default recording.",
		recordingChoice = "To manage recordings, enter the recording number from 1 to 9999. To hear a list of recordings for this account, press star star. To return to the main menu, press star.",
		recordingInfoInterrupt = "Press any key at any time to return to the previous menu.",
		recordingOptions = "To listen to this recording, press 1. To record this recording, press 2. To cancel and return to the previous menu, press star.",
		recordingExisting = "Please note, you are recording over an existing recording.",
		recordingRecord = "After the tone record the recording. When done press pound.",
		recordingRecordOptions = "To listen to this recording, press 1. To accept this recording, press 2. To try again, press 3. To cancel, press star.",
		recordingRecordSuccess = "Recording recorded successfully.",
		recordingNotExist = "This recording has not yet been recorded.",
	};
	

--include config.lua
	require "resources.functions.config";

--connect to the database
	local Database = require "resources.functions.database";
	dbh = Database.new('system');

--include json library
	local json = require "resources.functions.lunajson";

--get the domain_uuid
	domain_uuid = session:getVariable("domain_uuid");
	domain_name = session:getVariable("domain_name");

--add functions
	require "resources.functions.mkdir";
	require "resources.functions.explode";
	require "resources.functions.file_exists";
	file = require "resources.functions.file";

--initialize the recordings
	api = freeswitch.API();

--settings
	require "resources.functions.settings";
	settings = settings(domain_uuid);
	storage_type = "";
	storage_path = "";
	mgmt_acct = settings['recordings']['admin_acct']['numeric'] or '0000'; -- The account number for universal prompt managers
-- Set all of the directories needed to store recordings
	if (settings['recordings'] ~= nil) then
		if (settings['recordings']['vm_prefix'] ~= nil) then
			if (settings['recordings']['vm_prefix']['text'] ~= nil) then
				vm_prefix = settings['recordings']['vm_prefix']['text']
				freeswitch.consoleLog('INFO', "VM prefix override: `" .. vm_prefix .. "`")
			end
		end
		if (settings['recordings']['ivr_prefix'] ~= nil) then
			if (settings['recordings']['ivr_prefix']['text'] ~= nil) then
				ivr_prefix = settings['recordings']['ivr_prefix']['text']
				freeswitch.consoleLog('INFO', "IVR prefix override: `" .. ivr_prefix .. "`")
			end
		end
		if (settings['recordings']['ttsvoice'] ~= nil) then
			if (settings['recordings']['ttsvoice']['text'] ~= nil) then
				ttsvoice = settings['recordings']['ttsvoice']['text']
				freeswitch.consoleLog('INFO', "TTS voice override: `" .. ttsvoice .. "`")
			end
		end
		if (settings['recordings']['storage_type'] ~= nil) then
			if (settings['recordings']['storage_type']['text'] ~= nil) then
				storage_type = settings['recordings']['storage_type']['text'];
			end
		end
		if (settings['recordings']['storage_path'] ~= nil) then
			if (settings['recordings']['storage_path']['text'] ~= nil) then
				storage_path = settings['recordings']['storage_path']['text'];
				storage_path = storage_path:gsub("${domain_name}", domain_name);
				storage_path = storage_path:gsub("${voicemail_id}", voicemail_id);
				storage_path = storage_path:gsub("${voicemail_dir}", voicemail_dir);
			end
		else
			storage_path = settings['switch']['recordings']['dir'] .. '/' .. domain_name;
		end
	end
	if (settings['voicemail'] ~= nil) then
		vm_storage_type = '';
		if (settings['voicemail']['storage_type'] ~= nil) then
			if (settings['voicemail']['storage_type']['text'] ~= nil) then
				vm_storage_type = settings['voicemail']['storage_type']['text'];
			end
		end
		vm_storage_path = '';
		if (settings['voicemail']['storage_path'] ~= nil) then
			if (settings['voicemail']['storage_path']['text'] ~= nil) then
				vm_storage_path = settings['voicemail']['storage_path']['text'];
				vm_storage_path = vm_storage_path:gsub("${domain_name}", domain_name);
				vm_storage_path = storage_path:gsub("${voicemail_dir}", voicemail_dir);
			end
		else
			vm_storage_path = settings['switch']['voicemail']['dir'] .. '/default/' .. domain_name;
		end
	end
	if (not temp_dir) or (#temp_dir == 0) then
		if (settings['server'] ~= nil) then
			if (settings['server']['temp'] ~= nil) then
				if (settings['server']['temp']['dir'] ~= nil) then
					temp_dir = settings['server']['temp']['dir'];
				end
			end
		end
	end

-- function returns WAV location of text to speech
	function saytext(textstr)
		return api:executeString('python streamtext voice=' .. ttsvoice .. '|text=' .. textstr);
	end

-- flush memcache
	function flushcache()
		return api:executeString('memcache flush');
	end

-- returns an array of fields based on text and delimiter (one character only)
	function singlesplit(text, delim)
		local result = {};
		local magic = "().%+-*?[]^$";
		if delim == nil then
			delim = "%s";
		elseif string.find(delim, magic, 1, true) then
			-- escape magic
			delim = "%"..delim;
		end
		local pattern = "[^"..delim.."]+";
		for w in string.gmatch(text, pattern) do
			table.insert(result, w);
		end
		return result;
	end

-- returns a zero padded string from a number
function zeropad(numzero, instring)
	return string.format("%0" .. tostring(tonumber(numzero)) .. "d", tonumber(instring));
end

--authenticate against user parameters.
--THIS REQUIRES the PIN module to be enabled!
	function authenticate(acctcode, userpin)
		userauthed = 0;
		authname = '';
		local sql = [[SELECT * 
						FROM v_pin_numbers 
						WHERE pin_number = :pin_number 
						AND accountcode = :account_code 
						AND enabled = 'true' 
						AND domain_uuid = :domain_uuid]];
		local params = {
			pin_number = userpin,
			account_code = acctcode,
			domain_uuid = domain_uuid
		};
		dbh:query(sql, params, function(row)
			-- If we're here we have a match
			userauthed = 1;
			authname = row.description;
			return 1;
		end);
		if userauthed == 0 then
			local params = {
				pin_number = userpin,
				account_code = mgmt_acct,
				domain_uuid = domain_uuid
			};
			dbh:query(sql, params, function(row)
				-- If we're here we have a match
				userauthed = 2;
				authname = row.description;
				return 1;
			end);
		end
		return {authcode = userauthed, authnameinfo = authname};
	end

-- function queries for phrases that match the account and phrase type, returns phrase data and count
	function phrasesQuery(phrasetype, accountnum)
		local sql = [[SELECT * FROM v_phrases
						WHERE phrase_name LIKE :phrase_like
						AND domain_uuid = :domain_uuid
						AND phrase_enabled = :phrase_enabled
						ORDER BY phrase_name ASC]];
		-- format is {accountnum}-{\d\d\d}-{phrasetype}
		-- accountnum has leading 0's
		local params = {
			phrase_like = zeropad(4, accountnum) .. '-___-' .. phrasetype,
			domain_uuid = domain_uuid,
			phrase_enabled = 'true'
		};
		local phrasedata = {};
		phrasedata[0] = {};
		phrasedata[1] = {};
		local count = 0;
		dbh:query(sql, params, function(row)
			count = count + 1;
			local phraseparts = singlesplit(row.phrase_name, '-');
			-- I hate Lua. You can't skip values in a numbered array
			phrasedata[0][count] = zeropad(3, phraseparts[2]);
			phrasedata[1][zeropad(3, phraseparts[2])] = {
				phrase_uuid = row.phrase_uuid,
				phrase_description = row.phrase_description
			};
			
			-- LIMIT 1 will allow us to have unchangeable prompts before
			-- the main prompt if needed
			local subsql = [[SELECT * FROM v_phrase_details
								WHERE phrase_uuid = :phrase_uuid
								ORDER BY phrase_detail_order DESC
								LIMIT 1]];
			local subparams = {
				phrase_uuid = row.phrase_uuid
			};
			dbh:query(subsql, subparams, function(subrow)
				phrasedata[1][zeropad(3, phraseparts[2])]['detail'] = {
					phrase_detail_uuid = subrow.phrase_detail_uuid,
					phrase_detail_tag = subrow.phrase_detail_tag,
					phrase_detail_function = subrow.phrase_detail_function,
					phrase_detail_data = subrow.phrase_detail_data
				};
			end);
		end);
		return {phrasecount = count, data = phrasedata};
	end

-- Lists all phrases
	function listPhrases(phraseinfo, phrasetype)
		for _, item in ipairs(phraseinfo[0]) do
			local phrase_info = greetingTypes[phrasetype] .. " phrase number " .. tostring(tonumber(item)) .. '. Description, ';
			if phraseinfo[1][item]['phrase_description'] == '' then
				phrase_info = phrase_info .. 'No description.';
			else
				phrase_info = phrase_info .. phraseinfo[1][item]['phrase_description'] .. '.';
			end
			session:execute('playback', saytext(phrase_info));
			session:execute('sleep', '250');
		end
		return;
	end

-- matches phrase recordings with recordings in database
	function phraseRecordingID(filename, accountnum)
		local recordings = recordingsQuery(accountnum);
		--freeswitch.consoleLog('info', 'Rec Data!!!: ' .. json.encode(recordings[1]));
		for key, value in pairs(recordings[1]) do
			--freeswitch.consoleLog('info', 'Key: ' .. key);
			if value['recording_filename'] == filename then
				return zeropad(4, key);
			end
		end
		return;
	end

-- query to set recording in phrase
	function updatePhraseRecording(phrasenumber, phrases, recordingnumber, recordings)
		local sql = [[UPDATE v_phrase_details
						SET phrase_detail_data = :phrase_detail_data
						WHERE phrase_detail_uuid = :phrase_detail_uuid
						AND domain_uuid = :domain_uuid]];
		local dbparams = {
			phrase_detail_data = '${lua streamfile.lua ' .. recordings[1][zeropad(4, recordingnumber)]['recording_filename'] .. '}',
			phrase_detail_uuid = phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_uuid'],
			domain_uuid = domain_uuid
		};
		--freeswitch.consoleLog('info', 'UPDATE PARAMS: ' .. json.encode(dbparams));
		dbh:query(sql, dbparams);
		flushcache();
		return;
	end

-- Changes associated recording
	function phraseSetRecording(phrasenumber, phrasetype, phrases, accountnum)
		local result = false;
		if phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_function'] ~= 'play-file' or string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'], 1, 20) ~= '${lua streamfile.lua' then -- this means it's not a recording, but text to speech or something else
			session:execute('playback', saytext(greetings['phraseNoModify']));
			return;
		end
		--${lua streamfile.lua <FNAME>} (we're extracting <FNAME>)
		local recFileName = string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'], 22, -2);
		local phrase_recording_id = phraseRecordingID(recFileName, accountnum);
		if string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'], 1, 29) ~= "${lua streamfile.lua default-" then
			if phrase_recording_id == nil then
				freeswitch.consoleLog('err', phrasetype .. ' phrase ' .. phrasenumber .. ' references a missing recording!!!');
				session:execute('playback', saytext(greetings['phraseNoMatch']));
			else
				freeswitch.consoleLog('info', phrasetype .. ' phrase ' .. phrasenumber .. ' matches recording number ' .. tostring(phrase_recording_id) .. '!!!')
			end
		end
		local recordingsdata = recordingsQuery(accountnum);
		local validchoice = false;
		while validchoice == false and session:ready() do
			local phraseChoice = session:playAndGetDigits(1, 4, 3, digit_timeout, "#", saytext(greetings['phraseRecChoose']), saytext(greetings['recordChoiceMainInvalid']), "\\d+|\\*\\*|\\*");
			if phraseChoice == '*' or phraseChoice == '' then
				validchoice = true;
				return result;
			elseif phraseChoice == '**' then
				playRecordingsInfo(recordingsdata);
			else
				if recordingsdata[1][zeropad(4, phraseChoice)] == nil then
					session:execute('playback', saytext(greetings['recordingNotExist']));
				else
					updatePhraseRecording(phrasenumber, phrases, tonumber(phraseChoice), recordingsdata);
					-- After update, repopulate phrase data
					allphrases = phrasesQuery(phrasetype, accountnum);
					phrases = allphrases['data'];
					session:execute('playback', saytext(greetings['phraseRecSet'][1] .. phraseChoice .. greetings['phraseRecSet'][2] .. phrasetype .. greetings['phraseRecSet'][3] .. tostring(phrasenumber) .. greetings['phraseRecSet'][4]));
					result = true;
					validchoice = true;
				end
			end
		end
		return result;
	end
	
-- list all the recordings associated with a phrase
	function getPhraseInfo(phrasenumber, phrasetype, phrases, accountnum)
		local phrase_info = greetingTypes[phrasetype] .. " phrase number " .. tostring(phrasenumber) .. '. Description, ';
		local phrasesaytext = '';
		if phrases[1][zeropad(3, phrasenumber)]['phrase_description'] == '' then
			phrase_info = phrase_info .. 'No description. ';
		else
			phrase_info = phrase_info .. phrases[1][zeropad(3, phrasenumber)]['phrase_description'] .. '. ';
		end
		
		if phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_function'] == 'play-file' then
			if string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'], 1, 20) ~= '${lua streamfile.lua' then
				if string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'], 1, 19) == '${python streamtext' then
					if string.find(string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'],21, -2), '|') then
						phrasesaytext = string.sub(singlesplit(string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'],21, -2), '|')[2], 6, -1);
					else
						phrasesaytext = string.sub(string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'],21, -2), 6, -1);
					end
					--freeswitch.consoleLog('info', 'SAYTEXT: ' .. phrasesaytext);
					phrase_info = phrase_info .. 'This is a text to speech phrase and cannot be modified. The text reads, ' .. phrasesaytext;
				end
			else
				phrase_info = phrase_info .. 'The recording for this phrase is ';
			end
		else
			phrase_info = phrase_info .. 'This phrase has custom logic and cannot be modified.';
		end
		if string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'], 1, 20) == '${lua streamfile.lua' then
			local recordingID = phraseRecordingID(string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'], 22, -2), accountnum);
			if recordingID == nil then
				session:execute('playback', saytext(phrase_info));
				if string.sub(phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data'], 1, 29) == "${lua streamfile.lua default-" then
					session:execute('playback', saytext(greetings['phraseDefault']));
				else
					session:execute('playback', saytext(greetings['phraseRecNotFound']));
				end
			else
				phrase_info = phrase_info .. 'recording number ' .. tostring(tonumber(recordingID)) .. '.';
				session:execute('playback', saytext(phrase_info));
				session:execute('playback', phrases[1][zeropad(3, phrasenumber)]['detail']['phrase_detail_data']);
			end
		else
			session:execute('playback', saytext(phrase_info));
		end
		session:execute('sleep', '200');
		return;
	end
-- function to modify individual phrases
	function modifyPhrase(phrasenumber, phrasetype, phrases, accountnum)
		if phrases[1][zeropad(3, phrasenumber)] == nil then
			session:execute('playback', saytext(phrasetype .. greetings['noPhraseFound'][1] .. tostring(phrasenumber) .. greetings['noPhraseFound'][2]));
			return;
		end
		local phrasePrompt = greetings['phraseModifyPrompt'][1] .. greetingTypes[phrasetype] .. greetings['phraseModifyPrompt'][2] .. tostring(phrasenumber) .. greetings['phraseModifyPrompt'][3] .. greetingTypes[phrasetype] .. greetings['phraseModifyPrompt'][4] .. tostring(phrasenumber) .. greetings['phraseModifyPrompt'][5];
		local validchoice = false;
		while validchoice == false and session:ready() do
			local modifyPhraseChoice = session:playAndGetDigits(1, 1, 3, digit_timeout, "#", saytext(phrasePrompt), saytext(greetings['recordChoiceMainInvalid']), "[12\\*]");
			if modifyPhraseChoice == '*' or modifyPhraseChoice == '' then
				validchoice = true;
				return;
			elseif modifyPhraseChoice == '1' then
				getPhraseInfo(phrasenumber, phrasetype, phrases, accountnum);
			else
				if phraseSetRecording(phrasenumber, phrasetype, phrases, accountnum) == true then
					allphrases = phrasesQuery(phrasetype, accountnum);
					phrases = allphrases['data'];
					validchoice = true;
					return;
				end
			end
		end
		return;
	end

-- Entry point for phrase management
	function managePhrases(phrasetype, accountnum)
		allphrases = phrasesQuery(phrasetype, accountnum);
		--freeswitch.consoleLog('info', 'PHRASE COUNT: ' .. tostring(allphrases['phrasecount']));
		--freeswitch.consoleLog('info', 'PHRASE ARR: ' .. json.encode(allphrases['data'][0]));
		--freeswitch.consoleLog('info', 'PHRASE JSON: ' .. json.encode(allphrases['data'][1]));
		if allphrases['phrasecount'] < 1 then
			local nophrases = greetings['phraseNone'][1] .. greetingTypes[phrasetype] .. greetings['phraseNone'][2];
			session:execute('playback', saytext(nophrases));
			return;
		end
		local phraseChoicePrompt = greetings['phraseChoice'][1] .. greetingTypes[phrasetype] .. greetings['phraseChoice'][2] .. greetingTypes[phrasetype] .. greetings['phraseChoice'][3];
		local validchoice = false;
		while validchoice == false and session:ready() do
			local phraseChoice = session:playAndGetDigits(1, 3, 3, digit_timeout, "#", saytext(phraseChoicePrompt), saytext(greetings['recordChoiceMainInvalid']), "\\d+|\\*\\*|\\*");
			if phraseChoice == '*' or phraseChoice == '' then --cancel/invalid choice
				validchoice = true;
				return;
			elseif phraseChoice == '**' then
				listPhrases(allphrases['data'], phrasetype);
			else
				modifyPhrase(tonumber(phraseChoice), phrasetype, allphrases['data'], accountnum);
			end
		end
		return;
	end

-- function queries to see if voicemail boxes exist for account
-- returns dictionary of all voicemail boxes and their greetings for the account.
	function vmQuery(accountnum)
		local acct_vm_boxes = {};
		acct_vm_boxes['boxorder'] = {};
		local sql = [[SELECT * FROM v_voicemails 
						WHERE LEFT(voicemail_id::text, 5) = :acct_num 
						AND domain_uuid = :domain_uuid 
						ORDER BY voicemail_id ASC]];
		local params = {
			acct_num = vm_prefix .. zeropad(4, accountnum),
			domain_uuid = domain_uuid
		};
		local icount = 0;
		dbh:query(sql, params, function(row)
			-- If we're here we have a match
			local sub_box = string.match(tostring(row.voicemail_id), accountnum .. "(.*)");
			icount = icount + 1;
			if sub_box == '' or sub_box == nil then
				acct_vm_boxes['boxorder'][icount] = '9999';
				acct_vm_boxes['9999'] = {
							voicemail_id = row.voicemail_id,
							voicemail_uuid = row.voicemail_uuid,
							voicemail_description = row.voicemail_description,
							greeting_id = row.greeting_id,
							greetings = {}
						};
			else
				acct_vm_boxes['boxorder'][icount] = sub_box;
				acct_vm_boxes[sub_box] = {
							voicemail_id = row.voicemail_id,
							voicemail_uuid = row.voicemail_uuid,
							voicemail_description = row.voicemail_description,
							greeting_id = row.greeting_id,
							greetings = {}
						};
			end
		end);
		local count = 0;
		for k, v in pairs(acct_vm_boxes) do
			if k ~= 'boxorder' then
				count = count + 1;
				--freeswitch.consoleLog('info', v['voicemail_id']);
				local recsql = [[SELECT greeting_id, voicemail_greeting_uuid, greeting_name, greeting_filename 
									FROM v_voicemail_greetings 
									WHERE voicemail_id = :voicemail_id 
									ORDER BY greeting_id ASC]];
				local recparams = {
					voicemail_id = v['voicemail_id']
				};
				dbh:query(recsql, recparams, function(row)
					--freeswitch.consoleLog('info', json.encode(acct_vm_boxes[k]))
					acct_vm_boxes[k]['greetings'][row.greeting_id] = {
						voicemail_greeting_uuid = row.voicemail_greeting_uuid,
						greeting_name = row.greeting_name,
						greeting_filename = row.greeting_filename,
					};
				end);
			end
		end
		return {vmcount = count, vm_boxes = acct_vm_boxes};
	end

-- function plays full list of voicemail boxes
	function listVoicemailBoxes(boxlist)
		local playtext = 'To interrupt mailbox listing, press any key. ';
		for _, key in ipairs(boxlist['boxorder']) do
			--freeswitch.consoleLog('info', 'key: ' .. key);
			if key == '9999' then
				playtext = playtext .. 'Account default mailbox. ';
				if boxlist[key]['voicemail_description'] ~= '' then
					playtext = playtext .. 'Description, ' .. boxlist[key]['voicemail_description'] .. ' .';
				end
			else
				local mboxstr = tostring(tonumber(key));
				playtext = playtext .. 'Mailbox number, ' .. mboxstr .. '. ';
				if boxlist[key]['voicemail_description'] ~= '' then
					playtext = playtext .. 'Description, ' .. boxlist[key]['voicemail_description'] .. ' .';
				end
			end
		end
		session:playAndGetDigits(1, 1, 1, digit_timeout, '#', saytext(playtext), '', "\\d+|\\*");
		return;
	end

--function gets the greeting location. If stores in base64, pulls from database and writes to file
	function getVMFilename(greeting_uuid, mbox_id, greeting_fname)
		if vm_storage_type ~= 'base64' then
			return vm_storage_path .. '/' .. mbox_id .. '/' .. greeting_fname;
		else
			mkdir(vm_storage_path .. '/' .. mbox_id);
			local getgreetsql = [[SELECT greeting_base64 
									FROM v_voicemail_greetings 
									WHERE voicemail_greeting_uuid = :greet_uuid]];
			local getgreetparams = {
				greet_uuid = greeting_uuid
			};
			local dbh64 = Database.new('system', 'base64');
			dbh64:query(getgreetsql, getgreetparams, function(row)
				--freeswitch.consoleLog('info', 'Writing file ' .. vm_storage_path .. '/' .. mbox_id .. '/' .. greeting_fname .. ' with data ' .. row.greeting_base64);
				assert(file.write_base64(vm_storage_path .. '/' .. mbox_id .. '/' .. greeting_fname, row.greeting_base64));
			end);
			return vm_storage_path .. '/' .. mbox_id .. '/' .. greeting_fname;
		end
	end

-- function sets the greeting for the mailbox
	function setVMGreeting(greetnum, boxlist, mbox_id)
		local vm_box_num = '';
		if tonumber(mbox_id) ~= 9999 then
			vm_box_num = vm_prefix .. acctnumber .. zeropad(2, mbox_id);
			formatted_mbox_id = zeropad(2, mbox_id);
		else
			vm_box_num = vm_prefix .. acctnumber;
			formatted_mbox_id = '9999';
		end
		sql = [[UPDATE v_voicemails SET
			greeting_id = :greeting_id
			WHERE
			voicemail_id = :voicemail_id]];
		dbparams = {
			greeting_id = tonumber(greetnum);
			voicemail_id = tonumber(vm_box_num);
		};
		dbh:query(sql, dbparams);
		vmboxes['vm_boxes'][formatted_mbox_id]['greeting_id'] = tostring(greetnum);
		session:execute('playback',  saytext(greetings['VMActiveGreetingSet']));
		return;
	end

-- function records and verifies recording, puts in place
-- if no default prompt is set, sets default prompt
	function recordVMGreeting(greetnum, boxlist, mbox_id, accountnum)
		local vm_box_num = '';
		local record_uuid = '';
		local sql = '';
		if tonumber(mbox_id) ~= 9999 then
			vm_box_num = vm_prefix .. acctnumber .. zeropad(2, mbox_id);
			formatted_mbox_id = zeropad(2, mbox_id);
		else
			vm_box_num = vm_prefix .. acctnumber;
			formatted_mbox_id = '9999';
		end
		local final_recording_name = "Greeting " .. greetnum;
		local final_recording_file = "greeting_" .. greetnum .. ".wav";
		local final_recording_loc = vm_storage_path .. '/' .. mbox_id .. '/' .. final_recording_file;
		if boxlist['greetings'][greetnum] == nil then
			record_uuid = api:execute("create_uuid");
			sql = [[INSERT INTO v_voicemail_greetings 
					(voicemail_greeting_uuid,
					domain_uuid,
					voicemail_id,
					greeting_id,
					greeting_name,
					greeting_filename,
					greeting_description,
					greeting_base64)
					VALUES
					(:voicemail_greeting_uuid, 
					:domain_uuid,
					:voicemail_id,
					:greeting_id,
					:greeting_name,
					:greeting_filename,
					:greeting_description,
					:greeting_base64)
					]];
		else
			record_uuid = boxlist['greetings'][greetnum]['voicemail_greeting_uuid'];
			sql = [[UPDATE v_voicemail_greetings SET
					voicemail_greeting_uuid = :voicemail_greeting_uuid,
					domain_uuid = :domain_uuid,
					voicemail_id = :voicemail_id,
					greeting_id = :greeting_id,
					greeting_name = :greeting_name,
					greeting_filename = :greeting_filename,
					greeting_description = :greeting_description,
					greeting_base64 = :greeting_base64
					WHERE
					voicemail_greeting_uuid = :voicemail_greeting_uuid]];
		end
		local tmp_recording_file = temp_dir .. "/" .. record_uuid .. ".wav";
		local record_complete = false;
		while not record_complete and session:ready() do
			session:execute('playback', saytext(greetings['VMRecordGreeting']));
			session:execute('sleep', '1000');
			session:execute('playback', 'tone_stream://%(1000, 0, 640)');
			session:execute("set", "playback_terminators=#");
			session:execute('record', tmp_recording_file);
			local listening = true;
			while listening and session:ready() do
				local vmchoice = session:playAndGetDigits(1, 1, 3, digit_timeout, "#", saytext(greetings['VMRecordOptions']), saytext(greetings['recordChoiceMainInvalid']), "[123\\*]");
				if vmchoice == '1' then -- listen to recording
					session:execute('playback', tmp_recording_file);
				elseif vmchoice == '2' then -- save recording
					listening = false;
					record_complete = true;
					if storage_type == "base64" then
						recording_base64 = file.read_base64(tmp_recording_file);
						if recording_base64 == nil then
							recording_base64 = '';
						end
					else
						recording_base64 = '';
					end
					dbparams = {
						voicemail_greeting_uuid = record_uuid,
						domain_uuid = domain_uuid,
						voicemail_id = vm_box_num,
						greeting_id = tonumber(greetnum),
						greeting_name = final_recording_name,
						greeting_filename = final_recording_file,
						greeting_description = '',
						greeting_base64 = recording_base64
					};
					if storage_type == "base64" then
						local dbh64 = Database.new('system', 'base64');
						dbh64:query(sql, dbparams);
					else
						dbh:query(sql, dbparams);
					end
					if file.exists(final_recording_loc) ~= nil then
						file.remove(final_recording_loc);
					end
					file.rename(tmp_recording_file, final_recording_loc);
					-- update VM list
					vmboxes = vmQuery(accountnum);
					session:execute('playback', saytext(greetings['VMRecordSuccess']));
					if vmboxes['vm_boxes'][formatted_mbox_id]['greeting_id'] == "" then
						setVMGreeting(greetnum, boxlist, mbox_id);
					end
					--freeswitch.consoleLog('info', 'All MBOX json: ' .. json.encode(vmboxes));
					return
				elseif vmchoice == '3' then -- try again
					listening = false;
				elseif vmchoice == '*' then -- cancel
					if file.exists(tmp_recording_path) ~= nil then
					file.remove(tmp_recording_path);
					end
					return;
				else
					if file.exists(tmp_recording_path) ~= nil then
						file.remove(tmp_recording_path);
					end
					return;
				end

			end
		end
		return;
	end

-- function plays voicemail greeting
	function playVMGreeting(greetnum, boxlist)
		--freeswitch.consoleLog('info', 'boxlist: ' .. json.encode(boxlist));
		--freeswitch.consoleLog('info', 'greetnum: ' .. greetnum);
		if boxlist['greetings'][greetnum] == nil then
			freeswitch.consoleLog('err', 'Greeting ' .. greetnum .. ' not found');
			session:execute('playback', saytext(greetings['VMNotExist']));
		else
			local vm_greet_fname = getVMFilename(boxlist['greetings'][greetnum]['voicemail_greeting_uuid'], boxlist['voicemail_id'], boxlist['greetings'][greetnum]['greeting_filename']);
			session:execute('playback', vm_greet_fname);
		end
		return;
	end

-- main voicemail box management function
	function manageVoicemailBox(boxlist, mbox_id, accountnum)
		--freeswitch.consoleLog('info', 'MBox JSON: ' .. json.encode(boxlist));
		local validchoice = false;
		while validchoice == false and session:ready() do
			local vmchoice = session:playAndGetDigits(1, 2, 3, digit_timeout, "#", saytext(greetings['selectVMGreet']), saytext(greetings['recordChoiceMainInvalid']), "\\d+|\\*");
			if vmchoice == '*' or vmchoice == '' then
				return;
			else
				local validgreetchoice = false
				while validgreetchoice == false and session:ready() do
					--freeswitch.consoleLog('info', 'Manage MBOX json: ' .. json.encode(boxlist));
					local greetchoice = session:playAndGetDigits(1, 1, 3, digit_timeout, "#", saytext(greetings['VMGreetOptions']), saytext(greetings['recordChoiceMainInvalid']), "[123\\*]");
					if greetchoice == '*' then -- cancel
						validgreetchoice = true;
					elseif greetchoice == '1' then -- play greeting
						playVMGreeting(vmchoice, boxlist);
					elseif greetchoice == '2' then -- record greeting
						recordVMGreeting(vmchoice, boxlist, mbox_id, accountnum);
					elseif greetchoice == '3' then -- set this greeting as active
						setVMGreeting(vmchoice, boxlist, mbox_id);
					end
				end
			end
		end
		return 
	end

-- function facilitates Voicemail box selection
	function manageVoicemail(accountnum)
		vmboxes = vmQuery(accountnum);
		--freeswitch.consoleLog('info', "All MBOX json: " .. json.encode(vmboxes));
		if vmboxes['count'] == 0 then
			session:execute('playback', saytext(greetings['noVMBoxFound']));
			return;
		end
		local vmchoiceprompt = '';
		if vmboxes['vm_boxes']['9999'] ~= nil then
			vmchoiceprompt = greetings['defaultVMBox'] .. ' ' .. greetings['selectVMBox'];
		else
			vmchoiceprompt = greetings['selectVMBox'];
		end
		local validchoice = false;
		while validchoice == false and session:ready() do
			local vmchoice = session:playAndGetDigits(1, 2, 3, digit_timeout, "#", saytext(vmchoiceprompt), saytext(greetings['recordChoiceMainInvalid']), "\\d+|\\*\\*|\\*");
			if vmchoice == '**' then
				listVoicemailBoxes(vmboxes['vm_boxes']);
			elseif vmchoice == '*' then
				return;
			else
				local vmfinalchoice = '';
				if vmchoice == '0' then
					vmfinalchoice = '9999';
				else
					vmfinalchoice = vmchoice;
				end
				if tonumber(vmchoice) == nil then
					--session:execute('playback', saytext(greetings['recordChoiceMainInvalid']));
				elseif vmboxes['vm_boxes'][zeropad(2, vmfinalchoice)] ~= nil then
					validchoice = true;
					manageVoicemailBox(vmboxes['vm_boxes'][zeropad(2, vmfinalchoice)], vmfinalchoice, accountnum);
				else
					session:execute('playback', saytext(greetings['recordChoiceMainInvalid']));
				end
			end
		end
		return
	end
	
-- function queries all recordings for account, returns dictionary with data
	function recordingsQuery(accountnum)
		local sql = [[SELECT recording_uuid, recording_filename, recording_name, recording_description
						FROM v_recordings
						WHERE recording_name LIKE :recording_like
						AND domain_uuid = :domain_uuid
						ORDER BY recording_name]];
		-- recording name format - {ACCT}-XXXX
		local params = {
			recording_like = zeropad(4, accountnum) .. '-____',
			domain_uuid = domain_uuid
		};
		local recordingData = {};
		recordingData[0] = {};
		recordingData[1] = {};
		local count = 0;
		dbh:query(sql, params, function(row)
			local recordingParts = singlesplit(row.recording_name, '-');
			if tonumber(recordingParts[2]) ~= nil then
				count = count + 1;
				recordingData[0][count] = zeropad(4, recordingParts[2]);
				--freeswitch.consoleLog('info', 'Recording number ' .. zeropad(4, recordingParts[2]) .. ' added.');
				recordingData[1][zeropad(4, recordingParts[2])] = {
					recording_uuid = row.recording_uuid,
					recording_filename = row.recording_filename,
					recording_name = row.recording_name,
					recording_description = row.recording_description
				};
			end
		end);
		return recordingData;
	end
	
-- function plays info about all recordings
	function playRecordingsInfo(recordinglist)
		--freeswitch.consoleLog('info', 'recordinglist: ' .. json.encode(recordinglist));
		session:execute('playback', saytext(greetings['recordingInfoInterrupt']));
		session:execute('sleep', '200');
		for _, key in pairs(recordinglist[0]) do
			local recdescription = '';
			if recordinglist[1][key]['recording_description'] == nil or recordinglist[1][key]['recording_description'] == '' then
				recdescription = 'No description provided.';
			else
				recdescription = recordinglist[1][key]['recording_description'];
			end
			local recordingInfo = 'Recording number, ' .. tostring(tonumber(key)) .. '. Description, ' .. recdescription .. '.'
			local goprevious = session:playAndGetDigits(1, 1, 1, 1, "#", saytext(recordingInfo), '', '\\d|\\*|#');
			if goprevious ~= '' then
				return;
			end
		end
		return;
	end
	
--function gets the recording location. If stored in base64, pulls from database and writes to file
	function getRecordingFilename(recording_uuid, recording_fname)
		if vm_storage_type ~= 'base64' then
			return storage_path .. '/' .. recording_fname;
		else
			local getrecsql = [[SELECT recording_base64 
									FROM v_recordings
									WHERE recording_uuid = :recording_uuid]];
			local getrecparams = {
				recording_uuid = recording_uuid
			};
			local dbh64 = Database.new('system', 'base64');
			dbh64:query(getrecsql, getrecparams, function(row)
				assert(file.write_base64(storage_path .. '/' .. recording_fname, row.recording_base64));
			end);
			return storage_path .. '/' .. recording_fname;
		end
	end
	
-- function plays recording
	function playRecording(recordingnumber, recordinglist)
		if recordinglist[1][zeropad(4, recordingnumber)] == nil then
			freeswitch.consoleLog('err', 'Recording ' .. zeropad(4, recordingnumber) .. ' not found');
			session:execute('playback', saytext(greetings['recordingNotExist']));
		else
			local rec_fname = getRecordingFilename(recordinglist[1][zeropad(4, recordingnumber)]['recording_uuid'], recordinglist[1][zeropad(4, recordingnumber)]['recording_filename']);
			session:execute('playback', rec_fname);
		end
		return;
	end
	
-- record recording, warn if recording over greeting
	function recordRecording(recordingnumber, accountnum, recordinglist)
		local recording_file_loc = '';
		local recording_description = '';
		local recording_name = '';
		local recording_UUID = '';
		local recording_filename = '';
		local sql = '';
		local tmp_file_loc = '';
		if recordinglist[1][zeropad(4, recordingnumber)] == nil then
			recording_file_loc = storage_path .. '/' .. zeropad(4, accountnum) .. '-' .. zeropad(4, recordingnumber) .. '.wav';
			tmp_file_loc = temp_dir .. '/' .. zeropad(4, accountnum) .. '-' .. zeropad(4, recordingnumber) .. '.wav';
			recording_description = "";
			recording_name = zeropad(4, accountnum) .. '-' .. zeropad(4, recordingnumber);
			recording_UUID = api:execute("create_uuid");
			recording_filename = zeropad(4, accountnum) .. '-' .. zeropad(4, recordingnumber) .. '.wav';
			sql = [[INSERT INTO v_recordings 
					(recording_uuid,
					domain_uuid,
					recording_filename,
					recording_name,
					recording_description,
					recording_base64
					)
					VALUES
					(:recording_uuid,
					:domain_uuid,
					:recording_filename,
					:recording_name,
					:recording_description,
					:recording_base64
					)]];
		else
			recording_file_loc = storage_path .. '/' .. recordinglist[1][zeropad(4, recordingnumber)]['recording_filename'];
			tmp_file_loc = temp_dir .. '/' .. recordinglist[1][zeropad(4, recordingnumber)]['recording_filename'];
			recording_description = recordinglist[1][zeropad(4, recordingnumber)]['recording_description'];
			recording_name = recordinglist[1][zeropad(4, recordingnumber)]['recording_name'];
			recording_UUID = recordinglist[1][zeropad(4, recordingnumber)]['recording_uuid'];
			recording_filename = recordinglist[1][zeropad(4, recordingnumber)]['recording_filename'];
			sql = [[UPDATE v_recordings
					SET recording_base64 = :recording_base64
					WHERE recording_uuid = :recording_uuid
					AND domain_uuid = :domain_uuid]];
			session:execute('playback', saytext(greetings['recordingExisting']));
		end
		--freeswitch.consoleLog('info', 'Recording path: ' .. recording_file_loc);
		local record_complete = false;
		while not record_complete and session:ready() do
			session:execute('playback', saytext(greetings['recordingRecord']));
			session:execute('sleep', '1000');
			session:execute('playback', 'tone_stream://%(1000, 0, 640)');
			session:execute("set", "playback_terminators=#");
			session:execute('record', tmp_file_loc);
			local listening = true;
			while listening and session:ready() do
				local recchoice = session:playAndGetDigits(1, 1, 3, digit_timeout, "#", saytext(greetings['recordingRecordOptions']), saytext(greetings['recordChoiceMainInvalid']), "[123\\*]");
				if recchoice == '1' then --listen to recording
					session:execute('playback', tmp_file_loc);
				elseif recchoice == '2' then -- save recording
					listening = false;
					record_complete = true;
					if storage_type == "base64" then
						recording_base64 = file.read_base64(tmp_file_loc);
						if recording_base64 == nil then
							recording_base64 = '';
						end
					else
						recording_base64 = '';
					end
					local dbparams = {
						recording_uuid = recording_UUID,
						domain_uuid = domain_uuid,
						recording_filename = recording_filename,
						recording_name = recording_name,
						recording_description = recording_description,
						recording_base64 = recording_base64
					};
					if storage_type == "base64" then
						local dbh64 = Database.new('system', 'base64');
						dbh64:query(sql, dbparams);
					else
						dbh:query(sql, dbparams);
					end
					if file.exists(recording_file_loc) ~= nil then
						file.remove(recording_file_loc);
					end
					file.rename(tmp_file_loc, recording_file_loc);
					-- update recording list
					recordingData = recordingsQuery(accountnum);
					return;
				elseif recchoice == '3' then
					listening = false;
				elseif recchoice == '*' then
					if file.exists(tmp_file_loc) ~= nil then
						file.remove(tmp_file_loc);
					end
					return;
				end
			end
		end
		return;
	end
	
-- select option for recording
	function manageRecordingNumber(recordingnumber, accountnum, recordinglist)
		local validchoice = false;
		session:execute('playback', saytext('Greeting ' .. tostring(recordingnumber) .. ' selected.'));
		session:execute('sleep', '200');
		while validchoice == false and session:ready() do
			local recchoice = session:playAndGetDigits(1, 1, 3, digit_timeout, "#", saytext(greetings['recordingOptions']), saytext(greetings['recordChoiceMainInvalid']), "[123\\*]");
			if recchoice == '*' then -- cancel
				validchoice = true;
			elseif recchoice == '1' then -- play greeting
				playRecording(tonumber(recordingnumber), recordinglist);
			elseif recchoice == '2' then -- record greeting
				recordRecording(tonumber(recordingnumber), accountnum, recordinglist);
			end
		end
		return 
	end
	
-- main recording management function
	function manageRecordings(accountnum)
		recordingData = recordingsQuery(accountnum);
		--freeswitch.consoleLog('info', 'RECORDINGS JSON: ' .. json.encode(recordingData));
		local validchoice = false;
		while validchoice == false and session:ready() do
			local recordingchoice = session:playAndGetDigits(1, 4, 3, digit_timeout, "#", saytext(greetings['recordingChoice']), saytext(greetings['recordChoiceMainInvalid']), "\\d{1,4}|\\*\\*|\\*");
			if recordingchoice == '**' then -- play list of recordings
				playRecordingsInfo(recordingData);
			elseif recordingchoice == '*' then -- cancel
				validchoice = true;
			elseif recordingchoice == '' then -- invalid entry
				validchoice = true;
			else -- recording number entered
				manageRecordingNumber(recordingchoice, accountnum, recordingData);
			end
		end
		return
	end

-- main account management menu function
	function acctMgmt(accountnum)
		freeswitch.consoleLog('info', 'Account Number: ' .. accountnum);
		local attemptnums = 0;
		while attemptnums < 4 and session:ready() do
			session:execute('sleep', '500');
			local recchoice = session:playAndGetDigits(1, 1, 1, digit_timeout, "#", saytext(greetings['recordMainMenu']), "", "\\d+");
			if recchoice == '1' then --PreAnswer Greetings
				managePhrases('PREANSWER', accountnum);
			elseif recchoice == '2' then --IVR
				managePhrases('IVR', accountnum);
			elseif recchoice == '3' then -- VM
				manageVoicemail(accountnum);
			elseif recchoice == '4' then -- Whisper Prompts
				managePhrases('WHISPER', accountnum);
			elseif recchoice == '5' then -- Pre-Queue Prompts
				managePhrases('PREQUEUE', accountnum);
			elseif recchoice == '6' then -- Emergency Prompts
				managePhrases('EMERG', accountnum);
			elseif recchoice == '7' then -- Recordings
				manageRecordings(accountnum);
			else
				if attemptnums == 3 then
					session:execute('playback', saytext(greetings['recordChoiceMainFinal']));
					return
				else
					session:execute('playback', saytext(greetings['recordChoiceMainInvalid']));
					attemptnums = attemptnums + 1;
				end
			end
		end
	end

	if ( session:ready() ) then
		session:answer();

	--get the dialplan variables and set them as local variables
		sounds_dir = session:getVariable("sounds_dir");
		domain_name = session:getVariable("domain_name");
		domain_uuid = session:getVariable("domain_uuid");

	--add the domain name to the recordings directory
		recordings_dir = recordings_dir .. "/"..domain_name;

	--set the sounds path for the language, dialect and voice
		default_language = session:getVariable("default_language");
		default_dialect = session:getVariable("default_dialect");
		default_voice = session:getVariable("default_voice");

		if (not default_language) then default_language = 'en'; end
		if (not default_dialect) then default_dialect = 'us'; end
		if (not default_voice) then default_voice = 'callie'; end

	--Check PIN number
		
		min_digits = 4;
		max_digits = 10;
		--freeswitch.consoleLog('info', 'Storage Type: ' .. storage_type);
		--freeswitch.consoleLog('info', 'Storage Path: ' .. storage_path);
		--freeswitch.consoleLog('info', 'VM Storage Type: ' .. vm_storage_type);
		--freeswitch.consoleLog('info', 'VM Storage Path: ' .. vm_storage_path);
		pinnumber = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", saytext(greetings['pleaseEnterPIN']), "", "\\d+");
		acctnumber = session:playAndGetDigits(1, 4, max_tries, digit_timeout, "#", saytext(greetings['pleaseEnterAcct']), "", "\\d+");
		userauthed = authenticate(acctnumber, pinnumber);
		if userauthed['authcode'] == 0 then
			session:execute('playback', saytext(greetings['invalidAuth']));
			return
		
		elseif userauthed['authcode'] == 1 then
			acctMgmt(acctnumber);
		elseif userauthed['authcode'] == 2 then
			session:execute('sleep', '600');
			adminacct = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", saytext(greetings['checkAdminAcct']), "", "\\d+");
			if adminacct ~= mgmt_acct then
				session:execute('playback', saytext(greetings['invalidAuth']));
				return
			else
				acctMgmt(acctnumber);
			end
		end
	end
