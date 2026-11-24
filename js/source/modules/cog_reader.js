/**
 * Minimal reader for Cloud-Optimized GeoTIFFs (the Sentinel-2 COGs of Earth Search):
 * reads only the tiles that hold a small window, with HTTP Range requests.
 * Supports little-endian classic TIFF, tiled, DEFLATE (or no) compression,
 * horizontal predictor (2), 8/16-bit unsigned samples, pixel-interleaved,
 * first image only (full resolution). Inflate uses the browser's DecompressionStream.
 * Also: WGS84 -> UTM (latLonToUtm) for the EPSG:326zz / 327zz grids of Sentinel-2.
 */

const TYPE_SIZE = { 1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8 };
const HEADER_BYTES = 16384;
const headers = new Map();      // url -> Promise<cog>
const tiles = new Map();        // url#index -> Promise<TypedArray>
const MAX_TILES = 160;

async function fetchRange(url, start, end, signal) {
    const res = await fetch(url, { headers: { Range: `bytes=${start}-${end}` }, signal });
    if (!res.ok) throw new Error(`HTTP ${res.status} reading ${url}`);
    const buf = await res.arrayBuffer();
    // a server that ignores Range sends the whole file: keep only the asked part
    if (res.status === 200 && buf.byteLength > end - start + 1) return buf.slice(start, end + 1);
    return buf;
}

function readValues(dv, type, count, offset) {
    const out = [];
    for (let i = 0; i < count; i++) {
        const o = offset + i * TYPE_SIZE[type];
        switch (type) {
            case 1: case 2: case 6: case 7: out.push(dv.getUint8(o)); break;
            case 3: out.push(dv.getUint16(o, true)); break;
            case 8: out.push(dv.getInt16(o, true)); break;
            case 4: out.push(dv.getUint32(o, true)); break;
            case 9: out.push(dv.getInt32(o, true)); break;
            case 11: out.push(dv.getFloat32(o, true)); break;
            case 12: out.push(dv.getFloat64(o, true)); break;
            default: out.push(null);
        }
    }
    return out;
}

/** Parse the first IFD of a little-endian classic TIFF held in an ArrayBuffer. */
export function parseHeader(buf) {
    const dv = new DataView(buf);
    if (dv.getUint16(0, false) !== 0x4949) throw new Error('Only little-endian TIFF is supported');
    const magic = dv.getUint16(2, true);
    if (magic !== 42) throw new Error(magic === 43 ? 'BigTIFF is not supported' : 'Not a TIFF file');
    const ifd = dv.getUint32(4, true);
    const n = dv.getUint16(ifd, true);
    const tags = {};
    const missing = [];
    for (let i = 0; i < n; i++) {
        const e = ifd + 2 + i * 12;
        const tag = dv.getUint16(e, true), type = dv.getUint16(e + 2, true), count = dv.getUint32(e + 4, true);
        const size = (TYPE_SIZE[type] || 1) * count;
        const off = size <= 4 ? e + 8 : dv.getUint32(e + 8, true);
        if (off + size > buf.byteLength) { missing.push({ tag, type, count, off, size }); continue; }
        tags[tag] = type === 2
            ? new TextDecoder().decode(new Uint8Array(buf, off, Math.max(0, count - 1)))
            : readValues(dv, type, count, off);
    }
    return { tags, missing };
}

function describe(tags) {
    const one = (t, d) => (tags[t] ? tags[t][0] : d);
    const cog = {
        width: one(256), height: one(257),
        tileWidth: one(322), tileHeight: one(323),
        bits: one(258, 8), samples: one(277, 1),
        compression: one(259, 1), predictor: one(317, 1), planar: one(284, 1),
        offsets: tags[324], counts: tags[325],
        nodata: tags[42113] !== undefined ? Number(tags[42113]) : null,
    };
    if (!cog.tileWidth || !cog.offsets) throw new Error('The image is not tiled');
    if (![1, 8, 32946].includes(cog.compression)) throw new Error(`Compression ${cog.compression} is not supported`);
    if (cog.planar !== 1 && cog.samples > 1) throw new Error('Band-separated TIFF is not supported');
    if (![8, 16].includes(cog.bits)) throw new Error(`${cog.bits}-bit samples are not supported`);
    const scale = tags[33550], tie = tags[33922];
    if (!scale || !tie) throw new Error('The image has no georeference');
    // pixel (0,0) corner = tiepoint model x/y
    cog.originX = tie[3] - tie[0] * scale[0];
    cog.originY = tie[4] + tie[1] * scale[1];
    cog.resX = scale[0];
    cog.resY = scale[1];
    cog.tilesAcross = Math.ceil(cog.width / cog.tileWidth);
    cog.tilesDown = Math.ceil(cog.height / cog.tileHeight);
    return cog;
}

/** Open a COG: reads and caches its header (first image directory). */
export function openCog(url, signal) {
    if (!headers.has(url)) {
        const p = (async () => {
            let buf = await fetchRange(url, 0, HEADER_BYTES - 1, signal);
            let { tags, missing } = parseHeader(buf);
            if (missing.length) {
                const end = Math.max(...missing.map(m => m.off + m.size));
                buf = await fetchRange(url, 0, end - 1, signal);
                ({ tags } = parseHeader(buf));
            }
            const cog = describe(tags);
            cog.url = url;
            return cog;
        })();
        p.catch(() => headers.delete(url));
        headers.set(url, p);
    }
    return headers.get(url);
}

async function inflate(buf) {
    const stream = new Blob([buf]).stream().pipeThrough(new DecompressionStream('deflate'));
    return new Response(stream).arrayBuffer();
}

function undoPredictor(arr, width, height, samples) {
    const row = width * samples;
    for (let y = 0; y < height; y++) {
        const base = y * row;
        for (let i = samples; i < row; i++) arr[base + i] += arr[base + i - samples];
    }
}

function readTile(cog, index, signal) {
    const key = `${cog.url}#${index}`;
    if (!tiles.has(key)) {
        const p = (async () => {
            const off = cog.offsets[index], len = cog.counts[index];
            const n = cog.tileWidth * cog.tileHeight * cog.samples;
            const Arr = cog.bits === 16 ? Uint16Array : Uint8Array;
            if (!len) return new Arr(n).fill(cog.nodata || 0);   // sparse tile
            let buf = await fetchRange(cog.url, off, off + len - 1, signal);
            if (cog.compression !== 1) buf = await inflate(buf);
            const arr = new Arr(buf, 0, Math.min(n, buf.byteLength / Arr.BYTES_PER_ELEMENT));
            if (cog.predictor === 2) undoPredictor(arr, cog.tileWidth, cog.tileHeight, cog.samples);
            return arr;
        })();
        p.catch(() => tiles.delete(key));
        tiles.set(key, p);
        if (tiles.size > MAX_TILES) tiles.delete(tiles.keys().next().value);
    }
    return tiles.get(key);
}

/**
 * Read a pixel window (x0, y0 = top-left pixel, w x h; may extend past the image:
 * those pixels get the nodata value). Returns { data (pixel-interleaved), width, height, samples }.
 */
export async function readWindow(cog, x0, y0, w, h, signal) {
    const Arr = cog.bits === 16 ? Uint16Array : Uint8Array;
    const S = cog.samples;
    const out = new Arr(w * h * S).fill(cog.nodata || 0);
    const tx0 = Math.max(0, Math.floor(x0 / cog.tileWidth)), tx1 = Math.min(cog.tilesAcross - 1, Math.floor((x0 + w - 1) / cog.tileWidth));
    const ty0 = Math.max(0, Math.floor(y0 / cog.tileHeight)), ty1 = Math.min(cog.tilesDown - 1, Math.floor((y0 + h - 1) / cog.tileHeight));
    const jobs = [];
    for (let ty = ty0; ty <= ty1; ty++) {
        for (let tx = tx0; tx <= tx1; tx++) {
            jobs.push(readTile(cog, ty * cog.tilesAcross + tx, signal).then(tile => {
                const bx = tx * cog.tileWidth, by = ty * cog.tileHeight;
                const xa = Math.max(x0, bx), xb = Math.min(x0 + w, bx + cog.tileWidth, cog.width);
                const ya = Math.max(y0, by), yb = Math.min(y0 + h, by + cog.tileHeight, cog.height);
                for (let y = ya; y < yb; y++) {
                    const src = ((y - by) * cog.tileWidth + (xa - bx)) * S;
                    const dst = ((y - y0) * w + (xa - x0)) * S;
                    out.set(tile.subarray(src, src + (xb - xa) * S), dst);
                }
            }));
        }
    }
    await Promise.all(jobs);
    return { data: out, width: w, height: h, samples: S };
}

/** Pixel window of a COG for a square area (UTM centre e, n and size in metres). */
export function windowFor(cog, e, n, sizeM) {
    const half = sizeM / 2;
    const x0 = Math.floor((e - half - cog.originX) / cog.resX);
    const y0 = Math.floor((cog.originY - (n + half)) / cog.resY);
    const w = Math.max(1, Math.round(sizeM / cog.resX));
    const h = Math.max(1, Math.round(sizeM / cog.resY));
    // UTM of the window's top-left corner (to place polygons)
    return { x0, y0, w, h, left: cog.originX + x0 * cog.resX, top: cog.originY - y0 * cog.resY, res: cog.resX };
}

/** WGS84 lat/lon (degrees) -> UTM easting/northing (metres) in the given zone. */
export function latLonToUtm(lat, lon, zone, south) {
    const a = 6378137, f = 1 / 298.257223563, k0 = 0.9996;
    const e2 = f * (2 - f), e4 = e2 * e2, e6 = e4 * e2, ep2 = e2 / (1 - e2);
    const phi = lat * Math.PI / 180;
    const lon0 = ((zone - 1) * 6 - 180 + 3) * Math.PI / 180;
    const sin = Math.sin(phi), cos = Math.cos(phi), tan = Math.tan(phi);
    const N = a / Math.sqrt(1 - e2 * sin * sin);
    const T = tan * tan, C = ep2 * cos * cos, A = cos * (lon * Math.PI / 180 - lon0);
    const M = a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi
        - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * Math.sin(2 * phi)
        + (15 * e4 / 256 + 45 * e6 / 1024) * Math.sin(4 * phi)
        - (35 * e6 / 3072) * Math.sin(6 * phi));
    const E = k0 * N * (A + (1 - T + C) * A ** 3 / 6 + (5 - 18 * T + T * T + 72 * C - 58 * ep2) * A ** 5 / 120) + 500000;
    let Nn = k0 * (M + N * tan * (A * A / 2 + (5 - T + 9 * C + 4 * C * C) * A ** 4 / 24
        + (61 - 58 * T + T * T + 600 * C - 330 * ep2) * A ** 6 / 720));
    if (south) Nn += 10000000;
    return [E, Nn];
}

/** UTM zone and hemisphere of an EPSG code (32601-32660 north, 32701-32760 south). */
export function utmOfEpsg(epsg) {
    if (epsg >= 32601 && epsg <= 32660) return { zone: epsg - 32600, south: false };
    if (epsg >= 32701 && epsg <= 32760) return { zone: epsg - 32700, south: true };
    return null;
}
