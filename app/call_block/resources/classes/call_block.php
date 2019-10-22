<?php

/**
 * call block class
 *
 * @method null download
 */
if (!class_exists('call_block')) {
	class call_block {

		/**
		 * declare private variables
		 */
		private $app_name;
		private $app_uuid;
		private $permission_prefix;
		private $list_page;
		private $table;
		private $uuid_prefix;
		private $enabled_prefix;

		/**
		 * called when the object is created
		 */
		public function __construct() {

			//assign private variables
				$this->app_name = 'call_block';
				$this->app_uuid = '9ed63276-e085-4897-839c-4f2e36d92d6c';
				$this->permission_prefix = 'call_block_';
				$this->list_page = 'call_block.php';
				$this->table = 'call_block';
				$this->uuid_prefix = 'call_block_';
				$this->enabled_prefix = 'call_block_';

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
		 * toggle records
		 */
		public function toggle($records) {
			if (permission_exists($this->permission_prefix.'edit')) {

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

				//toggle the checked records
					if (is_array($records) && @sizeof($records) != 0) {

						//get current enabled state
							foreach($records as $x => $record) {
								if ($record['checked'] == 'true' && is_uuid($record['uuid'])) {
									$record_uuids[] = $this->uuid_prefix."uuid = '".$record['uuid']."'";
								}
							}
							if (is_array($record_uuids) && @sizeof($record_uuids) != 0) {
								$sql = "select ".$this->uuid_prefix."uuid as uuid, ".$this->enabled_prefix."enabled as enabled from v_".$this->table." ";
								$sql .= "where (domain_uuid = :domain_uuid or domain_uuid is null) ";
								$sql .= "and ( ".implode(' or ', $record_uuids)." ) ";
								$parameters['domain_uuid'] = $_SESSION['domain_uuid'];
								$database = new database;
								$rows = $database->select($sql, $parameters, 'all');
								if (is_array($rows) && @sizeof($rows) != 0) {
									foreach ($rows as $row) {
										$states[$row['uuid']] = $row['enabled'];
									}
								}
								unset($sql, $parameters, $rows, $row);
							}

						//build update array
							$x = 0;
							foreach($states as $uuid => $state) {
								$array[$this->table][$x][$this->uuid_prefix.'uuid'] = $uuid;
								$array[$this->table][$x][$this->enabled_prefix.'enabled'] = $state == 'true' ? 'false' : 'true';
								$x++;
							}

						//save the changes
							if (is_array($array) && @sizeof($array) != 0) {

								//save the array
									$database = new database;
									$database->app_name = $this->app_name;
									$database->app_uuid = $this->app_uuid;
									$database->save($array);
									unset($array);

								//set message
									message::add($text['message-toggle']);
							}
							unset($records, $states);
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
										$array[$this->table][$x]['call_block_name'] = $row['call_block_name'];
										$array[$this->table][$x]['call_block_number'] = $row['call_block_number'];
										$array[$this->table][$x]['call_block_count'] = 0;
										$array[$this->table][$x]['call_block_action'] = $row['call_block_action'];
										$array[$this->table][$x]['date_added'] = $row['date_added'];
										$array[$this->table][$x]['call_block_enabled'] = $row['call_block_enabled'];
										$array[$this->table][$x]['call_block_description'] = trim($row['call_block_description'].' ('.$text['label-copy'].')');
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