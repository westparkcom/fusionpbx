<?php
/*
	FusionPBX
	Version: MPL 1.1

	The contents of this file are subject to the Mozilla Public License Version
	1.1 (the "License"); you may not use this file except in compliance with
	the License. You may obtain a copy of the License at
	http://www.mozilla.org/MPL/

	Software distributed under the License is distributed on an "AS IS" basis,
	WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
	for the specific language governing rights and limitations under the
	License.

	The Original Code is FusionPBX

	The Initial Developer of the Original Code is
	Mark J Crane <markjcrane@fusionpbx.com>
	Portions created by the Initial Developer are Copyright (C) 2008-2018
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	Mark J Crane <markjcrane@fusionpbx.com>
*/

//includes
	require_once "root.php";
	require_once "resources/require.php";
	require_once "resources/check_auth.php";

//check permissions
	if (permission_exists('voicemail_option_delete')) {
		//access granted
	}
	else {
		echo "access denied";
		exit;
	}

//add multi-lingual support
	$language = new text;
	$text = $language->get();

//set the http values as variables
	$voicemail_option_uuid = $_GET["id"];
	$voicemail_uuid = $_GET["voicemail_uuid"];

//delete the voicemail option
	if (is_uuid($voicemail_option_uuid) && is_uuid($voicemail_uuid)) {
		//build delete array
			$array['voicemail_options'][0]['voicemail_option_uuid'] = $voicemail_option_uuid;
			$array['voicemail_options'][0]['domain_uuid'] = $domain_uuid;
		//execute delete
			$database = new database;
			$database->app_name = 'voicemails';
			$database->app_uuid = 'b523c2d2-64cd-46f1-9520-ca4b4098e044';
			$database->delete($array);
			unset($array);
		//set message
			message::add($text['message-delete']);
		//redirect
			header('Location: voicemail_edit.php?id='.$voicemail_uuid);
			exit;
	}

//default redirect
	header('Location: voicemails.php');

?>