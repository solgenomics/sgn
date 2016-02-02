window.onload = function initialize() { 

    var starting_categories = { '': 'Select a starting category', breeding_programs: 'breeding_programs', genotyping_protocols : 'genotyping_protocols', locations : 'locations', traits : 'traits', trials :'trials', years : 'years'};
    var start = format_options(starting_categories);

    jQuery('#select1').html(start);  
  
    jQuery('select').mouseenter(function() {this.tooltip});

    if (!isLoggedIn()) {

       create_list_start('Login to start from a list');

       jQuery('#c1_to_list_menu').html('<div class="well well-sm">Login to use lists</div>');
       jQuery('#c2_to_list_menu').html('<div class="well well-sm">Login to use lists</div>');
       jQuery('#c3_to_list_menu').html('<div class="well well-sm">Login to use lists</div>');
       jQuery('#c4_to_list_menu').html('<div class="well well-sm">Login to use lists</div>');

    } else {

      create_list_start('Start from a list');

      addToListMenu('c1_to_list_menu', 'c1_data', { 
        selectText: true,
        typeSourceDiv: 'select1',
      });
      addToListMenu('c2_to_list_menu', 'c2_data', { 
        selectText: true,
        typeSourceDiv: 'select2',
      });
      addToListMenu('c3_to_list_menu', 'c3_data', { 
        selectText: true,
        Typesourcediv: 'select3',
       });      
      addToListMenu('c4_to_list_menu', 'c4_data', { 
        selectText: true,
        typeSourceDiv: 'select4',
       });
    }

    jQuery('#select1').change( // reset start from list if select1 changes
	function() {
	    var startlist = jQuery('#c1_data_list_select').val();
	    if (startlist) {
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
	});

    jQuery('#c1_data, #c2_data, #c3_data, #c4_data').change( // update wizard panels and categories when data selections change 
    	function() {
	    var this_section = jQuery(this).attr('name');
	    update_download_options(this_section);

	    var data_id = jQuery(this).attr('id');
	    var data = jQuery('#'+data_id).val() || [];;
	    var count_id = "c"+this_section+"_data_count";

	    reset_downstream_sections(this_section);
	    update_select_categories(this_section);
	    show_list_counts(count_id, jQuery('#'+data_id).text().split("\n").length-1, data.length);
	});		 

    jQuery('#c1_select_all, #c2_select_all, #c3_select_all, #c4_select_all').click( // select all data in a wizard panel 
    	function() { 
	    var this_section = jQuery(this).attr('name');
	    var data_id = "c"+this_section+"_data";
	    selectAllOptions(document.getElementById(data_id));

	    var data = jQuery("#"+data_id).val() || [];;
	    var count_id = "c"+this_section+"_data_count";

	    show_list_counts(count_id, jQuery('#'+data_id).text().split("\n").length-1, data.length);
	    update_select_categories(this_section);
	});

      jQuery('select').dblclick(function() { // open detail page in new window or tab on double-click 
	  var this_section = jQuery(this).attr('name');
	  var categories = get_selected_categories(this_section);
	  var category = categories.pop();
	  switch (category)
	  {
	  case "accessions":
	  case "plots":
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
	  case "traits":
	      window.open("../../chado/cvterm?action=view&cvterm_id="+this.value);
	      break;
	  default: 
	      if (window.console) console.log("no link for this category");
	  }
      });
    
    
    jQuery('#download_button_excel').on('click', function () {
        var selected = get_selected_trials();
        if (selected.length !== 0) { 
	  window.open('/breeders/trials/phenotype/download/'+selected.join(","));
        }
        else { alert("No trials selected for download."); }
       
    });

    jQuery('#download_button_csv').on('click', function () {
        var selected = get_selected_trials();
        if (selected.length !== 0) { 
	  window.open('/breeders/trials/phenotype/download/'+selected.join(",")+'?format=csv');
        }
        else { alert("No trials selected for download."); }
       
    });
}

function retrieve_and_display_set(categories, data, this_section) {
    if (window.console) console.log("categories = "+categories);
    if (window.console) console.log("data = "+JSON.stringify(data));
    //if (window.console) console.log("querytypes="+get_querytypes(this_section));
    jQuery.ajax( {
	url: '/ajax/breeder/search',
	timeout: 60000,
	method: 'POST',
	data: {'categories': categories, 'data': data, 'querytypes': get_querytypes(this_section)},
	    beforeSend: function(){
		disable_ui();
            },  
            complete : function(){
		enable_ui();
            },  
	    success: function(response) { 
		if (response.error) {
		    var error_html = '<div class="well well-sm" id="response_error"><font color="red">'+response.error+'</font></div>';
		    var selectall_id = "c"+this_section+"_select_all";
		    jQuery('#'+selectall_id).before(error_html);
		} 
		else {
                    var list = response.list || [];
		    data_html = format_options_list(list);
		    var data_id = "c"+this_section+"_data";
		    var count_id = "c"+this_section+"_data_count";
		    var listmenu_id = "c"+this_section+"_to_list_menu";
		    var select_id = "select"+this_section;
		    
		    jQuery('#'+data_id).html(data_html);
		    show_list_counts(count_id, list.length);

		    if (isLoggedIn()) { 
			addToListMenu(listmenu_id, data_id, {
			    selectText: true,
			    typeSourceDiv: select_id });
		    }
		}	
	    } 
	
	});		
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
	var list_id = jQuery('#c1_data_list_select').val();
	if (list_id) { // check to see if paste from list was used, if so get list type
	    var list_id = jQuery('#c1_data_list_select').val();
	    var lo = new CXGN.List();
	    var list_data = lo.getListData(list_id);
	    select1 = list_data.type_name;
	}
    }
    selected_categories.push(select1);
    for (i=2; i <= this_section; i++) {
	var element_id = "select"+i;
	var category = jQuery("#"+element_id).val();
	selected_categories.push(category);
    }
    var next_section = this_section +1;
    var next_select_id = "select"+next_section;
    jQuery("#"+next_select_id).val('please select');
    //if (window.console) console.log("selected categories= "+JSON.stringify(selected_categories));
    return selected_categories;
}

function get_selected_trials () {
    var max_section = 4;
    var selected_trials;
    var categories = get_selected_categories(max_section);
    var data = get_selected_data(max_section);
    for (i=0; i < categories.length; i++) {
	if (categories[i] === 'trials' && data[i]) {
	    selected_trials = data[i];
	} else {
	}
    }
    if (selected_trials.length > 0) {
	return selected_trials;
    } else {
	alert("No trials selected");
    }
}

function update_select_categories(this_section) {
    var selected_categories = get_selected_categories(this_section);
    
    var categories = { '': 'please select', accessions : 'accessions', breeding_programs: 'breeding_programs', genotyping_protocols : 'genotyping_protocols', locations : 'locations', plots : 'plots', traits : 'traits', trials :'trials', years : 'years'};
    var all_categories = copy_hash(categories);

    for (i=0; i < this_section; i++) {
	delete all_categories[selected_categories[i]];
    }
    var remaining_categories = format_options(all_categories);
    var next_section = ++this_section;
    var next_select_id = "select"+next_section;

    jQuery('#'+next_select_id).html(remaining_categories);
}

function update_download_options(this_section) {
    var categories = get_selected_categories(this_section);
    var data = get_selected_data(this_section);
    var trials_selected = 0;
    for (i=0; i < categories.length; i++) {
	//if (categories[i]) {console.log("category ="+categories[i]);}
	//if (data !== undefined) {console.log("data ="+data[i]);}
	if (categories[i] === 'trials' && data[i]) {
	    trials_selected = 1;
	    jQuery('#download_button_excel').prop( 'title', 'Click to Download Trial Phenotypes');
	    jQuery('#download_button_csv').prop('title', 'Click to Download Trial Phenotypes');
	    jQuery('#download_button_excel').removeAttr('disabled');
	    jQuery('#download_button_csv').removeAttr('disabled');
	}
    }
    if (trials_selected !== 1) {
	jQuery('#download_button_excel').prop('title','First Select a Trial to Download');
	jQuery('#download_button_csv').prop('title', 'First Select a Trial to Download');
	jQuery('#download_button_excel').attr('disabled', 'disabled');
	jQuery('#download_button_csv').attr('disabled', 'disabled');
    }
}

	
function reset_downstream_sections(this_section) {  // clear downstream selects, data_panels, data_counts
    jQuery('#response_error').remove();
    for (i = 4; i > this_section; i--) {
	var select_id = "select"+i;
	var data_id = "c"+i+"_data";
	var count_id = "c"+i+"_data_count";
	var querytype_id = "c"+i+"_querytype";
	jQuery('#'+select_id).html('');
	jQuery('#'+data_id).html('');
	jQuery('#'+count_id).html('');
	jQuery('#'+querytype_id).bootstrapToggle('off');
    }
}

function create_list_start(message) {
    var lo = new CXGN.List();
    var listhtml = lo.listSelect('c1_data', '', message);
    jQuery('#paste_list').html(listhtml);
    jQuery('#paste_list').change(
    function() { // if 'select a list', reinitialize, otherwise
	
		   pasteList('c1_data');
    });
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
	if (window.console) console.log("querytype="+type);
	querytypes.push(type);
    }
    if (querytypes.length > 0) {
    return querytypes;
    }
}