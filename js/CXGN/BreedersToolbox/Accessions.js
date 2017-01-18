/*jslint browser: true, devel: true */
/**

=head1 Accessions.js

Dialogs for managing accessions


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    var list = new CXGN.List();
    var accessionList;
    var doFuzzySearch;
    var validSpecies;

    function disable_ui() {
	//$('#working').dialog("open");
	$('#working_modal').modal("show");
    }

    function enable_ui() {
	//$('#working').dialog("close");
	$('#working_modal').modal("hide");
    }

    jQuery('#manage_accessions_populations_onswitch').click( function() {
      var already_loaded_tables = jQuery('#accordion').find("table");
      if (already_loaded_tables.length > 0) { return; }

      jQuery.ajax ( {
        url : '/ajax/manage_accessions/populations',
        beforeSend: function() {
          disable_ui();
        },
        success: function(response){
          var populations = response.populations;
          for (var i in populations) {
            var name = populations[i].name;
            var accessions = populations[i].members;
            var table_id = name+i+"_pop_table";

            var section_html = '<div class="row"><div class="panel panel-default"><div class="panel-heading" data-toggle="collapse" data-parent="#accordion" data-target="#collapse'+i+'">';
            section_html += '<div class="panel-title"><a href="#'+table_id+'" class="accordion-toggle">'+name+'</a></div></div>';
            section_html += '<div id="collapse'+i+'" class="panel-collapse collapse">';
            section_html += '<div class="panel-body" style="overflow:hidden"><div class="table-responsive" style="margin-top: 10px;"><table id="'+table_id+'" class="table table-hover table-striped table-bordered" width="100%"></table></div>';
            section_html += '</div></div></div></div><br/>';

            jQuery('#accordion').append(section_html);

            jQuery('#'+table_id).DataTable( {
              data: accessions,
              retrieve: false,
              columns: [
                { title: "Accession Name", "data": null, "render": function ( data, type, row ) { return "<a href='/stock/"+row.stock_id+"/view'>"+row.name+"</a>"; } },
                { title: "Description", "data": "description" },
                { title: "Synonyms", "data": "synonyms[, ]" }
              ]
            });

          }
          enable_ui();
        },
        error: function(response) {
          enable_ui();
          alert('An error occured retrieving population data.');
        }
      });
    });

    function add_accessions(accessionsToAdd, speciesName, populationName) {
	var accessionsAsJSON = JSON.stringify(accessionsToAdd);
	$.ajax({
	    type: 'POST',
	    url: '/ajax/accession_list/add',
	    async: false,
	    dataType: "json",
	    timeout: 36000000,
	    data: {
		'accession_list': accessionsAsJSON,
		'species_name': speciesName,
		'population_name': populationName,
	    },
	    beforeSend: function(){
		disable_ui();
            },
	    success: function (response) {
		enable_ui();
		if (response.error) {
		    alert(response.error);
		} else {
		    alert("There were "+accessionsToAdd.length+" accessions added");
		}
	    },
	    error: function () {
		alert('An error occurred in processing. sorry');
	    }
	});
    }

    function verify_species_name() {
	var speciesName = $("#species_name_input").val();
	validSpecies = 0;
	$.ajax({
            type: 'GET',
            url: '/organism/verify_name',
	    dataType: "json",
            data: {
                'species_name': speciesName,
            },
            success: function (response) {
                if (response.error) {
                    alert(response.error);
		    validSpecies = 0;
                } else {
		    validSpecies = 1;
                }
            },
            error: function () {
                alert('An error occurred verifying species name. sorry');
		validSpecies = 0;
            }
	});
    }

    $('#species_name_input').change(function () {
        //verify_species_name();
    });

    $('#review_absent_accessions_submit').click(function () {
	var speciesName = $("#species_name_input").val();
	var populationName = $("#population_name_input").val();
	var accessionsToAdd = accessionList;
	if (!speciesName) {
	    alert("Species name required");
	    return;
	}
	if (!populationName) {
	    populationName = '';
	}
	if (!accessionsToAdd || accessionsToAdd.length == 0) {
	    alert("No accessions to add");
	    return;
	}
	add_accessions(accessionsToAdd, speciesName, populationName);
        $('#review_absent_dialog').modal("hide");
	location.reload();
    });

//    $("#review_absent_dialog").dialog({
//	autoOpen: false,
//	modal: true,
//	autoResize:true,
//        width: 500,
 //       position: ['top', 150],
//	buttons: {
//	    Add: function() {
//		var speciesName = $("#species_name_input").val();
//		var accessionsToAdd = accessionList;
//		if (!speciesName) {
//		    alert("Species name required");
//		    return;
//		}
//		//if (validSpecies == 0){
//		//    return;
//		//}
//		if (!accessionsToAdd || accessionsToAdd.length == 0) {
//		    alert("No accessions to add");
//		    return;
//		}
//		//alert("adding accessionsToAdd.length accessions");
//		add_accessions(accessionsToAdd, speciesName);
//		$(this).dialog( "close" );
//		location.reload();
//	    },
//	    Close: function() {
//		$(this).dialog( "close" );
//	    },
//	}
//    });

    //$("#review_found_matches_dialog").dialog({
//	autoOpen: false,
//	modal: true,
//	autoResize:true,
//        width: 500,
//        position: ['top', 150],
//	buttons: {
//	    Ok: function() {
//		$(this).dialog( "close" );
//	    },
//	}
//    });

//    $("#review_fuzzy_matches_dialog").dialog({
//	autoOpen: false,
//	modal: true,
//	autoResize:true,
//        width: 500,
//        position: ['top', 150],
//	buttons: {
//	    Ok: function() {
//		$(this).dialog( "close" );
//	    },
//	}
//    });

    function review_verification_results(verifyResponse){
	var i;
	var j;

	if (verifyResponse.found) {
	    $('#count_of_found_accessions').html("Total number already in the database("+verifyResponse.found.length+")");
	    var found_html = '<table class="table" id="found_accessions_table"><thead><tr><th>Search Name</th><th>Found in Database</th></tr></thead><tbody>';
	    for( i=0; i < verifyResponse.found.length; i++){
		found_html = found_html
		    +'<tr><td>'+verifyResponse.found[i].matched_string
		    +'</td>';
		    found_html = found_html
			+'<td>'
			+verifyResponse.found[i].unique_name
			+'</td>';
		found_html = found_html
		    +'</tr>';
	    }
	    found_html = found_html
		+'</tbody></table>';

	    $('#view_found_matches').html(found_html);

	    $('#review_found_matches_dialog').modal('show');

	    $('#found_accessions_table').DataTable({});

        accessionList = verifyResponse.absent;

	}

	if (verifyResponse.fuzzy.length > 0 && doFuzzySearch) {
	    var fuzzy_html = '<table class="table"><thead><tr><th>Name in Your List</th><th>Existing Name(s) in Database</th></tr></thead><tbody>';
	    for( i=0; i < verifyResponse.fuzzy.length; i++) {
		fuzzy_html = fuzzy_html + '<tr><td>'+ verifyResponse.fuzzy[i].name + '</td>';
		fuzzy_html = fuzzy_html + '<td><select class="form-control" id ="fuzzyselect'+i+'">';
		for(j=0; j < verifyResponse.fuzzy[i].matches.length; j++){
		    fuzzy_html = fuzzy_html + '<option value="">' + verifyResponse.fuzzy[i].matches[j].name + '</option>';
		}
		fuzzy_html = fuzzy_html + '</select></td></tr>';
	    }
	    fuzzy_html = fuzzy_html + '</tbody></table>';
	    $('#view_fuzzy_matches').html(fuzzy_html);
	    //$('#review_fuzzy_matches_dialog').dialog('open');

	    //Add to absent
	    for( i=0; i < verifyResponse.fuzzy.length; i++) {
		verifyResponse.absent.push(verifyResponse.fuzzy[i].name);
	    }
	    accessionList = verifyResponse.absent;

	}

	if (verifyResponse.absent) {
	    $('#count_of_absent_accessions').html("Total number to be added("+verifyResponse.absent.length+")");
	    var absent_html = '';
	    $("#species_name_input").autocomplete({
		source: '/organism/autocomplete'
	    });
	    for( i=0; i < verifyResponse.absent.length; i++){
		absent_html = absent_html
		    +'<div class="left">'+verifyResponse.absent[i]
		    +'</div>';
	    }
	    $('#view_absent').html(absent_html);
	    //$('#review_absent_dialog').dialog('open');
	}

    jQuery('#review_found_matches_hide').click(function(){
        if (verifyResponse.fuzzy.length > 0 && doFuzzySearch){
            jQuery('#review_fuzzy_matches_dialog').modal('show');
        } else {
            jQuery('#review_fuzzy_matches_dialog').modal('hide');
            jQuery('#review_absent_dialog').modal('show');
        }
    });

    jQuery('#review_fuzzy_matches_open_lists').click(function(){
        jQuery('#review_absent_dialog').modal('hide');
        jQuery("button[name = 'lists_link']").trigger("click");
    });

    jQuery('#review_fuzzy_matches_hide').click(function(){
        jQuery('#review_absent_dialog').modal('show');
    });

    }

    function verify_accession_list() {
	var accession_list_id = $('#accessions_list_select').val();
	var accession_list = JSON.stringify(list.getList(accession_list_id));
	doFuzzySearch = $('#fuzzy_check').attr('checked');
	//alert("should be disabled");
	//alert (doFuzzySearch);
	//alert(accession_list);



	$.ajax({
	    type: 'POST',
	    url: '/ajax/accession_list/verify',
	    timeout: 36000000,
	    //async: false,
	    dataType: "json",
	    data: {
                'accession_list': accession_list,
		'do_fuzzy_search': doFuzzySearch,
	    },
	    beforeSend: function(){
		disable_ui();
            },
            //complete : function(){
	    //enable_ui();
            //},
	    success: function (response) {
		//enable_ui();
		enable_ui();
                if (response.error) {
		    alert(response.error);
                } else {
		    review_verification_results(response);
                }
	    },
	    error: function () {
		//enable_ui();
                alert('An error occurred in processing. sorry');
	    }
        });
    }

    //$( "#add_accessions_dialog" ).dialog({
//	autoOpen: false,
//	modal: true,
//	autoResize:true,
//        width: 500,
//        position: ['top', 150],
//	buttons: {
//	    Ok: function() {
//		//disable_ui();
//		verify_accession_list();
//		$(this).dialog( "close" );
//		//location.reload();
//	    }
//	}
//    });

    $('#new_accessions_submit').click(function () {
	verify_accession_list();
        $('#add_accessions_dialog').modal("hide");
    });

    $('#add_accessions_link').click(function () {
        $('#add_accessions_dialog').modal("show");
	$("#list_div").html(list.listSelect("accessions"));
    });



});
