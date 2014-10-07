

function display_results(headers, results, page_number, page_size, total_results) { 

    var html = 'Total matches: <b>'+total_results + '</b>  Total pages: <b>'+ Math.floor((total_results / page_size)+1) + '</b>' ;
    html += '<table  alt="search results" cellpadding="4" >';

    html += '<tr>';
    for(var n=0; n<headers.length; n++) { 
	html += '<td>'+headers[n]+'</td>';
    }
    html += '</tr>';
    for(var n=0; n<results.length; n++) { 
	html += '<tr>';

	for(var i=0; i<results[n].length; i++) { 
	    html += '<td>'+results[n][i]+'</td>';
	}
	html += '</tr>';
    }
    html += '</table>';
    return html;
}
