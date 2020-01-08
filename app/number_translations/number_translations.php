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
	Portions created by the Initial Developer are Copyright (C) 2017-2018
	the Initial Developer. All Rights Reserved.
*/

//includes
	require_once "root.php";
	require_once "resources/require.php";
	require_once "resources/check_auth.php";
	require_once "resources/paging.php";

//check permissions
	if (permission_exists('number_translation_view')) {
		//access granted
	}
	else {
		echo "access denied";
		exit;
	}

//add multi-lingual support
	$language = new text;
	$text = $language->get();

//get posted data
	if (is_array($_POST['number_translations'])) {
		$action = $_POST['action'];
		$search = $_POST['search'];
		$number_translations = $_POST['number_translations'];
	}

//process the http post data by action
	if ($action != '' && is_array($number_translations) && @sizeof($number_translations) != 0) {
		switch ($action) {
			case 'copy':
				if (permission_exists('number_translation_add')) {
					$obj = new number_translations;
					$obj->copy($number_translations);
				}
				break;
			case 'toggle':
				if (permission_exists('number_translation_edit')) {
					$obj = new number_translations;
					$obj->toggle($number_translations);
				}
				break;
			case 'delete':
				if (permission_exists('number_translation_delete')) {
					$obj = new number_translations;
					$obj->delete($number_translations);
				}
				break;
		}

		header('Location: number_translations.php'.($search != '' ? '?search='.urlencode($search) : null));
		exit;
	}

//get order and order by
	$order_by = $_GET["order_by"];
	$order = $_GET["order"];

//add the search term
	$search = strtolower($_GET["search"]);
	if (strlen($search) > 0) {
		$sql_search = "where (";
		$sql_search .= "lower(number_translation_name) like :search ";
		$sql_search .= "or lower(number_translation_enabled) like :search ";
		$sql_search .= "or lower(number_translation_description) like :search ";
		$sql_search .= ") ";
		$parameters['search'] = '%'.$search.'%';
	}

//prepare to page the results
	$sql = "select count(*) from v_number_translations ";
	$sql .= $sql_search;
	$database = new database;
	$num_rows = $database->select($sql, $parameters, 'column');

//prepare to page the results
	$rows_per_page = ($_SESSION['domain']['paging']['numeric'] != '') ? $_SESSION['domain']['paging']['numeric'] : 50;
	$param = "&search=".$search;
	$page = is_numeric($_GET['page']) ? $_GET['page'] : 0;
	list($paging_controls, $rows_per_page) = paging($num_rows, $param, $rows_per_page);
	list($paging_controls_mini, $rows_per_page) = paging($num_rows, $param, $rows_per_page, true);
	$offset = $rows_per_page * $page;

//get the list
	$sql = str_replace('count(*)', '*', $sql);
	$sql .= order_by($order_by, $order, 'number_translation_name', 'asc');
	$sql .= limit_offset($rows_per_page, $offset);
	$database = new database;
	$number_translations = $database->select($sql, $parameters, 'all');
	unset($sql, $parameters);

//create token
	$object = new token;
	$token = $object->create($_SERVER['PHP_SELF']);

//additional includes
	$document['title'] = $text['title-number_translations'];
	require_once "resources/header.php";

//show the content
	echo "<div class='action_bar' id='action_bar'>\n";
	echo "	<div class='heading'><b>".$text['title-number_translations']." (".$num_rows.")</b></div>\n";
	echo "	<div class='actions'>\n";
	if (permission_exists('number_translation_add')) {
		echo button::create(['type'=>'button','label'=>$text['button-add'],'icon'=>$_SESSION['theme']['button_icon_add'],'link'=>'number_translation_edit.php']);
	}
	if (permission_exists('number_translation_add') && $number_translations) {
		echo button::create(['type'=>'button','label'=>$text['button-copy'],'icon'=>$_SESSION['theme']['button_icon_copy'],'onclick'=>"if (confirm('".$text['confirm-copy']."')) { list_action_set('copy'); list_form_submit('form_list'); } else { this.blur(); return false; }"]);
	}
	if (permission_exists('number_translation_edit') && $number_translations) {
		echo button::create(['type'=>'button','label'=>$text['button-toggle'],'icon'=>$_SESSION['theme']['button_icon_toggle'],'onclick'=>"if (confirm('".$text['confirm-toggle']."')) { list_action_set('toggle'); list_form_submit('form_list'); } else { this.blur(); return false; }"]);
	}
	if (permission_exists('number_translation_delete') && $number_translations) {
		echo button::create(['type'=>'button','label'=>$text['button-delete'],'icon'=>$_SESSION['theme']['button_icon_delete'],'onclick'=>"if (confirm('".$text['confirm-delete']."')) { list_action_set('delete'); list_form_submit('form_list'); } else { this.blur(); return false; }"]);
	}
	echo 		"<form id='form_search' class='inline' method='get'>\n";
	echo 		"<input type='text' class='txt list-search' name='search' id='search' value=\"".escape($search)."\" placeholder=\"".$text['label-search']."\" onkeydown='list_search_reset();'>";
	echo button::create(['label'=>$text['button-search'],'icon'=>$_SESSION['theme']['button_icon_search'],'type'=>'submit','id'=>'btn_search','style'=>($search != '' ? 'display: none;' : null)]);
	echo button::create(['label'=>$text['button-reset'],'icon'=>$_SESSION['theme']['button_icon_reset'],'type'=>'button','id'=>'btn_reset','link'=>'number_translations.php','style'=>($search == '' ? 'display: none;' : null)]);
	if ($paging_controls_mini != '') {
		echo 	"<span style='margin-left: 15px;'>".$paging_controls_mini."</span>";
	}
	echo "		</form>\n";
	echo "	</div>\n";
	echo "	<div style='clear: both;'></div>\n";
	echo "</div>\n";

	echo $text['title_description-number_translation']."\n";
	echo "<br /><br />\n";

	echo "<form id='form_list' method='post'>\n";
	echo "<input type='hidden' id='action' name='action' value=''>\n";
	echo "<input type='hidden' name='search' value=\"".escape($search)."\">\n";

	echo "<table class='list'>\n";
	echo "<tr class='list-header'>\n";
	if (permission_exists('number_translation_add') || permission_exists('number_translation_edit') || permission_exists('number_translation_delete')) {
		echo "	<th class='checkbox'>\n";
		echo "		<input type='checkbox' id='checkbox_all' name='checkbox_all' onclick='list_all_toggle();' ".($number_translations ?: "style='visibility: hidden;'").">\n";
		echo "	</th>\n";
	}
	echo th_order_by('number_translation_name', $text['label-number_translation_name'], $order_by, $order);
	echo th_order_by('number_translation_enabled', $text['label-number_translation_enabled'], $order_by, $order, null, "class='center'");
	echo th_order_by('number_translation_description', $text['label-number_translation_description'], $order_by, $order, null, "class='hide-sm-dn'  style='min-width: 50%;'");
	if (permission_exists('number_translation_edit') && $_SESSION['theme']['list_row_edit_button']['boolean'] == 'true') {
		echo "	<td class='action-button'>&nbsp;</td>\n";
	}
	echo "</tr>\n";

	if (is_array($number_translations) && @sizeof($number_translations) != 0) {
		$x = 0;
		foreach ($number_translations as $row) {
			if (permission_exists('number_translation_edit')) {
				$list_row_url = "number_translation_edit.php?id=".urlencode($row['number_translation_uuid']);
			}
			echo "<tr class='list-row' href='".$list_row_url."'>\n";
			if (permission_exists('number_translation_add') || permission_exists('number_translation_edit') || permission_exists('number_translation_delete')) {
				echo "	<td class='checkbox'>\n";
				echo "		<input type='checkbox' name='number_translations[$x][checked]' id='checkbox_".$x."' value='true' onclick=\"if (!this.checked) { document.getElementById('checkbox_all').checked = false; }\">\n";
				echo "		<input type='hidden' name='number_translations[$x][uuid]' value='".escape($row['number_translation_uuid'])."' />\n";
				echo "	</td>\n";
			}
			echo "	<td>";
			if (permission_exists('number_translation_edit')) {
				echo "<a href='".$list_row_url."' title=\"".$text['button-edit']."\">".escape($row['number_translation_name'])."</a>";
			}
			else {
				echo escape($row['number_translation_name']);
			}
			echo "	</td>\n";
			if (permission_exists('number_translation_edit')) {
				echo "	<td class='no-link center'>";
				echo button::create(['type'=>'submit','class'=>'link','label'=>$text['label-'.$row['number_translation_enabled']],'title'=>$text['button-toggle'],'onclick'=>"list_self_check('checkbox_".$x."'); list_action_set('toggle'); list_form_submit('form_list')"]);
			}
			else {
				echo "	<td class='center'>";
				echo $text['label-'.$row['number_translation_enabled']];
			}
			echo "	</td>\n";
			echo "	<td class='description overflow hide-sm-dn'>".escape($row['number_translation_description'])."&nbsp;</td>\n";
			if (permission_exists('number_translation_edit') && $_SESSION['theme']['list_row_edit_button']['boolean'] == 'true') {
				echo "	<td class='action-button'>";
				echo button::create(['type'=>'button','title'=>$text['button-edit'],'icon'=>$_SESSION['theme']['button_icon_edit'],'link'=>$list_row_url]);
				echo "	</td>\n";
			}
			echo "</tr>\n";
			$x++;
		}
	}
	unset($number_translations, $row);

	echo "</table>\n";
	echo "<br />\n";
	echo "<div align='center'>".$paging_controls."</div>\n";

	echo "<input type='hidden' name='".$token['name']."' value='".$token['hash']."'>\n";

	echo "</form>\n";

//include the footer
	require_once "resources/footer.php";

?>