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

    var hasDT = $.fn && $.fn.DataTable;
    function findSectionBody($sec){ var $b=$sec.find('.panel-body, .detail-section-body, .box-body, .card-body, .well').first(); return $b.length?$b:$sec; }

    /* ----------------------- Client state ---------------------- */
    var STATE = {
      list_id: '',
      rows: [],                 // rows actually rendered (after cross-product)
      baseRows: [],             // normalized rows returned by backend (may be partial)
      accessions: [],           // unique accession names from backend
      programs: [],             // array of program names from backend
      decisionsMap: new Map(),  // key: accession||program -> decision ('drop','hold','advance','jump','')
      currentBpFilter: ''       // '' means all
    };

    /* ===== Tiny CSS for decision colors ===== */
    function injectStyles(){
      if (document.getElementById('dm-decision-styles')) return;
      var css = `
        .dm-decision-select { min-width: 130px; }
        .dm-dec-none   { background-color: #fff; }
        .dm-dec-drop   { background-color: #f8d7da; color:#842029; }  /* red-ish */
        .dm-dec-hold   { background-color: #ffe5b4; color:#7a3e00; }  /* orange/amber */
        .dm-dec-advance{ background-color: #d4edda; color:#0f5132; }  /* green */
        .dm-dec-jump   { background-color: #e6d4ff; color:#2e1065; }  /* purple */
        .dm-bp-header-select { max-width: 220px; margin-top:6px; }
        .dm-topbar-search { width:260px; display:inline-block; }
      `;
      var el = document.createElement('style');
      el.id = 'dm-decision-styles';
      el.type = 'text/css';
      el.appendChild(document.createTextNode(css));
      document.head.appendChild(el);
    }
    injectStyles();

    /* ===== Topbar: Accession list (left) + Search (right) ===== */
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
          '<div class="col-sm-6 text-right">' +
            '<label class="control-label" for="dm_search" style="margin-right:8px;">Search</label>' +
            '<input type="search" id="dm_search" class="form-control dm-topbar-search" placeholder="Search  "/>' +
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
        '/ajax/decisionmeeting',
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

    /* ===== Breeding programs loader ===== */
    async function loadBreedingPrograms(){
      var endpoints = ['/programs'];
      for (var i=0;i<endpoints.length;i++){
        try{
          var j = await ajaxJSON(endpoints[i]);
          if (!j) continue;
          var arr = [];
          if (Array.isArray(j)) { arr = j; }
          else if (Array.isArray(j.programs)) { arr = j.programs; }
          else if (Array.isArray(j.breeding_programs)) { arr = j.breeding_programs; }
          else if (Array.isArray(j.rows)) { arr = j.rows; }

          var norm = arr.map(function(x){
            var name = x.name || x.program_name || x.label || x.value || String(x||'');
            return name;
          }).filter(Boolean);

          if (norm.length) {
            // Unique list preserving order
            var seen = new Set(), out = [];
            norm.forEach(function(n){ if (!seen.has(n)) { seen.add(n); out.push(n); } });
            return out;
          }
        }catch(e){ /* try next */ }
      }
      return [];
    }

    /* ===== Decision helpers ===== */
    function keyFor(acc, bp){ return String(acc||'') + '||' + String(bp||''); }
    function normDecision(v){
      var x = String(v||'').trim().toLowerCase();
      if (x === 'drop') return 'drop';
      if (x === 'hold') return 'hold';
      if (x === 'advance') return 'advance';
      if (x === 'jump') return 'jump';
      return '';
    }
    function colorClass(val){
      switch (val){
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
        '<select class="dm-decision-select form-control input-sm '+colorClass(cur)+'" ' +
                'data-acc="'+String(acc||'').replace(/"/g,'&quot;')+'" ' +
                'data-bp="'+String(bp||'').replace(/"/g,'&quot;')+'">' +
          '<option value="">(select)</option>' +
          '<option value="drop"'+    (cur==='drop'    ? ' selected':'')+'>Drop</option>' +
          '<option value="hold"'+    (cur==='hold'    ? ' selected':'')+'>Hold</option>' +
          '<option value="advance"'+ (cur==='advance' ? ' selected':'')+'>Advance</option>' +
          '<option value="jump"'+    (cur==='jump'    ? ' selected':'')+'>Jump</option>' +
        '</select>';
    }
    function applyDecisionColor(sel){
      var v = normDecision(sel.value);
      sel.classList.remove('dm-dec-none','dm-dec-drop','dm-dec-hold','dm-dec-advance','dm-dec-jump');
      sel.classList.add(colorClass(v));
    }

    /* ===== DataTables (no built-in search box) ===== */
    var decisionDT = (function(){
      var $tbl = $('#decision_table');
      if (!hasDT || !$tbl.length) return null;
      // Ensure thead exists (and capture BP th later)
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

    function clearDecisionRows(){ if (!decisionDT) return; decisionDT.clear().draw(); }

    function rowsToDataArrays(rows){
      return (rows||[]).map(function(r){
        var acc   = r.accession || '';
        var bp    = r.breeding_program || '';
        var stage = r.stage || '';
        var year  = r.year || '';
        var dec   = r.decision || '';
        var fem   = r.female_parent || '';
        var male  = r.male_parent || '';
        var notes = r.notes || '';
        var decSel = decisionSelectHTML(dec, acc, bp);
        return [acc, bp, stage, year, decSel, fem, male, notes];
      });
    }

    function renderRows(rows){
      if (!decisionDT) return;
      clearDecisionRows();
      var data = rowsToDataArrays(rows);
      if (data.length) decisionDT.rows.add(data).draw(false);
      // Re-apply BP header filter if set
      if (STATE.currentBpFilter) {
        if (decisionDT) decisionDT.column(1).search('^' + escapeRegExp(STATE.currentBpFilter) + '$', true, false).draw();
      }
    }

    function normalizeRows(rawRows){
      return (rawRows||[]).map(function(r){
        return {
          accession:        (r.accession||''),
          breeding_program: (r.breeding_program||''),
          stage:            (r.stage||''),
          year:             (r.year||''),
          decision:         normDecision(r.decision),
          female_parent:    (r.female_parent||''),
          male_parent:      (r.male_parent||''),
          notes:            (r.notes||'')
        };
      });
    }

    function uniq(arr){
      var s = new Set(), out=[];
      (arr||[]).forEach(function(x){
        var v = (x==null?'':String(x));
        if (!s.has(v)){ s.add(v); out.push(v); }
      });
      return out;
    }

    function escapeHtml(s){
      return String(s||'').replace(/[&<>"']/g, function(c){
        return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c] || c;
      });
    }
    function escapeRegExp(s){ return String(s||'').replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

    /* ===== Build cross-product: one row per Accession × Program ===== */
    function buildCrossProductRows(){
      var accs = STATE.accessions;
      var programs = STATE.programs;
      var byKey = new Map(); // from existing baseRows (with potential values)
      STATE.baseRows.forEach(function(r){
        var k = keyFor(r.accession || '', r.breeding_program || '');
        byKey.set(k, r);
      });

      var out = [];
      if (accs.length && programs.length){
        for (var i=0;i<accs.length;i++){
          var a = accs[i];
          for (var j=0;j<programs.length;j++){
            var p = programs[j];
            var k = keyFor(a, p);
            if (byKey.has(k)) {
              out.push(Object.assign({}, byKey.get(k)));
            } else {
              out.push({
                accession: a,
                breeding_program: p,
                stage: '',
                year: '',
                decision: normDecision(STATE.decisionsMap.get(k) || ''),
                female_parent:'',
                male_parent:'',
                notes:''
              });
            }
          }
        }
      } else {
        // Fallback: if no programs, just show whatever baseRows we have or accessions only
        if (accs.length && !programs.length){
          accs.forEach(function(a){
            var k = keyFor(a, '');
            out.push(byKey.get(k) || { accession:a, breeding_program:'', stage:'', year:'', decision:'', female_parent:'', male_parent:'', notes:'' });
          });
        } else {
          out = STATE.baseRows.slice();
        }
      }

      STATE.rows = out;
      renderRows(out);
    }

    /* ===== BP header select ===== */
    function ensureBpHeaderFilter(){
      var $tbl = $('#decision_table');
      if (!$tbl.length) return;

      // Grab header cell for Breeding Program (assumed column index 1)
      var $th = $tbl.find('thead th').eq(1);
      if (!$th.length) return;

      // Avoid duplicating the control
      if ($th.find('#dm_bp_header_filter').length) return;

      // Keep original label text
      var labelText = ($th.text() || 'Breeding Program').trim().split('\n')[0] || 'Breeding Program';
      $th.html(
        '<div style="display:flex;flex-direction:column;">' +
          '<div>' + escapeHtml(labelText) + '</div>' +
          '<select id="dm_bp_header_filter" class="form-control input-sm dm-bp-header-select">' +
             '<option value="">(All programs)</option>' +
          '</select>' +
        '</div>'
      );
      if (decisionDT) decisionDT.columns.adjust();
      populateBpHeaderFilterOptions(STATE.programs);

      // Bind change -> exact match search on column 1
      $(document).off('change.dm','#dm_bp_header_filter').on('change.dm','#dm_bp_header_filter', function(){
        var v = this.value || '';
        STATE.currentBpFilter = v;
        if (!decisionDT) return;
        if (v === '') {
          decisionDT.column(1).search('').draw();
        } else {
          decisionDT.column(1).search('^' + escapeRegExp(v) + '$', true, false).draw();
        }
      });
    }

    function populateBpHeaderFilterOptions(programs){
      var $sel = $('#dm_bp_header_filter');
      if (!$sel.length) return;
      var cur = $sel.val() || STATE.currentBpFilter || '';
      $sel.find('option:not([value=""])').remove();

      // Unique + sorted by appearance (keep input order)
      var seen = new Set();
      (programs||[]).forEach(function(p){
        if (!p) return;
        if (seen.has(p)) return;
        seen.add(p);
        $sel.append('<option value="'+escapeHtml(p)+'">'+escapeHtml(p)+'</option>');
      });

      // Restore previous selection if present
      if (cur && seen.has(cur)) $sel.val(cur); else { $sel.val(''); STATE.currentBpFilter=''; }
    }

    /* ===== Load + normalize + cross product ===== */
    async function loadDecisionsForList(list_id){
      STATE.list_id = list_id || '';
      STATE.rows = [];
      STATE.baseRows = [];
      STATE.accessions = [];
      STATE.decisionsMap.clear();

      // 1) Preferred: POST /decisions
      var loaded = false;
      try{
        var postRes = await ajaxPOST('/decisions', { list_id });
        if (postRes && Array.isArray(postRes.rows) && postRes.rows.length){
          STATE.baseRows = normalizeRows(postRes.rows);
          loaded = true;
        }
      }catch(e){ dbg('POST /decisions not available or empty. Falling back…'); }

      // 2) GET /decisions
      if (!loaded){
        try{
          var getRes = await ajaxJSON('/decisions', { list_id });
          if (getRes && Array.isArray(getRes.rows) && getRes.rows.length){
            STATE.baseRows = normalizeRows(getRes.rows);
            loaded = true;
          }
        }catch(e2){ dbg('GET /decisions not available or empty. Falling back…'); }
      }

      // 3) Fallback: /accessions (names only)
      if (!loaded){
        try{
          var acc = await ajaxJSON('/accessions', { list_id });
          var names = (acc && acc.accessions || []).map(function(a){ return (a && a.name)||''; }).filter(Boolean);
          STATE.baseRows = names.map(function(nm){
            return { accession:nm, breeding_program:'', stage:'', year:'', decision:'', female_parent:'', male_parent:'', notes:'' };
          });
          loaded = true;
        }catch(e3){
          console.error('[DecisionMeeting] Could not load decisions or accessions for list', list_id, e3);
        }
      }

      // Collect unique accessions from baseRows
      STATE.accessions = uniq(STATE.baseRows.map(function(r){ return r.accession || ''; }).filter(Boolean));

      // Merge in any programs found in baseRows (ensure the header filter includes them)
      var progsInRows = uniq(STATE.baseRows.map(function(r){ return r.breeding_program || ''; }).filter(Boolean));
      var mergedPrograms = STATE.programs.slice();
      progsInRows.forEach(function(p){ if (p && mergedPrograms.indexOf(p) === -1) mergedPrograms.push(p); });
      STATE.programs = mergedPrograms;

      // Seed decisionsMap
      STATE.baseRows.forEach(function(r){
        var k = keyFor(r.accession, r.breeding_program);
        STATE.decisionsMap.set(k, normDecision(r.decision));
      });

      // Update BP header filter options with merged list
      populateBpHeaderFilterOptions(STATE.programs);

      // Build cross product and render
      buildCrossProductRows();
    }

    /* ===== UI bindings ===== */
    function bindUI(){
      // list selector
      $(document).off('change.dm','#dm_list_sel').on('change.dm','#dm_list_sel', async function(){
        var id = $(this).val() || '';
        if (id) await loadDecisionsForList(id);
        else {
          STATE.list_id=''; STATE.rows=[]; STATE.baseRows=[]; STATE.accessions=[]; STATE.decisionsMap.clear();
          clearDecisionRows();
        }
      });

      // clear button: resets list, table, search, and BP header filter
      $(document).off('click.dm','#dm_clear_filters').on('click.dm','#dm_clear_filters', function(){
        $('#dm_list_sel').val('');
        $('#dm_search').val('');
        var $bp = $('#dm_bp_header_filter');
        if ($bp.length) $bp.val('');
        STATE.currentBpFilter = '';
        if (decisionDT){ decisionDT.search('').columns().search('').draw(); }
        STATE.list_id=''; STATE.rows=[]; STATE.baseRows=[]; STATE.accessions=[]; STATE.decisionsMap.clear();
        clearDecisionRows();
        dbg('Cleared selection and table');
      });

      // right-side search box -> DataTables global search
      $(document).off('input.dm keyup.dm change.dm','#dm_search').on('input.dm keyup.dm change.dm','#dm_search', function(){
        if (decisionDT) decisionDT.search(this.value || '').draw();
      });

      // decision change -> recolor + cache in STATE
      $(document).off('change.dm','.dm-decision-select').on('change.dm','.dm-decision-select', function(){
        applyDecisionColor(this);
        var acc = this.getAttribute('data-acc') || '';
        var bp  = this.getAttribute('data-bp') || '';
        var v   = normDecision(this.value);
        STATE.decisionsMap.set(keyFor(acc, bp), v);
        // Optional: persist immediately
        // ajaxPOST('/decision/save', { accession:acc, breeding_program:bp, decision:v }).catch(()=>{});
      });
    }
    bindUI();

    /* ===== Boot ===== */
    (async function boot(){
      var base = await detectApiBase();
      if (!base){ console.error('[DecisionMeeting] Could not detect backend base. Check controller namespace/routes.'); return; }
      window.DM_API_BASE = base;
      console.log('[DecisionMeeting] Using API base:', base);

      // Load lists + programs
      await loadLists();
      STATE.programs = await loadBreedingPrograms();
      dbg('Programs loaded:', STATE.programs);

      // Ensure BP header select exists and is populated
      ensureBpHeaderFilter();
      populateBpHeaderFilterOptions(STATE.programs);

      dbg('Lists loaded & header filter ready');
    })();

    /* ===== Public hook (append one row) ===== */
    window.addDecisionRow = function(row){
      // Normalize & merge into STATE.baseRows, then rebuild cross-product
      var r = normalizeRows([row||{}])[0];
      // Update/set decision map
      STATE.decisionsMap.set(keyFor(r.accession, r.breeding_program), normDecision(r.decision));
      // If new accession or program, expand sets
      if (STATE.accessions.indexOf(r.accession) === -1) STATE.accessions.push(r.accession);
      if (STATE.programs.indexOf(r.breeding_program) === -1 && r.breeding_program) {
        STATE.programs.push(r.breeding_program);
        populateBpHeaderFilterOptions(STATE.programs);
      }
      // Merge into baseRows (replace if same acc+bp)
      var replaced = false;
      for (var i=0;i<STATE.baseRows.length;i++){
        var br = STATE.baseRows[i];
        if (br.accession === r.accession && br.breeding_program === r.breeding_program) {
          STATE.baseRows[i] = r;
          replaced = true; break;
        }
      }
      if (!replaced) STATE.baseRows.push(r);

      buildCrossProductRows();
    };

  });
})(jQuery);


(function($){
  'use strict';
  // Prevent runaway duplication, but allow re-wiring on reload
  if (window.__DM_CREATE_WIRED__) {
    console.warn('[DM] script already wired — re-wiring handlers anyway');
  }
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

  // --- Breeding Program: enforce multi-select no matter what -----------------
  function ensureMultiProgramControl() {
    const $sel = $('#mtg_program');
    if (!$sel.length) return;

    // If a plugin wrapped it, destroy first so we can switch to multiple safely
    if ($.fn.select2 && $sel.data('select2')) {
      try { $sel.select2('destroy'); } catch(e) { /* ignore */ }
    }
    if ($.fn.selectpicker && $sel.data('selectpicker')) {
      try { $sel.selectpicker('destroy'); } catch(e) { /* ignore */ }
    }

    // Force native multiple + sensible size for fallback UI
    $sel.attr('multiple', 'multiple');   // attribute (not only prop) for consistency
    $sel.prop('multiple', true);
    if (!$sel.attr('size')) $sel.attr('size', 6); // visible rows for native control
    // Optional: make name array-like in case server reads form directly
    if (!$sel.attr('name') || $sel.attr('name') === 'mtg_program') {
      $sel.attr('name', 'mtg_program[]');
    }
  }

  function upgradeMultiProgramUI(items) {
    const $sel = $('#mtg_program');
    if (!$sel.length) return;

    // Re-init preferred plugin in multi mode
    if ($.fn.select2) {
      try {
        // Destroy any prior instance just in case
        if ($sel.data('select2')) $sel.select2('destroy');
        $sel.select2({
          width: '100%',
          placeholder: 'Select breeding program(s)',
          closeOnSelect: false
        });
        return; // prefer select2 if available
      } catch(e) { /* fallback below */ }
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
      } catch(e) { /* fallback below */ }
    }

    // Native fallback: set size proportional to number of options
    const n = Math.min(10, Math.max(5, (items && items.length) ? items.length : parseInt($sel.attr('size')||6, 10)));
    $sel.attr('size', n);
  }

  // Build payload with multi-select programs
  function buildPayload(){
    const progVals = $('#mtg_program').val(); // array for multiple
    const programs = Array.isArray(progVals)
      ? progVals.filter(Boolean)
      : (progVals ? [progVals] : []);

    return {
      meeting_name:       $.trim($('#mtg_name').val()||''),
      // Back-compat CSV
      breeding_program:   programs.join(','),
      // New: array
      breeding_programs:  programs,
      location:           $.trim($('#mtg_location').val()||''),
      year:               String($('#mtg_year').val()||''),
      date:               $('#mtg_date').val() || '',
      data:               $.trim($('#mtg_data').val()||''),
      // Will be overridden at submit with selected names from the table:
      attendees:          parseAttendees($('#mtg_attendees').val()).join(',')
    };
  }

  function validate(p){
    if (!p.meeting_name) return 'Please enter the Meeting name.';
    if (!p.location)     return 'Please enter the Location.';
    if (!p.year || isNaN(Number(p.year))) return 'Please enter a valid Year.';
    if (!p.date)         return 'Please choose a Date.';
    if (!p.breeding_programs || p.breeding_programs.length === 0) return 'Please select at least one Breeding Program.';
    return '';
  }

  // --- LOCATIONS --------------------------------------------------------------
  function dm_loadLocations() {
    const $sel = $('#mtg_location');
    if (!$sel.length) { console.warn('[DecisionMeeting] #mtg_location not found'); return; }
    if (!API_BASE) { console.warn('[DecisionMeeting] API_BASE missing'); return; }

    $sel.find('option:not([value=""])').remove();

    $.ajax({ url: API_BASE + '/locations', dataType: 'json' })
      .done(function(items){
        if (!items || !items.length) {
          console.warn('[DecisionMeeting] locations: empty response');
          return;
        }
        (items || []).forEach(function(l){
          const id = l.location_id ?? '';
          const nm = l.name ?? String(id);
          if (id !== '') $sel.append('<option value="'+id+'">'+nm+'</option>');
        });
      })
      .fail(function(xhr){
        console.error('[DecisionMeeting] Failed to load locations', xhr && xhr.status, xhr && xhr.responseText);
      });
  }

  // === PEOPLE: keep AJAX; add search + 10/per page + persistent selection =====
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
      (p.last_name  || '').toLowerCase(),
      (p.contact_email || '').toLowerCase()
    ].join('|');
  }

  function dm_syncSelectAllState(){
    const $rows = $('#people_table tbody tr');
    if (!$rows.length) { $('#people_select_all').prop('checked', false); return; }
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
    for (let i=start; i<=end; i++){
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

    if (!total){
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
            // NOTE: both classes so older handlers and new ones work;
            // store first/last for reliable name building.
            + `<input type="checkbox" class="person-check attendee-check" id="${id}"` +
              ` data-key="${key}" data-email="${em}" data-first="${p.first_name || ''}" data-last="${p.last_name || ''}"${checked}>`
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
      PEOPLE_FILTERED = PEOPLE_ALL.filter(p => {
        return (p.first_name || '').toLowerCase().includes(q)
            || (p.last_name  || '').toLowerCase().includes(q)
            || (p.contact_email || '').toLowerCase().includes(q);
      });
    }
    PEOPLE_PAGE = 1;
    renderPeople();
  }

  function dm_loadPeople() {
    const $tbody = $('#people_table tbody');
    if (!$tbody.length) { console.warn('[DecisionMeeting] #people_table tbody not found'); return; }
    if (typeof API_BASE === 'undefined' || !API_BASE) { console.warn('[DecisionMeeting] API_BASE missing'); return; }

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
    .fail(function(xhr){
      console.error('[DecisionMeeting] Failed to load people', xhr && xhr.responseText);
      $tbody.html('<tr><td colspan="4">Failed to load.</td></tr>');
    });
  }

  /* ===== Row-click selection ===== */
  function dm_enableRowSelection(tableSelectors) {
    (tableSelectors || ['#people_table', '#meeting_table', '#decision_table']).forEach(function(sel){
      const $t = $(sel);
      if (!$t.length) return;

      // Toggle selection by clicking the row (but ignore clicks on form controls)
      $t.off('click.dmPickRow').on('click.dmPickRow', 'tbody tr', function ev(e){
        if ($(e.target).is('input,button,a,select,label,textarea')) return;
        const $row = $(this);
        const nowSelected = !$row.hasClass('selected');
        $row.toggleClass('selected', nowSelected);
        // Keep checkbox (if present) in sync; trigger change to update PEOPLE_SELECTED
        let $chk = $row.find('input.attendee-check[type=checkbox]').first();
        if (!$chk.length) $chk = $row.find('input.person-check[type=checkbox]').first();
        if ($chk.length) $chk.prop('checked', nowSelected).trigger('change');
      });

      // If user checks/unchecks explicitly, sync the row class
      $t.off('change.dmPickRow').on('change.dmPickRow', 'input.attendee-check[type=checkbox], input.person-check[type=checkbox]', function(){
        const $row = $(this).closest('tr');
        $row.toggleClass('selected', this.checked);
      });
    });
  }

  // Keep PEOPLE_SELECTED and row highlighting in sync for checkboxes
  $(document)
    .off('change' + NS, '#people_table tbody input.person-check, #people_table tbody input.attendee-check')
    .on('change' + NS,  '#people_table tbody input.person-check, #people_table tbody input.attendee-check', function(){
      const $cb  = $(this);
      const key  = String($cb.data('key') || '');
      const on   = $cb.is(':checked');
      const $row = $cb.closest('tr');

      if (on) PEOPLE_SELECTED.add(key);
      else    PEOPLE_SELECTED.delete(key);

      $row.toggleClass('selected', on);
      dm_syncSelectAllState();
    });

  // Optional: header "select all" checkbox with id #people_select_all
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

  // Collect selected NAMES from the people table (first + last; fallback email)
  function dm_collectSelectedNames() {
    const out = [];
    $('#people_table tbody input.person-check:checked, #people_table tbody input.attendee-check:checked').each(function(){
      const $cb   = $(this);
      const first = String($cb.data('first') || '').trim();
      const last  = String($cb.data('last')  || '').trim();
      let name    = [first, last].filter(Boolean).join(' ').trim();

      if (!name) {
        // Fallback: read from columns 1 & 2 (First / Last), then fallback to email
        const $tr   = $cb.closest('tr');
        const tds   = $tr.children('td');
        const alt   = [tds.eq(1).text(), tds.eq(2).text()].map(s => (s||'').trim()).filter(Boolean).join(' ');
        name = alt || String($cb.data('email') || '').trim();
      }
      if (name) out.push(name);
    });

    // unique, keep order
    const seen = new Set();
    return out.filter(n => (n = n.trim()) && !seen.has(n) && seen.add(n));
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

      // Make sure the select is multi BEFORE fetching options
      ensureMultiProgramControl();

      $.ajax({ url: API_BASE + '/programs', dataType: 'json' })
        .done(function(items){
          const $sel = $('#mtg_program');
          if (!$sel.length) return;

          // Clear and repopulate
          $sel.find('option').remove();
          (items || []).forEach(function(p){
            const id = (p.program_id ?? p.name ?? '');
            const nm = (p.name ?? String(p.program_id));
            $sel.append('<option value="'+id+'">'+nm+'</option>');
          });

          // After options exist, upgrade UI (plugins or native)
          upgradeMultiProgramUI(items);
          // Trigger change so plugins (if any) sync
          $sel.trigger('change');
        });

      dm_loadLocations();
      $('#people_search').val('');
      PEOPLE_PAGE = 1;
      PEOPLE_SELECTED = new Set();
      $('#mtg_attendees').val(''); // hidden/textarea (if present)
      dm_loadPeople();

      const $modal = $('#createMeetingModal');
      if ($modal.length) {
        $modal.modal('show');
        setTimeout(()=> $('#mtg_name').trigger('focus'), 150);
      } else {
        console.warn('[DM] Missing #createMeetingModal in DOM.');
      }

      // Enable row click selection on the people table
      dm_enableRowSelection(['#people_table']);
    });

  // Search people as user types (optional element #people_search)
  $(document)
    .off('input' + NS, '#people_search')
    .on('input' + NS,  '#people_search', function(){
      applyPeopleSearch();
    });

  // Pager click
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

  // SAVE buttons explicitly trigger submit
  $(document)
    .off('click' + NS, '#create_meeting_submit, #create_meeting_save')
    .on('click' + NS,  '#create_meeting_submit, #create_meeting_save', function (e) {
      e.preventDefault();
      const $form = $('#create-meeting-form');
      if ($form.length) $form.trigger('submit');
    });

  // DELEGATED SUBMIT
  let creating = false;
  $(document)
    .off('submit' + NS, '#create-meeting-form')
    .on('submit' + NS, '#create-meeting-form', function (e) {
      e.preventDefault();
      if (creating) return;

      hideErr();
      const p = buildPayload();

      // Override attendees with selected names from the people table
      const selNames = dm_collectSelectedNames();
      if (selNames.length) {
        // safest for server-side: CSV (controller splits by comma/newline)
        p.attendees = selNames.join(',');
        // also send array form if you want to handle arrays in the controller
        p.attendees_list = selNames;
      }
      console.debug('[DM] create payload attendees:', p.attendees, p.attendees_list);

      const v = validate(p);
      if (v) { showErr(v); return; }

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

/* ===== Meeting Tracker: auto-load table (client parses meeting_json) ===== */
(function($){
  'use strict';

  var hasDT = $.fn && $.fn.DataTable;
  var meetingDT = null;

  // Optional: make the meeting name clickable
  // window.DM_MEETING_URL_TMPL = "/project/{id}";
  function linkify(name, id){
    var tmpl = window.DM_MEETING_URL_TMPL;
    if (!tmpl || !id) return name || '';
    var href = String(tmpl).replace('{id}', String(id));
    var safe = String(name||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    return '<a href="'+href+'">'+safe+'</a>';
  }

  function ensureDT(){
    var $tbl = $('#meeting_table');
    if (!hasDT || !$tbl.length) return null;
    if ($.fn.DataTable.isDataTable($tbl[0])) {
      meetingDT = $tbl.DataTable(); return meetingDT;
    }
    meetingDT = $tbl.DataTable({
      dom: 'lftip',
      pageLength: 10,
      lengthMenu: [[10,25,50],[10,25,50]],
      order: [[2,'desc']], // by Date
      autoWidth: false,
      deferRender: true,
      columns: [
        { title:'Meeting',   className:'text-left'  },
        { title:'Programs',  className:'text-left'  },
        { title:'Date',      className:'text-nowrap'},
        { title:'Year',      className:'text-center'},
        { title:'Location',  className:'text-left'  },
        { title:'Attendees', className:'text-left'  },
        { title:'Notes',     className:'text-left'  }
      ]
    });
    return meetingDT;
  }

  function parseJSON(s){ try { return JSON.parse(s||'{}')||{}; } catch(e){ return {}; } }

  function rowsToArrays(rows){
    return (rows||[]).map(function(r){
      var j = parseJSON(r.meeting_json);
      var id    = r.project_id;
      var name  = j.meeting_name || r.project_name || '';
      var date  = j.date  || '';
      var year  = j.year  || '';
      var loc   = j.location_name || j.location || '';
      var progs = Array.isArray(j.breeding_programs)
                    ? j.breeding_programs.join(', ')
                    : (j.breeding_programs || '');
      var atts  = Array.isArray(j.attendees_list)
                    ? j.attendees_list.join(', ')
                    : (j.attendees || '');
      var notes = j.notes || j.data || '';

      return [
        linkify(name, id),
        progs,
        date,
        year,
        loc,
        atts,
        notes
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
    try{
      var r = await fetch(url, { headers:{'Accept':'application/json'} });
      if (!r.ok) throw new Error('HTTP '+r.status+' '+r.statusText);
      var j = await r.json();

      var rows = j.rows || [];
      var data = rowsToArrays(rows);

      meetingDT.clear();
      if (data.length) meetingDT.rows.add(data);
      meetingDT.draw(false);
    } catch(err){
      console.error('[DecisionMeeting] loadMeetingTracker failed:', err);
      meetingDT.clear().draw();
    } finally {
      $tbl.removeClass('dm-loading');
    }
  }

  document.addEventListener('meeting:created', function(){
    setTimeout(loadMeetingTracker, 200);
  });

  $(function(){
    if ($('#meeting_table').length) setTimeout(loadMeetingTracker, 0);
  });

})(jQuery);
