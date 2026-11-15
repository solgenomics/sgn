/*
 * Decision meeting page: the "New meeting" dialog
 * (mason/breeders_toolbox/decision_meeting/add_meeting_dialog.mas).
 * Programs, locations and attendees are loaded from /ajax/decisionmeeting/*;
 * on success the event meeting:created is dispatched with the new project_id.
 * Moved unchanged from js/source/entries/decision_meeting.js.
 */
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

  function dmEscapeHtml(value){
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
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

  function twoDigit(value) {
    return value < 10 ? '0' + value : String(value);
  }

  function formatMeetingDateForDisplay(date) {
    return date.getFullYear() + '-' +
      twoDigit(date.getMonth() + 1) + '-' +
      twoDigit(date.getDate());
  }

  function meetingDateForServer(value) {
    const match = $.trim(value || '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!match) return '';

    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    const parsed = new Date(year, month - 1, day);

    if (parsed.getFullYear() !== year ||
        parsed.getMonth() !== month - 1 ||
        parsed.getDate() !== day) {
      return '';
    }

    return String(year) + '-' + twoDigit(month) + '-' + twoDigit(day);
  }

  function ensureMeetingDatePicker() {
    const $date = $('#mtg_date');
    if (!$date.length || !$.fn.datepicker) return;
    if ($date.data('dmDatePickerInitialized')) return;

    $date
      .off('changeDate.dmMeetingDate')
      .on('changeDate.dmMeetingDate', function(event) {
        if (event && event.date instanceof Date && !isNaN(event.date.getTime())) {
          $(this).val(formatMeetingDateForDisplay(event.date));
        }
      });

    $date.datepicker({
      // jQuery UI uses dateFormat; Bootstrap Datepicker uses format.
      dateFormat: 'yy-mm-dd',
      format: 'yyyy-mm-dd',
      changeMonth: true,
      changeYear: true,
      autoclose: true,
      onSelect: function(dateText) {
        $(this).val(dateText);
      }
    });
    $date.data('dmDatePickerInitialized', true);
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
      date:               meetingDateForServer($('#mtg_date').val()),
      data:               $.trim($('#mtg_data').val() || ''),
      attendees:          parseAttendees($('#mtg_attendees').val()).join(',')
    };
  }

  function validate(p){
    if (!p.meeting_name) return 'Please enter the Meeting name.';
    if (!p.location) return 'Please enter the Location.';
    if (!/^\d{4}$/.test(p.year)) return 'Please enter the Year in YYYY format.';
    if (!$.trim($('#mtg_date').val() || '')) return 'Please enter the Date in YYYY-MM-DD format.';
    if (!p.date) return 'Please enter a valid Date in YYYY-MM-DD format.';
    if (!p.breeding_programs || p.breeding_programs.length === 0) return 'Please select at least one Breeding Program.';
    return '';
  }

  function dm_loadLocations() {
    const $sel = $('#mtg_location');
    if (!$sel.length) return;
    if (!API_BASE) return;
    $sel.find('option:not([value=""])').remove();
    $.ajax({
      url: API_BASE + '/locations',
      dataType: 'json',
      cache: false
    })
      .done(function(items){
        if (!items || !items.length) {
          return;
        }
        (items || []).forEach(function(l){
          const id = l.location_id ?? '';
          const nm = l.name ?? String(id);
          if (id !== '') {
            $sel.append($('<option></option>').val(String(id)).text(String(nm)));
          }
        });
      })
      .fail(function(){});
  }

  const PEOPLE_PAGE_SIZE = 10;
  let PEOPLE_ALL = [];
  let PEOPLE_FILTERED = [];
  let PEOPLE_PAGE = 1;
  let PEOPLE_SELECTED = new Set();

  function dm_updateSelectedAttendeeCount() {
    const count = PEOPLE_SELECTED.size;
    $('#people_selected_count').text(count + ' selected');
  }

  function normPerson(p){
    p = p && typeof p === 'object' ? p : {};
    return {
      first_name:    String(p.first_name ?? p.first ?? p.given_name ?? '').trim(),
      last_name:     String(p.last_name  ?? p.last  ?? p.family_name ?? '').trim(),
      contact_email: String(p.contact_email ?? p.email ?? '').trim()
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
      dm_updateSelectedAttendeeCount();
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
      const safeKey = dmEscapeHtml(key);
      const safeEmail = dmEscapeHtml(em);
      const safeFirst = dmEscapeHtml(p.first_name || '');
      const safeLast = dmEscapeHtml(p.last_name || '');
      return (
        '<tr>'
          + '<td class="text-center">'
            + `<input type="checkbox" class="person-check attendee-check" id="${id}"`
              + ` data-key="${safeKey}" data-email="${safeEmail}" data-first="${safeFirst}" data-last="${safeLast}"${checked}>`
          + '</td>'
          + `<td><label for="${id}" class="sr-only">Select ${safeFirst || 'person'}</label>${safeFirst}</td>`
          + `<td>${safeLast}</td>`
          + `<td>${safeEmail}</td>`
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
    dm_updateSelectedAttendeeCount();
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
      dm_updateSelectedAttendeeCount();
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
    const out = PEOPLE_ALL
      .filter(function(person) {
        return PEOPLE_SELECTED.has(personKey(person));
      })
      .map(function(person) {
        const name = [person.first_name, person.last_name]
          .filter(Boolean)
          .join(' ')
          .trim();
        return name || person.contact_email || '';
      })
      .filter(Boolean);
    const seen = new Set();
    return out.filter(function(name){
      const normalized = name.trim();
      return normalized && !seen.has(normalized) && seen.add(normalized);
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
      ensureMeetingDatePicker();
      $('#mtg_date').val(formatMeetingDateForDisplay(now));
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
            $sel.append($('<option></option>').val(String(id)).text(String(nm)));
          });
          upgradeMultiProgramUI(items);
          $sel.trigger('change');
        });
      dm_loadLocations();
      $('#people_search').val('');
      PEOPLE_PAGE = 1;
      PEOPLE_SELECTED = new Set();
      dm_updateSelectedAttendeeCount();
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
          showErr((r && (r.message || r.msg || r.detail)) || 'Unexpected server response.');
        }
      })
      .fail(function (xhr) {
        const serverMsg =
          (xhr.responseJSON && (xhr.responseJSON.message || xhr.responseJSON.msg || xhr.responseJSON.detail)) ||
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
