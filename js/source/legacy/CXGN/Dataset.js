function escapeDatasetHtml(value) {
    return String(value).replace(/[&<>"']/g, function (character) {
        return { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[character];
    });
}


var CXGN;
if (!CXGN) CXGN = function () { };

CXGN.Dataset = function () {
    this.dataset = [];
};


CXGN.Dataset.prototype = {

    // return info on all available datasets
    getDatasets: function() {
	var datasets=[];
	jQuery.ajax( {
	    'url' : '/ajax/dataset/by_user',
	    'async': false,
	    'success': function(response) {
		if (response.error) {
		    //alert(response.error);
		}
		    datasets = response;

	    },
            'error': function(response) {
		alert((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.network_error", "An error occurred. Please try again.") : "An error occurred. Please try again."));
	    }
	});
	return datasets;
    },

    // return info on public datasets
    getPublicDatasets: function() {
        var datasets=[];
        jQuery.ajax( {
            'url' : '/ajax/dataset/get_public',
            'async': false,
            'success': function(response) {
                if (response.error) {
                    //alert(response.error);
                }
                    datasets = response;

            },
            'error': function(response) {
                alert((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.network_error", "An error occurred. Please try again.") : "An error occurred. Please try again."));
            }
        });
        return datasets;
    },

    getDataset: function(id) {
	var dataset;
	jQuery.ajax( {
	    "url" : "/ajax/dataset/get/"+id,
	    "async": false,
	    "success": function(response) {
		if (response.error) {
		    alert(response.error);
		}
		else {
		    dataset = response.dataset;
		}
	    },
	    "error": function(response) {
		alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.get_error", "An error occurred. The specified dataset may not exist. Please try again.%{response}", {response: JSON.stringify(response)}) : "An error occurred. The specified dataset may not exist. Please try again."+JSON.stringify(response));
	    }
	});
	return dataset;

    },

    deleteDataset: function(id, callback) {
      	var dataset;
        jQuery.ajax( {
            'url' : '/ajax/dataset/delete/'+id,
            'async': false,
            'success': function(response) {
                if (response.error) {
                    alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.delete_error", "An error occurred during dataset deletion. %{error}", {error: String(response.error)}) : "An error occurred during dataset deletion. "+response.error);
                }
                else {
                    if ( callback ) {
                        return callback();
                    }
                    else {
                        alert((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.delete_success", "The dataset has been deleted.") : "The dataset has been deleted."));
                    }
                }
            },
            'error': function(response) {
                alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.dataset_missing_error", "An error occurred. The specified dataset may not exist. Please try again.%{response}", {response: JSON.stringify(response)}) : "An error occurred. The specified dataset may not exist. Please try again."+JSON.stringify(response));
            }
        });
    },

    makePublicDataset: function(id, callback) {
        var dataset;
        jQuery.ajax( {
            'url' : '/ajax/dataset/set_public/'+id,
            'async': false,
            'success': function(response) {
                if (response.error) {
                    alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.action_error", "An error occurred during action. %{error}", {error: String(response.error)}) : "An error occurred during action. "+response.error);
                } else {
                    if ( callback ) {
                        return callback();
                    }
                    else {
                        alert((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.public_success", "The dataset is now public.") : "The dataset is now public."));
                    }
                }
            },
            'error': function(response) {
                alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.dataset_missing_error", "An error occurred. The specified dataset may not exist. Please try again.%{response}", {response: JSON.stringify(response)}) : "An error occurred. The specified dataset may not exist. Please try again."+JSON.stringify(response));

            }
        });
    },

   makePrivateDataset: function(id, callback) {
        var dataset;
        jQuery.ajax( {
            'url' : '/ajax/dataset/set_private/'+id,
            'async': false,
            'success': function(response) {
                if (response.error) {
                    alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.action_error", "An error occurred during action. %{error}", {error: String(response.error)}) : "An error occurred during action. "+response.error);
                } else {
                    if ( callback ) {
                        return callback();
                    }
                    else {
                        alert((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.private_success", "The dataset is now private.") : "The dataset is now private."));
                    }
                }
            },
            'error': function(response) {
                alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.dataset_missing_error", "An error occurred. The specified dataset may not exist. Please try again.%{response}", {response: JSON.stringify(response)}) : "An error occurred. The specified dataset may not exist. Please try again."+JSON.stringify(response));

            }
        });
    },

    updateDescription: function(id, callback) {
	var dataset;
	var description = document.getElementById('description').value
        jQuery.ajax( {
            'url' : '/ajax/dataset/update_description/'+id,
            'async': false,
	    'dataType': "json",
            'data': {
                'description': description
             },

            'success': function(response) {
                if (response.error) {
                    alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.action_error", "An error occurred during action. %{error}", {error: String(response.error)}) : "An error occurred during action. "+response.error);
                } else {
                    if ( callback ) {
                        callback(description)
                    }
                    else {
                        alert((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.description_updated", "The dataset description has been updated.") : "The dataset description has been updated."));
                    }
                }
            },
            'error': function(response) {
                alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.description_update_error", "An error occurred. The dataset description could not be updated. Please try again.%{response}", {response: JSON.stringify(response)}) : "An error occurred. The dataset description could not be updated. Please try again."+JSON.stringify(response));

            }
        });
    },

    datasetSelect: function(div_name, empty_element, refresh) {

  var datasets = new Array();
  datasets = this.getDatasets();
  var html = '<select class="form-control input-sm" id="'+div_name+'_dataset_select" name="'+div_name+'_dataset_select" >';
  if (empty_element) {
      html += '<option value="">'+empty_element+'</option>\n';
        }
  for (var n=0; n<datasets.length; n++) {
      html += '<option value='+datasets[n][0]+'>'+datasets[n][1]+'</option>';
  }
  if (refresh) {
    var refreshTitle = escapeDatasetHtml(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.refresh_title", "Refresh datasets") : "Refresh datasets");
    var refreshedMessage = escapeDatasetHtml(JSON.stringify(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.refresh_done", "Options refreshed.") : "Options refreshed."));
    html = '<div class="input-group">'+html+'</select><span class="input-group-btn"><button class="btn btn-default" type="button" id="'+div_name+'_dataset_refresh" title="'+refreshTitle+'" onclick="refreshDatasetSelect(\''+div_name+'_dataset_select\','+refreshedMessage+')"><span class="glyphicon glyphicon-refresh" aria-hidden="true"></span></button></span></div>';
    return html;
  }
  else {
    html = html + '</select>';
    return html;
  }
},

    renderDatasets: function(div) {
	var datasets = this.getDatasets();
	var html = '';

	if (!datasets || datasets.length===0) {
	    html = html + escapeDatasetHtml((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.none", "None") : "None"));
	    jQuery('#'+div+'_div').html(html);
	    return;
	}

	html += '<table class="table table-hover table-condensed">';
	html += '<thead><tr><th>' + escapeDatasetHtml((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.table.dataset_name", "Dataset Name") : "Dataset Name")) + '</th><th>' + escapeDatasetHtml((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.table.description", "Description") : "Description")) + '</th><th colspan="4">' + escapeDatasetHtml((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.table.actions", "Actions") : "Actions")) + '</th></tr></thead><tbody><tr>';
	for (var i = 0; i < datasets.length; i++) {
	    html += '<td><b>'+datasets[i][1]+'</b></td>';
	    html += '<td>'+datasets[i][2]+'</td>';
	    html += '<td><a title="' + escapeDatasetHtml((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.view", "View") : "View")) + '" id="view_dataset_'+datasets[i][1]+'" href="javascript:showDatasetItems(\'dataset_item_dialog\','+datasets[i][0]+')"><span class="glyphicon glyphicon-th-list"></span></a></td>';
	    html += '<td><a title="' + escapeDatasetHtml((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.delete", "Delete") : "Delete")) + '" id="delete_dataset_'+datasets[i][1]+'" href="javascript:deleteDataset('+datasets[i][0]+')"><span class="glyphicon glyphicon-remove"></span></a></td></tr>';
	}
	html = html + '</tbody></table>';
	html += '<div id="list_group_select_action"></div>';

	jQuery('#'+div+'_div').html(html);
    },

    renderItems: function(div, dataset_id) {
	var dataset = this.getDataset(dataset_id);

	var html = escapeDatasetHtml(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.items_intro", "This dataset contains the following:") : "This dataset contains the following:") + "<br />";

	var zero_count = 0;
	for(var key in dataset.categories) {
	    if (dataset.categories.hasOwnProperty(key)) {
		if (dataset.categories[key]===null || dataset.categories[key].length===0) {
		    zero_count++;
		}
		else {		   
	            var categoryLabel = '<b>' + escapeDatasetHtml(key) + '</b>';
		    var categorySummary = window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.items_type_count", "%{count} elements of type %{type}", {count: dataset.categories[key].length, type: categoryLabel}) : dataset.categories[key].length + " elements of type " + categoryLabel;
		    html += categorySummary + "<br />";
		}
	    }
	}

	if (zero_count === Object.keys(dataset.categories).length) { 
	    jQuery('#'+div).html(escapeDatasetHtml((window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.items_empty", "This dataset does not contain any selections.") : "This dataset does not contain any selections.")));
	}
	else { 
	    jQuery('#'+div).html(html);
	}
    }
}

function refreshDatasetSelect(div_name, empty_element) {
  var l = new CXGN.Dataset();
  var datasets = l.getDatasets();
  var html;
  if (empty_element) {
      html += '<option value="">'+empty_element+'</option>\n';
        }
  for (var n=0; n<datasets.length; n++) {
      html += '<option value='+datasets[n][0]+'>'+datasets[n][1]+'</option>';
  }
  jQuery('#'+div_name).html(html);
}

function setUpDatasets() {
//    jQuery("button[name='datasets_link']").click(
//	function() { show_datasets(); }
//    );
}

function show_datasets() {
    jQuery('#dataset_dialog').modal("show");
    var l = new CXGN.Dataset();
    l.renderDatasets('dataset_dialog');
}

function deleteDataset(dataset_id) {
    var reply = confirm((window.SGN && SGN.i18n ? SGN.i18n.p("lists_datasets.dataset.delete_confirm_id", "Are you sure you want to delete the dataset with id %{id}? Please note that deletion cannot be undone.", {id:String(dataset_id)}) : "Are you sure you want to delete the dataset with id "+dataset_id+"? Please note that deletion cannot be undone."));

    if (reply) {
	jQuery.ajax( {
	    'url' : '/ajax/dataset/delete/'+dataset_id,
	    'success': function(response) {
		if (response.error) {
		    alert(response.error);
		}
		else {
		    alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.delete_id_success", "Successfully deleted dataset with id %{id}", {id: String(dataset_id)}) : 'Successfully deleted dataset with id '+dataset_id);
		}
	    },
	    'error': function(response) {
		alert(window.SGN && SGN.i18n ? SGN.i18n.p("global.dataset_cxgn_dataset.processing_error", "A processing error occurred.") : "A processing error occurred.");
	    }
	})
    }

}

function showDatasetItems(div, dataset_id) {

    working_modal_show();

    var d = new CXGN.Dataset();

    jQuery('#'+div).text((window.SGN && SGN.i18n ? SGN.i18n.p("lists_datasets.dataset.transient_hello", "hello!") : "hello!"));
    
    d.renderItems(div, dataset_id);

    jQuery('#'+div).modal("show");

    working_modal_hide();
}
