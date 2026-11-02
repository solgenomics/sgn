
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

function pedigree_response_object(response) {
    return response !== null && typeof response === 'object' && !Array.isArray(response);
}

function get_remove_parents_list(stock_id) {
    jQuery.ajax({
        url: '/ajax/stock/parents',
        dataType: 'json',
        cache: false,
        data: { stock_id: stock_id },
        success: function(response) {
            if (!pedigree_response_object(response) || !Array.isArray(response.relationships)) {
                alert('Could not load the saved parent relationships. Please try again.');
                return;
            }
            var list = jQuery('#remove_parent_list').empty();
            jQuery.each(response.relationships, function(_, parent) {
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
        dataType: 'json',
        data: { stock_id: stock_id, parent_id: parent_id, parent_type: parent_type },
        success: function(response) {
            if (pedigree_response_object(response) && response.error) { alert(response.error); }
            else if (pedigree_response_object(response) && response.success === 1) {
                alert('The parent has been removed.');
                jQuery('#remove_parent_dialog').dialog('close');
                window.location.href = '/stock/' + stock_id + '/view';
            } else {
                alert('The removal result could not be confirmed. Reload the saved parents before trying again.');
                get_remove_parents_list(stock_id);
            }
        },
        error: function() {
            alert('The removal result could not be confirmed. Reload the saved parents before trying again.');
            get_remove_parents_list(stock_id);
        }
    });
}

/** Add missing parents using explicit names or selected stock identities. */
function stock_pedigree_dialog_init(stock_id) {
    var $ = jQuery;
    var modal = $('#add_parent_dialog');
    var female = $('#add_parent_female');
    var male = $('#add_parent_male');
    var crossType = $('#add_parent_cross_type');
    var save = $('#add_parent_submit');
    var error = $('#add_parent_error');
    var status = $('#add_parent_status');
    var fields = { female: female, male: male };
    var selected = { female: null, male: null };
    var saved = { female: null, male: null, type: '' };
    var generation = 0;
    var loadRequest = null;
    var loaded = false;
    var opened = false;
    var saveInFlight = false;
    var nextNotice = '';

    function showError(message) { error.text(message).show(); }
    function showStatus(message) { status.text(message).toggle(!!message); }
    function normalType(value) { return value && value !== 'null' ? String(value) : ''; }
    function changed() {
        return female.val() !== (saved.female ? saved.female.parent_name : '')
            || male.val() !== (saved.male ? saved.male.parent_name : '')
            || crossType.val() !== saved.type;
    }
    function updateRequirements() {
        var type = crossType.val();
        var required = !!type && type !== 'open';
        male.prop('required', required && !male.prop('readOnly'));
        $('#add_parent_male_help').text(required ? 'Required for this cross type.' : 'Optional; leave blank if the male parent is unknown.');
        save.prop('disabled', !loaded || saveInFlight || !changed());
    }
    function busy(value) {
        female.add(male).prop('disabled', value);
        if (value) { female.add(male).autocomplete('close'); }
        crossType.prop('disabled', value || !!(saved.female && saved.type));
        if (value) { save.prop('disabled', true); }
    }
    function abortLoad() {
        var request = loadRequest;
        loadRequest = null;
        if (request) { request.abort(); }
    }
    function loadSavedParents(notice, failureNotice) {
        loaded = false;
        var token = ++generation;
        abortLoad();
        busy(true);
        error.hide().empty();
        showStatus('Loading the saved parents...');
        loadRequest = $.ajax({
            url: '/ajax/stock/parents', type: 'GET', dataType: 'json', cache: false,
            data: { stock_id: stock_id },
            success: function(response) {
                if (!opened || token !== generation) { return; }
                loadRequest = null;
                if (!pedigree_response_object(response) || !Array.isArray(response.relationships)) {
                    showStatus('');
                    showError('Could not read the saved parents. Close this dialog and try again before saving.');
                    return;
                }
                if (response.error) { showStatus(''); showError(response.error); return; }
                var rows = { female: null, male: null };
                var invalid = false;
                $.each(response.relationships, function(_, parent) {
                    if (!pedigree_response_object(parent) || !Object.prototype.hasOwnProperty.call(rows, parent.parent_type)
                        || typeof parent.parent_name !== 'string' || rows[parent.parent_type]) {
                        invalid = true;
                        return;
                    }
                    rows[parent.parent_type] = parent;
                });
                if (invalid) {
                    showStatus('');
                    showError('The saved parent relationships are ambiguous. Review the saved pedigree first.');
                    return;
                }
                saved = { female: rows.female, male: rows.male, type: normalType(rows.female && rows.female.cross_type) };
                $.each(['female', 'male'], function(_, role) {
                    var parent = rows[role];
                    fields[role].val(parent ? parent.parent_name : '').prop('readOnly', !!parent);
                    selected[role] = parent && parent.parent_id !== undefined
                        ? { id: parent.parent_id, name: parent.parent_name } : null;
                });
                crossType.find('[data-existing]').remove();
                if (saved.type && !crossType.find('option').filter(function() { return this.value === saved.type; }).length) {
                    $('<option>').attr('data-existing', 'true').val(saved.type).text(saved.type + ' (existing)').appendTo(crossType);
                }
                crossType.find('option[value=""]').text(saved.female ? 'Unspecified (existing)' : 'Select cross type');
                crossType.val(saved.type);
                loaded = true;
                busy(false);
                showStatus(notice || (!changed() && saved.female && saved.male && saved.type
                    ? 'The recorded parents and cross type are already saved.' : ''));
                if (failureNotice) { showError(failureNotice); }
                updateRequirements();
            },
            error: function(xhr, textStatus) {
                if (!opened || token !== generation || textStatus === 'abort') { return; }
                loadRequest = null;
                showStatus('');
                showError('Could not reload the saved parents. Close this dialog and try again before saving.');
            }
        });
    }
    $.each(['female', 'male'], function(_, role) {
        var field = fields[role];
        field.autocomplete({
            source: function(request, response) {
                $.getJSON('/ajax/stock/pedigree_parent_autocomplete', { parent_type: role, term: request.term })
                    .done(function(matches) { response(!field.prop('disabled') && !field.prop('readOnly') && Array.isArray(matches) ? matches : []); })
                    .fail(function() { response([]); });
            },
            select: function(event, ui) {
                if (field.prop('disabled') || field.prop('readOnly')) { return false; }
                field.val(ui.item.value);
                selected[role] = { id: ui.item.id, name: ui.item.value };
                updateRequirements();
                return false;
            }
        });
        field.off('.pedigree').on('input.pedigree change.pedigree', function() {
            if (!field.prop('readOnly') && selected[role] && field.val() !== selected[role].name) { selected[role] = null; }
            updateRequirements();
        });
    });
    crossType.off('.pedigree').on('change.pedigree', updateRequirements);
    modal.off('.pedigree').on('hide.bs.modal.pedigree', function() {
        opened = false;
        loaded = false;
        ++generation;
        abortLoad();
    });
    $('#add_parent_link').off('click.pedigree').on('click.pedigree', function() {
        opened = true;
        modal.modal('show');
        if (saveInFlight) {
            busy(true);
            showStatus('Saving parents. Please wait for the result before starting another save.');
            return;
        }
        var notice = nextNotice;
        nextNotice = '';
        loadSavedParents(notice);
    });
    $('#add_parent_dialog_form').off('submit.pedigree').on('submit.pedigree', function(event) {
        event.preventDefault();
        if (!loaded || saveInFlight || save.prop('disabled') || !changed()) { return; }
        error.hide().empty();
        var femaleName = female.val();
        var maleName = male.val();
        var type = crossType.val();
        if (!femaleName) { showError('A female parent is required.'); return; }
        if (!type && !saved.female) { showError('Select a cross type.'); return; }
        if (type && type !== 'open' && !maleName) { showError('A male parent is required for this cross type.'); return; }
        // Selected IDs identify the stock even when its labels differ. Names or
        // aliases without IDs must be resolved by the server before comparison.
        if (type === 'self' && selected.female && selected.male
            && selected.female.id !== undefined && selected.male.id !== undefined
            && String(selected.female.id) !== String(selected.male.id)) {
            showError('For self, use the same parent in both fields.');
            return;
        }
        var data = { stock_id: stock_id, female_parent: femaleName, male_parent: maleName, cross_type: type };
        $.each(['female', 'male'], function(_, role) {
            if (selected[role] && selected[role].id !== undefined) { data[role + '_parent_id'] = selected[role].id; }
        });
        var token = generation;
        saveInFlight = true;
        busy(true);
        showStatus('Saving parents...');
        function finish(response, uncertain) {
            saveInFlight = false;
            var current = opened && token === generation;
            if (!uncertain && pedigree_response_object(response) && response.success === 1 && !response.error) {
                if (current) {
                    alert('The parents have been added.');
                    modal.modal('hide');
                    window.location.reload();
                } else {
                    nextNotice = 'The parents were saved. Reload the page to update all pedigree views.';
                    if (opened) { loadSavedParents(nextNotice); nextNotice = ''; }
                }
            } else if (!uncertain && pedigree_response_object(response) && typeof response.error === 'string' && response.error) {
                if (current) {
                    busy(false);
                    showStatus('');
                    showError(response.error);
                    updateRequirements();
                } else {
                    nextNotice = 'The previous save failed: ' + response.error;
                    if (opened) { loadSavedParents('', nextNotice); nextNotice = ''; }
                }
            } else {
                nextNotice = 'The previous save result was uncertain. Review the reloaded parents before saving again.';
                if (opened) { loadSavedParents('', nextNotice); nextNotice = ''; }
            }
        }
        $.ajax({
            url: '/ajax/stock/add_stock_parents', type: 'POST', dataType: 'json', data: data,
            success: function(response) { finish(response, false); },
            error: function() { finish(null, true); }
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
