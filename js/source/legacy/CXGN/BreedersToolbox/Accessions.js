/*jslint browser: true, devel: true */
/**

=head1 Accessions.js

Dialogs for managing accessions


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();
var list = new CXGN.List();
var accessionList;
var accession_list_id;
var validSpecies;
var fuzzyResponse;
var fullParsedData;
var infoToAdd;
var accessionListFound;
var speciesNames;
var doFuzzySearch;

function disable_ui() {
    jQuery('#working_modal').modal("show");
}

function enable_ui() {
    jQuery('#working_modal').modal("hide");
}

jQuery(document).ready(function ($) {

    jQuery('#manage_accessions_populations_new').click(function(){
        jQuery("#create_population_list_div").html(list.listSelect("create_population_list_div", ["accessions"], undefined, undefined, undefined ));
        jQuery('#manage_populations_add_population_dialog').modal('show');
    });

    jQuery("#create_population_submit").click(function(){
        jQuery.ajax({
            type: 'POST',
            url: '/ajax/population/new',
            dataType: "json",
            data: {
                'population_name': jQuery('#create_population_name').val(),
                'accession_list_id': jQuery('#create_population_list_div_list_select').val(),
            },
            beforeSend: function(){
                disable_ui();
            },
            success: function (response) {
                enable_ui();
                if (response.error){
                    alert(response.error);
                }
                if (response.success){
                    alert(response.success);
                }
            },
            error: function (r) {
                alert('An error occurred in adding population. sorry '+r.responseText);
            }
        });
    });

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
            var population_id = populations[i].stock_id;
            var accessions = populations[i].members;
            var table_id = name+i+"_pop_table";

            var section_html = '<div class="row"><div class="panel panel-default"><div class="panel-heading" >';
            section_html += '<div class="panel-title" name="populations_members_table_toggle" data-table_id="#'+table_id+'" data-population_id="'+population_id+'" data-population_name="'+name+'"><div class="row"><div class="col-sm-6" data-toggle="collapse" data-parent="#accordion" data-target="#collapse'+i+'"><a href="#'+table_id+'" class="accordion-toggle">'+name+'</a></div><div class="col-sm-3"><a href="/stock/'+population_id+'/view"><small>[Go To Population Page]</small></a></div><div class="col-sm-3"><a name="manage_populations_add_accessions" data-population_id="'+population_id+'" data-population_name="'+name+'"><small>[Add Accessions To Population]</small></a><br/><a name="manage_populations_delete_population" data-population_id="'+population_id+'" data-population_name="'+name+'"><small>[Delete Population]</small></a></div></div></div></div>';
            section_html += '<div id="collapse'+i+'" class="panel-collapse collapse">';
            section_html += '<div class="panel-body" style="overflow:hidden"><div class="table-responsive" style="margin-top: 10px;"><table id="'+table_id+'" class="table table-hover table-striped table-bordered" width="100%"></table><div id="populations_members_add_to_list_data_'+population_id+'" style="display:none"></div><br/><div id="populations_members_add_to_list_menu_'+population_id+'"></div></div>';
            section_html += '</div><br/></div></div></div><br/>';

            jQuery('#accordion').append(section_html);
          }
          enable_ui();
        },
        error: function(response) {
          enable_ui();
          alert('An error occured retrieving population data.');
        }
      });
    });

    jQuery(document).on("click", "div[name='populations_members_table_toggle']", function(){
        var table_id = jQuery(this).data('table_id');
        var population_id = jQuery(this).data('population_id');
        var population_name = jQuery(this).data('population_name');

        var table = jQuery(table_id).DataTable({
            ajax: '/ajax/manage_accessions/population_members/'+population_id,
            destroy: true,
            columns: [
                { title: "Accession Name", "data": null, "render": function ( data, type, row ) { return "<a href='/stock/"+row.stock_id+"/view'>"+row.name+"</a>"; } },
                { title: "Description", "data": "description" },
                { title: "Synonyms", "data": "synonyms[, ]" },
                { title: "Remove From Population", "data": null, "render": function ( data, type, row ) { return "<a name='populations_member_remove' data-stock_relationship_id='"+row.stock_relationship_id+"'>X</a>"; } },
            ],
            "fnInitComplete": function(oSettings, json) {
                //console.log(json);
                var html = "";
                for(var i=0; i<json.data.length; i++){
                    html += json.data[i].name+"\n";
                }
                jQuery("#populations_members_add_to_list_data_"+population_id).html(html);
                addToListMenu("populations_members_add_to_list_menu_"+population_id, "populations_members_add_to_list_data_"+population_id, {
                    selectText: true,
                    listType: 'accessions',
                    listName: population_name
                });
            }
        });

    });

    var population_id;
    var population_name;

    jQuery(document).on("click", "a[name='manage_populations_add_accessions']", function(){
        population_id = jQuery(this).data('population_id');
        population_name = jQuery(this).data('population_name');
        jQuery("#add_accession_to_population_list_div").html(list.listSelect("add_accession_to_population_list_div", ["accessions"], undefined, undefined, undefined));
        jQuery('#add_accession_population_name').html(population_name);
        jQuery('#manage_populations_add_accessions_dialog').modal('show');
    });

    jQuery(document).on("click", "a[name='manage_populations_delete_population']", function(){
        population_id = jQuery(this).data('population_id');
        population_name = jQuery(this).data('population_name');
        jQuery('#delete_population_name').html(population_name);
        jQuery('#manage_populations_delete_dialog').modal('show');
    });

    jQuery('#organization_name_input').autocomplete({
       source: '/ajax/stock/stockproperty_autocomplete?property=organization',
    });

    jQuery('#population_name_input').autocomplete({
       source: '/ajax/stock/population_autocomplete',
    });

    jQuery("#add_accessions_to_population_submit").click(function(){
        jQuery.ajax({
            type: 'POST',
            url: '/ajax/population/add_accessions',
            dataType: "json",
            data: {
                'population_name': population_name,
                'accession_list_id': jQuery('#add_accession_to_population_list_div_list_select').val(),
            },
            beforeSend: function(){
                disable_ui();
            },
            success: function (response) {
                enable_ui();
                if (response.error){
                    alert(response.error);
                }
                if (response.success){
                    alert(response.success);
                }
            },
            error: function () {
                alert('An error occurred in adding accessions to population. sorry');
            }
        });
    });

    jQuery("#delete_population_submit").click(function(){
        jQuery.ajax({
            type: 'POST',
            url: '/ajax/population/delete',
            dataType: "json",
            data: {
                'population_id': population_id,
                'population_name': population_name,
            },
            beforeSend: function(){
                disable_ui();
            },
            success: function (response) {
                enable_ui();
                if (response.error){
                    alert(response.error);
                }
                if (response.success){
                    alert(response.success);
                }
            },
            error: function () {
                alert('An error occurred in deleting population. sorry');
            }
        });
    });

    jQuery(document).on("click", "a[name='populations_member_remove']", function(){
        var stock_relationship_id= jQuery(this).data("stock_relationship_id");
        if (confirm("Are you sure?")){
            jQuery.ajax({
                url: '/ajax/population/remove_member?stock_relationship_id='+stock_relationship_id,
                dataType: "json",
                beforeSend: function(){
                    disable_ui();
                },
                success: function (response) {
                    enable_ui();
                    if (response.error){
                        alert(response.error);
                    }
                    if (response.success){
                        alert(response.success);
                    }
                },
                error: function () {
                    alert('An error occurred in removing accession from population. sorry');
                }
            });
        }
    });

    function add_accessions(full_info, species_names) {
        console.log(full_info);
        $.ajax({
            type: 'POST',
            url: '/ajax/accession_list/add',
            dataType: "json",
            timeout: 36000000,
            data: {
                'full_info': JSON.stringify(full_info),
                'allowed_organisms': JSON.stringify(species_names),
            },
            beforeSend: function(){
                disable_ui();
            },
            success: function (response) {
                enable_ui();
		//alert("ADD ACCESSIONS: "+JSON.stringify(response));
                if (response.error) {
                    alert(response.error);
                } else {
                    var html = 'The following stocks were added!<br/>';
                    for (var i=0; i<response.added.length; i++){
                        html = html + '<a href="/stock/'+response.added[i][0]+'/view">'+response.added[i][1]+'</a><br/>';
                    }
                    jQuery('#add_accessions_saved_message').html(html);
                    jQuery('#add_accessions_saved_message_modal').modal('show');
                }
            },
            error: function (response) {
                alert('An error occurred in processing. sorry'+response.responseText);
            }
        });
    }

    function verify_species_name() {
        var speciesName = $("#species_name_input").val();
        validSpecies = 0;
        return $.ajax({
            type: 'GET',
            url: '/organism/verify_name',
            dataType: "json",
            data: {
                'species_name': speciesName,
            },
            // success: function (response) {
            //     if (response.error) {
            //         alert(response.error);
            //         validSpecies = 0;
            //     } else {
            //         validSpecies = 1;
            //     }
            // },
            // error: function (response) {
            //     alert('An error occurred verifying species name. sorry'+response.responseText);
            //     validSpecies = 0;
            // }
        });
    }

    $('#species_name_input').focusout(function () {
        verify_species_name().then( function(r) { if (r.error) { alert(r.error); } }, function(r) { alert('An error occurred. The site may not be available right now.'); });
    });

    $('#review_absent_accessions_submit').click(function () {
        if (fullParsedData == undefined){
            var speciesName = $("#species_name_input").val();
            var populationName = $("#population_name_input").val();
            var organizationName = $("#organization_name_input").val();
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

	    verify_species_name().then(
		function(r) {
		    if (r.error) { alert('Please correct the species name and try again.'); }
		    else {
			for(var i=0; i<accessionsToAdd.length; i++){
			    infoToAdd.push({
				'species':speciesName,
				'defaultDisplayName':accessionsToAdd[i],
				'germplasmName':accessionsToAdd[i],
				'organizationName':organizationName,
				'populationName':populationName,
			    });
			    speciesNames.push(speciesName);
			}
			add_accessions(infoToAdd, speciesNames)
			$('#review_absent_dialog').modal("hide");
		    }
		},
		function(r) {
		    alert('ERROR! Try again later.');
		}
	    );
	}

        //window.location.href='/breeders/accessions';
    });

    $('#new_accessions_submit').click(function () {
        var selected_tab = jQuery('#add_new_accessions_tab_select .active').text()
        if (selected_tab == 'Using Lists'){
            accession_list_id = $('#list_div_list_select').val();
            fullParsedData = undefined;
	    verify_accession_list(accession_list_id); 
        } else if (selected_tab == 'Uploading a File'){
	    var uploadFile = jQuery("#new_accessions_upload_file").val();
	    jQuery('#upload_new_accessions_form').attr("action", "/ajax/accessions/verify_accessions_file");
	    if (uploadFile === '') {
                alert("Please select a file");
                return;
	    }
	    
	    jQuery("#upload_new_accessions_form").submit();
        }
	$('#add_accessions_dialog').modal("hide");
    });

    jQuery('#upload_new_accessions_form').iframePostForm({
        json: false,
        post: function () {
            var uploadedSeedlotFile = jQuery("#new_accessions_upload_file").val();
            jQuery('#working_modal').modal("show");
            if (uploadedSeedlotFile === '') {
                jQuery('#working_modal').modal("hide");
            }
        },
        complete: function (r) {
	    //alert("DONE WITH UPLOAD "+r);
	    var clean_r = r.replace('<pre>', '');
	    clean_r = clean_r.replace('</pre>', '');
	    response = JSON.parse(clean_r); //decodeURIComponent(clean_r));
            console.log(response);
            jQuery('#working_modal').modal("hide");

            if (response.error || response.error_string) {
                fullParsedData = undefined;
                alert(response.error || response.error_string);
            }
            else if (response.success) {
                fullParsedData = response.full_data;
                doFuzzySearch = jQuery('#fuzzy_check_upload_accessions').attr('checked');;
                review_verification_results(doFuzzySearch, response, response.list_id);
            }
            else {
                fullParsedData = undefined;
                alert("An unknown error occurred.  Please try again later or contact us for help.");
            }
        }
    });

    $('[name="add_accessions_link"]').click(function () {
        var list = new CXGN.List();
        accessionList;
        accession_list_id;
        validSpecies;
        fuzzyResponse;
        fullParsedData;
        infoToAdd;
        accessionListFound;
        speciesNames;
        doFuzzySearch;
        $('#add_accessions_dialog').modal("show");
        $('#review_found_matches_dialog').modal("hide");
        $('#review_fuzzy_matches_dialog').modal("hide");
        $('#review_absent_dialog').modal("hide");
        $("#list_div").html(list.listSelect("list_div", ["accessions"], undefined, undefined, undefined));
    });

    jQuery('#accessions_upload_spreadsheet_format_info').click(function(){
        jQuery('#accessions_upload_spreadsheet_format_modal').modal("show");
    });

    $('body').on('hidden.bs.modal', '.modal', function () {
        $(this).removeData('bs.modal');
    });

	$(document).on('change', 'select[name="fuzzy_option"]', function() {
		var value = $(this).val();
		if ($('#add_accession_fuzzy_option_all').is(":checked")){
			$('select[name="fuzzy_option"] option[value='+value+']').attr('selected','selected');
		}
	});

    $('#review_fuzzy_matches_download').click(function(){
        console.log(fuzzyResponse);
        openWindowWithPost(JSON.stringify(fuzzyResponse));
        //window.open('/ajax/accession_list/fuzzy_download?fuzzy_response='+JSON.stringify(fuzzyResponse));
    });

    jQuery('#review_absent_dialog').on('shown.bs.modal', function (e) {
        jQuery('#infoToAdd_updated_table').DataTable({});
        jQuery('#infoToAdd_new_table').DataTable({});
    });

});

function openWindowWithPost(fuzzyResponse) {
    var f = document.getElementById('add_accession_fuzzy_match_download');
    f.fuzzy_response.value = fuzzyResponse;
    window.open('', 'TheWindow');
    f.submit();
}

function verify_accession_list(accession_list_id) {
    accession_list = JSON.stringify(list.getList(accession_list_id));
    doFuzzySearch = jQuery('#fuzzy_check').attr('checked');
    
    jQuery.ajax({
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
        success: function (response) {
            enable_ui();
            if (response.error) {
                alert(response.error);
            }
            review_verification_results(doFuzzySearch, response, accession_list_id);
        },
        error: function (response) {
            enable_ui();
	    console.log(response.responseText);

            alert('An error occurred in processing. sorry'+response.responseText);
        }
    });
}

function review_verification_results(doFuzzySearch, verifyResponse, accession_list_id){
    var i;
    var j;
    accessionListFound = {};
    accessionList = [];
    infoToAdd = [];
    speciesNames = [];
    //console.log(verifyResponse);
    //console.log(accession_list_id);

    if (verifyResponse.found) {
        jQuery('#count_of_found_accessions').html("Total number already in the database("+verifyResponse.found.length+")");
        var found_html = '<table class="table table-bordered" id="found_accessions_table"><thead><tr><th>Search Name</th><th>Found in Database</th></tr></thead><tbody>';
        for( i=0; i < verifyResponse.found.length; i++){
            found_html = found_html
                +'<tr><td>'+verifyResponse.found[i].matched_string
                +'</td><td>'
                +verifyResponse.found[i].unique_name
                +'</td></tr>';
            accessionListFound[verifyResponse.found[i].unique_name] = 1;
        }
        found_html = found_html +'</tbody></table>';

        jQuery('#view_found_matches').html(found_html);

        jQuery('#review_found_matches_dialog').modal('show');

        jQuery('#found_accessions_table').DataTable({});

        accessionList = verifyResponse.absent;

    }

    if (verifyResponse.fuzzy.length > 0 && doFuzzySearch) {
        fuzzyResponse = verifyResponse.fuzzy;
        var fuzzy_html = '<table id="add_accession_fuzzy_table" class="table"><thead><tr><th class="col-xs-4">Name in Your List</th><th class="col-xs-4">Existing Name(s) in Database</th><th class="col-xs-4">Options&nbsp;&nbsp;&nbsp&nbsp;<input type="checkbox" id="add_accession_fuzzy_option_all"/> Use Same Option for All</th></tr></thead><tbody>';
        for( i=0; i < verifyResponse.fuzzy.length; i++) {
            fuzzy_html = fuzzy_html + '<tr id="add_accession_fuzzy_option_form'+i+'"><td>'+ verifyResponse.fuzzy[i].name + '<input type="hidden" name="fuzzy_name" value="'+ verifyResponse.fuzzy[i].name + '" /></td>';
            fuzzy_html = fuzzy_html + '<td><select class="form-control" name ="fuzzy_select">';
            for(j=0; j < verifyResponse.fuzzy[i].matches.length; j++){
                if (verifyResponse.fuzzy[i].matches[j].is_synonym){
                    fuzzy_html = fuzzy_html + '<option value="' + verifyResponse.fuzzy[i].matches[j].synonym_of + '">' + verifyResponse.fuzzy[i].matches[j].name + ' (SYNONYM OF: '+verifyResponse.fuzzy[i].matches[j].synonym_of+')</option>';
                } else {
                    fuzzy_html = fuzzy_html + '<option value="' + verifyResponse.fuzzy[i].matches[j].name + '">' + verifyResponse.fuzzy[i].matches[j].name + '</option>';
                }
            }
            fuzzy_html = fuzzy_html + '</select></td><td><select class="form-control" name="fuzzy_option"><option value="keep">Continue saving name in your list</option><option value="replace">Replace name in your list with selected existing name</option><option value="remove">Remove name in your list and ignore</option><option value="synonymize">Add name in your list as a synonym to selected existing name</option></select></td></tr>';
        }
        fuzzy_html = fuzzy_html + '</tbody></table>';
        jQuery('#view_fuzzy_matches').html(fuzzy_html);

        //Add to absent
        for( i=0; i < verifyResponse.fuzzy.length; i++) {
            verifyResponse.absent.push(verifyResponse.fuzzy[i].name);
        }
        accessionList = verifyResponse.absent;
    }

    if (verifyResponse.full_data){
        for(var key in verifyResponse.full_data){
            infoToAdd.push(verifyResponse.full_data[key]);
            speciesNames.push(verifyResponse.full_data[key]['species'])
        }
    }

    jQuery('#review_found_matches_hide').click(function(){
	
        if (verifyResponse.fuzzy.length > 0 && doFuzzySearch){
            jQuery('#review_fuzzy_matches_dialog').modal('show');
        } else {
            jQuery('#review_fuzzy_matches_dialog').modal('hide');
	    alert(JSON.stringify(verifyResponse.absent));
	    alert(JSON.stringify(infoToAdd));
            if (verifyResponse.absent.length > 0 || infoToAdd.length>0){
                populate_review_absent_dialog(verifyResponse.absent, infoToAdd);
            } else {
                alert('All accessions in your list already exist in the database. 3');
            }
        }
    });

    jQuery(document).on('click', '#review_fuzzy_matches_continue', function(){
        process_fuzzy_options(accession_list_id);
    });

}

function populate_review_absent_dialog(absent, infoToAdd){
    console.log(infoToAdd);
    console.log(absent);

    jQuery('#count_of_absent_accessions').html("Total number to be added("+absent.length+")");
    var absent_html = '';
    jQuery("#species_name_input").autocomplete({
        source: '/organism/autocomplete'
    });

    for( i=0; i < absent.length; i++){
        absent_html = absent_html
        +'<div class="left">'+absent[i]
        +'</div>';
    }
    jQuery('#view_absent').html(absent_html);
    jQuery('#view_infoToAdd').html('');

    if (infoToAdd.length>0){
        var infoToAdd_html = '<div class="well"><b>The following new accessions will be added:</b><br/><br/><table id="infoToAdd_new_table" class="table table-bordered table-hover"><thead><tr><th>uniquename</th><th>properties</th></tr></thead><tbody>';
        for( i=0; i < infoToAdd.length; i++){
            if (!('stock_id' in infoToAdd[i])){
                infoToAdd_html = infoToAdd_html + '<tr><td>'+infoToAdd[i]['germplasmName']+'</td>';
                var infoToAdd_properties_html = '';
                for (key in infoToAdd[i]){
                    if (key != 'uniquename' && key != 'other_editable_stock_props'){
                        infoToAdd_properties_html = infoToAdd_properties_html + key+':'+infoToAdd[i][key]+'   ';
                    }
                    else if (key == 'other_editable_stock_props') {
                        for (key_other in infoToAdd[i][key]) {
                            infoToAdd_properties_html = infoToAdd_properties_html + key_other+':'+infoToAdd[i][key][key_other]+'   ';
                        }
                    }
                }
                infoToAdd_html = infoToAdd_html + '<td>'+infoToAdd_properties_html+'</td></tr>';
            }
        }
        infoToAdd_html = infoToAdd_html + "</tbody></table></div>";
        infoToAdd_html = infoToAdd_html + '<div class="well"><b>The following accessions will be updated:</b><br/><br/><table id="infoToAdd_updated_table" class="table table-bordered table-hover"><thead><tr><th>uniquename</th><th>properties</th></tr></thead><tbody>';
        for( i=0; i < infoToAdd.length; i++){
            if ('stock_id' in infoToAdd[i]){
                infoToAdd_html = infoToAdd_html + '<tr><td>'+infoToAdd[i]['germplasmName']+'</td>';
                var infoToAdd_properties_html = '';
                for (key in infoToAdd[i]){
                    if (key != 'uniquename' && key != 'other_editable_stock_props') {
                        infoToAdd_properties_html = infoToAdd_properties_html + key+':'+infoToAdd[i][key]+'   ';
                    }
                    else if (key == 'other_editable_stock_props') {
                        for (key_other in infoToAdd[i][key]) {
                            infoToAdd_properties_html = infoToAdd_properties_html + key_other+':'+infoToAdd[i][key][key_other]+'   ';
                        }
                    }
                }
                infoToAdd_html = infoToAdd_html + '<td>'+infoToAdd_properties_html+'</td></tr>';
            }
        }
        infoToAdd_html = infoToAdd_html + "</tbody></table></div>";
        jQuery('#view_infoToAdd').html(infoToAdd_html);
        jQuery('#add_accessions_using_list_inputs').hide();
    } else {
        jQuery('#add_accessions_using_list_inputs').show();
    }

    jQuery('#review_absent_dialog').modal('show');
}

function process_fuzzy_options(accession_list_id) {
    var data={};
    jQuery('#add_accession_fuzzy_table').find('tr').each(function(){
        var id=jQuery(this).attr('id');
        if (id !== undefined){
            var row={};
            jQuery(this).find('input,select').each(function(){
                var type = jQuery(this).attr('type');
                if (type == 'radio'){
                    if (jQuery(this).is(':checked')){
                        row[jQuery(this).attr('name')]=jQuery(this).val();
                    }
                } else {
                    row[jQuery(this).attr('name')]=jQuery(this).val();
                }
            });
            data[id]=row;
        }
    });
    console.log(data);
    jQuery.ajax({
        type: 'POST',
        url: '/ajax/accession_list/fuzzy_options',
        dataType: "json",
        data: {
            'accession_list_id': accession_list_id,
            'fuzzy_option_data': JSON.stringify(data),
            'names_to_add': JSON.stringify(accessionList)
        },
        success: function (response) {
            //console.log(response);
            infoToAdd = [];
            speciesNames = [];
            accessionList = response.names_to_add;
            if (accessionList.length > 0){

                if (fullParsedData != null){
                    for (var i=0; i<accessionList.length; i++){
                        var accession_name = accessionList[i];
                        infoToAdd.push(fullParsedData[accession_name]);
                        speciesNames.push(fullParsedData[accession_name]['species']);
                    }
                    for (var accession_name in accessionListFound) {
                        if (accessionListFound.hasOwnProperty(accession_name)) {
                            infoToAdd.push(fullParsedData[accession_name]);
                            speciesNames.push(fullParsedData[accession_name]['species']);
                        }
                    }
                }
                populate_review_absent_dialog(accessionList, infoToAdd);
                jQuery('#review_absent_dialog').modal('show');
            } else {
                alert('All accessions in your list now exist in the database. 2');
            }
        },
        error: function () {
            alert('An error occurred checking your fuzzy options! Do not try to add a synonym to a synonym! Also do not use any special characters!');
        }
    });
}
