

function display_results(headers, results, page_number, page_size, total_results) { 

    var html = '<table id="results_table" class="display" cellspacing="0" width="100%" >';

    html += '<thead><tr>';
    for(var n=0; n<headers.length; n++) { 
	html += '<th>'+headers[n]+'</th>';
    }
    html += '</tr></thead><tbody>';
    for(var n=0; n<results.length; n++) { 
	html += '<tr>';

	for(var i=0; i<results[n].length; i++) { 
	    html += '<td>'+results[n][i]+'</td>';
	}
	html += '</td><td></td></tr>';
    }
    html += '</tbody></table>';
    alert(html);
    return html;
}
