

/******** global state ********/
let gridReady = false;
let lastUnusedRows = '';
let lastUnusedCols = '';

/******** Grid Zoom ********/
document.getElementById('zoom-slider').addEventListener('input', function (e) {
  const scale = parseFloat(e.target.value);
  const container = document.getElementById('field-zoom-container');
  if (container) container.style.transform = `scale(${scale})`;
});

/******** Export View as JPG ********/
document.getElementById('export-jpg-btn').addEventListener('click', function () {
  const target = document.getElementById('farm-scroll');
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
document.getElementById('export-full-jpg-btn').addEventListener('click', function () {
  const scrollContainer = document.getElementById('farm-scroll');
  const zoomContainer = document.getElementById('field-zoom-container');

  // Save original styles
  const originalOverflow = scrollContainer.style.overflow;
  const originalHeight = scrollContainer.style.maxHeight;
  const originalWidth = zoomContainer.style.width;
  const originalHeightZoom = zoomContainer.style.height;

  // Measure actual size
  const fullWidth = zoomContainer.scrollWidth;
  const fullHeight = zoomContainer.scrollHeight;

  // Force layout to full size
  scrollContainer.style.overflow = 'visible';
  scrollContainer.style.maxHeight = 'none';
  zoomContainer.style.width = `${fullWidth}px`;
  zoomContainer.style.height = `${fullHeight}px`;

  // Capture
  html2canvas(zoomContainer, {
    backgroundColor: '#ffffff',
    scale: 2
  }).then(canvas => {
    // Restore original styles
    scrollContainer.style.overflow = originalOverflow;
    scrollContainer.style.maxHeight = originalHeight;
    zoomContainer.style.width = originalWidth;
    zoomContainer.style.height = originalHeightZoom;

    // Export
    const link = document.createElement('a');
    link.download = 'farm_field_grid_full.jpg';
    link.href = canvas.toDataURL('image/jpeg');
    link.click();
  });
});

/******** util ********/
const qs  = s => document.querySelector(s);
const qsa = s => Array.from(document.querySelectorAll(s));
const CELL = 40, GAP = 2, STEP = CELL + GAP;
const colours = ['bg-red-400','bg-blue-400','bg-yellow-300','bg-green-400'];
const colourFor = n => colours[(n-1)%colours.length];
const uid = (() => { let i = 0; return () => `u${++i}`; })();
const key = (r,c) => `${r},${c}`;

/******** state ********/
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
function addTrialForm(i){
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
          <option>Alpha Lattice</option>
          <option>Augmented</option>
        </select>
      </label>
    </div>
    <div class='grid grid-cols-2 gap-4 mb-4'>
      <label>Treatments List
        <input id='ttreatments${i}' placeholder='e.g. A, B, C' class='w-full border rounded px-2 py-1' />
      </label>
      <label>Controls List
        <input id='tcontrols${i}' placeholder='e.g. Check1, Check2' class='w-full border rounded px-2 py-1' />
      </label>
    </div>
    <div class='grid grid-cols-2 gap-4 mb-4'>
      <label>Reps
        <input id='treps${i}' type='number' min='1' class='w-full border rounded px-2 py-1' />
      </label>
      <label>Blocks
        <input id='tblocks${i}' type='number' min='1' class='w-full border rounded px-2 py-1' />
      </label>
    </div>
    <div class='grid grid-cols-2 gap-4'>
      <label>Rows
        <input id='trows${i}' type='number' value='1' min='1' class='w-full border rounded px-2 py-1' />
      </label>
      <label>Cols
        <input id='tcols${i}' type='number' value='1' min='1' class='w-full border rounded px-2 py-1' />
      </label>
    </div>`;
  qs('#trial-details').appendChild(d);
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

  let col, row;

  if (src === 'grid') {
    // Adjust using offset when dragging from the grid
    col = Math.floor((e.clientX - rect.left - offX) / STEP) - 1;
    row = Math.floor((e.clientY - rect.top  - offY) / STEP) - 1;
  } else {
    // No offset if dragging from palette
    col = Math.floor((e.clientX - rect.left) / STEP) - 1;
    row = Math.floor((e.clientY - rect.top)  / STEP) - 1;
  }

  if (col < 0 || row < 0) return;

  const name        = qs(`#tname${tn}`)?.value || `Trial ${tn}`;
  const rowsWanted  = +qs(`#trows${tn}`)?.value || 1;
  const colsWanted  = +qs(`#tcols${tn}`)?.value || 1;
  const total       = rowsWanted * colsWanted;
  const colour      = colourFor(tn);

  if (src === 'grid') {
    const parent = qs('#field-zoom-container');
    const groups = parent.querySelectorAll(`.trial-group[data-root="${root}"]`);
    groups.forEach(g => parent.removeChild(g));
  }

  placeTrial({ tn, name, rowsWanted, colsWanted, total, rowStart: row, colStart: col, colour, rootId: src === 'grid' ? root : null });
}


const farmGridEl = qs('#farm-grid');
farmGridEl.addEventListener('dragover', e=>e.preventDefault());
farmGridEl.addEventListener('drop', handleDrop);

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

function placeTrial({tn, name, rowsWanted, colsWanted, total, rowStart, colStart, colour, rootId}) {
  disablePal(tn);
  const root = rootId || uid();
  const coords = [];
  let r = rowStart, c = colStart;
  let usableInRow = 0;

  while (coords.length < total) {
    const k = key(r, c);
    const isBorder = manualBorders.has(k);

    if (!cellIsUnused(r, c) && !isBorder) {
      if (trialCellExists(r, c)) {
        alert('Please find another region to place your trial. This is occupied!');
        return;
      }
      coords.push([r, c]);
      usableInRow++;
    }

    c++;
    if (usableInRow >= colsWanted) {
      // We filled the desired number of usable plots in this row
      r++;
      c = colStart;
      usableInRow = 0;
    }

    // Safety break
    if (r > 1000) {
      alert("Could not place trial: not enough usable space.");
      return;
    }
  }

  // Group by row
  const rowsMap = {};
  coords.forEach(([rr, cc]) => {
    (rowsMap[rr] = rowsMap[rr] || []).push(cc);
  });

  // Create segmented trial boxes
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

  function createSeg(rr, start, end) {
    const seg = end - start + 1;
    const g = document.createElement('div');
    g.className = 'trial-group';
    g.dataset.trial = tn;
    g.dataset.root = root;
    g.dataset.row = rr;
    g.dataset.col = start;
    g.style.left = `${(start + 1) * STEP}px`;
    g.style.top = `${(rr + 1) * STEP}px`;
    g.style.width = `${seg * STEP - GAP}px`;
    g.style.height = `${CELL}px`;
    g.style.gridTemplateColumns = `repeat(${seg}, ${CELL}px)`;
    g.draggable = true;
    g.ondragstart = startDrag;

    for (let i = 0; i < seg; i++) {
      const b = document.createElement('div');
      b.className = `trial-box ${colour} bg-opacity-60`;
      b.textContent = name;
      b.draggable = true;
      b.ondragstart = startDrag;
      g.appendChild(b);
    }

    if (!qs(`[data-root="${root}"] .remove-btn`)) {
      const rm = document.createElement('div');
      rm.className = 'remove-btn';
      rm.textContent = '×';
      rm.onclick = () => {
        const removalLoader = qs('#removal-loader');
        removalLoader?.classList.remove('hidden');

        requestAnimationFrame(() => {
          setTimeout(() => {
            qsa(`[data-root="${root}"]`).forEach(el => el.remove());
            enablePal(tn);
            removalLoader?.classList.add('hidden');
          }, 100);
        });
      };
      g.appendChild(rm);
    }

    qs('#field-zoom-container').appendChild(g);
  }
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


