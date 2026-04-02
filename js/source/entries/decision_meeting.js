(function (jQuery) {
  'use strict';
  jQuery(function ($) {

    window.DM_MEETING_CACHE = window.DM_MEETING_CACHE || {};

    /* ===== Root detection ===== */
    var $root =
      $('#decision_meeting_main').length ? $('#decision_meeting_main') :
      $('#decision_table').length       ? $('#decision_table').closest('.panel, .box, .card, .well, body') :
      $('#meeting_table').length        ? $('#meeting_table').closest('.panel, .box, .card, .well, body') :
      $();

    var hasDT = $.fn && $.fn.DataTable;

    function adjustVisibleDataTables() {
      if (!$.fn || !$.fn.dataTable) return;

      ['#decision_table', '#meeting_table', '#approvers_table'].forEach(function(sel) {
        var $tbl = $(sel);
        if (!$tbl.length) return;
        if (!$.fn.DataTable.isDataTable($tbl[0])) return;

        var dt = $tbl.DataTable();

        try { dt.columns.adjust(); } catch (e) {}
        try {
          if (dt.responsive && typeof dt.responsive.recalc === 'function') {
            dt.responsive.recalc();
          }
        } catch (e) {}
        try {
          if (dt.fixedHeader) {
            dt.fixedHeader.adjust();
          }
        } catch (e) {}

        var $wrap = $tbl.closest('.dataTables_wrapper');
        var $scrollHead = $wrap.find('.dataTables_scrollHeadInner');
        var $scrollHeadTable = $wrap.find('.dataTables_scrollHeadInner table');
        var $scrollBodyTable = $wrap.find('.dataTables_scrollBody table');

        if ($scrollBodyTable.length && $scrollHead.length && $scrollHeadTable.length) {
          var bodyWidth = $scrollBodyTable.outerWidth();
          if (bodyWidth) {
            $scrollHead.width(bodyWidth);
            $scrollHeadTable.width(bodyWidth);
          }
        }
      });
    }

    var dmResizeTimer = null;
    $(window)
      .off('resize.dmTables orientationchange.dmTables')
      .on('resize.dmTables orientationchange.dmTables', function () {
        clearTimeout(dmResizeTimer);
        dmResizeTimer = setTimeout(function () {
          adjustVisibleDataTables();
        }, 120);
      });

    $(document).on('shown.bs.collapse shown.bs.tab shown.bs.modal', function () {
      setTimeout(function () {
        adjustVisibleDataTables();
      }, 80);
    });

    function findSectionBody($sec){
      var $b = $sec.find('.panel-body, .detail-section-body, .box-body, .card-body, .well').first();
      return $b.length ? $b : $sec;
    }

    /* ----------------------- Client state ---------------------- */
    var STATE = {
      list_id: '',
      rows: [],
      baseRows: [],
      accessions: [],
      programs: [],
      decisionsMap: new Map(),
      currentBpFilter: ''
    };

    function injectStyles(){
      if (document.getElementById('dm-decision-styles')) return;
      var css = `
        .dm-decision-select { min-width: 130px; }
        .dm-dec-none   { background-color: #fff; }
        .dm-dec-drop   { background-color: #f8d7da; color:#842029; }
        .dm-dec-hold   { background-color: #ffe5b4; color:#7a3e00; }
        .dm-dec-advance{ background-color: #d4edda; color:#0f5132; }
        .dm-dec-jump   { background-color: #e6d4ff; color:#2e1065; }
        .dm-bp-header-select { max-width: 220px; margin-top:6px; }
        .dm-topbar-search { width:260px; display:inline-block; }
        .dm-meeting-check { transform: scale(1.1); }

        .dm-meeting-check[disabled] {
          cursor: not-allowed;
          opacity: 0.45;
        }

        .dm-meeting-select-disabled {
          color: #999;
          font-size: 12px;
          font-style: italic;
          display: inline-block;
          white-space: nowrap;
        }

        .dm-new-stage-cell {
          font-weight: 600;
          color: #1f4d7a;
        }

        .dm-stage-dialog::backdrop {
          background: rgba(0,0,0,0.35);
        }

        .dm-stage-dialog {
          border: none;
          border-radius: 10px;
          box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }

        #summary_table_wrapper .dataTables_filter {
          float: right !important;
          text-align: right !important;
          margin-bottom: 8px;
        }

        #summary_table_wrapper .dataTables_filter input {
          margin-left: 6px;
          min-width: 220px;
        }

        #summary_table_wrapper .dataTables_length {
          display: none !important;
        }

        #summary_table {
          width: 100% !important;
        }

        #decision_table,
        #meeting_table,
        #approvers_table {
          width: 100% !important;
        }

        .dataTables_scrollHeadInner table,
        .dataTables_scrollBody table {
          margin: 0 !important;
        }

        #decision_table_wrapper .dataTables_filter {
          float: right !important;
          text-align: right !important;
          margin-bottom: 8px;
        }

        #decision_table_wrapper .dataTables_filter input {
          margin-left: 6px;
          min-width: 220px;
        }

        #decision_table_wrapper .dataTables_length {
          display: none !important;
        }

        #dm-saveall-wrap {
          margin-top: 12px;
          margin-bottom: 18px;
          display: flex;
          justify-content: flex-end;
          gap: 8px;
        }

        #dm_save_all_btn {
          min-width: 170px;
          font-weight: 600;
        }

        .dm-save-dialog::backdrop {
          background: rgba(0,0,0,0.35);
        }

        .dm-save-dialog {
          border: none;
          border-radius: 12px;
          box-shadow: 0 10px 30px rgba(0,0,0,0.2);
          width: min(1200px, 96vw);
          max-width: 1200px;
          padding: 0;
        }

        .dm-save-dialog-header,
        .dm-save-dialog-footer {
          padding: 14px 18px;
          background: #fff;
        }

        .dm-save-dialog-body {
          padding: 0 18px 18px 18px;
          background: #fff;
        }

        .dm-save-meta-grid {
          display: grid;
          grid-template-columns: repeat(3, minmax(180px, 1fr));
          gap: 10px 16px;
          margin-bottom: 14px;
        }

        .dm-save-meta-box {
          border: 1px solid #ddd;
          border-radius: 8px;
          padding: 10px 12px;
          background: #fafafa;
        }

        .dm-save-meta-label {
          display: block;
          font-size: 12px;
          color: #666;
          margin-bottom: 4px;
          text-transform: uppercase;
          letter-spacing: .03em;
        }

        .dm-save-meta-value {
          font-size: 14px;
          font-weight: 600;
          word-break: break-word;
        }

        #dm-save-meeting-notes {
          min-height: 70px;
          resize: vertical;
          margin-bottom: 14px;
        }

        #dm-save-report-table {
          width: 100%;
          border-collapse: collapse;
        }

        #dm-save-report-table th,
        #dm-save-report-table td {
          border: 1px solid #ddd;
          padding: 8px;
          vertical-align: top;
        }

        #dm-save-report-table th {
          background: #f5f5f5;
          position: sticky;
          top: 0;
          z-index: 1;
        }

        .dm-save-report-wrap {
          max-height: 52vh;
          overflow: auto;
          border: 1px solid #ddd;
          border-radius: 8px;
        }

        .dm-save-comment {
          min-width: 220px;
          min-height: 62px;
          resize: vertical;
        }

        .dm-save-empty {
          color: #777;
          font-style: italic;
        }
      `;
      var el = document.createElement('style');
      el.id = 'dm-decision-styles';
      el.type = 'text/css';
      el.appendChild(document.createTextNode(css));
      document.head.appendChild(el);
    }
    injectStyles();

    function injectTopbar(){
      if (!$root.length) return;
      var $dest = findSectionBody($root);
      if ($('#dm-topbar').length) return;
      var html =
        '<div id="dm-topbar" class="row" style="margin-top:5px;margin-bottom:10px; align-items:center;">' +
          '<div class="col-sm-6" style="display:flex; gap:8px; align-items:center;">' +
            '<label class="control-label" for="dm_list_sel">Accession List</label>' +
            '<select id="dm_list_sel" class="form-control" style="width:auto; min-width:220px;"><option value="">(choose a list)</option></select>' +
            '<button id="dm_clear_filters" class="btn btn-default">Clear</button>' +
          '</div>' +
          '<div class="col-sm-6 text-right"></div>' +
        '</div>';
      $dest.prepend(html);
    }
    injectTopbar();

    function getSelectedMeetingAttendees(){
      var $checked = $('.dm-meeting-check:checked').first();
      if (!$checked.length) return '';

      var meetingId = $checked.data('meeting-id');
      if (!meetingId) return '';

      var cached = window.DM_MEETING_CACHE && window.DM_MEETING_CACHE[String(meetingId)];
      if (cached && cached.attendees_text) {
        return $.trim(cached.attendees_text || '');
      }

      var attendeesText = '';

      $('#meeting_table tbody tr').each(function(){
        var $tr = $(this);
        var $chk = $tr.find('.dm-meeting-check').first();
        if (String($chk.data('meeting-id') || '') === String(meetingId)) {
          attendeesText = $.trim($tr.children('td').eq(5).text() || '');
          return false;
        }
      });

      return attendeesText;
    }

    function ensureSaveAllUI(){
      if (!$('#decision_table').length) return;

      if (!$('#dm-saveall-wrap').length) {
        var $target = $('#decision_table').closest('.dataTables_wrapper');
        if (!$target.length) {
          $target = $('#decision_table').closest('.table-responsive, .panel, .box, .card, .well, div').first();
        }
        if ($target.length) {
          $target.after(
            '<div id="dm-saveall-wrap">' +
              '<button type="button" id="dm_save_all_btn" class="btn btn-primary">Save all decisions</button>' +
            '</div>'
          );
        }
      }

      if (!document.getElementById('dm_save_dialog')) {
        var html = ''
          + '<dialog id="dm_save_dialog" class="dm-save-dialog">'
          + '  <div class="dm-save-dialog-header">'
          + '    <div style="display:flex;justify-content:space-between;align-items:center;gap:12px;">'
          + '      <div>'
          + '        <div style="font-size:20px;font-weight:700;">Decision report before saving</div>'
          + '        <div style="font-size:13px;color:#666;">Review the meeting data and add comments for each accession before sending to the controller.</div>'
          + '      </div>'
          + '      <button type="button" id="dm_save_dialog_close_x" class="btn btn-default">Close</button>'
          + '    </div>'
          + '  </div>'
          + '  <div class="dm-save-dialog-body">'
          + '    <div class="dm-save-meta-grid">'
          + '      <div class="dm-save-meta-box"><span class="dm-save-meta-label">Meeting</span><div id="dm-save-meeting-name" class="dm-save-meta-value"></div></div>'
          + '      <div class="dm-save-meta-box"><span class="dm-save-meta-label">Date</span><div id="dm-save-meeting-date" class="dm-save-meta-value"></div></div>'
          + '      <div class="dm-save-meta-box"><span class="dm-save-meta-label">Attendees</span><div id="dm-save-meeting-attendees" class="dm-save-meta-value"></div></div>'
          + '    </div>'
          + '    <label for="dm-save-meeting-notes" style="font-weight:600; margin-bottom:6px;">Meeting notes</label>'
          + '    <textarea id="dm-save-meeting-notes" class="form-control" placeholder="Meeting notes to send with this report"></textarea>'
          + '    <div class="dm-save-report-wrap">'
          + '      <table id="dm-save-report-table">'
          + '        <thead>'
          + '          <tr>'
          + '            <th>Accession</th>'
          + '            <th>Breeding Program</th>'
          + '            <th>Previous Stage</th>'
          + '            <th>Decision</th>'
          + '            <th>New Stage</th>'
          + '            <th>Current Notes</th>'
          + '            <th>Comment Before Save</th>'
          + '          </tr>'
          + '        </thead>'
          + '        <tbody></tbody>'
          + '      </table>'
          + '    </div>'
          + '  </div>'
          + '  <div class="dm-save-dialog-footer" style="display:flex;justify-content:flex-end;gap:8px;">'
          + '    <button type="button" id="dm_save_dialog_cancel" class="btn btn-default">Cancel</button>'
          + '    <button type="button" id="dm_confirm_save_all_btn" class="btn btn-primary">Confirm and save</button>'
          + '  </div>'
          + '</dialog>';
        $('body').append(html);

        $(document)
          .off('click.dmSaveDialogClose', '#dm_save_dialog_close_x, #dm_save_dialog_cancel')
          .on('click.dmSaveDialogClose', '#dm_save_dialog_close_x, #dm_save_dialog_cancel', function(){
            var dlg = document.getElementById('dm_save_dialog');
            if (dlg) dlg.close('');
          });
      }
    }

    async function detectApiBase() {
      var hinted = document.querySelector('[data-dm-api-base]')?.getAttribute('data-dm-api-base');
      var candidates = [
        hinted,
        '/ajax/decisionmeeting',
        '/ajax/decision_meeting',
        '/ajax/decision'
      ].filter(Boolean);

      for (var i = 0; i < candidates.length; i++) {
        var base = candidates[i];
        try {
          var r = await fetch(base + '/ping', { headers:{ 'Accept':'application/json' } });
          var ct = r.headers.get('content-type') || '';
          if (!r.ok) continue;
          if (!ct.includes('application/json')) continue;
          var j = await r.json();
          if (j && (j.ok || j.lists || j.datasets)) return base;
        } catch (e) {}
      }
      return null;
    }

    function ajaxJSON(path, params){
      var base = window.DM_API_BASE || '';
      var q = params ? ('?' + new URLSearchParams(params)) : '';
      var url = base + path + q;

      return fetch(url, { headers:{ 'Accept':'application/json' } }).then(async function(r){
        var ct = r.headers.get('content-type') || '';
        if (!r.ok) {
          var txt = await r.text().catch(function(){ return ''; });
          throw new Error('HTTP ' + r.status + ' ' + r.statusText + ' on ' + url + '\n' + txt.slice(0, 200));
        }
        if (!ct.includes('application/json')) {
          var txt2 = await r.text().catch(function(){ return ''; });
          throw new Error('Non-JSON response for ' + url + ': ' + txt2.slice(0, 120) + '…');
        }
        return r.json();
      });
    }

    function ensureDatasetControl(){
      var $holder = $('#dataset_select');

      if ($holder.length) {
        if (!$holder.find('select').length) {
          $holder.html(
            '<select id="dm_dataset_sel" class="form-control input-sm" style="min-width:240px;">' +
              '<option value="">dataset ...</option>' +
            '</select>'
          );
        }
        return $('#dm_dataset_sel');
      }

      var selectors = [
        '#dm_dataset_sel',
        'select[name="dataset_id"]',
        '#dataset_id',
        '#dataset',
        'select[data-role="dataset-select"]'
      ];

      return $(selectors.join(', ')).first();
    }

    function ensureSummaryTbody(){
      var $table = $('#summary_table');

      if (!$table.length) {
        return $();
      }

      var $tbody = $table.find('tbody');
      if (!$tbody.length) {
        $tbody = $('<tbody></tbody>');
        $table.append($tbody);
      }

      return $tbody;
    }

    function ensureSummaryDataTable(){
      var $table = $('#summary_table');
      if (!hasDT || !$table.length) return null;

      if ($.fn.DataTable.isDataTable($table[0])) {
        return $table.DataTable();
      }

      return $table.DataTable({
        dom: 'ftip',
        pageLength: 20,
        lengthChange: false,
        searching: true,
        ordering: true,
        info: true,
        autoWidth: false,
        scrollX: true,
        order: [],
        drawCallback: function () {
          var api = this.api();
          setTimeout(function () {
            try { api.columns.adjust(); } catch (e) {}
          }, 0);
        },
        initComplete: function () {
          setTimeout(function () {
            try { $table.DataTable().columns.adjust(); } catch (e) {}
          }, 0);
        }
      });
    }

    function renderSummaryTable(rows){
      var $table = $('#summary_table');
      var $tbody = ensureSummaryTbody();
      if (!$table.length || !$tbody.length) return;

      if (hasDT) {
        var dt = ensureSummaryDataTable();
        if (!dt) return;

        dt.clear();

        (rows || []).forEach(function(r){
          dt.row.add([
            escapeHtml(r.accession || ''),
            escapeHtml(r.trait || ''),
            escapeHtml(r.min == null ? '' : r.min),
            escapeHtml(r.max == null ? '' : r.max),
            escapeHtml(r.average == null ? '' : r.average),
            escapeHtml(r.std == null ? '' : r.std)
          ]);
        });

        dt.draw(false);
        return;
      }

      setTimeout(function(){
        var $wrap = $('#summary_table_wrapper');
        var $plots = $('#dm-plots-wrap');
        if ($wrap.length && $plots.length) {
          $plots.insertAfter($wrap);
        }
      }, 0);

      $tbody.empty();

      if (!(rows || []).length) {
        $tbody.append('<tr><td colspan="6" class="text-center">No data found for this dataset.</td></tr>');
        return;
      }

      rows.forEach(function(r){
        $tbody.append(
          '<tr>' +
            '<td>' + escapeHtml(r.accession || '') + '</td>' +
            '<td>' + escapeHtml(r.trait || '') + '</td>' +
            '<td>' + escapeHtml(r.min == null ? '' : r.min) + '</td>' +
            '<td>' + escapeHtml(r.max == null ? '' : r.max) + '</td>' +
            '<td>' + escapeHtml(r.average == null ? '' : r.average) + '</td>' +
            '<td>' + escapeHtml(r.std == null ? '' : r.std) + '</td>' +
          '</tr>'
        );
      });
    }

    function loadDatasets(){
      return ajaxJSON('/datasets').then(function(resp){
        var $sel = ensureDatasetControl();

        if (!$sel.length) {
          return;
        }

        $sel.empty().append('<option value="">dataset ...</option>');

        ((resp && resp.datasets) || []).forEach(function(ds){
          var id   = ds.dataset_id || ds.sp_dataset_id || '';
          var name = ds.name || ds.dataset_name || ('Dataset ' + id);

          if (id !== '') {
            $sel.append('<option value="' + escapeHtml(id) + '">' + escapeHtml(name) + '</option>');
          }
        });
      }).catch(function(){});
    }

    function loadDatasetSummary(datasetId){
      var $table = $('#summary_table');
      var $tbody = ensureSummaryTbody();
      if (!$tbody.length) return;

      if (!datasetId) {
        if (hasDT && $table.length && $.fn.DataTable.isDataTable($table[0])) {
          $table.DataTable().clear().draw();
        } else {
          $tbody.empty();
        }
        return;
      }

      if (hasDT && $table.length) {
        var dt = ensureSummaryDataTable();
        if (dt) {
          dt.clear().draw();
        }
      } else {
        $tbody.html(
          '<tr><td colspan="6" class="text-center">Loading dataset summary...</td></tr>'
        );
      }

      return ajaxJSON('/dataset_summary', { dataset_id: datasetId })
        .then(function(resp){
          var rows = (resp && resp.summary) || [];
          renderSummaryTable(rows);
        })
        .catch(function(){
          if (hasDT && $table.length && $.fn.DataTable.isDataTable($table[0])) {
            $table.DataTable().clear().draw();
          } else {
            $tbody.html(
              '<tr><td colspan="6" class="text-center">Failed to load dataset.</td></tr>'
            );
          }
        });
    }

    /* ===========================
       Plot UI + dataset plot data
       =========================== */

    var DM_PLOT_CACHE = {};

    function getCurrentDatasetId(){
      var $sel = ensureDatasetControl();
      return $sel.length ? ($sel.val() || '') : '';
    }

    function ensurePlotlyLoaded(){
      return new Promise(function(resolve, reject){
        if (window.Plotly) {
          resolve(window.Plotly);
          return;
        }

        var existing = document.getElementById('dm-plotly-loader');
        if (existing) {
          existing.addEventListener('load', function(){ resolve(window.Plotly); });
          existing.addEventListener('error', reject);
          return;
        }

        var s = document.createElement('script');
        s.id = 'dm-plotly-loader';
        s.src = 'https://cdn.plot.ly/plotly-2.35.2.min.js';
        s.onload = function(){ resolve(window.Plotly); };
        s.onerror = function(){ reject(new Error('Could not load Plotly')); };
        document.head.appendChild(s);
      });
    }

    function ensurePlotPanels(){
      if ($('#dm-plots-wrap').length) return;

      var $anchor = $('#summary_table_wrapper');

      if (!$anchor.length) {
        $anchor = $('#summary_table').closest('.dataTables_wrapper');
      }

      if (!$anchor.length) {
        $anchor = $('#summary_table').closest('.table-responsive, .panel, .box, .card, .well, div').first();
      }

      if (!$anchor.length) {
        $anchor = $root.length ? $root : $('body');
      }

      var html = ''
        + '<div id="dm-plots-wrap" style="margin-top:20px;">'
        + '  <div class="panel panel-default">'
        + '    <div class="panel-heading"><strong>Boxplot</strong></div>'
        + '    <div class="panel-body">'
        + '      <div class="row" style="margin-bottom:12px;">'
        + '        <div class="col-sm-4">'
        + '          <label for="dm_box_trait_sel">Trait</label>'
        + '          <select id="dm_box_trait_sel" class="form-control input-sm">'
        + '            <option value="">(select trait)</option>'
        + '          </select>'
        + '        </div>'
        + '        <div class="col-sm-8">'
        + '          <label for="dm_box_highlight_sel">Highlight accession(s)</label>'
        + '          <select id="dm_box_highlight_sel" class="form-control input-sm" multiple size="5"></select>'
        + '        </div>'
        + '      </div>'
        + '      <div id="dm_boxplot" style="width:100%;min-height:500px;"></div>'
        + '    </div>'
        + '  </div>'
        + '  <div class="panel panel-default" style="margin-top:20px;">'
        + '    <div class="panel-heading"><strong>Barplot</strong></div>'
        + '    <div class="panel-body">'
        + '      <div class="row" style="margin-bottom:12px;">'
        + '        <div class="col-sm-4">'
        + '          <label for="dm_bar_trait_sel">Trait</label>'
        + '          <select id="dm_bar_trait_sel" class="form-control input-sm">'
        + '            <option value="">(select trait)</option>'
        + '          </select>'
        + '        </div>'
        + '        <div class="col-sm-8">'
        + '          <label for="dm_bar_highlight_sel">Highlight accession(s)</label>'
        + '          <select id="dm_bar_highlight_sel" class="form-control input-sm" multiple size="5"></select>'
        + '        </div>'
        + '      </div>'
        + '      <div id="dm_barplot" style="width:100%;min-height:500px;"></div>'
        + '    </div>'
        + '  </div>'
        + '</div>';

      $anchor.after(html);
    }

    function clearPlots(){
      ensurePlotPanels();
      $('#dm_boxplot').html('<div class="text-muted">Select a dataset and trait.</div>');
      $('#dm_barplot').html('<div class="text-muted">Select a dataset and trait.</div>');
    }

    function populateSelect($sel, items, placeholder){
      if (!$sel || !$sel.length) return;
      var isMultiple = $sel.prop('multiple');

      $sel.empty();

      if (!isMultiple) {
        $sel.append('<option value="">' + escapeHtml(placeholder || '(select)') + '</option>');
      }

      (items || []).forEach(function(item){
        $sel.append('<option value="' + escapeHtml(item) + '">' + escapeHtml(item) + '</option>');
      });
    }

    function getSelectedMultiValues(sel){
      var v = $(sel).val();
      return Array.isArray(v) ? v : (v ? [v] : []);
    }

    function getPlotCacheKey(datasetId, trait){
      return String(datasetId || '') + '||' + String(trait || '');
    }

    function fetchDatasetPlotData(datasetId, trait){
      var key = getPlotCacheKey(datasetId, trait);

      if (DM_PLOT_CACHE[key]) {
        return Promise.resolve(DM_PLOT_CACHE[key]);
      }

      return ajaxJSON('/dataset_plot_data', {
        dataset_id: datasetId,
        trait: trait
      }).then(function(resp){
        DM_PLOT_CACHE[key] = resp || {};
        return DM_PLOT_CACHE[key];
      });
    }
    function refreshPlotSelectors(datasetId){
      ensurePlotPanels();

      if (!datasetId) {
        populateSelect($('#dm_box_trait_sel'), [], '(select trait)');
        populateSelect($('#dm_bar_trait_sel'), [], '(select trait)');
        populateSelect($('#dm_box_highlight_sel'), []);
        populateSelect($('#dm_bar_highlight_sel'), []);
        clearPlots();
        return Promise.resolve();
      }

      return ajaxJSON('/dataset_traits', { dataset_id: datasetId })
        .then(function(resp){
          var traits = (resp && resp.traits) || [];
          var accessions = (resp && resp.accessions) || [];

          populateSelect($('#dm_box_trait_sel'), traits, '(select trait)');
          populateSelect($('#dm_bar_trait_sel'), traits, '(select trait)');
          populateSelect($('#dm_box_highlight_sel'), accessions);
          populateSelect($('#dm_bar_highlight_sel'), accessions);

          if (traits.length) {
            $('#dm_box_trait_sel').val(traits[0]);
            $('#dm_bar_trait_sel').val(traits[0]);
          }

          return renderAllPlots();
        })
        .catch(function(){
          clearPlots();
        });
    }

    function renderBoxplot(datasetId, trait, highlighted){
      ensurePlotPanels();

      if (!datasetId || !trait) {
        $('#dm_boxplot').html('<div class="text-muted">Select a dataset and trait.</div>');
        return Promise.resolve();
      }

      return ensurePlotlyLoaded()
        .then(function(Plotly){
          return fetchDatasetPlotData(datasetId, trait).then(function(resp){
            var rows = (resp && resp.rows) || [];
            if (!rows.length) {
              $('#dm_boxplot').html('<div class="text-muted">No plot data found.</div>');
              return;
            }

            var grouped = {};
            rows.forEach(function(r){
              var acc = r.accession || '';
              var val = Number(r.value);
              if (!acc || isNaN(val)) return;
              if (!grouped[acc]) grouped[acc] = [];
              grouped[acc].push(val);
            });

            var accessions = Object.keys(grouped).sort();

            var traces = accessions.map(function(acc){
              var isHi = highlighted.indexOf(acc) !== -1;
              return {
                type: 'box',
                name: acc,
                y: grouped[acc],
                boxpoints: 'outliers',
                jitter: 0.25,
                pointpos: 0,
                marker: {
                  size: isHi ? 7 : 5,
                  color: isHi ? '#d9480f' : '#4c78a8'
                },
                line: {
                  width: isHi ? 3 : 1
                },
                fillcolor: isHi ? 'rgba(217,72,15,0.25)' : 'rgba(76,120,168,0.18)'
              };
            });

            var layout = {
              title: trait,
              xaxis: {
                title: 'Accession',
                automargin: true
              },
              yaxis: {
                title: 'Value',
                automargin: true
              },
              showlegend: false,
              margin: { t: 50, r: 20, b: 120, l: 70 }
            };

            return Plotly.newPlot('dm_boxplot', traces, layout, { responsive: true });
          });
        })
        .catch(function(){
          $('#dm_boxplot').html('<div class="text-danger">Failed to render boxplot.</div>');
        });
    }

    function renderBarplot(datasetId, trait, highlighted){
      ensurePlotPanels();

      if (!datasetId || !trait) {
        $('#dm_barplot').html('<div class="text-muted">Select a dataset and trait.</div>');
        return Promise.resolve();
      }

      return ensurePlotlyLoaded()
        .then(function(Plotly){
          return fetchDatasetPlotData(datasetId, trait).then(function(resp){
            var summary = (resp && resp.accession_summary) || [];
            if (!summary.length) {
              $('#dm_barplot').html('<div class="text-muted">No plot data found.</div>');
              return;
            }

            summary = summary.slice().sort(function(a, b){
              return Number(b.mean) - Number(a.mean);
            });

            var x = summary.map(function(r){ return r.accession; });
            var y = summary.map(function(r){ return Number(r.mean); });
            var err = summary.map(function(r){ return Number(r.std); });
            var colors = summary.map(function(r){
              return highlighted.indexOf(r.accession) !== -1 ? '#d9480f' : '#4c78a8';
            });

            var trace = {
              type: 'bar',
              x: x,
              y: y,
              marker: { color: colors },
              error_y: {
                type: 'data',
                array: err,
                visible: true
              },
              customdata: summary.map(function(r){
                return [r.n, r.min, r.max, r.std];
              }),
              hovertemplate:
                '<b>%{x}</b><br>' +
                'Mean: %{y:.3f}<br>' +
                'N: %{customdata[0]}<br>' +
                'Min: %{customdata[1]}<br>' +
                'Max: %{customdata[2]}<br>' +
                'Std: %{customdata[3]}<extra></extra>'
            };

            var layout = {
              title: trait + ' (mean by accession)',
              xaxis: {
                title: 'Accession',
                automargin: true
              },
              yaxis: {
                title: 'Mean value',
                automargin: true
              },
              showlegend: false,
              margin: { t: 50, r: 20, b: 120, l: 70 }
            };

            return Plotly.newPlot('dm_barplot', [trace], layout, { responsive: true });
          });
        })
        .catch(function(){
          $('#dm_barplot').html('<div class="text-danger">Failed to render barplot.</div>');
        });
    }

    function renderAllPlots(){
      var datasetId = getCurrentDatasetId();
      var boxTrait = $('#dm_box_trait_sel').val() || '';
      var barTrait = $('#dm_bar_trait_sel').val() || '';
      var boxHi = getSelectedMultiValues('#dm_box_highlight_sel');
      var barHi = getSelectedMultiValues('#dm_bar_highlight_sel');

      return Promise.all([
        renderBoxplot(datasetId, boxTrait, boxHi),
        renderBarplot(datasetId, barTrait, barHi)
      ]);
    }

    function loadLists(){
      return ajaxJSON('/lists', { type:'accessions' }).then(function(resp){
        var $sel = $('#dm_list_sel');
        if (!$sel.length) return;
        $sel.empty().append('<option value="">(choose a list)</option>');
        ((resp && resp.lists) || []).forEach(function(li){
          $sel.append('<option value="' + (li.list_id || '') + '">' + (li.name || ('List ' + li.list_id)) + '</option>');
        });
      });
    }

    async function loadBreedingPrograms(){
      var endpoints = ['/programs'];
      for (var i = 0; i < endpoints.length; i++) {
        try {
          var j = await ajaxJSON(endpoints[i]);
          if (!j) continue;

          var arr = [];
          if (Array.isArray(j)) { arr = j; }
          else if (Array.isArray(j.programs)) { arr = j.programs; }
          else if (Array.isArray(j.breeding_programs)) { arr = j.breeding_programs; }
          else if (Array.isArray(j.rows)) { arr = j.rows; }

          var norm = arr.map(function(x){
            return x.name || x.program_name || x.label || x.value || String(x || '');
          }).filter(Boolean);

          if (norm.length) {
            var seen = new Set();
            var out = [];
            norm.forEach(function(n){
              if (!seen.has(n)) {
                seen.add(n);
                out.push(n);
              }
            });
            return out;
          }
        } catch (e) {}
      }
      return [];
    }

    function keyFor(acc, bp){ return String(acc || '') + '||' + String(bp || ''); }

    function normDecision(v){
      var x = String(v || '').trim().toLowerCase();
      if (x === 'drop') return 'drop';
      if (x === 'hold') return 'hold';
      if (x === 'advance') return 'advance';
      if (x === 'jump') return 'jump';
      return '';
    }

    function colorClass(val){
      switch (val) {
        case 'drop':    return 'dm-dec-drop';
        case 'hold':    return 'dm-dec-hold';
        case 'advance': return 'dm-dec-advance';
        case 'jump':    return 'dm-dec-jump';
        default:        return 'dm-dec-none';
      }
    }

    function decisionSelectHTML(current, acc, bp){
      var cur = normDecision(current);
      return '' +
        '<select class="dm-decision-select form-control input-sm ' + colorClass(cur) + '" ' +
                'data-acc="' + String(acc || '').replace(/"/g, '&quot;') + '" ' +
                'data-bp="' + String(bp || '').replace(/"/g, '&quot;') + '">' +
          '<option value="">(select)</option>' +
          '<option value="drop"' +    (cur === 'drop'    ? ' selected' : '') + '>Drop</option>' +
          '<option value="hold"' +    (cur === 'hold'    ? ' selected' : '') + '>Hold</option>' +
          '<option value="advance"' + (cur === 'advance' ? ' selected' : '') + '>Advance</option>' +
          '<option value="jump"' +    (cur === 'jump'    ? ' selected' : '') + '>Jump</option>' +
        '</select>';
    }

    function applyDecisionColor(sel){
      var v = normDecision(sel.value);
      sel.classList.remove('dm-dec-none', 'dm-dec-drop', 'dm-dec-hold', 'dm-dec-advance', 'dm-dec-jump');
      sel.classList.add(colorClass(v));
    }

    function getSelectedMeetingContext(){
      if (typeof window.getSelectedDecisionMeeting === 'function') {
        return window.getSelectedDecisionMeeting();
      }
      var $checked = $('.dm-meeting-check:checked').first();
      if (!$checked.length) return null;
      return {
        meeting_id: $checked.data('meeting-id'),
        meeting_name: $checked.data('meeting-name'),
        meeting_date: $checked.data('meeting-date')
      };
    }

    function normalizeStageList(raw){
      var flat = [];

      function pushValue(v){
        if (v == null) return;

        if (Array.isArray(v)) {
          v.forEach(pushValue);
          return;
        }

        if (typeof v === 'object') {
          pushValue(v.name || v.stage || v.value || v.label || '');
          return;
        }

        var s = String(v).trim();
        if (!s) return;

        if (s.indexOf(',') !== -1) {
          s.split(',').forEach(function(part){
            var item = String(part || '').trim();
            if (item) flat.push(item);
          });
          return;
        }

        flat.push(s);
      }

      pushValue(raw);

      var seen = new Set();
      return flat.filter(function(x){
        if (!x || seen.has(x)) return false;
        seen.add(x);
        return true;
      });
    }

    async function getAvailableStages() {
      var out = [];

      try {
        var resp = await ajaxJSON('/stages');
        var raw = [];

        if (resp && typeof resp === 'object' && 'stages' in resp) {
          raw = resp.stages;
        } else {
          raw = resp;
        }

        out = normalizeStageList(raw);
      } catch (e) {}

      return out;
    }

    function ensureStageDialog(){
      if (document.getElementById('dm_stage_dialog')) return;

      var html = ''
        + '<dialog id="dm_stage_dialog" class="dm-stage-dialog">'
        + '  <form method="dialog" style="min-width:320px;max-width:420px;padding:18px 18px 12px 18px;">'
        + '    <div style="font-size:18px;font-weight:600;margin-bottom:6px;">Select target stage</div>'
        + '    <div id="dm_stage_dialog_subtitle" style="font-size:12px;color:#666;margin-bottom:12px;"></div>'
        + '    <div id="dm_stage_dialog_options" style="max-height:280px;overflow:auto;border:1px solid #ddd;border-radius:6px;padding:10px;"></div>'
        + '    <div style="display:flex;justify-content:flex-end;gap:8px;margin-top:14px;">'
        + '      <button type="button" id="dm_stage_cancel" class="btn btn-default">Cancel</button>'
        + '      <button type="button" id="dm_stage_ok" class="btn btn-primary">OK</button>'
        + '    </div>'
        + '  </form>'
        + '</dialog>';

      $('body').append(html);

      $(document).off('click.dmStageCancel', '#dm_stage_cancel').on('click.dmStageCancel', '#dm_stage_cancel', function(){
        var dlg = document.getElementById('dm_stage_dialog');
        if (dlg) dlg.close('');
      });
    }

    function openStageDialog(opts){
      ensureStageDialog();

      opts = opts || {};
      var accession = opts.accession || '';
      var currentStage = opts.currentStage || '';
      var meetingDate = opts.meetingDate || '';
      var stages = Array.isArray(opts.stages) ? opts.stages : [];
      var selectedStage = opts.selectedStage || '';

      return new Promise(function(resolve){
        var dlg = document.getElementById('dm_stage_dialog');
        var $subtitle = $('#dm_stage_dialog_subtitle');
        var $options = $('#dm_stage_dialog_options');

        $subtitle.text(
          'Accession: ' + accession +
          (meetingDate ? ' | Meeting date: ' + meetingDate : '') +
          (currentStage ? ' | Current stage: ' + currentStage : '')
        );

        $options.empty();

        stages.forEach(function(stg, idx){
          var id = 'dm_stage_opt_' + idx;
          var checked = (selectedStage && stg === selectedStage) ? ' checked' : '';
          var row = ''
            + '<div style="margin-bottom:6px;">'
            + '  <label for="' + id + '" style="display:flex;align-items:center;gap:8px;font-weight:400;cursor:pointer;">'
            + '    <input type="radio" name="dm_stage_choice" id="' + id + '" value="' + escapeHtml(stg) + '"' + checked + '>'
            + '    <span>' + escapeHtml(stg) + '</span>'
            + '  </label>'
            + '</div>';
          $options.append(row);
        });

        if (!$options.find('input[name="dm_stage_choice"]:checked').length) {
          $options.find('input[name="dm_stage_choice"]').first().prop('checked', true);
        }

        $(document).off('click.dmStageOk', '#dm_stage_ok').on('click.dmStageOk', '#dm_stage_ok', function(){
          var val = $options.find('input[name="dm_stage_choice"]:checked').val() || '';
          dlg.close(val);
        });

        dlg.addEventListener('close', function onClose(){
          dlg.removeEventListener('close', onClose);
          resolve(dlg.returnValue || '');
        });

        dlg.showModal();
      });
    }

    var decisionDT = (function(){
      var $tbl = $('#decision_table');
      if (!hasDT || !$tbl.length) return null;

      var dt = $.fn.DataTable.isDataTable($tbl[0]) ? $tbl.DataTable() : $tbl.DataTable({
        dom:'ftip',
        pageLength:20,
        lengthChange:false,
        order:[],
        orderCellsTop:true,
        fixedHeader:true,
        autoWidth:false,
        scrollX:true,
        scrollCollapse:true,
        deferRender:true,
        drawCallback: function () {
          var api = this.api();
          setTimeout(function () {
            try { api.columns.adjust(); } catch (e) {}
            try {
              if (api.fixedHeader) {
                api.fixedHeader.adjust();
              }
            } catch (e) {}
            adjustVisibleDataTables();
          }, 0);
        },
        initComplete: function () {
          setTimeout(function () {
            adjustVisibleDataTables();
          }, 0);
        }
      });

      setTimeout(function () {
        adjustVisibleDataTables();
      }, 0);

      return dt;
    })();

    function clearDecisionRows(){
      if (!decisionDT) return;
      decisionDT.clear().draw();
    }

    function rowsToDataArrays(rows){
      return (rows || []).map(function(r){
        var acc      = r.accession || '';
        var bp       = r.breeding_program || '';
        var stage    = r.stage || '';
        var year     = r.year || '';
        var dec      = r.decision || '';
        var newStage = r.new_stage || '';
        var fem      = r.female_parent || '';
        var male     = r.male_parent || '';
        var notes    = r.notes || '';
        var decSel   = decisionSelectHTML(dec, acc, bp);

        return [acc, bp, stage, year, decSel, newStage, fem, male, notes];
      });
    }

    function normalizeRows(rawRows){
      return (rawRows || []).map(function(r){
        return {
          stock_id:         (r.stock_id || ''),
          accession:        (r.accession || ''),
          breeding_program: (r.breeding_program || ''),
          stage:            (r.stage || ''),
          year:             (r.year || ''),
          decision:         normDecision(r.decision),
          new_stage:        (r.new_stage || ''),
          female_parent:    (r.female_parent || ''),
          male_parent:      (r.male_parent || ''),
          notes:            (r.notes || '')
        };
      });
    }

    function renderRows(rows){
      if (!decisionDT) return;
      clearDecisionRows();
      var data = rowsToDataArrays(rows);
      if (data.length) decisionDT.rows.add(data).draw(false);
      if (STATE.currentBpFilter) {
        decisionDT.column(1).search('^' + escapeRegExp(STATE.currentBpFilter) + '$', true, false).draw();
      }
      setTimeout(function(){ adjustVisibleDataTables(); ensureSaveAllUI(); }, 0);
    }

    function uniq(arr){
      var s = new Set();
      var out = [];
      (arr || []).forEach(function(x){
        var v = (x == null ? '' : String(x));
        if (!s.has(v)) {
          s.add(v);
          out.push(v);
        }
      });
      return out;
    }

    function escapeHtml(s){
      return String(s || '').replace(/[&<>"']/g, function(c){
        return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c] || c;
      });
    }

    function escapeRegExp(s){
      return String(s || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }

    function buildCrossProductRows(){
      STATE.rows = (STATE.baseRows || []).slice();
      renderRows(STATE.rows);
    }

    function ensureBpHeaderFilter(){
      var $tbl = $('#decision_table');
      if (!$tbl.length) return;
      var $th = $tbl.find('thead th').eq(1);
      if (!$th.length) return;
      if ($th.find('#dm_bp_header_filter').length) return;

      var labelText = ($th.text() || 'Breeding Program').trim().split('\n')[0] || 'Breeding Program';
      $th.html(
        '<div style="display:flex;flex-direction:column;">' +
          '<div>' + escapeHtml(labelText) + '</div>' +
          '<select id="dm_bp_header_filter" class="form-control input-sm dm-bp-header-select">' +
             '<option value="">(All programs)</option>' +
          '</select>' +
        '</div>'
      );

      if (decisionDT) {
        try { decisionDT.columns.adjust(); } catch (e) {}
      }

      populateBpHeaderFilterOptions(STATE.programs);
      setTimeout(adjustVisibleDataTables, 0);

      $(document).off('change.dm','#dm_bp_header_filter').on('change.dm','#dm_bp_header_filter', function(){
        var v = this.value || '';
        STATE.currentBpFilter = v;
        if (!decisionDT) return;
        if (v === '') {
          decisionDT.column(1).search('').draw();
        } else {
          decisionDT.column(1).search('^' + escapeRegExp(v) + '$', true, false).draw();
        }
        setTimeout(adjustVisibleDataTables, 0);
      });
    }

    function populateBpHeaderFilterOptions(programs){
      var $sel = $('#dm_bp_header_filter');
      if (!$sel.length) return;

      var cur = $sel.val() || STATE.currentBpFilter || '';
      $sel.find('option:not([value=""])').remove();

      var seen = new Set();
      (programs || []).forEach(function(p){
        if (!p) return;
        if (seen.has(p)) return;
        seen.add(p);
        $sel.append('<option value="' + escapeHtml(p) + '">' + escapeHtml(p) + '</option>');
      });

      if (cur && seen.has(cur)) {
        $sel.val(cur);
      } else {
        $sel.val('');
        STATE.currentBpFilter = '';
      }
    }
    async function loadDecisionsForList(list_id){
      STATE.list_id = list_id || '';
      STATE.rows = [];
      STATE.baseRows = [];
      STATE.accessions = [];
      STATE.decisionsMap.clear();

      var meetingCtx = getSelectedMeetingContext();
      var meetingId = meetingCtx && meetingCtx.meeting_id ? meetingCtx.meeting_id : '';

      var loaded = false;
      try {
        var params = { list_id: list_id };
        if (meetingId) params.meeting_id = meetingId;

        var getRes = await ajaxJSON('/decisions', params);

        if (getRes && Array.isArray(getRes.rows)) {
          STATE.baseRows = normalizeRows(getRes.rows);
          loaded = true;
        }
      } catch (e) {}

      if (!loaded) {
        try {
          var acc = await ajaxJSON('/accessions', { list_id: list_id });
          var names = ((acc && acc.accessions) || []).map(function(a){ return (a && a.name) || ''; }).filter(Boolean);

          STATE.baseRows = names.map(function(nm){
            return {
              accession:nm,
              breeding_program:'',
              stage:'',
              year:'',
              decision:'',
              new_stage:'',
              female_parent:'',
              male_parent:'',
              notes:''
            };
          });
          loaded = true;
        } catch (e) {}
      }

      STATE.accessions = uniq(
        STATE.baseRows.map(function(r){ return r.accession || ''; }).filter(Boolean)
      );

      STATE.programs = uniq(
        STATE.baseRows.map(function(r){ return r.breeding_program || ''; }).filter(Boolean)
      );

      STATE.baseRows.forEach(function(r){
        var k = keyFor(r.accession, r.breeding_program);
        STATE.decisionsMap.set(k, normDecision(r.decision));
      });

      populateBpHeaderFilterOptions(STATE.programs);
      buildCrossProductRows();
      setTimeout(adjustVisibleDataTables, 0);
    }

    function getSelectedMeetingNotes(){
      var $checked = $('.dm-meeting-check:checked').first();
      if (!$checked.length) return '';
      var meetingId = $checked.data('meeting-id');
      if (!meetingId) return '';
      var cached = window.DM_MEETING_CACHE && window.DM_MEETING_CACHE[String(meetingId)];
      return $.trim((cached && cached.notes) || '');
    }

    function getDecisionRowsForSave(){
      return (STATE.rows || []).filter(function(r){
        return r && r.accession && (r.decision || r.new_stage || r.notes);
      }).map(function(r){
        return {
          stock_id: r.stock_id || '',
          accession: r.accession || '',
          breeding_program: r.breeding_program || '',
          previous_stage: r.stage || '',
          decision: normDecision(r.decision),
          new_stage: r.new_stage || '',
          notes: r.notes || ''
        };
      });
    }

    function renderSaveReport(payload){
      ensureSaveAllUI();

      $('#dm-save-meeting-name').text(payload.meeting_name || '');
      $('#dm-save-meeting-date').text(payload.date || '');
      $('#dm-save-meeting-attendees').text(payload.attendees || '');
      $('#dm-save-meeting-notes').val(payload.meeting_notes || '');

      var $tbody = $('#dm-save-report-table tbody');
      $tbody.empty();

      if (!payload.accessions.length) {
        $tbody.append(
          '<tr><td colspan="7" class="text-center dm-save-empty">No accession decisions available to save.</td></tr>'
        );
        return;
      }

      payload.accessions.forEach(function(row, idx){
        $tbody.append(
          '<tr data-idx="' + idx + '">' +
            '<td>' + escapeHtml(row.accession || '') + '</td>' +
            '<td>' + escapeHtml(row.breeding_program || '') + '</td>' +
            '<td>' + escapeHtml(row.previous_stage || '') + '</td>' +
            '<td>' + escapeHtml(row.decision || '') + '</td>' +
            '<td>' + escapeHtml(row.new_stage || '') + '</td>' +
            '<td>' + escapeHtml(row.notes || '') + '</td>' +
            '<td><textarea class="form-control dm-save-comment" data-idx="' + idx + '" placeholder="Add a comment for this accession...">' + escapeHtml(row.save_comment || '') + '</textarea></td>' +
          '</tr>'
        );
      });
    }

    function buildSavePayloadFromState(){
      var meetingCtx = getSelectedMeetingContext();
      if (!meetingCtx) {
        alert('Please select one meeting first.');
        return null;
      }

      if (!STATE.list_id) {
        alert('Please select one accession list first.');
        return null;
      }

      var accessions = getDecisionRowsForSave();
      if (!accessions.length) {
        alert('There are no accession decisions to save.');
        return null;
      }

      return {
        meeting_id: meetingCtx.meeting_id || '',
        meeting_name: meetingCtx.meeting_name || '',
        date: meetingCtx.meeting_date || '',
        attendees: getSelectedMeetingAttendees(),
        meeting_notes: getSelectedMeetingNotes(),
        list_id: STATE.list_id || '',
        accessions: accessions
      };
    }

    function openSaveReportDialog(payload){
      ensureSaveAllUI();
      renderSaveReport(payload);

      return new Promise(function(resolve){
        var dlg = document.getElementById('dm_save_dialog');

        function onClose(){
          dlg.removeEventListener('close', onClose);
          resolve(dlg.returnValue || '');
        }

        dlg.addEventListener('close', onClose);
        dlg.showModal();
      });
    }

    async function saveAllDecisionsToController(payload){
      var $btn = $('#dm_confirm_save_all_btn');
      var originalText = $btn.text();
      $btn.prop('disabled', true).text('Saving...');

      try {
        payload.meeting_notes = $.trim($('#dm-save-meeting-notes').val() || '');

        $('#dm-save-report-table .dm-save-comment').each(function(){
          var idx = Number($(this).attr('data-idx'));
          if (!isNaN(idx) && payload.accessions[idx]) {
            payload.accessions[idx].save_comment = $.trim($(this).val() || '');
          }
        });

        var resp = await fetch((window.DM_API_BASE || '/ajax/decisionmeeting') + '/save_all_decisions', {
          method: 'POST',
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(payload)
        });

        var ct = resp.headers.get('content-type') || '';
        var data = ct.indexOf('application/json') !== -1
          ? await resp.json()
          : { message: await resp.text().catch(function(){ return ''; }) };

        if (!resp.ok) {
          throw new Error((data && (data.message || data.error || data.detail)) || ('HTTP ' + resp.status));
        }

        var dlg = document.getElementById('dm_save_dialog');
        if (dlg) dlg.close('saved');

        alert((data && (data.message || data.detail)) || 'All decisions were saved successfully.');
      } catch (e) {
        alert('Failed to save all decisions: ' + (e && e.message ? e.message : e));
      } finally {
        $btn.prop('disabled', false).text(originalText);
      }
    }

    function bindUI(){
      $(document).off('change.dm','#dm_list_sel').on('change.dm','#dm_list_sel', async function(){
        var id = $(this).val() || '';

        if (id && !getSelectedMeetingContext()) {
          alert('Please select one meeting first.');
          $(this).val('');
          STATE.list_id = '';
          STATE.rows = [];
          STATE.baseRows = [];
          STATE.accessions = [];
          STATE.decisionsMap.clear();
          clearDecisionRows();
          setTimeout(adjustVisibleDataTables, 0);
          return;
        }

        if (id) {
          await loadDecisionsForList(id);
        } else {
          STATE.list_id = '';
          STATE.rows = [];
          STATE.baseRows = [];
          STATE.accessions = [];
          STATE.decisionsMap.clear();
          clearDecisionRows();
          setTimeout(adjustVisibleDataTables, 0);
        }
      });

      $(document).off('click.dm','#dm_clear_filters').on('click.dm','#dm_clear_filters', function(){
        $('#dm_list_sel').val('');
        var $bp = $('#dm_bp_header_filter');
        if ($bp.length) $bp.val('');
        STATE.currentBpFilter = '';
        if (decisionDT) {
          decisionDT.search('').columns().search('').draw();
        }
        STATE.list_id = '';
        STATE.rows = [];
        STATE.baseRows = [];
        STATE.accessions = [];
        STATE.decisionsMap.clear();
        clearDecisionRows();
        setTimeout(adjustVisibleDataTables, 0);
      });

      $(document).off('click.dmSaveAll', '#dm_save_all_btn').on('click.dmSaveAll', '#dm_save_all_btn', async function(){
        var payload = buildSavePayloadFromState();
        if (!payload) return;
        await openSaveReportDialog(payload);
      });

      $(document).off('click.dmConfirmSaveAll', '#dm_confirm_save_all_btn').on('click.dmConfirmSaveAll', '#dm_confirm_save_all_btn', async function(){
        var payload = buildSavePayloadFromState();
        if (!payload) return;
        await saveAllDecisionsToController(payload);
      });

      $(document)
        .off('change.dmDataset', '#dm_dataset_sel, #dataset_id, #dataset, select[name="dataset_id"], #dataset_select select')
        .on('change.dmDataset', '#dm_dataset_sel, #dataset_id, #dataset, select[name="dataset_id"], #dataset_select select', function(){
          var datasetId = $(this).val() || '';
          loadDatasetSummary(datasetId);
          refreshPlotSelectors(datasetId);
        });

      $(document)
        .off('change.dmBoxTrait', '#dm_box_trait_sel')
        .on('change.dmBoxTrait', '#dm_box_trait_sel', function(){
          renderAllPlots();
        });

      $(document)
        .off('change.dmBarTrait', '#dm_bar_trait_sel')
        .on('change.dmBarTrait', '#dm_bar_trait_sel', function(){
          renderAllPlots();
        });

      $(document)
        .off('change.dmBoxHi', '#dm_box_highlight_sel')
        .on('change.dmBoxHi', '#dm_box_highlight_sel', function(){
          renderAllPlots();
        });

      $(document)
        .off('change.dmBarHi', '#dm_bar_highlight_sel')
        .on('change.dmBarHi', '#dm_bar_highlight_sel', function(){
          renderAllPlots();
        });

      $(document).off('change.dm','.dm-decision-select').on('change.dm','.dm-decision-select', async function(){
        applyDecisionColor(this);

        var acc = this.getAttribute('data-acc') || '';
        var bp  = this.getAttribute('data-bp') || '';
        var v   = normDecision(this.value);
        var $tr = $(this).closest('tr');
        var meetingCtx = getSelectedMeetingContext();
        var meetingDate = (meetingCtx && meetingCtx.meeting_date) || '';

        var rowObj = null;
        for (var i = 0; i < STATE.rows.length; i++) {
          if (STATE.rows[i].accession === acc && STATE.rows[i].breeding_program === bp) {
            rowObj = STATE.rows[i];
            break;
          }
        }

        var stageText = rowObj ? (rowObj.stage || '') : '';
        var previousNewStage = rowObj ? (rowObj.new_stage || '') : '';
        var stockId = rowObj ? (rowObj.stock_id || '') : '';

        var meetingYearFull = '';
        if (meetingDate) {
          var m = String(meetingDate).match(/^(\d{4})-/);
          if (m) {
            meetingYearFull = m[1];
          } else {
            var d = new Date(meetingDate);
            if (!isNaN(d.getTime())) {
              meetingYearFull = String(d.getFullYear());
            }
          }
        }

        STATE.decisionsMap.set(keyFor(acc, bp), v);

        function updateNewStageValue(newStageValue, decisionValue){
          if (decisionDT) {
            var rowData = decisionDT.row($tr).data();
            if (rowData) {
              rowData[4] = decisionSelectHTML(decisionValue, acc, bp);
              rowData[5] = newStageValue || '';
              decisionDT.row($tr).data(rowData).invalidate().draw(false);
            }
          }

          for (var a = 0; a < STATE.rows.length; a++) {
            if (STATE.rows[a].accession === acc && STATE.rows[a].breeding_program === bp) {
              STATE.rows[a].decision = decisionValue;
              STATE.rows[a].new_stage = newStageValue || '';
              break;
            }
          }

          for (var b = 0; b < STATE.baseRows.length; b++) {
            if (STATE.baseRows[b].accession === acc && STATE.baseRows[b].breeding_program === bp) {
              STATE.baseRows[b].decision = decisionValue;
              STATE.baseRows[b].new_stage = newStageValue || '';
              break;
            }
          }
        }

        if (!v) {
          updateNewStageValue('', '');
          return;
        }

        if (!meetingDate || !meetingYearFull) {
          alert('Please select one meeting first so the year can be taken from the meeting date.');
          this.value = '';
          applyDecisionColor(this);
          STATE.decisionsMap.set(keyFor(acc, bp), '');
          updateNewStageValue(previousNewStage, '');
          return;
        }

        var selectedStage = '';
        if (v === 'advance' || v === 'jump') {
          $.ajax({
            url: (window.DM_API_BASE || '/ajax/decisionmeeting') + '/compute_new_stage',
            method: 'POST',
            dataType: 'json',
            data: {
              current_stage: stageText,
              decision: v,
              year: meetingYearFull,
              meeting_date: meetingDate,
              stock_id: stockId,
              selected_stage: ''
            },
            success: async function(resp){
              var allowedStages = Array.isArray(resp && resp.allowed_stages) ? resp.allowed_stages : [];

              if (!allowedStages.length) {
                alert((resp && resp.warning) || 'No valid target stages available for this accession.');
                updateNewStageValue('', v);
                return;
              }

              var chosenStage = await openStageDialog({
                accession: acc,
                currentStage: stageText,
                meetingDate: meetingDate,
                stages: allowedStages,
                selectedStage: (resp && resp.selected_stage) || ''
              });

              if (!chosenStage) {
                $('.dm-decision-select[data-acc="' + acc.replace(/"/g, '&quot;') + '"][data-bp="' + bp.replace(/"/g, '&quot;') + '"]').val('');
                STATE.decisionsMap.set(keyFor(acc, bp), '');
                updateNewStageValue(previousNewStage, '');
                return;
              }

              $.ajax({
                url: (window.DM_API_BASE || '/ajax/decisionmeeting') + '/compute_new_stage',
                method: 'POST',
                dataType: 'json',
                data: {
                  current_stage: stageText,
                  decision: v,
                  year: meetingYearFull,
                  meeting_date: meetingDate,
                  stock_id: stockId,
                  selected_stage: chosenStage
                },
                success: function(resp2){
                  var newStage = (resp2 && resp2.new_stage) || '';
                  updateNewStageValue(newStage, v);
                },
                error: function(){
                  updateNewStageValue('', v);
                }
              });
            },
            error: function(){
              updateNewStageValue('', v);
            }
          });
          return;
        }

        $.ajax({
          url: (window.DM_API_BASE || '/ajax/decisionmeeting') + '/compute_new_stage',
          method: 'POST',
          dataType: 'json',
          data: {
            current_stage: stageText,
            decision: v,
            year: meetingYearFull,
            meeting_date: meetingDate,
            stock_id: stockId,
            selected_stage: selectedStage
          },
          success: function(resp){
            var newStage = (resp && resp.new_stage) || '';
            updateNewStageValue(newStage, v);
          },
          error: function(){
            updateNewStageValue('', v);
          }
        });
      });
    }
    bindUI();

    (async function boot(){
      var base = await detectApiBase();
      if (!base) {
        return;
      }

      window.DM_API_BASE = base;

      await loadLists();
      await loadDatasets();
      ensureSaveAllUI();
      STATE.programs = await loadBreedingPrograms();

      var $datasetSel = ensureDatasetControl();
      if ($datasetSel.length && $datasetSel.val()) {
        loadDatasetSummary($datasetSel.val());
      }

      ensureBpHeaderFilter();
      populateBpHeaderFilterOptions(STATE.programs);
      setTimeout(adjustVisibleDataTables, 0);
    })();

    window.addDecisionRow = function(row){
      var r = normalizeRows([row || {}])[0];
      STATE.decisionsMap.set(keyFor(r.accession, r.breeding_program), normDecision(r.decision));
      if (STATE.accessions.indexOf(r.accession) === -1) STATE.accessions.push(r.accession);
      if (STATE.programs.indexOf(r.breeding_program) === -1 && r.breeding_program) {
        STATE.programs.push(r.breeding_program);
        populateBpHeaderFilterOptions(STATE.programs);
      }

      var replaced = false;
      for (var i = 0; i < STATE.baseRows.length; i++) {
        var br = STATE.baseRows[i];
        if (br.accession === r.accession && br.breeding_program === r.breeding_program) {
          STATE.baseRows[i] = r;
          replaced = true;
          break;
        }
      }

      if (!replaced) STATE.baseRows.push(r);
      buildCrossProductRows();
      setTimeout(adjustVisibleDataTables, 0);
    };

  });
})(jQuery);

(function($){
  'use strict';
  if (window.__DM_CREATE_WIRED__) {
    return;
  }
  window.__DM_CREATE_WIRED__ = true;

  const NS = '.dmCreateV4';
  const API_BASE = (window.DM_API_BASE
    || $('#decision_meeting_main').data('dmApiBase')
    || '/ajax/decisionmeeting');

  function parseAttendees(text){
    return (text || '').split(/\n|,/g).map(function(s){ return s.trim(); }).filter(Boolean);
  }

  function showErr(msg){
    $('#create-meeting-error').text(msg || 'Unexpected error').show();
  }

  function hideErr(){
    $('#create-meeting-error').hide().text('');
  }

  function ensureMultiProgramControl() {
    const $sel = $('#mtg_program');
    if (!$sel.length) return;
    if ($.fn.select2 && $sel.data('select2')) {
      try { $sel.select2('destroy'); } catch(e) {}
    }
    if ($.fn.selectpicker && $sel.data('selectpicker')) {
      try { $sel.selectpicker('destroy'); } catch(e) {}
    }
    $sel.attr('multiple', 'multiple');
    $sel.prop('multiple', true);
    if (!$sel.attr('size')) $sel.attr('size', 6);
    if (!$sel.attr('name') || $sel.attr('name') === 'mtg_program') {
      $sel.attr('name', 'mtg_program[]');
    }
  }

  function upgradeMultiProgramUI(items) {
    const $sel = $('#mtg_program');
    if (!$sel.length) return;
    if ($.fn.select2) {
      try {
        if ($sel.data('select2')) $sel.select2('destroy');
        $sel.select2({
          width: '100%',
          placeholder: 'Select breeding program(s)',
          closeOnSelect: false
        });
        return;
      } catch(e) {}
    }
    if ($.fn.selectpicker) {
      try {
        if ($sel.data('selectpicker')) $sel.selectpicker('destroy');
        $sel.selectpicker({
          actionsBox: true,
          liveSearch: true,
          noneSelectedText: 'Select breeding program(s)'
        });
        $sel.selectpicker('refresh');
        return;
      } catch(e) {}
    }
    const n = Math.min(10, Math.max(5, (items && items.length) ? items.length : parseInt($sel.attr('size') || 6, 10)));
    $sel.attr('size', n);
  }

  function buildPayload(){
    const progVals = $('#mtg_program').val();
    const programs = Array.isArray(progVals)
      ? progVals.filter(Boolean)
      : (progVals ? [progVals] : []);

    return {
      meeting_name:       $.trim($('#mtg_name').val() || ''),
      breeding_program:   programs.join(','),
      breeding_programs:  programs,
      location:           $.trim($('#mtg_location').val() || ''),
      year:               String($('#mtg_year').val() || ''),
      date:               $('#mtg_date').val() || '',
      data:               $.trim($('#mtg_data').val() || ''),
      attendees:          parseAttendees($('#mtg_attendees').val()).join(',')
    };
  }

  function validate(p){
    if (!p.meeting_name) return 'Please enter the Meeting name.';
    if (!p.location) return 'Please enter the Location.';
    if (!p.year || isNaN(Number(p.year))) return 'Please enter a valid Year.';
    if (!p.date) return 'Please choose a Date.';
    if (!p.breeding_programs || p.breeding_programs.length === 0) return 'Please select at least one Breeding Program.';
    return '';
  }

  function dm_loadLocations() {
    const $sel = $('#mtg_location');
    if (!$sel.length) return;
    if (!API_BASE) return;
    $sel.find('option:not([value=""])').remove();
    $.ajax({ url: API_BASE + '/locations', dataType: 'json' })
      .done(function(items){
        if (!items || !items.length) {
          return;
        }
        (items || []).forEach(function(l){
          const id = l.location_id ?? '';
          const nm = l.name ?? String(id);
          if (id !== '') $sel.append('<option value="' + id + '">' + nm + '</option>');
        });
      })
      .fail(function(){});
  }

  const PEOPLE_PAGE_SIZE = 10;
  let PEOPLE_ALL = [];
  let PEOPLE_FILTERED = [];
  let PEOPLE_PAGE = 1;
  let PEOPLE_SELECTED = new Set();

  function normPerson(p){
    return {
      first_name:    (p.first_name ?? p.first ?? p.given_name ?? '').trim(),
      last_name:     (p.last_name  ?? p.last  ?? p.family_name ?? '').trim(),
      contact_email: (p.contact_email ?? p.email ?? '').trim()
    };
  }

  function personKey(p){
    return [
      (p.first_name || '').toLowerCase(),
      (p.last_name || '').toLowerCase(),
      (p.contact_email || '').toLowerCase()
    ].join('|');
  }

  function dm_syncSelectAllState(){
    const $rows = $('#people_table tbody tr');
    if (!$rows.length) {
      $('#people_select_all').prop('checked', false);
      return;
    }
    const $checks = $rows.find('input.person-check, input.attendee-check');
    const allChecked = $checks.length > 0 && $checks.filter(':checked').length === $checks.length;
    $('#people_select_all').prop('checked', allChecked);
  }

  function buildPager(total, page, pageSize){
    const totalPages = Math.max(1, Math.ceil(total / pageSize));
    const cur = Math.min(Math.max(1, page), totalPages);
    let html = '<nav id="people_pager" aria-label="Attendees pagination"><ul class="pagination pagination-sm" style="margin:6px 0;">';
    html += `<li class="page-item${cur===1?' disabled':''}"><a class="page-link" href="#" data-page="${cur-1}" aria-label="Previous">&laquo;</a></li>`;
    const span = 2;
    const start = Math.max(1, cur - span);
    const end = Math.min(totalPages, cur + span);
    for (let i = start; i <= end; i++) {
      html += `<li class="page-item${i===cur?' active':''}"><a class="page-link" href="#" data-page="${i}">${i}</a></li>`;
    }
    html += `<li class="page-item${cur===totalPages?' disabled':''}"><a class="page-link" href="#" data-page="${cur+1}" aria-label="Next">&raquo;</a></li>`;
    html += '</ul></nav>';
    return html;
  }

  function renderPeople(){
    const $tbody = $('#people_table tbody');
    if (!$tbody.length) return;

    const total = PEOPLE_FILTERED.length;
    const totalPages = Math.max(1, Math.ceil(total / PEOPLE_PAGE_SIZE));
    if (PEOPLE_PAGE < 1) PEOPLE_PAGE = 1;
    if (PEOPLE_PAGE > totalPages) PEOPLE_PAGE = totalPages;

    if (!total) {
      $tbody.html('<tr><td colspan="4">No people found.</td></tr>');
      $('#people_pager').remove();
      dm_syncSelectAllState();
      return;
    }

    const start = (PEOPLE_PAGE - 1) * PEOPLE_PAGE_SIZE;
    const slice = PEOPLE_FILTERED.slice(start, start + PEOPLE_PAGE_SIZE);
    const rows = slice.map(function(p, i){
      const idx = start + i;
      const id  = `person_${idx}`;
      const key = personKey(p);
      const em  = p.contact_email || '';
      const checked = PEOPLE_SELECTED.has(key) ? ' checked' : '';
      return (
        '<tr>'
          + '<td class="text-center">'
            + `<input type="checkbox" class="person-check attendee-check" id="${id}"`
              + ` data-key="${key}" data-email="${em}" data-first="${p.first_name || ''}" data-last="${p.last_name || ''}"${checked}>`
          + '</td>'
          + `<td><label for="${id}" class="sr-only">Select ${p.first_name || 'person'}</label>${p.first_name || ''}</td>`
          + `<td>${p.last_name || ''}</td>`
          + `<td>${em}</td>`
        + '</tr>'
      );
    }).join('');

    $tbody.html(rows);
    const pagerHtml = buildPager(total, PEOPLE_PAGE, PEOPLE_PAGE_SIZE);
    if ($('#people_pager').length) {
      $('#people_pager').replaceWith(pagerHtml);
    } else {
      $('#people_table').closest('.table-responsive').after(pagerHtml);
    }
    dm_syncSelectAllState();
  }

  function applyPeopleSearch(){
    const q = ($.trim($('#people_search').val() || '')).toLowerCase();
    if (!q) {
      PEOPLE_FILTERED = PEOPLE_ALL.slice();
    } else {
      PEOPLE_FILTERED = PEOPLE_ALL.filter(function(p){
        return (p.first_name || '').toLowerCase().includes(q)
            || (p.last_name || '').toLowerCase().includes(q)
            || (p.contact_email || '').toLowerCase().includes(q);
      });
    }
    PEOPLE_PAGE = 1;
    renderPeople();
  }

  function dm_loadPeople() {
    const $tbody = $('#people_table tbody');
    if (!$tbody.length) return;
    if (typeof API_BASE === 'undefined' || !API_BASE) return;

    const term = $.trim($('#people_search').val() || '');
    $tbody.html('<tr><td colspan="4">Loading…</td></tr>');

    $.ajax({
      url: API_BASE + '/people',
      dataType: 'json',
      data: term ? { q: term } : undefined
    })
    .done(function(res){
      const items = Array.isArray(res) ? res : (res && res.data) || [];
      PEOPLE_ALL = items.map(normPerson);
      applyPeopleSearch();
    })
    .fail(function(){
      $tbody.html('<tr><td colspan="4">Failed to load.</td></tr>');
    });
  }

  function dm_enableRowSelection(tableSelectors) {
    (tableSelectors || ['#people_table', '#meeting_table', '#decision_table']).forEach(function(sel){
      const $t = $(sel);
      if (!$t.length) return;
      $t.off('click.dmPickRow').on('click.dmPickRow', 'tbody tr', function ev(e){
        if ($(e.target).is('input,button,a,select,label,textarea')) return;
        const $row = $(this);
        const nowSelected = !$row.hasClass('selected');
        $row.toggleClass('selected', nowSelected);
        let $chk = $row.find('input.attendee-check[type=checkbox]').first();
        if (!$chk.length) $chk = $row.find('input.person-check[type=checkbox]').first();
        if ($chk.length) $chk.prop('checked', nowSelected).trigger('change');
      });
    });
  }

  $(document)
    .off('change' + NS, '#people_table tbody input.person-check, #people_table tbody input.attendee-check')
    .on('change' + NS,  '#people_table tbody input.person-check, #people_table tbody input.attendee-check', function(){
      const $cb  = $(this);
      const key  = String($cb.data('key') || '');
      const on   = $cb.is(':checked');
      const $row = $cb.closest('tr');
      if (on) PEOPLE_SELECTED.add(key);
      else PEOPLE_SELECTED.delete(key);
      $row.toggleClass('selected', on);
      dm_syncSelectAllState();
    });

  $(document)
    .off('change' + NS, '#people_select_all')
    .on('change' + NS,  '#people_select_all', function(){
      const on = $(this).is(':checked');
      $('#people_table tbody input.person-check, #people_table tbody input.attendee-check').each(function(){
        const $cb = $(this);
        if ($cb.is(':checked') !== on) {
          $cb.prop('checked', on).trigger('change');
        }
      });
    });

  function dm_collectSelectedNames() {
    const out = [];
    $('#people_table tbody input.person-check:checked, #people_table tbody input.attendee-check:checked').each(function(){
      const $cb   = $(this);
      const first = String($cb.data('first') || '').trim();
      const last  = String($cb.data('last') || '').trim();
      let name    = [first, last].filter(Boolean).join(' ').trim();
      if (!name) {
        const $tr   = $cb.closest('tr');
        const tds   = $tr.children('td');
        const alt   = [tds.eq(1).text(), tds.eq(2).text()].map(function(s){ return (s || '').trim(); }).filter(Boolean).join(' ');
        name = alt || String($cb.data('email') || '').trim();
      }
      if (name) out.push(name);
    });
    const seen = new Set();
    return out.filter(function(n){
      n = n.trim();
      return n && !seen.has(n) && seen.add(n);
    });
  }

  $(document)
    .off('click' + NS, '#create_meeting_dialog, [data-dm="open-create-meeting"]')
    .on('click' + NS,  '#create_meeting_dialog, [data-dm="open-create-meeting"]', function (e) {
      e.preventDefault();
      const $form = $('#create-meeting-form');
      if ($form.length) $form[0].reset();
      const now = new Date();
      $('#mtg_year').val(now.getFullYear());
      $('#mtg_date').val(now.toISOString().slice(0,10));
      hideErr();
      ensureMultiProgramControl();
      $.ajax({ url: API_BASE + '/programs', dataType: 'json' })
        .done(function(items){
          const $sel = $('#mtg_program');
          if (!$sel.length) return;
          $sel.find('option').remove();
          (items || []).forEach(function(p){
            const id = (p.program_id ?? p.name ?? '');
            const nm = (p.name ?? String(p.program_id));
            $sel.append('<option value="' + id + '">' + nm + '</option>');
          });
          upgradeMultiProgramUI(items);
          $sel.trigger('change');
        });
      dm_loadLocations();
      $('#people_search').val('');
      PEOPLE_PAGE = 1;
      PEOPLE_SELECTED = new Set();
      $('#mtg_attendees').val('');
      dm_loadPeople();
      const $modal = $('#createMeetingModal');
      if ($modal.length) {
        $modal.modal('show');
        setTimeout(function(){ $('#mtg_name').trigger('focus'); }, 150);
      }
      dm_enableRowSelection(['#people_table']);
    });

  $(document)
    .off('input' + NS, '#people_search')
    .on('input' + NS,  '#people_search', function(){
      applyPeopleSearch();
    });

  $(document)
    .off('click' + NS, '#people_pager a.page-link')
    .on('click' + NS,  '#people_pager a.page-link', function(e){
      e.preventDefault();
      const pg = parseInt($(this).data('page'), 10);
      if (!isNaN(pg)) {
        PEOPLE_PAGE = pg;
        renderPeople();
      }
    });

  $(document)
    .off('click' + NS, '#create_meeting_submit, #create_meeting_save')
    .on('click' + NS,  '#create_meeting_submit, #create_meeting_save', function (e) {
      e.preventDefault();
      const $form = $('#create-meeting-form');
      if ($form.length) $form.trigger('submit');
    });

  let creating = false;
  $(document)
    .off('submit' + NS, '#create-meeting-form')
    .on('submit' + NS, '#create-meeting-form', function (e) {
      e.preventDefault();
      if (creating) return;
      hideErr();

      const p = buildPayload();
      const selNames = dm_collectSelectedNames();
      if (selNames.length) {
        p.attendees = selNames.join(',');
        p.attendees_list = selNames;
      }

      const v = validate(p);
      if (v) {
        showErr(v);
        return;
      }

      creating = true;
      const $footerBtns = $('#createMeetingModal .modal-footer .btn').prop('disabled', true).addClass('disabled');

      $.ajax({
        url: API_BASE + '/create',
        type: 'POST',
        data: p,
        dataType: 'json'
      })
      .done(function (r) {
        if (r && (r.ok || r.success)) {
          $('#createMeetingModal').modal('hide');
          document.dispatchEvent(new CustomEvent('meeting:created', { detail: Object.assign({}, p, r) }));
        } else {
          showErr((r && (r.message || r.detail)) || 'Unexpected server response.');
        }
      })
      .fail(function (xhr) {
        const serverMsg =
          (xhr.responseJSON && (xhr.responseJSON.message || xhr.responseJSON.detail)) ||
          xhr.responseText ||
          '';

        if (xhr.status === 403) {
          if (/login required/i.test(serverMsg)) {
            showErr('You must be logged in to create a meeting.');
          } else if (serverMsg) {
            showErr(serverMsg);
          } else {
            showErr('You are not allowed to create meetings.');
          }
        }
        else if (xhr.status === 404) {
          showErr('Create endpoint not found at ' + API_BASE + '/create');
        }
        else if (xhr.status === 400) {
          showErr(serverMsg || 'Invalid input. Please check the required fields.');
        }
        else {
          showErr('Error ' + xhr.status + ': ' + (serverMsg || xhr.statusText || 'request failed'));
        }
      })
      .always(function(){
        creating = false;
        $footerBtns.prop('disabled', false).removeClass('disabled');
      });
    });

})(jQuery);

(function($){
  'use strict';
  var hasDT = $.fn && $.fn.DataTable;
  var meetingDT = null;

  function adjustMeetingDT(){
    if (!meetingDT) return;

    try { meetingDT.columns.adjust(); } catch (e) {}

    var $tbl = $('#meeting_table');
    var $wrap = $tbl.closest('.dataTables_wrapper');
    var $scrollHead = $wrap.find('.dataTables_scrollHeadInner');
    var $scrollHeadTable = $wrap.find('.dataTables_scrollHeadInner table');
    var $scrollBodyTable = $wrap.find('.dataTables_scrollBody table');

    if ($scrollBodyTable.length && $scrollHead.length && $scrollHeadTable.length) {
      var bodyWidth = $scrollBodyTable.outerWidth();
      if (bodyWidth) {
        $scrollHead.width(bodyWidth);
        $scrollHeadTable.width(bodyWidth);
      }
    }
  }

  function linkify(name, id){
    var tmpl = window.DM_MEETING_URL_TMPL;
    if (!tmpl || !id) return name || '';
    var href = String(tmpl).replace('{id}', String(id));
    var safe = String(name || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    return '<a href="' + href + '">' + safe + '</a>';
  }

  function escAttr(v){
    return String(v == null ? '' : v)
      .replace(/&/g,'&amp;')
      .replace(/"/g,'&quot;')
      .replace(/</g,'&lt;')
      .replace(/>/g,'&gt;');
  }

  function escHtml(v){
    return String(v == null ? '' : v)
      .replace(/&/g,'&amp;')
      .replace(/</g,'&lt;')
      .replace(/>/g,'&gt;')
      .replace(/"/g,'&quot;')
      .replace(/'/g,'&#39;');
  }

  function parseJSON(s){
    try { return JSON.parse(s || '{}') || {}; }
    catch (e) { return {}; }
  }

  function isMeetingSaved(meetingJson){
    var j = meetingJson || {};
    if (j.saved === true) return true;
    if (j.is_saved === true) return true;
    if (j.meeting_saved === true) return true;
    if (j.decisions_saved === true) return true;
    if (String(j.status || '').toLowerCase() === 'saved') return true;
    if (String(j.save_status || '').toLowerCase() === 'saved') return true;
    if (j.saved_at) return true;
    if (j.date_saved) return true;
    return false;
  }

  function getMeetingProgramsText(j){
    return Array.isArray(j.breeding_programs)
      ? j.breeding_programs.join(', ')
      : (j.breeding_programs || j.breeding_program || '');
  }

  function getMeetingAttendeesText(j){
    return Array.isArray(j.attendees_list)
      ? j.attendees_list.join(', ')
      : (j.attendees || '');
  }

  function getMeetingNotesText(j){
    return j.notes || j.meeting_notes || j.data || '';
  }

  function meetingCheckboxHtml(id, name, date, saved){
    if (saved) {
      return '<span class="dm-meeting-select-disabled" title="This meeting has already been saved.">Saved</span>';
    }
    return '<input type="checkbox" class="dm-meeting-check" ' +
           'data-meeting-id="' + escAttr(id) + '" ' +
           'data-meeting-name="' + escAttr(name) + '" ' +
           'data-meeting-date="' + escAttr(date) + '">';
  }

  function meetingDownloadBtnHtml(id, saved){
    return '<button type="button" class="btn btn-sm btn-default dm-meeting-download-btn" ' +
           'data-meeting-id="' + escAttr(id) + '" ' +
           'data-meeting-saved="' + (saved ? '1' : '0') + '">' +
           'Download</button>';
  }

  function getSelectedMeeting(){
    var $checked = $('.dm-meeting-check:checked').first();
    if (!$checked.length) return null;
    return {
      meeting_id: $checked.data('meeting-id'),
      meeting_name: $checked.data('meeting-name'),
      meeting_date: $checked.data('meeting-date')
    };
  }

  window.getSelectedDecisionMeeting = getSelectedMeeting;

  window.requireSelectedDecisionMeeting = function(){
    var sel = getSelectedMeeting();
    if (!sel) {
      alert('Please select one meeting first.');
      return null;
    }
    return sel;
  };

  function ensureDT(){
    var $tbl = $('#meeting_table');
    if (!hasDT || !$tbl.length) return null;
    if ($.fn.DataTable.isDataTable($tbl[0])) {
      meetingDT = $tbl.DataTable();
      return meetingDT;
    }
    meetingDT = $tbl.DataTable({
      dom: 'lftip',
      pageLength: 10,
      lengthMenu: [[10,25,50],[10,25,50]],
      order: [[3,'desc']],
      autoWidth: false,
      scrollX: true,
      scrollCollapse: true,
      deferRender: true,
      columns: [
        { title:'Select',    className:'text-center', orderable:false, searchable:false },
        { title:'Meeting',   className:'text-left'   },
        { title:'Programs',  className:'text-left'   },
        { title:'Date',      className:'text-nowrap' },
        { title:'Location',  className:'text-left'   },
        { title:'Attendees', className:'text-left'   },
        { title:'Download',  className:'text-center', orderable:false, searchable:false }
      ],
      drawCallback: function () {
        var api = this.api();
        setTimeout(function () {
          try { api.columns.adjust(); } catch (e) {}
        }, 0);
      }
    });
    return meetingDT;
  }

  function rowsToArrays(rows){
    return (rows || []).map(function(r){
      var j = parseJSON(r.meeting_json);
      var id    = r.project_id;
      var name  = j.meeting_name || r.project_name || '';
      var date  = j.date || '';
      var loc   = j.location_name || j.location || '';
      var progs = getMeetingProgramsText(j);
      var atts  = getMeetingAttendeesText(j);
      var notes = getMeetingNotesText(j);
      var saved = isMeetingSaved(j);

      window.DM_MEETING_CACHE[String(id)] = {
        id: id,
        meeting_name: name,
        meeting_date: date,
        location: loc,
        programs_text: progs,
        attendees_text: atts,
        notes: notes,
        saved: saved,
        meeting_json: j
      };

      return [
        meetingCheckboxHtml(id, name, date, saved),
        linkify(name, id),
        escHtml(progs),
        escHtml(date),
        escHtml(loc),
        escHtml(atts),
        meetingDownloadBtnHtml(id, saved)
      ];
    });
  }

  async function loadMeetingTracker(){
    var base = window.DM_API_BASE || '/ajax/decisionmeeting';
    var url  = base + '/meetings';
    var $tbl = $('#meeting_table');
    if (!$tbl.length) return;
    ensureDT();
    if (!meetingDT) return;
    $tbl.addClass('dm-loading');

    try {
      var r = await fetch(url, { headers:{ 'Accept':'application/json' } });
      if (!r.ok) throw new Error('HTTP ' + r.status + ' ' + r.statusText);
      var j = await r.json();
      var rows = j.rows || [];
      window.DM_MEETING_CACHE = {};
      var data = rowsToArrays(rows);
      meetingDT.clear();
      if (data.length) meetingDT.rows.add(data);
      meetingDT.draw(false);
      setTimeout(adjustMeetingDT, 0);
    } catch (err) {
      meetingDT.clear().draw();
    } finally {
      $tbl.removeClass('dm-loading');
      setTimeout(adjustMeetingDT, 0);
    }
  }

  async function downloadMeetingReport(meetingId){
    var base = (window.DM_API_BASE || '/ajax/decisionmeeting');
    var url = base + '/meeting_report_html?meeting_id=' + encodeURIComponent(meetingId);

    try {
      var resp = await fetch(url, {
        headers: { 'Accept': 'text/html,application/json' }
      });

      var ct = resp.headers.get('content-type') || '';

      if (!resp.ok) {
        if (ct.indexOf('application/json') !== -1) {
          var errJson = await resp.json();
          throw new Error(errJson.message || errJson.error || ('HTTP ' + resp.status));
        } else {
          var txt = await resp.text().catch(function(){ return ''; });
          throw new Error(txt || ('HTTP ' + resp.status));
        }
      }

      window.open(url, '_blank');
    } catch (err) {
      alert(err && err.message ? err.message : 'Could not open meeting report.');
      throw err;
    }
  }

  document.addEventListener('meeting:created', function(){
    setTimeout(loadMeetingTracker, 200);
  });

  var dmMeetingResizeTimer = null;

  $(window)
    .off('resize.dmMeetingTable orientationchange.dmMeetingTable')
    .on('resize.dmMeetingTable orientationchange.dmMeetingTable', function(){
      clearTimeout(dmMeetingResizeTimer);
      dmMeetingResizeTimer = setTimeout(function(){
        adjustMeetingDT();
      }, 120);
    });

  $(document)
    .off('shown.bs.collapse.dmMeeting shown.bs.tab.dmMeeting shown.bs.modal.dmMeeting')
    .on('shown.bs.collapse.dmMeeting shown.bs.tab.dmMeeting shown.bs.modal.dmMeeting', function(){
      setTimeout(function(){
        adjustMeetingDT();
      }, 100);
    });

  $(document)
    .off('change.dmMeetingSelect', '.dm-meeting-check')
    .on('change.dmMeetingSelect', '.dm-meeting-check', function(){
      if (this.checked) {
        $('.dm-meeting-check').not(this).prop('checked', false);
      }
    });

  $(document)
    .off('click.dmMeetingDownload', '.dm-meeting-download-btn')
    .on('click.dmMeetingDownload', '.dm-meeting-download-btn', async function(){
      var $btn = $(this);
      var meetingId = $btn.data('meeting-id');
      var original = $btn.text();

      if (!meetingId) {
        alert('Meeting ID not found.');
        return;
      }

      $btn.prop('disabled', true).text('Preparing...');

      try {
        await downloadMeetingReport(meetingId);
      } catch (e) {
        alert('Could not open the meeting report.');
      } finally {
        $btn.prop('disabled', false).text(original);
      }
    });

  $(function(){
    if ($('#meeting_table').length) setTimeout(loadMeetingTracker, 0);
  });
})(jQuery);