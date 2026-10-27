function _sgnB16StockEscape(value) { return jQuery('<span>').text(value).html(); }

function stock_detail_page_init_dialogs() {
        jQuery('#stock_trials_info_popup').dialog({
	'autoOpen' : false,
	'modal' : true,
	'height' : 600,
	'width' : 700,
	'buttons' : {
	    [(window.SGN && window.SGN.i18n ? window.SGN.i18n.p("cross.ui.ok", "OK") : "OK")] : function() {
		jQuery('#stock_trials_info_popup').dialog("close");
	    }
	}

    });

    jQuery('#remove_parent_dialog').dialog({
	'autoOpen' : false,
	'modal' : true,
	'title' : (window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.remove_title", "Remove a parent") : "Remove a parent"),
	'height' : 300,
	'width' : 400,
	'buttons' : {
	    [(window.SGN && window.SGN.i18n ? window.SGN.i18n.p("cross.ui.done", "Done") : "Done")] : function() {
		jQuery('#remove_parent_dialog').dialog("close");
	    },

	}

    });


}

function show_stock_trial_detail(stock_id, stock_name, trial_id, trial_name) {
    jQuery('#stock_trials_info_popup').dialog("option", "title", (window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.trial_title", "Phenotypic data for %{stock} from trial %{trial}", {stock: String(stock_name), trial: String(trial_name)}) : "Phenotypic data for "+stock_name+" from trial "+trial_name));
    jQuery('#stock_trials_info_popup').dialog("open");
    jQuery('#stock_trials_info_table').DataTable().destroy();

    jQuery('#stock_trials_info_table').DataTable( {
	ajax: '/stock/'+stock_id+'/datatables/trial/'+trial_id,
    });
}

function get_remove_parents_list(stock_id) {
    jQuery.ajax( {
	url : '/ajax/stock/parents?stock_id='+stock_id,
	success: function(response) {
	    var html = "";
	    for (var n=0; n<response.parents.length; n++) {
		html += response.parents[n][1]+ '&nbsp;&nbsp;<a href="javascript:remove_parents('+response.stock_id+','+ response.parents[n][0]+');" ><font color="red" >X</font></a><br /><br />';

	    }

	    jQuery('#remove_parent_list').html(html);
	},
	error: function(response) {
	    alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.parent_read_error", "an error occurred.") : "an error occurred."));
	}
    });

}

function remove_parents(stock_id, parent_id) {
    var yes = confirm((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.remove_confirm", "Are you sure you want to remove this parent?") : "Are you sure you want to remove this parent?"));
    if (yes) {
	jQuery.ajax( {
	    url: '/ajax/stock/parent/remove',
	    data: { 'stock_id' : stock_id, 'parent_id' : parent_id },
	    success : function(response) {
		if (response.error) {
		    alert(response.error);
		}
		else {
		    alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.parent_removed", "The parent has been removed.") : "The parent has been removed."));
		    jQuery('#remove_parent_dialog').dialog("close");
		    window.location.href = '/stock/'+stock_id+'/view';

		}
	    }
	});

    }

}

function obsoleteStock(stock_id, stock_name){
    showObsoleteDialog(stock_id, stock_name, true);
}

function unObsoleteStock(stock_id, stock_name){
    showObsoleteDialog(stock_id, stock_name, false);
}

function showObsoleteDialog(stock_id, stock_name, obsolete) {
    let html = '';
    html = html + '<form class="form-horizontal"><div class="form-group"><label class="col-sm-4 control-label">' + _sgnB16StockEscape((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.name", "Stock Name: ") : "Stock Name: ")) + '</label><div class="col-sm-8" ><input class="form-control" id="obsolete_stock_name" name="obsolete_stock_name" value="'+stock_name+'" disabled></div></div>';
    html = html + '<div class="form-group"><label class="col-sm-4 control-label">' + _sgnB16StockEscape((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.note", "Note: ") : "Note: ")) + '</label><div class="col-sm-8" ><input class="form-control" id="obsolete_note" name="obsolete_note" placeholder="' + _sgnB16StockEscape((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.optional", "Optional") : "Optional")) + '"></div></div></form>';
    html = html + '<div class="form-group"><input id="obsolete_stock_id" type="hidden" value="'+stock_id+'"/>';

    jQuery("#obsoleteStockDialog").html(obsolete ? _sgnB16StockEscape((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.action.obsolete", "Obsolete This Stock") : "Obsolete This Stock")) : _sgnB16StockEscape((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.action.unobsolete", "Un-Obsolete This Stock") : "Un-Obsolete This Stock")));
    jQuery("#obsolete_stock_submit").html(obsolete ? _sgnB16StockEscape((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.obsolete_button", "Obsolete") : "Obsolete")) : _sgnB16StockEscape((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.unobsolete_button", "Un-Obsolete") : "Un-Obsolete")));
    jQuery("#obsolete_stock_submit").data("obsolete", obsolete ? 'true' : 'false');
    jQuery('#obsolete_stock_div').html(html);
    jQuery('#obsolete_stock_dialog').modal('show');
}

jQuery(document).ready(function($) {

    jQuery('#obsolete_stock_submit').click( function() {
        const obsolete = jQuery(this).data("obsolete") === 'true';
        const note = jQuery('#obsolete_note').val();
        const stock_id = jQuery('#obsolete_stock_id').val();
        if (!stock_id) {
            alert ((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.missing_id", "Error retrieving stock id") : "Error retrieving stock id"));
            return;
        }

        const stock_name = jQuery('#obsolete_stock_name').val();
        if (!stock_name) {
            alert ((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.missing_name", "Error retrieving stock name") : "Error retrieving stock name"));
            return;
        }

        const confirmation = confirm((obsolete ? (window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.obsolete_confirm", "Are you sure you want to obsolete this stock?  %{name}", {name: String(stock_name)}) : 'Are you sure you want to ' + (obsolete ? 'obsolete' : 'un-obsolete') + ' this stock?' + "  " + stock_name) : (window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.unobsolete_confirm", "Are you sure you want to un-obsolete this stock?  %{name}", {name: String(stock_name)}) : 'Are you sure you want to ' + (obsolete ? 'obsolete' : 'un-obsolete') + ' this stock?' + "  " + stock_name)));

        if (confirmation) {
            jQuery.ajax({
                url: '/stock/obsolete',
                data : {
                    'stock_id' : stock_id,
                    'is_obsolete': obsolete ? 1 : 0,
                    'obsolete_note': note,
                },
                beforeSend: function(response){
                    jQuery('#working_modal').modal('show');
                },
                success: function(response){
                    console.log(response);
                    jQuery('#working_modal').modal('hide');
                    if (response.error) {
                        alert(response.error);
                    }
                    if (response.success == 1) {
                        jQuery('#obsolete_stock_dialog').modal('hide');
                        jQuery('#obsolete_stock_message_dialog').modal('show');
                    }
                },                
                error: function(response){
                    jQuery('#working_modal').modal('hide');
                    alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.stock.obsolete_failed", "Error obsoleting stock.") : "Error obsoleting stock."));
                }
            });
        }
    });

    jQuery("#dismiss_obsolete_stock_message_dialog").click(function(){
        location.reload();
    });

});
