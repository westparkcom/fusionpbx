<?php

/**
 * call broadcast class
 *
 * @method null download
 */
if (!class_exists('call_broadcast')) {
	class call_broadcast {

		/**
		 * declare private variables
		 */
		private $app_name;
		private $app_uuid;
		private $permission_prefix;
		private $list_page;
		private $table;
		private $uuid_prefix;

		/**
		 * called when the object is created
		 */
		public function __construct() {

			//assign private variables
				$this->app_name = 'call_broadcast';
				$this->app_uuid = 'efc11f6b-ed73-9955-4d4d-3a1bed75a056';
				$this->permission_prefix = 'call_broadcast_';
				$this->list_page = 'call_broadcast.php';
				$this->table = 'call_broadcasts';
				$this->uuid_prefix = 'call_broadcast_';

		}

		/**
		 * called when there are no references to a particular object
		 * unset the variables used in the class
		 */
		public function __destruct() {
			foreach ($this as $key => $value) {
				unset($this->$key);
			}
		}

		/**
		 * delete records
		 */
		public function delete($records) {
			if (permission_exists($this->permission_prefix.'delete')) {

				//add multi-lingual support
					$language = new text;
					$text = $language->get();

				//validate the token
					$token = new token;
					if (!$token->validate($_SERVER['PHP_SELF'])) {
						message::add($text['message-invalid_token'],'negative');
						header('Location: '.$this->list_page);
						exit;
					}

				//delete multiple records
					if (is_array($records) && @sizeof($records) != 0) {

						//build the delete array
							foreach($records as $x => $record) {
								if ($record['checked'] == 'true' && is_uuid($record['uuid'])) {
									$array[$this->table][$x][$this->uuid_prefix.'uuid'] = $record['uuid'];
									$array[$this->table][$x]['domain_uuid'] = $_SESSION['domain_uuid'];
								}
							}

						//delete the checked rows
							if (is_array($array) && @sizeof($array) != 0) {

								//execute delete
									$database = new database;
									$database->app_name = $this->app_name;
									$database->app_uuid = $this->app_uuid;
									$database->delete($array);
									unset($array);

								//set message
									message::add($text['message-delete']);
							}
							unset($records);
					}
			}
		}

		/**
		 * copy records
		 */
		public function copy($records) {
			if (permission_exists($this->permission_prefix.'add')) {

				//add multi-lingual support
					$language = new text;
					$text = $language->get();

				//validate the token
					$token = new token;
					if (!$token->validate($_SERVER['PHP_SELF'])) {
						message::add($text['message-invalid_token'],'negative');
						header('Location: '.$this->list_page);
						exit;
					}

				//copy the checked records
					if (is_array($records) && @sizeof($records) != 0) {

						//get checked records
							foreach($records as $x => $record) {
								if ($record['checked'] == 'true' && is_uuid($record['uuid'])) {
									$record_uuids[] = $this->uuid_prefix."uuid = '".$record['uuid']."'";
								}
							}

						//create insert array from existing data
							if (is_array($record_uuids) && @sizeof($record_uuids) != 0) {
								$sql = "select * from v_".$this->table." ";
								$sql .= "where (domain_uuid = :domain_uuid or domain_uuid is null) ";
								$sql .= "and ( ".implode(' or ', $record_uuids)." ) ";
								$parameters['domain_uuid'] = $_SESSION['domain_uuid'];
								$database = new database;
								$rows = $database->select($sql, $parameters, 'all');
								if (is_array($rows) && @sizeof($rows) != 0) {
									foreach ($rows as $x => $row) {
										$new_uuid = uuid();
										$array[$this->table][$x][$this->uuid_prefix.'uuid'] = $new_uuid;
										$array[$this->table][$x]['domain_uuid'] = $row['domain_uuid'];
										$array[$this->table][$x]['broadcast_name'] = $row['broadcast_name'];
										$array[$this->table][$x]['broadcast_description'] = trim($row['broadcast_description'].' ('.$text['label-copy'].')');
										$array[$this->table][$x]['broadcast_timeout'] = $row['broadcast_timeout'];
										$array[$this->table][$x]['broadcast_concurrent_limit'] = $row['broadcast_concurrent_limit'];
										$array[$this->table][$x]['recording_uuid'] = $row['recording_uuid'];
										$array[$this->table][$x]['broadcast_caller_id_name'] = $row['broadcast_caller_id_name'];
										$array[$this->table][$x]['broadcast_caller_id_number'] = $row['broadcast_caller_id_number'];
										$array[$this->table][$x]['broadcast_destination_type'] = $row['broadcast_destination_type'];
										$array[$this->table][$x]['broadcast_phone_numbers'] = $row['broadcast_phone_numbers'];
										$array[$this->table][$x]['broadcast_avmd'] = $row['broadcast_avmd'];
										$array[$this->table][$x]['broadcast_destination_data'] = $row['broadcast_destination_data'];
										$array[$this->table][$x]['broadcast_accountcode'] = $row['broadcast_accountcode'];
									}
								}
								unset($sql, $parameters, $rows, $row);
							}

						//save the changes and set the message
							if (is_array($array) && @sizeof($array) != 0) {

								//save the array
									$database = new database;
									$database->app_name = $this->app_name;
									$database->app_uuid = $this->app_uuid;
									$database->save($array);
									unset($array);

								//set message
									message::add($text['message-copy']);

							}
							unset($records);
					}

			}
		}

	}
}

?>