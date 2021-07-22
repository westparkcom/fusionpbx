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
	Portions created by the Initial Developer are Copyright (C) 2008-2020
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	Mark J Crane <markjcrane@fusionpbx.com>
*/

// set included, if not
	if (!isset($included)) { $included = false; }

//check the permission
	if(defined('STDIN')) {
		$document_root = realpath(dirname(__FILE__, 3));
		$_SERVER["DOCUMENT_ROOT"] = $document_root;
		set_include_path($document_root);
		include "root.php";
		include "resources/require.php";
		$hostname = gethostname();
		// Making an assumption here, if you're running this you're using file based cache
		$cacheloc = '/var/cache/fusionpbx/';
		$sql = "select * from v_settings ";
		$database = new database;
		$row = $database->select($sql, null, 'row');
		if (is_array($row) && @sizeof($row) != 0) {
			$event_socket_ip_address = $row["event_socket_ip_address"];
			$event_socket_port = $row["event_socket_port"];
			$event_socket_password = $row["event_socket_password"];
		}
		unset($sql, $row);
		$esl = new event_socket;
		if (!$esl->connect($event_socket_ip_address, $event_socket_port, $event_socket_password)) {
			return false;
		}
		foreach (glob($cacheloc . '*:' . $hostname) as $filename) {
			$cmd = file_get_contents($filename);
			echo $cmd . "\n";
			$esl->request($cmd);
			unlink($filename);
		}
		$esl->close();
	}
