window.onload = function initialize() { 

    jQuery('input[type="checkbox"]').on('change', function() {  // ensure only one checkbox is selected at a time
	jQuery('input[id="' + this.id + '"]').not(this).prop('checked', false);
    });

    jQuery('#select1, #select2, #select3, #select4').change(  // retrieve new data once new category is selected
    	function() {
	    var this_section = jQuery(this).attr('name');
	    reset_downstream_sections(this_section);
	    update_select_categories(this_section);
	    if (jQuery(this).val() == '') { // return empty if no category defined
		var data_element = "c"+this_section+"_data";
		jQuery("#"+data_element).html("");
		return;
	    }
	    retrieve_and_display_set(get_selected_categories(this_section), get_selected_data(this_section), this_section);
	});

    jQuery('#c1_data, #c2_data, #c3_data, #c4_data').change( // update wizard panels and categories when data selections change 
    	function() {
	    var this_section = jQuery(this).attr('name');
	    var current_section = this_section;

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
}

function retrieve_and_display_set(categories, data, this_section) {
    if (window.console) console.log("categories = "+categories);
    if (window.console) console.log("data = "+JSON.stringify(data));
    if (window.console) console.log("genotypes="+get_genotype_checkbox());
    if (window.console) console.log("retrieval types="+get_retrieval_types());
    jQuery.ajax( {
	url: '/ajax/breeder/search',
	timeout: 60000,
	method: 'POST',
	data: {'categories': categories, 'data': data, 'genotypes': get_genotype_checkbox(), 'retrieval_types': get_retrieval_types()},
	    beforeSend: function(){
		disable_ui();
            },  
            complete : function(){
		enable_ui();
            },  
	    success: function(response) { 
		if (response.error) { 
		    alert("ERROR: "+response.error);
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

    for (i=1; i < this_section; i++) {
	var element_id = "c"+i+"_data";
	var data = jQuery("#"+element_id).val();
	selected_data.push(data);
    }

    var this_data_id = "c"+this_section+"_data";
    jQuery("#"+this_data_id).val('');
    if (window.console) console.log("selected data= "+JSON.stringify(selected_data));
    if (selected_data.length > 0) {
    return selected_data;
    }
}

function get_selected_categories(this_section) {

    var selected_categories = [];
    var select1 = jQuery('#select1').val();
    if (select1 === '') { // if paste from list was used at start instead of select then get list type
	var list_id = jQuery('#c1_data_list_select').val();
	var lo = new CXGN.List();
	var list_data = lo.getListData(list_id);
	select1 = list_data.type_name;
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
    if (window.console) console.log("selected categories= "+JSON.stringify(selected_categories));
    return selected_categories;
}

function update_select_categories(this_section) {
    var selected_categories = get_selected_categories(this_section);
    
    var categories = { '': 'please select', accessions : 'accessions', breeding_programs: 'breeding_programs', locations : 'locations', plots : 'plots', traits : 'traits', trials :'trials', years : 'years'};
    var all_categories = copy_hash(categories);

    for (i=0; i < this_section; i++) {
	delete all_categories[selected_categories[i]];
    }
    var remaining_categories = format_options(all_categories);
    var next_section = ++this_section;
    var next_select_id = "select"+next_section;

    jQuery('#'+next_select_id).html(remaining_categories);
}
	
function reset_downstream_sections(this_section) {  // clear downstream selects, data_panels, data_counts
    for (i = 4; i > this_section; i--) {
	var select_id = "select"+i;
	var data_id = "c"+i+"_data";
	var count_id = "c"+i+"_data_count";
	jQuery('#'+select_id).html('');
	jQuery('#'+data_id).html('');
	jQuery('#'+count_id).html('');
    }
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

function get_genotype_checkbox() { 
    var checkbox = jQuery('#restrict_genotypes').is(':checked')

    if (checkbox == true) {
	return jQuery("#gtp_select").val();
    }
    return 0;

}

function get_retrieval_types() { 

}