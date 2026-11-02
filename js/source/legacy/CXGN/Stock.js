
function stock_detail_page_init_dialogs() {
        jQuery('#stock_trials_info_popup').dialog({
	'autoOpen' : false,
	'modal' : true,
	'height' : 600,
	'width' : 700,
	'buttons' : {
	    'OK' : function() {
		jQuery('#stock_trials_info_popup').dialog("close");
	    }
	}

    });

    jQuery('#remove_parent_dialog').dialog({
	'autoOpen' : false,
	'modal' : true,
	'title' : 'Remove a parent',
	'height' : 300,
	'width' : 400,
	'buttons' : {
	    'Done' : function() {
		jQuery('#remove_parent_dialog').dialog("close");
	    },

	}

    });


}

function show_stock_trial_detail(stock_id, stock_name, trial_id, trial_name) {
    jQuery('#stock_trials_info_popup').dialog("option", "title", "Phenotypic data for "+stock_name+" from trial "+trial_name);
    jQuery('#stock_trials_info_popup').dialog("open");
    jQuery('#stock_trials_info_table').DataTable().destroy();

    jQuery('#stock_trials_info_table').DataTable( {
	ajax: '/stock/'+stock_id+'/datatables/trial/'+trial_id,
    });
}

function get_remove_parents_list(stock_id) {
    jQuery.ajax({
        url: '/ajax/stock/parents',
        data: { stock_id: stock_id },
        success: function(response) {
            var list = jQuery('#remove_parent_list').empty();
            jQuery.each(response.relationships || [], function(_, parent) {
                var row = jQuery('<div>').append(jQuery('<span>').text(parent.parent_name + ' (' + parent.parent_type + ') '));
                jQuery('<a href="#">').text('Remove').on('click', function(event) {
                    event.preventDefault();
                    remove_parents(stock_id, parent.parent_id, parent.parent_type);
                }).appendTo(row);
                row.appendTo(list);
            });
        },
        error: function() { alert('An error occurred while loading parents.'); }
    });
}

function remove_parents(stock_id, parent_id, parent_type) {
    if (!confirm('Are you sure you want to remove this parent relationship?')) { return; }
    jQuery.ajax({
        url: '/ajax/stock/parent/remove',
        type: 'POST',
        data: { stock_id: stock_id, parent_id: parent_id, parent_type: parent_type },
        success: function(response) {
            if (response.error) { alert(response.error); }
            else {
                alert('The parent has been removed.');
                jQuery('#remove_parent_dialog').dialog('close');
                window.location.href = '/stock/' + stock_id + '/view';
            }
        },
        error: function() { alert('An error occurred while removing the parent.'); }
    });
}

/**
 * Initialize the stock-page form for adding missing parents in one request.
 * Existing identities and known cross types remain read-only; no parent or
 * breeding method is inferred from the other fields.
 * @param {string} stock_id - Accession stock ID.
 */
function stock_pedigree_dialog_init(stock_id) {
    var $ = jQuery;
    var female = $('#add_parent_female');
    var male = $('#add_parent_male');
    var crossType = $('#add_parent_cross_type');
    var save = $('#add_parent_submit');
    var error = $('#add_parent_error');
    var loaded = false;
    var existingFemale = false;

    function showError(message) { error.text(message).show(); }
    function updateRequirements() {
        var type = crossType.val();
        var required = !!type && type !== 'open';
        male.prop('required', required);
        $('#add_parent_male_help').text(required ? 'Required for this cross type.' : 'Optional; leave blank if the male parent is unknown.');
    }
    female.autocomplete({ source: '/ajax/stock/accession_or_cross_autocomplete' });
    // Merge standard parent and population lookups without offering plot stocks.
    male.autocomplete({ source: function(request, response) {
        $.when(
            $.getJSON('/ajax/stock/accession_or_cross_autocomplete', request),
            $.getJSON('/ajax/stock/population_autocomplete', request)
        ).done(function(parents, populations) {
            var all = parents[0].concat(populations[0]);
            response($.grep(all, function(name, index) { return all.indexOf(name) === index; }));
        }).fail(function() { response([]); });
    }});
    crossType.off('.pedigree').on('change.pedigree', updateRequirements);
    $('#add_parent_link').off('click.pedigree').on('click.pedigree', function() {
        loaded = false;
        existingFemale = false;
        save.prop('disabled', true);
        error.hide().empty();
        female.add(male).val('').prop('readOnly', false);
        crossType.find('[data-existing]').remove();
        crossType.val('').prop('disabled', false);
        crossType.find('option[value=""]').text('Select cross type');
        $('#add_parent_dialog').modal('show');
        $.getJSON('/ajax/stock/parents', { stock_id: stock_id }).done(function(response) {
            if (response.error) { showError(response.error); return; }
            var seen = {};
            var invalid = false;
            $.each(response.relationships || [], function(_, parent) {
                var role = parent.parent_type;
                if (seen[role]) { invalid = true; return; }
                seen[role] = true;
                (role === 'female' ? female : male).val(parent.parent_name).prop('readOnly', true);
                if (role === 'female') {
                    existingFemale = true;
                    var type = parent.cross_type;
                    type = type && type !== 'null' ? type : '';
                    if (type && !crossType.find('option').filter(function() { return this.value === type; }).length) {
                        $('<option>').attr('data-existing', 'true').val(type).text(type + ' (existing)').appendTo(crossType);
                    }
                    crossType.val(type).prop('disabled', !!type);
                    if (!type) { crossType.find('option[value=""]').text('Unspecified (existing)'); }
                }
            });
            if (invalid) { showError('More than one parent of the same role is stored. Review the saved pedigree first.'); return; }
            loaded = true;
            updateRequirements();
            save.prop('disabled', false);
        }).fail(function() { showError('Could not load the saved parents. Close this dialog and try again.'); });
    });
    $('#add_parent_dialog_form').off('submit.pedigree').on('submit.pedigree', function(event) {
        event.preventDefault();
        if (!loaded || save.prop('disabled')) { return; }
        error.hide().empty();
        var femaleName = female.val();
        var maleName = male.val();
        var type = crossType.val();
        if (!femaleName) { showError('A female parent is required.'); return; }
        if (!type && !existingFemale) { showError('Select a cross type.'); return; }
        if (type && type !== 'open' && !maleName) { showError('A male parent is required for this cross type.'); return; }
        if (type === 'self' && femaleName !== maleName) { showError('For self, use the same parent in both fields.'); return; }
        save.prop('disabled', true);
        $.ajax({
            url: '/ajax/stock/add_stock_parents',
            type: 'POST',
            dataType: 'json',
            data: { stock_id: stock_id, female_parent: femaleName, male_parent: maleName, cross_type: type },
            success: function(response) {
                if (response.error) { showError(response.error); }
                else {
                    alert('The parents have been added.');
                    $('#add_parent_dialog').modal('hide');
                    window.location.reload();
                }
            },
            error: function() { showError('An error occurred while saving the parents. Please try again.'); },
            complete: function() { save.prop('disabled', false); }
        });
    });
}

function obsoleteStock(stock_id, stock_name){
    showObsoleteDialog(stock_id, stock_name, true);
}

function unObsoleteStock(stock_id, stock_name){
    showObsoleteDialog(stock_id, stock_name, false);
}

function showObsoleteDialog(stock_id, stock_name, obsolete) {
    let html = '';
    html = html + '<form class="form-horizontal"><div class="form-group"><label class="col-sm-4 control-label">Stock Name: </label><div class="col-sm-8" ><input class="form-control" id="obsolete_stock_name" name="obsolete_stock_name" value="'+stock_name+'" disabled></div></div>';
    html = html + '<div class="form-group"><label class="col-sm-4 control-label">Note: </label><div class="col-sm-8" ><input class="form-control" id="obsolete_note" name="obsolete_note" placeholder="Optional"></div></div></form>';
    html = html + '<div class="form-group"><input id="obsolete_stock_id" type="hidden" value="'+stock_id+'"/>';

    jQuery("#obsoleteStockDialog").html(obsolete ? "Obsolete This Stock" : "Un-Obsolete This Stock");
    jQuery("#obsolete_stock_submit").html(obsolete ? "Obsolete" : "Un-Obsolete");
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
            alert ("Error retrieving stock id");
            return;
        }

        const stock_name = jQuery('#obsolete_stock_name').val();
        if (!stock_name) {
            alert ("Error retrieving stock name");
            return;
        }

        const confirmation = confirm('Are you sure you want to ' + (obsolete ? 'obsolete' : 'un-obsolete') + ' this stock?' + "  " + stock_name);

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
                    alert("Error obsoleting stock.");
                }
            });
        }
    });

    jQuery("#dismiss_obsolete_stock_message_dialog").click(function(){
        location.reload();
    });

});
