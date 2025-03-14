

function init_tree(tree_type) {
    var last_refresh_date = localStorage.getItem(tree_type);
    alert("Last refresh timestamp = "+last_refresh_date);

    if (last_refresh_date === null) { alert("refresh date is not set"); }

    jQuery.ajax( {
    	url: '/ajax/breeders/recently_modified_projects',
	data: { since_date: last_refresh_date, type: tree_type },
    }).then( function(r) { alert("NEW TRIALS: "+JSON.stringify(r)); if (r.data.length > 0) { get_html_tree(tree_type).then( function(r) { alert("setting new tree"); format_html_tree(r.html)  } )} } ) ;
    

    alert('get tree from local storage...');
    var html = localStorage.getItem(tree_type);
    if (html !== null) {
	alert("HTML NOW: "+html);
	format_html_tree(html);
    }

    if (html === null) {
	alert('HTML NOT DEFINED! FETCHING...');
	get_html_tree(tree_type).then( function(r) { 
	    html = localStorage.getItem('html_trial_tree');
	    format_trial_tree(html);
	});
    }


}


function init_events(tree_type) { 
    jQuery('#refresh_'+tree_type+'_button').click(function(){
	alert('hello!');
	get_trial_tree(tree_type).then( function(r) { alert('now loading new tree'); format_trial_tree(r.html) });
	
    });


      jQuery('#'+tree_type+'_list').on("changed.jstree", function (e, data) {
    //console.log(data);
       if ($('#'+tree_type+'_list').jstree('is_leaf', data.node) && data.node.data.jstree.type == tree_type) {
         jQuery('#'+tree_type+'_download_phenotypes_button').removeAttr('disabled');
         jQuery("#folder_edit_options").hide();
       }
       else if ($('#'+tree_type+'_list').jstree('is_leaf', data.node) && data.node.data.jstree.type == 'folder') {
           jQuery('#'+tree_type+'_download_phenotypes_button').attr('disabled', 'disabled');
         jQuery("#folder_edit_options").show();
       }
       else {
         jQuery('#'+tree_type+'_download_phenotypes_button').attr('disabled', 'disabled');
         jQuery("#folder_edit_options").hide();
       }
    });


    $("#'+tree_type+'_list").delegate("li", "dblclick", function(event){
      var node = $("#"+tree_type+"_list").jstree("get_node", this);
      //console.log(node);
      if (node.id.substr(0,1) !== 'j') {
        if (node.type == 'folder') {
            window.open('/folder/'+node.id);
            event.stopPropagation();
        } else if (node.type == 'breeding_program') {
            window.open('/breeders/program/'+node.id);
            event.stopPropagation();
        } else if (node.type == 'analyses') {
            window.open('/analyses/'+node.id);
            event.stopPropagation();
        } else if (node.type == 'trial') {
            window.open('/breeders_toolbox/trial/'+node.id);
            event.stopPropagation();
        } else if (node.type == 'sampling_trial') {
            window.open('/breeders_toolbox/trial/'+node.id);
            event.stopPropagation();
        }
      }
    });

    jQuery("#"+tree_type+"_search").keyup(function() {
        var v = jQuery("#"+tree_type+"_tree_search").val();
        jQuery("#"+tree_type+"_list").jstree(true).search(v);
    });

});


function get_timestamp() {
    var today = new Date();
    var dd = String(today.getDate()).padStart(2, '0');
    var mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
    var yyyy = today.getFullYear();
    var timestamp = yyyy + '-'+ mm + '-' + dd;
    return timestamp;
}

    
function get_trial_tree(tree_type) {
    alert('get_trial_tree');
    return jQuery.ajax( {
	url: '/ajax/breeders/get_trials_with_folders_cached?type='+tree_type,  
    }).then(  function(r) {
	alert("adding new html and timestamp to localstorage");
	localStorage.setItem(tree_type, r.html);
	localStorage.setItem(tree_type+'_last_refresh', get_timestamp());
    });
}

function format_trial_tree(treehtml) {

    var html = '<ul>'+treehtml+'</ul>';
    
    jQuery('#trial_list').html(html);
    
    //console.log(html);
    jQuery('#trial_list').jstree( {
	"core": { 'themes': { 'name': 'proton', 'responsive': true}},
	"valid_children" : [ "folder", "trial", "breeding_program", "analyses", "sampling_trial" ],
	"types" : {
	    "breeding_program" : {
		"icon": 'glyphicon glyphicon-briefcase text-info',
	    },
	    "folder" : {
		"icon": 'glyphicon glyphicon-folder-open text-danger',
	    },
	    "trial" : {
		"icon": 'glyphicon glyphicon-leaf text-success',
	    },
	    "analyses" : {
		"icon": 'glyphicon glyphicon-stats text-success',
	    },
	    "sampling_trial" : {
		"icon": 'glyphicon glyphicon-th text-success',
	    }
	},
	"search" : {
	    "case_insensitive" : true,
	},
	"plugins" : ["html_data","types","search"],
	
    });
    
}



