window.onload = function initialize() {

    jQuery('#select1').change( // reset start from list if select1 changes
	     function() {
	        if (jQuery('#paste_list_list_select').val()) {
            create_list_start('Start from a list');
	         }
	  });

    jQuery('#select1, #select2, #select3, #select4').change(  // retrieve new data once new category is selected
    	function() {
	    var this_section = jQuery(this).attr('name');
	    reset_downstream_sections(this_section);
	    update_select_categories(this_section);
	    var category = jQuery(this).val();

	    if (!category) { // reset by returning empty if no category was defined
        var data_element = "c"+this_section+"_data";
        jQuery("#"+data_element).html('');
        return;
	    }
	    var categories = get_selected_categories(this_section);
	    var data = ''
	    if (this_section !== "1") data = get_selected_data(this_section);
	    var error = check_missing_criteria(categories, data, this_section); // make sure criteria selected in each panel
	    if (error) return;
	    if (data.length >= categories.length) data.pop(); //remove extra data array if exists

	    retrieve_and_display_set(categories, data, this_section);
	    update_download_options(this_section);
	});

    jQuery('#c1_data, #c2_data, #c3_data, #c4_data').change( // update wizard panels and categories when data selections change
    	function() {
	    var this_section = jQuery(this).attr('name');

	    var data_id = jQuery(this).attr('id');
	    var data = jQuery('#'+data_id).val() || [];;
	    var count_id = "c"+this_section+"_data_count";

      var categories = get_selected_categories(this_section);
	    reset_downstream_sections(this_section);
	    update_select_categories(this_section, categories);
	    show_list_counts(count_id, jQuery('#'+data_id).text().split("\n").length-1, data.length);
	    update_download_options(this_section, categories);
	});

    jQuery('#c1_select_all, #c2_select_all, #c3_select_all, #c4_select_all').click( // select all data in a wizard panel
    	function() {
	    var this_section = jQuery(this).attr('name');
	    var data_id = "c"+this_section+"_data";
	    selectAllOptions(document.getElementById(data_id));

	    var data = jQuery("#"+data_id).val() || [];;
	    var count_id = "c"+this_section+"_data_count";

	    show_list_counts(count_id, jQuery('#'+data_id).text().split("\n").length-1, data.length);
      var categories = get_selected_categories(this_section);
	    update_select_categories(this_section, categories);
	    update_download_options(this_section, categories);
	});

      jQuery('select').dblclick(function() { // open detail page in new window or tab on double-click
	  var this_section = jQuery(this).attr('name');
	  var categories = get_selected_categories(this_section);
	  var category = categories.pop();
	  switch (category)
	  {
	  case "accessions":
      case "plants":
	  case "plots":
      case "seedlots":
	      window.open("../../stock/"+this.value+"/view");
	      break;
	  case "trials":
	      window.open("../../breeders_toolbox/trial/"+this.value);
	      break;
	  case "breeding_programs":
	      window.open("../../breeders/manage_programs");
	      break;
	  case "locations":
	      window.open("../../breeders/locations");
	      break;
    case "trait_components":
	  case "traits":
	      window.open("../../cvterm/"+this.value+"/view");
	      break;
	  default:
	      if (window.console) console.log("no link for this category");
	  }
      });

    jQuery('#open_update_dialog').on('click', function () {
	jQuery('#update_wizard_dialog').modal("show");
	matviews_update_options();
    });

    jQuery('#update_wizard_dialog, #upload_datacollector_phenotypes_dialog, #upload_phenotype_spreadsheet_dialog, #upload_fieldbook_phenotypes_dialog').on("click", '.wiz-update', function () {
	//if (window.console) console.log("refreshing materialized views . . .");
	refresh_matviews("fullview");
    });

    jQuery('#wizard_download_phenotypes_button').click( function () {
        jQuery('#download_wizard_phenotypes_dialog').modal("show");
    });

    jQuery('#wizard_download_metadata_button').click( function () {
        jQuery('#download_wizard_metadata_dialog').modal("show");
    });
    
    jQuery('#download_wizard_phenotypes_submit_button').on('click', function (event) {
        event.preventDefault();
        var selected_trials = get_selected_results('trials');
        var selected_locations = get_selected_results('locations');
        var selected_accessions = get_selected_results('accessions');
        var selected_traits = get_selected_results('traits');
        var selected_trait_components = get_selected_results('trait_components');
        var selected_plots = get_selected_results('plots');
        var selected_plants = get_selected_results('plants');
        var selected_years = get_selected_results('years');
        var format = jQuery("#download_wizard_phenotypes_format").val();
        var timestamp = jQuery("#download_wizard_phenotypes_timestamp_option").val();
        var exclude_phenotype_outlier = jQuery("#download_wizard_phenotypes_exclude_outliers").val();
        var trait_contains = jQuery("#download_wizard_phenotype_trait_contains").val();
        var trait_contains_array = trait_contains.split(",");
        var data_level = jQuery("#download_wizard_phenotypes_level_option").val();
        var phenotype_min_value = jQuery("#download_wizard_phenotype_phenotype_min").val();
        var phenotype_max_value = jQuery("#download_wizard_phenotype_phenotype_max").val();
        console.log("plot list="+JSON.stringify(selected_plots));

        if (selected_trials.length !== 0 || selected_locations.length !== 0 || selected_accessions.length !== 0 || selected_traits.length !== 0 || selected_trait_components.length !== 0 || selected_plots.length !== 0 || selected_plants.length !== 0 || selected_years.length !== 0) {
            window.open("/breeders/trials/phenotype/download?trial_list="+JSON.stringify(selected_trials)+"&format="+format+"&trait_list="+JSON.stringify(selected_traits)+"&trait_component_list="+JSON.stringify(selected_trait_components)+"&accession_list="+JSON.stringify(selected_accessions)+"&plot_list="+JSON.stringify(selected_plots)+"&plant_list="+JSON.stringify(selected_plants)+"&location_list="+JSON.stringify(selected_locations)+"&year_list="+JSON.stringify(selected_years)+"&dataLevel="+data_level+"&phenotype_min_value="+phenotype_min_value+"&phenotype_max_value="+phenotype_max_value+"&timestamp="+timestamp+"&trait_contains="+JSON.stringify(trait_contains_array)+"&include_row_and_column_numbers=1&exclude_phenotype_outlier="+exclude_phenotype_outlier);
        } else {
            alert("No filters selected for download.");
        }
    });

    jQuery('#download_wizard_metadata_submit_button').on('click', function (event) {
        event.preventDefault();
        var selected_trials = get_selected_results('trials');
        var format = jQuery("#download_wizard_metadata_format").val();
        var data_level = 'metadata';
        if (selected_trials.length !== 0 ) {
            window.open("/breeders/trials/phenotype/download?trial_list="+JSON.stringify(selected_trials)+"&format="+format+"&dataLevel="+data_level);
        } else {
            alert("No filters selected for download.");
        }
    });

    jQuery('#download_button_genotypes').on('click', function (event) {
      event.preventDefault();
      var accession_ids = get_selected_results('accessions');
      var trial_ids = get_selected_results('trials');
      var protocol_id = get_selected_genotyping_protocols() ? get_selected_genotyping_protocols() : '';
        var ladda = Ladda.create(this);
        ladda.start();
        var token = new Date().getTime(); //use the current timestamp as the token name and value
        manage_dl_with_cookie(token, ladda);
        window.location.href = '/breeders/download_gbs_action/?ids='+accession_ids.join(",")+'&protocol_id='+protocol_id+'&gbs_download_token='+token+'&format=accession_ids&trial_ids='+trial_ids.join(",");
    });

    jQuery('#wizard_save_dataset_button').click( function() {
	jQuery('#save_wizard_dataset_dialog').modal("show");
    });

    jQuery('#wizard_save_dataset_submit_button').click( function() {
	var accessions = get_selected_results('accessions');
	var trials = get_selected_results('trials');
	var plots = get_selected_results('plots');
	var years = get_selected_results('years');
	var locations = get_selected_results('locations');
	var traits = get_selected_results('traits');
	var breeding_programs = get_selected_results('breeding_programs');
	var genotyping_protocols = get_selected_results('genotyping_protocols');
	var trial_types = get_selected_results('trial_types');
	var trial_designs = get_selected_results('trial_designs');
	var plants = get_selected_results('plants');
	var name = jQuery('#save_wizard_dataset_name').val();
	var description = jQuery('#save_wizard_dataset_description').val();
	var category_order = get_selected_categories(4);
	//alert(JSON.stringify(category_order));
	var params =  "accessions="+JSON.stringify(accessions)+"&trials="+JSON.stringify(trials)+"&plots="+JSON.stringify(plots)+"&years="+JSON.stringify(years)+"&locations="+JSON.stringify(locations)+"&traits="+JSON.stringify(traits)+"&breeding_programs="+JSON.stringify(breeding_programs)+"&genotyping_protocols="+JSON.stringify(genotyping_protocols)+"&trial_types="+JSON.stringify(trial_types)+"&trial_designs="+JSON.stringify(trial_designs)+"&plants="+JSON.stringify(plants)+"&name="+name+"&description="+description+"&category_order="+JSON.stringify(category_order);

	if (name === '' || name === undefined) {
	    alert('Please enter a name for the selection.');
	    return;
	}

	jQuery.ajax( {
	    'url': '/ajax/dataset/save?'+params,
            'method': 'POST',
	    'success' : function(response) {
		if (response.error) {
		    alert(response.error);
		}
		else {
	            alert("Successfully stored the dataset!");
		    jQuery('#save_wizard_dataset_dialog').modal("hide");
		    get_select_box('datasets', 'dataset_manage_select');
        
		}

	    },
            'error': function(response) {
	        alert("An error occurred.");
		jQuery('#save_wizard_dataset_dialog').modal("hide");
	    }
	});

    });
}

function addToggleIds () {
  for (i=2; i <= 4; i++) {
    var toggle_buttons = jQuery('#c'+i+'_querytype').next().children();
    toggle_buttons.first().attr( 'id', 'c'+i+'_querytype_and' );
    toggle_buttons.first().next().attr( 'id', 'c'+i+'_querytype_or' );
  }
}

function retrieve_and_display_set(categories, data, this_section, selected, dataset_id, callback) {
    if (window.console) console.log("categories = "+categories);
    if (window.console) console.log("data = "+JSON.stringify(data));
    if (window.console) console.log("this section="+this_section);
    if (window.console) console.log("selected = "+JSON.stringify(selected));

    jQuery.ajax( {
	url: '/ajax/breeder/search',
	timeout: 60000,
	method: 'POST',
	data: {'categories': categories, 'data': data, 'querytypes': get_querytypes(this_section)},
	    beforeSend: function(){
        if (!selected) {disable_ui();}
            },
            complete : function(){
              if (!selected) {enable_ui();}
            },
	    success: function(response) {
		if (response.error) {
		    var error_html = '<div class="well well-sm" id="response_error"><font color="red">'+response.error+'</font></div>';
		    var selectall_id = "c"+this_section+"_select_all";
		    jQuery('#'+selectall_id).before(error_html);
		}
		else {
        if (response.message) {
          var message_html = '<div class="well well-sm" id="response_error"><center><font color="orange">'+response.message+'</font></center></div>';
  		    var selectall_id = "c"+this_section+"_select_all";
  		    jQuery('#'+selectall_id).before(message_html);
        }
        var list = response.list || [];
		    data_html = format_options_list(list);
		    var data_id = "c"+this_section+"_data";
		    var count_id = "c"+this_section+"_data_count";
		    var listmenu_id = "c"+this_section+"_to_list_menu";
		    var select_id = "select"+this_section;

		    jQuery('#'+data_id).html(data_html);
        if (selected) {
          for (var n=0; n<selected.length; n++) {
            jQuery("#"+data_id+" option[value='"+selected[n]+"']").prop("selected", true);
          }
        }
        var data = jQuery('#'+data_id).val() || [];;
		    show_list_counts(count_id, list.length, data.length);
        update_download_options(this_section, categories);

		    if (jQuery('#navbar_lists').length) {
          addToListMenu(listmenu_id, data_id, {
            selectText: true,
            typeSourceDiv: select_id });
        }
        if (callback) {
          console.log("executing callback");
          callback(dataset_id, this_section+1);
        } else {
          console.log("finished panel"+data_id+", no more callbacks");
        }
      }
    },
	  error: function(request, status, err) {
		if (status == "timeout") {
                    // report timeout
		    var error_html = '<div class="well well-sm" id="response_error"><font color="red">Timeout error. Request could not be completed within 60 second time limit.</font></div>';
		    var selectall_id = "c"+this_section+"_select_all";
		    jQuery('#'+selectall_id).before(error_html);
		} else {
                    // report unspecified error occured
		    var error_html = '<div class="well well-sm" id="response_error"><font color="red">Error. If this problem persists, please <a href="../../contact/form">contact developers</a></font></div>';
		    var selectall_id = "c"+this_section+"_select_all";
		    jQuery('#'+selectall_id).before(error_html);
		}
            }

	});
}

function retrieve_and_display_sets(categories, data, this_section, selected) {
}

function get_selected_data(this_section) {
    var selected_data = [];

    for (i=1; i <= this_section; i++) {
	var element_id = "c"+i+"_data";
	var data = jQuery("#"+element_id).val();
	if (data) selected_data.push(data);
    }
    //if (window.console) console.log("selected data= "+JSON.stringify(selected_data));
    return selected_data;
}

function get_selected_categories(this_section) {
  var selected_categories = [];
  var select1 = jQuery('#select1').val();
  if (select1 === '') { // if starting category is undefined
    if (jQuery('#paste_list_list_select').val()) { // check to see if paste from list was used, if so get list type
	    select1 = jQuery('#paste_list_list_select').prop('title');
      //if (window.console) console.log("select1="+select1);
    }
  }
  selected_categories.push(select1);
  for (i=2; i <= this_section; i++) {
    var element_id = "select"+i;
    var category = jQuery("#"+element_id).val();
    if (category != '') { selected_categories.push(category) };
  }
  var next_section = this_section +1;
  var next_select_id = "select"+next_section;
  jQuery("#"+next_select_id).val('please select');
  //if (window.console) console.log("selected categories= "+JSON.stringify(selected_categories));
  return selected_categories;
}

function get_selected_results (type) {
    var max_section = 4;
    var selected = [];
    var categories = get_selected_categories(max_section);
    var data = get_selected_data(max_section);
    for (i=0; i < categories.length; i++) {
        if (categories[i] === type && data[i]) {
            selected = data[i];
        }
    }
    return selected;
}

function get_selected_genotyping_protocols () {
    var max_section = 4;
    var selected_genotyping_protocol;
    var categories = get_selected_categories(max_section);
    var data = get_selected_data(max_section);
    for (i=0; i < categories.length; i++) {
      if (categories[i] === 'genotyping_protocols' && data[i]) {
        selected_genotyping_protocol = data[i];
      }
    }
    if (selected_genotyping_protocol){
        if (selected_genotyping_protocol.length == 1) {
            return selected_genotyping_protocol;
        }
    }
}

function update_select_categories(this_section, selected_categories) {
    //console.log("selected_categories="+selected_categories);
    if (selected_categories === undefined) var selected_categories = get_selected_categories(this_section);
    var categories = { '': 'please select', accessions : 'accessions', breeding_programs: 'breeding_programs', genotyping_protocols : 'genotyping_protocols', locations : 'locations', plants : 'plants', plots : 'plots', seedlots: 'seedlots', trait_components : 'trait_components', traits : 'traits', trials : 'trials', trial_designs : 'trial_designs', trial_types : 'trial_types', years : 'years'};
    var all_categories = copy_hash(categories);

    for (i=0; i < this_section; i++) {
	delete all_categories[selected_categories[i]];
    }
    var remaining_categories = format_options(all_categories);
    var next_section = ++this_section;
    var next_select_id = "select"+next_section;

    jQuery('#'+next_select_id).html(remaining_categories);
}

function update_download_options(this_section, categories) {
    if (categories === undefined) var categories = get_selected_categories(this_section);
    var data = get_selected_data(this_section);
    var selected_trials = 0;
    var selected_accessions= 0;
    var selected_genotyping_protocols = 0;
    if (isLoggedIn()) {
        jQuery('#wizard_download_phenotypes_button').prop( 'title', 'Click to Download Trial Phenotypes');
        jQuery('#wizard_download_phenotypes_button').removeAttr('disabled');
        jQuery('#wizard_download_metadata_button').prop( 'title', 'Click to Download Trial Metadata');
        jQuery('#wizard_download_metadata_button').removeAttr('disabled');
    }

    for (i=0; i < categories.length; i++) {
	//if (categories[i]) {console.log("category ="+categories[i]);}
	//if (data !== undefined) {console.log("data ="+data[i]);}
      if (categories[i] === 'trials' && data[i]) {
        selected_trials = 1;
        var trial_html = '<font color="green">'+data[i].length+' trials selected</font></div>';
        jQuery('#selected_trials').html(trial_html);
        jQuery('#selected_trials_metadata').html(trial_html);
      }
      if (categories[i] === 'accessions' && data[i]) {
        selected_accessions = 1;
        var accession_html = '<font color="green">'+data[i].length+' accessions selected</font></div>';
        jQuery('#selected_accessions').html(accession_html);
      }
      if (categories[i] === 'genotyping_protocols' && data[i]) {
        selected_genotyping_protocols = 1;
        if (data[i].length > 1) {
          var genotyping_protocols_html = '<font color="red">'+data[i].length+' genotyping protocols selected</font></div>';
        }
        else {
          var genotyping_protocols_html = '<font color="green">'+data[i].length+' genotyping protocols selected</font></div>';
        }
        jQuery('#selected_genotyping_protocols').html(genotyping_protocols_html);
      }
    }
    if ( (selected_trials == 1 || selected_accessions == 1) && isLoggedIn()) {
      jQuery('#download_button_genotypes').prop( 'title', 'Click to Download Accession Genotypes');
	    jQuery('#download_button_genotypes').removeAttr('disabled');
    }
    //console.log("trials-selected="+trials_selected);
    //console.log("accessions-selected="+accessions_selected);
    if (selected_trials !== 1) {
      jQuery('#selected_trials').html('No trials selected');
      jQuery('#selected_trials_metadata').html('No trials selected');
    }
    if (selected_accessions !== 1) {
      jQuery('#selected_accessions').html('No accessions selected');
    }
    if (selected_genotyping_protocols !== 1) {
      jQuery('#selected_genotyping_protocols').html('No genotyping protocols selected. Default will be used.');
    }
}

function reset_downstream_sections(this_section) {  // clear downstream selects, data_panels, data_counts
    jQuery('#response_error').remove();
    for (i = 4; i > this_section; i--) {
	var select_id = "select"+i;
	var data_id = "c"+i+"_data";
	var count_id = "c"+i+"_data_count";
	var querytype_id = "c"+i+"_querytype";
  var list_menu_id = "c"+i+"_to_list_menu";
  var replacement = '<div id="'+list_menu_id+'"></div>';
	jQuery('#'+select_id).html('');
	jQuery('#'+data_id).html('');
	jQuery('#'+count_id).html('No Selection');
	jQuery('#'+querytype_id).bootstrapToggle('off');
  jQuery('#'+list_menu_id).replaceWith(replacement);
    }
}

function create_list_start(message) {
    var lo = new CXGN.List();
    var listhtml = lo.listSelect('paste_list', '', message, 'refresh', undefined);
    jQuery('#paste_list').html(listhtml);
    jQuery('#paste_list_list_select').change(
      function() {
        pasteList();
    });
}

function pasteDataset() {
  //if (window.console) console.log("pasting list . . .");
disable_ui();
  var dataset_id = jQuery('#paste_dataset_select').val();
  //var value = jQuery('#list_start_list_select').val();
  //if (window.console) console.log("list_start_list_select_val ="+value);
  if (dataset_id === '') {
    jQuery('#c1_data').html('');
    return;
  }
  else {
    replay_dataset_info(dataset_id, 1);
  }
  //enable_ui();
}

function pasteList() {
  //if (window.console) console.log("pasting list . . .");

  jQuery('#list_message').html('');
  var list_id = jQuery('#paste_list_list_select').val();
  //var value = jQuery('#list_start_list_select').val();
  //if (window.console) console.log("list_start_list_select_val ="+value);
  if (list_id === '') {
    jQuery('#c1_data').html('');
    return;
  }
  else {  // paste list by retrieving ids and combining them with list values in proper format
    //if (window.console) console.log("disabling ui . . .");
    disable_ui();
    var lo = new CXGN.List();
    var data = lo.getListData(list_id);
    var elements = data.elements;
    var options = [];
    //if (window.console) console.log("list_data="+JSON.stringify(data));

    if (data === undefined) {
      report_list_start_error("Unable to retrieve data from this list.");
      return;
    }

    if (data.type_name === '') {
      report_list_start_error("Unable to start from a list of type null.");
      return;
    }
    if (data.type_name === 'years') {
      for (var n=0; n<elements.length; n++) {
        options.push([elements[n][1], elements[n][1]]);
      }
    }
    else { // retrieve ids if they exist
      var ids = lo.transform2Ids(list_id, data);
      //if (window.console) console.log("list_ids="+JSON.stringify(ids));
      if (ids === undefined) {
        report_list_start_error("Unable to retrieve ids from this list. Has this list been validated using the list manager?");
        return;
      }
      for (var n=0; n<elements.length; n++) { // format ids and names of list elements to display
        options.push([ids[n], elements[n][1]]);
      }
    }
    c1_html = format_options_list(options);
    jQuery('#c1_data').html(c1_html);
    jQuery('#c1_data_text').html(retrieve_sublist(options, 1).join("\n"));

    // clear and reset all other wizard parts
    var this_section = 1;
    initialize_first_select();
    show_list_counts('c1_data_count', options.length);
    reset_downstream_sections(this_section);
    update_select_categories(this_section, data.type_name);
    update_download_options(this_section, data.type_name);

    if (jQuery('#navbar_lists').length) {
      addToListMenu('c1_to_list_menu', 'c1_data', {
        selectText: true,
        listType: data.type_name
      });
    }
    jQuery('#paste_list_list_select').prop('title', data.type_name);  // so get_selected_categories method doesn't have to retrieve list data everytime
    enable_ui();
  }
}

function report_list_start_error(error_message) {
  enable_ui();
  var error_html = '<div class="well well-sm"><font color="red">'+error_message+'</font></div>';
  jQuery('#list_message').html(error_html);
}

function format_options(items) {
    var html = '';
    for (var key in items) {
	html = html + '<option value="'+key+'" title="'+items[key]+'">'+items[key]+'</a>\n';
    }
    return html;
}

function retrieve_sublist(list, sublist_index) {
    var new_list = new Array();
    for(var i=0; i<list.length; i++) {
	new_list.push(list[i][sublist_index]);
    }
    return new_list;
}

function format_options_list(items) {
    var html = '';
    if (items) {
	for(var i=0; i<items.length; i++) {
	    html = html + '<option value="'+items[i][0]+'" title="'+items[i][1]+'">'+items[i][1]+'</a>\n';
	}
	return html;
    }
    return "no data";
}

function copy_hash(hash) {
    var new_hash = new Array();

    for (var key in hash) {
	new_hash[key] = hash[key];
    }
     return new_hash;
}

function disable_ui() {
    jQuery('#working_modal').modal("show");
}

function enable_ui() {
     jQuery('#working_modal').modal("hide");
}

function show_list_counts(count_div, total_count, selected) {
    var html = 'Items: '+total_count+'<br />';
    if (selected) {
	html += 'Selected: '+selected;
    }
    jQuery('#'+count_div).html(html);
}

function selectAllOptions(obj) {
    if (!obj || obj.options.length ==0) { return; }
    for (var i=0; i<obj.options.length; i++) {
      obj.options[i].selected = true;
    }
}

function clearAllOptions(obj) {
    if (!obj || obj.options.length ==0) { return; }
    for (var i=0; i<obj.options.length; i++) {
      obj.options[i].selected = false;
    }
}

function check_missing_criteria(categories, data, this_section) {
    var test = data.length + 1;
    if (categories.length > test) {
	var error_html = '<div class="well well-sm" id="response_error"><font color="red">Error: Select at least one option from each preceding panel</font></div>';
	var selectall_id = "c"+this_section+"_select_all";
	jQuery('#'+selectall_id).before(error_html);
	return 1;
    } else {
	return 0;
    }
}

function get_querytypes(this_section) {
    var querytypes = [];

    for (i=2; i <= this_section; i++) {
	var element_id = "c"+i+"_querytype";
	if (jQuery('#'+element_id).is(":checked")) {
	    var type = 1;
	} else {
	    var type = 0;
	}
	//if (window.console) console.log("querytype="+type);
	querytypes.push(type);
    }
    if (querytypes.length > 0) {
    return querytypes;
    }
}

function initialize_first_select() {
  var starting_categories = { '': 'Select a starting category', accessions: 'accessions', breeding_programs: 'breeding_programs', genotyping_protocols : 'genotyping_protocols', locations : 'locations', seedlots: 'seedlots', trait_components : 'trait_components', traits : 'traits', trials : 'trials', trial_designs : 'trial_designs', trial_types : 'trial_types', years : 'years'};
  var start = format_options(starting_categories);
  jQuery('#select1').html(start);
}

function add_data_refresh() {
    var roles = getUserRoles();
    //console.log("userroles="+roles);
    if (jQuery.inArray(roles, ['submitter', 'curator', 'sequencer']) >= 0) {
	jQuery('#wizard_refresh').append('<p align="center" style="margin: 0px 0"><i>Don\'t see your data?</i></p><input class="btn btn-link center-block" id="open_update_dialog" type="button" value="Update wizard">');
    }
}

// matview_select is either:
// "fullview" for refreshing materialized phenoview, genoview, traits, and stockprop
// "stockprop" for refreshing materialized stockprop
function refresh_matviews(matview_select) {
    jQuery.ajax( {
	url: '/ajax/breeder/refresh?matviews='+matview_select,
	timeout: 60000,
	method: 'POST',
	beforeSend: function() {
	    jQuery('#update_wizard').button('loading');
	},
	success: function(response) {
		if (response.error) {
		    var error_html = '<div class="well well-sm" id="update_wizard_error"><font color="red">'+response.error+'</font></div>';
		    jQuery('#update_wizard_error').replaceWith(error_html);
		} else {
		    var success_html = '<div class="well well-sm" id="update_wizard_error"><font color="green">'+response.message+'</font></div>';
		    jQuery('#update_wizard_error').replaceWith(success_html);
		    matviews_update_options();
		}
	    },
	error: function(request, status, err) {
		if (status == "timeout") {
                    // report timeout
		    var error_html = '<div class="well well-sm" id="update_wizard_error"><font color="red">Timeout error. Request could not be completed within 60 second time limit.</font></div>';
		    jQuery('#update_wizard_error').replaceWith(error_html);
		} else {
                    // report unspecified error occured
		    var error_html = '<div class="well well-sm" id="update_wizard_error"><font color="red">Unspecified error. If this problem persists, please <a href="../../contact/form">contact developers</a></font></div>';
		    jQuery('#update_wizard_error').replaceWith(error_html);
		}
            }
    });
}

function matviews_update_options() {
    jQuery.ajax( {
	url: '/ajax/breeder/check_status',
	timeout: 60000,
	method: 'POST',
	success: function(response) {
		if (response.refreshing) {
		    // if already refreshing, display status in modal and create disabled button
	            var update_status = response.refreshing;
		    jQuery('#wizard_status').replaceWith(update_status);
		    var button_html = '<button type="button" class="btn btn-primary wiz-update" name="update_wizard" data-loading-text="Working..." id="update_wizard" title="A search wizard update is already in progress..." disabled>Update search wizard</button>';
		    jQuery('#update_wizard').replaceWith(button_html);
		} else if (response.timestamp) {
		    // if exists display timestamp in modal and create button
		    var update_status = response.timestamp;
		    jQuery('#wizard_status').replaceWith(update_status);
		    var button_html = '<button type="button" class="btn btn-primary wiz-update" name="update_wizard" data-loading-text="Working..." id="update_wizard" title="Refresh the search wizard to include newly uploaded data">Update search wizard</button>';
		    jQuery('#update_wizard').replaceWith(button_html);
		}
	    },
	error: function(request, status, err) {
		if (status == "timeout") {
                    // report timeout
		    var error_html = '<div class="well well-sm" id="wizard_status"><font color="red">Timeout error. Request could not be completed within 60 second time limit.</font></div>';
		    jQuery('#wizard_status').replaceWith(error_html);
		} else {
                    // report unspecified error occured
		    var error_html = '<div class="well well-sm" id="wizard_status"><font color="red">Unspecified error. If this problem persists, please <a href="../../contact/form">contact developers</a></font></div>';
		    jQuery('#wizard_status').replaceWith(error_html);
		}
            }
    });
}

function manage_dl_with_cookie (token, ladda) {
  var cookie = 'download'+token;
  var fileDownloadCheckTimer = window.setInterval(function () { //checks for response cookie to keep working modal enabled until file is ready for download
    var cookieValue = jQuery.cookie(cookie);
    //console.log("cookieValue="+cookieValue);
    //var allCookies = document.cookie;
    //console.log("allCookies="+allCookies);
    if (cookieValue == token) {
      window.clearInterval(fileDownloadCheckTimer);
      jQuery.removeCookie(cookie); //clears this cookie value
      ladda.stop();
    }
  }, 500);
}

function replay_dataset_info(dataset_id, section_number) {
    if (!dataset_id) { return; }
    var d = new CXGN.Dataset();
    var dataset = d.getDataset(dataset_id);

    var category_order = dataset.category_order;
    if (!category_order) {
	category_order = Object.keys(dataset.categories);
    }
    var i = section_number - 1;
    var category = category_order[i];
  	jQuery('#select'+section_number).val(category);
  reset_downstream_sections(section_number);
  update_select_categories(section_number);

  var categories = get_selected_categories(section_number);
  var data = ''
  if (section_number !== "1") data = get_selected_data(section_number);
  var error = check_missing_criteria(categories, data, section_number); // make sure criteria selected in each panel
  if (error) return;
  if (data.length >= categories.length) data.pop(); //remove extra data array if exists
  var selected = dataset.categories[category_order[i]];
  var next_section_number = section_number + 1;
  if (section_number < category_order.length) {
    retrieve_and_display_set(categories, data, section_number, selected, dataset_id, replay_dataset_info);
  } else {
    retrieve_and_display_set(categories, data, section_number, selected);
    enable_ui();
  }
}
