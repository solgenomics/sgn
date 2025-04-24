
import '../legacy/jquery.js';
import '../legacy/d3/d3v4Min.js';

document.addEventListener('DOMContentLoaded', () => {

  /******** global state ********/
  let gridReady = false;
  let lastUnusedRows = '';
  let lastUnusedCols = '';

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
      link.download = 'farm_field_grid.jpg';
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
      link.download = 'farm_field_grid_full.jpg';
      link.href = canvas.toDataURL('image/jpeg');
      link.click();
    });
  });

  /******** grid ********/
  function drawGrid() {
    const rows   = +qs('#farm-rows')?.value || 0;
    const cols   = +qs('#farm-cols')?.value || 0;
    const grid   = qs('#farm-grid');
    const loader = qs('#grid-loader');

    gridReady = false;
    loader?.classList.remove('hidden');

    grid.classList.toggle('edit-mode', qs('#edit-toggle').checked);
    grid.innerHTML = '';
    grid.style.gridTemplateColumns = `repeat(${cols + 1}, ${CELL}px)`;
    grid.style.gridTemplateRows    = `repeat(${rows + 1}, ${CELL}px)`;

    const makeHeader = (cls, val = '') => {
      const d = document.createElement('div');
      d.className = `grid-cell header-cell ${cls}`;
      if (val) d.textContent = val;
      return d;
    };

    const fragment = document.createDocumentFragment();
    fragment.appendChild(makeHeader('corner'));
    for (let c = 0; c < cols; c++) fragment.appendChild(makeHeader('col-header', c + 1));
    grid.appendChild(fragment);

    let currentRow = 0;
    const chunkSize = 10;

    function drawChunk() {
      const frag = document.createDocumentFragment();
      for (let r = currentRow; r < Math.min(currentRow + chunkSize, rows); r++) {
        frag.appendChild(makeHeader('row-header', r + 1));
        for (let c = 0; c < cols; c++) {
          frag.appendChild(createCell(r, c));
        }
      }
      grid.appendChild(frag);
      currentRow += chunkSize;
      if (currentRow < rows) {
        requestAnimationFrame(drawChunk);
      } else {
        loader?.classList.add('hidden');
        repositionTrials();
        gridReady = true;
      }
    }

    drawChunk();
  }


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
    const cell = e.target;
    const r = +cell.dataset.row;
    const c = +cell.dataset.col;
    const k = key(r, c);

    const editMode = qs('#edit-toggle').checked;
    const borderMode = qs('#border-toggle').checked;

    if (!editMode && !borderMode) return;

    if (editMode) {
      if (cellIsUnused(r, c)) {
        manualBlock.delete(k);
        manualAllow.add(k);
      } else {
        manualAllow.delete(k);
        manualBlock.add(k);
      }
      // Just update this cell background
      const unused = cellIsUnused(r, c);
      cell.style.background = unused ? '#d1d5db' : '#ffffff';
    }

    if (borderMode) {
      if (manualBorders.has(k)) {
        manualBorders.delete(k);
        cell.classList.remove('border-plot');
        cell.textContent = '';
      } else {
        manualBorders.add(k);
        cell.classList.add('border-plot');
        cell.textContent = 'B';
      }
    }
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
            <option>Select type</option>
            <option>Yield Trial</option>
            <option>Phenotyping</option>
            <option>Nursery</option>
          </select>
        </label>
        <label>Trial Design
          <select id='tdesign${i}' class='w-full border rounded px-2 py-1'>
            <option>Select design</option>
            <option>RCBD</option>
            <option>Augmented Row-Column</option>
            <option>Row-Column Design</option>
            <option>Doubly-Resolvable Row-Column</option>
            <option>Un-Replicated Diagonal</option>
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

    // Design toggle logic
    const designSelect = d.querySelector(`#tdesign${i}`);
    const rowcol = d.querySelector(`#rowcol-container${i}`);
    const repsblocks = d.querySelector(`#repsblocks-container${i}`);

    designSelect.addEventListener('change', () => {
      const isRCBD = designSelect.value === 'RCBD';

      repsblocks.innerHTML = isRCBD
        ? `
          <label>Reps / Blocks
            <input id='trepsblocks${i}' type='number' min='1' value='1' class='w-full border rounded px-2 py-1' />
          </label>
          <div></div>
        `
        : `
          <label>Reps
            <input id='treps${i}' type='number' min='1' class='w-full border rounded px-2 py-1' />
          </label>
          <label>Blocks
            <input id='tblocks${i}' type='number' min='1' class='w-full border rounded px-2 py-1' />
          </label>
        `;

      rowcol.innerHTML = isRCBD
        ? `
          <label>Number of Rows per Block
            <input id='tblockrows${i}' type='number' min='1' value='1' class='w-full border rounded px-2 py-1' />
          </label>
          <div></div>
        `
        : `
          <label>Rows
            <input id='trows${i}' type='number' value='1' min='1' class='w-full border rounded px-2 py-1' />
          </label>
          <label>Cols
            <input id='tcols${i}' type='number' value='1' min='1' class='w-full border rounded px-2 py-1' />
          </label>
        `;
    });

    // Load dropdown lists
    loadTreatmentsList(i, null, function (selectedTreatmentListId) {
      loadControlsList(i, selectedTreatmentListId);
    });
  }



  function addPaletteBox(i){
    const box = document.createElement('div');
    box.id = `palette${i}`;
    box.className = `trial-box ${colourFor(i)} bg-opacity-60`;
    box.textContent = `Trial ${i}`;
    box.dataset.trial = i;
    box.draggable = true;
    box.ondragstart = startDrag;
    qs('#trial-boxes').appendChild(box);
    if(document.querySelector(`.trial-group[data-trial="${i}"]`)) disablePal(i);
  }

  /******** getting lists **********/
  function loadTreatmentsList(i, selectedListId = null, onSelectedCallback = null) {
    const $select = $(`#ttreatments${i}`);
    if ($select.length === 0) return;

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
          const selected = (selectedListId && list.list_id == selectedListId) ? 'selected' : '';
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

        // Optional: trigger callback if pre-selected
        if (selectedListId && onSelectedCallback) {
          onSelectedCallback(selectedListId);
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
          if (excludeListId && list.list_id == excludeListId) return; //skip treatment list
          const label = `${list.name} (${list.is_public ? 'Public' : 'Private'})`;
          $select.append(`<option value="${list.list_id}">${label}</option>`);
        });
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
    const design = $(`#tdesign${i}`).val();
    const isRCBD = design === 'RCBD';
    const layoutType = $(`#tlayout${i}`).val();

    const trial = {
      name: $(`#tname${i}`).val(),
      description: $(`#tdesc${i}`).val(),
      type: $(`#ttype${i}`).val(),
      design: design,
      treatment_list_id: $(`#ttreatments${i}`).val(),
      control_list_id: $(`#tcontrols${i}`).val(),
      layout_type: layoutType, 
      reps: isRCBD ? 0 : parseInt($(`#treps${i}`).val()) || 0,
      blocks: isRCBD ? parseInt($(`#trepsblocks${i}`).val()) || 0 : parseInt($(`#tblocks${i}`).val()) || 0,
      rows: isRCBD ? parseInt($(`#tblockrows${i}`).val()) || 0 : parseInt($(`#trows${i}`).val()) || 0,
      cols: parseInt($(`#tcols${i}`).val()) || 0
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
    const rect = el.getBoundingClientRect();
    e.dataTransfer.setData('src', fromPal ? 'pal' : 'grid');
    e.dataTransfer.setData('tn', el.dataset.trial);
    if(!fromPal) e.dataTransfer.setData('root', el.dataset.root);
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

    let col = Math.floor((e.clientX - rect.left - (src === 'grid' ? offX : 0)) / STEP) - 1;
    let row = Math.floor((e.clientY - rect.top  - (src === 'grid' ? offY : 0)) / STEP) - 1;

    if (col < 0 || row < 0) return;

    const name   = qs(`#tname${tn}`)?.value || `Trial ${tn}`;
    const colour = colourFor(tn);

    /* remove previously placed instance of this trial (if dragging from grid) */
    if (src === 'grid') {
      qsa(`.trial-group[data-root="${root}"]`).forEach(el => el.remove());
    }

    /* ───── request design from server ───── */
    generateDesign(tn, row, col)
      .done(function (response) {

        if (!response.success) {
          alert('Design failed: ' + response.error);
          return;
        }

        const rowsWanted = response.n_row;
        const colsWanted = response.n_col;

        /* inner helper does the actual placement + save-back */
        const applyPlacement = (rowsWanted, colsWanted) => {
          const total = rowsWanted * colsWanted;   // rectangular footprint

          const coords = placeTrial({
            tn,
            name,
            rowsWanted,
            colsWanted,
            total,
            rowStart: row,
            colStart: col,
            colour,
            rootId: null,
            design: response.design
          });

          console.log('Generated coords:', coords);
          console.log('Design file:', response.design_file);

          /* save coords back to backend */
          $.ajax({
            url: '/ajax/trialallocation/save_coordinates',
            method: 'POST',
            data: {
              trial: JSON.stringify({
                trial_name: name,
                trial_id: tn,
                coordinates: coords,
                design_file: response.design_file,
                param_file: response.param_file,
                r_output: response.r_output
              })
            },
            success: function (saveResponse) {
              if (saveResponse.success) {
                console.log(`Coordinates for "${name}" saved successfully.`);
                recolorTrialPlots(tn, response.design_file, colour);
              } else {
                console.warn('Save failed: ' + saveResponse.error);
              }
            },
            error: function (xhr, status, error) {
              console.error('Error saving coordinates:', error);
            }
          });
        };

        /* ←─── ACTUALLY RUN IT ───→ */
        applyPlacement(rowsWanted, colsWanted);
      })
      .fail(function (xhr, status, error) {
        console.error('AJAX error:', error);
        alert('Error generating design.');
      });
  }

  
  function lighterColor(base) {
    // drop one Tailwind “step” (e.g. 400→200, 500→300, 900→700)
    return base.replace(/-(\d+)$/, (_, num) => {
      let n = Math.max(+num - 200, 50);
      return '-' + n;
    });
  }


  const farmGridEl = qs('#farm-grid');
  farmGridEl.addEventListener('dragover', e=>e.preventDefault());
  farmGridEl.addEventListener('drop', handleDrop);

  /************* grab coodinates from grd ****************/

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
    return [...document.querySelectorAll('.trial-group')].some(group=>{
      const gr = +group.dataset.row;
      const gc = +group.dataset.col;
      const cols = group.style.gridTemplateColumns.split(' ').length || 1;
      const rows = Math.round(group.offsetHeight / (CELL+GAP));
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
    design,                 // (not changed here)
    rowsPerBlock, blocks    // (not used here yet)
  }) {
    disablePal(tn);

    const root   = rootId || uid();
    const coords = [];

    let r = rowStart,
        c = colStart;

    /* walk row-by-row until we have the required number of plots */
    while (coords.length < total) {

      /* FIX: accept only *usable* cells  ─────────────────────── */
      if (!cellIsUnused(r, c) && !manualBorders.has(key(r, c))) {
        if (trialCellExists(r, c)) {
          alert('Please find another region to place your trial. This is occupied!');
          return;                          // abort placement
        }
        coords.push([r, c]);
      }

      /* advance to next column / row */
      c++;
      if (coords.length % colsWanted === 0) {   // finished a logical row
        c = colStart;
        r++;
      }

      /* safety valve – prevents infinite loop if nothing fits */
      if (r > 1000) {
        alert('Could not place trial: not enough space.');
        return;
      }
    }

    /* group consecutive cells into “segments” so each visual row
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

    /* helper – draw one contiguous horizontal segment */
    function createSeg(rr, start, end) {
      const seg = end - start + 1;
      const g   = document.createElement('div');

      g.className     = 'trial-group';
      g.dataset.trial = tn;
      g.dataset.root  = root;
      g.dataset.row   = rr;
      g.dataset.col   = start;

      g.style.left  = `${(start + 1) * STEP}px`;
      g.style.top   = `${(rr    + 1) * STEP}px`;
      g.style.width = `${seg * STEP - GAP}px`;
      g.style.height= `${CELL}px`;
      g.style.gridTemplateColumns = `repeat(${seg}, ${CELL}px)`;

      g.draggable    = true;
      g.ondragstart  = startDrag;

      /* individual plot boxes */
      for (let i = 0; i < seg; i++) {
        const b = document.createElement('div');
        b.className    = `trial-box ${colour} bg-opacity-60`;
        b.textContent  = name;
        b.draggable    = true;
        b.ondragstart  = startDrag;
        b.dataset.row  = rr;          // for recoloring later
        b.dataset.col  = start + i;
        g.appendChild(b);
      }

      /* one “×” close button per root group */
      if (!qs(`[data-root="${root}"] .remove-btn`)) {
        const rm   = document.createElement('div');
        rm.className = 'remove-btn';
        rm.textContent = '×';
        rm.onclick = () => {
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
      }

      qs('#field-zoom-container').appendChild(g);
    }
    return coords.map(([row, col]) => [row + 1, col + 1]);
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
              cI = idx('col_number'), ctlI = idx('is_control');

        if ([bI, rI, cI, ctlI].includes(-1)) {
          console.error('Design file missing columns');  return;
        }

        /* Map: block # → colour (base or lighter) */
        const blockColour = new Map();

        lines.forEach(l => {
          const f   = l.split('\t');
          const blk = +f[bI];              // 1‑based block number
          const row = +f[rI] - 1;          // to 0‑based
          const col = +f[cI] - 1;
          const ctl = +f[ctlI] === 1;

          const box = document.querySelector(
            `.trial-box[data-row="${row}"][data-col="${col}"]`
          );
          if (!box) return;

          /* strip existing bg‑ & text‑ classes */
          box.className = box.className
            .replace(/\bbg-[^\s]+\b/g, '')
            .replace(/\btext-[^\s]+\b/g, '')
            .trim();

          if (ctl) {
            box.classList.add('bg-blue-900', 'text-white', 'bg-opacity-100');
            return;
          }

          /* decide colour for this block only once */
          if (!blockColour.has(blk)) {
            const colour = (blk % 2 === 0)
              ? lighterColor(baseColour)   // even block → lighter shade
              : baseColour;                // odd block  → base shade
            blockColour.set(blk, colour);
          }
          box.classList.add(blockColour.get(blk), 'bg-opacity-60');
        });
      },

      error: (_, __, err) => console.error('Recolor failed:', err)
    });
  }



  /******** selection drag for unused & borders (logic unchanged) ********/
  let isDragging=false;
  let dragStart=null;
  qs('#farm-grid').addEventListener('mousedown',e=>{
    const cell=e.target.closest('.grid-cell');
    if(!cell||!cell.dataset.row) return;
    const editMode=qs('#edit-toggle').checked;
    const borderMode=qs('#border-toggle').checked;
    if(!editMode && !borderMode) return;
    isDragging=true;
    dragStart={row:+cell.dataset.row,col:+cell.dataset.col};
    e.preventDefault();
  });


  document.addEventListener('mouseup', e => {
    if (!isDragging || !dragStart) return;

    const cell = document.elementFromPoint(e.clientX, e.clientY)?.closest('.grid-cell');
    if (!cell || !cell.dataset.row) {
      isDragging = false;
      dragStart = null;
      return;
    }

    const row1 = dragStart.row, col1 = dragStart.col;
    const row2 = +cell.dataset.row, col2 = +cell.dataset.col;
    const rMin = Math.min(row1, row2), rMax = Math.max(row1, row2);
    const cMin = Math.min(col1, col2), cMax = Math.max(col1, col2);
    const editMode = qs('#edit-toggle').checked;
    const borderMode = qs('#border-toggle').checked;
    let overlap = false;

    if (editMode && !borderMode) {
      for (let r = rMin; r <= rMax; r++) {
        for (let c = cMin; c <= cMax; c++) {
          const occupied = [...document.querySelectorAll('.trial-group')].some(group => {
            const gr = +group.dataset.row;
            const gc = +group.dataset.col;
            const gw = parseFloat(group.style.width) / STEP;
            const gh = parseFloat(group.style.height) / STEP;
            return (r === gr && c >= gc && c < gc + gw) ||
                   (c === gc && r >= gr && r < gr + gh) ||
                   (r >= gr && r < gr + gh && c >= gc && c < gc + gw);
          });
          if (occupied) {
            overlap = true;
            break;
          }
        }
        if (overlap) break;
      }
    }

    if (overlap) {
      alert('It is not possible to turn entire row or column unutilized because there is a trial already placed.');
    } else {
      for (let r = rMin; r <= rMax; r++) {
        for (let c = cMin; c <= cMax; c++) {
          const k = key(r, c);
          const cell = qs(`.grid-cell[data-row="${r}"][data-col="${c}"]`);
          if (!cell) continue;

          if (editMode) {
            if (cellIsUnused(r, c)) {
              manualBlock.delete(k);
              manualAllow.add(k);
            } else {
              manualAllow.delete(k);
              manualBlock.add(k);
            }
            const unused = cellIsUnused(r, c);
            cell.style.background = unused ? '#d1d5db' : '#ffffff';
          }

          if (borderMode) {
            if (manualBorders.has(k)) {
              manualBorders.delete(k);
              cell.classList.remove('border-plot');
              cell.textContent = '';
            } else {
              manualBorders.add(k);
              cell.classList.add('border-plot');
              cell.textContent = 'B';
            }
          }
        }
      }
    }

    isDragging = false;
    dragStart = null;
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
    const n=+qs('#num-trials')?.value||0;
    for(let i=1;i<=n;i++){ addTrialForm(i); addPaletteBox(i); }
  }

  function updateUnusedRowHighlights(rowList) {
    const cols = +qs('#farm-cols')?.value || 0;
    for (let r = 0; r < +qs('#farm-rows')?.value || 0; r++) {
      for (let c = 0; c < cols; c++) {
        const cell = qs(`.grid-cell[data-row="${r}"][data-col="${c}"]`);
        if (!cell) continue;
        const k = key(r, c);
        const isUnused = rowList.includes(r) || intList('unused-cols').includes(c);
        cell.style.background = isUnused && !manualAllow.has(k) ? '#d1d5db' : '#ffffff';
      }
    }
  }

  function updateUnusedColHighlights(colList) {
    const rows = +qs('#farm-rows')?.value || 0;
    for (let c = 0; c < +qs('#farm-cols')?.value || 0; c++) {
      for (let r = 0; r < rows; r++) {
        const cell = qs(`.grid-cell[data-row="${r}"][data-col="${c}"]`);
        if (!cell) continue;
        const k = key(r, c);
        const isUnused = colList.includes(c) || intList('unused-rows').includes(r);
        cell.style.background = isUnused && !manualAllow.has(k) ? '#d1d5db' : '#ffffff';
      }
    }
  }


  window.onload = ()=>{
    makeTrials();
    drawGrid();
    qs('#farm-rows').addEventListener('change',drawGrid);
    qs('#farm-cols').addEventListener('change',drawGrid);
    qs('#edit-toggle').addEventListener('change',()=>{ if(qs('#edit-toggle').checked) qs('#border-toggle').checked=false; });
    qs('#border-toggle').addEventListener('change',()=>{ if(qs('#border-toggle').checked) qs('#edit-toggle').checked=false; });
    lastUnusedRows = qs('#unused-rows').value;
    lastUnusedCols = qs('#unused-cols').value;

    qs('#unused-rows').addEventListener('change', function (e) {
      const val = e.target.value.trim();
      const rowList = val ? val.split(',').map(v => +v.trim() - 1).filter(n => !isNaN(n)) : [];
      const cols = +qs('#farm-cols')?.value || 0;

      const conflict = rowList.some(row => {
        return [...document.querySelectorAll('.trial-group')].some(group => {
          const gr = +group.dataset.row;
          const gh = parseFloat(group.style.height) / STEP;
          return row >= gr && row < gr + gh;
        }) || Array.from({ length: cols }).some((_, c) => manualBorders.has(key(row, c)));
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
          const gw = parseFloat(group.style.width) / STEP;
          return col >= gc && col < gc + gw;
        }) || Array.from({ length: rows }).some((_, r) => manualBorders.has(key(r, col)));
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
  };


});



