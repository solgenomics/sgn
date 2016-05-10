
//  Pass a js object with the headers and data as key:values, such as: 
//  [ 
//    {"col1":"col1row1value", "height":"12", "age":"900"}, 
//    {"col1":"col1row2value", "height":"1", "age":"9"},
//    {"col1":"col1row3value", "height":"2", "age":"99"}
//  ]
//  
//  as well as a pagination js object, such as:
//  {"currentPage": "2", "pageSize": "200", "totalCount": "999", "totalPages":"5"}
//
//  as well as the id for the div that you want the table to appear on the web page, e.g. "brapi_map_list_table"
//  as well as a return url for processing changing currentPage and pageSize
//  as well as optionally, a link js object, which will be used to construct links in the table. e.g. { "name": ["mapId", "/maps/protocols/"] }


function create_table(data, pagination, div_id, return_url, link) {
    var current_page = pagination.currentPage;
    var next_page = current_page + 1;
    var previous_page = current_page - 1;
    var page_size = pagination.pageSize;
    var total_count = pagination.totalCount;
    var total_pages = pagination.totalPages;
    var html = "";
    if (data.length == 0) {
        html = "<center><h3>No data available!</h3></center>";
    } else {
        html = "<table class='table table-hover table-bordered'><thead><tr>";
        var header = [];
        for(var h in data[0]) {
            if (data[0].hasOwnProperty(h)) {
                if (link) {
                    for(var link_header in link) {
                        if(h != link[link_header][0]) {
                            header.push(h);
                        }
                    }
                } else {
                    header.push(h);
                }
            }
        }
        header.sort();
        for(var col=0; col<header.length; col++){
            html = html+"<th>"+capitalizeEachWord(header[col])+"</th>";
        }
        html = html+"</tr></thead><tbody>";
        for(var row=0; row<data.length; row++) {
            html = html+"<tr>";
            for(var col=0; col<header.length; col++){
                if (link) {
                    for(var link_header in link) {
                        if (header[col] == link_header) {
                            html = html+"<td><a href='"+link[link_header][1]+data[row][link[link_header][0]]+"'>"+data[row][link_header]+"</a></td>";
                        } else {
                            html = html+"<td>"+data[row][header[col]]+"</td>";
                        }
                    }
                } else {
                    html = html+"<td>"+data[row][header[col]]+"</td>";
                }
            }
            html = html+"</tr>";
        }
        html = html+"</tbody></table>";
        
        html = html+"<div class='row'><div class='col-sm-3 col-sm-offset-6'>";
        html = html+"<div class='well well-sm'>";
        html = html+"</div></div></div>";
    }
    jQuery("#"+div_id).html(html);
}

function capitalizeEachWord(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}
