#!/usr/bin/env Rscript
#
# Satellite page models (Breedbase /breeders/satellite, step 5): crop / land-cover
# map, field yield estimates and vegetation indices per plot, from Sentinel-2
# Level-2A images (Earth Search Cloud-Optimized GeoTIFFs, read through GDAL
# /vsicurl: only the windows around the areas are downloaded).
#
# Usage: Rscript satellite_models.R <input.json> <output base>
#
# Input (written by bin/satellite_models.pl): dates, crop, settings, classes,
# sites [ { id, name, center [lon, lat], size_m, scenes [...], labels
# [ { class, ring } ], targets [ { id, name, ring } ], plots { trial_id, list } } ],
# calibration [ { id, name, source, ring, start, end, yield, scenes [...] } ].
# A scene: { id, date, scl, red, green, blue, nir, rededge1, swir16, red_offset }
# (an image path is a url, or a local file for the tests).
#
# Output: <base>.results.json, <base>.fields.csv, <base>.indices.csv,
# <base>.site<N>.map.tif. Progress lines start with "[satellite]".
#
# Method:
# - clear pixels: scene classification (SCL) not in 0 nodata, 1 saturated, 3 cloud
#   shadow, 8/9 cloud, 10 cirrus, 11 snow; reflectance = DN * 0.0001 + offset.
# - crop map: random forest on per-pixel features (period means of 6 bands and
#   NDVI / NDRE / EVI, plus season NDVI max / min / mean / sd), trained on the
#   drawn example areas of every site; accuracy by cross-validation where the
#   areas (not pixels) are left out, so pixels of one area are never in both
#   training and testing.
# - yield: per field, weighted means of NDVI / NDRE over its pixels on each
#   date with enough of the field clear; season features (NDVI area under the
#   curve above bare soil, NDVI and NDRE peaks, day of the peak) -> linear,
#   lasso or random forest model; accuracy by leave-one-field-out.

suppressPackageStartupMessages({
    library(jsonlite)
    library(terra)
    library(parallel)
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
# progress for the page and the job log: "[satellite] HH:MM:SS message"
say <- function(...) { cat("[satellite] ", format(Sys.time(), "%H:%M:%S"), " ", sprintf(...), "\n", sep = ""); flush(stdout()) }
notes <- character(0)
note <- function(...) { m <- sprintf(...); notes <<- c(notes, m); say("note: %s", m) }

# an error ends the run with the calls that led to it (in the job log)
options(error = function() {
    calls <- sys.calls()
    cat("[satellite] error in:\n")
    for (cl in rev(head(calls, -1))) cat("    ", deparse(cl, nlines = 1)[1], "\n")
    q(status = 1)
})

args <- commandArgs(TRUE)
if (length(args) < 2) stop("usage: satellite_models.R <input.json> <output base>")
inp <- fromJSON(args[1], simplifyVector = FALSE)
out_base <- args[2]
t_start <- Sys.time()

Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR", CPL_VSIL_CURL_ALLOWED_EXTENSIONS = ".tif,.TIF,.tiff",
           GDAL_HTTP_MAX_RETRY = "4", GDAL_HTTP_RETRY_DELAY = "2", VSI_CACHE = "TRUE", VSI_CACHE_SIZE = "50000000",
           GDAL_HTTP_MULTIRANGE = "YES", GDAL_HTTP_MERGE_CONSECUTIVE_RANGES = "YES")
terraOptions(progress = 0)

st <- inp$settings %||% list()
num <- function(x, default) { v <- suppressWarnings(as.numeric(x %||% default)); if (is.na(v)) default else v }
CORES <- max(1, min(num(st$cores, 4), detectCores()))
MIN_SCENE_CLEAR <- num(st$min_scene_clear, 10) / 100      # skip a date with less of the area clear
MIN_FIELD_CLEAR <- num(st$min_field_clear, 50) / 100      # a field / plot value needs this much of it clear
PERIOD_DAYS <- max(7, num(st$period_days, 30))
NTREE <- max(50, num(st$ntree, 300))
PX_PER_AREA <- max(20, num(st$pixels_per_area, 300))
CV_FOLDS <- max(2, num(st$cv_folds, 5))
MIN_PATCH_HA <- num(st$min_patch_ha, 0.5)
SMOOTH <- isTRUE(st$smooth %||% TRUE)
MIN_CONFIDENCE <- min(0.95, max(0, num(st$min_confidence, 50) / 100))   # share of the trees' votes; below: uncertain
BALANCE <- isTRUE(st$balance %||% TRUE)
YIELD_MODEL <- st$yield_model %||% "auto"
MAP_MODEL <- st$map_model %||% "auto"
PREDICTORS <- unlist(st$predictors %||% list("ndvi_auc", "ndre_max"))
MIN_DATES <- max(1, num(st$min_dates, 4))
MIN_FIELDS <- max(3, num(st$min_fields, 8))
LEVEL <- min(0.99, max(0.5, num(st$level, 90) / 100))
LOC_MIN_PEAK <- num(st$location_min_peak, 0.6)            # a trial placed at its location point: NDVI peak of a crop field
MIN_CROP_HA <- num(st$min_crop_ha, 2)                    # a regional training item: crop found in its sample squares
SOIL_NDVI <- 0.2
FEATS_ALL <- c("ndvi_auc", "ndvi_max", "ndre_max", "peak_day")
set.seed(num(st$seed, 1))

do_map <- isTRUE(inp$models$crop_map)
do_yield <- isTRUE(inp$models$yield)
do_indices <- isTRUE(inp$models$indices)
season_start <- as.Date(inp$dates$start)
season_end <- as.Date(inp$dates$end)
# the crop's season for the fields to estimate (the map may cover a whole year)
crop_start <- as.Date(inp$yield$season$start %||% inp$dates$start)
crop_end <- as.Date(inp$yield$season$end %||% inp$dates$end)
NOT_CLEAR <- c(0, 1, 3, 8, 9, 10, 11)
VARS <- c("blue", "green", "red", "nir", "rededge1", "swir16", "ndvi", "ndre", "evi")

# ---------------------------------------------------------------- geometry

utm_crs <- function(lon, lat) paste0("EPSG:", (if (lat < 0) 32700 else 32600) + floor((lon + 180) / 6) + 1)

# a 10 m grid in the UTM zone of the centre, aligned on 10 m
grid_square <- function(lon, lat, size_m, res = 10) {
    crs <- utm_crs(lon, lat)
    p <- crds(project(vect(cbind(lon, lat), crs = "EPSG:4326"), crs))
    half <- size_m / 2
    e <- ext(floor((p[1] - half) / res) * res, ceiling((p[1] + half) / res) * res,
             floor((p[2] - half) / res) * res, ceiling((p[2] + half) / res) * res)
    rast(e, res = res, crs = crs)
}

grid_rings <- function(rings, margin = 30, res = 10) {
    pts <- do.call(rbind, lapply(rings, function(r) do.call(rbind, lapply(r, function(p) c(p[[1]], p[[2]])))))
    lon <- mean(range(pts[, 1])); lat <- mean(range(pts[, 2]))
    crs <- utm_crs(lon, lat)
    xy <- crds(project(vect(pts, crs = "EPSG:4326"), crs))
    e <- ext(floor((min(xy[, 1]) - margin) / res) * res, ceiling((max(xy[, 1]) + margin) / res) * res,
             floor((min(xy[, 2]) - margin) / res) * res, ceiling((max(xy[, 2]) + margin) / res) * res)
    rast(e, res = res, crs = crs)
}

ring_matrix <- function(r) do.call(rbind, lapply(r, function(p) c(as.numeric(p[[1]]), as.numeric(p[[2]]))))

# rings (lon/lat) -> SpatVector in crs; points (one-point rings) and polygons
rings_vect <- function(rings, crs) {
    wkt <- vapply(rings, function(r) {
        m <- ring_matrix(r)
        if (nrow(m) == 1) return(sprintf("POINT (%.9f %.9f)", m[1, 1], m[1, 2]))
        if (any(m[1, ] != m[nrow(m), ])) m <- rbind(m, m[1, ])
        sprintf("POLYGON ((%s))", paste(sprintf("%.9f %.9f", m[, 1], m[, 2]), collapse = ", "))
    }, "")
    project(vect(wkt, crs = "EPSG:4326"), crs)
}

area_ha_ring <- function(m) {
    lat0 <- mean(m[, 2]); kx <- 111320 * cos(lat0 * pi / 180); ky <- 110574
    x <- m[, 1] * kx; y <- m[, 2] * ky; n <- nrow(m)
    abs(sum(x * c(y[-1], y[1]) - c(x[-1], x[1]) * y)) / 2 / 10000
}

# cells and weights (fraction of the cell inside) of each ring in a grid;
# a ring of one point is a point (the pixel under it)
ring_cells <- function(rings, tmpl) {
    idr <- tmpl; values(idr) <- seq_len(ncell(tmpl))
    out <- lapply(rings, function(r) list(cells = integer(0), w = numeric(0)))
    is_pt <- vapply(rings, function(r) length(r) == 1, TRUE)
    for (pts in c(FALSE, TRUE)) {
        k <- which(is_pt == pts)
        if (!length(k)) next
        v <- rings_vect(rings[k], crs(tmpl))
        ex <- if (pts) extract(idr, v, cells = TRUE) else extract(idr, v, exact = TRUE, cells = TRUE)
        for (j in seq_along(k)) {
            e <- ex[ex$ID == j & !is.na(ex$cell), , drop = FALSE]
            out[[k[j]]] <- list(cells = e$cell, w = if (pts) rep(1, nrow(e)) else e$fraction)
        }
    }
    out
}

# only the pixels wholly inside a field: nothing from outside it enters its values
# (a field narrower than about two pixels has none)
whole_pixels <- function(cw) { k <- cw$w >= 0.999; list(cells = cw$cells[k], w = rep(1, sum(k))) }

# cells whose centre is inside each ring (training pixels of the drawn examples)
ring_centre_cells <- function(rings, tmpl) {
    idr <- tmpl; values(idr) <- seq_len(ncell(tmpl))
    v <- rings_vect(rings, crs(tmpl))
    ex <- extract(idr, v, cells = TRUE)
    lapply(seq_along(rings), function(j) ex$cell[ex$ID == j & !is.na(ex$cell)])
}

# ---------------------------------------------------------------- images

src_path <- function(h) if (grepl("^https?://", h)) paste0("/vsicurl/", h) else h

# an image read in the window of the grid and resampled onto it
read_to <- function(href, tmpl, method) {
    r <- rast(src_path(href))
    e <- project(ext(tmpl), crs(tmpl), crs(r))
    e <- ext(xmin(e) - 60, xmax(e) + 60, ymin(e) - 60, ymax(e) + 60)
    e <- intersect(e, ext(r))
    if (is.null(e)) return(NULL)
    rc <- crop(r, e, snap = "out")
    if (same.crs(rc, tmpl)) resample(rc, tmpl, method = method) else project(rc, tmpl, method = method)
}

# one date in a grid: clear mask and reflectances (NA where not clear)
# roi: cells whose clear share decides whether the date is read at all
read_scene <- function(sc, tmpl, bands, roi = NULL) {
    out <- list(id = sc$id, date = as.Date(sc$date))
    res <- tryCatch({
        scl <- read_to(sc$scl, tmpl, "near")
        if (is.null(scl)) return(c(out, list(skipped = "outside")))
        v <- values(scl, mat = FALSE)
        clear <- !is.na(v) & !(v %in% NOT_CLEAR)
        frac <- if (length(roi)) mean(clear[roi]) else mean(clear)
        if (is.na(frac) || frac < MIN_SCENE_CLEAR) return(c(out, list(skipped = "cloud", clear = frac)))
        scale <- 0.0001
        offset <- as.numeric(sc$red_offset %||% 0)
        m <- matrix(NA_real_, nrow = ncell(tmpl), ncol = length(bands), dimnames = list(NULL, bands))
        for (b in bands) {
            if (is.null(sc[[b]])) stop(sprintf("the image has no %s band", b))
            r <- read_to(sc[[b]], tmpl, if (b %in% c("rededge1", "swir16")) "bilinear" else "near")
            x <- values(r, mat = FALSE)
            x[!is.na(x) & x == 0] <- NA
            m[, b] <- x * scale + offset
        }
        m[!clear, ] <- NA
        c(out, list(clear = frac, vals = add_indices(m)))
    }, error = function(e) c(out, list(error = conditionMessage(e))))
    res
}

add_indices <- function(m) {
    has <- function(b) b %in% colnames(m)
    cols <- list()
    if (has("red") && has("nir")) cols$ndvi <- (m[, "nir"] - m[, "red"]) / (m[, "nir"] + m[, "red"])
    if (has("rededge1") && has("nir")) cols$ndre <- (m[, "nir"] - m[, "rededge1"]) / (m[, "nir"] + m[, "rededge1"])
    if (has("blue") && has("red") && has("nir")) {
        evi <- 2.5 * (m[, "nir"] - m[, "red"]) / (m[, "nir"] + 6 * m[, "red"] - 7.5 * m[, "blue"] + 1)
        evi[!is.finite(evi) | evi < -1 | evi > 2.5] <- NA
        cols$evi <- evi
    }
    if (length(cols)) m <- cbind(m, do.call(cbind, cols))
    m[!is.finite(m)] <- NA
    m
}

# read dates in parallel batches; fun(scene result) consumes each date at once
# so a long season never holds all images in memory
for_scenes <- function(scenes, tmpl, bands, roi, label, fun) {
    n <- length(scenes)
    if (!n) return(invisible(list(used = 0, skipped = 0, failed = 0)))
    used <- 0; skipped <- 0; failed <- 0; errs <- character(0)
    log_dates <- list()    # every date: used / cloudy / outside / failed, with its clear share (for the report)
    batches <- split(seq_len(n), ceiling(seq_len(n) / CORES))
    done <- 0
    t0 <- Sys.time()
    say("%s: reading %d dates in %d batches of %d (%s)", label, n, length(batches), CORES, paste(bands, collapse = ", "))
    for (b in batches) {
        tb <- Sys.time()
        u0 <- used; s0 <- skipped; f0 <- failed
        rs <- mclapply(scenes[b], read_scene, tmpl = tmpl, bands = bands, roi = roi, mc.cores = CORES, mc.preschedule = FALSE)
        for (q in seq_along(rs)) {
            r <- rs[[q]]
            sc <- scenes[b][[q]]
            ent <- list(date = as.character(sc$date), id = as.character(sc$id))
            if (inherits(r, "try-error")) { failed <- failed + 1; errs <- c(errs, as.character(r)); log_dates[[length(log_dates) + 1]] <- c(ent, status = "failed"); next }
            if (!is.null(r$error)) { failed <- failed + 1; errs <- c(errs, r$error); log_dates[[length(log_dates) + 1]] <- c(ent, status = "failed"); next }
            if (!is.null(r$skipped)) {
                skipped <- skipped + 1
                log_dates[[length(log_dates) + 1]] <- c(ent, status = if (r$skipped == "outside") "outside" else "cloudy", clear = if (is.null(r$clear) || is.na(r$clear)) NULL else round(100 * r$clear))
                next
            }
            used <- used + 1
            log_dates[[length(log_dates) + 1]] <- c(ent, status = "used", clear = round(100 * r$clear))
            fun(r)
        }
        done <- done + length(b)
        say("%s: %d/%d dates read (this batch: %d used, %d too cloudy, %d failed; %.0f s)", label, done, n,
            used - u0, skipped - s0, failed - f0, as.numeric(difftime(Sys.time(), tb, units = "secs")))
    }
    say("%s: %d dates used, %d skipped as cloudy (< %.0f%% clear), %d failed, in %.0f s", label, used, skipped, 100 * MIN_SCENE_CLEAR, failed,
        as.numeric(difftime(Sys.time(), t0, units = "secs")))
    if (failed) note("%s: %d date(s) could not be read (%s)", label, failed, paste(unique(head(errs, 3)), collapse = "; "))
    log_dates <- log_dates[order(vapply(log_dates, function(e) e$date, ""))]
    invisible(list(used = used, skipped = skipped, failed = failed, dates = log_dates))
}

wmean <- function(x, cw) {
    x <- x[cw$cells]; ok <- !is.na(x)
    if (!length(x) || sum(cw$w) <= 0) return(c(NA, 0))
    share <- sum(cw$w[ok]) / sum(cw$w)
    if (share < MIN_FIELD_CLEAR) return(c(NA, share))
    c(sum(cw$w[ok] * x[ok]) / sum(cw$w[ok]), share)
}

# ---------------------------------------------------------------- season features

season_features <- function(d, start, end) {
    d <- d[!is.na(d$ndvi) & d$date >= start & d$date <= end, , drop = FALSE]
    n <- nrow(d)
    if (!n) return(c(n_dates = 0, ndvi_auc = NA, ndvi_max = NA, ndre_max = NA, peak_day = NA))
    t <- as.numeric(d$date - start); total <- as.numeric(end - start)
    # bare soil at both ends of the season
    tt <- c(0, t, total); yy <- c(SOIL_NDVI, pmax(d$ndvi, SOIL_NDVI), SOIL_NDVI)
    o <- order(tt); tt <- tt[o]; yy <- yy[o] - SOIL_NDVI
    auc <- sum(diff(tt) * (head(yy, -1) + tail(yy, -1)) / 2)
    c(n_dates = n, ndvi_auc = auc, ndvi_max = max(d$ndvi),
      ndre_max = if (all(is.na(d$ndre))) NA else max(d$ndre, na.rm = TRUE), peak_day = t[which.max(d$ndvi)])
}

# the site's crop seasons (sgn.conf available_seasons, e.g. summer, safrinha) with their sowing
# windows (R/satellite/standards/seasons.json): a season found in a field is named by the window
# its sowing falls in; a long period (>= 300 days) splits the maize map by season
.sfile <- grep("^--file=", commandArgs(FALSE), value = TRUE)
SCRIPT_DIR <- if (length(.sfile)) dirname(normalizePath(sub("^--file=", "", .sfile[1]))) else "R/satellite"
SEASONS_DEF <- tryCatch(fromJSON(file.path(SCRIPT_DIR, "standards", "seasons.json"), simplifyVector = FALSE), error = function(e) NULL)
SEASON_NAMES <- unlist(inp$season_names %||% list())
# the named seasons apply only to the countries listed (Brazil: summer / safrinha); elsewhere, and in
# the other hemisphere, seasons are found in each curve but not named by a calendar
seasons_for_country <- function(country) {
    cs <- SEASONS_DEF$countries
    if (is.null(cs) || is.null(country) || !nzchar(country)) return(list())
    k <- names(cs)[tolower(names(cs)) == tolower(trimws(country))]
    if (!length(k)) return(list())
    Filter(Negate(is.null), setNames(lapply(SEASON_NAMES, function(n) cs[[k[1]]]$seasons[[n]]), SEASON_NAMES))
}
SITE_SEASONS <- lapply(inp$sites %||% list(), function(s) seasons_for_country(s$country))
SEASONS_SOURCE <- function(country) { cs <- SEASONS_DEF$countries; k <- names(cs)[tolower(names(cs)) == tolower(trimws(country %||% ""))]; if (length(k)) cs[[k[1]]]$source else NULL }
in_window <- function(d, w) {
    md <- format(d, "%m-%d")
    if (w[[1]] <= w[[2]]) md >= w[[1]] & md <= w[[2]] else md >= w[[1]] | md <= w[[2]]
}
season_of <- function(d, cfg) {
    for (n in names(cfg)) if (isTRUE(in_window(d, cfg[[n]]$sow))) return(n)
    NA_character_
}

# seasons of a field from its NDVI curve: green-up (>= 0.6) from bare soil (<= 0.35) and back = harvest
SEASON_HI <- 0.6; SEASON_LO <- 0.35
detect_seasons <- function(d, cfg = list()) {
    d <- d[!is.na(d$ndvi), , drop = FALSE]
    d <- d[order(d$date), , drop = FALSE]
    n <- nrow(d)
    if (n < 5) return(list())
    x <- as.numeric(stats::runmed(d$ndvi, 3, endrule = "keep"))
    dt <- d$date
    out <- list(); i <- 1
    while (i <= n) {
        j <- which(x[i:n] >= SEASON_HI)[1]
        if (is.na(j)) break
        j <- i + j - 1
        lows <- which(x[i:j] <= SEASON_LO)
        st <- if (length(lows)) i + max(lows) - 1 else NA
        k <- which(x[j:n] <= SEASON_LO)[1]
        en <- if (is.na(k)) NA else j + k - 1
        last_green <- if (is.na(en)) n else en - 1
        p <- j - 1 + which.max(x[j:last_green])
        if (as.numeric(dt[last_green] - dt[j]) >= 30 || is.na(en)) {
            ref <- if (!is.na(st)) dt[st] else dt[j] - 30
            # named only where the site's country has season windows; otherwise just "season"
            label <- if (length(cfg)) { x0 <- season_of(ref, cfg); if (is.na(x0)) "other" else x0 } else "season"
            crosses <- !is.null(cfg[[label]]) && cfg[[label]]$harvest[[1]] < cfg[[label]]$sow[[1]]
            out[[length(out) + 1]] <- list(
                label = label,
                year = if (crosses) sprintf("%s/%s", format(ref, "%Y"), substr(format(ref + 365, "%Y"), 3, 4)) else format(ref, "%Y"),
                bare_until = if (!is.na(st)) as.character(dt[st]) else NULL, started_before_period = is.na(st),
                green_from = as.character(dt[j]), peak_date = as.character(dt[p]), peak = x[p],
                last_green = as.character(dt[last_green]), bare_again = if (!is.na(en)) as.character(dt[en]) else NULL,
                harvested = !is.na(en),
                # a harvest cuts the canopy: NDVI falls >= 0.2 within ~30 days; a slow fall is drying / senescence
                end_type = if (is.na(en)) "green" else {
                    w <- which(dt >= dt[en] - 30 & dt <= dt[en])
                    if (max(x[w]) - x[en] >= 0.2) "harvest" else "dry-down"
                },
                start = as.character(if (!is.na(st)) dt[st] else dt[1]), end = as.character(if (!is.na(en)) dt[en] else dt[n]))
        }
        i <- if (is.na(en)) n + 1 else en + 1
    }
    out
}
SEASON_NAME <- c(season = "season", other = "season outside the country's season windows")
for (cfg in SITE_SEASONS) for (n in names(cfg)) SEASON_NAME[[n]] <- cfg[[n]]$label %||% n
SEASON_MODE <- inp$yield$season_mode %||% "dates"

PRED_LABEL <- c(ndvi_auc = "NDVI area under the season curve", ndvi_max = "NDVI peak", ndre_max = "NDRE peak", peak_day = "day of the NDVI peak")

# ---------------------------------------------------------------- sites

classes <- inp$classes %||% list()
class_names <- vapply(classes, function(k) as.character(k$name), "")
class_ids <- vapply(classes, function(k) as.character(k$id), "")
crop_class <- as.character(inp$crop_class %||% "")
# memory: the crop map keeps, per pixel, sums of 9 values per period; longer
# periods when the largest site and the season would need too much
if (do_map && length(inp$sites)) {
    cells_max <- max(vapply(inp$sites, function(s) (as.numeric(s$size_m) / 10 + 2)^2, 0))
    max_periods <- max(1, floor(4e7 / (cells_max * length(VARS))))
    need <- ceiling(as.numeric(season_end - season_start + 1) / PERIOD_DAYS)
    if (need > max_periods) {
        PERIOD_DAYS <- ceiling(as.numeric(season_end - season_start + 1) / max_periods)
        note("crop map: periods of %d days instead of %d (large area and long season)", PERIOD_DAYS, num(st$period_days, 30))
    }
}
periods <- seq(season_start, season_end, by = PERIOD_DAYS)
n_periods <- length(periods)
period_of <- function(d) findInterval(as.numeric(d), as.numeric(periods))
# crop map method: "examples" (random forest on drawn examples) or "standard"
# (a stored crop curve, R/satellite/standards/<crop>.json, matched to every pixel)
STANDARD <- do_map && identical(inp$crop_map_method, "standard")
need_maps <- (do_yield && do_map && nzchar(crop_class)) || STANDARD

sites <- inp$sites %||% list()
site_out <- vector("list", length(sites))
site_data <- vector("list", length(sites))
say("%d site(s), %s to %s", length(sites), season_start, season_end)

for (si in seq_along(sites)) {
    s <- sites[[si]]
    label <- s$name
    tmpl <- grid_square(as.numeric(s$center[[1]]), as.numeric(s$center[[2]]), as.numeric(s$size_m))
    n <- ncell(tmpl)
    targets <- s$targets %||% list()
    plots <- s$plots$list %||% list()
    want_plots <- do_indices && length(plots) > 0
    want_targets <- do_yield && length(targets) > 0
    if (!do_map && !want_plots && !want_targets) { site_out[[si]] <- list(id = s$id, name = s$name); next }
    bands <- if (do_map && !STANDARD) c("blue", "green", "red", "nir", "rededge1", "swir16")
             else if (want_plots) c("blue", "red", "nir", "rededge1") else c("red", "nir", "rededge1")
    say("%s: %d x %d pixels, %d dates", label, ncol(tmpl), nrow(tmpl), length(s$scenes))

    tcw <- if (want_targets) lapply(ring_cells(lapply(targets, function(t) t$ring), tmpl), whole_pixels) else list()
    # the area selected on the page (the delimited fields): clouds, the crop map and its hectares only there;
    # without delimited fields the selected area is the whole square
    area_rings <- s$area %||% list()
    inside <- rep(TRUE, n)
    if (length(area_rings)) inside <- seq_len(n) %in% unique(unlist(ring_centre_cells(area_rings, tmpl)))
    roi_site <- if (length(area_rings)) which(inside) else NULL
    if (length(area_rings)) say("%s: selected area %d pixels (%.1f ha) of the %d read; clouds and the map only there", label, sum(inside), sum(inside) / 100, n)
    pcw <- if (want_plots) ring_cells(lapply(plots, function(p) p$ring), tmpl) else list()
    acc <- NULL
    if (do_map && !STANDARD) {
        acc <- list(sum = array(0, c(n, length(VARS), n_periods)), cnt = array(0L, c(n, length(VARS), n_periods)),
                    mx = rep(-Inf, n), mn = rep(Inf, n), s1 = numeric(n), s2 = numeric(n), k = integer(n))
    }
    ndvi_dates <- list(); ndre_dates <- list(); dates_used <- character(0)
    tseries <- lapply(targets, function(t) data.frame(date = as.Date(character(0)), ndvi = numeric(0), ndre = numeric(0)))
    prows <- list()

    sq_series <- list()
    stats <- for_scenes(s$scenes, tmpl, bands, roi_site, label, function(r) {
        m <- r$vals
        sq_series[[length(sq_series) + 1]] <<- list(date = as.character(r$date), ndvi = round(mean(m[inside, "ndvi"], na.rm = TRUE), 4),
                                                   clear = round(100 * mean(!is.na(m[inside, "ndvi"]))))
        dates_used <<- c(dates_used, as.character(r$date))
        if (do_map && !STANDARD) {
            p <- period_of(r$date)
            if (p >= 1 && p <= n_periods) {
                for (j in seq_along(VARS)) {
                    if (!VARS[j] %in% colnames(m)) next
                    x <- m[, VARS[j]]; ok <- !is.na(x)
                    acc$sum[ok, j, p] <<- acc$sum[ok, j, p] + x[ok]
                    acc$cnt[ok, j, p] <<- acc$cnt[ok, j, p] + 1L
                }
            }
            x <- m[, "ndvi"]; ok <- !is.na(x)
            acc$mx[ok] <<- pmax(acc$mx[ok], x[ok]); acc$mn[ok] <<- pmin(acc$mn[ok], x[ok])
            acc$s1[ok] <<- acc$s1[ok] + x[ok]; acc$s2[ok] <<- acc$s2[ok] + x[ok]^2; acc$k[ok] <<- acc$k[ok] + 1L
        }
        if (need_maps) {
            ndvi_dates[[length(ndvi_dates) + 1]] <<- as.integer(round(m[, "ndvi"] * 10000))
            ndre_dates[[length(ndre_dates) + 1]] <<- as.integer(round(m[, "ndre"] * 10000))
        }
        for (k in seq_along(tcw)) {
            a <- wmean(m[, "ndvi"], tcw[[k]]); b <- wmean(m[, "ndre"], tcw[[k]])
            if (!is.na(a[1])) tseries[[k]] <<- rbind(tseries[[k]], data.frame(date = r$date, ndvi = a[1], ndre = b[1]))
        }
        if (want_plots) {
            for (k in seq_along(pcw)) {
                a <- wmean(m[, "ndvi"], pcw[[k]])
                if (is.na(a[1])) next
                prows[[length(prows) + 1]] <<- data.frame(plot_id = plots[[k]]$id, plot_name = plots[[k]]$name, date = as.character(r$date),
                    ndvi = a[1], ndre = wmean(m[, "ndre"], pcw[[k]])[1], evi = wmean(m[, "evi"], pcw[[k]])[1], clear_pct = round(100 * a[2]))
            }
        }
    })
    site_out[[si]] <- list(id = s$id, name = s$name, center = s$center, dates_found = length(s$scenes), dates_hidden = as.integer(s$hidden %||% 0), dates_used = stats$used,
                           images = stats$dates, area_series = sq_series,
                           dates_cloudy = stats$skipped, dates_failed = stats$failed, size_m = s$size_m)
    site_data[[si]] <- list(tmpl = tmpl, tcw = tcw, acc = acc, inside = inside, ndvi = ndvi_dates, ndre = ndre_dates, dates = as.Date(dates_used),
                            tseries = tseries, plots = if (length(prows)) do.call(rbind, prows) else NULL)
    if (stats$used == 0) note("%s: no date clear enough in the date range", label)
}

# ---------------------------------------------------------------- crop map

period_label <- function(p) {
    a <- periods[p]; b <- min(season_end, a + PERIOD_DAYS - 1)
    sprintf("%s-%s", format(a, "%d %b"), format(b, "%d %b"))
}
feat_names <- c(as.vector(outer(VARS, seq_len(n_periods), function(v, p) paste0(v, "_p", p))), "ndvi_season_max", "ndvi_season_min", "ndvi_season_mean", "ndvi_season_sd")

site_features <- function(acc) {
    n <- dim(acc$sum)[1]
    f <- matrix(NA_real_, n, length(feat_names), dimnames = list(NULL, feat_names))
    col <- 1
    for (p in seq_len(n_periods)) for (j in seq_along(VARS)) {
        cnt <- acc$cnt[, j, p]
        f[, paste0(VARS[j], "_p", p)] <- ifelse(cnt > 0, acc$sum[, j, p] / pmax(cnt, 1), NA)
    }
    k <- acc$k
    f[, "ndvi_season_max"] <- ifelse(k > 0, acc$mx, NA)
    f[, "ndvi_season_min"] <- ifelse(k > 0, acc$mn, NA)
    f[, "ndvi_season_mean"] <- ifelse(k > 0, acc$s1 / pmax(k, 1), NA)
    f[, "ndvi_season_sd"] <- ifelse(k > 1, sqrt(pmax(0, acc$s2 / pmax(k, 1) - (acc$s1 / pmax(k, 1))^2)), NA)
    f
}

crop_map <- NULL
# training on regional statistics: the crop is found in sample squares by the same stored curve
HAS_REGIONS <- do_yield && any(vapply(inp$calibration %||% list(), function(cf) identical(cf$kind, "region"), TRUE))
if (STANDARD || HAS_REGIONS) {
    # ------------------------------------------------------------ the stored crop curve
    sfile <- grep("^--file=", commandArgs(FALSE), value = TRUE)
    script_dir <- if (length(sfile)) dirname(normalizePath(sub("^--file=", "", sfile[1]))) else "R/satellite"
    stdf <- file.path(script_dir, "standards", paste0(inp$standard %||% "maize", ".json"))
    std <- fromJSON(stdf)
    ru <- std$rules
    say("%s: matching pixels to the %s standard curve (%s)", if (STANDARD) "crop map" else "training", std$crop, basename(stdf))
    tmpl_at <- function(das) approx(std$das, std$ndvi, das, rule = 2)$y
    rmax <- max(std$das)
    ph <- std$phases
    # best match of every pixel over the sowing dates given: maize, sowing date, cycle
    match_std <- function(X, X0, X2, M, dates, sows) {
        N <- nrow(X)
        best <- rep(-Inf, N); b_r <- rep(NA_real_, N); b_rmse <- rep(NA_real_, N); b_sow <- rep(NA_real_, N); b_k <- rep(NA_real_, N); covered <- rep(FALSE, N)
        for (k in std$cycle_scales) for (s0 in as.list(sows)) {
            das <- as.numeric(dates - s0) / k
            inc <- das >= 0 & das <= rmax
            if (sum(inc) < ru$min_obs) next
            t <- ifelse(inc, tmpl_at(das), 0)
            w <- as.numeric(inc)
            n <- as.vector(M %*% w)
            sx <- as.vector(X0 %*% w); sxx <- as.vector(X2 %*% w)
            st <- as.vector(M %*% t); stt <- as.vector(M %*% (t^2)); sxt <- as.vector(X0 %*% t)
            ok <- n >= ru$min_obs &
                as.vector(M %*% as.numeric(inc & das <= ph$early[2])) > 0 &
                as.vector(M %*% as.numeric(inc & das >= ph$plateau[1] & das <= ph$plateau[2])) > 0 &
                as.vector(M %*% as.numeric(inc & das >= ph$decline[1])) > 0
            if (!any(ok)) next
            covered <- covered | ok
            nn <- pmax(n, 1)
            rmse <- sqrt(pmax(0, (sxx - 2 * sxt + stt) / nn))
            cv <- sxt / nn - (sx / nn) * (st / nn)
            vx <- sxx / nn - (sx / nn)^2; vt <- stt / nn - (st / nn)^2
            r <- cv / sqrt(pmax(vx * vt, 1e-12))
            score <- ifelse(ok, r - rmse, -Inf)
            up <- score > best
            if (any(up)) { best[up] <- score[up]; b_r[up] <- r[up]; b_rmse[up] <- rmse[up]; b_sow[up] <- as.numeric(s0); b_k[up] <- k }
        }
        peak <- suppressWarnings(apply(X, 1, max, na.rm = TRUE)); peak[!is.finite(peak)] <- NA
        is_crop <- covered & !is.na(b_r) & b_r >= ru$min_r & b_rmse <= ru$max_rmse & !is.na(peak) & peak >= ru$min_peak
        list(is_crop = is_crop, covered = covered, sow = b_sow, k = b_k)
    }
}
if (STANDARD) {
    LONG <- as.numeric(season_end - season_start) >= 300
    if (any(lengths(SITE_SEASONS) > 0) && !LONG) say("crop map: period shorter than 300 days, the map is not split by season")
    split_used <- list()
    for (si in seq_along(sites)) {
        sd <- site_data[[si]]
        if (is.null(sd$tmpl) || !length(sd$ndvi)) next
        X <- do.call(cbind, sd$ndvi) / 10000
        dates <- sd$dates
        M <- !is.na(X); X0 <- X; X0[!M] <- 0; X2 <- X0^2
        N <- nrow(X)
        all_sows <- seq(season_start - 60, season_end - 60, by = ru$sow_step_days)
        mm <- match_std(X, X0, X2, M, dates, all_sows)
        is_crop <- mm$is_crop; covered <- mm$covered; b_sow <- mm$sow; b_k <- mm$k
        code <- ifelse(!covered, 3L, ifelse(is_crop, 1L, 2L))
        r <- sd$tmpl; values(r) <- code
        if (SMOOTH) { r2 <- focal(r, w = 3, fun = "modal", na.rm = TRUE); r <- r2 }
        # nothing outside the selected area
        out_cells <- which(!sd$inside)
        if (length(out_cells)) r[out_cells] <- NA
        is_crop <- is_crop & sd$inside
        sowr <- sd$tmpl; values(sowr) <- ifelse(is_crop, b_sow, NA)
        site_data[[si]]$map <- r
        site_data[[si]]$sow <- sowr
        site_data[[si]]$cycle <- ifelse(is_crop, b_k, NA)
        v <- values(r, mat = FALSE)
        ha <- res(r)[1] * res(r)[2] / 10000
        site_out[[si]]$classes <- lapply(seq_along(class_ids), function(i) list(id = class_ids[i], name = class_names[i], ha = sum(v == i, na.rm = TRUE) * ha))
        site_out[[si]]$uncertain_ha <- sum(v == 3L, na.rm = TRUE) * ha
        site_out[[si]]$unclassified_ha <- 0
        sw <- b_sow[is_crop]
        site_out[[si]]$sowing <- if (length(sw)) list(median = as.character(as.Date(median(sw), origin = "1970-01-01")),
            q10 = as.character(as.Date(quantile(sw, 0.1), origin = "1970-01-01")), q90 = as.character(as.Date(quantile(sw, 0.9), origin = "1970-01-01")),
            cycle_days = round(median(b_k[is_crop]) * 185)) else NULL
        vv <- ifelse(is.na(v), 0L, as.integer(v))
        rl <- rle(vv)
        site_out[[si]]$map <- list(crs = crs(r, describe = TRUE)$code, xmin = xmin(r), ymax = ymax(r), res = res(r)[1],
                                   ncol = ncol(r), nrow = nrow(r), rle = as.vector(rbind(rl$values, rl$lengths)))
        f <- sprintf("%s.site%d.map.tif", out_base, si)
        writeRaster(r, f, datatype = "INT1U", NAflag = 0, overwrite = TRUE, gdal = c("COMPRESS=DEFLATE"))
        site_out[[si]]$map_file <- basename(f)
        # the same map per season: only sowing dates inside the season's window
        cfg_si <- SITE_SEASONS[[si]] %||% list()
        if (LONG && length(cfg_si)) {
            site_out[[si]]$season_maps <- list()
            for (sn in names(cfg_si)) split_used[[sn]] <- list(id = sn, label = SEASON_NAME[[sn]], sow = cfg_si[[sn]]$sow, harvest = cfg_si[[sn]]$harvest)
            site_out[[si]]$seasons_source <- SEASONS_SOURCE(sites[[si]]$country)
            for (sn in names(cfg_si)) {
                sws <- all_sows[in_window(all_sows, cfg_si[[sn]]$sow)]
                if (!length(sws)) next
                ms <- match_std(X, X0, X2, M, dates, sws)
                cs <- ifelse(!ms$covered, 3L, ifelse(ms$is_crop, 1L, 2L))
                rs <- sd$tmpl; values(rs) <- cs
                if (SMOOTH) rs <- focal(rs, w = 3, fun = "modal", na.rm = TRUE)
                if (length(out_cells)) rs[out_cells] <- NA
                vs <- values(rs, mat = FALSE)
                sws_c <- ms$sow[ms$is_crop & sd$inside]
                rls <- rle(ifelse(is.na(vs), 0L, as.integer(vs)))
                site_out[[si]]$season_maps[[length(site_out[[si]]$season_maps) + 1]] <- list(
                    season = sn, label = SEASON_NAME[[sn]], crop_ha = sum(vs == 1L, na.rm = TRUE) * ha, uncertain_ha = sum(vs == 3L, na.rm = TRUE) * ha,
                    sowing = if (length(sws_c)) list(median = as.character(as.Date(median(sws_c), origin = "1970-01-01")),
                        q10 = as.character(as.Date(quantile(sws_c, 0.1), origin = "1970-01-01")), q90 = as.character(as.Date(quantile(sws_c, 0.9), origin = "1970-01-01"))) else NULL,
                    rle = as.vector(rbind(rls$values, rls$lengths)))
                say("%s: %s: %.1f ha of %s", sites[[si]]$name, SEASON_NAME[[sn]], sum(vs == 1L, na.rm = TRUE) * ha, std$crop)
            }
        }
        # check against the fields given as examples (step-2 field of the crop, drawn areas)
        labs <- sites[[si]]$labels %||% list()
        if (length(labs)) {
            cells <- ring_centre_cells(lapply(labs, function(l) l$ring), sd$tmpl)
            chk <- lapply(seq_along(labs), function(j) {
                cl <- cells[[j]]; if (!length(cl)) return(NULL)
                vals <- v[cl]
                list(class = as.character(labs[[j]]$class), pixels = length(cl), as_crop = sum(vals == 1L, na.rm = TRUE),
                     as_other = sum(vals == 2L, na.rm = TRUE), uncertain = sum(vals == 3L | is.na(vals)))
            })
            site_out[[si]]$check <- Filter(Negate(is.null), chk)
        }
        say("%s: %.1f ha of %s, %.1f ha uncertain", sites[[si]]$name, sum(v == 1L, na.rm = TRUE) * ha, std$crop, site_out[[si]]$uncertain_ha)
    }
    crop_map <- list(method = "standard", classes = lapply(seq_along(class_ids), function(i) list(id = class_ids[i], name = class_names[i], trained = TRUE)),
                     standard = list(crop = std$crop, source = std$source, note = std$note, rules = std$rules, das = std$das, ndvi = std$ndvi, cycle_scales = std$cycle_scales),
                     accuracy = NULL, uncertain_code = 3L, min_confidence = NA, smoothed = SMOOTH,
                     split = length(split_used) > 0, seasons = unname(split_used),
                     seasons_source = if (length(split_used)) paste("Season windows only for", paste(names(SEASONS_DEF$countries), collapse = ", "), "locations:", SEASONS_DEF$countries[[1]]$source) else NULL)
    note("crop map: %s found by its typical season curve (proof of concept, no examples): crops with a similar season (e.g. soybean, sorghum) can be confused with it", std$crop)
}
if (do_map && !STANDARD) {
    say("crop map: collecting the drawn examples")
    rows <- list()
    for (si in seq_along(sites)) {
        labs <- sites[[si]]$labels %||% list()
        if (!length(labs) || is.null(site_data[[si]]$acc)) next
        site_data[[si]]$feat <- site_features(site_data[[si]]$acc)
        cells <- ring_centre_cells(lapply(labs, function(l) l$ring), site_data[[si]]$tmpl)
        for (k in seq_along(labs)) {
            cl <- cells[[k]]
            if (!length(cl)) { note("an example area of %s at %s holds no pixel of the area (too small, or outside it) and was not used", class_names[match(as.character(labs[[k]]$class), class_ids)] %||% labs[[k]]$class, sites[[si]]$name); next }
            if (length(cl) > PX_PER_AREA) cl <- sample(cl, PX_PER_AREA)
            rows[[length(rows) + 1]] <- data.frame(area = sprintf("%d_%d", si, k), class = as.character(labs[[k]]$class),
                                                   site_data[[si]]$feat[cl, , drop = FALSE], check.names = FALSE)
        }
    }
    for (si in seq_along(sites)) if (is.null(site_data[[si]]$feat) && !is.null(site_data[[si]]$acc)) site_data[[si]]$feat <- site_features(site_data[[si]]$acc)
    train <- if (length(rows)) do.call(rbind, rows) else NULL
    if (is.null(train)) {
        note("crop map: no example pixel could be used; the map was not made")
    } else {
        # columns: drop those mostly missing in the training pixels (a period without clear image)
        miss <- colMeans(is.na(train[, feat_names, drop = FALSE]))
        keep <- feat_names[miss <= 0.5]
        if (length(keep) < length(feat_names)) note("crop map: %d of %d features left out (periods without enough clear images)", length(feat_names) - length(keep), length(feat_names))
        med <- vapply(keep, function(k) median(train[[k]], na.rm = TRUE), 0)
        impute <- function(m) { for (k in keep) { x <- m[, k]; x[is.na(x)] <- med[[k]]; m[, k] <- x }; m }
        train <- train[rowSums(!is.na(train[, keep, drop = FALSE])) > 0, , drop = FALSE]
        tx <- impute(as.matrix(train[, keep, drop = FALSE]))
        ty <- factor(train$class, levels = class_ids[class_ids %in% unique(train$class)])
        present <- levels(ty)
        missing_cls <- setdiff(class_ids, present)
        if (length(missing_cls)) note("crop map: no example pixel for %s; it cannot appear on the map", paste(class_names[match(missing_cls, class_ids)], collapse = ", "))
        if (length(present) < 2) {
            note("crop map: examples of at least 2 classes are needed")
        } else {
            suppressPackageStartupMessages(library(randomForest))
            # ------------------------------------------------------------ classifiers
            CMODELS <- list(random_forest = list(label = "Random forest", pref = 1), svm = list(label = "SVM (radial)", pref = 2),
                            nnet = list(label = "Neural network", pref = 3), tree = list(label = "Decision tree", pref = 4))
            cls_fit <- function(type, x, y) {
                y <- droplevels(y)
                w <- as.numeric(1 / table(y)); names(w) <- levels(y)
                if (type == "random_forest") {
                    m <- if (BALANCE) randomForest(x, y, ntree = NTREE, strata = y, sampsize = rep(min(table(y)), nlevels(y))) else randomForest(x, y, ntree = NTREE)
                    return(list(type = type, m = m))
                }
                if (type == "svm") { suppressPackageStartupMessages(library(e1071)); return(list(type = type, m = svm(x, y, probability = TRUE, class.weights = if (BALANCE) w / mean(w) else NULL))) }
                if (type == "nnet") {
                    suppressPackageStartupMessages(library(nnet))
                    mu <- colMeans(x); sdv <- apply(x, 2, sd); sdv[!is.finite(sdv) | sdv == 0] <- 1
                    xs <- scale(x, mu, sdv)
                    wt <- if (BALANCE) as.numeric(w[as.character(y)] / mean(w)) else rep(1, length(y))
                    m <- nnet(xs, class.ind(y), size = min(10, max(3, ncol(x) %/% 4)), softmax = TRUE, decay = 5e-4, maxit = 300, MaxNWts = 1e5, trace = FALSE, weights = wt)
                    return(list(type = type, m = m, mu = mu, sd = sdv, levels = levels(y)))
                }
                if (type == "tree") {
                    suppressPackageStartupMessages(library(rpart))
                    d <- data.frame(y = y, x, check.names = FALSE)
                    return(list(type = type, m = rpart(y ~ ., data = d, method = "class", weights = if (BALANCE) as.numeric(w[as.character(y)]) else NULL, control = rpart.control(cp = 0.005))))
                }
                stop("unknown classifier ", type)
            }
            # class probabilities (columns: class ids)
            cls_prob <- function(fm, x) {
                p <- switch(fm$type,
                    random_forest = predict(fm$m, x, type = "prob"),
                    svm = { suppressPackageStartupMessages(library(e1071)); attr(predict(fm$m, x, probability = TRUE), "probabilities") },
                    nnet = { suppressPackageStartupMessages(library(nnet)); pr <- predict(fm$m, scale(x, fm$mu, fm$sd)); if (is.null(dim(pr))) pr <- cbind(1 - pr, pr); colnames(pr) <- fm$levels; pr },
                    tree = { suppressPackageStartupMessages(library(rpart)); predict(fm$m, data.frame(x, check.names = FALSE), type = "prob") })
                as.matrix(p)
            }
            cls_pred <- function(fm, x) { p <- cls_prob(fm, x); colnames(p)[max.col(p, ties.method = "first")] }
            # cross-validation by drawn area, every candidate on the same folds
            area_class <- tapply(train$class, train$area, function(x) x[1])
            per_class <- table(area_class)
            k <- min(CV_FOLDS, min(per_class[present]))
            cands <- if (MAP_MODEL == "auto") names(CMODELS) else MAP_MODEL
            cv <- NULL; ccomp <- list()
            if (k >= 2) {
                fold <- setNames(integer(length(area_class)), names(area_class))
                for (cl in present) {
                    a <- names(area_class)[area_class == cl]
                    fold[a] <- sample(rep_len(seq_len(k), length(a)))
                }
                say("crop map: comparing %d model(s) (%s) by %d-fold cross-validation by drawn area", length(cands), paste(cands, collapse = ", "), k)
                for (mt in cands) {
                    t0m <- Sys.time()
                    pred <- tryCatch({
                        pr <- factor(rep(NA, nrow(train)), levels = present)
                        for (f in seq_len(k)) {
                            test <- fold[train$area] == f
                            if (length(unique(ty[!test])) < 2) next
                            m <- cls_fit(mt, tx[!test, , drop = FALSE], ty[!test])
                            pr[test] <- cls_pred(m, tx[test, , drop = FALSE])
                        }
                        pr
                    }, error = function(e) { say("crop map: %s failed (%s)", mt, conditionMessage(e)); NULL })
                    if (is.null(pred)) { ccomp[[mt]] <- list(model = mt, label = CMODELS[[mt]]$label, failed = TRUE); next }
                    ok <- !is.na(pred)
                    cm <- table(observed = factor(ty[ok], levels = present), predicted = factor(pred[ok], levels = present))
                    oa <- sum(diag(cm)) / sum(cm)
                    pe <- sum(rowSums(cm) * colSums(cm)) / sum(cm)^2
                    kap <- if (pe < 1) (oa - pe) / (1 - pe) else NA
                    ccomp[[mt]] <- list(model = mt, label = CMODELS[[mt]]$label, pref = CMODELS[[mt]]$pref, overall = oa, kappa = kap, seconds = round(as.numeric(difftime(Sys.time(), t0m, units = "secs"))), failed = FALSE,
                        cv = list(folds = k, pixels = sum(cm), overall = oa, kappa = kap, classes = present, matrix = unname(lapply(seq_len(nrow(cm)), function(i) as.integer(cm[i, ]))),
                                  producer = unname(diag(cm) / pmax(rowSums(cm), 1)), user = unname(diag(cm) / pmax(colSums(cm), 1))))
                    say("crop map: %s accuracy %.1f%%, kappa %.2f (%.0f s)", CMODELS[[mt]]$label, 100 * oa, kap %||% NA, as.numeric(difftime(Sys.time(), t0m, units = "secs")))
                }
                okc <- Filter(function(z) !isTRUE(z$failed) && !is.na(z$kappa), ccomp)
                if (length(okc)) {
                    bk <- max(vapply(okc, function(z) z$kappa, 0))
                    near <- Filter(function(z) z$kappa >= bk - 0.01, okc)
                    MAP_MODEL <- near[[order(vapply(near, function(z) z$pref, 0))[1]]]$model
                    cv <- ccomp[[MAP_MODEL]]$cv
                    say("crop map: chosen %s (cross-validated accuracy %.1f%%)", CMODELS[[MAP_MODEL]]$label, 100 * cv$overall)
                } else MAP_MODEL <- "random_forest"
            } else {
                if (MAP_MODEL == "auto") MAP_MODEL <- "random_forest"
                note("crop map: accuracy not measured (and models not compared) - draw at least 2 example areas of each class")
            }
            say("crop map: training the %s on %d pixels of %d areas", CMODELS[[MAP_MODEL]]$label, nrow(tx), length(area_class))
            fm_map <- cls_fit(MAP_MODEL, tx, ty)
            model <- fm_map$m
            # which image features mattered: the random forest's importance (also when another model was chosen)
            rf_imp <- if (MAP_MODEL == "random_forest") model else tryCatch(cls_fit("random_forest", tx, ty)$m, error = function(e) NULL)
            imp <- if (!is.null(rf_imp)) importance(rf_imp)[, 1] else numeric(0)
            imp <- sort(imp, decreasing = TRUE)[seq_len(min(15, length(imp)))]
            imp_label <- vapply(names(imp), function(nm) {
                if (grepl("^ndvi_season_", nm)) return(paste("season NDVI", sub("ndvi_season_", "", nm)))
                v <- sub("_p\\d+$", "", nm); p <- as.integer(sub(".*_p", "", nm))
                sprintf("%s, %s", toupper(v), period_label(p))
            }, "")
            crop_map <- list(classes = lapply(seq_along(class_ids), function(i) list(id = class_ids[i], name = class_names[i], trained = class_ids[i] %in% present)),
                             accuracy = cv, training = list(pixels = nrow(tx), areas = length(area_class), per_class = as.list(table(ty))),
                             importance = unname(lapply(seq_along(imp), function(i) list(feature = imp_label[[i]], value = unname(imp[i])))),
                             features = length(keep), periods = n_periods, smoothed = SMOOTH,
                             uncertain_code = length(class_ids) + 1L, min_confidence = MIN_CONFIDENCE * 100,
                             model = MAP_MODEL, model_label = CMODELS[[MAP_MODEL]]$label, comparison = unname(lapply(ccomp, function(z) { z$cv <- NULL; c(z, chosen = identical(z$model, MAP_MODEL)) })))
            # classify every site
            for (si in seq_along(sites)) {
                sd <- site_data[[si]]
                if (is.null(sd$feat)) next
                fm <- sd$feat[, keep, drop = FALSE]
                has <- rowSums(!is.na(fm)) > 0 & sd$acc$k > 0
                cls <- rep(NA_integer_, nrow(fm))
                idx <- which(has)
                for (ch in split(idx, ceiling(seq_along(idx) / 100000))) {
                    if (!length(ch)) next
                    pr <- cls_prob(fm_map, impute(fm[ch, , drop = FALSE]))
                    best <- max.col(pr, ties.method = "first")
                    code <- match(colnames(pr)[best], class_ids)
                    # pixels the forest is not sure about: a land cover without examples, or mixed
                    code[pr[cbind(seq_len(nrow(pr)), best)] < MIN_CONFIDENCE] <- length(class_ids) + 1L
                    cls[ch] <- code
                }
                r <- sd$tmpl; values(r) <- cls
                if (SMOOTH) {
                    r2 <- focal(r, w = 3, fun = "modal", na.rm = TRUE)
                    r <- mask(r2, r)
                }
                # nothing outside the selected area
                if (!all(sd$inside)) r[which(!sd$inside)] <- NA
                site_data[[si]]$map <- r
                v <- values(r, mat = FALSE)
                ha <- res(r)[1] * res(r)[2] / 10000
                site_out[[si]]$classes <- lapply(seq_along(class_ids), function(i) list(id = class_ids[i], name = class_names[i], ha = sum(v == i, na.rm = TRUE) * ha))
                site_out[[si]]$uncertain_ha <- sum(v == length(class_ids) + 1L, na.rm = TRUE) * ha
                site_out[[si]]$unclassified_ha <- sum(is.na(v) & sd$inside) * ha
                vv <- ifelse(is.na(v), 0L, as.integer(v))
                rl <- rle(vv)
                site_out[[si]]$map <- list(crs = crs(r, describe = TRUE)$code, xmin = xmin(r), ymax = ymax(r), res = res(r)[1],
                                           ncol = ncol(r), nrow = nrow(r), rle = as.vector(rbind(rl$values, rl$lengths)))
                f <- sprintf("%s.site%d.map.tif", out_base, si)
                writeRaster(r, f, datatype = "INT1U", NAflag = 0, overwrite = TRUE, gdal = c("COMPRESS=DEFLATE"))
                site_out[[si]]$map_file <- basename(f)
                say("%s: map made", sites[[si]]$name)
            }
        }
    }
}

# ---------------------------------------------------------------- yield

yield <- NULL
fields_rows <- list()
INDEX_MODE <- do_yield && identical(inp$yield$mode, "index")
# a trained model saved earlier (Breedbase analysis model): no calibration, its fit predicts the fields
SAVED_MODE <- do_yield && identical(inp$yield$mode, "saved") && !is.null(inp$yield$saved_model$file)
if (do_yield) {
    say("%s", if (INDEX_MODE) "yield: relative index (no known yields)" else if (SAVED_MODE) paste("yield: saved model", inp$yield$saved_model$name %||% "") else "yield: calibration fields")
    calib <- if (INDEX_MODE || SAVED_MODE) list() else inp$calibration %||% list()
    # fields with the same season (same images) and close together are read as
    # one window per date: trials of one location and year cost one read, not one per trial
    ring_ll <- function(r) ring_matrix(r)
    span_m <- function(m) { lat <- mean(range(m[, 2])); max(diff(range(m[, 1])) * 111320 * cos(lat * pi / 180), diff(range(m[, 2])) * 110574) }
    is_region <- vapply(calib, function(cf) identical(cf$kind, "region"), TRUE)
    key <- vapply(calib, function(cf) paste(cf$start, cf$end, paste(sort(vapply(cf$scenes %||% list(), function(x) as.character(x$id), "")), collapse = ",")), "")
    groups <- list()
    for (k in unique(key[!is_region])) {
        pending <- which(key == k & !is_region)
        while (length(pending)) {
            g <- pending[1]; pts <- ring_ll(calib[[g]]$ring)
            for (j in pending[-1]) {
                cand <- rbind(pts, ring_ll(calib[[j]]$ring))
                if (span_m(cand) <= 3000) { g <- c(g, j); pts <- cand }
            }
            pending <- setdiff(pending, g)
            groups[[length(groups) + 1]] <- g
        }
    }
    if (length(groups)) say("yield: %d calibration field(s) read in %d group(s)", sum(!is_region), length(groups))
    series_of <- lapply(calib, function(cf) data.frame(date = as.Date(character(0)), ndvi = numeric(0), ndre = numeric(0)))
    reason_of <- vector("list", length(calib))
    for (gi in seq_along(groups)) {
        g <- groups[[gi]]
        lab <- sprintf("calibration group %d/%d (%s)", gi, length(groups), paste(vapply(calib[g], function(cf) as.character(cf$name), ""), collapse = ", "))
        tmpl <- tryCatch(grid_rings(lapply(calib[g], function(cf) cf$ring)), error = function(e) NULL)
        if (is.null(tmpl)) { for (ci in g) reason_of[[ci]] <- "the field outline cannot be read"; next }
        cws <- lapply(ring_cells(lapply(calib[g], function(cf) cf$ring), tmpl), whole_pixels)
        for (j in seq_along(g)) if (!length(cws[[j]]$cells)) reason_of[[g[j]]] <- "no whole 10 m pixel inside the field (too small or too narrow)"
        roi <- unique(unlist(lapply(cws, function(x) x$cells)))
        if (!length(roi)) next
        for_scenes(calib[[g[1]]]$scenes %||% list(), tmpl, c("red", "nir", "rededge1"), roi, lab, function(r) {
            for (j in seq_along(g)) {
                if (!length(cws[[j]]$cells)) next
                a <- wmean(r$vals[, "ndvi"], cws[[j]]); b <- wmean(r$vals[, "ndre"], cws[[j]])
                if (!is.na(a[1])) series_of[[g[j]]] <<- rbind(series_of[[g[j]]], data.frame(date = r$date, ndvi = a[1], ndre = b[1]))
            }
        })
    }
    # regional items (training on municipal statistics): in each sample square the crop's pixels
    # sown in the season's window are found with the stored curve; pixels with the same sowing date
    # and cycle give one mean curve, whose season features (sowing -> end of the cycle) are averaged,
    # weighted by their pixels, over all squares of the item
    region_out <- vector("list", length(calib))
    FEATS <- c("ndvi_auc", "ndvi_max", "ndre_max", "peak_day")
    nreg <- sum(is_region)
    for (ri in seq_along(which(is_region))) {
        ci <- which(is_region)[ri]; cf <- calib[[ci]]
        sows <- seq(as.Date(cf$sow[[1]]), as.Date(cf$sow[[2]]), by = ru$sow_step_days)
        acc_f <- setNames(rep(0, length(FEATS)), FEATS); wsum <- 0; nd_sum <- 0; crop_px <- 0; px_total <- 0; sq_read <- 0
        sums <- list()
        nq <- length(cf$squares)
        for (qi in seq_len(nq)) {
            q <- cf$squares[[qi]]
            tmpl <- grid_square(as.numeric(q$center[[1]]), as.numeric(q$center[[2]]), as.numeric(q$size_m))
            nd <- list(); nr <- list(); dts <- character(0)
            for_scenes(q$scenes %||% list(), tmpl, c("red", "nir", "rededge1"), NULL,
                       sprintf("training %d/%d %s, square %d/%d", ri, nreg, cf$name, qi, nq), function(r) {
                nd[[length(nd) + 1]] <<- as.integer(round(r$vals[, "ndvi"] * 10000))
                nr[[length(nr) + 1]] <<- as.integer(round(r$vals[, "ndre"] * 10000))
                dts <<- c(dts, as.character(r$date))
            })
            if (length(nd) < ru$min_obs) next
            sq_read <- sq_read + 1
            X <- do.call(cbind, nd) / 10000; R <- do.call(cbind, nr) / 10000; dates <- as.Date(dts)
            M <- !is.na(X); X0 <- X; X0[!M] <- 0; X2 <- X0^2
            mm <- match_std(X, X0, X2, M, dates, sows)
            px_total <- px_total + nrow(X)
            cp <- which(mm$is_crop)
            crop_px <- crop_px + length(cp)
            if (!length(cp)) next
            gk <- paste(mm$sow[cp], mm$k[cp])
            for (g in unique(gk)) {
                px <- cp[gk == g]
                s0 <- as.Date(mm$sow[px[1]], origin = "1970-01-01"); kk <- mm$k[px[1]]
                clear <- colMeans(M[px, , drop = FALSE])
                a <- colMeans(X[px, , drop = FALSE], na.rm = TRUE); b <- colMeans(R[px, , drop = FALSE], na.rm = TRUE)
                keep <- clear >= MIN_FIELD_CLEAR & is.finite(a)
                series <- data.frame(date = dates[keep], ndvi = a[keep], ndre = b[keep])
                f <- season_features(series, s0, s0 + round(kk * rmax))
                if (f[["n_dates"]] < MIN_DATES || any(is.na(f[FEATS]))) next
                w <- length(px)
                acc_f <- acc_f + w * f[FEATS]; nd_sum <- nd_sum + w * f[["n_dates"]]; wsum <- wsum + w
                for (j in seq_len(nrow(series))) {
                    d <- as.character(series$date[j])
                    sums[[d]] <- (sums[[d]] %||% c(0, 0)) + c(w * series$ndvi[j], w)
                }
            }
        }
        cell_ha <- 0.01
        reason <- NULL
        if (!sq_read) reason <- "no sample square had enough clear images"
        else if (crop_px * cell_ha < MIN_CROP_HA) reason <- sprintf("only %.1f ha of %s found in its %d sample square(s) (at least %.1f ha needed)", crop_px * cell_ha, std$crop, sq_read, MIN_CROP_HA)
        else if (wsum == 0) reason <- sprintf("the %s found had too few clear dates in its season", std$crop)
        f <- if (wsum > 0) c(n_dates = round(nd_sum / wsum), acc_f / wsum) else c(n_dates = 0, ndvi_auc = NA, ndvi_max = NA, ndre_max = NA, peak_day = NA)
        ds <- sort(names(sums))
        region_out[[ci]] <- list(f = f, reason = reason, crop_ha = crop_px * cell_ha, sampled_ha = px_total * cell_ha, squares = sq_read,
                                 series = data.frame(date = as.Date(ds), ndvi = vapply(ds, function(d) sums[[d]][1] / sums[[d]][2], 0),
                                                     ndre = rep(NA_real_, length(ds))))
        say("training %d/%d %s: %.1f ha of %s in %.0f ha sampled%s", ri, nreg, cf$name, crop_px * cell_ha, std$crop, px_total * cell_ha,
            if (is.null(reason)) sprintf(", NDVI area %.1f", f[["ndvi_auc"]]) else paste0(" - not used: ", reason))
    }
    crow <- list()
    n_loc_bad <- 0
    for (ci in seq_along(calib)) {
        cf <- calib[[ci]]
        start <- as.Date(cf$start); end <- as.Date(cf$end)
        rr <- region_out[[ci]]
        if (!is.null(rr)) {
            series <- rr$series; reason <- rr$reason; f <- rr$f
        } else {
            series <- series_of[[ci]]
            reason <- reason_of[[ci]]
            f <- season_features(series, start, end)
            # a trial placed by its location's coordinates: those must fall on a crop field
            if (is.null(reason) && isTRUE(cf$check_field) && !is.na(f[["ndvi_max"]]) && f[["ndvi_max"]] < LOC_MIN_PEAK) {
                n_loc_bad <- n_loc_bad + 1
                reason <- sprintf("no field of its own, and its location's coordinates (%s: %.5f, %.5f) fall where no crop grew in its season (NDVI peak %.2f): probably the town's coordinates. Fix: put the coordinates of the field where the trial was planted on the location (Manage > Locations), or draw the trial's field",
                                  cf$location$name %||% cf$site %||% "", as.numeric(cf$location$lat %||% NA), as.numeric(cf$location$lon %||% NA), f[["ndvi_max"]])
            }
        }
        if (is.null(reason) && f[["n_dates"]] < MIN_DATES) reason <- sprintf("only %d clear date(s) in its season (at least %d needed)", f[["n_dates"]], MIN_DATES)
        if (is.null(reason) && any(is.na(f[PREDICTORS]))) reason <- "a predictor could not be computed"
        crow[[ci]] <- data.frame(id = as.character(cf$id), name = as.character(cf$name), source = as.character(cf$source), site = as.character(cf$site %||% ""),
                                 observed = as.numeric(cf$yield), start = as.character(start), end = as.character(end), t(f[c("n_dates", FEATS_ALL)]),
                                 used = is.null(reason), reason = reason %||% "", kind = as.character(cf$kind %||% "field"),
                                 field_from = as.character(cf$field_from %||% (if (identical(cf$source, "drawn")) "drawn" else "")),
                                 location = as.character(cf$location$name %||% ""), season = as.character(cf$season %||% ""), year = as.integer(cf$year %||% NA),
                                 crop_ha = if (is.null(rr)) NA_real_ else rr$crop_ha, sampled_ha = if (is.null(rr)) NA_real_ else rr$sampled_ha,
                                 planted_ha = as.numeric(cf$planted_ha %||% NA), outliers_removed = as.integer(cf$outliers_removed %||% NA),
                                 values_n = as.integer(cf$n %||% NA), stringsAsFactors = FALSE)
        crow[[ci]]$series <- list(series)
    }
    n_loc <- sum(vapply(calib, function(cf) identical(cf$field_from, "location"), TRUE))
    if (n_loc) note("calibration: %d trial(s) have no field of their own (no plot coordinates, no drawn field) and were placed by their location's coordinates%s. Many locations hold the coordinates of the town, not of the field: put the coordinates of the field where the trial was planted on the location (Manage > Locations), or draw the trial's field on the satellite page",
                    n_loc, if (n_loc_bad) sprintf("; %d of them fall where no crop grew and were left out", n_loc_bad) else "")
    cal <- if (length(crow)) do.call(rbind, crow) else NULL
    used <- if (!is.null(cal)) cal[cal$used, , drop = FALSE] else NULL
    nused <- if (is.null(used)) 0 else nrow(used)
    yield <- list(mode = if (INDEX_MODE) "index" else "calibrated",
                  trait = inp$yield$trait %||% "", unit = inp$yield$unit %||% "", per_ha = isTRUE(inp$yield$per_ha) && !INDEX_MODE,
                  season = list(start = as.character(crop_start), end = as.character(crop_end)), season_mode = SEASON_MODE,
                  season_names = as.list(setdiff(names(SEASON_NAME), c("season", "other"))), season_labels = as.list(unname(SEASON_NAME[setdiff(names(SEASON_NAME), c("season", "other"))])),
                  model = YIELD_MODEL, predictors = as.list(PREDICTORS), predictor_labels = as.list(unname(PRED_LABEL[PREDICTORS])),
                  min_fields = MIN_FIELDS, n_calibration = if (is.null(cal)) 0 else nrow(cal), n_used = nused)
    # ------------------------------------------------------------ yield models
    # complexity: with few fields the simplest model whose error is within one standard error of the best wins
    YMODELS <- list(
        linear1 = list(label = "Linear (NDVI area only)", rank = 1, min_n = 8),
        linear = list(label = "Linear regression", rank = 2, min_n = 8),
        ridge = list(label = "Ridge regression", rank = 2, min_n = 8, min_p = 2),
        pls = list(label = "PLS (1 component)", rank = 2, min_n = 8, min_p = 2),
        elastic_net = list(label = "Elastic net", rank = 3, min_n = 8, min_p = 2),
        lasso = list(label = "Lasso", rank = 3, min_n = 8, min_p = 2),
        gam = list(label = "GAM (smooth)", rank = 4, min_n = 12),
        mixed = list(label = "Mixed model (location-year effect)", rank = 4, min_n = 10, min_groups = 3),
        mars = list(label = "MARS", rank = 5, min_n = 15),
        random_forest = list(label = "Random forest", rank = 6, min_n = 20),
        svm = list(label = "SVM regression", rank = 6, min_n = 20))
    bq <- function(x) sprintf("`%s`", x)
    fit_one <- function(type, X, y, g = NULL) {
        d <- data.frame(y = y, X, check.names = FALSE)
        if (type == "linear1") return(list(type = type, cols = colnames(X)[1], m = lm(reformulate(bq(colnames(X)[1]), "y"), data = d)))
        if (type == "linear") return(list(type = type, m = lm(reformulate(bq(colnames(X)), "y"), data = d)))
        if (type %in% c("ridge", "elastic_net", "lasso")) {
            suppressPackageStartupMessages(library(glmnet))
            a <- c(ridge = 0, elastic_net = 0.5, lasso = 1)[[type]]
            return(list(type = type, cols = colnames(X), m = cv.glmnet(X, y, alpha = a, nfolds = max(3, min(10, nrow(X))), grouped = FALSE)))
        }
        if (type == "pls") { suppressPackageStartupMessages(library(pls)); return(list(type = type, m = plsr(y ~ ., data = d, ncomp = 1, scale = TRUE))) }
        if (type == "gam") {
            suppressPackageStartupMessages(library(mgcv))
            f <- as.formula(paste("y ~", paste(c(sprintf("s(%s, k = %d)", bq(colnames(X)[1]), min(4, nrow(X) - 3)), if (ncol(X) > 1) bq(colnames(X)[-1])), collapse = " + ")))
            return(list(type = type, m = gam(f, data = d)))
        }
        if (type == "mixed") {
            suppressPackageStartupMessages(library(lme4))
            d$g <- factor(g)
            return(list(type = type, m = suppressMessages(lmer(as.formula(paste("y ~", paste(bq(colnames(X)), collapse = " + "), "+ (1 | g)")), data = d, REML = TRUE))))
        }
        if (type == "mars") { suppressPackageStartupMessages(library(earth)); return(list(type = type, m = earth(X, y, degree = 1))) }
        if (type == "random_forest") { suppressPackageStartupMessages(library(randomForest)); return(list(type = type, m = randomForest(X, y, ntree = 500))) }
        if (type == "svm") { suppressPackageStartupMessages(library(e1071)); return(list(type = type, m = svm(X, y, type = "eps-regression"))) }
        stop("unknown model ", type)
    }
    pred_one <- function(fm, X) {
        d <- data.frame(X, check.names = FALSE)
        switch(fm$type,
            linear1 = , linear = as.numeric(predict(fm$m, d)),
            ridge = , elastic_net = , lasso = { suppressPackageStartupMessages(library(glmnet)); as.numeric(predict(fm$m, X[, fm$cols, drop = FALSE], s = "lambda.min")) },
            pls = { suppressPackageStartupMessages(library(pls)); as.numeric(predict(fm$m, d, ncomp = 1)) },
            gam = { suppressPackageStartupMessages(library(mgcv)); as.numeric(predict(fm$m, d)) },
            mixed = { suppressPackageStartupMessages(library(lme4)); as.numeric(predict(fm$m, d, re.form = NA)) },
            mars = { suppressPackageStartupMessages(library(earth)); as.numeric(predict(fm$m, X)) },
            random_forest = { suppressPackageStartupMessages(library(randomForest)); as.numeric(predict(fm$m, X)) },
            svm = { suppressPackageStartupMessages(library(e1071)); as.numeric(predict(fm$m, X)) },
            # models saved before the comparison existed
            stop("unknown model ", fm$type))
    }
    fit <- NULL
    z <- qnorm((1 + LEVEL) / 2)
    if (INDEX_MODE) {
        # no model: the fields are compared with each other below
    } else if (SAVED_MODE) {
        sm <- readRDS(inp$yield$saved_model$file)
        fit <- sm$fit; X <- sm$X; y <- sm$y; PREDICTORS <- sm$predictors; YIELD_MODEL <- sm$model
        rmse <- sm$metrics$rmse
        yield$model <- sm$model; yield$predictors <- as.list(PREDICTORS); yield$predictor_labels <- as.list(unname(PRED_LABEL[PREDICTORS]))
        yield$metrics <- sm$metrics; yield$coefficients <- sm$coefficients; yield$level <- LEVEL; yield$ranges <- sm$ranges
        yield$trait <- sm$trait %||% yield$trait; yield$unit <- sm$unit %||% yield$unit
        yield$saved_model <- list(id = inp$yield$saved_model$id, name = inp$yield$saved_model$name, created = sm$created, n = sm$metrics$n,
                                  crop = sm$crop, season_mode = sm$season_mode)
        if (!identical(sm$crop %||% "", inp$crop %||% "")) note("yield: the saved model was trained on %s, this run is %s", sm$crop %||% "?", inp$crop %||% "?")
        say("yield: saved model %s (R2 %.2f, %d calibration fields)", inp$yield$saved_model$name %||% "", sm$metrics$r2 %||% NA, sm$metrics$n %||% 0L)
    } else if (nused < MIN_FIELDS) {
        note("yield: %d calibration field(s) usable, at least %d are needed; no yield model", nused, MIN_FIELDS)
    } else {
        X <- as.matrix(used[, PREDICTORS, drop = FALSE]); y <- used$observed
        # groups: location and year of each calibration field; >= 3 -> leave one location-year out
        grp <- paste(ifelse(nzchar(used$site), used$site, used$name), substr(used$start, 1, 4))
        by_group <- length(unique(grp)) >= 3 && length(unique(grp)) < nused
        folds <- if (by_group) as.integer(factor(grp)) else seq_len(nused)
        cv_label <- if (by_group) sprintf("leave one location-year out (%d groups)", length(unique(grp))) else "leave one field out"
        cands <- if (YIELD_MODEL == "auto") names(YMODELS) else YIELD_MODEL
        cands <- Filter(function(k) { m <- YMODELS[[k]]; is.null(m) || (nused >= (m$min_n %||% 0) && ncol(X) >= (m$min_p %||% 1) &&
                        length(unique(grp)) >= (m$min_groups %||% 0)) }, cands)
        if (!length(cands)) cands <- "linear1"
        say("yield: comparing %d model(s) by %s on %d fields: %s", length(cands), cv_label, nused, paste(cands, collapse = ", "))
        comp <- list(); cvpred <- list()
        for (k in cands) {
            pr <- tryCatch({
                vapply(seq_len(nused), function(i) NA_real_, 0) -> out
                for (f in unique(folds)) {
                    te <- folds == f
                    fm <- fit_one(k, X[!te, , drop = FALSE], y[!te], grp[!te])
                    out[te] <- pred_one(fm, X[te, , drop = FALSE])
                }
                out
            }, error = function(e) { say("yield: %s failed (%s)", k, conditionMessage(e)); NULL })
            if (is.null(pr) || any(!is.finite(pr))) { comp[[k]] <- list(model = k, label = YMODELS[[k]]$label %||% k, failed = TRUE); next }
            e <- pr - y
            rm <- sqrt(mean(e^2))
            comp[[k]] <- list(model = k, label = YMODELS[[k]]$label %||% k, rank = YMODELS[[k]]$rank %||% 9, rmse = rm, mae = mean(abs(e)), bias = mean(e),
                              r2 = 1 - sum(e^2) / sum((y - mean(y))^2), se = sd(e^2) / (2 * max(rm, 1e-9) * sqrt(nused)), failed = FALSE)
            cvpred[[k]] <- pr
        }
        okm <- Filter(function(z) !isTRUE(z$failed), comp)
        if (!length(okm)) stop("no yield model could be fitted")
        best <- okm[[which.min(vapply(okm, function(z) z$rmse, 0))]]
        within <- Filter(function(z) z$rmse <= best$rmse + best$se, okm)
        chosen <- within[[order(vapply(within, function(z) z$rank, 0), vapply(within, function(z) z$rmse, 0))[1]]]
        YIELD_MODEL <- chosen$model
        loo <- cvpred[[YIELD_MODEL]]
        err <- loo - y
        rmse <- chosen$rmse; mae <- chosen$mae; r2 <- chosen$r2
        yield$model <- YIELD_MODEL
        yield$comparison <- unname(lapply(comp, function(z) c(z, chosen = identical(z$model, YIELD_MODEL))))
        yield$selection <- list(cv = cv_label, rule = if (length(cands) > 1) sprintf("lowest error: %s (RMSE %.3g); chosen: the simplest model within one standard error of it", best$label, best$rmse) else "the model chosen in the settings",
                                auto = YIELD_MODEL != "" && length(cands) > 1)
        say("yield: chosen %s (CV RMSE %.3g, R2 %.2f)", chosen$label, rmse, r2)
        fit <- fit_one(YIELD_MODEL, X, y, grp)
        coefs <- NULL
        if (fit$type %in% c("linear", "linear1")) {
            cf <- summary(fit$m)$coefficients
            coefs <- lapply(seq_len(nrow(cf)), function(i) list(term = gsub("`", "", rownames(cf)[i]), estimate = cf[i, 1], se = cf[i, 2], p = cf[i, 4]))
        } else if (fit$type %in% c("lasso", "ridge", "elastic_net")) {
            b <- as.matrix(coef(fit$m, s = "lambda.min"))
            coefs <- lapply(seq_len(nrow(b)), function(i) list(term = rownames(b)[i], estimate = b[i, 1]))
            coefs <- Filter(function(x) x$term != ".const", coefs)
        }
        cal$loo <- NA_real_; cal$loo[cal$used] <- loo
        yield$metrics <- list(r2 = r2, rmse = rmse, mae = mae, bias = mean(err), n = nused, observed_mean = mean(y), cv = cv_label)
        yield$predictor_labels <- as.list(unname(PRED_LABEL[if (YIELD_MODEL == "linear1") PREDICTORS[1] else PREDICTORS]))
        yield$coefficients <- coefs
        yield$level <- LEVEL
        yield$ranges <- lapply(PREDICTORS, function(p) list(predictor = p, min = min(X[, p]), max = max(X[, p])))
        say("yield: %s R2 %.2f, RMSE %.3g (%d fields)", cv_label, r2, rmse, nused)
        # the trained model, to save as a Breedbase analysis model and use again without calibrating
        saveRDS(list(fit = fit, X = X, y = y, predictors = PREDICTORS, model = YIELD_MODEL, metrics = yield$metrics, coefficients = coefs,
                     ranges = yield$ranges, level = LEVEL, trait = yield$trait, unit = yield$unit, crop = inp$crop, season_mode = SEASON_MODE,
                     calibration = lapply(seq_len(nrow(used)), function(i) list(name = used$name[i], source = used$source[i], observed = used$observed[i], start = used$start[i], end = used$end[i])),
                     created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), R = R.version.string),
                paste0(out_base, ".model.rds"))
        yield$model_file <- basename(paste0(out_base, ".model.rds"))
    }
    if (!is.null(fit)) {
        predict_target <- function(f) {
            x <- matrix(f[PREDICTORS], nrow = 1, dimnames = list(NULL, PREDICTORS))
            est <- pred_one(fit, x)
            if (fit$type %in% c("linear", "linear1")) {
                pi <- predict(fit$m, data.frame(x, check.names = FALSE), interval = "prediction", level = LEVEL)
                lo <- pi[1, "lwr"]; hi <- pi[1, "upr"]
            } else { lo <- est - z * rmse; hi <- est + z * rmse }
            # a yield is not negative (when no calibration yield is)
            if (all(y >= 0)) { lo <- max(0, lo); est <- max(0, est) }
            rg <- vapply(PREDICTORS, function(p) { a <- min(X[, p]); b <- max(X[, p]); w <- 0.1 * (b - a); x[1, p] < a - w || x[1, p] > b + w }, TRUE)
            list(estimate = est, lower = lo, upper = hi, extrapolation = any(rg))
        }
    }
    yield$calibration <- if (is.null(cal)) list() else lapply(seq_len(nrow(cal)), function(i) {
        r <- cal[i, ]
        list(id = r$id, name = r$name, source = r$source, site = r$site, observed = r$observed, start = r$start, end = r$end,
             kind = r$kind, field_from = r$field_from, location = r$location, season = r$season, year = r$year,
             crop_ha = r$crop_ha, sampled_ha = r$sampled_ha, planted_ha = r$planted_ha, outliers_removed = r$outliers_removed, values_n = r$values_n,
             n_dates = r$n_dates, ndvi_auc = r$ndvi_auc, ndvi_max = r$ndvi_max, ndre_max = r$ndre_max, peak_day = r$peak_day,
             used = r$used, reason = r$reason, loo = if ("loo" %in% names(cal)) r$loo else NA,
             series = list(date = as.character(r$series[[1]]$date), ndvi = r$series[[1]]$ndvi))
    })

    # fields to estimate: drawn ones, and the crop's areas on the map
    say("yield: fields to estimate")
    targets_out <- list()
    for (si in seq_along(sites)) {
        s <- sites[[si]]; sd <- site_data[[si]]
        if (is.null(sd$tmpl)) next
        cfg_si <- SITE_SEASONS[[si]] %||% list()
        n_map_series <- 0
        add_target <- function(id, name, source, series, ha) {
            ss <- detect_seasons(series, cfg_si)
            one <- function(start, end, season, suffix) {
                f <- season_features(series, as.Date(start), as.Date(end))
                t <- list(id = paste0(id, suffix), name = paste0(name, if (nzchar(suffix)) paste0(" - ", SEASON_NAME[[season$label]], " ", season$year) else ""),
                          field = name, source = source, site = s$name, site_id = s$id, area_ha = ha, n_dates = f[["n_dates"]],
                          ndvi_auc = f[["ndvi_auc"]], ndvi_max = f[["ndvi_max"]], ndre_max = f[["ndre_max"]], peak_day = f[["peak_day"]],
                          season = season, seasons = ss, season_start = as.character(start), season_end = as.character(end),
                          series = if (source != "map" || n_map_series < 15) list(date = as.character(series$date), ndvi = round(series$ndvi, 4), ndre = round(series$ndre, 4)) else NULL)
                if (!is.null(fit) && f[["n_dates"]] >= MIN_DATES && !any(is.na(f[PREDICTORS]))) t <- c(t, predict_target(f))
                else if (!is.null(fit)) t$reason <- if (f[["n_dates"]] < MIN_DATES) sprintf("only %d clear date(s)", f[["n_dates"]]) else "a predictor could not be computed"
                targets_out[[length(targets_out) + 1]] <<- t
            }
            if (SEASON_MODE == "dates") { one(crop_start, crop_end, NULL, ""); return(invisible()) }
            pick <- Filter(function(z) SEASON_MODE == "detected" || z$label == SEASON_MODE, ss)
            if (!length(pick)) {
                targets_out[[length(targets_out) + 1]] <<- list(id = id, name = name, field = name, source = source, site = s$name, site_id = s$id, area_ha = ha,
                    n_dates = sum(!is.na(series$ndvi)), seasons = ss,
                    series = list(date = as.character(series$date), ndvi = round(series$ndvi, 4), ndre = round(series$ndre, 4)),
                    reason = if (!length(ss)) "no crop season found (no green-up from bare soil)"
                             else if (!SEASON_MODE %in% names(cfg_si)) sprintf("the %s season applies only to %s locations", SEASON_MODE, paste(names(SEASONS_DEF$countries), collapse = ", "))
                             else sprintf("no %s in the period", SEASON_NAME[[SEASON_MODE]] %||% "season"))
                return(invisible())
            }
            for (z in seq_along(pick)) one(pick[[z]]$start, pick[[z]]$end, pick[[z]], paste0("_s", z))
        }
        targets <- s$targets %||% list()
        ci_map <- match(crop_class, class_ids)
        for (k in seq_along(targets)) {
            m <- ring_matrix(targets[[k]]$ring)
            if (!length(sd$tcw[[k]]$cells)) {
                targets_out[[length(targets_out) + 1]] <- list(id = as.character(targets[[k]]$id), name = targets[[k]]$name, field = targets[[k]]$name, source = "drawn",
                    site = s$name, site_id = s$id, area_ha = area_ha_ring(m), n_dates = 0L,
                    reason = "no whole 10 m pixel inside the field (too small or too narrow): not estimated, so nothing outside it is used")
                next
            }
            add_target(as.character(targets[[k]]$id), targets[[k]]$name, "drawn", sd$tseries[[k]], area_ha_ring(m))
            # how much of the field the crop map found as the crop
            if (!is.null(sd$map) && !is.na(ci_map) && length(sd$tcw) >= k && length(sd$tcw[[k]]$cells)) {
                cw <- sd$tcw[[k]]; v <- values(sd$map, mat = FALSE)[cw$cells]
                targets_out[[length(targets_out)]]$map_crop_share <- sum(cw$w[!is.na(v) & v == ci_map]) / sum(cw$w)
            }
        }
        # the crop's areas found by the map: only when asked (by default when no field was delimited)
        if (need_maps && !is.null(sd$map) && isTRUE(inp$yield$map_areas %||% (length(targets) == 0))) {
            ci <- match(crop_class, class_ids)
            crop <- sd$map == ci
            crop[crop == 0] <- NA
            pt <- patches(crop, directions = 8, zeroAsNA = TRUE)
            pv <- values(pt, mat = FALSE)
            tab <- table(pv)
            cell_ha <- res(pt)[1] * res(pt)[2] / 10000
            big <- as.integer(names(tab)[tab * cell_ha >= MIN_PATCH_HA])
            small_ha <- sum(tab[tab * cell_ha < MIN_PATCH_HA]) * cell_ha
            if (small_ha > 0) site_out[[si]]$crop_small_ha <- small_ha
            if (length(big)) {
                nd <- do.call(cbind, sd$ndvi) / 10000; ne <- do.call(cbind, sd$ndre) / 10000
                big <- big[order(-tab[as.character(big)])]
                for (j in seq_along(big)) {
                    cells <- which(pv == big[j])
                    a <- colMeans(nd[cells, , drop = FALSE], na.rm = TRUE)
                    share <- colMeans(!is.na(nd[cells, , drop = FALSE]))
                    b <- colMeans(ne[cells, , drop = FALSE], na.rm = TRUE)
                    keep <- share >= MIN_FIELD_CLEAR
                    series <- data.frame(date = sd$dates[keep], ndvi = a[keep], ndre = b[keep])
                    add_target(sprintf("map_%d_%d", si, j), sprintf("%s area %d", class_names[ci], j), "map", series, length(cells) * cell_ha)
                    n_map_series <- n_map_series + 1
                }
            }
            say("%s: %d %s area(s) of at least %.1f ha", s$name, length(big), class_names[ci], MIN_PATCH_HA)
        }
    }
    if (INDEX_MODE) {
        # relative yield index: NDVI area under the season curve, 100 = mean of the fields with enough clear dates
        ok <- vapply(targets_out, function(t) !is.null(t$ndvi_auc) && !is.na(t$ndvi_auc) && t$n_dates >= MIN_DATES, TRUE)
        # fields are compared within the same kind of season (a second crop is not compared with a main season)
        lab <- vapply(targets_out, function(t) if (is.null(t$season)) "" else t$season$label, "")
        mean_of <- vapply(lab, function(L) { w <- ok & lab == L; if (any(w)) mean(vapply(targets_out[w], function(t) t$ndvi_auc, 0)) else NA_real_ }, 0)
        m <- if (any(ok)) mean(vapply(targets_out[ok], function(t) t$ndvi_auc, 0)) else NA
        idx <- vapply(seq_along(targets_out), function(i) if (ok[i] && !is.na(mean_of[i]) && mean_of[i] > 0) 100 * targets_out[[i]]$ndvi_auc / mean_of[i] else NA_real_, 0)
        rk <- rank(-idx, na.last = "keep", ties.method = "min")
        for (L in unique(lab[ok])) if (sum(ok & lab == L) == 1) {
            note("yield index: only one field%s - its index is 100 by definition (an index compares fields with each other)%s",
                 if (nzchar(L)) paste0(" in the ", SEASON_NAME[[L]]) else "", if (isTRUE(inp$yield$reference)) ", so its kg/ha is simply the regional average" else "")
        }
        for (i in seq_along(targets_out)) {
            targets_out[[i]]$index <- idx[i]
            targets_out[[i]]$rank <- if (is.na(rk[i])) NA else as.integer(rk[i])
            if (!ok[i] && is.null(targets_out[[i]]$reason)) targets_out[[i]]$reason <- sprintf("only %d clear date(s)", targets_out[[i]]$n_dates)
        }
        # approximate kg/ha from the public average yield of the region (IBGE PAM / FAOSTAT):
        # the fields sharing a reference are assumed to average like that region
        if (isTRUE(inp$yield$reference)) {
            ref_of <- lapply(sites, function(s) s$reference)
            key_of <- vapply(ref_of, function(r) if (is.null(r) || !is.null(r$error) || is.null(r$value)) "" else paste(r$source, r$level, r$area), "")
            site_key <- setNames(key_of, vapply(sites, function(s) as.character(s$id), ""))
            refs_out <- list()
            for (k in setdiff(unique(key_of), "")) {
                r <- ref_of[[match(k, key_of)]]
                members <- which(vapply(targets_out, function(t) identical(site_key[[as.character(t$site_id)]], k), TRUE) & ok)
                if (!length(members)) next
                for (i in members) {
                    same <- members[lab[members] == lab[i]]
                    m_k <- mean(vapply(targets_out[same], function(t) t$ndvi_auc, 0))
                    targets_out[[i]]$estimate <- as.numeric(r$value) * targets_out[[i]]$ndvi_auc / m_k
                    targets_out[[i]]$estimate_basis <- "regional"
                }
                refs_out[[length(refs_out) + 1]] <- c(r[c("source", "level", "area", "crop", "unit", "value", "basis", "url", "citation")],
                    list(years = r$years, fields = length(members), sites = as.list(unname(vapply(sites[key_of == k], function(s) s$name, "")))))
            }
            for (si in which(key_of == "")) {
                e <- sites[[si]]$reference$error %||% "no reference"
                note("yield: no regional average yield for %s (%s); its fields keep the index only", sites[[si]]$name, e)
            }
            yield$references <- refs_out
            if (length(refs_out)) {
                yield$unit <- "kg/ha"
                yield$per_ha <- TRUE
                note("yield: kg/ha are approximate - the regional average yield (%s) scaled by each field's season curve, assuming the fields average like the region; not a calibration, the error is unknown",
                     paste(unique(vapply(refs_out, function(r) r$source, "")), collapse = ", "))
            }
        }
        yield$index_basis <- "NDVI area under the season curve"
        yield$index_mean_auc <- m
        yield$n_indexed <- sum(ok)
        say("yield index: %d field(s) compared", sum(ok))
        tot <- list()
        for (si in seq_along(sites)) {
            ts <- Filter(function(t) identical(t$site_id, sites[[si]]$id) && !is.na(t$index), targets_out)
            ha <- sum(vapply(ts, function(t) t$area_ha, 0))
            te <- Filter(function(t) !is.null(t$estimate), ts)
            hae <- sum(vapply(te, function(t) t$area_ha, 0))
            tot[[si]] <- list(site = sites[[si]]$name, site_id = sites[[si]]$id, fields = length(ts), area_ha = ha,
                              mean_index = if (ha > 0) sum(vapply(ts, function(t) t$index * t$area_ha, 0)) / ha else NA,
                              mean_yield = if (hae > 0) sum(vapply(te, function(t) t$estimate * t$area_ha, 0)) / hae else NA,
                              production = if (hae > 0) sum(vapply(te, function(t) t$estimate * t$area_ha, 0)) else NA)
        }
        yield$totals <- tot
    }
    yield$targets <- targets_out
    # totals per location and season
    labs_all <- unique(unlist(lapply(targets_out, function(t) if (is.null(t$season)) NULL else t$season$label)))
    if (length(labs_all)) {
        tbs <- list()
        for (si in seq_along(sites)) for (L in labs_all) {
            ts <- Filter(function(t) identical(t$site_id, sites[[si]]$id) && !is.null(t$season) && t$season$label == L, targets_out)
            if (!length(ts)) next
            ha_s <- sum(vapply(ts, function(t) t$area_ha, 0))
            te <- Filter(function(t) !is.null(t$estimate) && !is.na(t$estimate), ts)
            hae <- sum(vapply(te, function(t) t$area_ha, 0))
            ti <- Filter(function(t) !is.null(t$index) && !is.na(t$index), ts)
            hai <- sum(vapply(ti, function(t) t$area_ha, 0))
            tbs[[length(tbs) + 1]] <- list(site = sites[[si]]$name, site_id = sites[[si]]$id, season = L, season_label = SEASON_NAME[[L]] %||% L,
                fields = length(ts), area_ha = ha_s,
                mean_index = if (hai > 0) sum(vapply(ti, function(t) t$index * t$area_ha, 0)) / hai else NA,
                mean_yield = if (hae > 0) sum(vapply(te, function(t) t$estimate * t$area_ha, 0)) / hae else NA,
                production = if (hae > 0) sum(vapply(te, function(t) t$estimate * t$area_ha, 0)) else NA)
        }
        yield$totals_by_season <- tbs
    }
    if (!is.null(fit)) {
        tot <- list()
        for (si in seq_along(sites)) {
            ts <- Filter(function(t) identical(t$site_id, sites[[si]]$id) && !is.null(t$estimate), targets_out)
            ha <- sum(vapply(ts, function(t) t$area_ha, 0))
            prod <- if (yield$per_ha) sum(vapply(ts, function(t) t$estimate * t$area_ha, 0)) else NA
            tot[[si]] <- list(site = sites[[si]]$name, site_id = sites[[si]]$id, fields = length(ts), area_ha = ha,
                              production = prod, mean_yield = if (ha > 0) sum(vapply(ts, function(t) t$estimate * t$area_ha, 0)) / ha else NA)
        }
        yield$totals <- tot
    }
    for (t in targets_out) {
        z <- t$season
        fields_rows[[length(fields_rows) + 1]] <- data.frame(site = t$site, field = t$name, source = t$source, area_ha = round(t$area_ha, 3),
            season = if (is.null(z)) "" else SEASON_NAME[[z$label]], bare_until = z$bare_until %||% "", peak_date = z$peak_date %||% "",
            harvest_between = if (is.null(z)) "" else if (isTRUE(z$harvested)) paste(if (identical(z$end_type, "dry-down")) "dried down (no sharp harvest) between" else "harvested between", z$last_green, "and", z$bare_again) else "not harvested (green at the end)",
            clear_dates = t$n_dates %||% NA, ndvi_auc = t$ndvi_auc %||% NA, ndvi_peak = t$ndvi_max %||% NA, ndre_peak = t$ndre_max %||% NA,
            estimate = t$estimate %||% NA, lower = t$lower %||% NA, upper = t$upper %||% NA, extrapolation = t$extrapolation %||% NA,
            yield_index = t$index %||% NA, rank = t$rank %||% NA, note = t$reason %||% "")
    }
}

# ---------------------------------------------------------------- indices per plot

indices <- NULL
if (do_indices) {
    all <- list()
    for (si in seq_along(sites)) {
        p <- site_data[[si]]$plots
        if (is.null(p) || !nrow(p)) next
        p$trial_id <- sites[[si]]$plots$trial_id
        p$trial_name <- sites[[si]]$plots$trial_name %||% ""
        all[[length(all) + 1]] <- p
        site_out[[si]]$indices <- list(trial_id = sites[[si]]$plots$trial_id, trial_name = sites[[si]]$plots$trial_name %||% "",
                                        plots = length(unique(p$plot_id)), dates = length(unique(p$date)), values = nrow(p))
    }
    if (length(all)) {
        ind <- do.call(rbind, all)
        write.csv(ind[, c("trial_id", "trial_name", "plot_id", "plot_name", "date", "ndvi", "ndre", "evi", "clear_pct")], paste0(out_base, ".indices.csv"), row.names = FALSE)
        indices <- list(file = basename(paste0(out_base, ".indices.csv")), values = nrow(ind))
    } else {
        note("indices: no plot had a clear date")
    }
}

# ---------------------------------------------------------------- output

if (length(fields_rows)) write.csv(do.call(rbind, fields_rows), paste0(out_base, ".fields.csv"), row.names = FALSE)
results <- list(
    version = "1.0", created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), seconds = as.numeric(difftime(Sys.time(), t_start, units = "secs")),
    dates = inp$dates, crop = inp$crop, crop_class = crop_class, settings = list(
        min_scene_clear = MIN_SCENE_CLEAR * 100, min_confidence = MIN_CONFIDENCE * 100, min_field_clear = MIN_FIELD_CLEAR * 100, period_days = PERIOD_DAYS, ntree = NTREE,
        pixels_per_area = PX_PER_AREA, cv_folds = CV_FOLDS, min_patch_ha = MIN_PATCH_HA, smooth = SMOOTH, balance = BALANCE,
        yield_model = YIELD_MODEL, predictors = as.list(PREDICTORS), min_dates = MIN_DATES, min_fields = MIN_FIELDS, level = LEVEL * 100),
    train = isTRUE(inp$train), calibration_skipped = inp$calibration_skipped %||% list(),
    models = inp$models, sites = site_out, crop_map = crop_map, yield = yield, indices = indices,
    fields_file = if (length(fields_rows)) basename(paste0(out_base, ".fields.csv")) else NULL,
    notes = as.list(notes), software = list(R = R.version.string, terra = as.character(packageVersion("terra")),
        randomForest = if (do_map) as.character(packageVersion("randomForest")) else NULL, GDAL = gdal()))
writeLines(toJSON(results, auto_unbox = TRUE, null = "null", na = "null", digits = NA), paste0(out_base, ".results.json"))
say("done in %.0f s", as.numeric(difftime(Sys.time(), t_start, units = "secs")))
