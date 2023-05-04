/*jslint browser: true, devel: true */
/**

=head1 Vectors.js

Dialogs for managing vectors


=head1 AUTHOR

Mirella Flores<mrf252@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();
var list = new CXGN.List();
var vectorList;
var vector_list_id;
var validSpecies;
var fuzzyResponse;
var fullParsedData;
var infoToAdd;
var vectorListFound;
var speciesNames;
var doFuzzySearch;

function disable_ui() {
    jQuery('#working_modal').modal("show");
}

function enable_ui() {
    jQuery('#working_modal').modal("hide");
}

jQuery(document).ready(function ($) {

    function add_vectors(full_info, species_names) {

        $.ajax({
            type: 'POST',
            url: '/ajax/create_vector_construct',
            dataType: "json",
            timeout: 36000000,
            data: {
                'data': JSON.stringify(full_info),
                'allowed_organisms': JSON.stringify(species_names),
            },
            beforeSend: function(){
                disable_ui();
            },
            success: function (response) {
                enable_ui();

                if (response.error) {
                    alert(response.error);
                } else {
                    var html = 'The following vectors were added!<br/>';
                    for (var i=0; i<response.added.length; i++){
                        html = html + '<a href="/stock/'+response.added[i][0]+'/view">'+response.added[i][1]+'</a><br/>';
                    }
                    jQuery('#add_vectors_saved_message').html(html);
                    jQuery('#add_vectors_saved_message_modal').modal('show');
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
            }
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

    //  review absent vectors
    $('#review_absent_vectors_submit').click(function () {
        if (fullParsedData == undefined){
            var speciesName = $("#species_name_input").val();
            var vectorsToAdd = vectorList;
            if (!speciesName) {
                alert("Species name required");
                return;
            }

            if (!vectorsToAdd || vectorsToAdd.length == 0) {
                alert("No vectors to add");
                return;
	        }
        
            verify_species_name().then(
                function(r) {
                    if (r.error) { alert(r.error); }
                    else {
                    for(var i=0; i<vectorsToAdd.length; i++){
                        infoToAdd.push({
                        'species_name':speciesName,
                        'defaultDisplayName':vectorsToAdd[i],
                        });
                        speciesNames.push(speciesName);
                    }
                    }
                    add_vectors(infoToAdd, speciesNames);
                    $('#review_absent_dialog').modal("hide");

                },
                function(r) {
                    alert('ERROR! Try again later.');
                }
            );
	    }
        add_vectors(infoToAdd, speciesNames);
        $('#review_absent_dialog').modal("hide");

    });

    $('#new_vectors_submit').click(function () {

	    var uploadFile = jQuery("#new_vectors_upload_file").val();
	    jQuery('#upload_new_vectors_form').attr("action", "/ajax/vectors/verify_vectors_file");
	    if (uploadFile === '') {
                alert("Please select a file");
                return;
	    }
	    jQuery("#upload_new_vectors_form").submit();

	$('#add_vectors_dialog').modal("hide");
    });

    jQuery('#upload_new_vectors_form').iframePostForm({
        json: false,
        post: function () {
            var vectorFile = jQuery("#new_vectors_upload_file").val();
            jQuery('#working_modal').modal("show");
            if (vectorFile === '') {
                jQuery('#working_modal').modal("hide");
            }
        },
        complete: function (r) {
            var clean_r = r.replace('<pre>', '');
            clean_r = clean_r.replace('</pre>', '');
            response = JSON.parse(clean_r);
            console.log(response);
            jQuery('#working_modal').modal("hide");

            if (response.error || response.error_string) {
                fullParsedData = undefined;
                alert(response.error || response.error_string);
            }
            else if (response.success) {
                fullParsedData = response.full_data;
                doFuzzySearch = jQuery('#fuzzy_check_upload_vectors').attr('checked');
                review_verification_results(doFuzzySearch, response, response.list_id);
            }
            else {
                fullParsedData = undefined;
                alert("An unknown error occurred.  Please try again later or contact us for help.");
            }
        }
    });

    $('[name="add_vectors_link"]').click(function () {

        $('#add_vectors_dialog').modal("show");
        $('#review_found_matches_dialog').modal("hide");
        $('#review_fuzzy_matches_dialog').modal("hide");
        $('#review_absent_dialog').modal("hide");

    });

    jQuery('#vectors_upload_spreadsheet_format_info').click(function(){
        jQuery('#vectors_upload_spreadsheet_format_modal').modal("show");
    });

    $('body').on('hidden.bs.modal', '.modal', function () {
        $(this).removeData('bs.modal');
    });

	$(document).on('change', 'select[name="fuzzy_option"]', function() {
		var value = $(this).val();
		if ($('#add_vector_fuzzy_option_all').is(":checked")){
			$('select[name="fuzzy_option"] option[value='+value+']').attr('selected','selected');
		}
	});

    $('#review_fuzzy_matches_download').click(function(){
        console.log(fuzzyResponse);
        openWindowWithPost(JSON.stringify(fuzzyResponse));
        //window.open('/ajax/vector_list/fuzzy_download?fuzzy_response='+JSON.stringify(fuzzyResponse));
    });

    jQuery('#review_absent_dialog').on('shown.bs.modal', function (e) {
        jQuery('#infoToAdd_updated_table').DataTable({});
        jQuery('#infoToAdd_new_table').DataTable({});
    });

    jQuery('#close_add_vectors_saved_message_modal').click( function() {
        location.reload();
    });

});

function openWindowWithPost(fuzzyResponse) {
    var f = document.getElementById('add_vector_fuzzy_match_download');
    f.fuzzy_response.value = fuzzyResponse;
    window.open('', 'TheWindow');
    f.submit();
}

function review_verification_results(doFuzzySearch, verifyResponse, vector_list_id){
    var i;
    var j;
    vectorListFound = {};
    vectorList = [];
    infoToAdd = [];
    speciesNames = [];
    //console.log(verifyResponse);
    //console.log(vector_list_id);

    if (verifyResponse.found) {
        jQuery('#count_of_found_vectors').html("Total number already in the database("+verifyResponse.found.length+")");
        var found_html = '<table class="table table-bordered" id="found_vectors_table"><thead><tr><th>Search Name</th><th>Found in Database</th></tr></thead><tbody>';
        for( i=0; i < verifyResponse.found.length; i++){
            found_html = found_html
                +'<tr><td>'+verifyResponse.found[i].matched_string
                +'</td><td>'
                +verifyResponse.found[i].unique_name
                +'</td></tr>';
            vectorListFound[verifyResponse.found[i].unique_name] = 1;
        }
        found_html = found_html +'</tbody></table>';

        jQuery('#view_found_matches').html(found_html);

        jQuery('#review_found_matches_dialog').modal('show');

        jQuery('#found_vectors_table').DataTable({});

        vectorList = verifyResponse.absent;
    }

    if (verifyResponse.fuzzy.length > 0 && doFuzzySearch) {
        fuzzyResponse = verifyResponse.fuzzy;
        var fuzzy_html = '<table id="add_vector_fuzzy_table" class="table"><thead><tr><th class="col-xs-4">Name in Your List</th><th class="col-xs-4">Existing Name(s) in Database</th><th class="col-xs-4">Options&nbsp;&nbsp;&nbsp&nbsp;<input type="checkbox" id="add_vector_fuzzy_option_all"/> Use Same Option for All</th></tr></thead><tbody>';
        for( i=0; i < verifyResponse.fuzzy.length; i++) {
            fuzzy_html = fuzzy_html + '<tr id="add_vector_fuzzy_option_form'+i+'"><td>'+ verifyResponse.fuzzy[i].name + '<input type="hidden" name="fuzzy_name" value="'+ verifyResponse.fuzzy[i].name + '" /></td>';
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
        vectorList = verifyResponse.absent;
    }

    if (verifyResponse.full_data){
        for(var key in verifyResponse.full_data){
            infoToAdd.push(verifyResponse.full_data[key]);
            speciesNames.push(verifyResponse.full_data[key]['species'])
        }
    }

    jQuery('#review_found_matches_hide').click(function(){

        if ( verifyResponse.found.length >0){
            jQuery('#review_fuzzy_matches_dialog').modal('hide');
            alert("Remove duplicated vectors and try again!");
            $('#add_vectors_dialog').modal("show");

        }  else if (verifyResponse.fuzzy.length > 0 && doFuzzySearch){
            jQuery('#review_fuzzy_matches_dialog').modal('show');
            
        } else {
            jQuery('#review_fuzzy_matches_dialog').modal('hide');

            if (verifyResponse.absent.length > 0 || infoToAdd.length>0){
                populate_review_absent_dialog(verifyResponse.absent, infoToAdd);
            } else {
                alert('All vectors in your list already exist in the database. (3)');
            }
        }
    });

    jQuery(document).on('click', '#review_fuzzy_matches_continue', function(){
        process_fuzzy_options(vector_list_id);
    });

}

function populate_review_absent_dialog(absent, infoToAdd){
    console.log(infoToAdd);
    console.log(absent);

    jQuery('#count_of_absent_vectors').html("Total number to be added("+absent.length+")");
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
        var infoToAdd_html = '<div class="well"><b>The following new vectors will be added:</b><br/><br/><table id="infoToAdd_new_table" class="table table-bordered table-hover"><thead><tr><th>uniquename</th><th>properties</th></tr></thead><tbody>';
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
        infoToAdd_html = infoToAdd_html + '<div class="well"><b>The following vectors will be updated:</b><br/><br/><table id="infoToAdd_updated_table" class="table table-bordered table-hover"><thead><tr><th>uniquename</th><th>properties</th></tr></thead><tbody>';
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
    }

    jQuery('#review_absent_dialog').modal('show');
}

function process_fuzzy_options(vector_list_id) {
    var data={};
    jQuery('#add_vector_fuzzy_table').find('tr').each(function(){
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
        url: '/ajax/vector_list/fuzzy_options',
        dataType: "json",
        data: {
            'vector_list_id': vector_list_id,
            'fuzzy_option_data': JSON.stringify(data),
            'names_to_add': JSON.stringify(vectorList)
        },
        success: function (response) {
            //console.log(response);
            infoToAdd = [];
            speciesNames = [];
            vectorList = response.names_to_add;
            if (vectorList.length > 0){

                if (fullParsedData != null){
                    for (var i=0; i<vectorList.length; i++){
                        var vector_name = vectorList[i];
                        infoToAdd.push(fullParsedData[vector_name]);
                        speciesNames.push(fullParsedData[vector_name]['species']);
                    }
                    for (var vector_name in vectorListFound) {
                        if (vectorListFound.hasOwnProperty(vector_name)) {
                            infoToAdd.push(fullParsedData[vector_name]);
                            speciesNames.push(fullParsedData[vector_name]['species']);
                        }
                    }
                }
                populate_review_absent_dialog(vectorList, infoToAdd);
                jQuery('#review_absent_dialog').modal('show');
            } else {
                alert('All vectors in your list now exist in the database. 2');
            }
        },
        error: function () {
            alert('An error occurred checking your fuzzy options! Do not try to add a synonym to a synonym! Also do not use any special characters!');
        }
    });
}
