/*
 * Weather for breeders: the calculations behind the Weather page
 * (/breeders/weather). No DOM here: daily observations in, indicators out.
 *
 *   seasonDays()   every calendar day of a period, with degree-days and
 *                  accumulated rain / ET0
 *   summarize()    the season indicators (rain, ET0, water balance,
 *                  degree-days, heat / frost days, dry spells, coverage)
 *   cropStages()   crop stages from planting, as proportions of the
 *                  season's degree-days (or days when there is no
 *                  temperature), with the stress of each stage
 *   stressDays()   the day-by-day stress calendar
 *   verdicts()     plain-language findings for the breeder
 *   covariates()   one row of environmental covariates (trials, years,
 *                  locations), for G x E analyses
 *
 * Author: Chris Simoes
 */

// Stages as proportions of the season (planting -> end), the critical one flagged.
// Defaults from crop physiology; real dates should come from phenotyped flowering.
export const CROPS = [
    { v: '', label: 'Generic crop', base: 10, cap: 30, stages: [['Early', 0.33], ['Middle', 0.66, 1], ['Late', 1]] },
    { v: 'maize', label: 'Maize', base: 10, cap: 30, stages: [['Emergence', 0.06], ['Vegetative', 0.45], ['Flowering', 0.58, 1], ['Grain filling', 0.92], ['Maturity', 1]] },
    { v: 'sorghum', label: 'Sorghum', base: 10, cap: 35, stages: [['Emergence', 0.06], ['Vegetative', 0.45], ['Flowering', 0.6, 1], ['Grain filling', 0.92], ['Maturity', 1]] },
    { v: 'rice', label: 'Rice', base: 10, cap: 35, stages: [['Establishment', 0.1], ['Tillering', 0.4], ['Panicle and flowering', 0.62, 1], ['Grain filling', 0.92], ['Maturity', 1]] },
    { v: 'wheat', label: 'Wheat', base: 0, cap: 30, stages: [['Emergence', 0.08], ['Tillering and stem', 0.48], ['Heading and flowering', 0.62, 1], ['Grain filling', 0.92], ['Maturity', 1]] },
    { v: 'soybean', label: 'Soybean', base: 10, cap: 30, stages: [['Emergence', 0.07], ['Vegetative', 0.35], ['Flowering and pod set', 0.6, 1], ['Seed filling', 0.92], ['Maturity', 1]] },
    { v: 'bean', label: 'Common bean', base: 10, cap: 30, stages: [['Emergence', 0.1], ['Vegetative', 0.38], ['Flowering', 0.58, 1], ['Pod filling', 0.9], ['Maturity', 1]] },
    { v: 'cotton', label: 'Cotton', base: 15.6, cap: 32, stages: [['Emergence', 0.06], ['Vegetative', 0.33], ['Flowering and boll set', 0.7, 1], ['Boll opening', 1]] },
    { v: 'potato', label: 'Potato', base: 7, cap: 30, stages: [['Emergence', 0.15], ['Vegetative', 0.3], ['Tuber initiation', 0.45, 1], ['Tuber bulking', 0.9], ['Maturity', 1]] },
    { v: 'cassava', label: 'Cassava', base: 12, cap: 35, stages: [['Establishment', 0.1], ['Canopy development', 0.35, 1], ['Root bulking', 0.85], ['Maturation', 1]] },
    { v: 'sweetpotato', label: 'Sweet potato', base: 10, cap: 35, stages: [['Establishment', 0.12], ['Vine development', 0.35, 1], ['Root bulking', 0.9], ['Maturity', 1]] },
    { v: 'sugarcane', label: 'Sugarcane', base: 18, cap: 35, stages: [['Germination', 0.1], ['Tillering', 0.3, 1], ['Grand growth', 0.8], ['Ripening', 1]] },
    { v: 'tomato', label: 'Tomato', base: 10, cap: 30, stages: [['Establishment', 0.12], ['Vegetative', 0.3], ['Flowering and fruit set', 0.55, 1], ['Fruit development', 0.9], ['Harvest', 1]] },
    { v: 'banana', label: 'Banana / plantain', base: 14, cap: 35, stages: [['Establishment', 0.15], ['Vegetative', 0.6], ['Flowering', 0.75, 1], ['Bunch filling', 1]] },
    { v: 'coffee', label: 'Coffee', base: 10, cap: 34, stages: [['Early', 0.33], ['Flowering and fruit set', 0.66, 1], ['Fruit filling', 1]] },
];

// ---------------------------------------------------------------- temperature display unit
// Every calculation and every stored value stays in degrees C; only what is shown
// (tables, charts, texts, CSV) follows the unit chosen on the page.
export const UNITS = { temp: 'C' };
export const isF = () => UNITS.temp === 'F';
export const tUnit = () => (isF() ? '°F' : '°C');
export const ddUnit = () => (isF() ? '°F·d' : '°C·d');
// a temperature, and a temperature difference / degree-days (no 32 offset)
export function toT(c) { const x = num(c); return x === null ? null : isF() ? x * 1.8 + 32 : x; }
export function toDD(c) { const x = num(c); return x === null ? null : isF() ? x * 1.8 : x; }
export function fromT(v) { const x = num(v); return x === null ? null : isF() ? Math.round(((x - 32) / 1.8) * 100) / 100 : x; }
// '35.2 °C' / '95.4 °F'; a threshold drops a trailing .0 ('0 °C', '32 °F', '28.4 °F')
export function fmtT(c, d) { const x = toT(c); return x === null ? '?' : x.toFixed(d === undefined ? 1 : d) + ' ' + tUnit(); }
export function fmtTh(c) { const x = toT(c); return x === null ? '?' : String(Math.round(x * 10) / 10) + ' ' + tUnit(); }
export const TEMP_KEYS = ['tmax', 'tmin', 'tmean', 'tmax_mean', 'tmin_mean', 'tmax_abs', 'tmin_abs', 'critical_tmax_mean', 'rm_kill_temp'];
// a value of a covariate / daily column in the display unit
export function inUnit(key, v) {
    if (TEMP_KEYS.includes(key)) return toT(v);
    if (key === 'gdd') return toDD(v);
    return v;
}

export const DEFAULTS = { base: 10, cap: 30, heat: 35, frost: 0, dry: 10, heavy: 50, kill: -2, rm100: 2450, rmDay: 25, silk: 50, rmRef: 110 };

// ---------------------------------------------------------------- maize relative maturity (RM / CRM)
// GDD in degrees F (base 50 F, cap 86 F) = 1.8 x GDD in degrees C (base 10 C, cap 30 C).
// From planting to black layer a hybrid of RM r needs about rm100 + rmDay x (r - 100) GDD F
// (typical seed-company ratings: ~2450 GDD F for a 100-day hybrid, ~25 GDD F per RM day);
// silking at about silk % of it. Both are settings: companies rate differently.
export const RM_STEPS = [75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130];
export function rmToGddF(rm, p) { return p.rm100 + p.rmDay * (rm - 100); }
export function gddFToRm(gddF, p) { return 100 + (gddF - p.rm100) / p.rmDay; }

// degree-days available to a maize crop: from planting to the first killing frost
// (min <= kill, after the first 3 weeks) or to the end of the period
export function rmSeason(days, p) {
    let gddC = 0, end = null, reason = 'end of the period', killTemp = null;
    for (let i = 0; i < days.length; i++) {
        const d = days[i];
        if (i > 21 && num(d.tmin) !== null && d.tmin <= p.kill) { end = d.date; reason = 'killing frost'; killTemp = d.tmin; break; }
        if (d.gdd !== null && d.gdd !== undefined) gddC += d.gdd;
        end = d.date;
    }
    const tempDays = days.filter(d => d.gdd !== null && d.gdd !== undefined).length;
    const ok = days.length && tempDays >= days.length * 0.8;
    const gddF = gddC * 1.8;
    const rm = ok ? Math.floor(gddFToRm(gddF, p)) : null;
    // without a killing frost the season length is the user's choice: the maximum RM then means nothing,
    // the speed does: days for the reference RM to reach black layer, and GDD per day
    const frost = /frost/.test(reason);
    const ref = ok ? rmDates(days, p.rmRef, p) : null;
    return { gddC, gddF, rm: frost && rm !== null && rm >= 60 ? rm : null, rmIfEnd: rm !== null && rm >= 60 ? rm : null, gddFPerDay: ok && days.length ? gddF / Math.max(1, days.indexOf(days.find(d => d.date === end)) + 1) : null,
        refDays: ref && ref.black ? daysBetween(days[0].date, ref.black) : null, refSilkDays: ref && ref.silk ? daysBetween(days[0].date, ref.silk) : null, tooShort: ok && gddFToRm(gddF, p) < 60, end, reason, killTemp, ok, tempCoverage: days.length ? tempDays / days.length : 0, frost: /frost/.test(reason) };
}

// silking and black-layer dates of a hybrid of RM rm planted on the first day
export function rmDates(days, rm, p) {
    const need = rmToGddF(rm, p) / 1.8, silkNeed = need * p.silk / 100;
    let cum = 0, silk = null, black = null, frostBefore = null;
    for (let i = 0; i < days.length; i++) {
        const d = days[i];
        if (!black && i > 21 && num(d.tmin) !== null && d.tmin <= p.kill && !frostBefore) frostBefore = d.date;
        if (d.gdd !== null && d.gdd !== undefined) cum += d.gdd;
        if (!silk && cum >= silkNeed) silk = d.date;
        if (!black && cum >= need) { black = d.date; break; }
    }
    return { rm, needC: need, needF: need * 1.8, silk, black, frostBefore: black && frostBefore && frostBefore < black ? frostBefore : (!black ? frostBefore : null), reached: cum, short: black ? 0 : need - cum };
}

// RM zone over several seasons: the largest RM reaching black layer in at least share of them
export function rmReasonText(reason, killTemp) { return reason + (killTemp !== null && killTemp !== undefined ? ' (' + fmtT(killTemp) + ')' : ''); }

export function rmZone(rms, share) {
    const v = rms.filter(x => x !== null && x !== undefined).sort((a, b) => a - b);
    if (v.length < 3) return null;
    const k = Math.floor((1 - (share || 0.8)) * v.length + 1e-9);
    return { rm: v[Math.min(k, v.length - 1)], years: v.length, share: share || 0.8 };
}
export function daysBand(days, width) { if (days === null || days === undefined) return null; const w = width || 10; const lo = Math.floor(days / w) * w; return lo + '–' + (lo + w) + ' days'; }
export function rmBand(rm, width) { if (rm === null || rm === undefined) return null; const w = width || 5; const lo = Math.floor(rm / w) * w; return lo + '–' + (lo + w); }

export function num(v) { return v === null || v === undefined || v === '' || isNaN(Number(v)) ? null : Number(v); }
function iso(d) { return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }
export function addDays(isoDate, n) { const d = new Date(isoDate + 'T12:00:00'); d.setDate(d.getDate() + n); return iso(d); }
export function daysBetween(a, b) { return Math.round((new Date(b + 'T12:00:00') - new Date(a + 'T12:00:00')) / 86400000) + 1; }
const sum = a => a.reduce((x, y) => x + y, 0);
const mean = a => (a.length ? sum(a) / a.length : null);
export function median(a) {
    if (!a.length) return null;
    const b = a.slice().sort((x, y) => x - y);
    const m = Math.floor(b.length / 2);
    return b.length % 2 ? b[m] : (b[m - 1] + b[m]) / 2;
}

export function gddOf(tmax, tmin, base, cap) {
    if (tmax === null || tmin === null) return null;
    const hi = Math.min(Math.max(tmax, base), cap);
    const lo = Math.min(Math.max(tmin, base), cap);
    return Math.max(0, (hi + lo) / 2 - base);
}

// every calendar day from start to end (not after today), observed values or empty
export function seasonDays(daily, start, end, p, today) {
    const by = {};
    (daily.days || []).forEach(d => { by[d.date] = d; });
    const last = today && end > today ? today : end;
    const out = [];
    let gdd = 0, rain = 0, et0 = 0;
    for (let d = start; d <= last; d = addDays(d, 1)) {
        const o = by[d] || { date: d, missing: true };
        const g = gddOf(num(o.tmax), num(o.tmin), p.base, p.cap);
        if (g !== null) gdd += g;
        if (num(o.rain) !== null) rain += num(o.rain);
        if (num(o.et0) !== null) et0 += num(o.et0);
        out.push(Object.assign({}, o, {
            gdd: g, gddCum: gdd, rainCum: daily.rain_reported ? rain : null, et0Cum: et0,
            balanceCum: daily.rain_reported ? rain - et0 : null,
        }));
    }
    return out;
}

function longestDry(days, threshold) {
    let run = 0, best = 0, bestEnd = null;
    days.forEach(d => {
        const r = num(d.rain);
        if (r === null) { run = 0; return; }
        if (r < 1) { run++; if (run > best) { best = run; bestEnd = d.date; } }
        else run = 0;
    });
    return { days: best, end: bestEnd, start: bestEnd ? addDays(bestEnd, -(best - 1)) : null, over: best >= (threshold || Infinity) };
}

export function summarize(days, rainReported, p) {
    const vals = k => days.map(d => num(d[k])).filter(v => v !== null);
    const tx = vals('tmax'), tn = vals('tmin'), et0v = vals('et0'), rainv = vals('rain');
    const dry = rainReported ? longestDry(days, p.dry) : null;
    const withData = days.filter(d => !d.missing && d.complete).length;
    const gddDays = days.filter(d => d.gdd !== null && d.gdd !== undefined);
    // a water balance needs rain on (almost) every day: missing days are not dry days
    const rainCoverage = days.length ? rainv.length / days.length : 0;
    const balanceOk = rainReported && et0v.length && rainCoverage >= 0.8;
    return {
        days: days.length,
        withData,
        coverage: days.length ? withData / days.length : 0,
        rain: rainReported ? sum(rainv) : null,
        rainyDays: rainReported ? rainv.filter(v => v >= 1).length : null,
        maxRain: rainReported && rainv.length ? Math.max(...rainv) : null,
        heavy: rainReported ? rainv.filter(v => v >= p.heavy).length : null,
        dry,
        rainHours: sum(vals('rain_hours')),
        et0: et0v.length ? sum(et0v) : null,
        balance: balanceOk ? sum(rainv) - sum(et0v) : null,
        rainCoverage,
        tmax: mean(tx), tmin: mean(tn),
        absMax: tx.length ? Math.max(...tx) : null, absMin: tn.length ? Math.min(...tn) : null,
        heat: tx.length ? tx.filter(v => v >= p.heat).length : null,
        frost: tn.length ? tn.filter(v => v <= p.frost).length : null,
        gdd: gddDays.length ? sum(gddDays.map(d => d.gdd)) : null,
        rh: mean(vals('rh')),
        radiation: vals('radiation').length ? sum(vals('radiation')) : null,
        hasTemp: tx.length > 0,
    };
}

// crop stages from planting, as proportions of the season's degree-days (days without temperature)
export function cropStages(days, rainReported, p, cropKey) {
    const crop = CROPS.find(c => c.v === (cropKey || '')) || CROPS[0];
    if (!days.length) return [];
    const total = days[days.length - 1].gddCum;
    const byGdd = total > 0 && days.filter(d => d.gdd !== null).length >= days.length * 0.6;
    // each day goes to the first stage whose upper limit it has not passed
    const stageOf = days.map((d, i) => {
        const x = byGdd ? d.gddCum / total : (i + 1) / days.length;
        const k = crop.stages.findIndex(st => x <= st[1] + 1e-9);
        return k < 0 ? crop.stages.length - 1 : k;
    });
    return crop.stages.map(([name, , critical], k) => {
        const part = days.filter((d, i) => stageOf[i] === k);
        const s = summarize(part, rainReported, p);
        const st = { name, critical: !!critical, start: part.length ? part[0].date : null, end: part.length ? part[part.length - 1].date : null, days: part, s, byGdd };
        st.issues = stageIssues(s, p);
        return st;
    }).filter(st => st.days.length);
}

// stress found in a stage (or a season), most serious first
export function stageIssues(s, p) {
    const out = [];
    if (s.rain !== null && s.et0 && s.rainCoverage >= 0.8) {
        const ratio = s.rain / s.et0;
        if (ratio < 0.5) out.push({ level: 'bad', kind: 'water', text: 'water deficit', detail: 'rain ' + s.rain.toFixed(0) + ' mm vs ET0 ' + s.et0.toFixed(0) + ' mm' });
        else if (ratio < 0.8) out.push({ level: 'warn', kind: 'water', text: 'some water deficit', detail: 'rain ' + s.rain.toFixed(0) + ' mm vs ET0 ' + s.et0.toFixed(0) + ' mm' });
    }
    if (s.dry && s.dry.days >= p.dry) out.push({ level: s.dry.days >= p.dry * 2 ? 'bad' : 'warn', kind: 'dry', text: 'dry spell of ' + s.dry.days + ' days', detail: s.dry.start + ' to ' + s.dry.end });
    // getters: the temperatures are written in the unit shown at the time they are read
    if (s.heat) out.push({ level: s.heat >= 3 ? 'bad' : 'warn', kind: 'heat', text: s.heat + ' heat-stress day' + (s.heat > 1 ? 's' : ''), get detail() { return 'max ≥ ' + fmtTh(p.heat) + ' (highest ' + fmtT(s.absMax) + ')'; } });
    if (s.frost) out.push({ level: 'bad', kind: 'frost', text: s.frost + ' frost day' + (s.frost > 1 ? 's' : ''), get detail() { return 'min ≤ ' + fmtTh(p.frost) + ' (lowest ' + fmtT(s.absMin) + ')'; } });
    if (s.heavy) out.push({ level: 'warn', kind: 'wet', text: s.heavy + ' day' + (s.heavy > 1 ? 's' : '') + ' of heavy rain', detail: '≥ ' + p.heavy + ' mm (max ' + (s.maxRain !== null ? s.maxRain.toFixed(0) : '?') + ' mm): waterlogging, lodging, disease' });
    if (s.rain !== null && s.et0 && s.rainCoverage >= 0.8 && s.rain / s.et0 > 2 && s.rain > 100) out.push({ level: 'warn', kind: 'wet', text: 'very wet', detail: 'rain ' + s.rain.toFixed(0) + ' mm, twice the ET0' });
    const order = { bad: 0, warn: 1 };
    return out.sort((a, b) => order[a.level] - order[b.level]);
}

// day-by-day stress: one flag set per day
export function stressDays(days, rainReported, p) {
    const inDry = {};
    if (rainReported) {
        let run = [];
        const flush = () => { if (run.length >= p.dry) run.forEach(d => { inDry[d] = 1; }); run = []; };
        days.forEach(d => {
            const r = num(d.rain);
            if (r !== null && r < 1) run.push(d.date); else flush();
        });
        flush();
    }
    return days.map(d => ({
        date: d.date,
        heat: num(d.tmax) !== null && d.tmax >= p.heat,
        frost: num(d.tmin) !== null && d.tmin <= p.frost,
        dry: !!inDry[d.date],
        heavy: rainReported && num(d.rain) !== null && d.rain >= p.heavy,
        missing: !!d.missing || !d.complete,
    }));
}

// the main findings, the critical stage first
export function verdicts(stages, season, p) {
    const out = [];
    stages.filter(s => s.critical).concat(stages.filter(s => !s.critical)).forEach(st => {
        // copy the property descriptors (Object.assign would freeze the detail getters)
        st.issues.forEach(i => out.push(Object.defineProperties({ stage: st.name, critical: st.critical }, Object.getOwnPropertyDescriptors(i))));
    });
    if (season.coverage < 0.8) out.push({ level: 'info', stage: 'Data', text: Math.round(100 * season.coverage) + '% of the days observed', detail: 'totals are lower than the real ones; see Data sources' });
    return out;
}

// one row of environmental covariates (for trials, past years, locations)
export function covariates(days, rainReported, p, cropKey) {
    const s = summarize(days, rainReported, p);
    const stages = cropStages(days, rainReported, p, cropKey);
    const crit = stages.find(st => st.critical);
    return {
        days: s.days, coverage: s.coverage,
        rain: s.rain, rainy_days: s.rainyDays, longest_dry_spell: s.dry ? s.dry.days : null,
        et0: s.et0, water_balance: s.balance, gdd: s.gdd,
        tmax_mean: s.tmax, tmin_mean: s.tmin, tmax_abs: s.absMax, tmin_abs: s.absMin,
        heat_days: s.heat, frost_days: s.frost, heavy_rain_days: s.heavy,
        critical_stage: crit ? crit.name : null,
        critical_start: crit ? crit.start : null, critical_end: crit ? crit.end : null,
        critical_rain: crit ? crit.s.rain : null, critical_et0: crit ? crit.s.et0 : null,
        critical_balance: crit ? crit.s.balance : null, critical_heat_days: crit ? crit.s.heat : null,
        critical_tmax_mean: crit ? crit.s.tmax : null,
        gdd_f: s.gdd !== null ? s.gdd * 1.8 : null,
        ...(cropKey === 'maize' ? (r => ({
            max_rm: r.rm, rm_season_end: r.end, rm_end_reason: r.reason, rm_kill_temp: r.killTemp, rm_temp_ok: r.ok,
            rm_ref_days: r.refDays, rm_ref_silk_days: r.refSilkDays, gdd_f_per_day: r.gddFPerDay,
        }))(rmSeason(days, p)) : {}),
        issues: verdicts(stages, s, p).filter(v => v.level !== 'info'),
    };
}

// covariate columns, labelled in the temperature unit shown
export function covariateColumns() {
    const t = tUnit();
    return [
        ['days', 'Days'], ['coverage', 'Days observed (%)'], ['rain', 'Rain (mm)'], ['rainy_days', 'Rainy days'],
        ['longest_dry_spell', 'Longest dry spell (days)'], ['et0', 'ET0 (mm)'], ['water_balance', 'Water balance (mm)'],
        ['gdd', 'Degree-days (' + ddUnit() + ')'], ['tmax_mean', 'Mean max (' + t + ')'], ['tmin_mean', 'Mean min (' + t + ')'], ['tmax_abs', 'Highest (' + t + ')'],
        ['tmin_abs', 'Lowest (' + t + ')'], ['heat_days', 'Heat days'], ['frost_days', 'Frost days'], ['heavy_rain_days', 'Heavy-rain days'],
        ['critical_stage', 'Critical stage'], ['critical_start', 'Critical from'], ['critical_end', 'Critical to'],
        ['critical_rain', 'Critical rain (mm)'], ['critical_et0', 'Critical ET0 (mm)'], ['critical_balance', 'Critical balance (mm)'],
        ['critical_heat_days', 'Critical heat days'], ['critical_tmax_mean', 'Critical mean max (' + t + ')'],
        ['gdd_f', 'GDD (°F, 50/86)'], ['max_rm', 'Max maize RM (black layer, frost-limited)'], ['rm_season_end', 'RM season end'], ['rm_end_reason', 'RM season end reason'],
        ['rm_kill_temp', 'Killing frost minimum (' + t + ')'],
        ['rm_ref_silk_days', 'Days to silking of the reference RM'], ['rm_ref_days', 'Days to black layer of the reference RM'], ['gdd_f_per_day', 'GDD °F per day'],
    ];
}
