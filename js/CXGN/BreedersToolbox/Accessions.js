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
    var accession_list_id;
    var validSpecies;

    function disable_ui() {
        $('#working_modal').modal("show");
    }

    function enable_ui() {
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
                    alert("All accessions in your list are in the database.");
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

    $('#species_name_input').focusout(function () {
        verify_species_name();
    });

    function process_fuzzy_options(accession_list_id) {
        var data={};
        $('#add_accession_fuzzy_table').find('tr').each(function(){
            var id=$(this).attr('id');
            if (id !== undefined){
                var row={};
                $(this).find('input,select').each(function(){
                    var type = $(this).attr('type');
                    if (type == 'radio'){
                        if ($(this).is(':checked')){
                            row[$(this).attr('name')]=$(this).val();
                        }
                    } else {
                        row[$(this).attr('name')]=$(this).val();
                    }
                });
                data[id]=row;
            }
        });
        //console.log(data);

        $.ajax({
            type: 'POST',
            url: '/ajax/accession_list/fuzzy_options',
            dataType: "json",
            data: {
                'accession_list_id': accession_list_id,
                'fuzzy_option_data': JSON.stringify(data),
            },
            success: function (response) {
                //console.log(response);
                accessionList = response.names_to_add;
                if (accessionList.length > 0){
                    populate_review_absent_dialog(accessionList);
                    jQuery('#review_absent_dialog').modal('show');
                } else {
                    alert('All accessions in your list are in the database.');
                }
            },
            error: function () {
                alert('An error occurred checking your fuzzy options! Do not try to add a synonym to a synonym!');
            }
        });
    }

    function populate_review_absent_dialog(absent){
        $('#count_of_absent_accessions').html("Total number to be added("+absent.length+")");
        var absent_html = '';
        $("#species_name_input").autocomplete({
            source: '/organism/autocomplete'
        });

        for( i=0; i < absent.length; i++){
            absent_html = absent_html
            +'<div class="left">'+absent[i]
            +'</div>';
        }
        $('#view_absent').html(absent_html);
    }

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


    function review_verification_results(verifyResponse, accession_list_id){
        var i;
        var j;
        accessionList;
        //console.log(verifyResponse);
        //console.log(accession_list_id);

        if (verifyResponse.found) {
            $('#count_of_found_accessions').html("Total number already in the database("+verifyResponse.found.length+")");
            var found_html = '<table class="table" id="found_accessions_table"><thead><tr><th>Search Name</th><th>Found in Database</th></tr></thead><tbody>';
            for( i=0; i < verifyResponse.found.length; i++){
                found_html = found_html
                    +'<tr><td>'+verifyResponse.found[i].matched_string
                    +'</td><td>'
                    +verifyResponse.found[i].unique_name
                    +'</td></tr>';
            }
            found_html = found_html +'</tbody></table>';

            $('#view_found_matches').html(found_html);

            $('#review_found_matches_dialog').modal('show');

            $('#found_accessions_table').DataTable({});

            accessionList = verifyResponse.absent;

        }

        if (verifyResponse.fuzzy.length > 0) {
            var fuzzy_html = '<table id="add_accession_fuzzy_table" class="table"><thead><tr><th class="col-xs-4">Name in Your List</th><th class="col-xs-4">Existing Name(s) in Database</th><th class="col-xs-4">Options</th></tr></thead><tbody>';
            for( i=0; i < verifyResponse.fuzzy.length; i++) {
                fuzzy_html = fuzzy_html + '<tr id="add_accession_fuzzy_option_form'+i+'"><td>'+ verifyResponse.fuzzy[i].name + '<input type="hidden" name="fuzzy_name" value="'+ verifyResponse.fuzzy[i].name + '" /></td>';
                fuzzy_html = fuzzy_html + '<td><select class="form-control" name ="fuzzy_select">';
                for(j=0; j < verifyResponse.fuzzy[i].matches.length; j++){
                    fuzzy_html = fuzzy_html + '<option value="' + verifyResponse.fuzzy[i].matches[j].name + '">' + verifyResponse.fuzzy[i].matches[j].name + '</option>';
                }
                fuzzy_html = fuzzy_html + '</select></td><td><select class="form-control" name="fuzzy_option"><option value="replace">Replace name in your list with selected existing name</option><option value="keep">Continue saving name in your list</option><option value="remove">Remove name in your list and ignore</option><option value="synonymize">Add name in your list as a synonym to selected existing name</option></select></td></tr>';
            }
            fuzzy_html = fuzzy_html + '</tbody></table>';
            $('#view_fuzzy_matches').html(fuzzy_html);

            //Add to absent
            for( i=0; i < verifyResponse.fuzzy.length; i++) {
                verifyResponse.absent.push(verifyResponse.fuzzy[i].name);
            }
            accessionList = verifyResponse.absent;
        }

        if (verifyResponse.absent.length > 0 && verifyResponse.fuzzy.length == 0) {
            populate_review_absent_dialog(verifyResponse.absent);
        }

        jQuery('#review_found_matches_hide').click(function(){
            if (verifyResponse.fuzzy.length > 0){
                jQuery('#review_fuzzy_matches_dialog').modal('show');
            } else {
                jQuery('#review_fuzzy_matches_dialog').modal('hide');
                if (verifyResponse.absent.length > 0){
                    jQuery('#review_absent_dialog').modal('show');
                } else {
                    alert('All accessions in your list are in the database.');
                }
            }
        });

        jQuery(document).on('click', '#review_fuzzy_matches_continue', function(){
            process_fuzzy_options(accession_list_id);
        });

    }

    function verify_accession_list() {
        accession_list_id = $('#accessions_list_select').val();
        accession_list = JSON.stringify(list.getList(accession_list_id));
        doFuzzySearch = $('#fuzzy_check').attr('checked'); //fuzzy search is always checked in a hidden input
        //alert("should be disabled");
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
            success: function (response) {
                enable_ui();
                if (response.error) {
                    alert(response.error);
                } else {
                    review_verification_results(response, accession_list_id);
                }
            },
            error: function () {
                enable_ui();
                alert('An error occurred in processing. sorry');
            }
        });
    }


    $('#new_accessions_submit').click(function () {
        verify_accession_list();
        $('#add_accessions_dialog').modal("hide");
    });

    $('#add_accessions_link').click(function () {
        $('#add_accessions_dialog').modal("show");
        $("#list_div").html(list.listSelect("accessions"));
    });

    $('body').on('hidden.bs.modal', '.modal', function () {
        $(this).removeData('bs.modal');
    });

});
