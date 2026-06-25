export function createAccessionTools({ qs }) {
  function currentBorderAccession() {
    return String(qs('#border-accession')?.value || '').trim();
  }

  function initAccessionAutocomplete(selector, placeholder, dropdownParent = null, width = '16rem') {
    if (!window.jQuery || !$(selector).length) return;

    const $select = $(selector);
    if (typeof $select.select2 !== 'function') return;
    if ($select.data('select2')) $select.select2('destroy');

    const config = {
      placeholder,
      allowClear: true,
      width,
      minimumInputLength: 2,
      ajax: {
        url: '/ajax/trialallocation/accession_autocomplete',
        dataType: 'json',
        delay: 250,
        data: params => ({ q: params.term || '' }),
        processResults: data => ({ results: data.results || [] })
      }
    };
    if (dropdownParent) config.dropdownParent = dropdownParent;

    $select.select2(config);
  }

  function setAccessionSelectValue(select, value) {
    if (!select) return;
    const accession = String(value || '').trim();
    select.innerHTML = '<option value=""></option>';
    if (accession) {
      select.appendChild(new Option(accession, accession, true, true));
    }
    if (window.jQuery) $(select).trigger('change.select2');
  }

  function chooseFillerAccession(currentValue = '') {
    return new Promise(resolve => {
      const overlay = document.createElement('div');
      overlay.className = 'fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center';
      overlay.style.zIndex = 10050;
      overlay.innerHTML = `
        <div class="bg-white rounded shadow-lg p-4 w-full max-w-md">
          <h3 class="text-lg font-semibold mb-3">Select filler accession</h3>
          <select id="plot-filler-accession-dialog" class="w-full border rounded px-2 py-1">
            <option value=""></option>
          </select>
          <div class="mt-4 flex justify-end gap-2">
            <button type="button" id="plot-filler-clear" class="px-3 py-1 border rounded">Clear</button>
            <button type="button" id="plot-filler-cancel" class="px-3 py-1 border rounded">Cancel</button>
            <button type="button" id="plot-filler-apply" class="px-3 py-1 bg-blue-600 text-white rounded">Apply</button>
          </div>
        </div>
      `;
      document.body.appendChild(overlay);

      const select = qs('#plot-filler-accession-dialog');
      setAccessionSelectValue(select, currentValue);
      initAccessionAutocomplete('#plot-filler-accession-dialog', 'Search accession', $(overlay).find('.bg-white'), '100%');

      const close = value => {
        if (window.jQuery && $('#plot-filler-accession-dialog').data('select2')) {
          $('#plot-filler-accession-dialog').select2('destroy');
        }
        overlay.remove();
        resolve(value);
      };

      qs('#plot-filler-apply')?.addEventListener('click', () => close(select.value.trim()));
      qs('#plot-filler-clear')?.addEventListener('click', () => close(''));
      qs('#plot-filler-cancel')?.addEventListener('click', () => close(null));
      overlay.addEventListener('click', e => {
        if (e.target === overlay) close(null);
      });
    });
  }

  return {
    currentBorderAccession,
    initAccessionAutocomplete,
    chooseFillerAccession
  };
}
