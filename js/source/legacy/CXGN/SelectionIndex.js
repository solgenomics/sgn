var selectionIndexMode = 'create';
var CURRENT_SIN_FORMULA_NAME = null;

function update_selected_trials_display(ids, names) {
  var $wrap = jQuery('#selected_trials_summary');
  var $list = jQuery('#selected_trials_list');
  if (!$wrap.length || !$list.length) { return; }
  if (!ids || !ids.length) {
    $wrap.hide();
    $list.html('');
    return;
  }
  var html = [];
  for (var i = 0; i < ids.length; i++) {
    var name = names && names[i] ? names[i] : ids[i];
    html.push(
      '<span class="label label-default" style="margin-right:6px; display:inline-block;" data-trial-id="' + ids[i] + '">' +
        name +
        ' <a href="#" class="remove-selected-trial" data-trial-id="' + ids[i] + '" aria-label="Remove">&times;</a>' +
      '</span>'
    );
  }
  $list.html(html.join(' '));
  $wrap.show();
}

function listElementValue(el) {
  if (!el) return null;
  if (typeof el === 'string') {
    try {
      var trimmed = el.trim();
      return trimmed;
    } catch (e) {
      return el;
    }
  }
  if (Array.isArray(el) && el.length) {
    if (el.length > 1 && typeof el[1] === 'string') {
      return el[1];
    }
    if (typeof el[0] === 'string') {
      return el[0];
    }
  }
  if (typeof el === 'number') {
    return String(el);
  }
  if (typeof el === 'object') {
    if (typeof el.content === 'string') {
      return el.content;
    }
    if (typeof el.value === 'string') {
      return el.value;
    }
  }
  return null;
}

function listElementText(el) {
  var val = listElementValue(el);
  if (!val && typeof el === 'object') {
    if (el.project_name) {
      val = el.project_name;
    } else if (el.trial_name) {
      val = el.trial_name;
    }
  }
  return typeof val === 'string' ? val.trim() : '';
}

function parseListElementId(el) {
  var content = listElementValue(el);
  if (!content) {
    if (typeof el === 'object' && el) {
      if (el.id) {
        return String(el.id);
      }
      if (el.project_id) {
        return String(el.project_id);
      }
      if (el.trial_id) {
        return String(el.trial_id);
      }
    }
    return null;
  }
  if (Array.isArray(content) && content.length) {
    return String(content[0]);
  }
  if (typeof content === 'object') {
    if (content.id) {
      return String(content.id);
    }
    if (content.value) {
      return String(content.value);
    }
  }
  var parts = String(content).split('|', 1);
  return parts[0] || null;
}

function ensureTrialLoadingModal() {
  if (jQuery('#trial_loading_modal').length) {
    return;
  }
  var modalHtml =
    '<div class="modal fade" id="trial_loading_modal" tabindex="-1" role="dialog" aria-hidden="true">' +
      '<div class="modal-dialog modal-sm modal-dialog-centered" role="document">' +
        '<div class="modal-content">' +
          '<div class="modal-header">' +
            '<h5 class="modal-title">Working....</h5>' +
          '</div>' +
          '<div class="modal-body text-center" style="padding: 25px;">' +
            '<p class="loading-text" style="margin-bottom: 15px;">Preparing trial list...</p>' +
            '<div class="progress">' +
              '<div class="progress-bar progress-bar-striped active" role="progressbar" aria-valuemin="0" aria-valuemax="100" style="width: 100%;"></div>' +
            '</div>' +
          '</div>' +
        '</div>' +
      '</div>' +
    '</div>';
  jQuery('body').append(modalHtml);
}

function showTrialLoadingModal(message) {
  ensureTrialLoadingModal();
  var $modal = jQuery('#trial_loading_modal');
  $modal.find('.loading-text').text(message || 'Loading trials...');
  $modal.modal({ backdrop: 'static', keyboard: false, show: true });
}

function hideTrialLoadingModal() {
  jQuery('#trial_loading_modal').modal('hide');
}

function refresh_trial_selectpicker($sel) {
  if (!$sel || !$sel.length) return;
  $sel.attr('multiple', 'multiple');
  $sel.attr('data-live-search', 'true');
  $sel.attr('data-actions-box', 'true');
  $sel.attr('data-selected-text-format', 'count > 3');
  if ($sel.selectpicker) {
    $sel.selectpicker({
      liveSearch: true,
      actionsBox: true,
      noneSelectedText: 'Select trials',
      noneResultsText: 'No trials matched {0}'
    });
    $sel.selectpicker('refresh');
  }
  if (!$sel.selectpicker || !$sel.data('selectpicker')) {
    var nOpts = $sel.find('option:visible').length;
    $sel.attr('size', Math.min(Math.max(nOpts, 8), 12));
  }
}

function apply_trial_visibility($sel, selectedIds) {
  if (!$sel || !$sel.length) return;
  var map = {};
  (selectedIds || []).forEach(function(id) { map[String(id)] = true; });
  $sel.find('option').each(function() {
    var v = jQuery(this).val();
    if (map[String(v)]) {
      jQuery(this).hide();
    } else {
      jQuery(this).show();
    }
  });
  refresh_trial_selectpicker($sel);
}

var CURRENT_SOURCE_TYPE = 'trials';
var trialDualState = { all: [], selected: [], search: '' };
window.trialDualSyncLock = false;
window.syncTrialDualListUI = null;
var loadItemsForSourceNonce = 0;
var traitRequestNonce = 0;

function resetTrialDualUIState() {
  trialDualState.all = [];
  trialDualState.selected = [];
  trialDualState.search = '';
  window.trialDualSyncLock = false;
  window.syncTrialDualListUI = null;
  jQuery('#trial_available_list').empty();
  jQuery('#trial_selected_list').empty();
  jQuery('#trial_counts_text').text('');
}

function isTrialSourceType() {
  return CURRENT_SOURCE_TYPE === 'trials';
}

function hideTrialSelectionSummary() {
  update_selected_trials_display([], []);
}

function setTrialModeVisibility(showTrialUI) {
  var $trialTools = jQuery('#trial_list_tools');
  var $trialWrapper = jQuery('#trial_dual_wrapper');
  var $selectContainer = jQuery('#select_trial_container');

  if (showTrialUI) {
    $trialTools.show();
    $trialWrapper.show();
    $selectContainer.hide();
  } else {
    $trialTools.hide();
    $trialWrapper.hide();
    $selectContainer.show();
    hideTrialSelectionSummary();
    resetTrialDualUIState();
    var $sel = jQuery('#select_trial_for_selection_index');
    if ($sel.length) {
      if ($sel.selectpicker && $sel.data('selectpicker')) {
        $sel.selectpicker('destroy');
      }
      $sel.removeAttr('multiple size data-live-search data-actions-box data-selected-text-format');
    }
  }
}

function updateTrialModeUI() {
  setTrialModeVisibility(isTrialSourceType());
}

function normalizeNonTrialSelect() {
  var $sel = jQuery('#select_trial_for_selection_index');
  if (!$sel.length) return;
  if ($sel.selectpicker && $sel.data('selectpicker')) {
    $sel.selectpicker('destroy');
  }
  $sel.removeAttr('multiple size data-live-search data-actions-box data-selected-text-format');
  $sel.addClass('form-control');
}

function showError(message) {
  var container = document.getElementById('selection_index_error_message');
  if (container) {
    container.innerHTML = '<center><li class="list-group-item list-group-item-danger">' + message + '</li></center>';
    jQuery('#selection_index_error_dialog').modal('show');
  } else {
    alert(message);
  }
}

function showWarning(message) {
  var container = document.getElementById('selection_index_error_message');
  if (container) {
    container.innerHTML = '<center><li class="list-group-item list-group-item-warning">' + message + '</li></center>';
    jQuery('#selection_index_error_dialog').modal('show');
  } else {
    alert(message);
  }
}

function appendDatasetOptionsToTrialMenu() {
  var $select = jQuery('#trial_source_list_list_select');
  if (!$select.length) {
    return;
  }
  $select.find('option[data-dataset]').remove();
  $select.find('option[data-dataset-header]').remove();
  try {
    var datasets = new CXGN.Dataset().getDatasets();
    if (!Array.isArray(datasets) || datasets.length === 0) {
      return;
    }
    var html = '<option disabled data-dataset-header>--------YOUR DATASETS BELOW--------</option>';
    datasets.forEach(function (dataset) {
      var datasetId = dataset && dataset[0];
      var datasetName = dataset && dataset[1];
      if (!datasetId) {
        return;
      }
      html += '<option value="dataset:' + datasetId + '" data-dataset="true">Dataset: ' + (datasetName || datasetId) + '</option>';
    });
    $select.append(html);
  } catch (err) {
    console.error('Error appending datasets to trial menu', err);
  }
}

if (typeof refreshListSelect === 'function') {
  var _refreshListSelect = refreshListSelect;
  refreshListSelect = function(div_name, types) {
    var result = _refreshListSelect.apply(this, arguments);
    if (div_name === 'trial_source_list') {
      appendDatasetOptionsToTrialMenu();
    }
    return result;
  };
}

function refreshSavedTrialListMenu(lo) {
  try {
    var menuHtml = lo.listSelect('trial_source_list', ['trials'], 'Use saved trial list', 'refresh', undefined);
    jQuery('#trial_list_menu').html('<div id="trial_source_list"></div>');
    jQuery('#trial_source_list').html(menuHtml);
    appendDatasetOptionsToTrialMenu();
  } catch (err) {
    console.error('Error refreshing trial list dropdown', err);
  }
}

function rebuildTrialStateFromSelect($sel, selectedIds) {
  trialDualState.all = [];
  $sel.find('option').each(function () {
    var id = jQuery(this).val();
    if (!id) return;
    trialDualState.all.push({ id: id, name: jQuery(this).text() });
  });

  var selSet = {};
  (selectedIds || []).forEach(function (id) { selSet[String(id)] = true; });
  trialDualState.selected = trialDualState.all.filter(function (t) { return selSet[String(t.id)]; });
}

function renderTrialDualLists() {
  if (!jQuery('#trial_dual_wrapper').length) return;
  if (!isTrialSourceType()) {
    jQuery('#trial_dual_wrapper').hide();
    return;
  }
  var term = (trialDualState.search || '').toLowerCase();
  var selMap = {};
  trialDualState.selected.forEach(function (t) { selMap[String(t.id)] = true; });
  var available = trialDualState.all.filter(function (t) { return !selMap[String(t.id)]; });

  if (term) {
    available = available.filter(function (t) {
      return t.name.toLowerCase().indexOf(term) !== -1;
    });
  }

  var availHtml = available.map(function (t) {
    return '<div class="list-group-item" data-id="' + t.id + '">' +
      '<button class="btn btn-success btn-xs trial-add-btn" data-id="' + t.id + '" aria-label="Add trial">+</button> ' +
      t.name +
      '</div>';
  }).join('');
  jQuery('#trial_available_list').html(availHtml || '<div class="text-muted" style="padding:6px;">No trials matched</div>');

  var selectedHtml = trialDualState.selected.map(function (t) {
    return '<div class="list-group-item" data-id="' + t.id + '">' +
      '<button class="btn btn-danger btn-xs trial-remove-btn" data-id="' + t.id + '" aria-label="Remove trial">&times;</button> ' +
      t.name +
      '</div>';
  }).join('');
  jQuery('#trial_selected_list').html(selectedHtml || '<div class="text-muted" style="padding:6px;">No trials selected</div>');

  jQuery('#trial_counts_text').text(trialDualState.selected.length + ' selected / ' + trialDualState.all.length + ' total');
}

function applySelectionToHiddenSelect(ids) {
  var $sel = jQuery('#select_trial_for_selection_index');
  if (!$sel.length) return;
  ids = Array.isArray(ids) ? ids : (ids ? [ids] : []);
  window.trialDualSyncLock = true;
  $sel.find('option').prop('selected', false);
  var displayNames = [];
  ids.forEach(function (id) {
    $sel.find('option[value="' + id + '"]').prop('selected', true);
    var optionText = $sel.find('option[value="' + id + '"]').text();
    var label = optionText ? optionText.trim() : id;
    displayNames.push(label);
  });
  if ($sel.selectpicker) $sel.selectpicker('refresh');
  window.trialDualSyncLock = false;
  $sel.trigger('change');
  if (isTrialSourceType()) {
    update_selected_trials_display(ids, displayNames);
  } else {
    hideTrialSelectionSummary();
  }
}

function collectSelectedTrials() {
  var $sel = jQuery('#select_trial_for_selection_index');
  var ids = trialDualState.selected.map(function (t) { return String(t.id); });
  var nameMap = {};
  trialDualState.selected.forEach(function (t) {
    nameMap[String(t.id)] = t.name;
  });

  if (!ids.length && $sel.length) {
    var values = $sel.val() || [];
    if (!Array.isArray(values)) {
      values = values ? [values] : [];
    }
    ids = values.map(function (id) { return String(id); });
    ids.forEach(function (id) {
      if (!nameMap[id]) {
        nameMap[id] = $sel.find('option[value="' + id + '"]').text();
      }
    });
  }
  return { ids: ids, nameMap: nameMap };
}

function applyTrialListSelection(ids) {
  var normalized = Array.isArray(ids) ? ids : (ids ? [ids] : []);
  normalized = normalized.map(function (id) { return String(id); }).filter(Boolean);
  if (!normalized.length) {
    return;
  }
  var $sel = jQuery('#select_trial_for_selection_index');
  if (!$sel.length) return;

  applySelectionToHiddenSelect(normalized);

  if (typeof window.syncTrialDualListUI === 'function') {
    window.syncTrialDualListUI(normalized);
  } else {
    build_trial_dual_list_ui($sel);
  }
}

function build_trial_dual_list_ui($sel) {
  var $wrapper = jQuery('#trial_dual_wrapper');
  if (!$wrapper.length || !isTrialSourceType()) {
    if ($wrapper.length) {
      $wrapper.hide();
    }
    window.syncTrialDualListUI = null;
    return;
  }

  trialDualState.search = '';
  jQuery('#trial_search_input').val('');

  rebuildTrialStateFromSelect($sel, $sel.val() || []);
  renderTrialDualLists();

  $wrapper.show();

  window.syncTrialDualListUI = function (ids) {
    rebuildTrialStateFromSelect(jQuery('#select_trial_for_selection_index'), ids || []);
    renderTrialDualLists();
  };
  updateTrialModeUI();
}

function initTrialDualListUI() {
  var $sel = jQuery('#select_trial_for_selection_index');
  if (!$sel.length) {
    setTimeout(initTrialDualListUI, 250);
    return;
  }
  $sel.attr('multiple', 'multiple').css('display', 'none');
  try {
    var lo = new CXGN.List();
    jQuery('#trial_list_menu').html('<div id="trial_source_list"></div>');
    jQuery('#trial_source_list').html(
      lo.listSelect(
        'trial_source_list',
        ['trials'],
        'Use saved trial list',
        'refresh',
        undefined
      )
    );
    appendDatasetOptionsToTrialMenu();
  } catch (e) {
    console.error('error rendering trial_source_list selector', e);
  }
  build_trial_dual_list_ui($sel);
}

function load_items_for_source(type) {
  var sourceType = type || 'trials';
  var requestNonce = ++loadItemsForSourceNonce;
  CURRENT_SOURCE_TYPE = sourceType;
  setTrialModeVisibility(isTrialSourceType());
  if (sourceType === 'trials') {
    resetTrialDualUIState();
  }

  hideTrialLoadingModal();

  if (sourceType === 'trials') {
    showTrialLoadingModal('Loading trials...');
    jQuery('#select_trial_container').html('<div class="loading">Loading...</div>');
    get_select_box('projects', 'select_trial_container', {
      'get_field_trials': 1,
      'include_analyses': 0,
      'has_phenotype': 1,
      'name': 'select_trial_for_selection_index',
      'id':   'select_trial_for_selection_index',
      'default': 'Select one or more trials',
      'live_search': 1,
      'after_load': function () {
        if (requestNonce !== loadItemsForSourceNonce) {
          return;
        }
        hideTrialLoadingModal();
        jQuery('#select_trial_container').hide();
        initTrialDualListUI();
      }
  });

    } else if (sourceType === 'analyses') {
      jQuery('#select_trial_container').html('<div class="loading">Loading...</div>');
      get_select_box('projects', 'select_trial_container', {
        'get_field_trials': 0,
        'include_analyses': 1,
        'multiple': 0,
        'name': 'select_trial_for_selection_index',
        'id':   'select_trial_for_selection_index',
        'default': 'Select an analysis',
        'live_search': 1
      });
      setTimeout(function () {
        if (requestNonce === loadItemsForSourceNonce) {
          jQuery('#select_trial_container').show();
          setTrialModeVisibility(false);
          normalizeNonTrialSelect();
        }
      }, 250);

    } else if (sourceType === 'datasets') {
      jQuery('#select_trial_container').html('<div class="loading">Loading...</div>');
      jQuery.ajax({
      url: '/ajax/html/select/datasets',
      data: { 'id': 'dataset_select', 'name': 'dataset_select' },
      success: function(response) {
        if (requestNonce !== loadItemsForSourceNonce) {
          return;
        }
        var container = jQuery('<div>').html(response.select);
        var items = [];
        container.find('table tbody tr').each(function() {
          var link = jQuery(this).find('td:nth-child(2) a');
          if (link.length) {
            var href = link.attr('href');
            var match = href && href.match(/\/dataset\/(\d+)/);
            if (match) {
              items.push({ id: match[1], name: jQuery.trim(link.text()) });
            }
          }
        });
        var html = '<select id="select_trial_for_selection_index" class="form-control"><option value="">Select a dataset</option>';
        items.forEach(function(it) {
          html += '<option value="' + it.id + '">' + it.name + '</option>';
        });
        html += '</select>';
        jQuery('#select_trial_container').html(html);
        jQuery('#select_trial_container').show();
        setTrialModeVisibility(false);
        normalizeNonTrialSelect();
      },
      error: function() {
        if (requestNonce !== loadItemsForSourceNonce) {
          return;
        }
        jQuery('#select_trial_container').html('<select class="form-control"><option value="">Error loading datasets</option></select>');
        jQuery('#select_trial_container').show();
        setTrialModeVisibility(false);
        normalizeNonTrialSelect();
      }
    });
  }
}

window.load_items_for_source = load_items_for_source;


jQuery(document).ready(function() {

  jQuery(document)
    .on('show.bs.collapse', '.panel-collapse', function() {
      var $span = jQuery(this).parents('.panel').find('.panel-heading span.clickable');
      $span.find('i').removeClass('glyphicon-chevron-down').addClass('glyphicon-chevron-up');
    })
    .on('hide.bs.collapse', '.panel-collapse', function() {
      var $span = jQuery(this).parents('.panel').find('.panel-heading span.clickable');
      $span.find('i').removeClass('glyphicon-chevron-up').addClass('glyphicon-chevron-down');
    });

  jQuery('#pagetitle_h3').append('&nbsp;<a id="selection_index_more_info" href="#"><span class="glyphicon glyphicon-info-sign"></span></a>');

  // When a trial / analysis / dataset is selected in CREATE pipeline: populate traits and controls
  jQuery(document).on('change', '#select_trial_for_selection_index', function() {

    var selected = jQuery(this).val();
    var trial_ids = Array.isArray(selected) ? selected.filter(Boolean) : (selected ? [selected] : []);
    if (!trial_ids.length) {
      jQuery('#selection_index').html("");
      jQuery('#trait_table').html("");
      jQuery('#weighted_values_div').html("");
      jQuery('#raw_avgs_div').html("");
      jQuery('#sin_formula_list_select').val("");
      update_formula();
      update_selected_trials_display([], []);
      return;
    }

    jQuery('#selection_index').html("");
    jQuery('#trait_table').html("");
    jQuery('#weighted_values_div').html("");
    jQuery('#raw_avgs_div').html("");
    jQuery('#sin_formula_list_select').val("");
    update_formula();

    var $sel = jQuery(this);
    var source_names = $sel.find('option:selected').map(function() { return jQuery(this).text(); }).get();
    var source_text = source_names.join(', ');
    if (isTrialSourceType()) {
      update_selected_trials_display(trial_ids, source_names);
      apply_trial_visibility($sel, trial_ids);
    } else {
      hideTrialSelectionSummary();
    }

      var label_links = trial_ids.map(function(id) {
        var txt = $sel.find('option[value="' + id + '"]').text() || id;
        return '<a href="/breeders_toolbox/trial/' + id + '">' + txt + '</a>';
      });
      jQuery('#trait_table_label').html('Traits and coefficients for ' + label_links.join(', ') + ':');

      // Backend search endpoints expect trial ids per request; request traits for every selected trial.
      var data = [ trial_ids ];

    var traitRequestId = ++traitRequestNonce;
    jQuery('#trait_list').html('<option id="select_message" value="" title="Select a trait">Loading traits...</option>');
    jQuery.ajax({
      url: '/ajax/breeder/search',
      method: 'POST',
      data: { 'categories': ['trials', 'traits'], 'data': data, 'querytypes': 0 },
      beforeSend: function() { if (typeof disable_ui === 'function') { disable_ui(); } },
      complete: function() { if (typeof enable_ui === 'function') { enable_ui(); } },
      success: function(response) {
        if (traitRequestId !== traitRequestNonce) {
          return;
        }
        var list = response.list || [];
        if (!list.length) {
          var trait_html = '<option id="select_message" value="" title="No trait measurements found.">No trait measurements found for ' + source_text + '.</option>\n';
          jQuery('#trait_list').html(trait_html);
          return;
        }
        var trait_ids = [];
        var trait_html = '<option id="select_message" value="" title="Select a trait">Select a trait</option>\n';
        for (var i = 0; i < list.length; i++) {
          var trait_id = list[i][0];
          trait_ids.push(trait_id);
          var trait_name = list[i][1];
          var parts = trait_name.split("|");
          trait_html += '<option value="' + trait_id + '" data-synonym="" data-list_name="' + trait_name + '" title="' + parts[0] + '">' + parts[0] + '</option>\n';
        }
        jQuery('#trait_list').html(trait_html);

        if (!trait_ids.length) {
          return;
        }
        var synonymsRequestId = traitRequestId;
        jQuery.ajax({
          url: '/ajax/cvterm/get_synonyms',
          method: 'POST',
          data: { 'trait_ids': trait_ids },
          success: function(resp) {
            if (synonymsRequestId !== traitRequestNonce) {
              return;
            }
            var synonyms = resp.synonyms || {};
            trait_ids.forEach(function(id) {
              var value = synonyms[id] || '';
              jQuery('#trait_list option[value="' + id + '"]').attr('data-synonym', value);
            });
          },
          error: function() {
            if (synonymsRequestId !== traitRequestNonce) {
              return;
            }
            alert("An error occurred while retrieving synonyms for traits with ids " + trait_ids);
          }
        });
      },
      error: function() {
        if (traitRequestId !== traitRequestNonce) {
          return;
        }
        alert("An error occurred while transforming the list");
      }
    });

    // fetch plots and controls
    jQuery.ajax({
      url: '/ajax/breeder/search',
      method: 'POST',
      data: { 'categories': ['trials', 'plots'], 'data': data, 'querytypes': 0 },
      success: function(response) {
        var plots = response.list || [];
        var plot_ids = plots.map(function(val) { return val[0]; });
        // Use only the primary trial id for controls_by_plot, as the endpoint expects a single trial
        var trial_id_param = trial_ids[0];
        jQuery.ajax({
          url: '/ajax/breeders/trial/' + trial_id_param + '/controls_by_plot',
          data: { 'plot_ids': plot_ids },
          success: function(resp) {
            var accessions = resp.accessions;
            var accession_html;
            if (resp.accessions[0].length === 0) {
              accession_html = '<option value="" title="Select a control">No controls found</option>\n';
            } else {
              accession_html = '<option value="" title="Select a control">Select a control</option>\n';
              for (var i = 0; i < resp.accessions[0].length; i++) {
                accession_html += '<option value="' + accessions[0][i].stock_id + '" title="' + resp.accessions[0][i].stock_id + '">' + resp.accessions[0][i].accession_name + '</option>\n';
              }
            }
            jQuery('#control_list').html(accession_html);
            jQuery('#trait_list').focus();
          },
          error: function() {
            jQuery('#control_list').html('<option value="" title="Select a control">Error retrieving trial controls</option>');
          }
        });
      },
      error: function() {
        jQuery('#control_list').html('<option value="" title="Select a control">Error retrieving trial design</option>');
      }
    });
  });

  // Remove a previously selected trial from the chip list
  jQuery(document).on('click', '.remove-selected-trial', function(e) {
    e.preventDefault();
    var id = jQuery(this).data('trial-id');
    var $sel = jQuery('#select_trial_for_selection_index');
    if (!$sel.length) { return; }
    var current = $sel.val();
    if (!Array.isArray(current)) {
      current = current ? [current] : [];
    }
    var updated = current.filter(function(val) { return String(val) !== String(id); });
    $sel.val(updated);
    apply_trial_visibility($sel, updated);
    $sel.trigger('change');
  });

  // Add selected trait row
  jQuery('#trait_list').change(function() {
    var trait_id = jQuery('option:selected', this).val();
    if (!trait_id) { return; }
    var coefficient_id = trait_id + '_coefficient';
    var control_id = trait_id + '_control';
    var trait_name = jQuery('option:selected', this).text();
    var trait_synonym = jQuery('option:selected', this).data("synonym");
    var list_name = jQuery('option:selected', this).data("list_name");
    var control_html = jQuery('#control_list').html() || '<option value="">Select a control</option>';

    var trait_html =
      "<tr id='" + trait_id + "_row'>" +
        "<td><a href='/cvterm/" + trait_id + "/view' data-list_name='" + list_name + "' data-value='" + trait_id + "'>" + trait_name + "</a></td>" +
        "<td><p id='" + trait_id + "_synonym'>" + (trait_synonym || 'None') + "<p></td>" +
        "<td><input type='text' id='" + coefficient_id + "' class='form-control' placeholder='Default is 1'></input></td>" +
        "<td><select class='form-control' id='" + control_id + "'>" + control_html + "</select></td>" +
        "<td align='center'><a title='Remove' id='" + trait_id + "_remove' href='javascript:remove_trait(" + trait_id + ")'><span class='glyphicon glyphicon-remove'></span></a></td>" +
      "</tr>";

    jQuery('#trait_table').append(trait_html);
    jQuery('#select_message').text('Add another trait').attr('selected', true);

    update_formula();
    jQuery('#' + coefficient_id).focus();

    jQuery('#' + coefficient_id).change(function() {
      if (isNaN(jQuery(this).val())) {
        jQuery(this).val('');
        document.getElementById('selection_index_error_message').innerHTML =
          "<center><li class='list-group-item list-group-item-danger'> Error.<br> Index coefficients must be a positive or negative number.</li></center>";
        jQuery('#selection_index_error_dialog').modal("show");
      } else {
        update_formula();
        jQuery('#trait_list').focus();
      }
    });

    jQuery('#' + control_id).change(function() {
      update_formula();
    });
  });

  // Helper to actually perform the save
  function do_save_sin(new_name) {
    if (jQuery('#trait_table').children().length < 1) {
      document.getElementById('selection_index_error_message').innerHTML =
        "<center><li class='list-group-item list-group-item-danger'> Formula not saved.<br> At least one trait must be selected before saving a SIN formula.</li></center>";
      jQuery('#selection_index_error_dialog').modal("show");
      return;
    }

    if (!new_name) {
      document.getElementById('selection_index_error_message').innerHTML =
        "<center><li class='list-group-item list-group-item-danger'> Formula not saved.<br> Please enter a name for the SIN formula.</li></center>";
      jQuery('#selection_index_error_dialog').modal("show");
      return;
    }

    var lo = new CXGN.List();
    console.log("Saving SIN formula to list named " + new_name);

    var selected_trait_rows = jQuery('#trait_table').children();
    var traits = [], coefficients = [], controls = [];

    jQuery(selected_trait_rows).each(function() {
      var trait_id = jQuery('a', this).data("value");
      traits.push(jQuery('a', this).data("list_name"));
      coefficients.push(jQuery('#' + trait_id + '_coefficient').val() || 1);

      var control_name;
      if (jQuery('#' + trait_id + '_control option:selected').val()) {
        control_name = jQuery('#' + trait_id + '_control option:selected').text();
      } else {
        control_name = '';
      }
      controls.push(control_name.trim());
    });

    var data = "traits:" + traits.join();
    data += "\nnumbers:" + coefficients.join();
    data += "\naccessions:" + controls.join();
    console.log("Saving SIN formula to dataset: " + JSON.stringify(data));

    var list_id = lo.newList(new_name);
    var elementsAdded = false;
    if (list_id > 0) {
      elementsAdded = lo.addToList(list_id, data);
      lo.setListType(list_id, 'dataset');
    }
    if (elementsAdded) {
      alert("Saved SIN formula with name " + new_name);
    }
  }

  // Save SIN formula – with special behaviour in LOAD mode
  jQuery('#save_sin').click(function() {
    // Check which workflow mode we're in
    var mode = jQuery('input[name="sin_workflow"]:checked').val() || 'create';

    // If we're in LOAD mode and we have a loaded formula, show the popup
    if (mode === 'load' && (window.CURRENT_SIN_FORMULA_NAME || jQuery('#sin_list_list_select').val())) {
      var existing = window.CURRENT_SIN_FORMULA_NAME || jQuery('#save_sin_name').val();
      jQuery('#sin_save_current_name').text(existing || '(unnamed formula)');
      jQuery('#sin_save_use_same').prop('checked', true);
      jQuery('#sin_save_new_name').val('');
      jQuery('#sin_save_choice_modal').modal('show');
      return;
    }

    // Normal CREATE mode behaviour: just save using whatever is in the input
    var new_name = jQuery('#save_sin_name').val();
    do_save_sin(new_name);
  });

  // Handle "Save" / "Discard" buttons from the popup in LOAD mode
  jQuery('#sin_save_confirm_button').click(function() {
    var mode = jQuery('input[name="sin_workflow"]:checked').val() || 'create';
    if (mode !== 'load') {
      // Shouldn't happen, but just in case
      jQuery('#sin_save_choice_modal').modal('hide');
      return;
    }

    var saveMode = jQuery('input[name="sin_save_mode"]:checked').val();
    var targetName;

    if (saveMode === 'same') {
      targetName = window.CURRENT_SIN_FORMULA_NAME || jQuery('#save_sin_name').val();
    } else {
      targetName = jQuery('#sin_save_new_name').val();
    }

    if (!targetName) {
      alert('Please enter a name to save the formula.');
      return;
    }

    // reflect chosen name in the main input as well
    jQuery('#save_sin_name').val(targetName);
    jQuery('#sin_save_choice_modal').modal('hide');

    do_save_sin(targetName);
    window.CURRENT_SIN_FORMULA_NAME = targetName;
  });

  jQuery('#sin_save_discard_button').click(function() {
    // Just close the modal; no save is performed
    jQuery('#sin_save_choice_modal').modal('hide');
  });


  jQuery('#selection_index_more_info').click(function() {
    jQuery('#selection_index_info_dialog').modal("show");
  });

  jQuery('#selection_index_error_close_button').click(function() {
    document.getElementById('selection_index_error_message').innerHTML = "";
  });

  jQuery(document).on('change', '#source_type_select', function() {
    jQuery('#trial_dual_wrapper').hide();
    load_items_for_source(jQuery(this).val());
  });

  jQuery(document).on('keyup change', '#trial_search_input', function () {
    trialDualState.search = jQuery(this).val();
    renderTrialDualLists();
  });

  jQuery(document).on('click', '.trial-add-btn', function (e) {
    e.preventDefault();
    var id = jQuery(this).data('id');
    var item = trialDualState.all.find(function (t) { return String(t.id) === String(id); });
    if (!item) return;
    var already = trialDualState.selected.find(function (t) { return String(t.id) === String(id); });
    if (already) return;
    trialDualState.selected.push(item);
    applySelectionToHiddenSelect(trialDualState.selected.map(function (t) { return t.id; }));
    renderTrialDualLists();
  });

  jQuery(document).on('click', '.trial-remove-btn', function (e) {
    e.preventDefault();
    var id = jQuery(this).data('id');
    trialDualState.selected = trialDualState.selected.filter(function (t) { return String(t.id) !== String(id); });
    applySelectionToHiddenSelect(trialDualState.selected.map(function (t) { return t.id; }));
    renderTrialDualLists();
  });

  jQuery(document).on('click', '#trial_select_all_btn', function () {
    var term = (trialDualState.search || '').toLowerCase();
    var selMap = {};
    trialDualState.selected.forEach(function (t) { selMap[String(t.id)] = true; });
    trialDualState.all.forEach(function (t) {
      var matches = !term || t.name.toLowerCase().indexOf(term) !== -1;
      if (matches) selMap[String(t.id)] = true;
    });
    trialDualState.selected = trialDualState.all.filter(function (t) { return selMap[String(t.id)]; });
    applySelectionToHiddenSelect(trialDualState.selected.map(function (t) { return t.id; }));
    renderTrialDualLists();
  });

  jQuery(document).on('click', '#trial_clear_btn', function () {
    trialDualState.selected = [];
    applySelectionToHiddenSelect([]);
    renderTrialDualLists();
  });

  jQuery(document).on('click', '#save_selected_trials_btn', function () {
    if (!isTrialSourceType()) {
      showWarning('Saved trial lists are only available when the source type is Trials.');
      return;
    }
    var $sel = jQuery('#select_trial_for_selection_index');
    if (!$sel.length) {
      showError('Please load trials first.');
      return;
    }
    var selection = collectSelectedTrials();
    var selected_ids = selection.ids;
    var nameMap = selection.nameMap;
    if (!selected_ids.length) {
      selected_ids = $sel.val() || [];
      if (!Array.isArray(selected_ids)) {
        selected_ids = selected_ids ? [selected_ids] : [];
      }
      selected_ids = selected_ids.map(function (id) {
        return String(id);
      });
    }
    if (!selected_ids.length) {
      showError('Please select at least one trial to save.');
      return;
    }
    var list_data = selected_ids.map(function (id) {
      var name = nameMap[id];
      if (!name) {
        name = $sel.find('option[value="' + id + '"]').text();
      }
      return id + '|' + (name || id);
    });
    try {
      var lo = new CXGN.List();
      var listName = window.prompt('Enter a name for the trial list:', '');
      if (listName === null) {
        return;
      }
      listName = listName.trim();
      if (!listName) {
        showWarning('Please provide a name to save the trial list.');
        return;
      }
      var listDesc = window.prompt('Enter an optional description:', '') || '';
      var newListId = lo.newList(listName, listDesc);
      if (!newListId) {
        showError('Could not create the list. You may already have a list by that name or be logged out.');
        return;
      }
      lo.setListType(newListId, 'trials');
      var count = lo.addBulk(newListId, list_data);
      if (typeof count !== 'number') {
        count = 0;
      }
      var savedMessage = 'Saved "' + listName + '" with ' + count + ' trial' + (count === 1 ? '' : 's') + '.';
      if (count === 0) {
        savedMessage += ' (Trials may already be in the list.)';
      }
      alert(savedMessage);
      refreshSavedTrialListMenu(lo);
    } catch (e) {
      console.error('save_selected_trials_btn error', e);
      showError('There was a problem saving the trial list.');
    }
  });

  jQuery(document).on('change', '#select_trial_for_selection_index', function () {
    if (typeof window.syncTrialDualListUI === 'function' && !window.trialDualSyncLock) {
      window.syncTrialDualListUI(jQuery(this).val() || []);
    }
  });

  jQuery(document).on('change', '#trial_source_list_list_select', function () {
    var list_id = jQuery(this).val();
    if (!isTrialSourceType() || !list_id) {
      return;
    }
    if (list_id.indexOf('dataset:') === 0) {
      loadTrialListFromDataset(list_id.split(':')[1]);
      return;
    }
    try {
      var lo = new CXGN.List();
      var list_data = lo.getListData(list_id);
      var elems = (list_data && list_data.elements) ? list_data.elements : [];
      var parseJsonString = function (value) {
        if (typeof value !== 'string') {
          return value;
        }
        var trimmed = value.trim();
        if (
          (trimmed.charAt(0) === '[' && trimmed.charAt(trimmed.length - 1) === ']') ||
          (trimmed.charAt(0) === '{' && trimmed.charAt(trimmed.length - 1) === '}')
        ) {
          try {
            return JSON.parse(trimmed);
          } catch (err) {
            return value;
          }
        }
        return value;
      };

      var shouldTransform = true;
      for (var i = 0; i < elems.length; i++) {
        var elem = elems[i];
        var str = '';
        if (typeof elem === 'string') {
          str = elem;
        } else if (Array.isArray(elem) && elem.length && typeof elem[0] === 'string') {
          str = elem[0];
        } else if (typeof elem === 'object' && elem) {
          if (elem.content) {
            str = elem.content;
          } else if (elem.value) {
            str = elem.value;
          }
        }
        if (str.indexOf('|') !== -1) {
          shouldTransform = false;
          break;
        }
      }
      var transformEntries = [];
      var shouldTransform = elems.every(function (el) {
        var text = listElementText(el);
        return text.indexOf('|') === -1;
      });
      try {
        if (shouldTransform) {
          transformEntries = lo.transform(list_id, 'projects_2_project_ids') || [];
        }
      } catch (err) {
        transformEntries = [];
      }

      var extractTransformIds = function (entries, prefix) {
        var result = [];
        entries.forEach(function (entry) {
          if (!entry) return;
          var raw = entry;
          if (Array.isArray(entry)) {
            raw = entry[0];
          }
          if (typeof raw !== 'string') {
            raw = String(raw);
          }
          if (raw.indexOf('|') !== -1) {
            return;
          }
          if (/^\d+$/.test(raw.trim())) {
            result.push(raw.trim());
            return;
          }
          var parts = raw.split(/:(.+)/);
          if (parts.length < 2) return;
          var key = parts[0];
          var values = parts[1];
          if (key === prefix || key === (prefix.replace(/_ids$/, '') + '_ids')) {
            values.split(',').forEach(function (id) {
              if (id) {
                result.push(String(id).trim());
              }
            });
          }
        });
        return result;
      };

      var ids = extractTransformIds(transformEntries, 'project_ids');
      if (!ids.length) {
        ids = elems.map(parseListElementId).filter(Boolean);
      }
      ids = Array.from(new Set((ids || []).filter(Boolean)));
      if (!ids.length) {
        showWarning('This saved list does not contain trials we can load.');
        return;
      }
      var $sel = jQuery('#select_trial_for_selection_index');
      if ($sel.length) {
        if (typeof window.syncTrialDualListUI !== 'function') {
          build_trial_dual_list_ui($sel);
        }
        applyTrialListSelection(ids);
        if (isTrialSourceType()) {
          jQuery('#trial_dual_wrapper').show();
          setTrialModeVisibility(true);
        }
      }
    } catch (e) {
      console.error('load trial list error', e);
      showError('There was a problem loading the trial list.');
    }
  });

function loadTrialListFromDataset(datasetId) {
  if (!datasetId) {
    return;
  }
  jQuery.ajax({
    url: '/ajax/dataset/get/' + datasetId,
    method: 'GET',
    success: function (resp) {
      var dataset = resp && resp.dataset;
      var datasetTrials = dataset && dataset.categories && dataset.categories.trials ? dataset.categories.trials : [];
      if (!Array.isArray(datasetTrials) || !datasetTrials.length) {
        showWarning('The selected dataset does not list any trials we can load.');
        return;
      }
      var $sel = jQuery('#select_trial_for_selection_index');
      if (!$sel.length) {
        return;
      }
      var optionMap = {};
      $sel.find('option').each(function () {
        optionMap[jQuery(this).val()] = jQuery(this).text().trim();
      });
      var selected = [];
      datasetTrials.forEach(function (entry) {
        var id = parseListElementId(entry);
        if (id && optionMap[id]) {
          selected.push(id);
          return;
        }
        var text = listElementText(entry);
        if (!text) {
          return;
        }
        var match = $sel.find('option').filter(function () {
          return jQuery(this).text().trim() === text;
        });
        if (match.length) {
          selected.push(String(match.val()));
        }
      });
      var trials = Array.from(new Set(selected)).filter(Boolean);
      if (!trials.length) {
        showWarning('The selected dataset does not list any trials we can load.');
        return;
      }
      if (typeof window.syncTrialDualListUI !== 'function') {
        build_trial_dual_list_ui($sel);
      }
      applyTrialListSelection(trials);
      if (isTrialSourceType()) {
        jQuery('#trial_dual_wrapper').show();
        setTrialModeVisibility(true);
      }
      },
      error: function () {
        showError('Could not load the selected dataset.');
      }
    });
  }

  jQuery(document).on('click', '#load_selected_trial_list_btn', function () {
    if (!isTrialSourceType()) {
      return;
    }
    var $menuSelect = jQuery('#trial_source_list_list_select');
    if (!$menuSelect.length) {
      showError('Please load trials before picking a saved list.');
      return;
    }
    var list_id = $menuSelect.val();
    if (!list_id) {
      showError('Choose a saved trial list to load.');
      return;
    }
    $menuSelect.trigger('change');
  });

  // Main "Calculate Rankings" button in the wizard
  jQuery('#calculate_rankings_button').off('click.selectionIndex').on('click.selectionIndex', function() {
    if (jQuery('#trait_table').children().length < 1) {
      document.getElementById('selection_index_error_message').innerHTML =
        "<center><li class='list-group-item list-group-item-danger'> Error.<br> A trial and at least one trait must be selected before calculating rankings.</li></center>";
      jQuery('#selection_index_error_dialog').modal("show");
      return;
    }

    jQuery('#raw_avgs_div').html("");
    jQuery('#weighted_values_div').html("");

    var trial_ids = jQuery("#select_trial_for_selection_index").val();
    if (!trial_ids || (Array.isArray(trial_ids) && !trial_ids.length)) {
      document.getElementById('selection_index_error_message').innerHTML =
        "<center><li class='list-group-item list-group-item-danger'> Error.<br> At least one trial must be selected before calculating rankings.</li></center>";
      jQuery('#selection_index_error_dialog').modal("show");
      return;
    }
    if (!Array.isArray(trial_ids)) {
      trial_ids = [trial_ids];
    }

    var selected_trait_rows = jQuery('#trait_table').children();

    var trait_ids = [], column_names = [], weighted_column_names = [], coefficients = [], controls = [];

    var trial_name = jQuery('#select_trial_for_selection_index option:selected').map(function() {
      return jQuery(this).text();
    }).get().join(', ');
    column_names.push({ title: "Accession" });
    weighted_column_names.push({ title: "Accession" });

    jQuery(selected_trait_rows).each(function() {
      var trait_id = jQuery('a', this).data("value");
      trait_ids.push(trait_id);
      var trait = jQuery('#' + trait_id + '_synonym').text();
      if (trait === 'None' || !trait) {
        trait = jQuery('a', this).text();
      }
      var trait_term = trait;
      var coefficient = jQuery('#' + trait_id + '_coefficient').val() || 1;

      coefficients.push(coefficient);
      var control = jQuery('#' + trait_id + '_control option:selected').val() || '';
      controls.push(control);
      if (control) {
        trait_term += " as a fraction of " + jQuery('#' + trait_id + '_control option:selected').text();
      }
      column_names.push({ title: trait_term });
      weighted_column_names.push({ title: coefficient + " * (" + trait_term + ")" });
    });

    weighted_column_names.push({ title: "SIN" }, { title: "SIN Rank" });

    var allow_missing = jQuery("#allow_missing").is(':checked');

    jQuery.ajax({
      url: '/ajax/breeder/search/avg_phenotypes',
      method: 'POST',
      data: {
        'trial_id': trial_ids[0],     // keep old behaviour
        'trial_ids': trial_ids,       // optional array for backend to use if supported
        'trait_ids': trait_ids,
        'coefficients': coefficients,
        'controls': controls,
        'allow_missing': allow_missing
      },
      success: function(response) {
        if (response.error) {
          alert(response.error);
          return;
        }
        var raw_avgs = response.raw_avg_values || [];
        var weighted_values = response.weighted_values || [];
        var trial_name = jQuery('#select_trial_for_selection_index option:selected').map(function() { return jQuery(this).text(); }).get().join(', ');
        build_table(raw_avgs, column_names, trial_name, 'raw_avgs_div');
        build_table(weighted_values, weighted_column_names, trial_name, 'weighted_values_div');
      },
      error: function() {
        alert("An error occurred while retrieving average phenotypes");
      }
    });
  });

});

// Build Datatables
function build_table(data, column_names, trial_name, target_div) {

  var table_id = target_div.replace("div", "table");
  var table_type = target_div.replace("_div", "");
  var table_html =
    '<br><br><div class="table-responsive" style="margin-top: 10px;">' +
      '<table id="' + table_id + '" class="table table-hover table-striped table-bordered" width="100%">' +
        '<caption class="well well-sm" style="caption-side: bottom;margin-top: 10px;">' +
          '<center> Table description: <i>' + table_type + ' for trial(s) ' + trial_name + '.</i></center>' +
        '</caption>' +
      '</table>' +
    '</div>';

  if (table_type === 'weighted_values') {
    table_html +=
      '<div class="col-sm-12 col-md-12 col-lg-12">' +
        '<hr><label>Save top ranked accessions to a list: </label><br><br>' +
        '<div class="col-sm-3 col-md-3 col-lg-3" style="display: inline-block">' +
          '<label>By number:</label>&nbsp;<select class="form-control" id="top_number"></select>' +
        '</div>' +
        '<div class="col-sm-3 col-md-3 col-lg-3" style="display: inline-block">' +
          '<label>Or percent:</label>&nbsp;<select class="form-control" id="top_percent"></select>' +
        '</div>' +
        '<div class="col-sm-6 col-md-6 col-lg-6">' +
          '<div style="text-align:right" id="ranking_to_list_menu"></div>' +
          '<div id="top_ranked_names" style="display: none;"></div>' +
        '</div>' +
        '<br><br><br><br><br>' +
      '</div>';
  }

  jQuery('#' + target_div).html(table_html);

  var export_message = 'Accession rankings calculated using a selection index at ' + window.location.href;
  var penultimate_column = column_names.length - 2;

  jQuery('#' + table_id).DataTable({
    dom: 'Bfrtip',
    buttons: [
      'copy',
      {
        extend: 'excelHtml5',
        title: trial_name + '_rankings'
      },
      {
        extend: 'csvHtml5',
        title: trial_name + '_rankings'
      },
      {
        extend: 'pdfHtml5',
        title: trial_name + '_rankings',
        message: export_message
      },
      {
        extend: 'print',
        message: export_message
      }
    ],
    data: data,
    destroy: true,
    paging: true,
    order: [[1, 'asc']],
    lengthMenu: [
      [10, 25, 50, -1],
      [10, 25, 50, "All"]
    ],
    columns: column_names,
    order: [[penultimate_column, "desc"]]
  });

  if (table_type === 'weighted_values') {
    var table = jQuery('#weighted_values_table').DataTable();
    var name_links = table.column(0).data();

    jQuery("#top_number").append('<option value="">Select a number</option>');
    jQuery("#top_percent").append('<option value="">Select a percent</option>');

    for (var i = 1; i <= name_links.length; i++) {
      jQuery("#top_number").append('<option value=' + i + '>' + i + '</option>');
    }
    for (var j = 1; j <= 100; j++) {
      jQuery("#top_percent").append('<option value=' + j + '>' + j + '%</option>');
    }

    jQuery('select[id^="top_"]').change(function() {
      var type = this.id.split("_").pop();
      var number = jQuery('#top_' + type).val();
      var names = [];

      if (type === 'number') {
        jQuery("#top_percent").val('');
        for (var k = 0; k < number; k++) {
          names.push(name_links[k].match(/<a [^>]+>([^<]+)<\/a>/)[1] + '\n');
        }
      } else if (type === 'percent') {
        jQuery("#top_number").val('');
        var adjusted_number = Math.round((number / 100) * name_links.length);
        for (var m = 0; m < adjusted_number; m++) {
          names.push(name_links[m].match(/<a [^>]+>([^<]+)<\/a>/)[1] + '\n');
        }
      }
      jQuery('#top_ranked_names').html(names);
      addToListMenu('ranking_to_list_menu', 'top_ranked_names', { listType: 'accessions' });
    });
  }
}

// NEW: Load SIN formula in a way that does NOT require a source
function load_sin() {
  // Look for either the new or legacy select IDs
  var sin_list_id = jQuery('#sin_list_list_select').val() || jQuery('#sin_formula_list_select').val();
  if (!sin_list_id) {
    update_formula();
    return;
  }

  // *** NEW: remember the name of the loaded formula ***
  var selectedOption = jQuery('#sin_list_list_select option:selected');
  if (selectedOption.length) {
    window.CURRENT_SIN_FORMULA_NAME = jQuery.trim(selectedOption.text());
    jQuery('#save_sin_name').val(window.CURRENT_SIN_FORMULA_NAME);
  }

  var lo = new CXGN.List();
  var list_data = lo.getListData(sin_list_id);
  var sin_data = list_data && list_data.elements ? list_data.elements : [];

  var traits = [], coefficients = [], controls = [];

  for (var i = 0; i < sin_data.length; i++) {
    var array = sin_data[i];
    array.shift();
    var string = array.shift();
    var parts = string.split(/:(.+)/);
    var key = parts[0];
    var values = parts[1];
    if (key === 'traits') {
      traits = values.split(",");
    } else if (key === 'numbers') {
      coefficients = values.split(",");
    } else if (key === 'accessions') {
      controls = values.split(",");
    }
  }

  var ids = lo.transform(sin_list_id, 'dataset_2_dataset_ids');
  var trait_ids = [], control_ids = [];

  for (var j = 0; j < ids.length; j++) {
    var data = ids[j];
    var parts2 = data.split(/:(.+)/);
    var key2 = parts2[0];
    var values2 = parts2[1];
    if (key2 === 'trait_ids') {
      trait_ids = values2.split(",");
    } else if (key2 === 'accession_ids') {
      control_ids = values2.split(",");
    }
  }

  jQuery('#selection_index').html("");
  jQuery('#trait_table').html("");

  if (!trait_ids || trait_ids.length === 0) {
    update_formula();
    return;
  }

  // Try to fetch synonyms; if it fails, we just leave them blank
  var synonyms = {};
  try {
    jQuery.ajax({
      url: '/ajax/cvterm/get_synonyms',
      async: false,
      method: 'POST',
      data: { 'trait_ids': trait_ids },
      success: function(resp) {
        synonyms = resp && resp.synonyms ? resp.synonyms : {};
      },
      error: function() {
        synonyms = {};
      }
    });
  } catch (e) {
    synonyms = {};
  }

  var control_html = jQuery('#control_list').html() || '<option value="">Select a control</option>';

  for (var t = 0; t < trait_ids.length; t++) {
    var trait_id = trait_ids[t];
    var coefficient_input_id = trait_id + '_coefficient';
    var control_select_id = trait_id + '_control';

    var saved_trait_name = traits[t] || '';
    var partsName = saved_trait_name.split("|");
    var trait_label = partsName[0] || saved_trait_name || ('Trait ' + trait_id);
    var trait_syn = synonyms[trait_id] || 'None';

    var row_html =
      "<tr id='" + trait_id + "_row'>" +
        "<td><a href='/cvterm/" + trait_id + "/view' data-value='" + trait_id + "'>" + trait_label + "</a></td>" +
        "<td><p id='" + trait_id + "_synonym'>" + trait_syn + "<p></td>" +
        "<td><input type='text' id='" + coefficient_input_id + "' class='form-control' placeholder='Default is 1'></input></td>" +
        "<td><select class='form-control' id='" + control_select_id + "'>" + control_html + "</select></td>" +
        "<td align='center'><a title='Remove' id='" + trait_id + "_remove' href='javascript:remove_trait(" + trait_id + ")'><span class='glyphicon glyphicon-remove'></span></a></td>" +
      "</tr>";

  jQuery('#trait_table').append(row_html);

    // Set coefficient
    var coeff = coefficients[t] || 1;
    jQuery('#' + coefficient_input_id).val(coeff);

    // Try to select saved control if it exists in the list
    var control_id = control_ids[t];
    if (control_id && jQuery('#' + control_select_id + ' option[value="'+control_id+'"]').length) {
      jQuery('#' + control_select_id).val(control_id);
    }

    // Bind change handlers like in the "add trait" path
    jQuery('#' + coefficient_input_id).change(function() {
      if (isNaN(jQuery(this).val())) {
        jQuery(this).val('');
        document.getElementById('selection_index_error_message').innerHTML =
          "<center><li class='list-group-item list-group-item-danger'> Error.<br> Index coefficients must be a positive or negative number.</li></center>";
        jQuery('#selection_index_error_dialog').modal("show");
      } else {
        update_formula();
      }
    });
    jQuery('#' + control_select_id).change(function() {
      update_formula();
    });
  }

  jQuery('#select_message').text('Add another trait').attr('selected', true);
  update_formula();
}

// Remove row
function remove_trait(trait_id) {
  jQuery('#' + trait_id + '_row').remove();
  update_formula();
}

// Update formula text
function update_formula() {
  var selected_trait_rows = jQuery('#trait_table').children();
  if (selected_trait_rows.length < 1) {
    jQuery('#ranking_formula').html("<center><i>Select a trial, then pick traits and coefficients (or load a saved formula).</i></center>");
    jQuery('#calculate_rankings').addClass('disabled');
    jQuery('#save_sin').addClass('disabled');
    jQuery('#calculate_rankings_button').addClass('disabled');
    jQuery('#save_sin_name').addClass('disabled');
    return;
  }

  var formula = "<center><b>SIN = </b></center>";
  var term_number = 0;

  jQuery(selected_trait_rows).each(function() {
    var trait_id = jQuery('a', this).data("value");
    var trait = jQuery('#' + trait_id + '_synonym').text();
    if (trait === 'None' || !trait) {
      trait = jQuery('a', this).text();
    }
    var trait_term = trait;
    var coefficient = jQuery('#' + trait_id + '_coefficient').val() || 1;
    if (jQuery('#' + trait_id + '_control option:selected').val()) {
      trait_term += " as a fraction of " + jQuery('#' + trait_id + '_control option:selected').text();
    }

    if (term_number === 0 || coefficient <= 0) {
      formula += "<center>" + coefficient + " * ( " + trait_term + ")</center>";
    } else {
      formula += "<center>+ " + coefficient + " * ( " + trait_term + ")</center>";
    }
    term_number++;
  });

  jQuery('#ranking_formula').html(formula);
  jQuery('#calculate_rankings').removeClass('disabled');
  jQuery('#calculate_rankings_button').removeClass('disabled');
  jQuery('#save_sin').removeClass('disabled');
  jQuery('#save_sin_name').removeClass('disabled');
}
