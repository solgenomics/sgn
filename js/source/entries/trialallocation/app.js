import { createAccessionTools } from './accessions.js';
import { createDownloadTools } from './downloads.js';

export function initTrialAllocation() {
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
  const {
    currentBorderAccession,
    initAccessionAutocomplete,
    chooseFillerAccession
  } = createAccessionTools({ qs });
  let plantingSettings = () => ({});
  let initDownloadTools = () => {};

  function nextRootId() {
    let root;
    do {
      root = uid();
    } while (qs(`.trial-group[data-root="${root}"]`) || lockedTrialRoots.has(root));
    return root;
  }

  let manualBlock   = new Set();
  let manualAllow   = new Set();
  let manualBorders = new Set();
  let borderPlots   = new Map();
  let fillerPlots   = new Map();
  let selectedRoot  = null;
  let suppressCellClick = false;
  let lockedTrialRoots = new Set();
  let lockedTrialForms = new Map();
  let databaseSavedTrialIndexes = new Set();
  let layoutContextLocked = false;
  let savedLayoutContext = null;
  let applyingSavedLayout = false;
  let existingProjectTrials = new Map();
  const userIsCurator = !!window.trialAllocationIsCurator;

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

  function gridCellTooltipHtml(cell){
    const r = +cell.dataset.row;
    const c = +cell.dataset.col;
    const k = key(r, c);
    const border = borderPlots.get(k);
    const filler = fillerPlots.get(k);
    const isBorder = manualBorders.has(k);
    const isUnused = cellIsUnused(r, c);
    const rowNumber = Number.isNaN(r) ? 'Not available' : r + 1;
    const colNumber = Number.isNaN(c) ? 'Not available' : c + 1;

    if (isBorder) {
      return `
        <div><span class="tooltip-label">Type:</span> Border</div>
        <div><span class="tooltip-label">Row:</span> ${rowNumber}</div>
        <div><span class="tooltip-label">Column:</span> ${colNumber}</div>
        <div><span class="tooltip-label">Accession:</span> ${border?.accession || 'Blank border'}</div>
      `;
    }

    if (filler) {
      return `
        <div><span class="tooltip-label">Type:</span> Filler</div>
        <div><span class="tooltip-label">Row:</span> ${rowNumber}</div>
        <div><span class="tooltip-label">Column:</span> ${colNumber}</div>
        <div><span class="tooltip-label">Accession:</span> ${filler.accession || 'Not available'}</div>
      `;
    }

    if (isUnused) {
      return `
        <div><span class="tooltip-label">Type:</span> Unutilized region</div>
        <div><span class="tooltip-label">Row:</span> ${rowNumber}</div>
        <div><span class="tooltip-label">Column:</span> ${colNumber}</div>
      `;
    }

    return '';
  }

  function sanitizeTrialName(name) {
    return String(name || '')
      .trim()
      .replace(/\s+/g, '_')
      .replace(/[\\/:,"*?<>|]+/g, '_')
      .replace(/_+/g, '_')
      .replace(/^_+|_+$/g, '');
  }

  function currentLayoutContext() {
    const validValue = value => {
      const normalized = String(value || '').trim();
      return (normalized && normalized !== 'null' && normalized !== 'undefined') ? normalized : '';
    };
    return {
      locationId: validValue(qs('#farm_dropdown')?.value) || validValue(savedLayoutContext?.farm?.location_id),
      year: validValue(qs('#layout-year')?.value) || validValue(savedLayoutContext?.year),
      season: validValue(qs('#layout-season')?.value) || validValue(savedLayoutContext?.season)
    };
  }

  function isValidLayoutYear(year) {
    const value = String(year || '').trim();
    if (!/^\d{4}$/.test(value)) return false;
    const numericYear = Number(value);
    return numericYear > 1960 && numericYear < 2100;
  }

  function requireValidLayoutYear() {
    const yearInput = qs('#layout-year');
    const year = String(yearInput?.value || '').trim();
    if (isValidLayoutYear(year)) return true;
    alert('Year must be in YYYY format, greater than 1960 and smaller than 2100.');
    yearInput?.focus();
    return false;
  }

  function designIsAugmentedRowColumn(value) {
    return value === 'ARC' || value === 'Augmented Row-Column';
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
      if (lockedTrialForms.has(trialIndex) || existingProjectTrials.has(trialIndex)) select.disabled = true;
    });

    Array.from(scope.querySelectorAll('select[id^="tdesign"]')).forEach(select => {
      const trialIndex = +(select.id.replace('tdesign', '') || 0);
      const selected = select.value || lockedTrialForms.get(trialIndex)?.design || '';
      select.innerHTML = '<option value="">Select design</option>';
      availableTrialDesigns.forEach(design => {
        select.appendChild(new Option(design.name, design.value));
      });
      if (selected) select.value = selected;
      if (lockedTrialForms.has(trialIndex) || existingProjectTrials.has(trialIndex)) select.disabled = true;
    });
  }

  function isLockedRoot(root) {
    return !!root && lockedTrialRoots.has(root);
  }

  function lockControl(id, locked = true) {
    const el = qs(`#${id}`);
    if (!el) return;
    el.disabled = locked;
    el.readOnly = locked;
    if (window.jQuery) $(`#${id}`).trigger('change.select2');
  }

  function lockLayoutContext(locked = true) {
    layoutContextLocked = locked;
    [
      'farm_dropdown',
      'breeding_program_dropdown',
      'layout-year',
      'layout-season',
      'farm-rows',
      'farm-cols',
      'unused-rows',
      'unused-cols',
      'edit-toggle'
    ].forEach(id => lockControl(id, locked));
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
    setSelectValue(`tstartplot${i}`, form.start_plot_number);
    setSelectValue(`tplotnumbering${i}`, form.plot_numbering);
    setInputValue(`treps${i}`, form.reps);
    setInputValue(`tblocks${i}`, form.blocks);
    setInputValue(`trepsblocks${i}`, form.repsblocks);
    setInputValue(`trows${i}`, form.rows);
    setInputValue(`tcols${i}`, form.cols);
    setInputValue(`tplotwidth${i}`, form.plot_width);
    setInputValue(`tplotlength${i}`, form.plot_length);
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
    form.dataset.locked = locked ? '1' : '0';
    form.querySelectorAll('input, textarea, select, button').forEach(el => {
      el.disabled = locked;
      el.readOnly = locked;
    });
    [
      `grid-direction-horizontal${trialIndex}`,
      `grid-direction-vertical${trialIndex}`,
      `rotate-trial-cw${trialIndex}`,
      `rotate-trial-ccw${trialIndex}`
    ].forEach(id => lockControl(id, locked));
  }

  function lockExistingProjectForm(trialIndex) {
    const form = qs(`#tname${trialIndex}`)?.closest('.border.rounded');
    if (!form) return;
    form.classList.add('opacity-80');
    form.dataset.existingProject = '1';
    form.querySelectorAll('input, textarea, select, button').forEach(el => {
      el.disabled = true;
      el.readOnly = true;
    });
  }

  function lockTrialVisuals(root, locked = true) {
    qsa(`.trial-group[data-root="${root}"]`).forEach(group => {
      group.dataset.locked = locked ? '1' : '0';
      group.draggable = !locked;
      group.classList.toggle('locked-trial', locked);
      group.querySelectorAll('.trial-box').forEach(box => {
        box.draggable = !locked;
      });
      group.querySelectorAll('.remove-btn').forEach(btn => {
        btn.style.display = locked && !userIsCurator ? 'none' : '';
      });
      group.querySelectorAll('.transpose-btn').forEach(btn => {
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

  function isDatabaseSavedTrialIndex(trialIndex) {
    return databaseSavedTrialIndexes.has(String(trialIndex));
  }

  function filterLayoutToUnsavedDatabaseTrials(layout) {
    const newPlacedTrials = (layout.placed_trials || []).filter(trial => {
      if (trial.existing_project_id) return true;
      return !isDatabaseSavedTrialIndex(trial.trial_index);
    });
    const newTrialIndexes = new Set(newPlacedTrials.map(trial => String(trial.trial_index)));

    return Object.assign({}, layout, {
      trial_forms: (layout.trial_forms || []).filter(form => newTrialIndexes.has(String(form.trial_index))),
      placed_trials: newPlacedTrials
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
    showTooltip(plotTooltipHtml(e.currentTarget), e);
  }

  function showGridCellTooltip(e){
    const html = gridCellTooltipHtml(e.currentTarget);
    if (!html) {
      hidePlotTooltip();
      return;
    }
    showTooltip(html, e);
  }

  function showTooltip(html, e){
    let tooltip = qs('#plot-hover-tooltip');
    if (!tooltip) {
      tooltip = document.createElement('div');
      tooltip.id = 'plot-hover-tooltip';
      tooltip.className = 'plot-hover-tooltip';
      document.body.appendChild(tooltip);
    }
    tooltip.innerHTML = html;
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
    box.removeAttribute('title');
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
    cell.removeAttribute('title');
  }

  function disablePal(t){ const p = qs(`#palette${t}`); if(p){ p.style.opacity='0.3'; p.draggable=false; p.classList.add('cursor-not-allowed'); } }
  function enablePal(t){ const p = qs(`#palette${t}`); if(p){ p.style.opacity='1';  p.draggable=true;  p.classList.remove('cursor-not-allowed'); } }

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
    cell.addEventListener('mouseenter', e => {
      if (qs('#edit-toggle').checked || qs('#border-toggle').checked) cell.classList.add('hover-preview');
      showGridCellTooltip(e);
    });
    cell.addEventListener('mousemove', movePlotTooltip);
    cell.addEventListener('mouseleave', () => {
      cell.classList.remove('hover-preview');
      hidePlotTooltip();
    });

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
          <select id='tstartplot${i}' class='w-full border rounded px-2 py-1'>
            <option value="1">1</option>
            <option value="101">101</option>
            <option value="1001">1001</option>
          </select>
        </label>
        <label>Plot Numbering
          <select id='tplotnumbering${i}' class='w-full border rounded px-2 py-1'>
            <option value="continuous">Continuous across blocks</option>
            <option value="block_prefix">Start with block number</option>
          </select>
        </label>
      </div>

      <div class='grid grid-cols-2 gap-4 mb-4'>
        <label>Accessions List
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

      <div class='grid grid-cols-2 gap-4 mt-4'>
        <label>Plot Width
          <input id='tplotwidth${i}' type='number' min='0' step='0.01' class='w-full border rounded px-2 py-1' />
        </label>
        <label>Plot Length
          <input id='tplotlength${i}' type='number' min='0' step='0.01' class='w-full border rounded px-2 py-1' />
        </label>
      </div>

      <div class='mt-4 text-right'>
        <button onclick='generateDesign(${i}, 0, 0, this)' class='px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700'>
          Generate Design
        </button>
      </div>
    `;

    qs('#trial-details').appendChild(d);
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

        if ($select[0]?.dataset.pendingValue) {
          $select.val($select[0].dataset.pendingValue);
        }

        // Initialize Select2 *after* data is populated
        $select.select2({
          placeholder: 'Select or type a location',
          allowClear: true,
          width: '100%',
          dropdownParent: $('#farm_dropdown').closest('div')
        });
        $select.trigger('change.select2');
        if (layoutContextLocked) lockControl('farm_dropdown', true);
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
        if (layoutContextLocked) lockControl('breeding_program_dropdown', true);
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

  function loadExistingTrialsForContext() {
    const select = qs('#existing-trial-select');
    if (!select) return;

    const { locationId, year } = currentLayoutContext();
    if (!locationId || !year) {
      select.innerHTML = '<option value="">Select location and year first</option>';
      if (window.jQuery && $('#existing-trial-select').data('select2')) {
        $('#existing-trial-select').val('').trigger('change.select2');
      }
      return;
    }
    if (!isValidLayoutYear(year)) {
      select.innerHTML = '<option value="">Enter a valid YYYY year</option>';
      if (window.jQuery && $('#existing-trial-select').data('select2')) {
        $('#existing-trial-select').val('').trigger('change.select2');
      }
      return;
    }

    select.innerHTML = '<option value="">Loading trials...</option>';
    $.ajax({
      url: '/ajax/trialallocation/existing_trials',
      method: 'GET',
      dataType: 'json',
      data: { location_id: locationId, year },
      success: function(data) {
        select.innerHTML = '<option value="">Select an existing trial</option>';
        const trials = data.success && Array.isArray(data.trials) ? data.trials : [];
        const placedExistingProjects = placedExistingProjectIds();
        trials
          .filter(trial => !placedExistingProjects.has(String(trial.trial_id)))
          .forEach(trial => {
            const option = new Option(trial.name, trial.trial_id);
            option.dataset.name = trial.name || '';
            option.dataset.description = trial.description || '';
            option.dataset.design = trial.design || '';
            option.dataset.type = trial.type || '';
            option.dataset.breedingProgramId = trial.breeding_program_id || '';
            option.dataset.breedingProgramName = trial.breeding_program_name || '';
            select.appendChild(option);
          });

        if (window.jQuery) {
          const $select = $('#existing-trial-select');
          if ($select.data('select2')) $select.select2('destroy');
          $select.select2({
            placeholder: 'Select an existing trial',
            allowClear: true,
            width: '100%',
            dropdownParent: $select.closest('label')
          });
        }
      },
      error: function(_, __, error) {
        console.error('Failed to load existing trials:', error);
        select.innerHTML = '<option value="">Could not load existing trials</option>';
      }
    });
  }

  function selectedExistingTrialAlreadyAdded(projectId) {
    return placedExistingProjectIds().has(String(projectId));
  }

  function placedExistingProjectIds() {
    const ids = new Set();
    existingProjectTrials.forEach(trial => {
      if (trial.project_id) ids.add(String(trial.project_id));
      if (trial.existing_project_id) ids.add(String(trial.existing_project_id));
    });
    lockedTrialForms.forEach(form => {
      if (form.existing_project_id) ids.add(String(form.existing_project_id));
      if (form.project_id) ids.add(String(form.project_id));
    });
    qsa('.trial-group').forEach(group => {
      const trialIndex = +group.dataset.trial;
      const existingProjectId = existingProjectTrials.get(trialIndex)?.project_id ||
        lockedTrialForms.get(trialIndex)?.existing_project_id ||
        group.dataset.existingProjectId ||
        '';
      if (existingProjectId) ids.add(String(existingProjectId));
    });
    return ids;
  }

  function addExistingTrialToPalette() {
    const select = qs('#existing-trial-select');
    const projectId = select?.value || '';
    if (!projectId) {
      alert('Select an existing trial first.');
      return;
    }
    if (selectedExistingTrialAlreadyAdded(projectId)) {
      alert('This existing trial is already included in the layout.');
      return;
    }

    const option = select.selectedOptions?.[0];
    const btn = qs('#add-existing-trial-btn');
    if (btn) {
      btn.disabled = true;
      btn.textContent = 'Adding...';
    }

    $.ajax({
      url: '/ajax/trialallocation/existing_trial_design',
      method: 'GET',
      dataType: 'json',
      data: { trial_id: projectId },
      success: function(response) {
        if (!response.success || !response.trial) {
          alert(response.error || 'Could not load the selected trial design.');
          return;
        }

        const trial = response.trial;
        const index = (+qs('#num-trials')?.value || 0) + 1;
        const form = {
          trial_index: index,
          project_id: String(projectId),
          existing_project_id: String(projectId),
          name: trial.name || option?.dataset.name || `Trial ${index}`,
          description: trial.description || option?.dataset.description || '',
          type: option?.dataset.type || '',
          design: option?.dataset.design || '',
          layout_type: 'serpentine',
          horizontal_direction: 'ltr',
          vertical_direction: 'ttb',
          start_plot_number: '1',
          plot_numbering: 'continuous',
          plot_width: '',
          plot_length: '',
          reps: '',
          blocks: '',
          repsblocks: '',
          rows: trial.n_row || '',
          cols: trial.n_col || '',
          block_rows: '',
          block_cols: '',
          super_rows: '',
          super_cols: '',
          treatment_list_id: '',
          control_list_id: ''
        };

        existingProjectTrials.set(index, form);
        databaseSavedTrialIndexes.add(String(index));
        trialDesignCache[index] = {
          design_file: '',
          param_file: '',
          design: trial.design || [],
          n_row: trial.n_row || 1,
          n_col: trial.n_col || Math.max(1, (trial.design || []).length),
          existing_project_id: String(projectId)
        };

        setInputValue('num-trials', index);
        makeTrials();
        restoreTrialFormValues(form);
        lockExistingProjectForm(index);
        enablePal(index);
        alert(`Existing trial "${form.name}" was added to the trial list.`);
      },
      error: function(xhr, __, error) {
        console.error('Failed to add existing trial:', error, xhr?.responseText);
        alert('Could not add the selected existing trial.');
      },
      complete: function() {
        if (btn) {
          btn.disabled = false;
          btn.textContent = 'Add Existing Trial';
        }
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
      <button type="button" id="rotate-trial-cw${i}" class="h-8 px-2 bg-gray-700 text-white rounded hover:bg-gray-800 text-lg leading-none" title="Rotate clockwise" aria-label="Rotate clockwise">
        &#8635;
      </button>
      <button type="button" id="rotate-trial-ccw${i}" class="h-8 px-2 bg-gray-700 text-white rounded hover:bg-gray-800 text-lg leading-none" title="Rotate counter-clockwise" aria-label="Rotate counter-clockwise">
        &#8634;
      </button>
    `;

    wrap.appendChild(box);
    wrap.appendChild(controls);
    qs('#trial-boxes').appendChild(wrap);
    qs(`#rotate-trial-cw${i}`)?.addEventListener('click', () => rotateTrialFromPalette(i, 'cw'));
    qs(`#rotate-trial-ccw${i}`)?.addEventListener('click', () => rotateTrialFromPalette(i, 'ccw'));

    // if(document.querySelector(`.trial-group[data-trial="${i}"]`)) disablePal(i);
    if (lockedTrialForms.has(i)) {
      disablePal(i);
    } else {
      disablePal(i);
    }
  }

  function rotateTrialFromPalette(i, direction = 'cw') {
    const roots = [...new Set(qsa(`.trial-group[data-trial="${i}"]`).map(group => group.dataset.root))];
    if (!roots.length) {
      alert('Place this trial in the grid before rotating it.');
      return;
    }

    const root = roots[0];
    if (isLockedRoot(root)) {
      alert('This trial is part of a saved layout and cannot be rotated.');
      return;
    }

    transposeTrial(root, direction);
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
          alert("Could not load Accessions List");
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
          placeholder: 'Select an accessions list',
          allowClear: true,
          width: '100%',
          dropdownParent: $select.closest('label')
        });
        if (pendingValue) {
          $select.val(String(pendingValue)).trigger('change');
        }
        if (lockedTrialForms.has(i) || existingProjectTrials.has(i)) {
          $select.prop('disabled', true).trigger('change.select2');
        }

        // Optional: trigger callback if pre-selected
        if (pendingValue && onSelectedCallback && $select.val() !== String(pendingValue)) {
          onSelectedCallback(pendingValue);
        }
      },
      error: function(xhr, status, error) {
        console.error("Error loading Accessions List:", status, error);
        $select.html(`<option value="">Failed to load</option>`);
        alert("Error loading Accessions List.");
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
        if (lockedTrialForms.has(i) || existingProjectTrials.has(i)) {
          $select.prop('disabled', true).trigger('change.select2');
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
      plot_width:           $(`#tplotwidth${i}`).val(),
      plot_length:          $(`#tplotlength${i}`).val(),

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
      if (!response.success) {
        if (btn) {
          btn.classList.remove('bg-blue-600', 'hover:bg-blue-700');
          btn.classList.add('bg-red-600', 'hover:bg-red-700');
          btn.textContent = 'Error';
        }
        alert(response.error || 'Error generating design.');
        return;
      }
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
      const response = err?.responseJSON || {};
      alert(response.error || 'Error generating design.');
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

    let rowsWanted = cached.n_row;
    let colsWanted = cached.n_col;
    let plotDesign = cached.design;
    let totalPlots = rowsWanted * colsWanted;

    if (src === 'grid') {
      const parts = qsa(`.trial-group[data-root="${root}"]`);
      const firstPart = parts[0];
      const boxes = parts
        .flatMap(part => [...part.querySelectorAll('.trial-box')])
        .sort((a, b) => (+a.dataset.designIndex - +b.dataset.designIndex));

      rowsWanted = +firstPart?.dataset.rowsWanted || rowsWanted;
      colsWanted = +firstPart?.dataset.colsWanted || colsWanted;
      totalPlots = boxes.length || totalPlots;
      plotDesign = boxes.map(box => ({
        plot_id: box.dataset.plotId,
        plot_name: box.dataset.plotName,
        plot_number: box.dataset.plotNumber,
        original_plot_number: box.dataset.originalPlotNumber || box.dataset.plotNumber,
        block: box.dataset.block,
        accession_name: box.dataset.accessionName,
        is_control: box.dataset.isControl
      }));
    }

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
      total: totalPlots,
      rowStart: row,
      colStart: col,
      colour,
      rootId: src === 'grid' ? root : null,
      ignoreRoot: src === 'grid' ? root : null,
      design: plotDesign
    });

    if (!coords || !coords.length) {
      if (loading) loading.classList.add('hidden');
      return;
    }

    if (cached.existing_project_id) {
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

  async function handleTrialPlotClick(e){
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
      accession = await chooseFillerAccession(box.dataset.fillerAccession || standard || '');
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
      plot_id: box.dataset.plotId,
      plot_name: box.dataset.plotName,
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

    const root   = rootId || nextRootId();
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

    if (!existingProjectTrials.has(Number(tn))) {
      plotDesign = assignPlotNumbers(plotDesign, settings);
    }
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
        b.dataset.row  = rr;          // for recoloring later
        b.dataset.col  = col;
        b.dataset.designIndex = designIndex;
        b.dataset.plotId = meta.plot_id || '';
        b.dataset.plotName = meta.plot_name || '';
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
        appendRemoveButton(g, root, tn);

        /* rotate button (one per root) */
        const tp = document.createElement('div');
        tp.className = 'transpose-btn';
        tp.textContent = 'R';
        tp.title = 'Rotate trial clockwise';
        tp.onclick = () => transposeTrial(root, 'cw');
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

  function plotBoxMeta(box) {
    const meta = {
      row: Number(box.dataset.row),
      col: Number(box.dataset.col),
      designIndex: Number(box.dataset.designIndex) || 0,
      plotNumber: box.dataset.plotNumber || '',
      plotId: box.dataset.plotId || '',
      plotName: box.dataset.plotName || '',
      originalPlotNumber: box.dataset.originalPlotNumber || box.dataset.plotNumber || '',
      block: box.dataset.block || 1,
      isControl: box.dataset.isControl || '0',
      accessionName: box.dataset.accessionName || ''
    };
    if (box.dataset.fillerAccession) meta.fillerAccession = box.dataset.fillerAccession;
    return meta;
  }

  function rotatedTrialCells(root, direction) {
    const boxes = qsa(`.trial-group[data-root="${root}"] .trial-box`)
      .map(plotBoxMeta)
      .filter(cell => !Number.isNaN(cell.row) && !Number.isNaN(cell.col));

    if (!boxes.length) return null;

    const rows = boxes.map(cell => cell.row);
    const cols = boxes.map(cell => cell.col);
    const minR = Math.min(...rows);
    const minC = Math.min(...cols);
    const maxR = Math.max(...rows);
    const maxC = Math.max(...cols);
    const curH = maxR - minR + 1;
    const curW = maxC - minC + 1;

    const cells = boxes.map(cell => {
      const relR = cell.row - minR;
      const relC = cell.col - minC;
      const rotated = Object.assign({}, cell);

      if (direction === 'ccw') {
        rotated.row = minR + (curW - 1 - relC);
        rotated.col = minC + relR;
      } else {
        rotated.row = minR + relC;
        rotated.col = minC + (curH - 1 - relR);
      }

      return rotated;
    });

    return {
      minR,
      minC,
      rowsWanted: curW,
      colsWanted: curH,
      cells
    };
  }

  function rotationHasConflict(cells, ignoreRoot) {
    return cells.some(cell => {
      if (cell.row < 0 || cell.col < 0 || cell.row >= totalRows || cell.col >= totalCols) return true;
      const k = key(cell.row, cell.col);
      if (cellIsUnused(cell.row, cell.col) || manualBorders.has(k) || fillerPlots.has(k)) return true;
      return qsa('.trial-box').some(box => {
        const group = box.closest('.trial-group');
        if (group?.dataset.root === ignoreRoot) return false;
        return Number(box.dataset.row) === cell.row && Number(box.dataset.col) === cell.col;
      });
    });
  }

  function drawTrialFromCells({ root, tn, rowStart, colStart, rowsWanted, colsWanted, colour, cells }) {
    qsa(`.trial-group[data-root="${root}"]`).forEach(el => el.remove());

    const rowsMap = {};
    cells.forEach(cell => {
      if (!rowsMap[cell.row]) rowsMap[cell.row] = [];
      rowsMap[cell.row].push(cell);
    });

    Object.entries(rowsMap).forEach(([row, rowCells]) => {
      rowCells.sort((a, b) => a.col - b.col);
      let segment = [];

      rowCells.forEach(cell => {
        if (segment.length && cell.col !== segment[segment.length - 1].col + 1) {
          createCellSegment(+row, segment);
          segment = [];
        }
        segment.push(cell);
      });

      if (segment.length) createCellSegment(+row, segment);
    });

    selectTrial(root);

    function createCellSegment(row, segmentCells) {
      const start = segmentCells[0].col;
      const seg = segmentCells.length;
      const g = document.createElement('div');

      g.className = 'trial-group';
      g.dataset.trial = tn;
      g.dataset.root = root;
      g.dataset.row = row;
      g.dataset.col = start;
      g.dataset.rowsWanted = rowsWanted;
      g.dataset.colsWanted = colsWanted;
      g.dataset.anchorRow = rowStart;
      g.dataset.anchorCol = colStart;

      g.style.left = `${(start + 1) * STEP}px`;
      g.style.top = `${(row + 1) * STEP}px`;
      g.style.width = `${seg * STEP - GAP}px`;
      g.style.height = `${CELL}px`;
      g.style.gridTemplateColumns = `repeat(${seg}, ${CELL}px)`;

      g.draggable = true;
      g.ondragstart = startDrag;
      g.tabIndex = 0;
      g.addEventListener('click', e => {
        e.stopPropagation();
        selectTrial(root);
      });

      segmentCells.forEach(cell => {
        const b = document.createElement('div');
        b.className = 'trial-box';
        b.draggable = true;
        b.ondragstart = startDrag;
        b.dataset.row = cell.row;
        b.dataset.col = cell.col;
        b.dataset.designIndex = cell.designIndex;
        b.dataset.plotId = cell.plotId || '';
        b.dataset.plotName = cell.plotName || '';
        b.dataset.plotNumber = cell.plotNumber || (cell.designIndex + 1);
        b.dataset.originalPlotNumber = cell.originalPlotNumber || cell.plotNumber || (cell.designIndex + 1);
        b.dataset.block = cell.block || 1;
        b.dataset.isControl = String(cell.isControl || 0);
        b.dataset.accessionName = cell.accessionName || '';
        if (cell.fillerAccession) {
          b.dataset.fillerAccession = cell.fillerAccession;
          b.classList.add('filler-applied');
        }
        b.addEventListener('click', handleTrialPlotClick);
        b.addEventListener('mouseenter', showPlotTooltip);
        b.addEventListener('mousemove', movePlotTooltip);
        b.addEventListener('mouseleave', hidePlotTooltip);
        applyPlotVisual(b, colour);
        g.appendChild(b);
      });

      if (!qs(`[data-root="${root}"] .remove-btn`)) {
        appendRemoveButton(g, root, tn);

        const tp = document.createElement('div');
        tp.className = 'transpose-btn';
        tp.textContent = 'R';
        tp.title = 'Rotate trial clockwise';
        tp.onclick = () => transposeTrial(root, 'cw');
        g.appendChild(tp);
      }

      qs('#farm-grid').appendChild(g);
    }
  }

  /* Rotate 90 degrees in either direction around the current footprint. */
  function transposeTrial(root, direction = 'cw'){
    if (isLockedRoot(root)) {
      alert('This trial is part of a saved layout and cannot be changed.');
      return;
    }
    const parts = [...document.querySelectorAll(`.trial-group[data-root="${root}"]`)];
    if(!parts.length) return;

    const rotation = rotatedTrialCells(root, direction === 'ccw' ? 'ccw' : 'cw');
    if (!rotation || rotationHasConflict(rotation.cells, root)) {
      alert('Cannot rotate - no free space at current position.');
      return;
    }

    const tn = parts[0].dataset.trial;
    const colour = colourFor(tn);
    drawTrialFromCells({
      root,
      tn,
      rowStart: rotation.minR,
      colStart: rotation.minC,
      rowsWanted: rotation.rowsWanted,
      colsWanted: rotation.colsWanted,
      colour,
      cells: rotation.cells
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
    const currentForms = new Map(serializeTrialForms().map(form => [form.trial_index, form]));
    qs('#trial-details').innerHTML='';
    qs('#trial-boxes').innerHTML='';
    const lockedMax = lockedTrialForms.size ? Math.max(...lockedTrialForms.keys()) : 0;
    const existingMax = existingProjectTrials.size ? Math.max(...existingProjectTrials.keys()) : 0;
    const n = Math.max(+qs('#num-trials')?.value || 0, lockedMax, existingMax);
    setInputValue('num-trials', n);
    const countLabel = qs('#trial-count-label');
    if (countLabel) countLabel.textContent = n ? `${n} trial${n === 1 ? '' : 's'} added.` : 'No trials added yet.';
    for(let i=1;i<=n;i++){
      addTrialForm(i);
      addPaletteBox(i);
      if (lockedTrialForms.has(i)) {
        restoreTrialFormValues(lockedTrialForms.get(i));
        lockTrialForm(i, true);
        disablePal(i);
        setTimeout(() => {
          restoreTrialFormValues(lockedTrialForms.get(i));
          lockTrialForm(i, true);
          disablePal(i);
        }, 750);
      }
      if (existingProjectTrials.has(i)) {
        restoreTrialFormValues(existingProjectTrials.get(i));
        lockExistingProjectForm(i);
        if (trialDesignCache[i]) enablePal(i);
      } else if (!lockedTrialForms.has(i) && currentForms.has(i)) {
        restoreTrialFormValues(currentForms.get(i));
        if (trialDesignCache[i]) enablePal(i);
        setTimeout(() => {
          restoreTrialFormValues(currentForms.get(i));
          if (trialDesignCache[i]) enablePal(i);
        }, 300);
      }
    }
    if (layoutContextLocked) lockLayoutContext(true);
  }

  function addTrialFromButton() {
    const next = (+qs('#num-trials')?.value || 0) + 1;
    setInputValue('num-trials', next);
    makeTrials();
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
        plot_width: qs(`#tplotwidth${i}`)?.value || '',
        plot_length: qs(`#tplotlength${i}`)?.value || '',
        block_rows: qs(`#tblockrows${i}`)?.value || '',
        block_cols: qs(`#tblockcols${i}`)?.value || '',
        super_rows: qs(`#tsuperrows${i}`)?.value || '',
        super_cols: qs(`#tsupercols${i}`)?.value || '',
        existing_project_id: existingProjectTrials.get(i)?.project_id || lockedTrialForms.get(i)?.existing_project_id || ''
      });
    }

    return trials;
  }

  function serializePlacedTrials() {
    const roots = {};

    qsa('.trial-group').forEach(group => {
      const root = group.dataset.root;
      if (!roots[root]) {
        const trialIndex = +group.dataset.trial;
        roots[root] = {
          root,
          trial_index: trialIndex,
          existing_project_id: existingProjectTrials.get(trialIndex)?.project_id || lockedTrialForms.get(trialIndex)?.existing_project_id || '',
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
          plot_id: box.dataset.plotId || '',
          plot_name: box.dataset.plotName || '',
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
    const fallbackFarm = savedLayoutContext?.farm || {};
    const fallbackBreedingProgram = savedLayoutContext?.breeding_program || {};
    const farmLocationId = selectedValue(farm) || validValue(fallbackFarm.location_id);
    const breedingProgramId = selectedValue(breedingProgram) || validValue(fallbackBreedingProgram.program_id);
    const year = String(qs('#layout-year')?.value || savedLayoutContext?.year || '').trim();
    const season = String(qs('#layout-season')?.value || savedLayoutContext?.season || '').trim();

    return {
      schema_version: 1,
      saved_at: new Date().toISOString(),
      year,
      season,
      breeding_program: {
        program_id: breedingProgramId,
        name: breedingProgramId ? (breedingProgram?.selectedOptions?.[0]?.textContent || fallbackBreedingProgram.name || '') : ''
      },
      farm: {
        location_id: farmLocationId,
        name: farmLocationId ? (farm?.selectedOptions?.[0]?.textContent || fallbackFarm.name || '') : ''
      },
      field: {
        rows: +qs('#farm-rows')?.value || 0,
        cols: +qs('#farm-cols')?.value || 0
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

  function trialDisplayName(layout, trialIndex) {
    const form = (layout.trial_forms || []).find(item => String(item.trial_index) === String(trialIndex)) || {};
    return sanitizeTrialName(form.name) || `Trial_${trialIndex}`;
  }

  function chartColour(index) {
    const palette = [
      '#2563eb', '#dc2626', '#16a34a', '#ca8a04', '#7c3aed',
      '#0891b2', '#db2777', '#4b5563', '#ea580c', '#059669'
    ];
    return palette[index % palette.length];
  }

  function drawPieChart(canvas, legend, rows) {
    if (!canvas || !legend) return;
    const ctx = canvas.getContext('2d');
    const width = canvas.width;
    const height = canvas.height;
    ctx.clearRect(0, 0, width, height);
    legend.innerHTML = '';

    const data = rows.filter(row => Number(row.value) > 0);
    const total = data.reduce((sum, row) => sum + Number(row.value), 0);
    if (!total) {
      ctx.fillStyle = '#6b7280';
      ctx.font = '16px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('No layout data to display', width / 2, height / 2);
      return;
    }

    const cx = width / 2;
    const cy = height / 2;
    const radius = Math.min(width, height) * 0.38;
    let start = -Math.PI / 2;

    data.forEach(row => {
      const slice = (Number(row.value) / total) * Math.PI * 2;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, radius, start, start + slice);
      ctx.closePath();
      ctx.fillStyle = row.color;
      ctx.fill();
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 2;
      ctx.stroke();
      start += slice;
    });

    data.forEach(row => {
      const pct = ((Number(row.value) / total) * 100).toFixed(1);
      const item = document.createElement('div');
      item.className = 'flex items-center gap-2';
      item.innerHTML = `
        <span class="inline-block w-3 h-3 rounded-sm" style="background:${row.color}"></span>
        <span>${row.label}: ${row.value} (${pct}%)</span>
      `;
      legend.appendChild(item);
    });
  }

  function generateLayoutGraphics() {
    const layout = collectLayoutJson();
    const panel = qs('#layout-graphics-panel');
    if (!panel) return;

    const trialRows = (layout.placed_trials || []).map((trial, index) => ({
      label: trialDisplayName(layout, trial.trial_index),
      value: (trial.plots || []).length,
      color: chartColour(index)
    })).filter(row => row.value > 0);

    let checks = 0;
    let treatments = 0;
    let fillers = 0;
    const occupied = new Set();
    (layout.placed_trials || []).forEach(trial => {
      (trial.plots || []).forEach(plot => {
        occupied.add(key((+plot.row || 1) - 1, (+plot.col || 1) - 1));
        if (plot.filler_accession) fillers++;
        else if (String(plot.is_control) === '1') checks++;
        else treatments++;
      });
    });

    const rows = +layout.field.rows || 0;
    const cols = +layout.field.cols || 0;
    let unused = 0;
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        if (cellIsUnused(r, c)) unused++;
      }
    }

    const borders = layout.manual_borders?.length || 0;
    const totalCells = rows * cols;
    const usedCells = occupied.size + borders + unused;
    const emptyAvailable = Math.max(0, totalCells - usedCells);
    const usageRows = [
      { label: 'Treatments', value: treatments, color: '#2563eb' },
      { label: 'Checks', value: checks, color: '#dc2626' },
      { label: 'Borders', value: borders, color: '#16a34a' },
      { label: 'Unutilized plots', value: unused, color: '#9ca3af' },
      { label: 'Available empty', value: emptyAvailable, color: '#e5e7eb' }
    ];
    if (fillers) usageRows.splice(2, 0, { label: 'Fillers', value: fillers, color: '#f59e0b' });

    panel.classList.remove('hidden');
    drawPieChart(qs('#trial-area-chart'), qs('#trial-area-legend'), trialRows);
    drawPieChart(qs('#field-usage-chart'), qs('#field-usage-legend'), usageRows);
  }

  ({ initDownloadTools, plantingSettings } = createDownloadTools({
    qs,
    key,
    sanitizeTrialName,
    collectLayoutJson
  }));

  function restoreSet(items) {
    return new Set((items || []).map(item => key((+item.row || 1) - 1, (+item.col || 1) - 1)));
  }

  function clearPlacedTrials() {
    qsa('.trial-group').forEach(el => el.remove());
    selectedRoot = null;
  }

  function removeTrialRootFromView(root, trialIndex) {
    qsa(`[data-root="${root}"]`).forEach(el => el.remove());
    lockedTrialRoots.delete(root);
    if (!qs(`.trial-group[data-trial="${trialIndex}"]`)) {
      lockedTrialForms.delete(+trialIndex);
      databaseSavedTrialIndexes.delete(String(trialIndex));
      enablePal(trialIndex);
    }
    if (selectedRoot === root) selectedRoot = null;
  }

  function handleRemoveTrialRoot(root, trialIndex) {
    if (isLockedRoot(root)) {
      deleteSavedTrialFromLayout(root, trialIndex);
      return;
    }

    const loading = qs('#grid-loader');
    if (loading) {
      loading.querySelector('span').textContent = 'Removing trial...';
      loading.classList.remove('hidden');
      setTimeout(() => {
        removeTrialRootFromView(root, trialIndex);
        loading.classList.add('hidden');
      }, 50);
    } else {
      removeTrialRootFromView(root, trialIndex);
    }
  }

  function appendRemoveButton(group, root, trialIndex) {
    if (qs(`[data-root="${root}"] .remove-btn`)) return;
    const rm = document.createElement('div');
    rm.className = 'remove-btn';
    rm.textContent = 'x';
    rm.title = 'Remove trial from layout view';
    rm.onclick = () => handleRemoveTrialRoot(root, trialIndex);
    group.appendChild(rm);
  }

  function deleteSavedTrialFromLayout(root, trialIndex) {
    if (!userIsCurator) {
      alert('Only curators can remove saved trials from a layout.');
      return;
    }

    const layout = collectLayoutJson();
    if (!layout.farm.location_id || !layout.year) {
      alert('Select location and year before removing a saved trial.');
      return;
    }
    if (!window.confirm('Remove this trial from the saved layout view? This does not delete the trial from the database.')) {
      return;
    }

    $.ajax({
      url: '/ajax/trialallocation/delete_layout_trial',
      method: 'POST',
      dataType: 'json',
      data: {
        location_id: layout.farm.location_id,
        year: layout.year,
        season: layout.season || '',
        root,
        trial_index: trialIndex
      },
      success: function(response) {
        if (response.success) {
          removeTrialRootFromView(root, trialIndex);
          loadExistingTrialsForContext();
          alert('Trial removed from the saved layout view.');
        } else {
          alert(response.error || 'Could not remove trial from the saved layout view.');
        }
      },
      error: function(_, __, error) {
        console.error('Delete saved trial failed:', error);
        alert('Could not remove trial from the saved layout view.');
      }
    });
  }

  function deleteCurrentLayoutView() {
    if (!userIsCurator) {
      alert('Only curators can delete a saved layout view.');
      return;
    }

    const layout = collectLayoutJson();
    if (!layout.farm.location_id || !layout.year) {
      alert('Select location and year before deleting the layout view.');
      return;
    }
    if (!window.confirm('Delete the whole saved layout view for this location, year, and season? This does not delete the trials from the database.')) {
      return;
    }

    $.ajax({
      url: '/ajax/trialallocation/delete_layout',
      method: 'POST',
      dataType: 'json',
      data: {
        location_id: layout.farm.location_id,
        year: layout.year,
        season: layout.season || ''
      },
      success: function(response) {
        if (response.success) {
          clearPlacedTrials();
          lockedTrialRoots = new Set();
          lockedTrialForms = new Map();
          databaseSavedTrialIndexes = new Set();
          savedLayoutContext = null;
          layoutContextLocked = false;
          lockLayoutContext(false);
          makeTrials();
          loadExistingTrialsForContext();
          alert('Saved layout view deleted.');
        } else {
          alert(response.error || 'Could not delete the saved layout view.');
        }
      },
      error: function(_, __, error) {
        console.error('Delete layout failed:', error);
        alert('Could not delete the saved layout view.');
      }
    });
  }

  function drawSavedTrial(savedTrial, lockLoadedTrial = false) {
    const tn = savedTrial.trial_index;
    const root = savedTrial.root || nextRootId();
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
      if (savedTrial.existing_project_id) g.dataset.existingProjectId = savedTrial.existing_project_id;
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
        b.dataset.plotId = plot.plot_id || '';
        b.dataset.plotName = plot.plot_name || '';
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

      appendRemoveButton(g, root, tn);
      qs('#farm-grid').appendChild(g);
      if (lockLoadedTrial) {
        lockedTrialRoots.add(root);
        lockTrialVisuals(root, true);
        lockTrialForm(tn, true);
      }
      disablePal(tn);
    }
  }

  function applySavedLayout(layout) {
    if (!layout) return;

    applyingSavedLayout = true;
    try {
    savedLayoutContext = {
      year: layout.year || '',
      season: layout.season || '',
      farm: Object.assign({}, layout.farm || {}),
      breeding_program: Object.assign({}, layout.breeding_program || {})
    };
    lockedTrialRoots = new Set();
    const placedExistingProjectByTrial = new Map((layout.placed_trials || [])
      .filter(trial => trial.existing_project_id)
      .map(trial => [trial.trial_index, trial.existing_project_id]));
    lockedTrialForms = new Map((layout.trial_forms || []).map(form => {
      const existingProjectId = form.existing_project_id || placedExistingProjectByTrial.get(form.trial_index) || '';
      return [form.trial_index, Object.assign({}, form, { existing_project_id: existingProjectId })];
    }));
    databaseSavedTrialIndexes = new Set((layout.placed_trials || []).map(trial => String(trial.trial_index)));
    existingProjectTrials = new Map();
    lockLayoutContext(true);
    setInputValue('num-trials', (layout.trial_forms || []).length);
    makeTrials();

    setSelectValue('farm_dropdown', layout.farm?.location_id);
    setInputValue('layout-year', layout.year);
    setSelectValue('layout-season', layout.season);
    setSelectValue('breeding_program_dropdown', layout.breeding_program?.program_id);
    setInputValue('farm-rows', layout.field?.rows);
    setInputValue('farm-cols', layout.field?.cols);
    setInputValue('unused-rows', layout.unused_rows);
    setInputValue('unused-cols', layout.unused_cols);

    (layout.trial_forms || []).forEach(form => {
      if (!form.plot_width && layout.field?.plot_width) form.plot_width = layout.field.plot_width;
      if (!form.plot_length && layout.field?.plot_length) form.plot_length = layout.field.plot_length;
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
    (layout.trial_forms || []).forEach(form => lockTrialForm(form.trial_index, true));
    loadExistingTrialsForContext();
    renderVisibleCells(lastRow, lastCol);
    } finally {
      applyingSavedLayout = false;
    }
  }

  function saveCurrentLayout() {
    const layout = collectLayoutJson();
    if (!layout.farm.location_id || !layout.year) {
      alert('Select location and year before saving the layout.');
      return;
    }
    if (!requireValidLayoutYear()) return;

    saveLayoutView(layout)
      .done(function(response) {
        if (!response.success) {
          alert(response.error || 'Could not save layout.');
          return;
        }
        markLayoutViewSaved(layout);
        alert('Layout saved.');
      })
      .fail(function(_, __, error) {
        console.error('Save layout failed:', error);
        alert('Could not save layout.');
      });
  }

  function saveLayoutView(layout) {
    return $.ajax({
      url: '/ajax/trialallocation/save_layout',
      method: 'POST',
      dataType: 'json',
      data: { layout: JSON.stringify(layout) }
    });
  }

  function markLayoutViewSaved(layout) {
    savedLayoutContext = {
      year: layout.year || '',
      season: layout.season || '',
      farm: Object.assign({}, layout.farm || {}),
      breeding_program: Object.assign({}, layout.breeding_program || {})
    };
    lockLayoutContext(true);
    lockPlacedTrials(true);
  }

  function restoreSaveTrialsButton(saveButton) {
    if (saveButton) {
      saveButton.disabled = false;
      saveButton.textContent = 'Save Layout Trials in Database';
      saveButton.classList.remove('opacity-70', 'cursor-wait');
    }
  }

  function trialSaveSuccessMessage(response) {
    const names = (response.trials || []).map(trial => `${trial.name} (${trial.trial_id})`).join('\n');
    const updated = response.existing_trials_updated || 0;
    if (names && updated) return `Trials saved:\n${names}\n\nExisting trial coordinate updates: ${updated}`;
    if (names) return `Trials saved:\n${names}`;
    if (updated) return `Existing trial coordinate updates saved: ${updated}`;
    return 'Trials saved in the database.';
  }

  function finishTrialsDatabaseSave(layout, newTrialLayout, response, saveButton) {
    lockLayoutContext(true);
    const savedIndexes = new Set((newTrialLayout.placed_trials || []).map(trial => String(trial.trial_index)));
    savedIndexes.forEach(index => databaseSavedTrialIndexes.add(index));
    const savedRoots = (layout.placed_trials || [])
      .filter(trial => savedIndexes.has(String(trial.trial_index)))
      .map(trial => trial.root);
    lockPlacedTrials(true, savedRoots);

    const message = trialSaveSuccessMessage(response);
    if (saveButton) saveButton.textContent = 'Saving Layout...';

    saveLayoutView(layout)
      .done(function(layoutResponse) {
        if (layoutResponse.success) {
          markLayoutViewSaved(layout);
          alert(`${message}\n\nLayout view saved.`);
        } else {
          alert(`${message}\n\nCould not save layout view: ${layoutResponse.error || 'Unknown error'}`);
        }
      })
      .fail(function(xhr, __, error) {
        console.error('Save layout after trial database save failed:', error, xhr?.responseText);
        alert(`${message}\n\nCould not save layout view.`);
      })
      .always(function() {
        restoreSaveTrialsButton(saveButton);
      });
  }

  function saveTrialsInDatabase() {
    const layout = collectLayoutJson();
    const newTrialLayout = filterLayoutToUnsavedDatabaseTrials(layout);
    const saveButton = qs('#save-trials-db-btn');

    if (!layout.farm.location_id || !layout.year) {
      alert('Select location and year before saving the trials.');
      return;
    }
    if (!requireValidLayoutYear()) return;
    const hasNewTrialToCreate = (newTrialLayout.placed_trials || []).some(trial => !trial.existing_project_id);
    if (hasNewTrialToCreate && !layout.breeding_program.program_id) {
      alert('Select a breeding program before saving the trials.');
      return;
    }
    if (!newTrialLayout.placed_trials.length) {
      alert('There are no new trials or existing-trial coordinate updates to save in the database.');
      return;
    }
    const placedTrialIndexes = new Set(newTrialLayout.placed_trials.map(trial => String(trial.trial_index)));
    const missingTrials = (layout.trial_forms || [])
      .filter(form => !form.existing_project_id)
      .filter(form => !isDatabaseSavedTrialIndex(form.trial_index))
      .filter(form => !placedTrialIndexes.has(String(form.trial_index)));
    if (missingTrials.length) {
      const names = missingTrials.map(form => sanitizeTrialName(form.name) || `Trial ${form.trial_index}`).join(', ');
      alert(`These trials are not placed in the grid yet: ${names}. Place all trials before saving them in the database.`);
      return;
    }
    if (!window.confirm('Save new trial(s) and update coordinates for placed existing trial(s) in the database?')) {
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
      data: { layout: JSON.stringify(newTrialLayout) },
      success: function(response) {
        if (response.success) {
          finishTrialsDatabaseSave(layout, newTrialLayout, response, saveButton);
        } else {
          alert(response.error || 'Could not save trials in the database.');
          restoreSaveTrialsButton(saveButton);
        }
      },
      error: function(xhr, __, error) {
        console.error('Save trials failed:', error, xhr?.responseText);
        alert('Could not save trials in the database.');
        restoreSaveTrialsButton(saveButton);
      }
    });
  }

  function loadExistingLayoutForSelection() {
    if (applyingSavedLayout) return;

    const locationId = qs('#farm_dropdown')?.value;
    const year = qs('#layout-year')?.value;
    const season = qs('#layout-season')?.value;

    if (!locationId || !year) return;
    if (!isValidLayoutYear(year)) return;

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
        if (!response.found) {
          savedLayoutContext = null;
          return;
        }

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
    initDownloadTools();
    initAccessionAutocomplete('#border-accession', 'Search border accession');
    initAccessionAutocomplete('#filler-accession', 'Search filler accession');
    loadExistingTrialsForContext();
    makeTrials();
    drawGrid();
    qs('#farm-rows').addEventListener('change',drawGrid);
    qs('#farm-cols').addEventListener('change',drawGrid);
    qs('#edit-toggle').addEventListener('change',()=>{
      if(qs('#edit-toggle').checked) {
        qs('#border-toggle').checked=false;
        if (qs('#filler-toggle')) qs('#filler-toggle').checked=false;
      }
    });
    qs('#border-toggle').addEventListener('change',()=>{
      if(qs('#border-toggle').checked) {
        qs('#edit-toggle').checked=false;
        if (qs('#filler-toggle')) qs('#filler-toggle').checked=false;
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



    qs('#add-trial-btn')?.addEventListener('click', addTrialFromButton);
    qs('#num-trials')?.addEventListener('change',makeTrials);
    qs('#add-existing-trial-btn')?.addEventListener('click', addExistingTrialToPalette);
    qs('#delete-layout-btn')?.addEventListener('click', deleteCurrentLayoutView);
    qs('#save-layout-btn')?.addEventListener('click', saveCurrentLayout);
    qs('#save-trials-db-btn')?.addEventListener('click', saveTrialsInDatabase);
    qs('#generate-layout-graphics-btn')?.addEventListener('click', generateLayoutGraphics);
    qs('#layout-year')?.addEventListener('change', () => {
      loadExistingLayoutForSelection();
      loadExistingTrialsForContext();
    });
    qs('#layout-season')?.addEventListener('change', loadExistingLayoutForSelection);
    $('#farm_dropdown').on('change', () => {
      loadExistingLayoutForSelection();
      loadExistingTrialsForContext();
    });
  };
}
