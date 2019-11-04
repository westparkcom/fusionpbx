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
	Portions created by the Initial Developer are Copyright (C) 2016
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	Mark J Crane <markjcrane@fusionpbx.com>
*/

//includes
	require_once "root.php";
	require_once "resources/require.php";

//check permissions
	require_once "resources/check_auth.php";
	if (permission_exists('ibr_pilot_add') || permission_exists('ibr_pilot_edit')) {
		//access granted
	}
	else {
		echo "access denied";
		exit;
	}

//add multi-lingual support
	$language = new text;
	$text = $language->get();

//action add or update
	if (is_uuid($_REQUEST["id"])) {
		$action = "update";
		$ibr_pilot_uuid = $_REQUEST["id"];
	}
	else {
		$action = "add";
	}

//get http post variables and set them to php variables
	if (count($_POST)>0) {
		$ibr_pilot = $_POST["ibr_pilot"];
		$ibr_pilot_json = $_POST["ibr_pilot_json"];
		$enabled = $_POST["enabled"];
		$description = $_POST["description"];
	}

if (count($_POST)>0 && strlen($_POST["persistformvar"]) == 0) {

	$msg = '';
	if ($action == "update") {
		$ibr_pilot_uuid = $_POST["ibr_pilot_uuid"];
	}

	//validate the token
		$token = new token;
		if (!$token->validate($_SERVER['PHP_SELF'])) {
			message::add($text['message-invalid_token'],'negative');
			header('Location: ibr_pilots.php');
			exit;
		}

	//check for all required data
		if (strlen($ibr_pilot) == 0) { $msg .= $text['message-required']." ".$text['label-ibr_pilot']."<br>\n"; }
		//if (strlen($accountcode) == 0) { $msg .= $text['message-required']." ".$text['label-accountcode']."<br>\n"; }
		if (strlen($enabled) == 0) { $msg .= $text['message-required']." ".$text['label-enabled']."<br>\n"; }
		//if (strlen($description) == 0) { $msg .= $text['message-required']." ".$text['label-description']."<br>\n"; }
		if (strlen($msg) > 0 && strlen($_POST["persistformvar"]) == 0) {
			require_once "resources/header.php";
			require_once "resources/persist_form_var.php";
			echo "<div align='center'>\n";
			echo "<table><tr><td>\n";
			echo $msg."<br />";
			echo "</td></tr></table>\n";
			persistformvar($_POST);
			echo "</div>\n";
			require_once "resources/footer.php";
			return;
		}

	//add or update the database
		if ($_POST["persistformvar"] != "true") {
			if ($action == "add" && permission_exists('ibr_pilot_add')) {
				//begin array
					$ibr_pilot_uuid = uuid();
					$array['ibr_pilots'][0]['ibr_pilot_uuid'] = $ibr_pilot_uuid;
				//set message
					message::add($text['message-add']);
			}

			if ($action == "update" && permission_exists('ibr_pilot_edit')) {
				//begin array
					$array['ibr_pilots'][0]['ibr_pilot_uuid'] = $ibr_pilot_uuid;
				//set message
					message::add($text['message-update']);
			}

			if (is_array($array) && @sizeof($array) != 0) {
				//add common array items
					$array['ibr_pilots'][0]['domain_uuid'] = $domain_uuid;
					$array['ibr_pilots'][0]['ibr_pilot'] = $ibr_pilot;
					$array['ibr_pilots'][0]['ibr_pilot_json'] = $ibr_pilot_json;
					$array['ibr_pilots'][0]['enabled'] = $enabled;
					$array['ibr_pilots'][0]['description'] = $description;
				//save data
					$database = new database;
					$database->app_name = 'ibr_pilots';
					$database->app_uuid = '4b88ccfe-cb98-30b1-a5f5-32389e14a348';
					$database->save($array);
					unset($array);
				//redirect
					header("Location: ibr_pilots.php");
					exit;
			}
		}

}

//pre-populate the form
	if (count($_GET) > 0 && $_POST["persistformvar"] != "true") {
		$ibr_pilot_uuid = $_GET["id"];
		$sql = "select * from v_ibr_pilots ";
		$sql .= "where domain_uuid = :domain_uuid ";
		$sql .= "and ibr_pilot_uuid = :ibr_pilot_uuid ";
		$parameters['domain_uuid'] = $domain_uuid;
		$parameters['ibr_pilot_uuid'] = $ibr_pilot_uuid;
		$database = new database;
		$row = $database->select($sql, $parameters, 'row');
		if (is_array($row) && @sizeof($row) != 0) {
			$ibr_pilot = $row["ibr_pilot"];
			$ibr_pilot_json = $row["ibr_pilot_json"];
			$enabled = $row["enabled"];
			$description = $row["description"];
		}
		unset($sql, $parameters, $row);
	}

//create token
	$object = new token;
	$token = $object->create($_SERVER['PHP_SELF']);

//show the header
	require_once "resources/header.php";

//show the content
	echo "<form name='frm' id='frm' method='post' action=''>\n";
	echo "<table width='100%'  border='0' cellpadding='0' cellspacing='0'>\n";
	echo "<tr>\n";
	echo "<td align='left' width='30%' nowrap='nowrap' valign='top'><b>".$text['title-ibr_pilot']."</b><br><br></td>\n";
	echo "<td width='70%' align='right' valign='top'>\n";
	echo "	<input type='button' class='btn' name='' alt='".$text['button-back']."' onclick=\"window.location='ibr_pilots.php'\" value='".$text['button-back']."'>";
	echo "	<input type='submit' name='submit' class='btn' value='".$text['button-save']."'>";
	echo "</td>\n";
	echo "</tr>\n";

	echo "<tr>\n";
	echo "<td class='vncellreq' valign='top' align='left' nowrap='nowrap'>\n";
	echo "	".$text['label-ibr_pilots']."\n";
	echo "</td>\n";
	echo "<td class='vtable' align='left'>\n";
	echo "	<input class='formfld' type='text' name='ibr_pilot' maxlength='255' value=\"".escape($ibr_pilot)."\">\n";
	echo "<br />\n";
	echo $text['description-ibr_pilots']."\n";
	echo "</td>\n";
	echo "</tr>\n";

	echo "<tr>\n";
	echo "<td class='vncellreq' valign='top' align='left' nowrap='nowrap'>\n";
	echo "	".$text['label-ibr_pilots_json']."\n";
	echo "</td>\n";
	echo "<td class='vtable' align='left'>\n";
	echo "	<textarea class='formfld' style='width: 500px; height: 500px;' name='ibr_pilot_json' >".$ibr_pilot_json."</textarea>\n";
	echo "<br />\n";
	echo $text['description-ibr_pilots_json']."\n";
	echo "</td>\n";
	echo "</tr>\n";

	echo "<tr>\n";
	echo "<td class='vncellreq' valign='top' align='left' nowrap='nowrap'>\n";
	echo "	".$text['label-enabled']."\n";
	echo "</td>\n";
	echo "<td class='vtable' align='left'>\n";
	echo "	<select class='formfld' name='enabled'>\n";
	if ($enabled == "true") {
		echo "	<option value='true' selected='selected'>".$text['label-true']."</option>\n";
	}
	else {
		echo "	<option value='true'>".$text['label-true']."</option>\n";
	}
	if ($enabled == "false") {
		echo "	<option value='false' selected='selected'>".$text['label-false']."</option>\n";
	}
	else {
		echo "	<option value='false'>".$text['label-false']."</option>\n";
	}
	echo "	</select>\n";
	echo "<br />\n";
	echo $text['description-enabled']."\n";
	echo "</td>\n";
	echo "</tr>\n";

	echo "<tr>\n";
	echo "<td class='vncell' valign='top' align='left' nowrap='nowrap'>\n";
	echo "	".$text['label-description']."\n";
	echo "</td>\n";
	echo "<td class='vtable' align='left'>\n";
	echo "	<textarea class='formfld' style='width: 450px; height: 175px;' name='description' >".escape($description)."</textarea>\n";
	echo "<br />\n";
	echo $text['description-description']."\n";
	echo "</td>\n";
	echo "</tr>\n";
	echo "	<tr>\n";
	echo "		<td colspan='2' align='right'>\n";
	if ($action == "update") {
		echo "				<input type='hidden' name='ibr_pilot_uuid' value='".escape($ibr_pilot_uuid)."'>\n";
	}
	echo "			<input type='hidden' name='".$token['name']."' value='".$token['hash']."'>\n";
	echo "			<input type='submit' name='submit' class='btn' value='".$text['button-save']."'>\n";
	echo "		</td>\n";
	echo "	</tr>";
	echo "</table>";
	echo "</form>";
	echo "<br /><br />";

//include the footer
	require_once "resources/footer.php";

?>
