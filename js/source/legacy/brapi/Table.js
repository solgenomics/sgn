
//  This is for displaying brapi non-paginated responses in a table format.
//
//  Pass a js object with the headers and data as key:values, such as: 
//    {
//        "col1":"col1row1value",
//        "height":"12",
//        "age":"900"
//    }
//
//  as well as the id for the div that you want the table to appear on the web page, e.g. "brapi_map_list_table"
//  as well as optionally, a link js object, which will be used to construct links in the table. e.g. { "name": ["mapId", "/maps/protocols/"] }

function brapi_create_table(data, div_id, link) {
    console.log(data);
    console.log(div_id);
    console.log(link);
    var html = "<table class='table table-hover table-bordered'><thead><tr>";
    var header = [];
    for(var h in data) {
        if (data.hasOwnProperty(h)) {
            if (checkDefined(link) == 0) {
                header.push(h);
            } else {
                for(var link_header in link) {
                    if(h != link[link_header][0]) {
                        header.push(h);
                    }
                }
            }
        }
    }
    //console.log(header);
    header.sort();
    for(var col=0; col<header.length; col++){
        html = html+"<th>"+capitalizeEachWord(header[col])+"</th>";
    }
    html = html+"</tr></thead><tbody>";
    html = html+"<tr>";
    for(var col=0; col<header.length; col++){
        if (checkDefined(link) == 0) {
            html = html+"<td>"+data[header[col]]+"</td>";
        } else {
            for(var link_header in link) {
                if (header[col] == link_header) {
                    if (link[link_header][1] == 'stock') {
                        html = html+"<td><a href='/"+link[link_header][1]+"/"+data[link[link_header][0]]+"/view'>"+data[link_header]+"</a></td>";
                    } else {
                        html = html+"<td><a href='/"+link[link_header][1]+"/"+data[link[link_header][0]]+"'>"+data[link_header]+"</a></td>";
                    }
                } else {
                    html = html+"<td>"+data[header[col]]+"</td>";
                }
            }
        }
    }
    html = html+"</tr>";
    html = html+"</tbody></table>";
    jQuery("#"+div_id).html(html);
}


//  This is for displaying brapi paginated responses in a table format. The brapi response should be paginated over response.result.data and pagination info should be in response.metadata.pagination
//
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
//  as well as the search query data so that the query can be run on next page, prev page, etc
//  as well as a list of column names you want to display_columns
//  as well as the column name that should be the value of the select BreedersToolbox
//  as well as a list of column names that can be added as data-attributes to the select box

function brapi_create_paginated_table(data, pagination, div_id, return_url, link, search_query_data, display_columns, select_column, select_data) {
    console.log(data);
    console.log(pagination);
    //console.log(div_id);
    //console.log(return_url);
    //console.log(link);
    //console.log(display_columns);
    var current_page = pagination.currentPage;
    var next_page = Number(current_page) + 1;
    var previous_page = Number(current_page) - 1;
    var page_size = pagination.pageSize;
    var total_count = pagination.totalCount;
    var total_pages = pagination.totalPages;
    var url = jQuery("#table_return_url_input").val() ? jQuery("#table_return_url_input").val() : 'This Database';
    var html = "<input id='table_div_id_input' type='hidden' value='"+div_id+"'/>";
    var html = html+"<input id='table_return_url_input' type='hidden' value='"+return_url+"'/>";
    if (checkDefined(link) == 1) {
        var html = html+"<input id='table_links_input' type='hidden' value='"+JSON.stringify(link)+"'/>";
    } else {
        var html = html+"<input id='table_links_input' type='hidden' value='"+link+"'/>";
    }
    var html = html+"<input id='table_page_size_input' type='hidden' value='"+page_size+"'/>";
    var html = html+"<input id='table_next_page_input' type='hidden' value='"+next_page+"'/>";
    var html = html+"<input id='table_previous_page_input' type='hidden' value='"+previous_page+"'/>";
    var html = html+"<input id='table_checkbox_select_column' type='hidden' value='"+select_column+"'/>";
    var html = html+"<input id='table_search_query_params' type='hidden' value='"+JSON.stringify(search_query_data)+"'/>";
    var html = html+"<input id='table_display_columns_params' type='hidden' value='"+JSON.stringify(display_columns)+"'/>";
    var html = html+"<input id='table_display_select_data_param' type='hidden' value='"+JSON.stringify(select_data)+"'/>";
    if (data.length == 0) {
        html = html+"<center><h3>No data available!</h3></center>";
    } else {
        html = html+"<h3>Results From "+url+"</h3><table class='table table-hover table-bordered'><thead><tr><th>Select</th>";
        var header = [];
        for(var h in data[0]) {
            if (data[0].hasOwnProperty(h)) {
                //console.log(h);
                if (jQuery.inArray(h, display_columns) != -1){
                    if (checkDefined(link) == 0) {
                        header.push(h);
                    } else {
                        for(var link_header in link) {
                            if(h != link[link_header][0]) {
                                header.push(h);
                            }
                        }
                    }
                }
            }
        }
        header.sort();
        for(var col=0; col<header.length; col++){
            html = html+"<th>"+capitalizeEachWord(header[col])+"</th>";
        }
        html = html+"</tr></thead><tbody>";
        for(var row=0; row<data.length; row++) {
            html = html+"<tr><td><input type='checkbox' name='brapi_table_select_"+return_url+"' value='"+data[row][select_column]+"'";
            for (var s_data=0; s_data<select_data.length; s_data++){
                html = html + " data-"+select_data[s_data]+"='"+data[row][select_data[s_data]]+"'";
            }
            html = html + "/></td>";
            for(var col=0; col<header.length; col++){
                if (checkDefined(link) == 0) {
                    var v = data[row][header[col]];
                    if (typeof v === 'object'){
                        v = JSON.stringify(v);
                    }
                    html = html+"<td>"+v+"</td>";
                } else {
                    for(var link_header in link) {
                        if (header[col] == link_header) {
                            if (link[link_header][1] == 'stock') {
                                html = html+"<td><a href='"+link[link_header][1]+"/"+data[row][link[link_header][0]]+"/view'>"+data[row][link_header]+"</a></td>";
                            } else {
                                html = html+"<td><a href='"+data[row][link[link_header][0]]+"'>"+data[row][link_header]+"</a></td>";
                            }
                        } else {
                            var v = data[row][header[col]];
                            if (typeof v === 'object'){
                                v = JSON.stringify(v);
                            }
                            html = html+"<td>"+v+"</td>";
                        }
                    }
                }
            }
            html = html+"</tr>";
        }
        html = html+"</tbody></table>";
        
        html = html+"<div class='well well-sm'><div class='row'>";
        html = html+"<div class='col-sm-7'><div class='row'><div class='col-sm-2'><button class='btn btn-primary' id='brapi_table_select_submit_"+div_id+"' >Select</button></div><div class='col-sm-7 col-md-5'><div class='btn-group' role='group'>";
        
        if (total_pages > 1) {
            if (current_page > 0) {
                html = html+"<button id='table_previous_page_button' class='btn btn-sm btn-default glyphicon glyphicon-arrow-left'></button><button class='btn btn-sm btn-default' style='margin-top:1px'>Page "+current_page+" of "+total_pages+"</button><button id='table_next_page_button' class='btn btn-sm btn-default glyphicon glyphicon-arrow-right'></button>";
            } else {
                html = html+"<button class='disabled btn btn-sm btn-default glyphicon glyphicon-arrow-left'></button><button class='btn btn-sm btn-default' style='margin-top:1px'>Page "+current_page+" of "+total_pages+"</button><button id='table_next_page_button' class='btn btn-sm btn-default glyphicon glyphicon-arrow-right'></button>";
            }
        } else {
            html = html+"<button class='disabled btn btn-sm btn-default glyphicon glyphicon-arrow-left'></button><button class='btn btn-sm btn-default' style='margin-top:1px'>Page "+current_page+" of "+total_pages+"</button><button id='table_next_page_button' class='disabled btn btn-sm btn-default glyphicon glyphicon-arrow-right'></button>";
        }
        html = html+"</div></div><div class='col-sm-3 col-md-5'><div class='input-group input-group-sm'><span class='input-group-addon' id='basic-addon1'>Page:</span><input type='text' id='table_change_current_page_input' class='form-control' placeholder='"+current_page+"' aria-describedby='basic-addon1'></div></div></div></div>";
        html = html+"<div class='col-sm-5'><div class='row'><div class='col-sm-7'><div class='input-group input-group-sm'><span class='input-group-addon' id='basic-addon2'>Page Size:</span><input type='text' id='table_change_page_size_input' class='form-control' placeholder='"+page_size+"' aria-describedby='basic-addon2'></div></div><div class='col-sm-5'><button class='btn btn-sm btn-default'>Total: "+total_count+"</button></div></div></div></div>";
        html = html+"</div>";
    }
    jQuery("#"+div_id).html(html);
}

function capitalizeEachWord(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

function checkDefined(o) {
    if (typeof o === 'undefined' || o === null || o === 'undefined') {
        return 0;
    } else {
        return 1;
    }
}

function brapi_recreate_paginated_table(search_query_data, display_columns, select_column, select_data){
    var delay = (function(){
        var timer = 0;
        return function(callback, ms){
            clearTimeout (timer);
            timer = setTimeout(callback, ms);
        };
    })();

    delay(function() {
        jQuery.ajax( {
            url: jQuery("#table_return_url_input").val(),
            dataType: 'json',
            data: search_query_data,
            method:'POST',
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            success: function(response) {
                jQuery("#working_modal").modal("hide");
                //console.log(response);
                var div_id = jQuery("#table_div_id_input").val();
                var return_url = jQuery("#table_return_url_input").val();
                if (checkDefined(jQuery("#table_links_input").val()) == 1) {
                    var links = jQuery.parseJSON( jQuery("#table_links_input").val() );
                } else {
                    var links = jQuery("#table_links_input").val();
                }
                jQuery("#"+jQuery("#table_div_id_input").val()).empty();
                console.log(search_query_data);
                brapi_create_paginated_table(response.result.data, response.metadata.pagination, div_id, return_url, links, search_query_data, display_columns, select_column, select_data);
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred constructing table after moving to the previous page.');
            }
        });
    }, 200);
}

jQuery(document).ready(function () {
    
    jQuery(document).on( 'click', "#table_next_page_button", function() {
        var search_query_data = JSON.parse(jQuery('#table_search_query_params').val());
        var display_columns = JSON.parse(jQuery('#table_display_columns_params').val());
        var select_data = JSON.parse(jQuery('#table_display_select_data_param').val());
        var select_column = jQuery('#table_checkbox_select_column').val();
        search_query_data['page'] = jQuery("#table_next_page_input").val();
        search_query_data['pageSize'] = jQuery("#table_page_size_input").val();
        brapi_recreate_paginated_table(search_query_data, display_columns, select_column, select_data);
    });
    
    jQuery(document).on( 'click', "#table_previous_page_button", function() {
        var search_query_data = JSON.parse(jQuery('#table_search_query_params').val());
        var display_columns = JSON.parse(jQuery('#table_display_columns_params').val());
        var select_data = JSON.parse(jQuery('#table_display_select_data_param').val());
        var select_column = jQuery('#table_checkbox_select_column').val();
        search_query_data['page'] = jQuery("#table_previous_page_input").val();
        search_query_data['pageSize'] = jQuery("#table_page_size_input").val();
        brapi_recreate_paginated_table(search_query_data, display_columns, select_column, select_data);
    });
    
    jQuery(document).on( 'keyup', "#table_change_page_size_input", function() {
        var search_query_data = JSON.parse(jQuery('#table_search_query_params').val());
        var display_columns = JSON.parse(jQuery('#table_display_columns_params').val());
        var select_data = JSON.parse(jQuery('#table_display_select_data_param').val());
        var select_column = jQuery('#table_checkbox_select_column').val();
        search_query_data['page'] = 0;
        search_query_data['pageSize'] = jQuery("#table_change_page_size_input").val();
        brapi_recreate_paginated_table(search_query_data, display_columns, select_column, select_data);
    });
    
    jQuery(document).on( 'keyup', "#table_change_current_page_input", function() {
        var search_query_data = JSON.parse(jQuery('#table_search_query_params').val());
        var display_columns = JSON.parse(jQuery('#table_display_columns_params').val());
        var select_data = JSON.parse(jQuery('#table_display_select_data_param').val());
        var select_column = jQuery('#table_checkbox_select_column').val();
        search_query_data['page'] = jQuery("#table_change_current_page_input").val();
        brapi_recreate_paginated_table(search_query_data, display_columns, select_column, select_data);
    });

});
