// js/entries/decision_meeting.js
(function (jQuery) {
  'use strict';
  jQuery(function ($) {

    function dbg(){ if (window.DM_DEBUG) { var a=[].slice.call(arguments); a.unshift('[DecisionMeeting]'); console.log.apply(console,a);} }
    console.info('%cDecisionMeeting JS file loaded','color:#0a7;font-weight:bold');

    /* ===== Root detection ===== */
    var $root =
      $('#decision_meeting_main').length ? $('#decision_meeting_main') :
      $('#decision_table').length       ? $('#decision_table').closest('.panel, .box, .card, .well, body') :
      $('#meeting_table').length        ? $('#meeting_table').closest('.panel, .box, .card, .well, body') :
      $();

    if (!$root.length) console.error('[DecisionMeeting] No suitable container found (missing #decision_meeting_main and tables).');
    else console.info('%cDecisionMeeting JS initialized','color:#1b6;font-weight:bold');

    var hasDT = $.fn && $.fn.DataTable;
    function findSectionBody($sec){ var $b=$sec.find('.panel-body, .detail-section-body, .box-body, .card-body, .well').first(); return $b.length?$b:$sec; }

    /* ===== Topbar (Accession List + Clear) ===== */
    function injectTopbar(){
      if (!$root.length) return;
      var $dest = findSectionBody($root);
      if ($('#dm-topbar').length) return;
      var html =
        '<div id="dm-topbar" class="row" style="margin-top:5px;margin-bottom:10px;">' +
          '<div class="col-sm-12">' +
            '<label class="control-label" for="dm_list_sel" style="margin-right:8px;">Accession List</label>' +
            '<select id="dm_list_sel" class="form-control" style="display:inline-block; width:auto; min-width:220px;"><option value="">(choose a list)</option></select>' +
            '<button id="dm_clear_filters" class="btn btn-default" style="margin-left:10px;">Clear</button>' +
          '</div>' +
        '</div>';
      $dest.prepend(html);
    }
    injectTopbar();

    /* ===== API base auto-detect ===== */
    async function detectApiBase() {
      var hinted = document.querySelector('[data-dm-api-base]')?.getAttribute('data-dm-api-base');
      var candidates = [
        hinted,
        '/ajax/decisionmeeting',   // try the correct one first to avoid noisy 404s
        '/ajax/decision_meeting',
        '/ajax/decision'
      ].filter(Boolean);

      for (var i=0;i<candidates.length;i++){
        var base = candidates[i];
        try{
          var r = await fetch(base + '/ping', { headers:{'Accept':'application/json'} });
          var ct = r.headers.get('content-type')||'';
          if (!r.ok) continue;
          if (!ct.includes('application/json')) continue;
          var j = await r.json();
          if (j && (j.ok || j.lists || j.datasets)) return base;
        }catch(e){}
      }
      return null;
    }

    /* ===== AJAX helpers ===== */
    function ajaxJSON(path, params){
      var base = window.DM_API_BASE || '';
      var q = params ? ('?' + new URLSearchParams(params)) : '';
      var url = base + path + q;
      dbg('GET', url);
      return fetch(url, { headers:{'Accept':'application/json'} }).then(async function(r){
        var ct = r.headers.get('content-type')||'';
        if (!r.ok){ var txt = await r.text().catch(()=> ''); throw new Error('HTTP '+r.status+' '+r.statusText+' on '+url+'\n'+txt.slice(0,200)); }
        if (!ct.includes('application/json')){ var txt2 = await r.text().catch(()=> ''); throw new Error('Non-JSON response for '+url+': '+txt2.slice(0,120)+'…'); }
        return r.json();
      });
    }
    function ajaxPOST(path, bodyObj){
      var base = window.DM_API_BASE || '';
      var url = base + path;
      dbg('POST', url, bodyObj);
      return fetch(url, {
        method:'POST',
        headers:{'Content-Type':'application/json','Accept':'application/json'},
        body: JSON.stringify(bodyObj||{})
      }).then(async function(r){
        var ct = r.headers.get('content-type')||'';
        if (!r.ok){ var txt = await r.text().catch(()=> ''); throw new Error('HTTP '+r.status+' '+r.statusText+' on '+url+'\n'+txt.slice(0,200)); }
        if (!ct.includes('application/json')){ var txt2 = await r.text().catch(()=> ''); throw new Error('Non-JSON response for '+url+': '+txt2.slice(0,120)+'…'); }
        return r.json();
      });
    }

    /* ===== Lists loader ===== */
    function loadLists(){
      return ajaxJSON('/lists', { type:'accessions' }).then(function(resp){
        var $sel = $('#dm_list_sel');
        if (!$sel.length) return;
        $sel.empty().append('<option value="">(choose a list)</option>');
        (resp && resp.lists || []).forEach(function(li){
          $sel.append('<option value="'+(li.list_id||'')+'">'+(li.name||('List '+li.list_id))+'</option>');
        });
      });
    }

    /* ===== Decision table (no search UI) ===== */
    var decisionDT = (function(){
      var $tbl = $('#decision_table');
      if (!hasDT || !$tbl.length) return null;
      var dt = $.fn.DataTable.isDataTable($tbl[0]) ? $tbl.DataTable() : $tbl.DataTable({
        dom:'lptip',
        pageLength:10,
        lengthMenu:[[10,25,50],[10,25,50]],
        order:[],
        orderCellsTop:true,
        fixedHeader:true,
        autoWidth:false,
        scrollX:true,
        deferRender:true
      });
      return dt;
    })();

    function clearDecisionRows(){ if (!decisionDT) return; decisionDT.rows().clear().draw(); }
    function addDecisionRows(rows){
      if (!decisionDT) return;
      if (!rows || !rows.length){ decisionDT.draw(false); return; }
      var data = rows.map(function(r){
        return [ r.accession||'', r.breeding_program||'', r.stage||'', r.year||'', r.decision||'', r.female_parent||'', r.male_parent||'', r.notes||'' ];
      });
      decisionDT.rows.add(data).draw(false);
    }

    /* ===== Populate table ===== */
    async function loadDecisionsForList(list_id){
      clearDecisionRows();
      try{
        var postRes = await ajaxPOST('/decisions', { list_id });
        if (postRes && Array.isArray(postRes.rows) && postRes.rows.length){ addDecisionRows(postRes.rows); dbg('Decisions via POST:', postRes.rows.length); return; }
      }catch(e){ dbg('POST /decisions not available or empty. Falling back…'); }

      try{
        var getRes = await ajaxJSON('/decisions', { list_id });
        if (getRes && Array.isArray(getRes.rows) && getRes.rows.length){ addDecisionRows(getRes.rows); dbg('Decisions via GET:', getRes.rows.length); return; }
      }catch(e2){ dbg('GET /decisions not available or empty. Falling back…'); }

      try{
        var acc = await ajaxJSON('/accessions', { list_id });
        var names = (acc && acc.accessions || []).map(a => a.name||'').filter(Boolean);
        addDecisionRows(names.map(nm => ({ accession:nm, breeding_program:'', stage:'', year:'', decision:'', female_parent:'', male_parent:'', notes:'' })));
        dbg('Filled table with accession names only:', names.length);
      }catch(e3){ console.error('[DecisionMeeting] Could not load decisions or accessions for list', list_id, e3); }
    }

    /* ===== UI binding ===== */
    function bindUI(){
      $(document).off('change.dm','#dm_list_sel').on('change.dm','#dm_list_sel', async function(){
        var id = $(this).val() || '';
        if (id) await loadDecisionsForList(id); else clearDecisionRows();
      });
      $(document).off('click.dm','#dm_clear_filters').on('click.dm','#dm_clear_filters', function(){
        $('#dm_list_sel').val(''); clearDecisionRows(); dbg('Cleared list selection and table');
      });
    }
    bindUI();

    /* ===== Boot ===== */
    (async function boot(){
      var base = await detectApiBase();
      if (!base){ console.error('[DecisionMeeting] Could not detect backend base. Check controller namespace/routes.'); return; }
      window.DM_API_BASE = base;
      console.log('[DecisionMeeting] Using API base:', base);
      await loadLists();
      dbg('Lists loaded');
    })();

    /* ===== Public hook ===== */
    window.addDecisionRow = function(row){ addDecisionRows([row]); };

  });
})(jQuery);

(function($){
  'use strict';

  // Prevent double-initialization if the script is included multiple times
  if (window.__DM_CREATE_WIRED__) return;
  window.__DM_CREATE_WIRED__ = true;

  const NS = '.dmCreateV4';
  const API_BASE = (window.DM_API_BASE
    || $('#decision_meeting_main').data('dmApiBase')
    || '/ajax/decisionmeeting');

  function parseAttendees(text){
    return (text||'').split(/\n|,/g).map(s=>s.trim()).filter(Boolean);
  }
  function showErr(msg){ $('#create-meeting-error').text(msg||'Unexpected error').show(); }
  function hideErr(){ $('#create-meeting-error').hide().text(''); }

  function buildPayload(){
    return {
      meeting_name:     $.trim($('#mtg_name').val()||''),
      breeding_program: $('#mtg_program').val() || '',
      location:         $.trim($('#mtg_location').val()||''),
      year:             String($('#mtg_year').val()||''),
      date:             $('#mtg_date').val() || '',
      data:             $.trim($('#mtg_data').val()||''),
      attendees:        parseAttendees($('#mtg_attendees').val()).join(',')
    };
  }
  function validate(p){
    if (!p.meeting_name) return 'Please enter the Meeting name.';
    if (!p.location)     return 'Please enter the Location.';
    if (!p.year || isNaN(Number(p.year))) return 'Please enter a valid Year.';
    if (!p.date)         return 'Please choose a Date.';
    return '';
  }

  // OPEN modal (supports id or data-attr)
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

      $.ajax({ url: API_BASE + '/programs', dataType: 'json' })
        .done(function(items){
          const $sel = $('#mtg_program');
          if (!$sel.length) return;
          $sel.empty().append('<option value="">— Select (optional) —</option>');
          (items || []).forEach(function(p){
            const id = (p.program_id ?? p.name ?? '');
            const nm = (p.name ?? String(p.program_id));
            $sel.append('<option value="'+id+'">'+nm+'</option>');
          });
        });

      const $modal = $('#createMeetingModal');
      if ($modal.length) {
        $modal.modal('show');
        setTimeout(()=> $('#mtg_name').trigger('focus'), 150);
      } else {
        console.warn('[DM] Missing #createMeetingModal in DOM.');
      }
    });

  // SAVE buttons explicitly trigger submit (in case they’re not type=submit)
  $(document)
    .off('click' + NS, '#create_meeting_submit, #create_meeting_save')
    .on('click' + NS,  '#create_meeting_submit, #create_meeting_save', function (e) {
      e.preventDefault();
      const $form = $('#create-meeting-form');
      if ($form.length) $form.trigger('submit');
    });

  // ⬇️ DELEGATED SUBMIT: survives form re-renders inside the modal
  let creating = false;
  $(document)
    .off('submit' + NS, '#create-meeting-form')
    .on('submit' + NS, '#create-meeting-form', function (e) {
      e.preventDefault();
      if (creating) return;

      hideErr();
      const p = buildPayload();
      const v = validate(p);
      if (v) { showErr(v); return; }

      creating = true;
      const $footerBtns = $('#createMeetingModal .modal-footer .btn').prop('disabled', true).addClass('disabled');

      $.ajax({
        url: API_BASE + '/create',
        type: 'POST',
        data: p,          // form-urlencoded
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
        if (xhr.status === 403)       showErr('You must be logged in to create a meeting.');
        else if (xhr.status === 404)  showErr('Create endpoint not found at ' + API_BASE + '/create');
        else if (xhr.status === 400)  showErr('Invalid input. Please check the required fields.');
        else                          showErr('Error ' + xhr.status + ': ' + (xhr.responseJSON?.message || xhr.statusText || 'request failed'));
      })
      .always(function(){
        creating = false;
        $footerBtns.prop('disabled', false).removeClass('disabled');
      });
    });

  // One-time wiring log
  $(function(){
    console.log('[DecisionMeeting] Using API base:', API_BASE);
    console.log('[DM] wiring ready. API_BASE=', API_BASE,
      ' openBtn=', !!($('#create_meeting_dialog').length || $('[data-dm="open-create-meeting"]').length),
      ' form=', !!$('#create-meeting-form').length,
      ' saveBtn=', !!($('#create_meeting_submit').length || $('#create_meeting_save').length)
    );
  });

})(jQuery);
