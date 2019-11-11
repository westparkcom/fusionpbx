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
	Portions created by the Initial Developer are Copyright (C) 2008-2019
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	Mark J Crane <markjcrane@fusionpbx.com>
*/
require_once "root.php";
require_once "resources/require.php";
require_once "resources/check_auth.php";
if (permission_exists('voicemail_add') || permission_exists('voicemail_edit')) {
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
		$voicemail_escalation_uuid = $_REQUEST["id"];
	}

//get the menu id
	if (is_uuid($_GET["voicemail_uuid"])) {
		$voicemail_uuid = $_GET["voicemail_uuid"];
	}

//get the http post variables and set them to php variables
	if (count($_POST)>0) {
		$voicemail_uuid = $_POST["voicemail_uuid"];
		$voicemail_escalation_phonenum = $_POST["voicemail_escalation_phonenum"];
		$voicemail_escalation_delay = $_POST["voicemail_escalation_delay"];
		$voicemail_escalation_order = $_POST["voicemail_escalation_order"];
		$voicemail_escalation_description = $_POST["voicemail_escalation_description"];
	}

if (count($_POST)>0 && strlen($_POST["persistformvar"]) == 0) {

	$msg = '';
	$voicemail_escalation_uuid = $_POST["voicemail_escalation_uuid"];

	//validate the token
		$token = new token;
		if (!$token->validate($_SERVER['PHP_SELF'])) {
			message::add($text['message-invalid_token'],'negative');
			header('Location: voicemails.php');
			exit;
		}

	//check for all required data
		error_log("Len of phonenum: " . strlen($voicemail_escalation_phonenum . "\n");
		error_log("Len of order: " . strlen($voicemail_escalation_order . "\n");
		error_log("Len of delay: " . strlen($voicemail_escalation_delay . "\n");
		if (strlen($voicemail_escalation_phonenum) == 0) { $msg .= $text['message-required'].$text['label-option']."<br>\n"; }
		if (strlen($voicemail_escalation_delay) == 0) { $msg .= $text['message-required'].$text['label-option']."<br>\n"; }
		if (strlen($voicemail_escalation_order) == 0) { $msg .= $text['message-required'].$text['label-order']."<br>\n"; }
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

	//update the database
		if ($_POST["persistformvar"] != "true" && permission_exists('voicemail_edit')) {
			//build update array
				$array['voicemail_escalations'][0]['voicemail_escalation_uuid'] = $voicemail_escalation_uuid;
				$array['voicemail_escalations'][0]['domain_uuid'] = $domain_uuid;
				$array['voicemail_escalations'][0]['voicemail_escalation_phonenum'] = $voicemail_escalation_phonenum;
				$array['voicemail_escalations'][0]['voicemail_escalation_delay'] = $voicemail_escalation_delay;
				$array['voicemail_escalations'][0]['voicemail_escalation_order'] = $voicemail_escalation_order;
				$array['voicemail_escalations'][0]['voicemail_escalation_description'] = $voicemail_escalation_description;
			//grant temporary permissions
				$p = new permissions;
				$p->add('voicemail_escalation_edit', 'temp');
			//execute update
				$database = new database;
				$database->app_name = 'voicemails';
				$database->app_uuid = 'c613c2e4-54bf-26a1-9321-de4c4097e054';
				$database->save($array);
				unset($array);
			//revoke temporary permissions
				$p->delete('voicemail_escalation_edit', 'temp');
			//set message
				message::add($text['message-update']);
			//redirect the user
				header('Location: voicemail_edit.php?id='.$voicemail_uuid);
				exit;
		}
}

//pre-populate the form
	if (count($_GET)>0 && $_POST["persistformvar"] != "true") {
		$voicemail_option_uuid = $_GET["id"];
		$sql = "select * from v_voicemail_escalations ";
		$sql .= "where voicemail_escalation_uuid = :voicemail_escalation_uuid ";
		$sql .= "and domain_uuid = :domain_uuid ";
		$parameters['voicemail_escalation_uuid'] = $voicemail_escalation_uuid;
		$parameters['domain_uuid'] = $domain_uuid;
		$database = new database;
		$row = $database->select($sql, $parameters, 'row');
		if (is_array($row) && @sizeof($row) != 0) {
			$domain_uuid = $row["domain_uuid"];
			$voicemail_uuid = $row["voicemail_uuid"];
			$voicemail_escalation_phonenum = trim($row["voicemail_escalation_phonenum"]);
			$voicemail_escalation_delay = $row["voicemail_escalation_delay"];
			$voicemail_escalation_order = $row["voicemail_escalation_order"];
			$voicemail_escalation_description = $row["voicemail_escalation_description"];
		}
		unset($sql, $parameters, $row);
	}

//create token
	$object = new token;
	$token = $object->create($_SERVER['PHP_SELF']);

//send the content to the browser
	require_once "resources/header.php";
	$document['title'] = $text['title-voicemail_escalation'];

	echo "<form method='post' name='frm' action=''>\n";
	echo "<table width='100%' border='0' cellpadding='0' cellspacing='0'>\n";

	echo "<tr>\n";
	echo "<td align='left' width='30%' align='left' valign='top'>";
	echo "	<b>".$text['header-voicemail_escalation']."</b>";
	echo "	<br><br>";
	echo "</td>\n";
	echo "<td width='70%' align='right' nowrap='nowrap' valign='top'>";
	echo "	<input type='button' class='btn' name='' alt='".$text['button-back']."' onclick=\"window.location='voicemail_edit.php?id=".escape($voicemail_uuid)."'\" value='".$text['button-back']."'>";
	echo "	<input type='submit' name='submit' class='btn' value='".$text['button-save']."'>\n";
	echo "</td>\n";
	echo "</tr>\n";

	echo "<tr>\n";
	echo "<td class='vncellreq' valign='top' align='left' nowrap>\n";
	echo "	".$text['label-destination']."\n";
	echo "</td>\n";
	echo "<td class='vtable' align='left'>\n";
	echo "  <input class='formfld' type='text' name='voicemail_escalation_phonenum' maxlength='255' value='".escape($voicemail_escalation_phonenum)."'>\n";
	echo "<br />\n";
	echo $text['description-option']."\n";
	echo "</td>\n";
	echo "</tr>\n";

	echo "<tr>\n";
	echo "<td class='vncellreq' valign='top' align='left' nowrap>\n";
	echo "	".$text['label-delay']."\n";
	echo "</td>\n";
	echo "<td class='vtable' align='left'>\n";
	echo "  <input class='formfld' type='text' name='voicemail_escalation_delay' maxlength='4' pattern='\d+' value='".escape($voicemail_escalation_delay)."'>\n";
	echo "<br />\n";
	echo $text['description-option']."\n";
	echo "</td>\n";
	echo "</tr>\n";

	echo "<tr>\n";
	echo "<td class='vncellreq' valign='top' align='left' nowrap>\n";
	echo "	".$text['label-order']."\n";
	echo "</td>\n";
	echo "<td class='vtable' align='left'>\n";
	echo "	<select name='voicemail_escalation_order' class='formfld'>\n";
	$i = 0;
	while ($i <= 999) {
		$selected = ($voicemail_escalation_order == $i) ? "selected" : null;
		if (strlen($i) == 1) {
			echo "	<option value='00$i' ".$selected.">00$i</option>\n";
		}
		if (strlen($i) == 2) {
			echo "	<option value='0$i' ".$selected.">0$i</option>\n";
		}
		if (strlen($i) == 3) {
			echo "	<option value='$i' ".$selected.">$i</option>\n";
		}
		$i++;
	}
	echo "	</select>\n";
	echo "<br />\n";
	echo $text['description-order']."\n";
	echo "</td>\n";
	echo "</tr>\n";

	echo "<tr>\n";
	echo "<td class='vncell' valign='top' align='left' nowrap>\n";
	echo "	".$text['label-description']."\n";
	echo "</td>\n";
	echo "<td class='vtable' align='left'>\n";
	echo "	<input class='formfld' type='text' name='voicemail_escalation_description' maxlength='255' value=\"".escape($voicemail_escalation_description)."\">\n";
	echo "<br />\n";
	echo $text['description-description']."\n";
	echo "</td>\n";
	echo "</tr>\n";
	echo "	<tr>\n";
	echo "		<td colspan='2' align='right'>\n";
	echo "			<input type='hidden' name='voicemail_uuid' value='".escape($voicemail_uuid)."'>\n";
	echo "			<input type='hidden' name='voicemail_escalation_uuid' value='".escape($voicemail_escalation_uuid)."'>\n";
	echo "			<input type='hidden' name='".$token['name']."' value='".$token['hash']."'>\n";
	echo "			<br>";
	echo "			<input type='submit' name='submit' class='btn' value='".$text['button-save']."'>\n";
	echo "		</td>\n";
	echo "	</tr>";

	echo "</table>\n";
	echo "</form>\n";

//include the footer
	require_once "resources/footer.php";

?>