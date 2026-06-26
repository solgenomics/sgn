export function createDownloadTools({ qs, key, sanitizeTrialName, collectLayoutJson }) {
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
      plot_width: '',
      plot_length: '',
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
        plot_width: '',
        plot_length: '',
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
          plot_width: form.plot_width || layout.field.plot_width || '',
          plot_length: form.plot_length || layout.field.plot_length || '',
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
      'plot_width', 'plot_length', 'rows_per_plot', 'plants_per_plot', 'plant_spacing', 'row_spacing',
      'alley_spacing', 'planting_notes'
    ];
    const settingsRows = [
      { setting: 'location', value: layout.farm.name },
      { setting: 'year', value: layout.year },
      { setting: 'season', value: layout.season },
      { setting: 'breeding_program', value: layout.breeding_program.name },
      { setting: 'field_rows', value: layout.field.rows },
      { setting: 'field_cols', value: layout.field.cols },
      { setting: 'planting_direction', value: settings.planting_direction }
    ];
    const filenameParts = ['planting_map', layout.farm.name, layout.year, layout.season].filter(Boolean);
    const filename = `${filenameParts.join('_').replace(/[^\w.-]+/g, '_') || 'planting_map'}.xlsx`;

    downloadExcelWorkbook(filename, [
      { name: 'Planting_Map', headers: plotHeaders, rows },
      { name: 'Settings', headers: ['setting', 'value'], rows: settingsRows }
    ]);
  }

  function initDownloadTools() {
    qs('#zoom-slider')?.addEventListener('input', function (e) {
      const scale = parseFloat(e.target.value);
      const container = qs('#field-zoom-container');
      if (container) container.style.transform = `scale(${scale})`;
    });

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

    qs('#download-planting-map-btn')?.addEventListener('click', downloadPlantingMap);
  }

  return {
    initDownloadTools,
    plantingSettings
  };
}
