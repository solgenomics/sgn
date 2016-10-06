/*jslint browser: true, devel: true */

/**

=head1 Crosses.js

Dialogs for adding and uploading crosses


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    var list = new CXGN.List();

    function upload_crosses_file() {
        var uploadFile = $("#crosses_upload_file").val();
        $('#upload_crosses_form').attr("action", "/ajax/cross/upload_crosses_file");
        if (uploadFile === '') {
	    alert("Please select a file");
	    return;
        }
        $("#upload_crosses_form").submit();
    }

    $("#upload_crosses_submit").click( function () {
	$("#upload_crosses_dialog" ).modal("hide");
	upload_crosses_file();
    });



    $('#upload_crosses_form').iframePostForm({
	json: true,
	post: function () {
	    var uploadFile = $("#crosses_upload_file").val();
	    if (uploadFile === '') {
		alert("No file selected");
	    }
	},
	complete: function (response) {
            if (response.error_string) {
		$("#upload_cross_error_display tbody").html('');
		$("#upload_cross_error_display tbody").append(response.error_string);
		$("#upload_cross_error_display").modal("show");

		return;
            }
	    if (response.error) {
		alert(response.error);
		return;
	    }
	    if (response.success) {
		$('#cross_saved_dialog_message').modal("show");
	    }
	}
    });


    $("#cross_upload_spreadsheet_format_info").click( function () {
	$("#upload_crosses_dialog" ).modal("hide");
	$("#cross_upload_spreadsheet_info_dialog" ).modal("show");
    });

    $("#cross_type_info").click( function () {
      $("#create_crosses" ).modal("hide");
      $("#cross_type_dialog" ).modal("show");
    });

    $('#create_cross_submit').click(function () {

      var crossType = $("#cross_type").val();
      if (!crossType) { alert("No type was selected, please select a type before saving a cross/crosses"); return; }

      var crossName = $("#cross_name").val();
      if (!crossName) { alert("A cross name is required"); return; }

      var breeding_program_id = $("#program").val();
      if (!breeding_program_id) { alert("A breeding program is required"); return; }

      var visibleToRole = $("#visible_to_role").val();
      var location = $("#location").val();
      var folder_name = $("#add_cross_folder_name").val();
      var folder_id = $("#add_cross_folder_id").val();

      switch(crossType) {
          case 'polycross':
            add_polycross(crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id);
            jQuery("#create_cross").modal("hide");
            jQuery('#cross_saved_dialog_message').modal("show");
            break;
          case 'reciprocal':
            add_reciprocal_crosses(crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id);
            jQuery("#create_cross").modal("hide");
            jQuery('#cross_saved_dialog_message').modal("show");
            break;
          case 'multicross':
            add_multicross(crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id);
            jQuery("#create_cross").modal("hide");
            jQuery('#cross_saved_dialog_message').modal("show");
            break;
          default:
            add_cross(crossType, crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id);
      }

    });

    $("#open_paternal_population_checkbox").change(function(){
	     $("open_paternal_population").toggle(this.checked);
    });

    $("#bulk_open_paternal_population_checkbox").change(function(){
	     $("#bulk_open_paternal_population").toggle(this.checked);
    });

    $("#flower_number_checkbox").change(function(){
	$("#get_flower_number").toggle(this.checked);  // show if it is checked, otherwise hide
    });

    $("#use_folders_checkbox").change(function(){
      $("#folder_section").toggle(this.checked);  // show if it is checked, otherwise hide
    });

    $("#seed_number_checkbox").change(function(){
	$("#get_seed_number").toggle(this.checked);  // show if it is checked, otherwise hide
    });

    $("#create_progeny_checkbox").change(function(){
	$("#create_progeny_number").toggle(this.checked);  // show if it is checked, otherwise hide
	$("#use_prefix_suffix").toggle(this.checked);  // show if it is checked, otherwise hide
	$("#get_prefix_suffix").toggle(this.checked);  // show if it is checked, otherwise hide
    });

    $("#use_prefix_suffix_checkbox").change(function(){
	$("#get_prefix_suffix").toggle(this.checked);  // show if it is checked, otherwise hide
    });

    $("#data_access_checkbox").change(function(){
	$("#show_visible_to_role_selection").toggle(this.checked);  // show if it is checked, otherwise hide
    });

  $("#create_cross_link").click( function () {

    get_select_box('folders', 'add_cross_folder_select_div', { 'name' : 'add_cross_folder_id', 'id' : 'add_cross_folder_id', 'empty' : 1  });
    var lo = new CXGN.List();
    $('#polycross_accession_list').html(lo.listSelect('polycross_accessions', [ 'accessions' ], 'select'));
    $('#reciprocal_accession_list').html(lo.listSelect('reciprocal_accessions', [ 'accessions' ], 'select'));
    $('#maternal_accession_list').html(lo.listSelect('maternal_accessions', [ 'accessions' ], 'select'));
    $('#paternal_accession_list').html(lo.listSelect('paternal_accessions', [ 'accessions' ], 'select'));

	    $("#create_cross" ).modal("show");

      $("#cross_type").change(function(){  // show cross_type specific inputs depending on cross type selected
        $("#get_maternal_parent").toggle($("#cross_type").val()=="biparental");
        $("#get_paternal_parent").toggle($("#cross_type").val()=="biparental");
        $("#get_selfed_parent").toggle($("#cross_type").val()=="self");
        $("#get_open_maternal_parent").toggle($("#cross_type").val()=="open");
        $("#get_open_paternal_population").toggle($("#cross_type").val()=="open");
        $("#get_bulk_maternal_population").toggle($("#cross_type").val()=="bulk");
        $("#get_bulk_paternal_parent").toggle($("#cross_type").val()=="bulk");
        $("#get_bulk_selfed_population").toggle($("#cross_type").val()=="bulk_self");
        $("#get_bulk_open_maternal_population").toggle($("#cross_type").val()=="bulk_open");
        $("#get_bulk_open_paternal_population").toggle($("#cross_type").val()=="bulk_open");
        $("#get_doubled_haploid_parent").toggle($("#cross_type").val()=="doubled_haploid");
        $("#polycross_accessions").toggle($("#cross_type").val()=="polycross");
        $("#reciprocal_accessions").toggle($("#cross_type").val()=="reciprocal");
        $("#maternal_accessions").toggle($("#cross_type").val()=="multicross");
        $("#paternal_accessions").toggle($("#cross_type").val()=="multicross");
      });

  });

  function add_cross(crossType, crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id) {

    var progenyNumber = $("#progeny_number").val();
    var flowerNumber = $("#flower_number").val();
    var seedNumber = $("#seed_number").val();
    var prefix = $("#prefix").val();
    var suffix = $("#suffix").val();

    var maternalParent;
    var paternalParent;

    switch(crossType) {
      case 'biparental':
        maternalParent = $("#maternal_parent").val();
        paternalParent = $("#paternal_parent").val();
        break;
      case 'self':
        var selfedParent = $("#selfed_parent").val();
        maternalParent = selfedParent;
        paternalParent = selfedParent;
        break;
      case 'open':
        maternalParent = $("#open_maternal_parent").val();
        paternalParent = $("#open_paternal_population").val();
        break;
      case 'bulk':
        maternalParent = $("#bulk_maternal_population").val();
        paternalParent = $("#bulk_paternal_parent").val();
        break;
      case 'bulk_self':
        var bulkedSelfedPopulation = $("#bulk_selfed_population").val();
        maternalParent = bulkedSelfedPopulation;
        paternalParent = bulkedSelfedPopulation;
        break;
      case 'bulk_open':
        maternalParent = $("#bulk_open_maternal_population").val();
        paternalParent = $("#bulk_open_paternal_population").val();
        break;
      case 'doubled_haploid':
        var doubledHaploidParent = $("#doubled_haploid_parent").val();
        maternalParent = doubledHaploidParent;
        paternalParent = doubledHaploidParent;
        break;
    }

	  $.ajax({
      url: '/ajax/cross/add_cross',
      timeout: 3000000,
      dataType: "json",
      type: 'POST',
      data: 'cross_name='+crossName+'&cross_type='+crossType+'&maternal_parent='+encodeURIComponent(maternalParent)+'&paternal_parent='+encodeURIComponent(paternalParent)+'&progeny_number='+progenyNumber+'&flower_number='+flowerNumber+'&seed_number='+seedNumber+'&prefix='+prefix+'&suffix='+suffix+'&visible_to_role'+visibleToRole+'&breeding_program_id='+breeding_program_id+'&location='+location+'&folder_name='+folder_name+'&folder_id='+folder_id,
      error: function(response) { alert("An error occurred. Please try again later!"+response); },
      parseerror: function(response) { alert("A parse error occurred. Please try again."+response); },
      success: function(response) {
        if (response.error) { alert(response.error); }
        else {
          $("#create_cross").modal("hide");
          $('#cross_saved_dialog_message').modal("show");
        }
      },
    });

  }

  $('#cross_saved_dialog_message').on('hidden.bs.modal', function () {
    location.reload();
  })

function add_reciprocal_crosses(crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id) {
  var accession_names =get_accession_names('reciprocal_accessions_list_select');

  for ( i=0; i < accession_names.length; i++) {
    var maternalParent = accession_names[i];

    for ( j=0; j < accession_names.length; j++) {
      var paternalParent = accession_names[j];

      if (maternalParent == paternalParent) { continue; }

      var reciprocalcrossName = crossName + '_' + maternalParent + 'x' + accession_names[j] + '_reciprocalcross';
      var crossType = 'biparental';

      folder_id = ajax_add_cross (reciprocalcrossName, crossType, maternalParent, paternalParent, visibleToRole, breeding_program_id, location, folder_name, folder_id);
    }
  }
}

function add_multicross(crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id) {
  var maternal_names = get_accession_names('maternal_accessions_list_select');
  var paternal_names = get_accession_names('paternal_accessions_list_select');

  for ( i=0; i < maternal_names.length; i++) {
    var maternalParent = maternal_names[i];
    var paternalParent = paternal_names[i];
    var multicrossName = crossName + '_' + maternalParent + 'x' + paternalParent + '_multicross';
    var crossType = 'biparental';

    folder_id = ajax_add_cross (multicrossName, crossType, maternalParent, paternalParent, visibleToRole, breeding_program_id, location, folder_name, folder_id);
  }
}

function add_polycross(crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id) {
  var accession_names = get_accession_names('polycross_accessions_list_select');
  var populationName = crossName + '_parents';
  var paternalParent = '';

  jQuery.ajax({
    url: '/ajax/population/new',
    timeout: 60000,
    method: 'POST',
    async: false,
    data: {'population_name': populationName, 'accessions': accession_names},
    success: function(response) {
      paternalParent = populationName;
    },
    error: function(response) { alert("An error occurred creating population "+populationName+". Please try again later!"+response); },
  });

  for ( i=0; i < accession_names.length; i++) {
    var maternalParent = accession_names[i];
    var polycrossName = crossName + '_' + accession_names[i] + '_polycross';
    var crossType = 'biparental';
    folder_id = ajax_add_cross(polycrossName, crossType, maternalParent, paternalParent, visibleToRole, breeding_program_id, location, folder_name, folder_id);
  }
}

    $("#upload_crosses_link").click( function () {
      get_select_box('folders', 'cross_folder_select_div', { 'name' : 'upload_folder_id', 'id' : 'upload_folder_id', 'empty' : 1  });
      $("#upload_crosses_dialog" ).modal("show");
    });

    $("#maternal_parent").autocomplete( {
	source: '/ajax/stock/accession_autocomplete'
    });

    $("#paternal_parent").autocomplete( {
	source: '/ajax/stock/accession_autocomplete'
    });

    $("#selfed_parent").autocomplete( {
	source: '/ajax/stock/accession_autocomplete'
    });

    $("#doubled_haploid_parent").autocomplete( {
	source: '/ajax/stock/accession_autocomplete'
    });

    $("#open_pollinated_maternal_parent").autocomplete( {
	source: '/ajax/stock/accession_autocomplete'
    });

    $("#paternal_population").autocomplete( {
	source: '/ajax/stock/stock_autocomplete'
    });

    $("#bulked_maternal_population").autocomplete( {
	source: '/ajax/stock/stock_autocomplete'
    });

    $("#bulked_paternal_parent").autocomplete( {
	source: '/ajax/stock/stock_autocomplete'
    });

    $("#bulked_selfed_population").autocomplete( {
	source: '/ajax/stock/stock_autocomplete'
    });

    $("#bulked_open_maternal_population").autocomplete( {
	source: '/ajax/stock/stock_autocomplete'
    });

    $("#bulked_open_paternal_population").autocomplete( {
	source: '/ajax/stock/stock_autocomplete'
    });

    jQuery("#refresh_crosstree_button").click( function() {
        jQuery.ajax( {
            url: '/ajax/breeders/get_crosses_with_folders',
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            success: function(response) {
                jQuery("#working_modal").modal("hide");
                location.reload();
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred refreshing crosses jstree html');
            }
        });
    });

  function get_accession_names (accession_select_id) {

    var accession_list_id = $('#'+accession_select_id).val();
    var lo = new CXGN.List();
    var accession_validation = 1;
    if (accession_list_id) { accession_validation = lo.validate(accession_list_id, 'accessions', true); }

    if (!accession_list_id) {
       alert("You need to select an accession list!");
       return;
    }

    if (accession_validation != 1) {
      alert("The accession list did not pass validation. Please correct the list and try again");
      return;
    }

    var list_data = lo.getListData(accession_list_id);
    var accessions = list_data.elements;
    var names = [];
    for ( i=0; i < accessions.length; i++) {
      names.push(accessions[i][1]);
    }
    return names;
  }

  function ajax_add_cross (crossName, crossType, maternalParent, paternalParent, visibleToRole, breeding_program_id, location, folder_name, folder_id) {
    var new_folder_id;
    jQuery.ajax({
            url: '/ajax/cross/add_cross',
            timeout: 3000000,
            dataType: "json",
            type: 'POST',
            async: false,
            data: 'cross_name='+crossName+'&cross_type='+crossType+'&maternal_parent='+maternalParent+'&paternal_parent='+paternalParent+'&visible_to_role'+visibleToRole+'&breeding_program_id='+breeding_program_id+'&location='+location+'&folder_name='+folder_name+'&folder_id='+folder_id,
            error: function(response) { alert("An error occurred creating cross "+crossName+". Please try again later!"+response); },
            parseerror: function(response) { alert("A parse error occurred while creating cross "+crossName+". Please try again."+response); },
            success: function(response) {
              if (response.error) { alert(response.error); }
              new_folder_id = response.folder_id;
            }
    });
    return new_folder_id;
  }

});
