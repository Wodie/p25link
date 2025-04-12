<?php

# use one of these methods to access arsed's state file:
$State_location = "/var/www/html/p25link/LastHeard_Out.json";

function fetch_state()
{
	global $State_location;

	if (substr($State_location, 0, 1) == '/') {
		$json = file_get_contents($State_location);
	} else {
		// create a new cURL resource
		$ch = curl_init();
		
		// set URL and other appropriate options
		curl_setopt($ch, CURLOPT_URL, $State_location);
		curl_setopt($ch, CURLOPT_HEADER, 0);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
		
		// grab URL and pass it to the browser
		$json = curl_exec($ch);
		
		// close cURL resource, and free up system resources
		curl_close($ch);
	}
	
	return json_decode($json, true);
}

function duration_str($s) {
	if ($s < 0) {
		$str = "-";
		$s *= -1;
	} else {
		$str = "";
	}
	
	$origs = $s;
	
	if ($s < 1) {
		$str .= "0s";
		return $str;
	}
	
	if ($s >= 24 * 60 * 60) {
		$d = floor($s / (24 * 60 * 60));
		$s -= $d * 24 * 60 * 60;
		$str .= $d . 'd ';
	}
	
	if ($s >= 60 * 60) {
		$d = floor($s / (60 * 60));
		$s -= $d * 60 * 60;
		$str .= $d . "h";
	}
	
	if ($s >= 60) {
		$d = floor($s / 60);
		$s -= $d * 60;
		$str .= $d . "m";
	}
	
	if ($s >= 1) {
		if ($origs < 60*60)
			$str .= floor($s) . "s";
	}
	
	return $str;
}


function logtime($tstamp)
{
	return gmstrftime('%Y-%m-%d %T', $tstamp);
}

function lastheard_sort($a, $b)
{
	if ($a['LastHeard'] == $b['LastHeard'])
		return 0;

	return ($a['LastHeard'] > $b['LastHeard']) ? -1 : 1;
}



## Main ########################################################################

if ($_GET['u']) {
	#error_log("state update");

	header('Content-Type: application/json; charset=utf-8');
	
	$j = array(); # returned json

	$state = fetch_state();
	$reg = $state['registry'];

	$j['at'] = "at " . logtime($state['time']) . " UTC";# - uptime "
		#. duration_str($state['uptime']);
	$j['radios'] = "";//Showing all known P25.Link Talk Groups only. The last $state[NumberOfRecords] online.";

	$here = array();
	$away = array();
	foreach ($reg as $SourceRadioID => $radio) {
		if ($radio['state'] == 'here')
			array_push($here, $radio);
		else
			array_push($away, $radio);
	}

	uasort($here, 'lastheard_sort');
	uasort($away, 'lastheard_sort');

/*	$s = "<table>\n" . "<tr>
		<th>Last Heard</th>
		<th>Talk Group</th>
		<th>Radio ID</th>
		<th>Callsign</th>
		<th>First Name</th>
		<th>Duration</th>
		<th>Country</th>
		<th>State</th>
		<th>City</th>
		<th>Remote Host IP</th>
		</tr>\n";
*/

	$s = "<table>\n" . "<tr>
		<th>Last Heard</th>
		<th>Talk Group</th>
		<th>Radio ID</th>
		<th>Duration</th>
		</tr>\n";


	$shown = 0;
	foreach ($here as $radio) {
		$shown++;
/*		$s .= "<tr class='pnx'>
			<td>" . logtime($radio['LastHeard']) . "</td>
			<td>" . $radio['AstroTalkGroup'] . "</td>
			<td>" . $radio['SourceRadioID'] . "</td>
			<td><a href='http://aprs.fi/?call=$radio[Callsign]' target='_blank'>" . $radio['Callsign'] . "</a></td>
			<td>" . $radio['FName'] . "</td>
			<td>" . $radio['Duration'] . "</td>
			<td>" . $radio['Country'] . "</td>
			<td>" . $radio['State'] . "</td>
			<td>" . $radio['City'] . "</td>
			<td>" . $radio['RemoteHostIP'] . "</td>
			</tr>\n";
	}
*/
		$s .= "<tr class='pnx'>
			<td>" . logtime($radio['LastHeard']) . "</td>
			<td>" . $radio['AstroTalkGroup'] . "</td>
			<td>" . $radio['SourceRadioID'] . "</td>
			<td>" . $radio['Duration'] . "</td>
			</tr>\n";
	}

	$s .= "<tr class='separator'><td> </td><td> </td><td> </td><td> </td><td> </td></tr>\n";

	foreach ($away as $radio) {
		if (!$radio['LastHeard'])
			continue;
		$shown++;
		if ($radio['RemoteHostIP'] == "MMDVM Reflector" ) {
			 $s .= "<tr class='away'>
				<td>" . logtime($radio['LastHeard']) . "</td>
				<td>" . $radio['AstroTalkGroup'] . "</td>
				<td>" . $radio['SourceRadioID'] . "</td>
				<td>" . $radio['Duration'] . "</td>
				</tr>\n";
		} else {
			$s .= "<tr class='here'>
				<td>" . logtime($radio['LastHeard']) . "</td>
				<td>" . $radio['AstroTalkGroup'] . "</td>
				<td>" . $radio['SourceRadioID'] . "</td>
				<td>" . $radio['Duration'] . "</td>
				</tr>\n";
		}
	}

	$s .= "</table>\n";

	$j['table'] = $s;

	$unshown = $state['$NumberOfRecords'] - $shown;
//	$j['unshown'] = ($unshown) ? "Not showing $unshown configured radios which have never registered." : "";
	
	print json_encode($j);
	
	return;
} else {
	print_body();
}


function print_body()
{

print '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "https://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="https://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xml:lang="%language%" lang="%language%">
<head>
<title>P25Link Local Dashboard</title>
<link rel="stylesheet" type="text/css" href="style.css" />
</head>

<body>
<img src="P25Link_Logo_Small_Blue.jpg" alt="P25.Link">
<script type="text/JavaScript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.5.1/jquery.min.js"></script>
<div class="title" id="title">P25Link Local Dashboard <span id="at"></span></div>



<div class="radios" id="radios">Initializing ...</div>
<div class="table" id="table"></div>
<div class="unshown" id="unshown"></div>

<div class="footer">P25Link Local Dashboard Service - Created by Juan Carlos Perez.</div>

<script type="text/JavaScript">

function repl(id, data, cb)
{
	// bla coment char is like C++
	$(id).html(data);
	cb();
}
function refresh()
{
	$.ajax({
		url: "?u=1",
		cache: false,
		dataType: "json",
		success: function(data) {
			$("#at").html(data.at);
			repl("#radios", data.radios, function() {
				repl("#table", data.table, function(){
					repl("#unshown", data.unshown, function(){});
				});
			});
			
			setTimeout(function() { refresh(); }, 1000);
		},
		error: function() {
			setTimeout(function() { refresh(); }, 10000);
		}
	});
}
refresh();

</script>
</body>
</html>
';

}


?>
