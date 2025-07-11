
import '../legacy/jquery.js';
import '../legacy/d3/d3Min.js';

var version = '0.01';

export function init(tree_type, hard_refresh) {

    alert("STARTING..."+tree_type+" refresh="+hard_refresh);
    
    init_events(tree_type);
    // check if we have no last refresh date or hard_refresh is true
    // fetch the tree from the back end and store it in the browser
    //
    alert("HARD REFRESH: "+hard_refresh);
    var last_refresh_date = localStorage.getItem(tree_type+'_last_refresh');
    alert("Last refresh timestamp: "+last_refresh_date);

    if (hard_refresh === 1) {
	alert("refresh date is not set or hard_refresh is 1");
	jQuery.ajax({ 
	    url: '/ajax/breeders/recently_modified_projects',
	    data: { 'type' : tree_type, 'hard_refresh' : hard_refresh },
	}).then( function(r) {
	    alert("NEW TRIALS: "+JSON.stringify(r));

	    if (r.data.length > 0) {
		get_html_tree(tree_type).then( function(r) { alert("setting new tree 1"+JSON.stringify(html)); format_html_tree(html, tree_type); }, alert(r) )
	    }    
	});
    }
    else if (last_refresh_date !== undefined) { 
	alert('TREE TYPE: '+tree_type);
	
	jQuery.ajax( {
    	    url: '/ajax/breeders/recently_modified_projects',
	    data: { since_date: last_refresh_date, type: tree_type },
	}).then( function(r) { alert("NEW TRIALS: "+JSON.stringify(r)); if (r.data.length > 0) { get_html_tree(tree_type).then( function(r) { alert("setting new tree 2"); format_html_tree(r.html, tree_type); } ); } } );
	

	//alert('get tree from local storage 2...');
	
//	}
	//if (html !== null) {
	//    alert("HTML NOW 2: "+html);
	//get_html_tree(tree_type).then( function(r) { 
	  //  format_html_tree(html, tree_type);
	//});
    //}
	
	alert('Done with local storage...');
	
    }
    else {
	var html = localStorage.getItem(tree_type);
    }

    if (html === null) {
	alert('HTML NOT DEFINED! FETCHING...');
	get_html_tree(tree_type).then( function(r) { 
	    html = localStorage.getItem(tree_type);
	    format_html_tree(html, tree_type);
	});
    }
    alert('Done with init');
}

export function init_events(tree_type) {
    alert('TREE TYPE: '+tree_type);
    jQuery('#refresh_'+tree_type+'_button').click(function(){
	alert('hello!');
	get_html_tree(tree_type).then( function(r) { alert('now loading new tree'); format_html_tree(r.html, tree_type) });
	
    });


      jQuery('#'+tree_type+'_list').on("changed.jstree", function (e, data) {
    //console.log(data);
       if (jQuery('#'+tree_type+'_list').jstree('is_leaf', data.node) && data.node.data.jstree.type == tree_type) {
         jQuery('#'+tree_type+'_download_phenotypes_button').removeAttr('disabled');
         jQuery("#folder_edit_options").hide();
       }
       else if (jQuery('#'+tree_type+'_list').jstree('is_leaf', data.node) && data.node.data.jstree.type == 'folder') {
           jQuery('#'+tree_type+'_download_phenotypes_button').attr('disabled', 'disabled');
         jQuery("#folder_edit_options").show();
       }
       else {
         jQuery('#'+tree_type+'_download_phenotypes_button').attr('disabled', 'disabled');
         jQuery("#folder_edit_options").hide();
       }
    });


    jQuery('#'+tree_type+'_list').delegate("li", "dblclick", function(event){
      var node = jQuery('#'+tree_type+'_list').jstree("get_node", this);
      console.log(node);
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

    jQuery('#'+tree_type+'_search').keyup(function() {
        var v = jQuery('#'+tree_type+'_tree_search').val();
        jQuery('#'+tree_type+'_list').jstree(true).search(v);
    });

}


export function get_timestamp() {
    var today = new Date();
    var dd = String(today.getDate()).padStart(2, '0');
    var mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
    var yyyy = today.getFullYear();
    var timestamp = yyyy + '-'+ mm + '-' + dd;
    return timestamp;
}

    
export function get_html_tree(tree_type) {
    alert('get_html_tree with tree type '+tree_type);
    return jQuery.ajax( {
	url: '/ajax/breeders/get_trials_with_folders?type='+tree_type,  
    }).then(  function(r) {
	alert("adding new html and timestamp to localstorage" + r.html);
	localStorage.setItem(tree_type, r.html);
	localStorage.setItem(tree_type+'_last_refresh', get_timestamp());

	return new Promise((resolve, reject) => {
	    if (r.html) {
		alert('RHTML IN GET_HTEML_TREE '+r.html);
		resolve(r.html);
	    }
	    else {
		alert("REJECTING EVERYTHING!!!!!");
		reject('an error occurred in get_html_tree');
	    }
	}
			  );
    }
	   );
}

export function format_html_tree(treehtml, tree_type) {

    var html = '<ul>'+treehtml+'</ul>';

    alert('format_html_tree with TREE TYPE = '+tree_type);

    alert('html now: '+html);

    jQuery('#'+tree_type+'_list').html(html);
    
    alert("NEW HTML = "+html);
    jQuery('#'+tree_type+'_list').jstree( {
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



