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


function create_table(data, pagination, div_id, return_url, link) {
    console.log(data);
    console.log(pagination);
    console.log(div_id);
    console.log(return_url);
    console.log(link);
    var current_page = pagination.currentPage;
    var next_page = current_page + 1;
    var previous_page = current_page - 1;
    var page_size = pagination.pageSize;
    var total_count = pagination.totalCount;
    var total_pages = pagination.totalPages;
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
    if (data.length == 0) {
        html = html+"<center><h3>No data available!</h3></center>";
    } else {
        html = html+"<table class='table table-hover table-bordered'><thead><tr>";
        var header = [];
        for(var h in data[0]) {
            if (data[0].hasOwnProperty(h)) {
                //console.log(h);
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
        header.sort();
        for(var col=0; col<header.length; col++){
            html = html+"<th>"+capitalizeEachWord(header[col])+"</th>";
        }
        html = html+"</tr></thead><tbody>";
        for(var row=0; row<data.length; row++) {
            html = html+"<tr>";
            for(var col=0; col<header.length; col++){
                if (checkDefined(link) == 0) {
                    html = html+"<td>"+data[row][header[col]]+"</td>";
                } else {
                    for(var link_header in link) {
                        if (header[col] == link_header) {
                            html = html+"<td><a href='"+link[link_header][1]+data[row][link[link_header][0]]+"'>"+data[row][link_header]+"</a></td>";
                        } else {
                            html = html+"<td>"+data[row][header[col]]+"</td>";
                        }
                    }
                }
            }
            html = html+"</tr>";
        }
        html = html+"</tbody></table>";
        
        html = html+"<div class='well well-sm'><div class='row'>";
        html = html+"<div class='col-sm-6'><div class='row'><div class='col-sm-7'><div class='btn-group' role='group'>";
        
        if (total_pages > 1) {
            if (current_page > 1) {
                html = html+"<button id='table_previous_page_button' class='btn btn-sm btn-default glyphicon glyphicon-arrow-left'></button><button class='btn btn-sm btn-default' style='margin-top:1px'>Page "+current_page+" of "+total_pages+"</button><button id='table_next_page_button' class='btn btn-sm btn-default glyphicon glyphicon-arrow-right'></button>";
            } else {
                html = html+"<button class='disabled btn btn-sm btn-default glyphicon glyphicon-arrow-left'></button><button class='btn btn-sm btn-default' style='margin-top:1px'>Page "+current_page+" of "+total_pages+"</button><button id='table_next_page_button' class='btn btn-sm btn-default glyphicon glyphicon-arrow-right'></button>";
            }
        } else {
            html = html+"<button class='disabled btn btn-sm btn-default glyphicon glyphicon-arrow-left'></button><button class='btn btn-sm btn-default' style='margin-top:1px'>Page "+current_page+" of "+total_pages+"</button><button id='table_next_page_button' class='disabled btn btn-sm btn-default glyphicon glyphicon-arrow-right'></button>";
        }
        html = html+"</div></div><div class='col-sm-5'><div class='input-group input-group-sm'><span class='input-group-addon' id='basic-addon1'>Page:</span><input type='text' id='table_change_current_page_input' class='form-control' placeholder='"+current_page+"' aria-describedby='basic-addon1'></div></div></div></div>";
        html = html+"<div class='col-sm-6'><div class='row'><div class='col-sm-7'><div class='input-group input-group-sm'><span class='input-group-addon' id='basic-addon2'>Page Size:</span><input type='text' id='table_change_page_size_input' class='form-control' placeholder='"+page_size+"' aria-describedby='basic-addon2'></div></div><div class='col-sm-5'><button class='btn btn-sm btn-default'>Total: "+total_count+"</button></div></div></div></div>";
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

jQuery(document).ready(function () {
    
    jQuery(document).on( 'click', "#table_next_page_button", function() {
        jQuery.ajax( {
            url: jQuery("#table_return_url_input").val()+"?currentPage="+jQuery("#table_next_page_input").val()+"&pageSize="+jQuery("#table_page_size_input").val(),
            dataType: 'json',
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
                create_table(response.result.data, response.metadata.pagination, div_id, return_url, links);
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred constructing table after moving to the next page.');
            }
        });
    });
    
    jQuery(document).on( 'click', "#table_previous_page_button", function() {
        jQuery.ajax( {
            url: jQuery("#table_return_url_input").val()+"?currentPage="+jQuery("#table_previous_page_input").val()+"&pageSize="+jQuery("#table_page_size_input").val(),
            dataType: 'json',
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
                create_table(response.result.data, response.metadata.pagination, div_id, return_url, links);
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred constructing table after moving to the previous page.');
            }
        });
    });
    
    jQuery(document).on( 'keyup', "#table_change_page_size_input", function() {
        delay(function() {
            jQuery.ajax( {
                url: jQuery("#table_return_url_input").val()+"?currentPage="+jQuery("#table_previous_page_input").val()+"&pageSize="+jQuery("#table_change_page_size_input").val(),
                dataType: 'json',
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
                    create_table(response.result.data, response.metadata.pagination, div_id, return_url, links);
                },
                error: function(response) {
                    jQuery("#working_modal").modal("hide");
                    alert('An error occurred constructing table after moving to the previous page.');
                }
            });
        }, 800);
    });
    
    jQuery(document).on( 'keyup', "#table_change_current_page_input", function() {
        delay(function() {
            jQuery.ajax( {
                url: jQuery("#table_return_url_input").val()+"?currentPage="+jQuery("#table_change_current_page_input").val()+"&pageSize="+jQuery("#table_page_size_input").val(),
                dataType: 'json',
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
                    create_table(response.result.data, response.metadata.pagination, div_id, return_url, links);
                },
                error: function(response) {
                    jQuery("#working_modal").modal("hide");
                    alert('An error occurred constructing table after moving to the previous page.');
                }
            });
        }, 800);
    });
    
    var delay = (function(){
        var timer = 0;
        return function(callback, ms){
            clearTimeout (timer);
            timer = setTimeout(callback, ms);
        };
    })();
    
});
