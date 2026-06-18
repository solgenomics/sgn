import React, { useState, useEffect, useMemo, useRef } from 'react';
import { createRoot } from 'react-dom/client';

// Declare external legacy global libraries
// We must use 'any' here as Leaflet (L) and Turf are loaded globally as script includes 
// via Mason templates and do not have type declarations within this bundler.
declare const L: any;
declare const turf: any;
declare const BrAPIFieldmap: any;
declare const jQuery: any;

interface ObservationLevel {
    levelCode: string | number;
    levelName: string;
    levelOrder?: number;
}

interface ObservationLevelRelationship {
    levelCode: string;
    levelName: string;
}

interface ObservationUnitPosition {
    positionCoordinateX: string | number;
    positionCoordinateY: string | number;
    observationLevel: ObservationLevel;
    observationLevelRelationships?: ObservationLevelRelationship[];
    entryType?: string;
}

interface Plot {
    type: 'data' | 'filler' | 'border' | 'empty_space';
    observationUnitDbId?: string;
    observationUnitName: string;
    observationUnitPosition: ObservationUnitPosition;
    germplasmDbId?: string;
    germplasmName?: string;
    crossName?: string;
    locationName?: string;
    studyName?: string;
    plotImageDbIds?: string[];
    additionalInfo?: {
        intercropGermplasm?: { germplasmName: string }[];
        familyName?: string;
        [key: string]: any;
    };
}

interface HeatmapValue {
    val: number;
    plot_name: string;
    id: string;
}

interface TrialDetails {
    id: string;
    name: string;
    bg: string;
    fg: string;
}

interface PlotStructureNode {
    type: string;
    stock_id?: number;
    name?: string;
    attributes?: Record<string, { value: any }>;
    has?: Record<string, PlotStructureNode>;
}

const palette = [
    "#8dd3c7", "#ffffb3", "#bebada", "#fb8072", "#80b1d3",
    "#fdb462", "#b3de69", "#fccde5", "#d9d9d9", "#bc80bd",
    "#ccebc5", "#ffed6f"
];
const trial_colors = [
    "#2f4f4f", "#ff8c00", "#ffff00", "#00ff00", "#9400d3",
    "#00ffff", "#1e90ff", "#ff1493", "#ffdab9", "#228b22",
];
const trial_colors_text = [
    "#ffffff", "#000000", "#000000", "#000000", "#ffffff",
    "#000000", "#ffffff", "#ffffff", "#000000", "#ffffff",
];

const colorNameToHex = (color: string): string => {
    const colors: Record<string, string> = {
        white: "#ffffff",
        darkred: "#8b0000",
        darkblue: "#00008b",
        red: "#ff0000",
        blue: "#0000ff",
        green: "#008000"
    };
    return colors[color.toLowerCase()] || color;
};

const hexToRgb = (hex: string) => {
    const shorthandRegex = /^#?([a-f\d])([a-f\d])([a-f\d])$/i;
    const fullHex = hex.replace(shorthandRegex, (_, r, g, b) => r + r + g + g + b + b);
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(fullHex);
    return result ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
    } : { r: 255, g: 255, b: 255 };
};

const rgbToHex = (r: number, g: number, b: number) => {
    return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
};

const interpolate = (color1: string, color2: string, factor: number) => {
    const rgb1 = hexToRgb(colorNameToHex(color1));
    const rgb2 = hexToRgb(colorNameToHex(color2));
    const r = Math.round(rgb1.r + (rgb2.r - rgb1.r) * factor);
    const g = Math.round(rgb1.g + (rgb2.g - rgb1.g) * factor);
    const b = Math.round(rgb1.b + (rgb2.b - rgb1.b) * factor);
    return rgbToHex(r, g, b);
};

const RenderPlantGrid: React.FC<{ node: PlotStructureNode }> = ({ node }) => {
    if (!node.has) return null;
    
    let maxRow = 1;
    let maxCol = 1;
    const coordMap: Record<string, string> = {};
    
    Object.entries(node.has).forEach(([plantName, plantNode]) => {
        const row = parseInt(plantNode.attributes?.row_number?.value) || 0;
        const col = parseInt(plantNode.attributes?.col_number?.value) || 0;
        if (row > maxRow) maxRow = row;
        if (col > maxCol) maxCol = col;
        coordMap[`${row},${col}`] = plantName;
    });
    
    const rows = [];
    for (let r = maxRow; r >= 0; r--) {
        const cols = [];
        for (let c = 0; c <= maxCol; c++) {
            if (r === 0) {
                if (c === 0) {
                    cols.push(<th key="empty" className="tw:border-0"></th>);
                } else {
                    cols.push(<th key={`col-header-${c}`} className="tw:border-0 tw:text-center tw:align-middle tw:p-1 tw:text-xs">{c}</th>);
                }
            } else {
                if (c === 0) {
                    cols.push(<th key={`row-header-${r}`} className="tw:border-0 tw:text-left tw:align-middle tw:pr-2 tw:text-xs">{r}</th>);
                } else {
                    const key = `${r},${c}`;
                    const plantName = coordMap[key];
                    cols.push(
                        <td key={key} className="tw:border tw:border-black tw:p-1 tw:rounded tw:text-center tw:align-middle tw:text-[11px] tw:min-w-15 tw:h-8">
                            {plantName || <span className="tw:text-gray-300">empty</span>}
                        </td>
                    );
                }
            }
        }
        rows.push(<tr key={`row-${r}`}>{cols}</tr>);
    }
    
    return (
        <table className="tw:border-separate tw:border-spacing-1 tw:overflow-hidden tw:mx-auto tw:mt-2" style={{ aspectRatio: `${maxCol + 1} / ${maxRow + 1}` }}>
            <tbody>{rows}</tbody>
        </table>
    );
};

const RenderSubplotGrid: React.FC<{ node: PlotStructureNode }> = ({ node }) => {
    if (!node.has) return null;
    
    return (
        <div className="tw:flex tw:flex-col tw:gap-2.5 tw:items-center tw:mt-2">
            {Object.entries(node.has).sort(([a], [b]) => a.localeCompare(b)).map(([subplotName, subplotNode]) => (
                <div key={subplotName} className="tw:border tw:border-gray-400 tw:p-2.5 tw:rounded-lg tw:text-center tw:align-middle tw:w-full">
                    <div className="tw:font-bold tw:mb-1 tw:text-sm">{subplotName}</div>
                    <RenderPlantGrid node={subplotNode} />
                </div>
            ))}
        </div>
    );
};

const pearsonSkewness = (arr: number[]): number => {
    if (arr.length === 0) return 0;
    const sorted = [...arr].sort((a, b) => a - b);
    const median = sorted[Math.floor(sorted.length / 2)];
    const mean = arr.reduce((sum, val) => sum + val, 0) / arr.length;
    const variance = arr.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / arr.length;
    const stdDev = Math.sqrt(variance);
    return stdDev === 0 ? 0 : (3 * (mean - median)) / stdDev;
};

const AccessionAutocomplete: React.FC<{
    value: string;
    onChange: (val: string) => void;
    placeholder?: string;
    className?: string;
    appendToId?: string;
}> = ({ value, onChange, placeholder, className }) => {
    const [suggestions, setSuggestions] = useState<string[]>([]);
    const [show, setShow] = useState(false);

    useEffect(() => {
        if (value.length < 2) {
            setSuggestions([]);
            return;
        }
        const delayDebounce = setTimeout(() => {
            fetch(`/ajax/stock/accession_autocomplete?term=${encodeURIComponent(value)}`)
                .then(res => res.json())
                .then((data: any) => {
                    if (Array.isArray(data)) {
                        const list = data.map(item => typeof item === 'string' ? item : item.label || item.value);
                        setSuggestions(list);
                    }
                })
                .catch(() => {});
        }, 300);
        return () => clearTimeout(delayDebounce);
    }, [value]);

    return (
        <div className="tw:relative">
            <input
                type="text"
                value={value}
                onChange={e => { onChange(e.target.value); setShow(true); }}
                onBlur={() => setTimeout(() => setShow(false), 200)}
                placeholder={placeholder}
                className={className}
            />
            {show && suggestions.length > 0 && (
                <ul className="dropdown-menu tw:block! tw:w-full tw:max-h-50 tw:overflow-y-auto tw:z-1000">
                    {suggestions.map((s, idx) => (
                        <li key={idx} onMouseDown={() => { onChange(s); setShow(false); }} className="tw:cursor-pointer">
                            <a>{s}</a>
                        </li>
                    ))}
                </ul>
            )}
        </div>
    );
};

interface FieldMapContainerProps {
    trialId: string;
    trialStockType: string;
    hasColAndRowNumbers: boolean;
    hasSubplotEntries: boolean;
    hasPlantEntries: boolean;
    authToken?: string;
}


const FieldMapContainer: React.FC<FieldMapContainerProps> = ({
    trialId,
    trialStockType,
    hasColAndRowNumbers,
    hasSubplotEntries,
    hasPlantEntries,
    authToken
}) => {
    const [loading, setLoading] = useState(false);
    const [selectedViewLabel, setSelectedViewLabel] = useState<string>('');
    const [plotObject, setPlotObject] = useState<Record<string, Plot>>({});
    const [variables, setVariables] = useState<Record<string, string>>({});
    const [selectedView, setSelectedView] = useState<string>('fieldmap');
    const [displayLinkedTrials, setDisplayLinkedTrials] = useState(false);
    const [linkedTrialsList, setLinkedTrialsList] = useState<TrialDetails[]>([]);
    const [activeTrialIds, setActiveTrialIds] = useState<string[]>([trialId]);

    const [plotLayout, setPlotLayout] = useState<'serpentine' | 'zigzag'>('serpentine');
    const [invertRows, setInvertRows] = useState(false);
    const [colorVar, setColorVar] = useState<'parity' | 'germplasm' | 'block' | 'family_name' | 'cross_name'>('parity');
    const [labelVar, setLabelVar] = useState<'plot_number' | 'germplasm' | 'block' | 'family_name' | 'cross_name'>('plot_number');
    const [labelSize, setLabelSize] = useState(10);

    const [invertCols, setInvertCols] = useState(false);
    const [topBorder, setTopBorder] = useState(false);
    const [leftBorder, setLeftBorder] = useState(false);
    const [rightBorder, setRightBorder] = useState(false);
    const [bottomBorder, setBottomBorder] = useState(false);
    const [dimensions, setDimensions] = useState({ rows: 0, cols: 0 });

    const [showDimDialog, setShowDimDialog] = useState(false);
    const [dimRowsInput, setDimRowsInput] = useState('');
    const [dimColsInput, setDimColsInput] = useState('');
    const [fillerAccessionInput, setFillerAccessionInput] = useState('');
    const [fillerAccessionId, setFillerAccessionId] = useState<string | undefined>(undefined);

    const [heatmapData, setHeatmapData] = useState<Record<string, HeatmapValue>>({});
    const [spatialAdjustments, setSpatialAdjustments] = useState<Record<string, Record<string, number>>>({});
    const [controlAccessions, setControlAccessions] = useState<string[]>([]);
    const [selectedControlPlot, setSelectedControlPlot] = useState<string>('');
    const [controlRelationshipText, setControlRelationshipText] = useState<string>('');
    const [showControlsSection, setShowControlsSection] = useState(false);

    const [hoveredPlot, setHoveredPlot] = useState<{ plot: Plot; x: number; y: number } | null>(null);
    const [selectedPlot, setSelectedPlot] = useState<Plot | null>(null);
    const [plotStructure, setPlotStructure] = useState<PlotStructureNode | null>(null);
    const [plotImages, setPlotImages] = useState<string>('');
    const [plotContentCache, setPlotContentCache] = useState<Record<string, string[]>>({});
    const [showPlotDetails, setShowPlotDetails] = useState(false);
    const [showEditAccession, setShowEditAccession] = useState(false);
    const [newAccession, setNewAccession] = useState('');
    const [newPlotName, setNewPlotName] = useState('');

    const [showCuratorWarning, setShowCuratorWarning] = useState(false);
    const [showSuppressModal, setShowSuppressModal] = useState(false);
    const [showDeleteTraitModal, setShowDeleteTraitModal] = useState(false);
    const [showDownloadCSVModal, setShowDownloadCSVModal] = useState(false);

    const [csvDownloadOpts, setCsvDownloadOpts] = useState({
        accession: true,
        obsUnit: false,
        seedlot: false,
        plotId: false,
        plotNum: false,
        familyName: false,
        crossName: false,
    });

    const clickTimer = useRef<NodeJS.Timeout | null>(null);
    const geoMapRef = useRef<HTMLDivElement | null>(null);
    const leafletMapInstance = useRef<any>(null);

    const [downloadOpts, setDownloadOpts] = useState({
        type: '',
        order: 'by_row_zigzag',
        start: 'bottom_left',
        borders: false,
        gaps: false,
        subplots: false,
        plants: false,
        hmPltid: 'plot_id',
        hmRange: 'row_number',
        hmRow: 'col_number'
    });

    const stockLabel = useMemo(() => {
        if (trialStockType === 'cross') return 'Cross';
        if (trialStockType === 'family_name') return 'Family';
        return 'Accession';
    }, [trialStockType]);

    useEffect(() => {
        if (loading) {
            jQuery("#working_modal").modal("show");
        } else {
            jQuery("#working_modal").modal("hide");
        }
    }, [loading]);

    useEffect(() => {
        fetchObservationUnits();
        loadVariables();
        loadSpatialAdjustments();
    }, [activeTrialIds]);

    useEffect(() => {
        fetch(`/ajax/breeders/trial/${trialId}/controls`)
            .then(res => res.json())
            .then(response => {
                if (response?.accessions) {
                    setControlAccessions(response.accessions.map((a: any) => a.accession_name));
                }
            })
            .catch(() => {});
    }, [trialId]);

    // Handle Leaflet GeoMap rendering
    useEffect(() => {
        if (selectedView === 'geofieldmap' && geoMapRef.current) {
            if (leafletMapInstance.current) {
                leafletMapInstance.current.remove();
            }
            try {
                // Initialize custom Leaflet container mapping
                const mapEl = geoMapRef.current;
                mapEl.innerHTML = "<div id='geoflatmap_leaflet' style='width:100%; height:600px;'></div>";
                
                const fmInstance = new BrAPIFieldmap('#geoflatmap_leaflet', '/brapi/v2', {
                    viewOnly: false,
                    brapi_auth: authToken,
                    defaultPos: [0, 0],
                    defaultZoom: 2,
                    plotScaleFactor: 1,
                    style: { weight: 1, color: '#41b6c4', fillOpacity: 0.4 }
                });
                fmInstance.load(trialId).then((success: boolean) => {
                    if (!success) {
                        alert("No geo reference data in this trial!");
                    }
                });
                leafletMapInstance.current = fmInstance.map;
                (window as any).geoFieldMapInstance = fmInstance;
            } catch (e) {
                console.error("Leaflet initialization failed", e);
            }
        }
        return () => {
            if (leafletMapInstance.current) {
                leafletMapInstance.current.remove();
                leafletMapInstance.current = null;
            }
            delete (window as any).geoFieldMapInstance;
        };
    }, [selectedView, trialId, authToken]);

    const fetchObservationUnits = () => {
        setLoading(true);
        const headers: Record<string, string> = {};
        if (authToken) {
            headers['Authorization'] = `Bearer ${authToken}`;
        }

        const url = `/brapi/v2/observationunits?studyDbIds=${activeTrialIds.join(',')}&observationUnitLevelName=plot&pageSize=10000`;
        fetch(url, { headers })
            .then(res => res.json())
            .then(response => {
                const units = response?.result?.data || [];
                if (units.length > 0) {
                    const firstInfo = units[0].additionalInfo;
                    if (firstInfo) {
                        setTopBorder(firstInfo.top_border_selection);
                        setLeftBorder(firstInfo.left_border_selection);
                        setRightBorder(firstInfo.right_border_selection);
                        setBottomBorder(firstInfo.bottom_border_selection);
                        setInvertRows(firstInfo.invert_row_checkmark);
                        setInvertCols(firstInfo.invert_col_checkmark);
                        if (firstInfo.plot_layout) {
                            setPlotLayout(firstInfo.plot_layout);
                        }
                        if (firstInfo.plot_color_var) setColorVar(firstInfo.plot_color_var);
                        if (firstInfo.plot_label_var) setLabelVar(firstInfo.plot_label_var);
                        if (firstInfo.plot_label_size) setLabelSize(firstInfo.plot_label_size);
                    }
                    parsePlotData(units);
                }
                setLoading(false);
            })
            .catch(() => {
                setLoading(false);
                alert('Error loading plot units.');
            });
    };

    const loadVariables = () => {
        const headers: Record<string, string> = {};
        if (authToken) {
            headers['Authorization'] = `Bearer ${authToken}`;
        }
        fetch(`/brapi/v2/variables?studyDbId=${trialId}&pageSize=10000`, { headers })
            .then(res => res.json())
            .then(response => {
                const data = response?.result?.data || [];
                const vars: Record<string, string> = {};
                data.forEach((v: any) => {
                    if (v.observationVariableName && v.observationVariableDbId) {
                        vars[v.observationVariableName] = v.observationVariableDbId;
                    }
                });
                setVariables(vars);
            })
            .catch(() => {});
    };

    const loadSpatialAdjustments = () => {
        fetch(`/ajax/spatial_model/retrieve_spatial_adjustments/${trialId}`)
            .then(res => res.json())
            .then(response => {
                if (response?.data) {
                    setSpatialAdjustments(JSON.parse(response.data));
                }
            })
            .catch(() => {});
    };

    const parsePlotData = (data: any[]) => {
        const mapped: Record<string, Plot> = {};
        const pseudo_layout: Record<string, number> = {};

        let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;

        data.forEach(plot => {
            let x = parseInt(plot.observationUnitPosition?.positionCoordinateX);
            let y = parseInt(plot.observationUnitPosition?.positionCoordinateY);

            if (isNaN(y)) {
                const rel = plot.observationUnitPosition?.observationLevelRelationships || [];
                const blockRel = rel.find((r: any) => r.levelName === 'block');
                const repRel = rel.find((r: any) => r.levelName === 'rep');
                const plotRel = rel.find((r: any) => r.levelName === 'plot');
                const code = blockRel?.levelCode || repRel?.levelCode || plotRel?.levelCode || '1';
                y = parseInt(code);
                if (isNaN(y)) y = 1;
            }

            if (isNaN(x)) {
                if (pseudo_layout[y] !== undefined) {
                    pseudo_layout[y] += 1;
                    x = pseudo_layout[y];
                } else {
                    pseudo_layout[y] = 1;
                    x = 1;
                }
            }

            if (!isNaN(x)) { minX = Math.min(minX, x); maxX = Math.max(maxX, x); }
            if (!isNaN(y)) { minY = Math.min(minY, y); maxY = Math.max(maxY, y); }

            if (plot.observationUnitPosition?.observationLevel?.levelName === 'plot') {
                let type: Plot['type'] = 'data';
                if (plot.observationUnitPosition.entryType === 'filler' || plot.germplasmName === 'Filler') type = 'filler';
                else if (plot.observationUnitPosition.entryType === 'border') type = 'border';

                mapped[plot.observationUnitDbId] = {
                    type,
                    observationUnitDbId: plot.observationUnitDbId,
                    observationUnitName: plot.observationUnitName,
                    observationUnitPosition: {
                        positionCoordinateX: x,
                        positionCoordinateY: y,
                        observationLevel: plot.observationUnitPosition.observationLevel,
                        observationLevelRelationships: plot.observationUnitPosition.observationLevelRelationships,
                        entryType: plot.observationUnitPosition.entryType
                    },
                    germplasmDbId: plot.germplasmDbId,
                    germplasmName: plot.germplasmName,
                    crossName: plot.crossName,
                    locationName: plot.locationName,
                    studyName: plot.studyName,
                    plotImageDbIds: plot.plotImageDbIds || [],
                    additionalInfo: plot.additionalInfo || {}
                };
            }
        });
        setPlotObject(mapped);
        setDimensions({
            rows: isFinite(maxY) ? maxY - minY + 1 : 0,
            cols: isFinite(maxX) ? maxX - minX + 1 : 0
        });
    };

    const toggleLinkedTrials = (checked: boolean) => {
        setDisplayLinkedTrials(checked);
        if (checked) {
            fetch(`/ajax/breeders/trial/${trialId}/linked_field_trials`)
                .then(res => res.json())
                .then(response => {
                    if (response?.trials) {
                        const list = response.trials.map((t: any, i: number) => {
                            const idx = i % trial_colors.length;
                            return {
                                id: t.trial_id,
                                name: t.trial_name,
                                bg: trial_colors[idx],
                                fg: trial_colors_text[idx]
                            };
                        });
                        setLinkedTrialsList(list);
                        setActiveTrialIds([trialId, ...list.map((l: any) => l.id)]);
                    } else {
                        alert(response?.error || 'Could not load linked trials.');
                        setDisplayLinkedTrials(false);
                    }
                })
                .catch(() => {
                    setDisplayLinkedTrials(false);
                });
        } else {
            setLinkedTrialsList([]);
            setActiveTrialIds([trialId]);
        }
    };

    const plotList = useMemo(() => {
        return Object.values(plotObject);
    }, [plotObject]);

    const germplasmPalette = useMemo(() => {
        const names = Array.from(new Set(plotList.map(p => p.germplasmName || p.crossName || p.additionalInfo?.familyName || '')))
            .filter(n => n && n !== 'Filler');
        const mapping: Record<string, string> = {};
        names.sort().forEach((name, i) => {
            mapping[name] = palette[i % palette.length];
        });
        return mapping;
    }, [plotList]);

    const blockPalette = useMemo(() => {
        const blocks = Array.from(new Set(plotList.map(p => {
            return p.observationUnitPosition?.observationLevelRelationships?.find(r => r.levelName === 'block')?.levelCode || '';
        }))).filter(b => b !== '');
        const mapping: Record<string, string> = {};
        blocks.sort().forEach((block, i) => {
            mapping[block] = palette[i % palette.length];
        });
        return mapping;
    }, [plotList]);

    const familyNamePalette = useMemo(() => {
        const family_names = Array.from(new Set(plotList.map(p => {
            return p.additionalInfo?.familyName || '';
        }))).filter(b => b !== '');
        const mapping: Record<string, string> = {};
        family_names.sort().forEach((family_name, i) => {
            mapping[family_name] = palette[i % palette.length];
        });
        return mapping;
    }, [plotList]);

    const crossNamePalette = useMemo(() => {
        const cross_names = Array.from(new Set(plotList.map(p => {
            return p.crossName || '';
        }))).filter(b => b !== '');
        const mapping: Record<string, string> = {};
        cross_names.sort().forEach((cross_name, i) => {
            mapping[cross_name] = palette[i % palette.length];
        });
        return mapping;
    }, [plotList]);

    const controlPlots = useMemo(() => {
        return plotList.filter(p => {
            return p.type === 'data' && (p.additionalInfo?.is_a_control || (p.germplasmName && controlAccessions.includes(p.germplasmName)));
        });
    }, [plotList, controlAccessions]);

    const maxLevelCode = useMemo(() => {
        let maxVal = 0;
        plotList.forEach(plot => {
            const code = parseInt(String(plot.observationUnitPosition?.observationLevel?.levelCode));
            if (!isNaN(code) && code > maxVal) {
                maxVal = code;
            }
        });
        return maxVal;
    }, [plotList]);

    const bounds = useMemo(() => {
        if (plotList.length === 0) return { minCol: 1, maxCol: dimensions.cols || 1, minRow: 1, maxRow: dimensions.rows || 1, numRows: dimensions.rows || 1, numCols: dimensions.cols || 1 };
        let minCol = Infinity;
        let minRow = Infinity;
        let maxCol = -Infinity;
        let maxRow = -Infinity;

        plotList.forEach(p => {
            const x = Number(p.observationUnitPosition.positionCoordinateX);
            const y = Number(p.observationUnitPosition.positionCoordinateY);
            if (!isNaN(x)) {
                if (x < minCol) minCol = x;
                if (x > maxCol) maxCol = x;
            }
            if (!isNaN(y)) {
                if (y < minRow) minRow = y;
                if (y > maxRow) maxRow = y;
            }
        });

        if (minCol === Infinity) minCol = 1;
        if (maxCol === -Infinity) maxCol = 1;
        if (minRow === Infinity) minRow = 1;
        if (maxRow === -Infinity) maxRow = 1;

        if (dimensions.cols > (maxCol - minCol + 1)) {
            maxCol = minCol + dimensions.cols - 1;
        }
        if (dimensions.rows > (maxRow - minRow + 1)) {
            maxRow = minRow + dimensions.rows - 1;
        }

        return {
            minCol,
            maxCol,
            minRow,
            maxRow,
            numRows: maxRow - minRow + 1,
            numCols: maxCol - minCol + 1
        };
    }, [plotList, dimensions]);

    const renderBounds = useMemo(() => {
        const { minCol, maxCol, minRow, maxRow } = bounds;
        const rMinCol = leftBorder ? minCol - 1 : minCol;
        const rMaxCol = rightBorder ? maxCol + 1 : maxCol;
        const rMinRow = bottomBorder ? minRow - 1 : minRow;
        const rMaxRow = topBorder ? maxRow + 1 : maxRow;

        return {
            minCol: rMinCol,
            maxCol: rMaxCol,
            minRow: rMinRow,
            maxRow: rMaxRow,
            numRows: rMaxRow - rMinRow + 1,
            numCols: rMaxCol - rMinCol + 1
        };
    }, [bounds, topBorder, bottomBorder, leftBorder, rightBorder]);

    const gridMatrix = useMemo(() => {
        const { minCol, maxCol, minRow, maxRow } = renderBounds;
        const matrix: Plot[][] = [];
        const indexed: Record<string, Plot[]> = {};

        plotList.forEach(p => {
            const x = Number(p.observationUnitPosition.positionCoordinateX);
            const y = Number(p.observationUnitPosition.positionCoordinateY);
            const key = `${x}-${y}`;
            if (!indexed[key]) indexed[key] = [];
            indexed[key].push(p);
        });

        for (let r = minRow; r <= maxRow; r++) {
            const rowArr: Plot[] = [];
            for (let c = minCol; c <= maxCol; c++) {
                const key = `${c}-${r}`;
                const found = indexed[key];
                if (found && found.length > 0) {
                    rowArr.push(found[0]);
                } else {
                    const isBorder = (r < bounds.minRow || r > bounds.maxRow || c < bounds.minCol || c > bounds.maxCol);
                    rowArr.push({
                        type: isBorder ? 'border' : (fillerAccessionId ? 'filler' : 'empty_space'),
                        observationUnitName: isBorder ? `Border (${c}_${r})` : (fillerAccessionId ? `Filler (${c}_${r})` : `Space (${c}_${r})`),
                        observationUnitPosition: {
                            positionCoordinateX: c,
                            positionCoordinateY: r,
                            observationLevel: { levelCode: '', levelName: 'plot' },
                            entryType: isBorder ? 'border' : (fillerAccessionId ? 'filler' : undefined)
                        }
                    });
                }
            }
            matrix.push(rowArr);
        }

        return matrix;
    }, [bounds, renderBounds, plotList, fillerAccessionId]);

    const overlappingPlots = useMemo(() => {
        const positions: Record<string, Plot[]> = {};
        plotList.forEach(p => {
            const x = p.observationUnitPosition?.positionCoordinateX;
            const y = p.observationUnitPosition?.positionCoordinateY;
            if (x !== undefined && y !== undefined) {
                const key = `${x}-${y}`;
                if (!positions[key]) positions[key] = [];
                positions[key].push(p);
            }
        });
        const overlaps: Record<string, Plot[]> = {};
        Object.entries(positions).forEach(([key, plots]) => {
            if (plots.length > 1) overlaps[key] = plots;
        });
        return overlaps;
    }, [plotList]);

    const recalculateLayout = (currentPlots: Record<string, Plot>, rows: number, cols: number, layout: 'serpentine' | 'zigzag') => {
        const plotsArr = Object.values(currentPlots).filter(p => !!p.observationUnitDbId);
        
        let minC = Infinity, minR = Infinity;
        plotsArr.forEach(p => {
            const x = Number(p.observationUnitPosition.positionCoordinateX);
            const y = Number(p.observationUnitPosition.positionCoordinateY);
            if (x < minC) minC = x;
            if (y < minR) minR = y;
        });
        if (minC === Infinity) minC = 1;
        if (minR === Infinity) minR = 1;

        const sortedPlots = [...plotsArr];
        sortedPlots.sort((a, b) => {
            const codeA = parseFloat(String(a.observationUnitPosition?.observationLevel?.levelCode)) || 0;
            const codeB = parseFloat(String(b.observationUnitPosition?.observationLevel?.levelCode)) || 0;
            return codeA - codeB;
        });

        const newPlotObject: Record<string, Plot> = {};
        let plotIdx = 0;
        for (let r = 0; r < rows; r++) {
            const currentRow = minR + r;
            const swap_columns = layout === 'serpentine' && (currentRow % 2 === 0);

            for (let c = 0; c < cols; c++) {
                if (plotIdx < sortedPlots.length) {
                    const plot = sortedPlots[plotIdx];
                    const currentCol = swap_columns ? (minC + cols - 1 - c) : (minC + c);

                    newPlotObject[plot.observationUnitDbId!] = {
                        ...plot,
                        observationUnitPosition: {
                            ...plot.observationUnitPosition,
                            positionCoordinateX: currentCol,
                            positionCoordinateY: currentRow,
                        }
                    };
                    plotIdx++;
                }
            }
        }
        return newPlotObject;
    };

    const fetchHeatmapObservations = (variableId: string) => {
        setLoading(true);
        const headers: Record<string, string> = {};
        if (authToken) {
            headers['Authorization'] = `Bearer ${authToken}`;
        }
        fetch(`/brapi/v2/observations?observationVariableDbId=${variableId}&studyDbId=${activeTrialIds.join(',')}&pageSize=10000`, { headers })
            .then(res => res.json())
            .then(response => {
                const data = response?.result?.data || [];
                const map: Record<string, HeatmapValue> = {};
                data.forEach((obs: any) => {
                    let finalVal = Number(obs.value);
                    const plotName = obs.observationUnitName;

                    // Apply Spatial adjustments if viewing Corrected or Adjustments
                    if (selectedView.includes(' (corrected)') && spatialAdjustments[plotName]?.[variableId] !== undefined) {
                        finalVal += Number(spatialAdjustments[plotName][variableId]);
                    } else if (selectedView.includes(' (adjustment)') && spatialAdjustments[plotName]?.[variableId] !== undefined) {
                        finalVal = Number(spatialAdjustments[plotName][variableId]);
                    }

                    if (!isNaN(finalVal)) {
                        map[obs.observationUnitDbId] = {
                            val: finalVal,
                            plot_name: obs.observationUnitName,
                            id: obs.observationDbId
                        };
                    }
                });
                setHeatmapData(map);
                setLoading(false);
            })
            .catch(() => {
                setLoading(false);
            });
    };

    const handleViewChange = (val: string) => {
        setSelectedView(val);
        if (val === 'fieldmap' || val === 'geofieldmap') {
            setHeatmapData({});
        } else if (val) {
            const variableId = val.replace(' (corrected)', '').replace(' (adjustment)', '');
            fetchHeatmapObservations(variableId);
        }
    };

    const valueColorScale = useMemo(() => {
        const values = Object.values(heatmapData).map(v => v.val);
        if (values.length === 0) return { min: 0, max: 0, scale: (val: number) => '#ffffff' };
        const min = Math.min(...values);
        const max = Math.max(...values);

        // Skewness power transform scaling
        const skew = pearsonSkewness(values);
        const exponent = skew > 0.5 ? 0.5 : 1.0;

        const hasNegatives = values.some(v => v < 0);
        const hasPositives = values.some(v => v > 0);
        const colors = (hasNegatives && !hasPositives) ? ['darkblue', 'white'] : (!hasNegatives && hasPositives) ? ['white', 'darkred'] : ['darkblue', 'white', 'darkred'];

        const scale = (val: number) => {
            if (min === max) return colors[0];
            const factor = Math.pow((val - min) / (max - min), exponent);
            if (colors.length === 3) {
                if (factor < 0.5) {
                    return interpolate(colors[0], colors[1], factor * 2);
                } else {
                    return interpolate(colors[1], colors[2], (factor - 0.5) * 2);
                }
            } else {
                return interpolate(colors[0], colors[1], factor);
            }
        };
        return { min, max, scale, colors };
    }, [heatmapData, selectedView]);

    // Handle click vs double click logic
    const handlePlotSelect = (plot: Plot) => {
        if (clickTimer.current) {
            clearTimeout(clickTimer.current);
            clickTimer.current = null;
            // Double Click behavior
            if (plot.observationUnitDbId) {
                window.open(`/stock/${plot.observationUnitDbId}/view`, '_blank');
            }
        } else {
            clickTimer.current = setTimeout(() => {
                clickTimer.current = null;
                // Single Click behavior
                if (plot.type === 'empty_space') return;
                setSelectedPlot(plot);
                setShowPlotDetails(true);
                setPlotStructure(null);
                setPlotImages('');

                fetch(`/stock/get_child_stocks/${plot.observationUnitDbId}`)
                    .then(res => res.json())
                    .then(response => {
                        if (response?.data) {
                            const struct = JSON.parse(response.data);
                            const plants: string[] = [];
                            if (struct.has) {
                                Object.values(struct.has).forEach((node: any) => {
                                    if (node.type === 'plant') plants.push(node.name || '');
                                });
                            }
                            setPlotContentCache(prev => ({ ...prev, [plot.observationUnitDbId!]: plants }));
                            setPlotStructure(struct);
                        }
                    })
                    .catch(() => {});

                fetch(`/ajax/breeders/trial/${trialId}/retrieve_plot_images`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: new URLSearchParams({
                        image_ids: JSON.stringify(plot.plotImageDbIds || []),
                        plot_name: plot.observationUnitName,
                        plot_id: plot.observationUnitDbId || ''
                    })
                })
                    .then(res => res.json())
                    .then(response => {
                        if (response?.image_html) {
                            setPlotImages(response.image_html);
                        }
                    })
                    .catch(() => {});
            }, 250);
        }
    };

    const submitReplaceAccession = (override: 'check' | 'override') => {
        if (!selectedPlot) return;
        setLoading(true);
        fetch(`/ajax/breeders/trial/${trialId}/replace_plot_accessions`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
                new_accession: newAccession,
                new_plot_name: newPlotName,
                old_accession: selectedPlot.germplasmName || '',
                old_plot_id: selectedPlot.observationUnitDbId || '',
                old_plot_name: selectedPlot.observationUnitName,
                override: override
            })
        })
            .then(res => res.json())
            .then(response => {
                if (response.warning) {
                    setLoading(false);
                    setShowCuratorWarning(true);
                } else if (response.error) {
                    setLoading(false);
                    alert(response.error);
                } else {
                    alert('Plot Accession Replaced successfully!');
                    setShowPlotDetails(false);
                    setShowEditAccession(false);
                    setShowCuratorWarning(false);
                    fetchObservationUnits();
                }
            })
            .catch(() => {
                setLoading(false);
            });
    };

    const submitFieldLayout = () => {
        const answer = window.confirm('You are about to save this plot layout to the database. Are you sure you would like to continue?');
        if (!answer) return;
        setLoading(true);

        const allPlots = gridMatrix.flat();
        const plotsToCreate = allPlots.filter(plot => !plot.observationUnitDbId && (plot.type === 'filler' || plot.type === 'border'));

        const brapiPostObject = fillerAccessionId ? plotsToCreate
            .map((plot, i) => ({
                additionalInfo: {
                    invert_row_checkmark: invertRows,
                    invert_col_checkmark: invertCols,
                    top_border_selection: topBorder,
                    left_border_selection: leftBorder,
                    right_border_selection: rightBorder,
                    bottom_border_selection: bottomBorder,
                    plot_layout: plotLayout,
                    plot_color_var: colorVar,
                    plot_label_var: labelVar,
                    plot_label_size: labelSize
                },
                germplasmDbId: fillerAccessionId,
                germplasmName: fillerAccessionInput,
                observationUnitName: `${trialId} filler ${maxLevelCode + i + 1}`,
                observationUnitPosition: {
                    observationLevel: { levelCode: maxLevelCode + i + 1, levelName: 'plot', levelOrder: 2 },
                    positionCoordinateX: plot.observationUnitPosition.positionCoordinateX,
                    positionCoordinateY: plot.observationUnitPosition.positionCoordinateY,
                    entryType: plot.type
                },
                trialDbId: trialId,
                studyDbId: trialId
            })) : [];

        const brapiPutObject: Record<string, any> = {};
        allPlots
            .filter(plot => !!plot.observationUnitDbId)
            .forEach(plot => {
                brapiPutObject[plot.observationUnitDbId!] = {
                    additionalInfo: {
                        invert_row_checkmark: invertRows,
                        invert_col_checkmark: invertCols,
                        top_border_selection: topBorder,
                        left_border_selection: leftBorder,
                        right_border_selection: rightBorder,
                        bottom_border_selection: bottomBorder,
                        plot_layout: plotLayout,
                        plot_color_var: colorVar,
                        plot_label_var: labelVar,
                        plot_label_size: labelSize
                    },
                    germplasmDbId: plot.germplasmDbId,
                    germplasmName: plot.germplasmName,
                    observationUnitName: plot.observationUnitName,
                    observationUnitPosition: {
                        observationLevel: { levelCode: plot.observationUnitPosition.observationLevel.levelCode, levelName: 'plot', levelOrder: 2 },
                        positionCoordinateX: plot.observationUnitPosition.positionCoordinateX,
                        positionCoordinateY: plot.observationUnitPosition.positionCoordinateY,
                        entryType: plot.type === 'data' ? plot.observationUnitPosition.entryType : plot.type
                    },
                    trialDbId: trialId
                };
            });

        const headers: Record<string, string> = { 'Content-Type': 'application/json' };
        if (authToken) headers['Authorization'] = `Bearer ${authToken}`;

        console.log('BRAPI POST OBJECT', brapiPostObject);
        console.log('BRAPI PUT OBJECT', brapiPutObject);

        const putPromise = fetch('/brapi/v2/observationunits', {
            method: 'PUT',
            headers,
            body: JSON.stringify(brapiPutObject)
        });

        const postPromise = brapiPostObject.length > 0
            ? fetch('/brapi/v2/observationunits', {
                method: 'POST',
                headers,
                body: JSON.stringify(brapiPostObject)
            })
            : Promise.resolve();

        Promise.all([putPromise, postPromise])
            .then(() => fetch(`/ajax/breeders/trial/${trialId}/refresh_cache`, { method: 'POST' }))
            .then(() => {
                alert('Field Plot layout submitted successfully!');
                fetchObservationUnits();
            })
            .catch(() => {
                setLoading(false);
                alert('Error submitting layout metadata.');
            });
    };

    const handleDownloadOrder = () => {
        const q = new URLSearchParams({
            trial_ids: activeTrialIds.join(','),
            type: downloadOpts.type,
            order: downloadOpts.order,
            start: downloadOpts.start,
            top_border: String(downloadOpts.borders && topBorder),
            right_border: String(downloadOpts.borders && rightBorder),
            bottom_border: String(downloadOpts.borders && bottomBorder),
            left_border: String(downloadOpts.borders && leftBorder),
            gaps: String(downloadOpts.gaps),
            subplots: String(downloadOpts.subplots),
            plants: String(downloadOpts.plants),
            hm_pltid: downloadOpts.hmPltid,
            hm_range: downloadOpts.hmRange,
            hm_row: downloadOpts.hmRow
        }).toString();
        window.open(`/ajax/breeders/trial_plot_order?${q}`, '_blank');
    };

    const submitGeoLayout = () => {
        const fm = (window as any).geoFieldMapInstance;
        if (fm) {
            setLoading(true);
            fm.update()
                .then((msg: string) => {
                    alert(msg || 'Geo layout updated successfully!');
                    fetchObservationUnits();
                })
                .catch((err: any) => {
                    setLoading(false);
                    alert(err || 'Failed to update geo layout');
                });
        }
    };

    const handleApplyDimensions = () => {
        const cols = parseInt(dimColsInput) || 0;
        const rows = parseInt(dimRowsInput) || 0;
        const numRealPlots = plotList.length;

        if (cols * rows < numRealPlots) {
            alert('Those are not valid dimensions.\nPlease select dimensions that can accommodate your current plots.');
            return;
        }

        const proceed = (accessionId?: string) => {
            if (accessionId) setFillerAccessionId(accessionId);
            setDimensions({ rows, cols });
            setPlotObject(prev => recalculateLayout(prev, rows, cols, plotLayout));
            setShowDimDialog(false);
        };

        if (fillerAccessionInput) {
            fetch(`/ajax/breeders/trial/${trialId}/accession_exists?accession_name=${encodeURIComponent(fillerAccessionInput)}`)
                .then(res => res.json())
                .then(response => {
                    if (response.success) proceed(response.success); else alert(response.error || 'Accession not found.');
                });
        } else {
            proceed();
        }
    };

    const handleTranspose = () => {
        setPlotObject(current => {
            const transposed: Record<string, Plot> = {};
            for (const [id, plot] of Object.entries(current)) {
                transposed[id] = {
                    ...plot,
                    observationUnitPosition: {
                        ...plot.observationUnitPosition,
                        positionCoordinateX: plot.observationUnitPosition.positionCoordinateY,
                        positionCoordinateY: plot.observationUnitPosition.positionCoordinateX
                    }
                };
            }
            return transposed;
        });
        setDimensions(d => ({ rows: d.cols, cols: d.rows }));
    };

    const handleRotate = () => {
        const { minCol, maxCol } = bounds;
        setPlotObject(current => {
            const rotated: Record<string, Plot> = {};
            for (const [id, plot] of Object.entries(current)) {
                const oldX = Number(plot.observationUnitPosition.positionCoordinateX);
                const oldY = Number(plot.observationUnitPosition.positionCoordinateY);

                rotated[id] = {
                    ...plot,
                    observationUnitPosition: {
                        ...plot.observationUnitPosition,
                        // CW 90deg: newX = oldY, newY = maxCol - oldX + minCol
                        positionCoordinateX: oldY,
                        positionCoordinateY: maxCol - oldX + minCol
                    }
                };
            }
            return rotated;
        });
        setDimensions(d => ({ rows: d.cols, cols: d.rows }));
    };


    const handlePrint = () => {
        alert("You may need to change print settings - such as page size, margins, and scaling - to get the fieldmap to display properly in the print preview. Select \"Background graphics\" to ensure the legend includes colors.");
        const title = selectedView === 'fieldmap' ? 'Field Map View' : selectedViewLabel;
        const printWindow = window.open('', '', 'width=800,height=600');
        if (printWindow) {
            printWindow.document.write('<html><head><title>Print Field Map</title>');
            
            // Copy styles from the main window to ensure Tailwind classes work in the print window
            document.querySelectorAll('style, link[rel="stylesheet"]').forEach(style => {
                printWindow.document.write(style.outerHTML);
            });

            // Extract the dynamic gradient style to override print resets
            const gradientDiv = document.querySelector('#legend_list div[style*="linear-gradient"]');
            const gradientStyle = gradientDiv ? (gradientDiv as HTMLElement).style.background : '';

            printWindow.document.write(`
                <style>
                    * {
                        -webkit-print-color-adjust: exact !important;
                        print-color-adjust: exact !important;
                    }
                    body {
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        flex-direction: column;
                        margin: 0;
                        padding: 20px;
                    }
                    svg {
                        max-width: 100%;
                        height: auto !important;
                        display: block;
                        margin: 0 auto;
                    }
                    #legend_list {
                        width: 100%;
                        margin-bottom: 20px;
                    }
                    @media print {
                        body { padding: 0; }
                        
                        /* Override aggressive print resets (like Bootstrap's) by using higher specificity than '*' */
                        #legend_list span, 
                        #legend_list div {
                            print-color-adjust: exact !important;
                            -webkit-print-color-adjust: exact !important;
                        }

                        /* Re-assert the dynamic heatmap gradient */
                        #legend_list div[style*="linear-gradient"] {
                            background: ${gradientStyle} !important;
                        }

                        /* Explicitly re-assert standard legend colors to fight off 'background: transparent !important' */
                        #legend_list .tw\\:bg-\\[\\#d3d3d3\\] { background-color: #d3d3d3 !important; }
                        #legend_list .tw\\:bg-\\[\\#c7e9b4\\] { background-color: #c7e9b4 !important; }
                        #legend_list .tw\\:bg-\\[\\#41b6c4\\] { background-color: #41b6c4 !important; }
                        #legend_list .tw\\:bg-\\[\\#6a5acd\\] { background-color: #6a5acd !important; }
                        #legend_list .tw\\:bg-\\[\\#008000\\] { background-color: #008000 !important; }
                        #legend_list .tw\\:bg-\\[\\#ff0000\\] { background-color: #ff0000 !important; }
                        #legend_list .tw\\:bg-\\[\\#000000\\] { background-color: #000000 !important; }
                        #legend_list .tw\\:bg-\\[\\#a9afaf\\] { background-color: #a9afaf !important; }
                        #legend_list .tw\\:bg-\\[\\#ffffff\\] { background-color: #ffffff !important; }
                    }
                </style>
            </head>
            <body>
                <h1>${title}</h1>
                ${document.getElementById('legend_list')?.outerHTML || ''}
                ${document.getElementById('fieldmap_chart_svg')?.outerHTML || ''}
            </body></html>
            `);
            printWindow.document.close();
            
            setTimeout(() => {
                if (printWindow) printWindow.print();
            }, 500);
        }
    };

    const downloadHeatmapImage = () => {
        const svgEl = document.getElementById('fieldmap_chart_svg');
        if (!svgEl) return;
        
        const svgString = new XMLSerializer().serializeToString(svgEl);
        const svgBlob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
        const blobURL = URL.createObjectURL(svgBlob);

        const image = new Image();
        image.onload = () => {
            const canvas = document.createElement('canvas');
            canvas.width = svgEl.clientWidth || 1500;
            canvas.height = svgEl.clientHeight || 1500;
            const context = canvas.getContext('2d');
            if (context) {
                context.fillStyle = '#ffffff';
                context.fillRect(0, 0, canvas.width, canvas.height);
                context.drawImage(image, 0, 0);
                
                const pngData = canvas.toDataURL('image/png');
                const downloadLink = document.createElement('a');
                downloadLink.download = `${selectedViewLabel || 'fieldmap'}_heatmap.png`;
                downloadLink.href = pngData;
                downloadLink.click();
            }
        };
        image.src = blobURL;
    };

    const handleDownloadCSV = () => {
        let cols_csv_header = [];
        for (let i = bounds.minCol; i <= bounds.maxCol; i++) {
            cols_csv_header.push(i);
        }
        if (invertCols) {
            cols_csv_header.reverse();
        }
        let csv = '';
        csv += ['Rows/Columns', ...cols_csv_header].join(',') + '\n';

        let coord_matrix: string[][] = [];
        const sortedPlots = [...plotList].filter(p => p.type !== 'border');

        sortedPlots.forEach(plot => {
            const r = Number(plot.observationUnitPosition.positionCoordinateY) - bounds.minRow;
            const c = Number(plot.observationUnitPosition.positionCoordinateX) - bounds.minCol;

            if (!coord_matrix[r]) coord_matrix[r] = [];

            let cellVal = '';
            if (csvDownloadOpts.accession) {
                cellVal += plot.germplasmName || plot.crossName || '';
                if (plot.additionalInfo?.intercropGermplasm) {
                    plot.additionalInfo.intercropGermplasm.forEach((g: any) => {
                        cellVal += `, ${g.germplasmName}`;
                    });
                }
            }
            if (csvDownloadOpts.obsUnit && plot.observationUnitName) {
                cellVal += (cellVal ? '\n' : '') + plot.observationUnitName;
            }
            if (csvDownloadOpts.plotId && plot.observationUnitDbId) {
                cellVal += (cellVal ? '\n' : '') + plot.observationUnitDbId;
            }
            if (csvDownloadOpts.plotNum && plot.observationUnitPosition.observationLevel?.levelCode) {
                cellVal += (cellVal ? '\n' : '') + plot.observationUnitPosition.observationLevel.levelCode;
            }
            if (csvDownloadOpts.familyName && plot.additionalInfo?.familyName) {
                cellVal += (cellVal ? '\n' : '') + plot.additionalInfo?.familyName;
            }
            if (csvDownloadOpts.crossName && plot.crossName) {
                cellVal += (cellVal ? '\n' : '') + plot.additionalInfo?.crossName;
            }

            coord_matrix[r][c] = `"${cellVal}"`;
        });

        if (!invertRows) {
            coord_matrix.reverse();
        }

        coord_matrix.forEach((rowArr, idx) => {
            if (!rowArr) rowArr = Array(bounds.numCols).fill('""');
            for (let i = 0; i < bounds.numCols; i++) {
                if (rowArr[i] === undefined) rowArr[i] = '""';
            }
            if (invertCols) {
                rowArr.reverse();
            }

            const rowLabel = invertRows ? bounds.minRow + idx : bounds.maxRow - idx;
            csv += [rowLabel, ...rowArr].join(',') + '\n';
        });

        const hiddenElement = document.createElement('a');
        hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csv);
        hiddenElement.target = '_blank';
        hiddenElement.download = `Trial_${trialId}_spatial_layout.csv`;
        hiddenElement.click();
        setShowDownloadCSVModal(false);
    };

    const handleSuppressPhenotype = () => {
        if (!selectedPlot) return;
        const currentTraitId = selectedView.replace(' (corrected)', '').replace(' (adjustment)', '');
        const valObj = heatmapData[selectedPlot.observationUnitDbId || ''];
        if (!valObj) return;

        setLoading(true);
        fetch(`/ajax/breeders/trial/${trialId}/suppress_phenotype`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
                plot_name: selectedPlot.observationUnitName,
                phenotype_value: String(valObj.val),
                trait_id: currentTraitId,
                phenotype_id: valObj.id
            })
        })
            .then(res => res.json())
            .then(response => {
                setLoading(false);
                if (response.error) {
                    alert(response.error);
                } else {
                    alert('Phenotype was suppressed successfully!');
                    setShowSuppressModal(false);
                    setShowPlotDetails(false);
                    fetchHeatmapObservations(currentTraitId);
                }
            })
            .catch(() => {
                setLoading(false);
            });
    };

    const handleDeleteSingleTrait = () => {
        const currentTraitId = selectedView.replace(' (corrected)', '').replace(' (adjustment)', '');
        setLoading(true);
        fetch(`/ajax/breeders/trial/${trialId}/delete_single_trait`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
                traits_id: JSON.stringify([currentTraitId])
            })
        })
            .then(res => res.json())
            .then(response => {
                setLoading(false);
                if (response.error) {
                    alert(response.error);
                } else {
                    alert('Trait deleted successfully!');
                    setShowDeleteTraitModal(false);
                    setSelectedView('fieldmap');
                    setHeatmapData({});
                    loadVariables();
                }
            })
            .catch(() => {
                setLoading(false);
            });
    };

    const plotStructureLayoutType = useMemo(() => {
        if (!plotStructure || !plotStructure.has) return 'none';
        const children = Object.values(plotStructure.has) as PlotStructureNode[];
        if (children.length > 0) {
            const firstChild = children[0];
            if (firstChild.type === 'subplot') {
                if (firstChild.has) {
                    const subChildren = Object.values(firstChild.has) as PlotStructureNode[];
                    if (subChildren.length > 0 && subChildren[0].attributes?.row_number?.value > 0) {
                        return 'subplot_grid';
                    }
                }
            } else if (firstChild.type === 'plant' && firstChild.attributes?.row_number?.value > 0) {
                return 'plant_grid';
            }
        }
        return 'tree';
    }, [plotStructure]);

    const svgWidth = (renderBounds.numCols + 1) * 55 + 50;
    const svgHeight = (renderBounds.numRows + 1) * 55 + 50;

    return (
        <div className="tw:p-3.75">
            <div className="panel panel-default">
                <div className="panel-body">
                    <div className="tw:flex tw:gap-6.25 tw:flex-wrap tw:items-center">
                        <div className="form-group tw:m-0 tw:min-w-50">
                            <label className="tw:mr-2.5">Select Layout View:</label>
                            <select
                                className="form-control"
                                value={selectedView}
                                onChange={e => {
                                    setSelectedViewLabel(e.target.options[e.target.selectedIndex]?.text || '');
                                    handleViewChange(e.target.value);
                                }}
                            >
                                <optgroup label="Field Map">
                                    <option value="fieldmap">View Field Layout</option>
                                    <option value="geofieldmap">View Geo Field Layout</option>
                                </optgroup>
                                <optgroup label="Assayed Traits">
                                    {Object.keys(variables).sort().map(name => (
                                        <option key={variables[name]} value={variables[name]}>{name}</option>
                                    ))}
                                </optgroup>
                                {Object.keys(spatialAdjustments).length > 0 && (
                                    <optgroup label="Spatial Corrections">
                                        {Object.keys(variables).sort().map(name => {
                                            const id = variables[name];
                                            return (
                                                <React.Fragment key={id}>
                                                    <option value={`${id} (corrected)`}>{name} (corrected)</option>
                                                    <option value={`${id} (adjustment)`}>{name} (adjustment)</option>
                                                </React.Fragment>
                                            );
                                        })}
                                    </optgroup>
                                )}
                            </select>
                        </div>

                        <div className="form-check tw:m-0">
                            <label className="form-check-label">
                                <input
                                    type="checkbox"
                                    className="form-check-input tw:mr-1.25"
                                    checked={displayLinkedTrials}
                                    onChange={e => toggleLinkedTrials(e.target.checked)}
                                />
                                Display Trials in Same Field
                            </label>
                        </div>
                    </div>

                    {displayLinkedTrials && linkedTrialsList.length > 0 && (
                        <div className="tw:mt-2.5 tw:p-2.5 tw:bg-[#f9f9f9] tw:rounded-lg">
                            <strong>Trials in Same Field:</strong>
                            <div className="tw:flex tw:gap-2.5 tw:flex-wrap tw:mt-1.25">
                                {linkedTrialsList.map(t => (
                                    <span key={t.id} style={{ background: t.bg, color: t.fg }} className="tw:px-2 tw:py-0.75 tw:rounded-lg tw:text-[12px]">
                                        {t.name}
                                    </span>
                                ))}
                            </div>
                        </div>
                    )}
                </div>
            </div>

            {selectedView !== 'fieldmap' && selectedView !== 'geofieldmap' && (
                <div className="panel panel-default">
                    <div className="panel-body tw:flex tw:gap-3.75 tw:items-center tw:flex-wrap">
                        {!showControlsSection ? (
                            <button className="btn btn-primary btn-sm" onClick={() => setShowControlsSection(true)}>View Controls</button>
                        ) : (
                            <div className="tw:flex tw:gap-2.5 tw:items-center tw:flex-wrap">
                                <select
                                    className="form-control"
                                    value={selectedControlPlot}
                                    onChange={e => {
                                        const val = e.target.value;
                                        setSelectedControlPlot(val);
                                        if (val) {
                                            const p = plotList.find(plot => plot.observationUnitDbId === val);
                                            if (p) {
                                                setControlRelationshipText(`Plot: ${p.observationUnitName} contains Check: ${p.germplasmName || ''}`);
                                            }
                                        } else {
                                            setControlRelationshipText('');
                                        }
                                    }}
                                >
                                    <option value="">checks and plot numbers</option>
                                    {controlPlots.map(cp => (
                                        <option key={cp.observationUnitDbId} value={cp.observationUnitDbId}>
                                            Plot:{cp.observationUnitName} [{cp.germplasmName}]
                                        </option>
                                    ))}
                                </select>
                                {controlRelationshipText && (
                                    <span className="text-sm font-semibold bg-[#fcf8e3] p-1 border rounded">{controlRelationshipText}</span>
                                )}
                                <button className="btn btn-default btn-xs" onClick={() => { setShowControlsSection(false); setSelectedControlPlot(''); setControlRelationshipText(''); }}>Hide</button>
                            </div>
                        )}
                    </div>
                </div>
            )}

            {/* Render view panel for Geo Field Map or Standard SVG Map */}
            {selectedView === 'geofieldmap' ? (
                <div key="geofieldmap-panel" className="panel panel-default">
                    <div className="panel-body tw:flex tw:flex-col tw:gap-2.5">
                        <div ref={geoMapRef} style={{ width: '100%', height: '600px' }}></div>
                        <button className="btn btn-success tw:self-start" onClick={submitGeoLayout}>Submit Geo Layout Changes</button>
                    </div>
                </div>
            ) : (
                <div key="standard-fieldmap-panel" className="panel panel-default">
                    <div className="panel-body tw:grid">
                        <div className="tw:flex tw:gap-5 tw:flex-wrap tw:mb-3.75">
                            <div className="form-inline">
                                <label className="tw:mr-1.25">Plot Layout:</label>
                                <select 
                                    className="form-control" 
                                    value={plotLayout} 
                                    onChange={e => {
                                        const nextLayout = e.target.value as 'serpentine' | 'zigzag';
                                        setPlotLayout(nextLayout);
                                        setPlotObject(prev => recalculateLayout(prev, dimensions.rows || bounds.numRows, dimensions.cols || bounds.numCols, nextLayout));
                                    }} 
                                    disabled={displayLinkedTrials}
                                >
                                    <option value="serpentine">Serpentine</option>
                                    <option value="zigzag">Zigzag</option>
                                </select>
                            </div>
                            <div className="form-check tw:flex tw:items-center">
                                <label className="form-check-label">
                                    <input type="checkbox" className="form-check-input tw:mr-1.25" checked={invertRows} onChange={e => setInvertRows(e.target.checked)} />
                                    Invert Rows
                                </label>
                            </div>
                            <div className="form-check tw:flex tw:items-center">
                                <label className="form-check-label">
                                    <input type="checkbox" className="form-check-input tw:mr-1.25" checked={invertCols} onChange={e => setInvertCols(e.target.checked)} />
                                    Invert Columns
                                </label>
                            </div>
                            <div className="form-inline">
                                <label className="tw:mr-1.25">Color By:</label>
                                <select className="form-control" value={colorVar} onChange={e => setColorVar(e.target.value as any)}>
                                    <option value="parity">Default (Parity)</option>
                                    <option value="germplasm">{stockLabel}</option>
                                    <option value="block">Block Number</option>
                                    <option value="family_name">Family</option>
                                    <option value="cross_name">Cross</option>
                                </select>
                            </div>
                            <div className="form-inline">
                                <label className="tw:mr-1.25">Label By:</label>
                                <select className="form-control" value={labelVar} onChange={e => setLabelVar(e.target.value as any)}>
                                    <option value="plot_number">Plot Number</option>
                                    <option value="germplasm">{stockLabel} Name</option>
                                    <option value="block">Block Number</option>
                                    <option value="family_name">Family</option>
                                    <option value="cross_name">Cross</option>
                                </select>
                            </div>
                            <div className="form-inline">
                                <label className="tw:mr-1.25">Label Size:</label>
                                <input type="number" className="form-control tw:w-15" value={labelSize} onChange={e => setLabelSize(parseInt(e.target.value) || 10)} />
                            </div>
                            <div className="tw:flex tw:gap-2.5 tw:items-center">
                                <label className="tw:m-0">Include Borders:</label>
                                <label className="tw:font-normal tw:m-0"><input type="checkbox" checked={topBorder} onChange={e => setTopBorder(e.target.checked)} disabled={displayLinkedTrials} /> Top</label>
                                <label className="tw:font-normal tw:m-0"><input type="checkbox" checked={bottomBorder} onChange={e => setBottomBorder(e.target.checked)} disabled={displayLinkedTrials} /> Bottom</label>
                                <label className="tw:font-normal tw:m-0"><input type="checkbox" checked={leftBorder} onChange={e => setLeftBorder(e.target.checked)} disabled={displayLinkedTrials} /> Left</label>
                                <label className="tw:font-normal tw:m-0"><input type="checkbox" checked={rightBorder} onChange={e => setRightBorder(e.target.checked)} disabled={displayLinkedTrials} /> Right</label>
                            </div>
                        </div>
                        <div className="tw:flex tw:gap-2.5 tw:flex-wrap tw:mb-3.75">
                            <button className="btn btn-default" onClick={handleTranspose} disabled={displayLinkedTrials}>Transpose Display</button>
                            <button className="btn btn-default" onClick={handleRotate} disabled={displayLinkedTrials}>Rotate</button>
                            <button className="btn btn-default" onClick={() => setShowDimDialog(true)} disabled={displayLinkedTrials}>Change Dimensions</button>
                            <button className="btn btn-default" onClick={() => setShowDownloadCSVModal(true)}>Download Spatial Layout (CSV)</button>
                            <button className="btn btn-default" onClick={handlePrint}>Print Fieldmap</button>
                            {selectedView !== 'fieldmap' && selectedView !== 'geofieldmap' && (
                                <button className="btn btn-default" onClick={downloadHeatmapImage}>Download Heatmap Image</button>
                            )}
                            <button className="btn btn-success" onClick={submitFieldLayout} disabled={displayLinkedTrials}>Submit Layout Changes</button>
                            {selectedView !== 'fieldmap' && selectedView !== 'geofieldmap' && (
                                <button className="btn btn-danger" onClick={() => setShowDeleteTraitModal(true)}>Delete Selected Trait</button>
                            )}
                        </div>

                        <div className="tw:relative tw:border tw:border-[#ddd] tw:p-2.5 tw:bg-[#fcfcfc] tw:min-h-75 tw:flex tw:overflow-auto">
                            <svg
                                id="fieldmap_chart_svg"
                                className="tw:max-w-none tw:shrink-0"
                                width={svgWidth}
                                height={svgHeight}
                                viewBox={`0 0 ${svgWidth} ${svgHeight}`}
                            >
                                <g transform="translate(50, 25)">
                                    {/* Pass 1: Render Plot Geometry (Backgrounds, Borders, Icons) */}
                                    {gridMatrix.map((row, rIdx) => {
                                        const displayY = invertRows ? rIdx : renderBounds.numRows - rIdx - 1;

                                        return (
                                            <g key={`row-group-${rIdx}`}>
                                                {row.map((plot, cIdx) => {
                                                    const displayXIdx = invertCols ? renderBounds.numCols - cIdx - 1 : cIdx;
                                                    const plotX = displayXIdx * 52;
                                                    const plotY = displayY * 52;

                                                    const isObsolete = plot.additionalInfo?.isObsolete;

                                                    const coordKey = `${plot.observationUnitPosition?.positionCoordinateX}-${plot.observationUnitPosition?.positionCoordinateY}`;
                                                    const isOverlapping = !!overlappingPlots[coordKey];

                                                    let fill = '#c7e9b4'; // Default block parity color (even block placeholder)
                                                    let stroke = '#41b6c4'; // Default replicate parity stroke
                                                    let strokeWidth = 1.5;

                                                    if (colorVar === 'germplasm') {
                                                        const name = plot.germplasmName || plot.crossName || plot.additionalInfo?.familyName || '';
                                                        if (name && name !== 'Filler' && germplasmPalette[name]) {
                                                            fill = germplasmPalette[name];
                                                        }
                                                    } else if (colorVar === 'block') {
                                                        const block = plot.observationUnitPosition?.observationLevelRelationships?.find(r => r.levelName === 'block')?.levelCode || '';
                                                        if (block && blockPalette[block]) {
                                                            fill = blockPalette[block];
                                                        }
                                                    } else if (colorVar === 'family_name') {
                                                        const family_name = plot.additionalInfo?.familyName || '';
                                                        if (family_name && familyNamePalette[family_name]) {
                                                            fill = familyNamePalette[family_name];
                                                        }
                                                    } else if (colorVar === 'cross_name') {
                                                        const cross_name = plot.crossName || '';
                                                        if (cross_name && crossNamePalette[cross_name]) {
                                                            fill = crossNamePalette[cross_name];
                                                        }
                                                    } else {
                                                        // Replicate even/odd stroke coloring
                                                        const repNo = parseInt(String(plot.observationUnitPosition?.observationLevelRelationships?.[0]?.levelCode));
                                                        if (!isNaN(repNo)) {
                                                            stroke = repNo % 2 === 0 ? 'red' : 'green';
                                                        }

                                                        // Block even/odd fill coloring
                                                        const blockNo = parseInt(String(plot.observationUnitPosition?.observationLevelRelationships?.[1]?.levelCode));
                                                        if (!isNaN(blockNo)) {
                                                            fill = blockNo % 2 === 0 ? '#c7e9b4' : '#41b6c4';
                                                        }
                                                    }

                                                    if (plot.observationUnitPosition?.entryType === 'check') fill = '#6a5acd';
                                                    else if (plot.type === 'border' || plot.type === 'filler') fill = '#ecefef';
                                                    else if (plot.type === 'empty_space') fill = 'transparent';

                                                    // Overlapping style override
                                                    if (isOverlapping) {
                                                        fill = '#000000';
                                                        stroke = '#ff0000';
                                                        strokeWidth = 3;
                                                    }

                                                    // Heatmap views logic
                                                    if (selectedView !== 'fieldmap' && selectedView !== 'geofieldmap' && plot.observationUnitDbId) {
                                                        const valObj = heatmapData[plot.observationUnitDbId];
                                                        fill = valObj ? valueColorScale.scale(valObj.val) : '#a9afaf';
                                                    }

                                                    if (isObsolete) return null;

                                                    return (
                                                        <g
                                                            key={plot.observationUnitDbId || `empty-${cIdx}-${rIdx}`}
                                                            transform={`translate(${plotX}, ${plotY})`}
                                                            className="tw:cursor-pointer"
                                                            onClick={() => handlePlotSelect(plot)}
                                                            onMouseEnter={(e) => setHoveredPlot({ plot, x: e.clientX, y: e.clientY })}
                                                            onMouseLeave={() => setHoveredPlot(null)}
                                                        >
                                                            {plot.type !== 'empty_space' && (
                                                                <rect
                                                                    width={50}
                                                                    height={50}
                                                                    rx={4}
                                                                    fill={fill}
                                                                    stroke={stroke}
                                                                    strokeWidth={strokeWidth}
                                                                />
                                                            )}

                                                            {/* Multiple trial colored band */}
                                                            {displayLinkedTrials && plot.studyName && (
                                                                <rect
                                                                    x={4}
                                                                    y={43}
                                                                    width={42}
                                                                    height={4}
                                                                    fill={linkedTrialsList.find(t => t.name === plot.studyName)?.bg || '#888'}
                                                                />
                                                            )}

                                                            {/* Camera Image Icon */}
                                                            {plot.plotImageDbIds && plot.plotImageDbIds.length > 0 && (
                                                                <g transform="translate(5, 5) scale(0.6)">
                                                                    <rect width="18" height="14" rx="2" fill="#ff8c00" />
                                                                    <circle cx="9" cy="7" r="3" fill="#ffffff" />
                                                                </g>
                                                            )}
                                                        </g>
                                                    );
                                                })}
											</g>
                                        );
									})}

                                    {/* Pass 2: Render Label Layer (Always on top) */}
                                    <g style={{ pointerEvents: 'none' }}>
                                        {/* Column Axis Labels (Top and Bottom) */}
                                        {Array.from({ length: bounds.numCols }).map((_, idx) => {
                                            const colCoord = bounds.minCol + idx;
                                            const colIdx = colCoord - renderBounds.minCol;
                                            const displayX = (invertCols ? renderBounds.numCols - colIdx - 1 : colIdx) * 52 + 25;
                                            return (
                                                <React.Fragment key={`col-lbl-grp-${idx}`}>
                                                    <text x={displayX} y={-10} textAnchor="middle" fontSize="11" fontWeight="bold" fill="#000">
                                                        {colCoord}
                                                    </text>
                                                    <text x={displayX} y={renderBounds.numRows * 52 + 20} textAnchor="middle" fontSize="11" fontWeight="bold" fill="#000">
                                                        {colCoord}
                                                    </text>
                                                </React.Fragment>
                                            );
                                        })}

                                        {/* Row Axis Labels (Left and Right) */}
                                        {gridMatrix.map((row, rIdx) => {
                                            const rCoord = renderBounds.minRow + rIdx;
                                            const isDataRow = rCoord >= bounds.minRow && rCoord <= bounds.maxRow;
                                            const displayY = invertRows ? rIdx : renderBounds.numRows - rIdx - 1;
                                            if (!isDataRow) return null;
                                            return (
                                                <React.Fragment key={`row-lbl-grp-${rIdx}`}>
                                                    <text x={-20} y={displayY * 52 + 30} textAnchor="middle" fontSize="11" fontWeight="bold" fill="#000">
                                                        {rCoord}
                                                    </text>
                                                    <text x={renderBounds.numCols * 52 + 20} y={displayY * 52 + 30} textAnchor="middle" fontSize="11" fontWeight="bold" fill="#000">
                                                        {rCoord}
                                                    </text>
                                                </React.Fragment>
                                            );
                                        })}

                                        {/* Individual Plot Labels */}
                                        {gridMatrix.map((row, rIdx) => {
                                            const displayY = invertRows ? rIdx : renderBounds.numRows - rIdx - 1;
                                            return row.map((plot, cIdx) => {
                                                if (plot.type !== 'data' || plot.additionalInfo?.isObsolete) return null;

                                                const displayXIdx = invertCols ? renderBounds.numCols - cIdx - 1 : cIdx;
                                                const plotX = displayXIdx * 52;
                                                const plotY = displayY * 52;

                                                const coordKey = `${plot.observationUnitPosition?.positionCoordinateX}-${plot.observationUnitPosition?.positionCoordinateY}`;
                                                const isOverlapping = !!overlappingPlots[coordKey];
                                                if (isOverlapping) return null;

                                                let labelText = String(plot.observationUnitPosition?.observationLevel?.levelCode || '');
                                                if (labelVar === 'germplasm') {
                                                    labelText = plot.germplasmName || plot.crossName || plot.additionalInfo?.familyName || '';
                                                    if (labelText === 'Filler') labelText = '';
                                                } else if (labelVar === 'block') {
                                                    labelText = plot.observationUnitPosition?.observationLevelRelationships?.find(r => r.levelName === 'block')?.levelCode || '';
                                                } else if (labelVar === 'family_name') {
                                                    labelText = plot.additionalInfo?.familyName || '';
                                                } else if (labelVar === 'cross_name') {
                                                    labelText = plot.crossName || '';
                                                }

                                                if (!labelText) return null;

                                                return (
                                                    <text
                                                        key={`plot-lbl-${plot.observationUnitDbId}`}
                                                        x={plotX + 25}
                                                        y={plotY + (labelVar === 'germplasm' ? (Number(plot.observationUnitPosition.positionCoordinateX) % 2 ? 20 : 40) : 30)}
                                                        textAnchor="middle"
                                                        fill="#000"
                                                        fontSize={labelSize}
                                                        fontWeight="bold"
                                                    >
                                                        {labelText}
                                                    </text>
                                                );
                                            });
                                        })}
                                    </g>
                                </g>
                            </svg>

                            {/* Dynamic Tooltip */}
                            {hoveredPlot && (
                                <div
                                    className="tw:fixed tw:bg-black/85 tw:text-white tw:px-3 tw:py-2 tw:rounded-md tw:z-10000 tw:text-[11px] tw:pointer-events-none tw:max-w-70"
                                    style={{
                                        top: hoveredPlot.y + 15,
                                        left: hoveredPlot.x + 15,
                                    }}
                                >
                                    {(() => {
                                        const plot = hoveredPlot.plot;
                                        const coordKey = `${plot.observationUnitPosition?.positionCoordinateX}-${plot.observationUnitPosition?.positionCoordinateY}`;
                                        if (overlappingPlots[coordKey]) {
                                            return (
                                                <div>
                                                    <strong>Overlapping Plots:</strong>{' '}
                                                    {overlappingPlots[coordKey].map(p => {
                                                        const code = p.observationUnitPosition?.observationLevel?.levelCode || p.observationUnitName;
                                                        return displayLinkedTrials && p.studyName ? `${code} (${p.studyName})` : code;
                                                    }).join(', ')}
                                                </div>
                                            );
                                        }
                                        return (
                                            <>
                                                {displayLinkedTrials && plot.studyName && (
                                                    <div>
                                                        <strong>Trial Name:</strong>{' '}
                                                        {(() => {
                                                            const t = linkedTrialsList.find(lt => lt.name === plot.studyName);
                                                            if (t) {
                                                                return (
                                                                    <span style={{ backgroundColor: t.bg, color: t.fg, padding: '1px 2px', borderRadius: '4px' }}>
                                                                        {plot.studyName}
                                                                    </span>
                                                                );
                                                            }
                                                            return <span>{plot.studyName}</span>;
                                                        })()}
                                                    </div>
                                                )}
                                                <div><strong>Plot Name:</strong> {plot.observationUnitName}</div>
                                                {plot.type === 'data' && (
                                                    <>
                                                        <div><strong>Plot Number:</strong> {plot.observationUnitPosition?.observationLevel?.levelCode}</div>
                                                        {plot.observationUnitPosition?.observationLevelRelationships && plot.observationUnitPosition.observationLevelRelationships.length > 1 && (
                                                            <>
                                                                <div><strong>Block Number:</strong> {plot.observationUnitPosition.observationLevelRelationships[1].levelCode}</div>
                                                                <div><strong>Rep Number:</strong> {plot.observationUnitPosition.observationLevelRelationships[0].levelCode}</div>
                                                            </>
                                                        )}
                                                        {plot.germplasmName && <div><strong>Accession Name:</strong> {plot.germplasmName}</div>}
                                                        {plot.crossName && <div><strong>Cross Unique ID:</strong> {plot.crossName}</div>}
                                                        {plot.additionalInfo?.familyName && <div><strong>Family Name:</strong> {plot.additionalInfo.familyName}</div>}
                                                        {plot.additionalInfo?.intercropGermplasm?.map((g, i) => (
                                                            <div key={i}><strong>Accession Name:</strong> {g.germplasmName}</div>
                                                        ))}
                                                        {plot.observationUnitDbId && plotContentCache[plot.observationUnitDbId] && plotContentCache[plot.observationUnitDbId].length > 0 && (
                                                            <div><strong>Plants:</strong> {plotContentCache[plot.observationUnitDbId].join(', ')}</div>
                                                        )}
                                                        {selectedView !== 'fieldmap' && selectedView !== 'geofieldmap' && (
                                                            <div className="tw:text-[#ffd700] tw:mt-1">
                                                                <strong>Trait Name:</strong> {selectedViewLabel.replace(/ \(corrected\)| \(adjustment\)/, '')}<br />
                                                                <strong>Trait Value:</strong> {(() => {
                                                                    const val = heatmapData[plot.observationUnitDbId || '']?.val;
                                                                    if (val === undefined) return <em>NA</em>;
                                                                    const num = parseFloat(String(val));
                                                                    return isNaN(num) ? val : Math.round((num + Number.EPSILON) * 100) / 100;
                                                                })()}
                                                            </div>
                                                        )}
                                                    </>
                                                )}
                                            </>
                                        );
                                    })()}
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}

            {/* Legend Container */}
            <div id="legend_list" className="panel panel-default">
                <div className="panel-body">
                    <div className="tw:flex tw:gap-3.75 tw:flex-wrap tw:items-center">
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <span className="tw:inline-block tw:w-3.75 tw:h-3.75 tw:bg-[#d3d3d3] tw:border tw:border-[#ddd]"></span> Border Plots and Filler Plots
                        </span>
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <span className="tw:inline-block tw:w-3.75 tw:h-3.75 tw:bg-[#c7e9b4] tw:border tw:border-[#ddd]"></span> Even Block Numbers (e.g. 2,4,...)
                        </span>
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <span className="tw:inline-block tw:w-3.75 tw:h-3.75 tw:bg-[#41b6c4] tw:border tw:border-[#ddd]"></span> Odd Block Numbers (e.g. 1,3,...)
                        </span>
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <span className="tw:inline-block tw:w-3.75 tw:h-3.75 tw:bg-[#6a5acd] tw:border tw:border-[#ddd]"></span> Checks
                        </span>
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <span className="tw:inline-block tw:w-3.75 tw:h-1 tw:bg-[#008000] tw:self-center"></span> Odd Rep Numbers (e.g. 1,3,...)
                        </span>
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <span className="tw:inline-block tw:w-3.75 tw:h-1 tw:bg-[#ff0000] tw:self-center"></span> Even Rep Numbers (e.g. 2,4,...)
                        </span>
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <span className="tw:inline-block tw:w-3.75 tw:h-3.75 tw:bg-[#000000] tw:border-2 tw:border-[#ff0000]"></span> Overlapping Plots
                        </span>
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <img src="/static/css/images/plot_images.png" alt="Camera" width="20" height="20" className="tw:align-middle" /> Plot Has Image
                        </span>
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <span className="tw:inline-block tw:w-3.75 tw:h-3.75 tw:bg-[#a9afaf] tw:border tw:border-[#ddd]"></span> No measurement
                        </span>
                        <div className="tw:flex tw:items-center tw:gap-2.5">
                            <span>Low trait value</span>
                            <div className="tw:w-30 tw:h-3.75" style={{ background: `linear-gradient(to right, ${valueColorScale.colors?.join(', ') || 'white, darkred'})` }} />
                            <span>High trait value</span>
                        </div>
                        <span className="tw:inline-flex tw:items-center tw:gap-1.25 tw:whitespace-nowrap">
                            <span className="tw:inline-block tw:w-3.75 tw:h-3.75 tw:bg-[#ffffff] tw:border tw:border-[#eee]"></span> Empty Coordinate
                        </span>
                    </div>
                </div>
            </div>

            {/* Download CSV Layout Customizer */}
            {showDownloadCSVModal && (
                <div className="modal show tw:block tw:bg-black/50">
                    <div className="modal-dialog">
                        <div className="modal-content">
                            <div className="modal-header">
                                <button type="button" className="close" onClick={() => setShowDownloadCSVModal(false)}>&times;</button>
                                <h4 className="modal-title">Download Spatial Layout Customizer</h4>
                            </div>
                            <div className="modal-body">
                                <div className="checkbox">
                                    <label><input type="checkbox" checked={csvDownloadOpts.accession} onChange={e => setCsvDownloadOpts({ ...csvDownloadOpts, accession: e.target.checked })} /> Accession Name</label>
                                </div>
                                <div className="checkbox">
                                    <label><input type="checkbox" checked={csvDownloadOpts.obsUnit} onChange={e => setCsvDownloadOpts({ ...csvDownloadOpts, obsUnit: e.target.checked })} /> Plot Name</label>
                                </div>
                                <div className="checkbox">
                                    <label><input type="checkbox" checked={csvDownloadOpts.seedlot} onChange={e => setCsvDownloadOpts({ ...csvDownloadOpts, seedlot: e.target.checked })} /> Seedlot Name</label>
                                </div>
                                <div className="checkbox">
                                    <label><input type="checkbox" checked={csvDownloadOpts.plotId} onChange={e => setCsvDownloadOpts({ ...csvDownloadOpts, plotId: e.target.checked })} /> Plot ID</label>
                                </div>
                                <div className="checkbox">
                                    <label><input type="checkbox" checked={csvDownloadOpts.plotNum} onChange={e => setCsvDownloadOpts({ ...csvDownloadOpts, plotNum: e.target.checked })} /> Plot Number</label>
                                </div>
                                <div className="checkbox">
                                    <label><input type="checkbox" checked={csvDownloadOpts.familyName} onChange={e => setCsvDownloadOpts({ ...csvDownloadOpts, familyName: e.target.checked })} /> Family</label>
                                </div>
                                <div className="checkbox">
                                    <label><input type="checkbox" checked={csvDownloadOpts.crossName} onChange={e => setCsvDownloadOpts({ ...csvDownloadOpts, crossName: e.target.checked })} /> Cross</label>
                                </div>
                            </div>
                            <div className="modal-footer">
                                <button className="btn btn-default" onClick={() => setShowDownloadCSVModal(false)}>Close</button>
                                <button className="btn btn-primary" onClick={handleDownloadCSV}>Download CSV</button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Suppress Phenotype outlier dialog */}
            {showSuppressModal && selectedPlot && (
                <div className="modal show tw:block tw:bg-black/50">
                    <div className="modal-dialog">
                        <div className="modal-content">
                            <div className="modal-header">
                                <button type="button" className="close" onClick={() => setShowSuppressModal(false)}>&times;</button>
                                <h4 className="modal-title">Suppress Plot Phenotype Measurement</h4>
                            </div>
                            <div className="modal-body">
                                <p>Suppressed measurements will be seen as outliers and can be excluded during phenotype analysis.</p>
                                <div><strong>Plot Name:</strong> {selectedPlot.observationUnitName}</div>
                                <div><strong>Phenotype Value:</strong> {heatmapData[selectedPlot.observationUnitDbId || '']?.val}</div>
                            </div>
                            <div className="modal-footer">
                                <button className="btn btn-default" onClick={() => setShowSuppressModal(false)}>Close</button>
                                <button className="btn btn-danger" onClick={handleSuppressPhenotype}>Suppress Phenotype</button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Delete Trait confirmation dialog */}
            {showDeleteTraitModal && (
                <div className="modal show tw:block tw:bg-black/50">
                    <div className="modal-dialog">
                        <div className="modal-content">
                            <div className="modal-header text-center">
                                <button type="button" className="close" onClick={() => setShowDeleteTraitModal(false)}>&times;</button>
                                <h4 className="modal-title">Assayed Trait Deletion</h4>
                            </div>
                            <div className="modal-body">
                                <p className="font-bold">Are you sure you want to delete this assayed trait?</p>
                                <p>All phenotyping data values linked with this trait in this trial will be removed permanently.</p>
                            </div>
                            <div className="modal-footer">
                                <button className="btn btn-default" onClick={() => setShowDeleteTraitModal(false)}>Close</button>
                                <button className="btn btn-danger" onClick={handleDeleteSingleTrait}>Delete Trait</button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Dimensions Dialog */}
            {showDimDialog && (
                <div className="modal show tw:block tw:bg-black/50">
                    <div className="modal-dialog">
                        <div className="modal-content">
                            <div className="modal-header">
                                <button type="button" className="close" onClick={() => setShowDimDialog(false)}>&times;</button>
                                <h4 className="modal-title">Change Layout Dimensions</h4>
                            </div>
                            <div className="modal-body">
                                <div className="form-group">
                                    <label>Rows:</label>
                                    <input type="number" className="form-control" value={dimRowsInput} onChange={e => setDimRowsInput(e.target.value)} />
                                </div>
                                <div className="form-group">
                                    <label>Columns:</label>
                                    <input type="number" className="form-control" value={dimColsInput} onChange={e => setDimColsInput(e.target.value)} />
                                </div>
                                <div className="form-group">
                                    <label>Filler Accession (Optional):</label>
                                    <AccessionAutocomplete value={fillerAccessionInput} onChange={setFillerAccessionInput} className="form-control" />
                                </div>
                            </div>
                            <div className="modal-footer">
                                <button className="btn btn-default" onClick={() => setShowDimDialog(false)}>Cancel</button>
                                <button className="btn btn-primary" onClick={handleApplyDimensions}>Apply</button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Plot Details Modal */}
            {showPlotDetails && selectedPlot && (
                <div className="modal show tw:block tw:bg-black/50">
                    <div className="modal-dialog modal-lg">
                        <div className="modal-content">
                            <div className="modal-header">
                                <button type="button" className="close" onClick={() => setShowPlotDetails(false)}>&times;</button>
                                <h4 className="modal-title">Plot Details: {selectedPlot.observationUnitName}</h4>
                            </div>
                            <div className="modal-body">
                                <ul className="nav nav-tabs tw:mb-3.75">
                                    <li className={!showEditAccession ? 'active' : ''}><a className="tw:cursor-pointer" onClick={() => setShowEditAccession(false)}>Summary</a></li>
                                    <li className={showEditAccession ? 'active' : ''}><a className="tw:cursor-pointer" onClick={() => setShowEditAccession(true)}>Replace {stockLabel}</a></li>
                                </ul>

                                {!showEditAccession ? (
                                    <div className="tw:p-2.5">
                                        <table className="table table-bordered">
                                            <tbody>
                                                <tr>
                                                    <td className="tw:w-[30%] tw:font-bold">Plot Database ID:</td>
                                                    <td>{selectedPlot.observationUnitDbId}</td>
                                                </tr>
                                                <tr>
                                                    <td className="tw:font-bold">{stockLabel} Name:</td>
                                                    <td>{selectedPlot.germplasmName}</td>
                                                </tr>
                                                <tr>
                                                    <td className="tw:font-bold">Plot Number:</td>
                                                    <td>{selectedPlot.observationUnitPosition?.observationLevel?.levelCode}</td>
                                                </tr>
                                                {selectedPlot.observationUnitPosition?.positionCoordinateX && (
                                                    <tr>
                                                        <td className="tw:font-bold">Coordinates (X / Y):</td>
                                                        <td>{selectedPlot.observationUnitPosition.positionCoordinateX} / {selectedPlot.observationUnitPosition.positionCoordinateY}</td>
                                                    </tr>
                                                )}
                                            </tbody>
                                        </table>

                                        {/* Expandable Plot Structure Section */}
                                        {plotStructure && (
                                            <div className="tw:mt-5">
                                                <h5 className="tw:font-bold tw:mb-2">Plot Contents & Structure Hierarchy:</h5>
                                                {plotStructureLayoutType === 'subplot_grid' ? (
                                                    <div className="tw:p-2.5 tw:border tw:rounded tw:bg-[#fafafa]">
                                                        <RenderSubplotGrid node={plotStructure} />
                                                    </div>
                                                ) : plotStructureLayoutType === 'plant_grid' ? (
                                                    <div className="tw:p-2.5 tw:border tw:rounded tw:bg-[#fafafa]">
                                                        <RenderPlantGrid node={plotStructure} />
                                                    </div>
                                                ) : (
                                                    <div className="tw:max-h-62.5 tw:overflow-y-auto tw:bg-[#f5f5f5] tw:p-2.5 tw:rounded tw:text-xs">
                                                        <pre className="tw:border-0 tw:bg-transparent tw:p-0 tw:m-0">{JSON.stringify(plotStructure, null, 2)}</pre>
                                                    </div>
                                                )}
                                            </div>
                                        )}

                                        {plotImages && (
                                            <div className="tw:mt-5">
                                                <h5><strong>Plot Images:</strong></h5>
                                                <div dangerouslySetInnerHTML={{ __html: plotImages }} />
                                            </div>
                                        )}
                                    </div>
                                ) : (
                                    <div className="tw:p-2.5">
                                        <div className="form-group">
                                            <label>New {stockLabel} Name:</label>
                                            <AccessionAutocomplete value={newAccession} onChange={setNewAccession} className="form-control" />
                                        </div>
                                        <div className="form-group">
                                            <label>New Plot Name (Optional):</label>
                                            <input type="text" className="form-control" value={newPlotName} onChange={e => setNewPlotName(e.target.value)} />
                                        </div>
                                        <div className="alert alert-warning">
                                            Replacing this {stockLabel.toLowerCase()} will update layout structures and replicates. Ensure changes are correct.
                                        </div>
                                        <button className="btn btn-primary tw:mr-2" onClick={() => submitReplaceAccession('check')}>Update {stockLabel}</button>
                                        {selectedView !== 'fieldmap' && selectedView !== 'geofieldmap' && heatmapData[selectedPlot.observationUnitDbId || ''] && (
                                            <button className="btn btn-warning" onClick={() => setShowSuppressModal(true)}>Suppress Current Trait Value</button>
                                        )}
                                    </div>
                                )}
                            </div>
                            <div className="modal-footer">
                                <button className="btn btn-default" onClick={() => setShowPlotDetails(false)}>Close</button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Curator overrides warn popup */}
            {showCuratorWarning && (
                <div className="modal show tw:block tw:bg-black/50">
                    <div className="modal-dialog">
                        <div className="modal-content">
                            <div className="modal-header">
                                <button type="button" className="close" onClick={() => setShowCuratorWarning(false)}>&times;</button>
                                <h4 className="modal-title">Curator Override Warning</h4>
                            </div>
                            <div className="modal-body">
                                <p>One or more traits have already been assayed for this trial. Are you sure you want to replace this accession?</p>
                            </div>
                            <div className="modal-footer">
                                <button className="btn btn-default" onClick={() => setShowCuratorWarning(false)}>No</button>
                                <button className="btn btn-primary" onClick={() => submitReplaceAccession('override')}>Yes, Override</button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Download Options Panel */}
            {hasColAndRowNumbers && (
                <div className="panel panel-default tw:mt-5">
                    <div className="panel-heading">
                        <h3 className="panel-title tw:font-bold">Download Plot Order</h3>
                    </div>
                    <div className="panel-body">
                        <div className="tw:flex tw:gap-5 tw:flex-wrap">
                            <div className="form-group tw:min-w-45">
                                <label>File Format:</label>
                                <select
                                    className="form-control"
                                    value={downloadOpts.type}
                                    onChange={e => setDownloadOpts({ ...downloadOpts, type: e.target.value })}
                                >
                                    <option value="">--Select Type--</option>
                                    <option value="planting">Planting Order</option>
                                    <option value="collection">Collection Order</option>
                                    <option value="harvest">Harvest Order</option>
                                    <option value="harvestmaster">HarvestMaster</option>
                                </select>
                            </div>

                            <div className="form-group tw:min-w-45">
                                <label>Traversal Order:</label>
                                <select
                                    className="form-control"
                                    value={downloadOpts.order}
                                    onChange={e => setDownloadOpts({ ...downloadOpts, order: e.target.value })}
                                >
                                    <option value="by_col_serpentine">By Column: Serpentine</option>
                                    <option value="by_col_zigzag">By Column: Zigzag</option>
                                    <option value="by_row_serpentine">By Row: Serpentine</option>
                                    <option value="by_row_zigzag">By Row: Zigzag</option>
                                </select>
                            </div>

                            <div className="form-group tw:min-w-45">
                                <label>Starting Corner:</label>
                                <select
                                    className="form-control"
                                    value={downloadOpts.start}
                                    onChange={e => setDownloadOpts({ ...downloadOpts, start: e.target.value })}
                                >
                                    <option value="bottom_left">Bottom Left</option>
                                    <option value="top_left">Top Left</option>
                                    <option value="top_right">Top Right</option>
                                    <option value="bottom_right">Bottom Right</option>
                                </select>
                            </div>
                        </div>

                        {downloadOpts.type === 'harvestmaster' && (
                            <div className="well well-sm tw:mt-2.5">
                                <strong>HarvestMaster Mapping Config:</strong>
                                <div className="tw:flex tw:gap-3.75 tw:flex-wrap tw:mt-2.5">
                                    <div className="form-group">
                                        <label>PLTID:</label>
                                        <select className="form-control" value={downloadOpts.hmPltid} onChange={e => setDownloadOpts({ ...downloadOpts, hmPltid: e.target.value })}>
                                            <option value="plot_id">Plot Database ID</option>
                                            <option value="plot_name">Plot Name</option>
                                            <option value="plot_number">Plot Number</option>
                                        </select>
                                    </div>
                                    <div className="form-group">
                                        <label>Range Mapping:</label>
                                        <select className="form-control" value={downloadOpts.hmRange} onChange={e => setDownloadOpts({ ...downloadOpts, hmRange: e.target.value })}>
                                            <option value="col_number">Breedbase Column</option>
                                            <option value="row_number">Breedbase Row</option>
                                        </select>
                                    </div>
                                    <div className="form-group">
                                        <label>Row Mapping:</label>
                                        <select className="form-control" value={downloadOpts.hmRow} onChange={e => setDownloadOpts({ ...downloadOpts, hmRow: e.target.value })}>
                                            <option value="col_number">Breedbase Column</option>
                                            <option value="row_number">Breedbase Row</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                        )}

                        <div className="tw:flex tw:gap-3.75 tw:my-3.75">
                            <label><input type="checkbox" checked={downloadOpts.borders} onChange={e => setDownloadOpts({ ...downloadOpts, borders: e.target.checked })} /> Include Borders</label>
                            <label><input type="checkbox" checked={downloadOpts.gaps} onChange={e => setDownloadOpts({ ...downloadOpts, gaps: e.target.checked })} /> Include Gaps</label>
                            {hasSubplotEntries && <label><input type="checkbox" checked={downloadOpts.subplots} onChange={e => setDownloadOpts({ ...downloadOpts, subplots: e.target.checked })} /> Include Subplots</label>}
                            {hasPlantEntries && <label><input type="checkbox" checked={downloadOpts.plants} onChange={e => setDownloadOpts({ ...downloadOpts, plants: e.target.checked })} /> Include Plants</label>}
                        </div>

                        <button className="btn btn-primary" onClick={handleDownloadOrder}>Generate & Download File</button>
                    </div>
                </div>
            )}
        </div>
    );
};

export const init = (containerId: string, options: any) => {
    const container = document.getElementById(containerId);
    if (container) {
        const root = createRoot(container);
        root.render(<FieldMapContainer {...options} />);
    }
};