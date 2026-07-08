import '../legacy/jquery.js';
import '../legacy/leaflet.js';

var environmentStratificationMap = null;
var environmentStratificationMapMarkers = null;
var environmentStratificationGroupColors = [
    '#0057b8',
    '#00a651',
    '#e31b23',
    '#7b2cbf',
    '#ff8c00',
    '#008c95',
    '#c2185b',
    '#6b8e23',
    '#2f4b7c',
    '#f95d6a',
    '#665191',
    '#ffa600'
];

export function init(main_div) {
    if (!(main_div instanceof HTMLElement)) {
        main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
    }

    if (typeof isLoggedIn === 'function' && !isLoggedIn()) {
        alert('You must be logged in to use Environment Stratification');
        return;
    }

    get_select_box("datasets", "environment_stratification_dataset_select", {
        "checkbox_name": "environment_stratification_dataset_select_checkbox",
        "analysis_type": "Environment Stratification",
        "show_compatibility": "yes"
    });

    $('#environment_stratification_trait_select').attr("disabled", true).html('');
    initializeMap();
    setTimeout(function() {
        if (environmentStratificationMap) {
            environmentStratificationMap.invalidateSize();
        }
    }, 100);

    $('#environment_stratification_dataset_select').on('click', function() {
        $('#environment_stratification_trait_select').attr("disabled", true).html('');
        $('#environment_stratification_tempfile').html('');
        $('#environment_stratification_trait_summary').empty();
        clearResults();
    });

    $('#environment_stratification_select_dataset').on('click', function() {
        var dataset_id = getDatasetId();
        if (!dataset_id) {
            return;
        }

        $.ajax({
            url: '/ajax/environment_stratification/shared_phenotypes',
            data: {
                dataset_id: dataset_id,
                dataset_trait_outliers: $('#environment_stratification_dataset_trait_outliers').is(':checked') ? 1 : 0
            },
            beforeSend: function() {
                $('#environment_stratification_trait_select').attr("disabled", true).html('');
                $('#environment_stratification_trait_summary').empty();
                clearResults();
            },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                    return;
                }

                var option_html = '<option selected="selected" value=""></option>';
                for (var i = 0; i < response.options.length; i++) {
                    option_html += '<option value="' + htmlEscape(response.options[i][1]) + '">' + htmlEscape(response.options[i][1]) + '</option>';
                }
                $('#environment_stratification_trait_select').attr("disabled", false).html(option_html);
                $('#environment_stratification_tempfile').html(response.tempfile);
            },
            error: function() {
                alert("An error occurred while preparing the dataset.");
            }
        });
    });

    $('#environment_stratification_trait_select').on('change', function() {
        var trait = $(this).val();
        var tempfile = $('#environment_stratification_tempfile').html();

        $('#environment_stratification_trait_summary').empty();
        clearResults();

        if (!trait || !tempfile) {
            return;
        }

        $.get('/ajax/environment_stratification/getdata', { file: tempfile, trait: trait })
            .done(function(response) {
                if (response.error) {
                    alert(response.error);
                    return;
                }
                renderTraitSummary(response.data || [], trait);
            })
            .fail(function() {
                alert("An error occurred while reading the phenotype file.");
            });
    });

    $('#environment_stratification_run').on('click', function() {
        var dataset_id = getDatasetId();
        var trait = $('#environment_stratification_trait_select').val();
        var alpha = parseFloat($('#environment_stratification_alpha').val());

        if (!dataset_id) {
            return;
        }
        if (!trait) {
            alert("Please select a trait.");
            return;
        }
        if (isNaN(alpha) || alpha <= 0 || alpha >= 1) {
            alert("Alpha must be a number between 0 and 1.");
            return;
        }

        $.ajax({
            url: '/ajax/environment_stratification/generate_results',
            data: {
                dataset_id: dataset_id,
                trait_id: trait,
                alpha: alpha,
                dataset_trait_outliers: $('#environment_stratification_dataset_trait_outliers').is(':checked') ? 1 : 0
            },
            beforeSend: function() {
                clearResults();
                $('#environment_stratification_message').html('<div class="alert alert-info">Running environment stratification...</div>');
                if ($('#working_modal').length) {
                    $('#working_modal').modal("show");
                }
            },
            timeout: 30000000,
            success: function(response) {
                if ($('#working_modal').length) {
                    $('#working_modal').modal("hide");
                }
                if (response.error) {
                    $('#environment_stratification_message').html('<div class="alert alert-danger">' + htmlEscape(response.error) + '</div>');
                    return;
                }

                $('#environment_stratification_message').html('<div class="alert alert-success">' + htmlEscape(response.message || 'Analysis finished.') + '</div>');
                renderResults(response);
                renderMap(response.map_locations || []);
            },
            error: function() {
                if ($('#working_modal').length) {
                    $('#working_modal').modal("hide");
                }
                $('#environment_stratification_message').html('<div class="alert alert-danger">An error occurred while running environment stratification.</div>');
            }
        });
    });

    $('.environment-stratification-download').on('click', function() {
        downloadTableXlsx($(this).data('table'), $(this).data('filename'));
    });
}

function getDatasetId() {
    var selected_datasets = [];
    $('input[name="environment_stratification_dataset_select_checkbox"]:checked').each(function() {
        selected_datasets.push($(this).val());
    });

    if (selected_datasets.length < 1) {
        alert('Please select one dataset.');
        return false;
    }
    if (selected_datasets.length > 1) {
        alert('Please select only one dataset.');
        return false;
    }
    return selected_datasets[0];
}

function renderTraitSummary(data, trait) {
    var key = cleanTraitName(trait);
    var values = data.map(function(row) { return parseFloat(row[key]); }).filter(function(value) { return !isNaN(value); });
    var missing = data.length - values.length;

    if (data.length === 0) {
        return;
    }

    var mean = values.length ? values.reduce(function(a, b) { return a + b; }, 0) / values.length : NaN;
    var variance = values.length ? values.reduce(function(acc, val) { return acc + Math.pow(val - mean, 2); }, 0) / values.length : NaN;

    var summary = [{
        Trait: key,
        Observations: data.length,
        Measured: values.length,
        Missing: missing,
        Mean: formatNumber(mean),
        Minimum: formatNumber(Math.min.apply(null, values)),
        Maximum: formatNumber(Math.max.apply(null, values)),
        "Std Dev": formatNumber(Math.sqrt(variance)),
        "Percent Missing": formatNumber((missing / data.length) * 100)
    }];

    renderTable('#environment_stratification_trait_summary', 'environment_stratification_trait_summary_table', summary);
}

function renderResults(response) {
    var membership = response.group_membership || [];
    var groupsById = {};
    membership.forEach(function(row) {
        if (!groupsById[row.group_id]) {
            groupsById[row.group_id] = [];
        }
        groupsById[row.group_id].push(row.environment);
    });

    var groups = (response.group_summary || []).map(function(row) {
        return {
            Group: row.group_id,
            Environments: firstPresent(row.environments, groupsById[row.group_id] ? groupsById[row.group_id].join(', ') : ''),
            Locations: firstPresent(row.locations, row.location),
            Trials: firstPresent(row.trials, row.trial),
            "N Environments": row.n_env,
            "N Genotypes": row.n_genotypes,
            "F Value": formatNumber(row.f_value),
            "P Value": formatNumber(row.p_value),
            Compatible: row.compatible,
            Message: row.message
        };
    });

    var pairwise = (response.pairwise || []).map(function(row) {
        return {
            "Environment 1 Location": firstPresent(row.env1_location, row.env1),
            "Environment 1 Trial": row.env1_trial,
            "Environment 2 Location": firstPresent(row.env2_location, row.env2),
            "Environment 2 Trial": row.env2_trial,
            "N Genotypes": row.n_genotypes,
            "SS": formatNumber(row.ss_ge),
            "MS GxE": formatNumber(row.ms_ge),
            "MSE": formatNumber(row.mse_error),
            "F Value": formatNumber(row.f_value),
            "P Value": formatNumber(row.p_value),
            Compatible: row.compatible,
            Message: row.message
        };
    });

    var anova = (response.anova || []).map(function(row) {
        return {
            Design: row.design || '',
            Term: row.term,
            DF: formatNumber(row.df),
            "Sum Sq": formatNumber(row.sum_sq),
            "Mean Sq": formatNumber(row.mean_sq),
            "F Value": formatNumber(row.f_value),
            "P Value": formatNumber(row.p_value),
            Message: row.message || ''
        };
    });

    var ungrouped = (response.ungrouped || []).map(function(row) {
        return {
            Environment: firstPresent(row.environment_label, row.environment),
            Location: firstPresent(row.location, row.environment),
            Trial: row.trial
        };
    });

    renderTable('#environment_stratification_groups', 'environment_stratification_groups_table', groups);
    renderTable('#environment_stratification_pairwise', 'environment_stratification_pairwise_table', pairwise);
    renderTable('#environment_stratification_anova', 'environment_stratification_anova_table', anova);
    renderTable('#environment_stratification_ungrouped', 'environment_stratification_ungrouped_table', ungrouped);
}

function renderMap(mapLocations) {
    if (typeof L === 'undefined') {
        $('#environment_stratification_map_message').html('<div class="alert alert-warning">Map library is not available.</div>');
        return;
    }

    initializeMap();
    environmentStratificationMapMarkers.clearLayers();
    $('#environment_stratification_map_message').empty();
    $('#environment_stratification_map_legend').empty();

    var locationsWithCoordinates = (mapLocations || []).filter(function(row) {
        return row.has_coordinates && isFinite(parseFloat(row.latitude)) && isFinite(parseFloat(row.longitude));
    });
    var missingCoordinates = (mapLocations || []).filter(function(row) {
        return !row.has_coordinates;
    });

    if (locationsWithCoordinates.length === 0) {
        if ((mapLocations || []).length > 0) {
            $('#environment_stratification_map_message').html('<div class="alert alert-warning">No mapped locations have latitude and longitude coordinates.</div>');
        }
        environmentStratificationMap.setView([0, 0], 2);
        return;
    }

    var colorByGroup = {};
    var colorIndex = 0;
    locationsWithCoordinates.forEach(function(row) {
        if (!colorByGroup[row.group_id]) {
            colorByGroup[row.group_id] = row.group_id === 'Ungrouped' ? '#777777' : environmentStratificationGroupColors[colorIndex++ % environmentStratificationGroupColors.length];
        }
    });

    var bounds = [];
    locationsWithCoordinates.forEach(function(row) {
        var lat = parseFloat(row.latitude);
        var lng = parseFloat(row.longitude);
        var color = colorByGroup[row.group_id];
        var marker = L.circleMarker([lat, lng], {
            radius: row.group_id === 'Ungrouped' ? 7 : 12,
            color: color,
            weight: row.group_id === 'Ungrouped' ? 2 : 5,
            fillColor: color,
            fillOpacity: row.group_id === 'Ungrouped' ? 0.55 : 0.88
        });

        marker.bindTooltip(
            '<b>' + htmlEscape(row.location) + '</b><br>' +
            'Trial: ' + htmlEscape(row.trial || ''),
            {
                direction: 'top',
                sticky: true,
                opacity: 0.95
            }
        );

        marker.bindPopup(
            '<b>' + htmlEscape(row.location) + '</b><br>' +
            'Group: ' + htmlEscape(row.group_label || row.group_id) + '<br>' +
            'Environment: ' + htmlEscape(row.environment) + '<br>' +
            'Trial: ' + htmlEscape(row.trial || '')
        );
        marker.addTo(environmentStratificationMapMarkers);
        bounds.push([lat, lng]);
    });

    if (bounds.length === 1) {
        environmentStratificationMap.setView(bounds[0], 8);
    } else {
        environmentStratificationMap.fitBounds(bounds, { padding: [30, 30] });
    }
    setTimeout(function() {
        environmentStratificationMap.invalidateSize();
    }, 100);

    renderMapLegend(colorByGroup);

    if (missingCoordinates.length > 0) {
        var missingNames = missingCoordinates.map(function(row) { return row.location; }).filter(function(value, index, arr) {
            return value && arr.indexOf(value) === index;
        });
        $('#environment_stratification_map_message').html('<div class="alert alert-warning">Locations without coordinates are not shown: ' + htmlEscape(missingNames.join(', ')) + '</div>');
    }
}

function initializeMap() {
    if (environmentStratificationMap) {
        return;
    }

    environmentStratificationMap = L.map('environment_stratification_map').setView([0, 0], 2);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors'
    }).addTo(environmentStratificationMap);
    environmentStratificationMapMarkers = L.layerGroup().addTo(environmentStratificationMap);
}

function renderMapLegend(colorByGroup) {
    var groups = Object.keys(colorByGroup).sort();
    if (groups.length === 0) {
        return;
    }

    var html = '';
    groups.forEach(function(groupId) {
        var label = groupId === 'Ungrouped' ? 'Ungrouped or statistically distinct' : groupId + ' - not statistically different';
        html += '<span class="environment-stratification-map-legend-item">' +
            '<span class="environment-stratification-map-swatch" style="background-color:' + htmlEscape(colorByGroup[groupId]) + '"></span>' +
            htmlEscape(label) +
            '</span>';
    });
    $('#environment_stratification_map_legend').html(html);
}

function renderTable(container, tableId, rows) {
    if ($.fn.DataTable && $.fn.DataTable.isDataTable('#' + tableId)) {
        $('#' + tableId).DataTable().destroy();
    }

    if (!rows || rows.length === 0) {
        $(container).html('<p>No rows to display.</p>');
        return;
    }

    var columns = Object.keys(rows[0]);
    var html = '<table id="' + tableId + '" class="display"><thead><tr>';
    columns.forEach(function(column) {
        html += '<th>' + htmlEscape(column) + '</th>';
    });
    html += '</tr></thead><tbody>';

    rows.forEach(function(row) {
        html += '<tr>';
        columns.forEach(function(column) {
            html += '<td>' + htmlEscape(row[column]) + '</td>';
        });
        html += '</tr>';
    });
    html += '</tbody></table>';
    $(container).html(html);

    if ($.fn.DataTable) {
        $('#' + tableId).DataTable({
            paging: true,
            searching: true
        });
    }
}

function clearResults() {
    $('#environment_stratification_message').empty();
    $('#environment_stratification_groups').empty();
    $('#environment_stratification_pairwise').empty();
    $('#environment_stratification_anova').empty();
    $('#environment_stratification_ungrouped').empty();
    $('#environment_stratification_map_message').empty();
    $('#environment_stratification_map_legend').empty();
    if (environmentStratificationMapMarkers) {
        environmentStratificationMapMarkers.clearLayers();
    }
}

function cleanTraitName(trait) {
    return String(trait || '').replace(/\|CO_.*$/, '');
}

function formatNumber(value) {
    var number = parseFloat(value);
    return isFinite(number) ? number.toFixed(4) : '';
}

function firstPresent() {
    for (var i = 0; i < arguments.length; i++) {
        if (arguments[i] !== null && arguments[i] !== undefined && String(arguments[i]) !== '') {
            return arguments[i];
        }
    }
    return '';
}

function htmlEscape(value) {
    if (value === null || value === undefined) {
        return '';
    }
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function downloadTableXlsx(tableId, filename) {
    var table = document.getElementById(tableId);
    if (!table) {
        alert('No results are available to download.');
        return;
    }

    var JSZipConstructor = getJSZipConstructor();
    if (!JSZipConstructor) {
        alert('XLSX export library is not available.');
        return;
    }

    var rows = [];
    $(table).find('tr').each(function() {
        var row = [];
        $(this).find('th,td').each(function() {
            row.push($(this).text());
        });
        rows.push(row);
    });

    if (rows.length === 0) {
        alert('No results are available to download.');
        return;
    }

    var workbook = buildXlsxWorkbook(rows, JSZipConstructor);
    generateXlsxBlob(workbook, function(blob) {
        var link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = filename || 'environment_stratification.xlsx';
        link.click();
        setTimeout(function() {
            URL.revokeObjectURL(link.href);
        }, 1000);
    });
}

function getJSZipConstructor() {
    if (typeof window !== 'undefined' && window.JSZip) {
        return window.JSZip;
    }
    if (typeof globalThis !== 'undefined' && globalThis.JSZip) {
        return globalThis.JSZip;
    }
    return null;
}

function generateXlsxBlob(workbook, callback) {
    var options = {
        type: 'blob',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    };

    if (typeof workbook.generate !== 'function') {
        alert('XLSX export library is not compatible with this page.');
        return;
    }

    callback(workbook.generate(options));
}

function buildXlsxWorkbook(rows, JSZipConstructor) {
    var zip = new JSZipConstructor();
    zip.file('[Content_Types].xml', xlsxContentTypesXml());
    zip.folder('_rels').file('.rels', xlsxRootRelsXml());
    zip.folder('xl').file('workbook.xml', xlsxWorkbookXml());
    zip.folder('xl').folder('_rels').file('workbook.xml.rels', xlsxWorkbookRelsXml());
    zip.folder('xl').folder('worksheets').file('sheet1.xml', xlsxSheetXml(rows));
    zip.folder('xl').file('styles.xml', xlsxStylesXml());
    return zip;
}

function xlsxSheetXml(rows) {
    var sheetRows = rows.map(function(row, rowIndex) {
        var cells = row.map(function(value, colIndex) {
            var cellRef = xlsxColumnName(colIndex + 1) + (rowIndex + 1);
            return '<c r="' + cellRef + '" t="inlineStr"><is><t>' + xmlEscape(value) + '</t></is></c>';
        }).join('');
        return '<row r="' + (rowIndex + 1) + '">' + cells + '</row>';
    }).join('');

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
        '<sheetData>' + sheetRows + '</sheetData>' +
        '</worksheet>';
}

function xlsxColumnName(index) {
    var name = '';
    while (index > 0) {
        var remainder = (index - 1) % 26;
        name = String.fromCharCode(65 + remainder) + name;
        index = Math.floor((index - 1) / 26);
    }
    return name;
}

function xlsxContentTypesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
        '<Default Extension="xml" ContentType="application/xml"/>' +
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
        '</Types>';
}

function xlsxRootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
        '</Relationships>';
}

function xlsxWorkbookXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
        '<sheets><sheet name="Results" sheetId="1" r:id="rId1"/></sheets>' +
        '</workbook>';
}

function xlsxWorkbookRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' +
        '</Relationships>';
}

function xlsxStylesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
        '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>' +
        '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>' +
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
        '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>' +
        '</styleSheet>';
}

function xmlEscape(value) {
    if (value === null || value === undefined) {
        return '';
    }
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;');
}
