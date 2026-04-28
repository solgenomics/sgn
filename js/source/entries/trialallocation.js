
import '../legacy/jquery.js';
import '../legacy/d3/d3v4Min.js';


document.addEventListener('DOMContentLoaded', () => {

  /******** global state ********/
  let gridReady = false;
  let lastUnusedRows = '';
  let lastUnusedCols = '';
  const trialDesignCache = {};
  let availableTrialTypes = [];
  let availableTrialDesigns = [];

  /******** constants and utils ********/
  const qs  = s => document.querySelector(s);
  const qsa = s => Array.from(document.querySelectorAll(s));
  const CELL = 40, GAP = 2, STEP = CELL + GAP;
  const colours = ['bg-red-400','bg-blue-400','bg-yellow-300','bg-green-400'];
  const colourFor = n => colours[(n-1)%colours.length];
  const uid = (() => { let i = 0; return () => `u${++i}`; })();
  const key = (r,c) => `${r},${c}`;

  let manualBlock   = new Set();
  let manualAllow   = new Set();
  let manualBorders = new Set();
  let borderPlots   = new Map();
  let fillerPlots   = new Map();
  let selectedRoot  = null;
  let suppressCellClick = false;
  let lockedTrialRoots = new Set();
  let lockedTrialForms = new Map();
  let layoutContextLocked = false;

  const intList = id => {
    const t = qs('#'+id)?.value.trim();
    return t ? t.split(',').map(v=>+v.trim()-1).filter(n=>!isNaN(n)) : [];
  };

  function cellIsUnused(r,c){
    const row = intList('unused-rows').includes(r);
    const col = intList('unused-cols').includes(c);
    const k   = key(r,c);
    if (manualAllow.has(k)) return false;
    if (manualBlock.has(k)) return true;
    return row || col;
  }

  function activeTool(){
    if (qs('#edit-toggle')?.checked) return 'unused';
    if (qs('#border-toggle')?.checked) return 'border';
    if (qs('#filler-toggle')?.checked) return 'filler';
    return null;
  }

  function isCellOccupied(r, c, ignoreRoot = null){
    return [...document.querySelectorAll('.trial-group')].some(group => {
      if (ignoreRoot && group.dataset.root === ignoreRoot) return false;
      const gr = +group.dataset.row;
      const gc = +group.dataset.col;
      const gw = groupWidth(group);
      const gh = groupHeight(group);
      return r >= gr && r < gr + gh && c >= gc && c < gc + gw;
    }) || fillerPlots.has(key(r, c));
  }

  function groupWidth(group){
    return group.style.gridTemplateColumns.split(' ').filter(Boolean).length || 1;
  }

  function groupHeight(group){
    return Math.max(1, Math.round(group.offsetHeight / STEP));
  }

  function designRows(design){
    if (!design) return [];
    if (Array.isArray(design)) return design;
    try {
      const parsed = JSON.parse(design);
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      console.error('Could not parse trial design metadata:', e);
      return [];
    }
  }

  function trialLayoutSettings(tn){
    return {
      layoutType: qs(`#tlayout${tn}`)?.value || 'serpentine',
      horizontalDir: qs(`#grid-direction-horizontal${tn}`)?.value || 'ltr',
      verticalDir: qs(`#grid-direction-vertical${tn}`)?.value || 'ttb',
      startPlotNumber: parseInt(qs(`#tstartplot${tn}`)?.value, 10) || 1,
      plotNumbering: qs(`#tplotnumbering${tn}`)?.value || 'continuous'
    };
  }

  function orderedCells(cells, colsWanted, settings){
    const rows = [];
    for (let i = 0; i < cells.length; i += colsWanted) {
      rows.push(cells.slice(i, i + colsWanted));
    }

    return rows.flatMap((row, rowIndex) => {
      const reverseRow = (settings.horizontalDir === 'rtl') !==
        (settings.layoutType === 'serpentine' && rowIndex % 2 === 1);
      return reverseRow ? row.slice().reverse() : row;
    });
  }

  function assignPlotNumbers(rows, settings){
    const blockCounts = {};
    const start = settings.startPlotNumber;
    const magnitude = start < 100 ? 100 : Math.pow(10, Math.max(1, String(Math.abs(start)).length - 1));
    const withinBlockStart = start % magnitude || 1;

    return rows.map((row, index) => {
      const block = parseInt(row.block, 10) || 1;
      const numbered = Object.assign({}, row);

      if (settings.plotNumbering === 'block_prefix') {
        const blockIndex = blockCounts[block] || 0;
        numbered.plot_number = block * magnitude + withinBlockStart + blockIndex;
        blockCounts[block] = blockIndex + 1;
      } else {
        numbered.plot_number = start + index;
      }

      return numbered;
    });
  }

  function basePlotLabel(box){
    return box.dataset.plotNumber || '';
  }

  function plotTypeLabel(box){
    if (box.dataset.fillerAccession) return 'Filler';
    return box.dataset.isControl === '1' ? 'Check accession' : 'Test accession';
  }

  function plotTooltipHtml(box){
    const plotNumber = basePlotLabel(box);
    const accession = box.dataset.fillerAccession || box.dataset.accessionName || 'Not available';
    const rowNumber = Number.isNaN(Number(box.dataset.row)) ? 'Not available' : Number(box.dataset.row) + 1;
    const colNumber = Number.isNaN(Number(box.dataset.col)) ? 'Not available' : Number(box.dataset.col) + 1;

    return `
      <div><span class="tooltip-label">Plot number:</span> ${plotNumber || 'Not available'}</div>
      <div><span class="tooltip-label">Row:</span> ${rowNumber}</div>
      <div><span class="tooltip-label">Column:</span> ${colNumber}</div>
      <div><span class="tooltip-label">Accession:</span> ${accession}</div>
      <div><span class="tooltip-label">Type:</span> ${plotTypeLabel(box)}</div>
    `;
  }

  function currentBorderAccession() {
    return String(qs('#border-accession')?.value || '').trim();
  }

  function sanitizeTrialName(name) {
    return String(name || '')
      .trim()
      .replace(/\s+/g, '_')
      .replace(/[\\/:,"*?<>|]+/g, '_')
      .replace(/_+/g, '_')
      .replace(/^_+|_+$/g, '');
  }

  function designIsAugmentedRowColumn(value) {
    return value === 'ARC' || value === 'Augmented' || value === 'Augmented Row-Column';
  }

  function designIsRowColumn(value) {
    return value === 'RRC' || value === 'Row-Column Design';
  }

  function populateTrialMetadataSelects(scope = document) {
    Array.from(scope.querySelectorAll('select[id^="ttype"]')).forEach(select => {
      const trialIndex = +(select.id.replace('ttype', '') || 0);
      const selected = select.value || lockedTrialForms.get(trialIndex)?.type || '';
      select.innerHTML = '<option value="">Select type</option>';
      availableTrialTypes.forEach(type => {
        select.appendChild(new Option(type.name, type.name));
      });
      if (selected) select.value = selected;
    });

    Array.from(scope.querySelectorAll('select[id^="tdesign"]')).forEach(select => {
      const trialIndex = +(select.id.replace('tdesign', '') || 0);
      const selected = select.value || lockedTrialForms.get(trialIndex)?.design || '';
      select.innerHTML = '<option value="">Select design</option>';
      availableTrialDesigns.forEach(design => {
        select.appendChild(new Option(design.name, design.value));
      });
      if (selected) select.value = selected;
    });
  }

  function isLockedRoot(root) {
    return !!root && lockedTrialRoots.has(root);
  }

  function lockControl(id, locked = true) {
    const el = qs(`#${id}`);
    if (!el) return;
    el.disabled = locked;
    if (window.jQuery) $(`#${id}`).trigger('change.select2');
  }

  function lockLayoutContext(locked = true) {
    layoutContextLocked = locked;
    ['farm_dropdown', 'breeding_program_dropdown', 'layout-year', 'layout-season', 'farm-rows', 'farm-cols'].forEach(id => lockControl(id, locked));
  }

  function restoreTrialFormValues(form) {
    if (!form) return;
    const i = form.trial_index;
    setInputValue(`tname${i}`, form.name);
    setInputValue(`tdesc${i}`, form.description);
    setSelectValue(`ttype${i}`, form.type);
    setSelectValue(`tdesign${i}`, form.design);
    setSelectValue(`tlayout${i}`, form.layout_type);
    setSelectValue(`grid-direction-horizontal${i}`, form.horizontal_direction);
    setSelectValue(`grid-direction-vertical${i}`, form.vertical_direction);
    setInputValue(`tstartplot${i}`, form.start_plot_number);
    setSelectValue(`tplotnumbering${i}`, form.plot_numbering);
    setInputValue(`treps${i}`, form.reps);
    setInputValue(`tblocks${i}`, form.blocks);
    setInputValue(`trepsblocks${i}`, form.repsblocks);
    setInputValue(`trows${i}`, form.rows);
    setInputValue(`tcols${i}`, form.cols);
    setInputValue(`tblockrows${i}`, form.block_rows);
    setInputValue(`tblockcols${i}`, form.block_cols);
    setInputValue(`tsuperrows${i}`, form.super_rows);
    setInputValue(`tsupercols${i}`, form.super_cols);
    setSelectValue(`ttreatments${i}`, form.treatment_list_id);
    setSelectValue(`tcontrols${i}`, form.control_list_id);
  }

  function lockTrialForm(trialIndex, locked = true) {
    const form = qs(`#tname${trialIndex}`)?.closest('.border.rounded');
    if (!form) return;
    form.classList.toggle('opacity-70', locked);
    form.querySelectorAll('input, textarea, select, button').forEach(el => {
      el.disabled = locked;
    });
    [`grid-direction-horizontal${trialIndex}`, `grid-direction-vertical${trialIndex}`].forEach(id => lockControl(id, locked));
  }

  function lockTrialVisuals(root, locked = true) {
    qsa(`.trial-group[data-root="${root}"]`).forEach(group => {
      group.dataset.locked = locked ? '1' : '0';
      group.draggable = !locked;
      group.classList.toggle('locked-trial', locked);
      group.querySelectorAll('.trial-box').forEach(box => {
        box.draggable = !locked;
      });
      group.querySelectorAll('.remove-btn,.transpose-btn').forEach(btn => {
        btn.style.display = locked ? 'none' : '';
      });
    });
  }

  function lockPlacedTrials(locked = true, roots = null) {
    const allowedRoots = roots ? new Set(roots) : null;
    qsa('.trial-group').forEach(group => {
      if (allowedRoots && !allowedRoots.has(group.dataset.root)) return;
      if (locked) lockedTrialRoots.add(group.dataset.root);
      else lockedTrialRoots.delete(group.dataset.root);
      lockTrialVisuals(group.dataset.root, locked);
      lockTrialForm(+group.dataset.trial, locked);
      const form = serializeTrialForms().find(item => item.trial_index === +group.dataset.trial);
      if (locked && form) lockedTrialForms.set(+group.dataset.trial, form);
    });
  }

  function movePlotTooltip(e){
    const tooltip = qs('#plot-hover-tooltip');
    if (!tooltip) return;

    const offset = 14;
    const rect = tooltip.getBoundingClientRect();
    let left = e.clientX + offset;
    let top = e.clientY + offset;

    if (left + rect.width > window.innerWidth) left = e.clientX - rect.width - offset;
    if (top + rect.height > window.innerHeight) top = e.clientY - rect.height - offset;

    tooltip.style.left = `${Math.max(8, left)}px`;
    tooltip.style.top = `${Math.max(8, top)}px`;
  }

  function showPlotTooltip(e){
    let tooltip = qs('#plot-hover-tooltip');
    if (!tooltip) {
      tooltip = document.createElement('div');
      tooltip.id = 'plot-hover-tooltip';
      tooltip.className = 'plot-hover-tooltip';
      document.body.appendChild(tooltip);
    }
    tooltip.innerHTML = plotTooltipHtml(e.currentTarget);
    tooltip.style.display = 'block';
    movePlotTooltip(e);
  }

  function hidePlotTooltip(){
    const tooltip = qs('#plot-hover-tooltip');
    if (tooltip) tooltip.style.display = 'none';
  }

  function setPlotLabel(box){
    const plotNumber = basePlotLabel(box);
    box.textContent = box.dataset.fillerAccession ? `${plotNumber}\nF` : plotNumber;
    box.title = box.dataset.fillerAccession
      ? `Plot ${plotNumber}; accession: ${box.dataset.fillerAccession}; type: Filler`
      : `Plot ${plotNumber}; accession: ${box.dataset.accessionName || 'Not available'}; type: ${plotTypeLabel(box)}`;
  }

  function applyPlotVisual(box, baseColour){
    const keep = ['trial-box'];
    if (box.classList.contains('filler-applied')) keep.push('filler-applied');
    box.className = keep.join(' ');

    if (box.dataset.fillerAccession) {
      box.classList.add('filler-applied');
      setPlotLabel(box);
      return;
    }

    if (box.dataset.isControl === '1') {
      box.classList.add('bg-blue-900', 'text-white', 'bg-opacity-100');
    } else {
      const block = parseInt(box.dataset.block, 10) || 1;
      box.classList.add(block % 2 === 0 ? lighterColor(baseColour) : baseColour, 'bg-opacity-60');
    }
    setPlotLabel(box);
  }

  function paintCell(cell){
    if (!cell || !cell.dataset.row) return;

    const r = +cell.dataset.row;
    const c = +cell.dataset.col;
    const k = key(r, c);
    const isUnused = cellIsUnused(r, c);
    const isBorder = manualBorders.has(k);
    const filler = fillerPlots.get(k);
    const border = borderPlots.get(k);

    cell.classList.toggle('border-plot', isBorder);
    cell.classList.toggle('filler-plot', !!filler);
    cell.style.backgroundColor = filler ? '#fef3c7' : (isUnused ? '#d1d5db' : '#ffffff');
    cell.style.color = isBorder ? '#065f46' : (filler ? '#78350f' : '');
    cell.textContent = filler ? 'F' : (isBorder ? 'B' : '');
    cell.title = filler ? `Filler: ${filler.accession}` : (isBorder && border?.accession ? `Border: ${border.accession}` : '');
  }

  function disablePal(t){ const p = qs(`#palette${t}`); if(p){ p.style.opacity='0.3'; p.draggable=false; p.classList.add('cursor-not-allowed'); } }
  function enablePal(t){ const p = qs(`#palette${t}`); if(p){ p.style.opacity='1';  p.draggable=true;  p.classList.remove('cursor-not-allowed'); } }

  /******** Zoom Slider ********/
  qs('#zoom-slider')?.addEventListener('input', function (e) {
    const scale = parseFloat(e.target.value);
    const container = qs('#field-zoom-container');
    if (container) container.style.transform = `scale(${scale})`;
  });

  /******** Export View as JPG ********/
  qs('#export-jpg-btn')?.addEventListener('click', function () {
    const target = qs('#farm-scroll');
    html2canvas(target, {
      backgroundColor: '#ffffff',
      scale: 2
    }).then(canvas => {
      const link = document.createElement('a');
      link.download = 'location_field_grid.jpg';
      link.href = canvas.toDataURL('image/jpeg');
      link.click();
    });
  });

  /******** Export Full grid ********/
  qs('#export-full-jpg-btn')?.addEventListener('click', function () {
    const scrollContainer = qs('#farm-scroll');
    const zoomContainer = qs('#field-zoom-container');

    if (!scrollContainer || !zoomContainer) return;

    const originalOverflow = scrollContainer.style.overflow;
    const originalHeight = scrollContainer.style.maxHeight;
    const originalWidth = zoomContainer.style.width;
    const originalHeightZoom = zoomContainer.style.height;

    const fullWidth = zoomContainer.scrollWidth;
    const fullHeight = zoomContainer.scrollHeight;

    scrollContainer.style.overflow = 'visible';
    scrollContainer.style.maxHeight = 'none';
    zoomContainer.style.width = `${fullWidth}px`;
    zoomContainer.style.height = `${fullHeight}px`;

    html2canvas(zoomContainer, {
      backgroundColor: '#ffffff',
      scale: 2
    }).then(canvas => {
      scrollContainer.style.overflow = originalOverflow;
      scrollContainer.style.maxHeight = originalHeight;
      zoomContainer.style.width = originalWidth;
      zoomContainer.style.height = originalHeightZoom;

      const link = document.createElement('a');
      link.download = 'location_field_grid_full.jpg';
      link.href = canvas.toDataURL('image/jpeg');
      link.click();
    });
  });

  function xmlEscape(value) {
    return String(value ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  function excelColumnName(index) {
    let name = '';
    let n = index + 1;
    while (n > 0) {
      const rem = (n - 1) % 26;
      name = String.fromCharCode(65 + rem) + name;
      n = Math.floor((n - 1) / 26);
    }
    return name;
  }

  function xlsxCell(value, rowIndex, colIndex) {
    const ref = `${excelColumnName(colIndex)}${rowIndex}`;
    const isNumeric = value !== '' && value !== null && value !== undefined && !Number.isNaN(Number(value));
    if (isNumeric) return `<c r="${ref}"><v>${Number(value)}</v></c>`;
    return `<c r="${ref}" t="inlineStr"><is><t>${xmlEscape(value)}</t></is></c>`;
  }

  function xlsxSheetXml(headers, rows) {
    const allRows = [Object.fromEntries(headers.map(header => [header, header])), ...rows];
    const sheetRows = allRows.map((row, rowIndex) => {
      const excelRow = rowIndex + 1;
      return `<row r="${excelRow}">${headers.map((header, colIndex) => xlsxCell(row[header] ?? '', excelRow, colIndex)).join('')}</row>`;
    }).join('');
    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>${sheetRows}</sheetData>
</worksheet>`;
  }

  function cleanSheetName(name) {
    return String(name || 'Sheet').replace(/[\[\]:*?/\\]/g, '_').slice(0, 31);
  }

  function downloadExcelWorkbook(filename, sheets) {
    if (!window.JSZip) {
      alert('The XLSX export library is not available on this page.');
      return;
    }

    const zip = new JSZip();
    const worksheetEntries = sheets.map((sheet, index) => ({
      id: index + 1,
      name: cleanSheetName(sheet.name),
      headers: sheet.headers,
      rows: sheet.rows
    }));

    zip.file('[Content_Types].xml', `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
${worksheetEntries.map(sheet => `  <Override PartName="/xl/worksheets/sheet${sheet.id}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join('\n')}
</Types>`);
    zip.folder('_rels').file('.rels', `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>`);

    const xl = zip.folder('xl');
    xl.file('workbook.xml', `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
${worksheetEntries.map(sheet => `    <sheet name="${xmlEscape(sheet.name)}" sheetId="${sheet.id}" r:id="rId${sheet.id}"/>`).join('\n')}
  </sheets>
</workbook>`);
    xl.folder('_rels').file('workbook.xml.rels', `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${worksheetEntries.map(sheet => `  <Relationship Id="rId${sheet.id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${sheet.id}.xml"/>`).join('\n')}
</Relationships>`);
    const worksheets = xl.folder('worksheets');
    worksheetEntries.forEach(sheet => {
      worksheets.file(`sheet${sheet.id}.xml`, xlsxSheetXml(sheet.headers, sheet.rows));
    });

    const finishDownload = blob => {
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = filename.replace(/\.xls$/i, '.xlsx');
      link.click();
      URL.revokeObjectURL(link.href);
    };

    if (zip.generateAsync) {
      zip.generateAsync({
        type: 'blob',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      }).then(finishDownload);
    } else {
      finishDownload(zip.generate({
        type: 'blob',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      }));
    }
  }

  function plantingSettings() {
    return {
      rows_per_plot: qs('#planting-rows-per-plot')?.value || '',
      plants_per_plot: qs('#planting-plants-per-plot')?.value || '',
      plant_spacing: qs('#planting-plant-spacing')?.value || '',
      row_spacing: qs('#planting-row-spacing')?.value || '',
      alley_spacing: qs('#planting-alley-spacing')?.value || '',
      planting_direction: qs('#planting-direction')?.value || '',
      notes: qs('#planting-notes')?.value || ''
    };
  }

  function formByTrialIndex(layout) {
    return Object.fromEntries((layout.trial_forms || []).map(form => [form.trial_index, form]));
  }

  function trialNameForPlot(layout, trialIndex) {
    return formByTrialIndex(layout)[trialIndex]?.name || `Trial ${trialIndex}`;
  }

  function borderRowsForPlanting(layout, settings) {
    return (layout.manual_borders || []).map(border => ({
      planting_order: '',
      field_row: border.row,
      field_col: border.col,
      plot_type: 'border',
      trial_name: '',
      plot_number: '',
      plot_name: '',
      accession_name: border.accession || '',
      block_number: '',
      is_check: '',
      rows_per_plot: settings.rows_per_plot,
      plants_per_plot: settings.plants_per_plot,
      plant_spacing: settings.plant_spacing,
      row_spacing: settings.row_spacing,
      alley_spacing: settings.alley_spacing,
      planting_notes: settings.notes
    }));
  }

  function fillerRowsForPlanting(layout, settings, occupiedKeys) {
    return (layout.filler_plots || [])
      .filter(filler => !occupiedKeys.has(key((+filler.row || 1) - 1, (+filler.col || 1) - 1)))
      .map(filler => ({
        planting_order: '',
        field_row: filler.row,
        field_col: filler.col,
        plot_type: 'filler',
        trial_name: '',
        plot_number: '',
        plot_name: '',
        accession_name: filler.accession || '',
        block_number: '',
        is_check: '',
        rows_per_plot: settings.rows_per_plot,
        plants_per_plot: settings.plants_per_plot,
        plant_spacing: settings.plant_spacing,
        row_spacing: settings.row_spacing,
        alley_spacing: settings.alley_spacing,
        planting_notes: settings.notes
      }));
  }

  function plantingSort(rows, direction) {
    const rowAsc = (a, b) => (+a.field_row - +b.field_row) || (+a.field_col - +b.field_col);
    const rowDesc = (a, b) => (+a.field_row - +b.field_row) || (+b.field_col - +a.field_col);
    const colAsc = (a, b) => (+a.field_col - +b.field_col) || (+a.field_row - +b.field_row);

    rows.sort((a, b) => {
      if (direction === 'row_col_reverse') return rowDesc(a, b);
      if (direction === 'col_row') return colAsc(a, b);
      if (direction === 'serpentine') {
        const rowDiff = +a.field_row - +b.field_row;
        if (rowDiff) return rowDiff;
        return (+a.field_row % 2 === 1) ? (+a.field_col - +b.field_col) : (+b.field_col - +a.field_col);
      }
      return rowAsc(a, b);
    });

    rows.forEach((row, index) => {
      row.planting_order = index + 1;
    });
    return rows;
  }

  function collectPlantingMapRows(layout, settings) {
    const forms = formByTrialIndex(layout);
    const occupiedKeys = new Set();
    const rows = [];

    (layout.placed_trials || []).forEach(trial => {
      const form = forms[trial.trial_index] || {};
      const trialName = sanitizeTrialName(form.name) || `Trial_${trial.trial_index}`;
      (trial.plots || []).forEach(plot => {
        occupiedKeys.add(key((+plot.row || 1) - 1, (+plot.col || 1) - 1));
        rows.push({
          planting_order: '',
          field_row: plot.row,
          field_col: plot.col,
          plot_type: plot.filler_accession ? 'filler' : (String(plot.is_control) === '1' ? 'check' : 'test'),
          trial_name: trialName,
          plot_number: plot.plot_number || plot.original_plot_number || '',
          plot_name: `${trialName}_PLOT_${plot.plot_number || plot.original_plot_number || ''}`,
          accession_name: plot.filler_accession || plot.accession_name || '',
          block_number: plot.block || '',
          is_check: plot.filler_accession ? 0 : (String(plot.is_control) === '1' ? 1 : 0),
          rows_per_plot: settings.rows_per_plot,
          plants_per_plot: settings.plants_per_plot,
          plant_spacing: settings.plant_spacing,
          row_spacing: settings.row_spacing,
          alley_spacing: settings.alley_spacing,
          planting_notes: settings.notes
        });
      });
    });

    rows.push(...borderRowsForPlanting(layout, settings));
    rows.push(...fillerRowsForPlanting(layout, settings, occupiedKeys));
    return plantingSort(rows, settings.planting_direction);
  }

  function downloadPlantingMap() {
    const layout = collectLayoutJson();
    const settings = plantingSettings();
    const rows = collectPlantingMapRows(layout, settings);

    if (!rows.length) {
      alert('Place trials, borders, or fillers before downloading the planting map.');
      return;
    }

    const plotHeaders = [
      'planting_order', 'field_row', 'field_col', 'plot_type', 'trial_name',
      'plot_number', 'plot_name', 'accession_name', 'block_number', 'is_check',
      'rows_per_plot', 'plants_per_plot', 'plant_spacing', 'row_spacing',
      'alley_spacing', 'planting_notes'
    ];
    const settingsRows = [
      { setting: 'location', value: layout.farm.name },
      { setting: 'year', value: layout.year },
      { setting: 'season', value: layout.season },
      { setting: 'breeding_program', value: layout.breeding_program.name },
      { setting: 'field_rows', value: layout.field.rows },
      { setting: 'field_cols', value: layout.field.cols },
      { setting: 'plot_width', value: layout.field.plot_width },
      { setting: 'plot_length', value: layout.field.plot_length },
      { setting: 'planting_direction', value: settings.planting_direction }
    ];
    const filenameParts = ['planting_map', layout.farm.name, layout.year, layout.season].filter(Boolean);
    const filename = `${filenameParts.join('_').replace(/[^\w.-]+/g, '_') || 'planting_map'}.xlsx`;

    downloadExcelWorkbook(filename, [
      { name: 'Planting_Map', headers: plotHeaders, rows },
      { name: 'Settings', headers: ['setting', 'value'], rows: settingsRows }
    ]);
  }

  qs('#download-planting-map-btn')?.addEventListener('click', downloadPlantingMap);

  





  /******** grid ********/

  /***************************************************************
   *  Virtual-grid renderer  (50 x 50 cell window, cell pool reuse)
   ***************************************************************/
  const VISIBLE_ROWS = 50, VISIBLE_COLS = 50;

  /* DOM scaffolding ------------------------------------------------ */
  const grid     = document.getElementById('farm-grid');
  const viewport = document.createElement('div');
  viewport.id = 'virtual-viewport';
  viewport.style.position      = 'absolute';
  viewport.style.pointerEvents = 'auto';
  viewport.style.zIndex        = '5';
  grid.appendChild(viewport);

  /* State ---------------------------------------------------------- */
  let totalRows = 0, totalCols = 0;
  let lastRow   = 0, lastCol   = 0;

  function maxStartRow() {
    return Math.max(0, totalRows - VISIBLE_ROWS);
  }

  function maxStartCol() {
    return Math.max(0, totalCols - VISIBLE_COLS);
  }

  function clampScrollStart(row, col) {
    return {
      row: Math.max(0, Math.min(row, maxStartRow())),
      col: Math.max(0, Math.min(col, maxStartCol()))
    };
  }

  function syncScrollerSize() {
    const scroller = grid.querySelector('.fake-scroller');
    if (!scroller) return;

    scroller.style.width = `${maxStartCol() * STEP + grid.clientWidth}px`;
    scroller.style.height = `${maxStartRow() * STEP + grid.clientHeight}px`;
  }

  /* One-time cell pool -------------------------------------------- */
  const cellPool = [];
  (function buildPool () {
    const frag = document.createDocumentFragment();
    for (let i = 0; i < VISIBLE_ROWS * VISIBLE_COLS; i++) {
      const d  = document.createElement('div');
      d.className = 'grid-cell border';
      d.style.position = 'absolute';
      d.style.width  = `${CELL}px`;
      d.style.height = `${CELL}px`;
      d.addEventListener('click', handleCellClick);
      d.addEventListener('mouseenter', () => {
        if (activeTool()) d.classList.add('hover-preview');
      });
      d.addEventListener('mouseleave', () => d.classList.remove('hover-preview'));
      frag.appendChild(d);
      cellPool.push(d);
    }
    viewport.appendChild(frag);
  })();

  /* row / column label pools */
  const rowLabelContainer = document.createElement('div');
  rowLabelContainer.style.position      = 'absolute';
  rowLabelContainer.style.left = '0';            
  rowLabelContainer.style.top  = `${STEP}px`;    
  rowLabelContainer.style.pointerEvents = 'none';
  viewport.appendChild(rowLabelContainer);

  const colLabelContainer = document.createElement('div');
  colLabelContainer.style.position      = 'absolute';
  colLabelContainer.style.left = `${STEP}px`;    
  colLabelContainer.style.top  = '0';            
  colLabelContainer.style.pointerEvents = 'none';
  viewport.appendChild(colLabelContainer);

  /* pools the renderer can re-use */
  const rowLabelPool = [], colLabelPool = [];
  for (let i = 0; i < VISIBLE_ROWS; i++) {
    const d = document.createElement('div');
    d.className = 'bg-green-200 text-xs text-center leading-[40px]';
    d.style.position = 'absolute';
    d.style.width  = `${CELL}px`;
    d.style.height = `${CELL}px`;
    rowLabelContainer.appendChild(d);
    rowLabelPool.push(d);
  }
  for (let i = 0; i < VISIBLE_COLS; i++) {
    const d = document.createElement('div');
    d.className = 'bg-green-200 text-xs text-center leading-[40px]';
    d.style.position = 'absolute';
    d.style.width  = `${CELL}px`;
    d.style.height = `${CELL}px`;
    colLabelContainer.appendChild(d);
    colLabelPool.push(d);
  }


  /* Render current 50x50 window ----------------------------------- */
  function renderVisibleCells(startRow, startCol) {
    let idx = 0;

    /* rows */
    for (let r = 0; r < VISIBLE_ROWS; r++) {
      const gRow = r + startRow;            // global row index (0-based)

      /* row label (green bar at left) */
      const rl = rowLabelPool[r];
      rl.style.top       = `${r * STEP}px`;
      rl.textContent     = gRow < totalRows ? gRow + 1 : '';

      /* columns inside this visible row */
      for (let c = 0; c < VISIBLE_COLS; c++, idx++) {
        const gCol = c + startCol;          // global col index
        const cell = cellPool[idx];

        /* hide cells that are outside location bounds */
        if (gRow >= totalRows || gCol >= totalCols) {
          cell.style.display = 'none';
          continue;
        }

        cell.style.display = 'block';
        cell.style.left = `${(c + 1) * STEP}px`;
        cell.style.top  = `${(r + 1) * STEP}px`;

        /* cache row/col in data attrs for hit tests later */
        if (cell.dataset.row !== String(gRow)) cell.dataset.row = gRow;
        if (cell.dataset.col !== String(gCol)) cell.dataset.col = gCol;

        paintCell(cell);
      }
    }

    /* column labels (green bar on top) */
    for (let c = 0; c < VISIBLE_COLS; c++) {
      const gCol = c + startCol;
      const cl = colLabelPool[c];
      cl.style.left      = `${c * STEP}px`;
      cl.textContent     = gCol < totalCols ? gCol + 1 : '';
    }
  }



  /* Init / resize -------------------------------------------------- */
  function initVirtualGrid(rows, cols) {
    totalRows = rows;
    totalCols = cols;

    /* grid shell */
    grid.style.position = 'relative';
    grid.style.overflow = 'auto';
    grid.style.width  = `${VISIBLE_COLS * STEP}px`;
    grid.style.height = `${VISIBLE_ROWS * STEP}px`;
    grid.style.paddingLeft = `${STEP}px`;   
    grid.style.paddingTop  = `${STEP}px`;   

    /* fake scroller div */
    let scroller = grid.querySelector('.fake-scroller');
    if (!scroller) {
      scroller = document.createElement('div');
      scroller.className = 'fake-scroller';
      grid.appendChild(scroller);
    }
    syncScrollerSize();

    /* first draw */
    viewport.style.transform = 'translate(0,0)';
    renderVisibleCells(0, 0);
    lastRow = lastCol = 0;
  }

  /* Scroll handler (rAF throttled) -------------------------------- */
  let needsPaint = false;
  grid.addEventListener('scroll', () => {
    if (needsPaint) return;
    needsPaint = true;
    requestAnimationFrame(() => {
      const rawCol = Math.floor(grid.scrollLeft / STEP);
      const rawRow = Math.floor(grid.scrollTop  / STEP);
      const clamped = clampScrollStart(rawRow, rawCol);
      const newRow = clamped.row;
      const newCol = clamped.col;

      if (rawRow !== newRow) grid.scrollTop = newRow * STEP;
      if (rawCol !== newCol) grid.scrollLeft = newCol * STEP;

      if (newRow !== lastRow || newCol !== lastCol) {
        renderVisibleCells(newRow, newCol);
        viewport.style.transform =
          `translate(${newCol * STEP}px, ${newRow * STEP}px)`;
        rowLabelContainer.style.transform = `translateY(${newRow * STEP}px)`;
        colLabelContainer.style.transform = `translateX(${newCol * STEP}px)`;
        lastRow = newRow;
        lastCol = newCol;
      }
      needsPaint = false;
    });
  }, { passive: true });


  let gridInitialised = false;

  /* keep these in module scope so we can compare */
  let prevRows = 0, prevCols = 0;

  function drawGrid () {
    /* 1. current values from the UI */
    const rows = +qs('#farm-rows')?.value || 0;
    const cols = +qs('#farm-cols')?.value || 0;

    /* first run? build everything */
    if (!gridInitialised) {
      initVirtualGrid(rows, cols);
      gridInitialised   = true;
      prevRows = rows;  prevCols = cols;
      gridReady = true;                 // for drag-&-drop logic
      return;
    }

    /* dimensions unchanged: just repaint window */
    if (rows === prevRows && cols === prevCols) {
      /* keep scroll position; only redraw visible cells */
      renderVisibleCells(lastRow, lastCol);
      return;
    }

    /* only scroller size changes: quick resize */
    totalRows = rows;
    totalCols = cols;

    /* update fake scroller div */
    syncScrollerSize();

    /* if user shrank the grid and current scroll is out-of-bounds,
       bring it back into range */
    const maxLeft = maxStartCol() * STEP;
    const maxTop  = maxStartRow() * STEP;
    if (grid.scrollLeft > maxLeft) grid.scrollLeft = maxLeft;
    if (grid.scrollTop  > maxTop)  grid.scrollTop  = maxTop;

    /* repaint visible area */
    const clamped = clampScrollStart(
      Math.floor(grid.scrollTop / STEP),
      Math.floor(grid.scrollLeft / STEP)
    );
    const newRow = clamped.row;
    const newCol = clamped.col;
    renderVisibleCells(newRow, newCol);
    viewport.style.transform =
      `translate(${newCol * STEP}px, ${newRow * STEP}px)`;

    /* remember for next call */
    prevRows = rows;
    prevCols = cols;
  }

  /* hook UI controls back to the optimised drawGrid() */
  qs('#farm-rows')?.addEventListener('change', drawGrid);
  qs('#farm-cols')?.addEventListener('change', drawGrid);

  /* first paint on page load */
  window.addEventListener('load', drawGrid);



  function createCell(r, c) {
    const cell = document.createElement('div');
    cell.className = 'grid-cell border';
    cell.dataset.row = r;
    cell.dataset.col = c;

    const k = key(r, c);
    const isUnused = cellIsUnused(r, c);
    const isBorder = manualBorders.has(k);

    cell.style.background = isUnused ? '#d1d5db' : '#ffffff';
    cell.textContent = isBorder ? 'B' : '';
    if (isBorder) cell.classList.add('border-plot');

    cell.onclick = toggleCell;
    cell.addEventListener('mouseenter', () => {
      if (qs('#edit-toggle').checked || qs('#border-toggle').checked) cell.classList.add('hover-preview');
    });
    cell.addEventListener('mouseleave', () => cell.classList.remove('hover-preview'));

    return cell;
  }

  function toggleCell(e) {
    handleCellClick(e);
  }

  function handleCellClick(e) {
    if (suppressCellClick) {
      suppressCellClick = false;
      return;
    }

    const cell = e.target.closest('.grid-cell');
    if (!cell || !cell.dataset.row) return;
    const r = +cell.dataset.row;
    const c = +cell.dataset.col;
    const k = key(r, c);

    const tool = activeTool();

    if (!tool) return;

    if (tool === 'unused') {
      if (isCellOccupied(r, c) || manualBorders.has(k)) {
        alert('This plot already contains a trial, filler, or border.');
        return;
      }
      if (cellIsUnused(r, c)) {
        manualBlock.delete(k);
        manualAllow.add(k);
      } else {
        manualAllow.delete(k);
        manualBlock.add(k);
      }
    }

    if (tool === 'border') {
      if (!manualBorders.has(k) && isCellOccupied(r, c)) {
        alert('Borders cannot be placed on trial or filler plots.');
        return;
      }
      if (manualBorders.has(k)) {
        manualBorders.delete(k);
        borderPlots.delete(k);
      } else {
        manualBorders.add(k);
        borderPlots.set(k, { accession: currentBorderAccession() });
      }
    }

    if (tool === 'filler') {
      alert('Select a trial plot to place a filler inside the trial.');
      return;
    }

    paintCell(cell);
  }

  function applyGridBrush(cell, forceOn = null){
    if (!cell || !cell.dataset.row) return false;

    const r = +cell.dataset.row;
    const c = +cell.dataset.col;
    const k = key(r, c);
    const tool = activeTool();

    if (tool === 'unused') {
      if (isCellOccupied(r, c) || manualBorders.has(k)) return false;
      const makeUnused = forceOn === null ? !cellIsUnused(r, c) : forceOn;
      if (makeUnused) {
        manualAllow.delete(k);
        manualBlock.add(k);
      } else {
        manualBlock.delete(k);
        manualAllow.add(k);
      }
      paintCell(cell);
      return true;
    }

    if (tool === 'border') {
      if (isCellOccupied(r, c) || cellIsUnused(r, c)) return false;
      const makeBorder = forceOn === null ? !manualBorders.has(k) : forceOn;
      if (makeBorder) {
        manualBorders.add(k);
        borderPlots.set(k, { accession: currentBorderAccession() });
      } else {
        manualBorders.delete(k);
        borderPlots.delete(k);
      }
      paintCell(cell);
      return true;
    }

    return false;
  }


  /******** trial forms ********/
  function addTrialForm(i, selectedListId = null) {
    const d = document.createElement('div');
    d.className = 'border rounded p-4 mb-4 bg-gray-100';
    d.innerHTML = `
      <h4 class='font-semibold mb-2'>Trial ${i}</h4>
      <label class='block mb-2'>Name
        <input id='tname${i}' class='w-full border rounded px-2 py-1' />
      </label>

      <label class='block mb-4'>Description
        <textarea id='tdesc${i}' class='w-full border rounded px-2 py-1' rows='2'></textarea>
      </label>

      <div class='grid grid-cols-2 gap-4 mb-4'>
        <label>Trial Type
          <select id='ttype${i}' class='w-full border rounded px-2 py-1'>
            <option value="">Loading...</option>
          </select>
        </label>
        <label>Trial Design
          <select id='tdesign${i}' class='w-full border rounded px-2 py-1'>
            <option value="">Loading...</option>
          </select>
        </label>
      </div>

      <div class='mb-4'>
        <label>Layout Type
          <select id='tlayout${i}' class='w-full border rounded px-2 py-1'>
            <option value="serpentine">Serpentine</option>
            <option value="cartesian">Cartesian</option>
          </select>
        </label>
      </div>

      <div class='grid grid-cols-2 gap-4 mb-4'>
        <label>Start Plot Number
          <input id='tstartplot${i}' type='number' min='1' value='1' class='w-full border rounded px-2 py-1' />
        </label>
        <label>Plot Numbering
          <select id='tplotnumbering${i}' class='w-full border rounded px-2 py-1'>
            <option value="continuous">Continuous across blocks</option>
            <option value="block_prefix">Start with block number</option>
          </select>
        </label>
      </div>

      <div class='grid grid-cols-2 gap-4 mb-4'>
        <label>Treatments List
          <select id='ttreatments${i}' class='w-full border rounded px-2 py-1'>
            <option value="">Loading...</option>
          </select>
        </label>
        <label>Controls List
          <select id='tcontrols${i}' class='w-full border rounded px-2 py-1'>
            <option value="">-- Select a list --</option>
          </select>
        </label>
      </div>

      <div id='repsblocks-container${i}' class='grid grid-cols-2 gap-4 mb-4'>
        <label>Reps
          <input id='treps${i}' type='number' min='1' class='w-full border rounded px-2 py-1' />
        </label>
        <label>Blocks
          <input id='tblocks${i}' type='number' min='1' class='w-full border rounded px-2 py-1' />
        </label>
      </div>

      <div id='rowcol-container${i}' class='grid grid-cols-2 gap-4'>
        <label>Rows
          <input id='trows${i}' type='number' value='1' min='1' class='w-full border rounded px-2 py-1' />
        </label>
        <label>Cols
          <input id='tcols${i}' type='number' value='1' min='1' class='w-full border rounded px-2 py-1' />
        </label>
      </div>

      <div class='mt-4 text-right'>
        <button onclick='generateDesign(${i}, 0, 0, this)' class='px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700'>
          Generate Design
        </button>
      </div>
    `;

    qs('#trial-details').appendChild(d);
    loadGlobalFarmDropdown();
    populateTrialMetadataSelects(d);

    // Design-specific toggles
    const designSelect = d.querySelector(`#tdesign${i}`);
    const rowcol       = d.querySelector(`#rowcol-container${i}`);
    const repsblocks   = d.querySelector(`#repsblocks-container${i}`);

    designSelect.addEventListener('change', () => {
      const val        = designSelect.value;
      const isRCBD     = val === 'RCBD';
      const isAugRC    = designIsAugmentedRowColumn(val);

      /* REPS / BLOCKS PANEL */
      if (isRCBD) {
        repsblocks.innerHTML = `
          <label>Reps / Blocks
            <input id='trepsblocks${i}' type='number' min='1' value='1'
                   class='w-full border rounded px-2 py-1' />
          </label>
          <div></div>`;
      } else if (isAugRC) {
        // Augmented row-column: super-rows & super-cols replace reps/blocks
        repsblocks.innerHTML = '';          // nothing needed here
      } else {
        // all other designs (Row-Column, DRRC, etc.)
        repsblocks.innerHTML = `
          <label>Reps
            <input id='treps${i}' type='number' min='1'
                   class='w-full border rounded px-2 py-1' />
          </label>
          <label>Blocks
            <input id='tblocks${i}' type='number' min='1'
                   class='w-full border rounded px-2 py-1' />
          </label>`;
      }

      /* ROW / COL PANEL */
      if (isRCBD) {
        rowcol.innerHTML = `
          <label>Number of Rows per Block
            <input id='tblockrows${i}' type='number' min='1' value='1'
                   class='w-full border rounded px-2 py-1' />
          </label>
          <div></div>`;
      } else if (isAugRC) {
        // four inputs: super-rows, super-cols, rows, cols
        rowcol.innerHTML = `
          <label>Rows per block  
            <input id='tblockrows${i}' type='number' min='1'
                   class='w-full border rounded px-2 py-1' />
          </label>
          <label>Cols per block
            <input id='tblockcols${i}' type='number' min='1'
                   class='w-full border rounded px-2 py-1' />
          </label>
          <label>Total rows in trial
            <input id='tsuperrows${i}' type='number' min='1'
                   class='w-full border rounded px-2 py-1' />
          </label>
          <label>Total cols in trial
            <input id='tsupercols${i}' type='number' min='1'
                   class='w-full border rounded px-2 py-1' />
          </label>`;
      } else {
        // default two-input panel
        rowcol.innerHTML = `
          <label>Rows
            <input id='trows${i}' type='number' min='1'
                   class='w-full border rounded px-2 py-1' />
          </label>
          <label>Cols
            <input id='tcols${i}' type='number' min='1'
                   class='w-full border rounded px-2 py-1' />
          </label>`;
      }
    });


    // Load dropdown lists
    loadTreatmentsList(i, null, function (selectedTreatmentListId) {
      loadControlsList(i, selectedTreatmentListId);
    });

  }

  function loadGlobalFarmDropdown() {
    const $select = $('#farm_dropdown');

    // Show loading state
    $select.html('<option value="">Loading...</option>');

    $.ajax({
      url: '/ajax/trialallocation/farms',
      method: 'GET',
      dataType: 'json',
      success: function(data) {
        if (!data.success || !Array.isArray(data.farms)) {
          $select.html('<option value="">Failed to load locations</option>');
          return;
        }

        // Populate dropdown
        $select.empty().append('<option value="">-- Select Location --</option>');
        data.farms.forEach(loc => {
          $select.append(`<option value="${loc.location_id}">${loc.name}</option>`);
        });

        // Initialize Select2 *after* data is populated
        $select.select2({
          placeholder: 'Select or type a location',
          allowClear: true,
          width: '100%',
          dropdownParent: $('#farm_dropdown').closest('div')
        });
      },
      error: function(xhr, status, error) {
        console.error('Failed to load global location list:', error);
        $select.html('<option value="">Failed to load</option>');
      }
    });
  }

  function loadBreedingProgramDropdown() {
    const $select = $('#breeding_program_dropdown');
    if ($select.length === 0) return;

    $select.html('<option value="">Loading...</option>');

    $.ajax({
      url: '/ajax/trialallocation/breeding_programs',
      method: 'GET',
      dataType: 'json',
      success: function(data) {
        if (!data.success || !Array.isArray(data.programs)) {
          $select.html('<option value="">Failed to load programs</option>');
          return;
        }

        $select.empty().append('<option value="">-- Select Breeding Program --</option>');
        data.programs.forEach(program => {
          $select.append(`<option value="${program.program_id}">${program.name}</option>`);
        });

        $select.select2({
          placeholder: 'Select a breeding program',
          allowClear: true,
          width: '100%',
          dropdownParent: $('#breeding_program_dropdown').closest('div')
        });
      },
      error: function(xhr, status, error) {
        console.error('Failed to load breeding programs:', error);
        $select.html('<option value="">Failed to load</option>');
      }
    });
  }

  function loadSeasonDropdown() {
    const select = qs('#layout-season');
    if (!select) return;

    const selected = select.value;
    select.innerHTML = '<option value="">Loading...</option>';

    $.ajax({
      url: '/ajax/trialallocation/seasons',
      method: 'GET',
      dataType: 'json',
      success: function(data) {
        select.innerHTML = '<option value="">Select Season</option>';
        const seasons = data.success && Array.isArray(data.seasons) ? data.seasons : [];
        seasons.forEach(season => {
          select.appendChild(new Option(season, season));
        });
        if (selected) select.value = selected;
        if (layoutContextLocked) lockControl('layout-season', true);
      },
      error: function(_, __, error) {
        console.error('Failed to load seasons:', error);
        select.innerHTML = '<option value="">Select Season</option>';
        ['summer', 'winter'].forEach(season => select.appendChild(new Option(season, season)));
        if (selected) select.value = selected;
        if (layoutContextLocked) lockControl('layout-season', true);
      }
    });
  }

  function loadTrialTypes() {
    return $.ajax({
      url: '/ajax/trialallocation/trial_types',
      method: 'GET',
      dataType: 'json',
      success: function(data) {
        availableTrialTypes = data.success && Array.isArray(data.trial_types) ? data.trial_types : [];
        populateTrialMetadataSelects();
      },
      error: function(_, __, error) {
        console.error('Failed to load trial types:', error);
        availableTrialTypes = [];
        populateTrialMetadataSelects();
      }
    });
  }

  function loadTrialDesigns() {
    return $.ajax({
      url: '/ajax/trialallocation/trial_designs',
      method: 'GET',
      dataType: 'json',
      success: function(data) {
        availableTrialDesigns = data.success && Array.isArray(data.trial_designs) ? data.trial_designs : [];
        populateTrialMetadataSelects();
      },
      error: function(_, __, error) {
        console.error('Failed to load trial designs:', error);
        availableTrialDesigns = [];
        populateTrialMetadataSelects();
      }
    });
  }






  function addPaletteBox(i){
    const wrap = document.createElement('div');
    wrap.className = 'border rounded p-3 bg-white';

    const box = document.createElement('div');
    box.id = `palette${i}`;
    box.className = `trial-box ${colourFor(i)} bg-opacity-60 mb-2`;
    box.textContent = `Trial ${i}`;
    box.dataset.trial = i;
    box.draggable = true;
    box.ondragstart = startDrag;

    const controls = document.createElement('div');
    controls.className = 'grid grid-cols-2 gap-2 text-xs';
    controls.innerHTML = `
      <label>Horizontal
        <select id="grid-direction-horizontal${i}" class="w-full border rounded px-1 py-1">
          <option value="ltr">Left to right</option>
          <option value="rtl">Right to left</option>
        </select>
      </label>
      <label>Vertical
        <select id="grid-direction-vertical${i}" class="w-full border rounded px-1 py-1">
          <option value="ttb">Top to bottom</option>
          <option value="btt">Bottom to top</option>
        </select>
      </label>
    `;

    wrap.appendChild(box);
    wrap.appendChild(controls);
    qs('#trial-boxes').appendChild(wrap);

    // if(document.querySelector(`.trial-group[data-trial="${i}"]`)) disablePal(i);
    if (lockedTrialForms.has(i)) {
      disablePal(i);
    } else {
      disablePal(i);
    }
  }

  /******** getting lists **********/
  function loadTreatmentsList(i, selectedListId = null, onSelectedCallback = null) {
    const $select = $(`#ttreatments${i}`);
    if ($select.length === 0) return;

    const pendingValue = selectedListId || $select[0].dataset.pendingValue || lockedTrialForms.get(i)?.treatment_list_id || '';
    $select.html(`<option value="">Loading...</option>`);

    $.ajax({
      url: '/ajax/trialallocation/accession_lists',
      method: 'GET',
      dataType: 'json',
      success: function(data) {
        if (!data.success) {
          $select.html(`<option value="">Failed to load</option>`);
          alert("Could not load Treatments List");
          return;
        }

        $select.empty().append(`<option value="">-- Select a list --</option>`);

        data.lists.forEach(function(list) {
          const selected = (pendingValue && String(list.list_id) === String(pendingValue)) ? 'selected' : '';
          const label = `${list.name} (${list.is_public ? 'Public' : 'Private'})`;
          $select.append(`<option value="${list.list_id}" ${selected}>${label}</option>`);
        });

        //Attach change listener to trigger control refresh
        $select.off('change').on('change', function () {
          const selectedTreatmentsList = $(this).val();
          if (onSelectedCallback) {
            onSelectedCallback(selectedTreatmentsList);
          }
        });

        if ($select.data('select2')) $select.select2('destroy');
        $select.select2({
          placeholder: 'Select a treatment list',
          allowClear: true,
          width: '100%',
          dropdownParent: $select.closest('label')
        });
        if (pendingValue) {
          $select.val(String(pendingValue)).trigger('change');
        }

        // Optional: trigger callback if pre-selected
        if (pendingValue && onSelectedCallback && $select.val() !== String(pendingValue)) {
          onSelectedCallback(pendingValue);
        }
      },
      error: function(xhr, status, error) {
        console.error("Error loading Treatments List:", status, error);
        $select.html(`<option value="">Failed to load</option>`);
        alert("Error loading Treatments List.");
      }
    });
  }

  function loadControlsList(i, excludeListId = null) {
    const $select = $(`#tcontrols${i}`);
    if ($select.length === 0) return;

    const pendingValue = $select[0].dataset.pendingValue || lockedTrialForms.get(i)?.control_list_id || '';
    $select.html(`<option value="">Loading...</option>`);

    $.ajax({
      url: '/ajax/trialallocation/accession_lists',
      method: 'GET',
      dataType: 'json',
      success: function(data) {
        if (!data.success) {
          $select.html(`<option value="">Failed to load</option>`);
          alert("Could not load Controls List");
          return;
        }

        $select.empty().append(`<option value="">-- Select a list --</option>`);

        data.lists.forEach(function(list) {
          const label = `${list.name} (${list.is_public ? 'Public' : 'Private'})`;
          $select.append(`<option value="${list.list_id}">${label}</option>`);
        });

        if (pendingValue) {
          $select.val(String(pendingValue));
        }
        if ($select.data('select2')) $select.select2('destroy');
        $select.select2({
          placeholder: 'Select a controls list',
          allowClear: true,
          width: '100%',
          dropdownParent: $select.closest('label')
        });
        if (pendingValue) {
          $select.trigger('change');
        }
      },
      error: function(xhr, status, error) {
        console.error("Error loading Controls List:", status, error);
        $select.html(`<option value="">Failed to load</option>`);
        alert("Error loading Controls List.");
      }
    });
  }
  
  /******** Gereate trial Design *************/
  window.generateDesign = function(i, rowStart = 0, colStart = 0, btn) {
    const design  = $(`#tdesign${i}`).val();
    const layoutType = $(`#tlayout${i}`).val();
    const isRCBD  = design === 'RCBD';
    const isAugRC = designIsAugmentedRowColumn(design);

    if (btn && btn.textContent.includes('Re-Run')) {
      delete trialDesignCache[i];
      console.log(`Cache for trial ${i} cleared`);
    }

    const trial = {
      name:             $(`#tname${i}`).val(),
      description:      $(`#tdesc${i}`).val(),
      type:             $(`#ttype${i}`).val(),
      design:           design,
      treatment_list_id:$(`#ttreatments${i}`).val(),
      control_list_id:  $(`#tcontrols${i}`).val(),
      layout_type:      layoutType,
      horizontal_direction: $(`#grid-direction-horizontal${i}`).val(),
      vertical_direction:   $(`#grid-direction-vertical${i}`).val(),
      start_plot_number:    parseInt($(`#tstartplot${i}`).val()) || 1,
      plot_numbering:       $(`#tplotnumbering${i}`).val(),

      // reps / blocks logic
      reps: parseInt($(`#treps${i}`).val()) || 0,
      blocks: isRCBD ? (parseInt($(`#trepsblocks${i}`).val()) || 0) : (isAugRC ? 0 : parseInt($(`#tblocks${i}`).val())   || 0),

      // super-row / super-col only for AugRC
      rows_in_field: isAugRC ? parseInt($(`#tsuperrows${i}`).val()) || 0 : 0,
      cols_in_field: isAugRC ? parseInt($(`#tsupercols${i}`).val()) || 0 : 0,
      rows_per_block: isAugRC ? parseInt($(`#tblockrows${i}`).val()) || 0 : 0,
      cols_per_block: isAugRC ? parseInt($(`#tblockcols${i}`).val()) || 0 : 0,

      // rows / cols in the whole trial
      rows: isRCBD ? parseInt($(`#tblockrows${i}`).val()) || 0 : parseInt($(`#trows${i}`).val())      || 0,
      cols: parseInt($(`#tcols${i}`).val()) || 0       // same input for all designs
    };


    // Reset state before AJAX
    if (btn) {
      btn.classList.remove('bg-green-600', 'hover:bg-green-700', 'bg-red-600', 'hover:bg-red-700');
      btn.classList.add('bg-blue-600', 'hover:bg-blue-700');
      btn.textContent = 'Generating...';
    }

    return $.ajax({
      url: '/ajax/trialallocation/generate_design',
      method: 'POST',
      data: {
        trial: JSON.stringify(trial)
      }
    }).done(function(response) {
      if (btn) {
        btn.classList.remove('bg-blue-600', 'hover:bg-blue-700');
        btn.classList.add('bg-green-600', 'hover:bg-green-700');
        btn.textContent = 'Design Ready/Re-Run?';
        enablePal(i);
      }
      trialDesignCache[i] = {
          design_file: response.design_file,
          param_file: response.param_file,
          design: response.design,
          n_row: response.n_row,
          n_col: response.n_col
      }
    }).fail(function(err) {
      if (btn) {
        btn.classList.remove('bg-blue-600', 'hover:bg-blue-700');
        btn.classList.add('bg-red-600', 'hover:bg-red-700');
        btn.textContent = 'Error';
      }
      console.error('Design generation failed:', err);
    });
  };



  /******** drag & drop ********/
  function startDrag(e){
    const el = e.target.closest('.trial-group') || e.target;
    const fromPal = el.id.startsWith('palette');
    if (!fromPal && isLockedRoot(el.dataset.root)) {
      e.preventDefault();
      alert('This trial is part of a saved layout and cannot be moved.');
      return;
    }
    const rect = el.getBoundingClientRect();
    e.dataTransfer.setData('src', fromPal ? 'pal' : 'grid');
    e.dataTransfer.setData('tn', el.dataset.trial);
    if(!fromPal) {
      const root = el.dataset.root;
      const rootPart = qs(`.trial-group[data-root="${root}"]`);
      const anchorRow = +(rootPart?.dataset.anchorRow || el.dataset.row || 0);
      const anchorCol = +(rootPart?.dataset.anchorCol || el.dataset.col || 0);
      const gridRect = farmGridEl.getBoundingClientRect();
      const anchorLeft = gridRect.left - farmGridEl.scrollLeft + ((anchorCol + 1) * STEP);
      const anchorTop = gridRect.top - farmGridEl.scrollTop + ((anchorRow + 1) * STEP);

      e.dataTransfer.setData('root', root);
      e.dataTransfer.setData('offX', e.clientX - anchorLeft);
      e.dataTransfer.setData('offY', e.clientY - anchorTop);
      return;
    }

    e.dataTransfer.setData('offX', e.clientX - rect.left);
    e.dataTransfer.setData('offY', e.clientY - rect.top);
  }

  function handleDrop(e) {
    e.preventDefault();

    if (!gridReady) {
      alert('Grid is still loading. Please wait.');
      return;
    }

    const tn   = e.dataTransfer.getData('tn');
    const src  = e.dataTransfer.getData('src');
    const root = e.dataTransfer.getData('root');
    const offX = +e.dataTransfer.getData('offX');
    const offY = +e.dataTransfer.getData('offY');

    const rect = qs('#farm-grid').getBoundingClientRect();

    let col = Math.floor((e.clientX - rect.left + farmGridEl.scrollLeft - (src === 'grid' ? offX : 0)) / STEP) - 1;
    let row = Math.floor((e.clientY - rect.top  + farmGridEl.scrollTop  - (src === 'grid' ? offY : 0)) / STEP) - 1;

    if (col < 0 || row < 0) return;
    if (src === 'grid' && isLockedRoot(root)) {
      alert('This trial is part of a saved layout and cannot be moved.');
      return;
    }

    const name   = qs(`#tname${tn}`)?.value || `Trial ${tn}`;
    const colour = colourFor(tn);

    /* request design from server */
    const cached = trialDesignCache[tn];
    if (!cached) {
      alert("Please click 'Generate Design' before placing the trial.");
      return;
    }

    const rowsWanted = cached.n_row;
    const colsWanted = cached.n_col;
    const loading = qs('#grid-loader');
    if (loading) {
      loading.querySelector('span').textContent = 'Placing trial...';
      loading.classList.remove('hidden');
    }

    const coords = placeTrial({
      tn,
      name,
      rowsWanted,
      colsWanted,
      total: rowsWanted * colsWanted,
      rowStart: row,
      colStart: col,
      colour,
      rootId: src === 'grid' ? root : null,
      ignoreRoot: src === 'grid' ? root : null,
      design: cached.design
    });

    if (!coords || !coords.length) {
      if (loading) loading.classList.add('hidden');
      return;
    }

    // save coordinates
    $.ajax({
      url: '/ajax/trialallocation/save_coordinates',
      method: 'POST',
      data: {
        trial: JSON.stringify({
          trial_name: name,
          trial_id: tn,
          breeding_program_id: $('#breeding_program_dropdown').val(),
          coordinates: coords,
          design_file: cached.design_file,
          param_file: cached.param_file,
          r_output: cached.r_output
        })
      },
      success: function (saveResponse) {
        if (loading) loading.classList.add('hidden');
        if (saveResponse.success) {
          console.log(`Coordinates for "${name}" saved successfully.`);
          recolorTrialPlots(tn, cached.design_file, colour);
        } else {
          console.warn('Save failed: ' + saveResponse.error);
        }
      },
      error: function (xhr, status, error) {
        if (loading) loading.classList.add('hidden');
        console.error('Error saving coordinates:', error);
      }
    })
      .fail(function (xhr, status, error) {
        console.error('AJAX error:', error);
        alert('Error generating design.');
      });
  }

  
  function lighterColor(base) {
    // drop one Tailwind step (e.g. 400 to 200, 500 to 300, 900 to 700)
    return base.replace(/-(\d+)$/, (_, num) => {
      let n = Math.max(+num - 200, 50);
      return '-' + n;
    });
  }


  const farmGridEl = qs('#farm-grid');
  farmGridEl.addEventListener('dragover', e=>e.preventDefault());
  farmGridEl.addEventListener('drop', handleDrop);

  function selectTrial(root){
    if (isLockedRoot(root)) {
      selectedRoot = null;
      qsa('.trial-group').forEach(g => g.classList.remove('selected-trial'));
      return;
    }
    selectedRoot = root;
    qsa('.trial-group').forEach(g => {
      g.classList.toggle('selected-trial', !!root && g.dataset.root === root);
    });
  }

  function handleTrialPlotClick(e){
    if (activeTool() !== 'filler') return;
    e.preventDefault();
    e.stopPropagation();

    const box = e.currentTarget;
    const root = box.closest('.trial-group')?.dataset.root;
    if (isLockedRoot(root)) {
      alert('This trial is part of a saved layout and cannot be changed.');
      return;
    }
    const useStandard = qs('#standard-filler-toggle')?.checked;
    const standard = qs('#filler-accession')?.value.trim() || '';
    let accession = standard;

    if (!useStandard || !accession) {
      accession = window.prompt('Filler accession name', box.dataset.fillerAccession || standard || '');
      if (accession === null) return;
      accession = accession.trim();
    }

    if (!accession) {
      delete box.dataset.fillerAccession;
      box.classList.remove('filler-applied');
    } else {
      box.dataset.fillerAccession = accession;
      box.classList.add('filler-applied');
    }

    applyPlotVisual(box, colourFor(box.closest('.trial-group')?.dataset.trial || 1));
  }

  function rootCells(root){
    const cells = [];
    qsa(`.trial-group[data-root="${root}"]`).forEach(group => {
      const gr = +group.dataset.row;
      const gc = +group.dataset.col;
      group.querySelectorAll('.trial-box').forEach((box, i) => {
        if (box.classList.contains('filler-box')) return;
        const row = Number(box.dataset.row);
        const col = Number(box.dataset.col);
        cells.push({
          row: Number.isNaN(row) ? gr : row,
          col: Number.isNaN(col) ? gc + i : col
        });
      });
    });
    return cells;
  }

  function canMoveRoot(root, dRow, dCol){
    const parts = qsa(`.trial-group[data-root="${root}"]`);
    if (!parts.length) return false;

    const startRow = +(parts[0].dataset.anchorRow || Math.min(...parts.map(g => +g.dataset.row))) + dRow;
    const startCol = +(parts[0].dataset.anchorCol || Math.min(...parts.map(g => +g.dataset.col))) + dCol;

    return startRow >= 0 && startCol >= 0;
  }

  function moveSelectedTrial(dRow, dCol){
    if (!selectedRoot || isLockedRoot(selectedRoot) || !canMoveRoot(selectedRoot, dRow, dCol)) return false;

    const parts = qsa(`.trial-group[data-root="${selectedRoot}"]`);
    if (!parts.length) return false;

    const first = parts[0];
    const tn = first.dataset.trial;
    const name = qs(`#tname${tn}`)?.value || `Trial ${tn}`;
    const startRow = +(first.dataset.anchorRow || Math.min(...parts.map(g => +g.dataset.row))) + dRow;
    const startCol = +(first.dataset.anchorCol || Math.min(...parts.map(g => +g.dataset.col))) + dCol;
    const boxes = parts
      .flatMap(part => [...part.querySelectorAll('.trial-box')])
      .sort((a, b) => (+a.dataset.designIndex - +b.dataset.designIndex));

    const plotDesign = boxes.map(box => ({
      plot_number: box.dataset.plotNumber,
      block: box.dataset.block,
      accession_name: box.dataset.accessionName,
      is_control: box.dataset.isControl,
      original_plot_number: box.dataset.originalPlotNumber || box.dataset.plotNumber
    }));

    const coords = placeTrial({
      tn,
      name,
      rowsWanted: +first.dataset.rowsWanted || Math.max(...parts.map(groupHeight)),
      colsWanted: +first.dataset.colsWanted || boxes.length,
      total: boxes.length,
      rowStart: startRow,
      colStart: startCol,
      colour: colourFor(tn),
      rootId: selectedRoot,
      ignoreRoot: selectedRoot,
      design: plotDesign
    });

    return !!(coords && coords.length);
  }

  document.addEventListener('keydown', e => {
    if (!selectedRoot || ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;

    const jump = e.shiftKey ? 5 : 1;
    const delta = {
      ArrowUp:    [-jump, 0],
      ArrowDown:  [ jump, 0],
      ArrowLeft:  [0, -jump],
      ArrowRight: [0,  jump]
    }[e.key];

    if (!delta) return;
    e.preventDefault();
    moveSelectedTrial(delta[0], delta[1]);
  });

  /************* grab coodinates from grd ****************/

  function clearTrialCache(i) {
    delete trialDesignCache[i];
    alert(`Trial ${i} design cache cleared.`);
  }

  function getTrialCoordinates(trialName) {
    const coords = [];

    document.querySelectorAll(`.trial-cell[data-trial="${trialName}"]`).forEach(cell => {
      const row = parseInt(cell.dataset.row);
      const col = parseInt(cell.dataset.col);
      coords.push({ row, col });
    });

    return coords;
  }



  /******** placement helpers (unchanged logic, syntax corrected) ********/
  function checkBordersInRegion(rowStart,colStart,rowsWanted,colsWanted){
    for(let r=rowStart;r<rowStart+rowsWanted;r++){
      for(let c=colStart;c<colStart+colsWanted;c++){
        if(manualBorders.has(key(r,c))) return true;
      }
    }
    return false;
  }

  function trialCellExists(r,c){
    if (fillerPlots.has(key(r, c))) return true;
    return [...document.querySelectorAll('.trial-group')].some(group=>{
      const gr = +group.dataset.row;
      const gc = +group.dataset.col;
      const cols = groupWidth(group);
      const rows = groupHeight(group);
      return (r>=gr && r<gr+rows) && (c>=gc && c<gc+cols);
    });
  }

  function willOverlapTrialRegion(rowStart,colStart,rowsWanted,colsWanted){
    const total = rowsWanted*colsWanted;
    let r=rowStart,c=colStart,count=0;
    while(count<total){
      if(!cellIsUnused(r,c)){
        const cellLeft = (c+1)*STEP;
        const cellTop  = (r+1)*STEP;
        const cellBox  = { left:cellLeft, top:cellTop, right:cellLeft+CELL, bottom:cellTop+CELL };
        const overlap = [...document.querySelectorAll('.trial-group')].some(group=>{
          const gLeft = parseFloat(group.style.left);
          const gTop  = parseFloat(group.style.top);
          const gRight= gLeft + parseFloat(group.style.width);
          const gBottom = gTop + parseFloat(group.style.height);
          return !(cellBox.right<=gLeft || cellBox.left>=gRight || cellBox.bottom<=gTop || cellBox.top>=gBottom);
        });
        if(overlap) return true;
      }
      count++; c++;
      if(c-colStart>=colsWanted){ c=colStart; r++; }
    }
    return false;
  }
  

  /******** Placing Trial ********/
  function placeTrial({
    tn, name,
    rowsWanted, colsWanted, total,
    rowStart, colStart,
    colour, rootId,
    ignoreRoot,
    design,                 // (not changed here)
    rowsPerBlock, blocks    // (not used here yet)
  }) {
    disablePal(tn);

    const root   = rootId || uid();
    const coords = [];
    const settings = trialLayoutSettings(tn);
    let plotDesign = designRows(design);
    const fillerByPlot = new Map();

    if (rootId) {
      qsa(`.trial-group[data-root="${rootId}"] .trial-box[data-filler-accession]`).forEach(box => {
        if (box.dataset.plotNumber) fillerByPlot.set(box.dataset.plotNumber, box.dataset.fillerAccession);
      });
    }

    while (plotDesign.length < total) {
      plotDesign.push({
        plot_number: plotDesign.length + 1,
        block: 1,
        is_control: 0,
        accession_name: ''
      });
    }

    if (rowStart < 0 || colStart < 0 || rowStart >= totalRows || colStart >= totalCols) {
      alert('Could not place trial: starting plot is outside the field.');
      return;
    }

    let rr = rowStart;
    let cc = colStart;
    let rowPlots = 0;
    let guard = 0;
    let blockingConflict = false;
    const maxChecks = Math.max(1, totalRows * totalCols);
    const rowStep = settings.verticalDir === 'btt' ? -1 : 1;
    const colInBounds = col => col >= 0 && col < totalCols;
    const rowInBounds = row => row >= 0 && row < totalRows;

    while (coords.length < total && guard < maxChecks && rowInBounds(rr)) {
      const k = key(rr, cc);

      if (colInBounds(cc)) {
        if (manualBorders.has(k) || fillerPlots.has(k) || isCellOccupied(rr, cc, ignoreRoot)) {
          blockingConflict = true;
          break;
        }

        if (!cellIsUnused(rr, cc)) {
          coords.push([rr, cc]);
          rowPlots++;
        }
      }

      cc++;
      if (rowPlots === colsWanted || !colInBounds(cc)) {
        rr += rowStep;
        cc = colStart;
        rowPlots = 0;
      }

      guard++;
    }

    if (blockingConflict) {
      alert('Could not place trial: the selected path contains another trial, border, or filler plot.');
      return;
    }

    if (coords.length < total) {
      alert('Could not place trial: not enough available plots from this starting position.');
      return;
    }

    if (rootId) {
      qsa(`.trial-group[data-root="${rootId}"]`).forEach(el => el.remove());
    }

    plotDesign = assignPlotNumbers(plotDesign, settings);
    const ordered = orderedCells(coords, colsWanted, settings);
    const designIndexByKey = new Map();
    ordered.forEach(([coordRow, coordCol], index) => {
      designIndexByKey.set(key(coordRow, coordCol), index);
    });

    /* group consecutive cells into segments so each visual row
       becomes a single `.trial-group` div for efficient DOM use  */
    const rowsMap = {};
    coords.forEach(([rr, cc]) => ((rowsMap[rr] = rowsMap[rr] || []).push(cc)));

    Object.entries(rowsMap).forEach(([rr, cols]) => {
      cols.sort((a, b) => a - b);
      let s = cols[0];
      for (let i = 1; i <= cols.length; i++) {
        if (i === cols.length || cols[i] !== cols[i - 1] + 1) {
          createSeg(+rr, s, cols[i - 1]);
          s = cols[i];
        }
      }
    });
    selectTrial(root);

    /* helper - draw one contiguous horizontal segment */
    function createSeg(rr, start, end) {
      const seg = end - start + 1;
      const g   = document.createElement('div');

      g.className     = 'trial-group';
      g.dataset.trial = tn;
      g.dataset.root  = root;
      g.dataset.row   = rr;
      g.dataset.col   = start;
      g.dataset.rowsWanted = rowsWanted;
      g.dataset.colsWanted = colsWanted;
      g.dataset.anchorRow = rowStart;
      g.dataset.anchorCol = colStart;

      g.style.left  = `${(start + 1) * STEP}px`;
      g.style.top   = `${(rr    + 1) * STEP}px`;
      g.style.width = `${seg * STEP - GAP}px`;
      g.style.height= `${CELL}px`;
      g.style.gridTemplateColumns = `repeat(${seg}, ${CELL}px)`;

      g.draggable    = true;
      g.ondragstart  = startDrag;
      g.tabIndex     = 0;
      g.addEventListener('click', e => {
        e.stopPropagation();
        selectTrial(root);
      });

      /* individual plot boxes */
      for (let i = 0; i < seg; i++) {
        const col = start + i;
        const designIndex = designIndexByKey.get(key(rr, col));
        const meta = plotDesign[designIndex] || {};
        const b = document.createElement('div');
        b.className    = 'trial-box';
        b.draggable    = true;
        b.ondragstart  = startDrag;
        b.title        = 'Click to select, then use arrow keys to move';
        b.dataset.row  = rr;          // for recoloring later
        b.dataset.col  = col;
        b.dataset.designIndex = designIndex;
        b.dataset.plotNumber = meta.plot_number || (designIndex + 1);
        b.dataset.originalPlotNumber = meta.original_plot_number || meta.plot_number || (designIndex + 1);
        b.dataset.block = meta.block || 1;
        b.dataset.isControl = String(meta.is_control || 0);
        b.dataset.accessionName = meta.accession_name || '';
        if (fillerByPlot.has(b.dataset.plotNumber)) {
          b.dataset.fillerAccession = fillerByPlot.get(b.dataset.plotNumber);
          b.classList.add('filler-applied');
        }
        b.addEventListener('click', handleTrialPlotClick);
        b.addEventListener('mouseenter', showPlotTooltip);
        b.addEventListener('mousemove', movePlotTooltip);
        b.addEventListener('mouseleave', hidePlotTooltip);
        applyPlotVisual(b, colour);
        g.appendChild(b);
      }

      /* one remove button per root group */
      if (!qs(`[data-root="${root}"] .remove-btn`)) {
        const rm   = document.createElement('div');
        rm.className = 'remove-btn';
        rm.textContent = 'x';
        rm.onclick = () => {
          if (isLockedRoot(root)) {
            alert('This trial is part of a saved layout and cannot be removed.');
            return;
          }
          const loading = qs('#grid-loader');
          if (loading) {
            loading.querySelector('span').textContent = 'Removing trial...';
            loading.classList.remove('hidden');
            setTimeout(() => {
              qsa(`[data-root="${root}"]`).forEach(el => el.remove());
              enablePal(tn);
              loading.classList.add('hidden');
            }, 50);
          } else {
            qsa(`[data-root="${root}"]`).forEach(el => el.remove());
            enablePal(tn);
          }
        };
        g.appendChild(rm);

        /* transpose button (one per root) */
        const tp = document.createElement('div');
        tp.className = 'transpose-btn';
        tp.textContent = 'T';
        tp.title = 'Transpose trial';
        tp.onclick = () => transposeTrial(root);
        g.appendChild(tp);
      }

      qs('#farm-grid').appendChild(g);
    }
    return ordered.map(([row, col], index) => ({
      row: row + 1,
      col: col + 1,
      plot_number: plotDesign[index]?.plot_number || (index + 1)
    }));
  }


  function recolorTrialPlots(trialId, designPath, baseColour) {

    $.ajax({
      url: '/ajax/trialallocation/get_design',
      method: 'GET',
      dataType: 'text',
      data: { trial_path: designPath },

      success: txt => {
        const lines  = txt.trim().split('\n');
        const header = lines.shift().split('\t');

        const idx = k => header.indexOf(k);
        const bI = idx('block'), rI = idx('row_number'),
              cI = idx('col_number'), ctlI = idx('is_control'),
              pI = idx('plots'), aI = idx('all_entries');

        if ([bI, rI, cI, ctlI].includes(-1)) {
          console.error('Design file missing columns');  return;
        }

        lines.forEach((l, designIndex) => {
          const f   = l.split('\t');
          const blk = +f[bI];              // 1-based block number
          const ctl = +f[ctlI] === 1;

          const box = document.querySelector(
            `.trial-group[data-trial="${trialId}"] .trial-box[data-design-index="${designIndex}"]`
          );
          if (!box) return;

          box.dataset.block = blk || 1;
          box.dataset.isControl = ctl ? '1' : '0';
          if (pI !== -1) box.dataset.originalPlotNumber = f[pI] || (designIndex + 1);
          if (aI !== -1) box.dataset.accessionName = f[aI] || '';
          applyPlotVisual(box, baseColour);
        });
      },

      error: (_, __, err) => console.error('Recolor failed:', err)
    });
  }

  /* Helper: is the rectangle free? */
function regionHasConflict(r0, c0, h, w, ignoreRoot){
  for(let r=r0; r<r0+h; r++){
    for(let c=c0; c<c0+w; c++){
      const k = key(r,c);
      if(cellIsUnused(r,c) || manualBorders.has(k) || fillerPlots.has(k)) return true;

      const clash = [...document.querySelectorAll('.trial-group')]
        .some(g=>{
          if(g.dataset.root === ignoreRoot) return false;
          const gr = +g.dataset.row;
          const gc = +g.dataset.col;
          const gw = groupWidth(g);
          const gh = groupHeight(g);
          return r>=gr && r<gr+gh && c>=gc && c<gc+gw;
        });
      if(clash) return true;
    }
  }
  return false;
}

  /* Transpose (rows/cols) */
  function transposeTrial(root){
    if (isLockedRoot(root)) {
      alert('This trial is part of a saved layout and cannot be changed.');
      return;
    }
    const parts = [...document.querySelectorAll(`.trial-group[data-root="${root}"]`)];
    if(!parts.length) return;

    /* derive footprint */
    let minR=1e9,minC=1e9,maxR=-1,maxC=-1;
    parts.forEach(g=>{
      const gr = +g.dataset.row;
      const gc = +g.dataset.col;
      const gw = g.style.gridTemplateColumns.split(' ').length;
      const gh = Math.round(g.offsetHeight / (CELL+GAP));
      minR = Math.min(minR, gr);           minC = Math.min(minC, gc);
      maxR = Math.max(maxR, gr+gh-1);      maxC = Math.max(maxC, gc+gw-1);
    });

    const curH = maxR-minR+1, curW = maxC-minC+1;
    const newH = curW,          newW = curH;

    /* bounds + overlap check */
    const rowsMax = +qs('#farm-rows').value,
          colsMax = +qs('#farm-cols').value;

    if(minR+newH > rowsMax || minC+newW > colsMax ||
       regionHasConflict(minR, minC, newH, newW, root)){
      alert('Cannot transpose - no free space at current position.');
      return;
    }

    /* remove old, place new */
    const tn     = parts[0].dataset.trial;
    const name   = qs(`#tname${tn}`)?.value || `Trial ${tn}`;
    const colour = colourFor(tn);
    const plotDesign = parts
      .flatMap(part => [...part.querySelectorAll('.trial-box')])
      .sort((a, b) => (+a.dataset.row - +b.dataset.row) || (+a.dataset.col - +b.dataset.col))
      .map(box => ({
        plot_number: box.dataset.plotNumber,
        block: box.dataset.block,
        accession_name: box.dataset.accessionName,
        is_control: box.dataset.isControl
      }));

    placeTrial({
      tn, name,
      rowsWanted: newH,
      colsWanted: newW,
      total: newH*newW,
      rowStart: minR,
      colStart: minC,
      colour,
      rootId: root,         // reuse same root so buttons stay unique
      ignoreRoot: root,
      design: plotDesign    // keep plot numbers, block colours, checks
    });
  }




  /******** selection drag for unused & borders (logic unchanged) ********/
  let isDragging=false;
  let brushForceOn=null;
  let brushedCells = new Set();
  qs('#farm-grid').addEventListener('mousedown',e=>{
    const cell=e.target.closest('.grid-cell');
    if(!cell||!cell.dataset.row) return;
    const tool = activeTool();
    if(tool !== 'unused' && tool !== 'border') return;
    isDragging=true;
    suppressCellClick = true;
    const r = +cell.dataset.row;
    const c = +cell.dataset.col;
    brushForceOn = tool === 'border' ? !manualBorders.has(key(r, c)) : !cellIsUnused(r, c);
    brushedCells = new Set();
    brushedCells.add(key(r, c));
    applyGridBrush(cell, brushForceOn);
    e.preventDefault();
  });

  qs('#farm-grid').addEventListener('mousemove', e => {
    if (!isDragging) return;
    const cell = e.target.closest('.grid-cell');
    if (!cell || !cell.dataset.row) return;
    const k = key(+cell.dataset.row, +cell.dataset.col);
    if (brushedCells.has(k)) return;
    brushedCells.add(k);
    applyGridBrush(cell, brushForceOn);
  });

  document.addEventListener('mouseup', e => {
    isDragging = false;
    brushForceOn = null;
    brushedCells = new Set();
  });



  /******** reposition helper ********/
  function repositionTrials(){ qsa('.trial-group').forEach(g=>{
    g.style.left = `${(+g.dataset.col+1)*STEP}px`;
    g.style.top  = `${(+g.dataset.row+1)*STEP}px`;
  }); }

  /******** boot ********/
  function makeTrials(){
    qs('#trial-details').innerHTML='';
    qs('#trial-boxes').innerHTML='';
    const lockedMax = lockedTrialForms.size ? Math.max(...lockedTrialForms.keys()) : 0;
    const n = Math.max(+qs('#num-trials')?.value || 0, lockedMax);
    setInputValue('num-trials', n);
    for(let i=1;i<=n;i++){
      addTrialForm(i);
      addPaletteBox(i);
      if (lockedTrialForms.has(i)) {
        restoreTrialFormValues(lockedTrialForms.get(i));
        setTimeout(() => {
          restoreTrialFormValues(lockedTrialForms.get(i));
          lockTrialForm(i, true);
          disablePal(i);
        }, 750);
      }
    }
    if (layoutContextLocked) lockLayoutContext(true);
  }

  function updateUnusedRowHighlights(rowList) {
    const cols = +qs('#farm-cols')?.value || 0;
    for (let r = 0; r < +qs('#farm-rows')?.value || 0; r++) {
      for (let c = 0; c < cols; c++) {
        const cell = qs(`.grid-cell[data-row="${r}"][data-col="${c}"]`);
        if (!cell) continue;
        paintCell(cell);
      }
    }
  }

  function updateUnusedColHighlights(colList) {
    const rows = +qs('#farm-rows')?.value || 0;
    for (let c = 0; c < +qs('#farm-cols')?.value || 0; c++) {
      for (let r = 0; r < rows; r++) {
        const cell = qs(`.grid-cell[data-row="${r}"][data-col="${c}"]`);
        if (!cell) continue;
        paintCell(cell);
      }
    }
  }

  function setInputValue(id, value) {
    const el = qs(`#${id}`);
    if (el && value !== undefined && value !== null) el.value = value;
  }

  function setSelectValue(id, value) {
    const el = qs(`#${id}`);
    if (!el || value === undefined || value === null) return;
    const normalized = String(value);
    el.dataset.pendingValue = normalized;
    el.value = normalized;
    el.dispatchEvent(new Event('change', { bubbles: true }));
    if (window.jQuery) $(`#${id}`).trigger('change.select2');
  }

  function serializeSet(set) {
    return Array.from(set).map(k => {
      const [row, col] = k.split(',').map(Number);
      return { row: row + 1, col: col + 1 };
    });
  }

  function serializeBorders() {
    return Array.from(manualBorders).map(k => {
      const [row, col] = k.split(',').map(Number);
      return {
        row: row + 1,
        col: col + 1,
        accession: borderPlots.get(k)?.accession || ''
      };
    });
  }

  function serializeTrialForms() {
    const n = +qs('#num-trials')?.value || 0;
    const trials = [];

    for (let i = 1; i <= n; i++) {
      trials.push({
        trial_index: i,
        name: qs(`#tname${i}`)?.value || '',
        description: qs(`#tdesc${i}`)?.value || '',
        type: qs(`#ttype${i}`)?.value || '',
        design: qs(`#tdesign${i}`)?.value || '',
        layout_type: qs(`#tlayout${i}`)?.value || '',
        horizontal_direction: qs(`#grid-direction-horizontal${i}`)?.value || 'ltr',
        vertical_direction: qs(`#grid-direction-vertical${i}`)?.value || 'ttb',
        start_plot_number: qs(`#tstartplot${i}`)?.value || '',
        plot_numbering: qs(`#tplotnumbering${i}`)?.value || '',
        treatment_list_id: qs(`#ttreatments${i}`)?.value || '',
        control_list_id: qs(`#tcontrols${i}`)?.value || '',
        reps: qs(`#treps${i}`)?.value || '',
        blocks: qs(`#tblocks${i}`)?.value || '',
        repsblocks: qs(`#trepsblocks${i}`)?.value || '',
        rows: qs(`#trows${i}`)?.value || '',
        cols: qs(`#tcols${i}`)?.value || '',
        block_rows: qs(`#tblockrows${i}`)?.value || '',
        block_cols: qs(`#tblockcols${i}`)?.value || '',
        super_rows: qs(`#tsuperrows${i}`)?.value || '',
        super_cols: qs(`#tsupercols${i}`)?.value || ''
      });
    }

    return trials;
  }

  function serializePlacedTrials() {
    const roots = {};

    qsa('.trial-group').forEach(group => {
      const root = group.dataset.root;
      if (!roots[root]) {
        roots[root] = {
          root,
          trial_index: +group.dataset.trial,
          anchor_row: (+group.dataset.anchorRow || 0) + 1,
          anchor_col: (+group.dataset.anchorCol || 0) + 1,
          rows_wanted: +group.dataset.rowsWanted || 0,
          cols_wanted: +group.dataset.colsWanted || 0,
          plots: []
        };
      }

      group.querySelectorAll('.trial-box').forEach(box => {
        roots[root].plots.push({
          row: (+box.dataset.row || 0) + 1,
          col: (+box.dataset.col || 0) + 1,
          design_index: +box.dataset.designIndex || 0,
          plot_number: box.dataset.plotNumber || '',
          original_plot_number: box.dataset.originalPlotNumber || '',
          block: box.dataset.block || '',
          is_control: box.dataset.isControl || '0',
          accession_name: box.dataset.accessionName || '',
          filler_accession: box.dataset.fillerAccession || ''
        });
      });
    });

    return Object.values(roots).map(trial => {
      trial.plots.sort((a, b) => a.design_index - b.design_index);
      return trial;
    });
  }

  function collectLayoutJson() {
    const farm = qs('#farm_dropdown');
    const breedingProgram = qs('#breeding_program_dropdown');
    const validValue = value => {
      const normalized = String(value || '').trim();
      return (normalized && normalized !== 'null' && normalized !== 'undefined') ? normalized : '';
    };
    const selectedValue = el => validValue(el?.value || el?.selectedOptions?.[0]?.value);
    const farmLocationId = selectedValue(farm);
    const breedingProgramId = selectedValue(breedingProgram);
    const year = String(qs('#layout-year')?.value || '').trim();

    return {
      schema_version: 1,
      saved_at: new Date().toISOString(),
      year,
      season: String(qs('#layout-season')?.value || '').trim(),
      breeding_program: {
        program_id: breedingProgramId,
        name: breedingProgramId ? (breedingProgram?.selectedOptions?.[0]?.textContent || '') : ''
      },
      farm: {
        location_id: farmLocationId,
        name: farmLocationId ? (farm?.selectedOptions?.[0]?.textContent || '') : ''
      },
      field: {
        rows: +qs('#farm-rows')?.value || 0,
        cols: +qs('#farm-cols')?.value || 0,
        plot_width: qs('#plot-width')?.value || '',
        plot_length: qs('#plot-length')?.value || ''
      },
      unused_rows: qs('#unused-rows')?.value || '',
      unused_cols: qs('#unused-cols')?.value || '',
      manual_block: serializeSet(manualBlock),
      manual_allow: serializeSet(manualAllow),
      manual_borders: serializeBorders(),
      filler_plots: Array.from(fillerPlots.entries()).map(([k, v]) => {
        const [row, col] = k.split(',').map(Number);
        return { row: row + 1, col: col + 1, accession: v.accession };
      }),
      planting_settings: plantingSettings(),
      trial_forms: serializeTrialForms(),
      placed_trials: serializePlacedTrials()
    };
  }

  function restoreSet(items) {
    return new Set((items || []).map(item => key((+item.row || 1) - 1, (+item.col || 1) - 1)));
  }

  function clearPlacedTrials() {
    qsa('.trial-group').forEach(el => el.remove());
    selectedRoot = null;
  }

  function drawSavedTrial(savedTrial, lockLoadedTrial = false) {
    const tn = savedTrial.trial_index;
    const root = savedTrial.root || uid();
    const colour = colourFor(tn);
    const rowsMap = {};

    (savedTrial.plots || []).forEach(plot => {
      const row = (+plot.row || 1) - 1;
      const col = (+plot.col || 1) - 1;
      (rowsMap[row] = rowsMap[row] || []).push(Object.assign({}, plot, { row0: row, col0: col }));
    });

    Object.entries(rowsMap).forEach(([row, plots]) => {
      plots.sort((a, b) => a.col0 - b.col0);
      let start = 0;
      for (let i = 1; i <= plots.length; i++) {
        if (i === plots.length || plots[i].col0 !== plots[i - 1].col0 + 1) {
          createSavedSegment(+row, plots.slice(start, i));
          start = i;
        }
      }
    });

    function createSavedSegment(row, plots) {
      const startCol = plots[0].col0;
      const seg = plots.length;
      const g = document.createElement('div');

      g.className = 'trial-group';
      g.dataset.trial = tn;
      g.dataset.root = root;
      g.dataset.row = row;
      g.dataset.col = startCol;
      g.dataset.rowsWanted = savedTrial.rows_wanted || 0;
      g.dataset.colsWanted = savedTrial.cols_wanted || seg;
      g.dataset.anchorRow = (+savedTrial.anchor_row || row + 1) - 1;
      g.dataset.anchorCol = (+savedTrial.anchor_col || startCol + 1) - 1;
      if (lockLoadedTrial) g.dataset.locked = '1';
      g.style.left = `${(startCol + 1) * STEP}px`;
      g.style.top = `${(row + 1) * STEP}px`;
      g.style.width = `${seg * STEP - GAP}px`;
      g.style.height = `${CELL}px`;
      g.style.gridTemplateColumns = `repeat(${seg}, ${CELL}px)`;
      g.draggable = !lockLoadedTrial;
      g.ondragstart = startDrag;
      g.tabIndex = 0;
      g.addEventListener('click', e => {
        e.stopPropagation();
        selectTrial(root);
      });

      plots.forEach(plot => {
        const b = document.createElement('div');
        b.className = 'trial-box';
        b.draggable = !lockLoadedTrial;
        b.ondragstart = startDrag;
        b.dataset.row = plot.row0;
        b.dataset.col = plot.col0;
        b.dataset.designIndex = plot.design_index || 0;
        b.dataset.plotNumber = plot.plot_number || '';
        b.dataset.originalPlotNumber = plot.original_plot_number || plot.plot_number || '';
        b.dataset.block = plot.block || 1;
        b.dataset.isControl = String(plot.is_control || 0);
        b.dataset.accessionName = plot.accession_name || '';
        if (plot.filler_accession) b.dataset.fillerAccession = plot.filler_accession;
        b.addEventListener('click', handleTrialPlotClick);
        b.addEventListener('mouseenter', showPlotTooltip);
        b.addEventListener('mousemove', movePlotTooltip);
        b.addEventListener('mouseleave', hidePlotTooltip);
        applyPlotVisual(b, colour);
        g.appendChild(b);
      });

      qs('#farm-grid').appendChild(g);
      if (lockLoadedTrial) {
        lockedTrialRoots.add(root);
        lockTrialVisuals(root, true);
      }
      disablePal(tn);
    }
  }

  function applySavedLayout(layout) {
    if (!layout) return;

    lockedTrialRoots = new Set();
    lockedTrialForms = new Map((layout.trial_forms || []).map(form => [form.trial_index, form]));
    lockLayoutContext(true);
    setInputValue('num-trials', (layout.trial_forms || []).length);
    makeTrials();

    setInputValue('layout-year', layout.year);
    setInputValue('layout-season', layout.season);
    setSelectValue('breeding_program_dropdown', layout.breeding_program?.program_id);
    setInputValue('farm-rows', layout.field?.rows);
    setInputValue('farm-cols', layout.field?.cols);
    setInputValue('plot-width', layout.field?.plot_width);
    setInputValue('plot-length', layout.field?.plot_length);
    setInputValue('unused-rows', layout.unused_rows);
    setInputValue('unused-cols', layout.unused_cols);

    (layout.trial_forms || []).forEach(form => {
      const i = form.trial_index;
      restoreTrialFormValues(form);
      lockTrialForm(i, true);
      setTimeout(() => {
        restoreTrialFormValues(form);
        lockTrialForm(i, true);
      }, 750);
    });

    manualBlock = restoreSet(layout.manual_block);
    manualAllow = restoreSet(layout.manual_allow);
    manualBorders = restoreSet(layout.manual_borders);
    borderPlots = new Map((layout.manual_borders || []).map(item => [
      key((+item.row || 1) - 1, (+item.col || 1) - 1),
      { accession: item.accession || '' }
    ]));
    fillerPlots = new Map((layout.filler_plots || []).map(item => [
      key((+item.row || 1) - 1, (+item.col || 1) - 1),
      { accession: item.accession || '' }
    ]));
    setInputValue('planting-rows-per-plot', layout.planting_settings?.rows_per_plot);
    setInputValue('planting-plants-per-plot', layout.planting_settings?.plants_per_plot);
    setInputValue('planting-plant-spacing', layout.planting_settings?.plant_spacing);
    setInputValue('planting-row-spacing', layout.planting_settings?.row_spacing);
    setInputValue('planting-alley-spacing', layout.planting_settings?.alley_spacing);
    setSelectValue('planting-direction', layout.planting_settings?.planting_direction);
    setInputValue('planting-notes', layout.planting_settings?.notes);

    drawGrid();
    clearPlacedTrials();
    (layout.placed_trials || []).forEach(trial => drawSavedTrial(trial, true));
    lockPlacedTrials(true);
    lockLayoutContext(true);
    renderVisibleCells(lastRow, lastCol);
  }

  function saveCurrentLayout() {
    const layout = collectLayoutJson();
    if (!layout.farm.location_id || !layout.year) {
      alert('Select location and year before saving the layout.');
      return;
    }

    $.ajax({
      url: '/ajax/trialallocation/save_layout',
      method: 'POST',
      dataType: 'json',
      data: { layout: JSON.stringify(layout) },
      success: function(response) {
        if (response.success) {
          lockLayoutContext(true);
          lockPlacedTrials(true);
          alert('Layout saved.');
        } else {
          alert(response.error || 'Could not save layout.');
        }
      },
      error: function(_, __, error) {
        console.error('Save layout failed:', error);
        alert('Could not save layout.');
      }
    });
  }

  function saveTrialsInDatabase() {
    const layout = collectLayoutJson();
    const saveButton = qs('#save-trials-db-btn');

    if (!layout.farm.location_id || !layout.year) {
      alert('Select location and year before saving the trials.');
      return;
    }
    if (!layout.breeding_program.program_id) {
      alert('Select a breeding program before saving the trials.');
      return;
    }
    if (!layout.placed_trials.length) {
      alert('Place at least one trial in the grid before saving.');
      return;
    }
    const placedTrialIndexes = new Set(layout.placed_trials.map(trial => String(trial.trial_index)));
    const missingTrials = layout.trial_forms.filter(form => !placedTrialIndexes.has(String(form.trial_index)));
    if (missingTrials.length) {
      const names = missingTrials.map(form => sanitizeTrialName(form.name) || `Trial ${form.trial_index}`).join(', ');
      alert(`These trials are not placed in the grid yet: ${names}. Place all trials before saving them in the database.`);
      return;
    }
    if (!window.confirm('Save all placed trials in the database?')) {
      return;
    }

    if (saveButton) {
      saveButton.disabled = true;
      saveButton.textContent = 'Saving Trials...';
      saveButton.classList.add('opacity-70', 'cursor-wait');
    }

    $.ajax({
      url: '/ajax/trialallocation/save_trials_database',
      method: 'POST',
      dataType: 'json',
      data: { layout: JSON.stringify(layout) },
      success: function(response) {
        if (response.success) {
          lockLayoutContext(true);
          lockPlacedTrials(true);
          const names = (response.trials || []).map(trial => `${trial.name} (${trial.trial_id})`).join('\n');
          alert(names ? `Trials saved:\n${names}` : 'Trials saved in the database.');
        } else {
          alert(response.error || 'Could not save trials in the database.');
        }
      },
      error: function(xhr, __, error) {
        console.error('Save trials failed:', error, xhr?.responseText);
        alert('Could not save trials in the database.');
      },
      complete: function() {
        if (saveButton) {
          saveButton.disabled = false;
          saveButton.textContent = 'Save Layout Trials in Database';
          saveButton.classList.remove('opacity-70', 'cursor-wait');
        }
      }
    });
  }

  function loadExistingLayoutForSelection() {
    const locationId = qs('#farm_dropdown')?.value;
    const year = qs('#layout-year')?.value;
    const season = qs('#layout-season')?.value;

    if (!locationId || !year) return;

    $.ajax({
      url: '/ajax/trialallocation/get_layout',
      method: 'GET',
      dataType: 'json',
      data: { location_id: locationId, year, season },
      success: function(response) {
        if (!response.success) {
          console.warn(response.error || 'Could not load saved layout.');
          return;
        }
        if (!response.found) return;

        const hasCurrentLayout = qsa('.trial-group').length > 0;
        if (hasCurrentLayout && !window.confirm('A layout is already saved for this location, year, and season. Load it and replace the current grid view?')) {
          return;
        }
        applySavedLayout(response.layout);
      },
      error: function(_, __, error) {
        console.error('Load layout failed:', error);
      }
    });
  }


  window.onload = ()=>{
    loadBreedingProgramDropdown();
    loadGlobalFarmDropdown();
    loadSeasonDropdown();
    loadTrialTypes();
    loadTrialDesigns();
    makeTrials();
    drawGrid();
    qs('#farm-rows').addEventListener('change',drawGrid);
    qs('#farm-cols').addEventListener('change',drawGrid);
    qs('#edit-toggle').addEventListener('change',()=>{
      if(qs('#edit-toggle').checked) {
        qs('#border-toggle').checked=false;
        qs('#filler-toggle').checked=false;
      }
    });
    qs('#border-toggle').addEventListener('change',()=>{
      if(qs('#border-toggle').checked) {
        qs('#edit-toggle').checked=false;
        qs('#filler-toggle').checked=false;
      }
    });
    qs('#filler-toggle')?.addEventListener('change',()=>{
      if(qs('#filler-toggle').checked) {
        qs('#edit-toggle').checked=false;
        qs('#border-toggle').checked=false;
      }
    });
    lastUnusedRows = qs('#unused-rows').value;
    lastUnusedCols = qs('#unused-cols').value;

    qs('#unused-rows').addEventListener('change', function (e) {
      const val = e.target.value.trim();
      const rowList = val ? val.split(',').map(v => +v.trim() - 1).filter(n => !isNaN(n)) : [];
      const cols = +qs('#farm-cols')?.value || 0;

      const conflict = rowList.some(row => {
        return [...document.querySelectorAll('.trial-group')].some(group => {
          const gr = +group.dataset.row;
          const gh = groupHeight(group);
          return row >= gr && row < gr + gh;
        }) || Array.from({ length: cols }).some((_, c) => manualBorders.has(key(row, c)) || fillerPlots.has(key(row, c)));
      });

      if (conflict) {
        alert("It is not possible to turn entire row or column unutilized because there is a trial or border already placed.");
        e.target.value = lastUnusedRows;
        return;
      }

      lastUnusedRows = val;
      updateUnusedRowHighlights(rowList);  // <-- efficient, no redraw
    });



    qs('#unused-cols').addEventListener('change', function (e) {
      const val = e.target.value.trim();
      const colList = val ? val.split(',').map(v => +v.trim() - 1).filter(n => !isNaN(n)) : [];
      const rows = +qs('#farm-rows')?.value || 0;

      const conflict = colList.some(col => {
        return [...document.querySelectorAll('.trial-group')].some(group => {
          const gc = +group.dataset.col;
          const gw = groupWidth(group);
          return col >= gc && col < gc + gw;
        }) || Array.from({ length: rows }).some((_, r) => manualBorders.has(key(r, col)) || fillerPlots.has(key(r, col)));
      });

      if (conflict) {
        alert("It is not possible to turn entire row or column unutilized because there is a trial or border already placed.");
        e.target.value = lastUnusedCols;
        return;
      }

      lastUnusedCols = val;
      updateUnusedColHighlights(colList);
    });



    qs('#num-trials')?.addEventListener('change',makeTrials);
    qs('#save-layout-btn')?.addEventListener('click', saveCurrentLayout);
    qs('#save-trials-db-btn')?.addEventListener('click', saveTrialsInDatabase);
    qs('#layout-year')?.addEventListener('change', loadExistingLayoutForSelection);
    qs('#layout-season')?.addEventListener('change', loadExistingLayoutForSelection);
    $('#farm_dropdown').on('change', loadExistingLayoutForSelection);
  };


});
