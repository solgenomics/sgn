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
say <- function(...) { cat("[satellite] ", sprintf(...), "\n", sep = ""); flush(stdout()) }
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
YIELD_MODEL <- st$yield_model %||% "linear"
PREDICTORS <- unlist(st$predictors %||% list("ndvi_auc", "ndre_max"))
MIN_DATES <- max(1, num(st$min_dates, 4))
MIN_FIELDS <- max(3, num(st$min_fields, 8))
LEVEL <- min(0.99, max(0.5, num(st$level, 90) / 100))
SOIL_NDVI <- 0.2
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
    batches <- split(seq_len(n), ceiling(seq_len(n) / CORES))
    done <- 0
    for (b in batches) {
        rs <- mclapply(scenes[b], read_scene, tmpl = tmpl, bands = bands, roi = roi, mc.cores = CORES, mc.preschedule = FALSE)
        for (r in rs) {
            if (inherits(r, "try-error")) { failed <- failed + 1; errs <- c(errs, as.character(r)); next }
            if (!is.null(r$error)) { failed <- failed + 1; errs <- c(errs, r$error); next }
            if (!is.null(r$skipped)) { skipped <- skipped + 1; next }
            used <- used + 1
            fun(r)
        }
        done <- done + length(b)
        say("%s: %d/%d dates read", label, done, n)
    }
    if (failed) note("%s: %d date(s) could not be read (%s)", label, failed, paste(unique(head(errs, 3)), collapse = "; "))
    invisible(list(used = used, skipped = skipped, failed = failed))
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

    tcw <- if (want_targets) ring_cells(lapply(targets, function(t) t$ring), tmpl) else list()
    pcw <- if (want_plots) ring_cells(lapply(plots, function(p) p$ring), tmpl) else list()
    acc <- NULL
    if (do_map && !STANDARD) {
        acc <- list(sum = array(0, c(n, length(VARS), n_periods)), cnt = array(0L, c(n, length(VARS), n_periods)),
                    mx = rep(-Inf, n), mn = rep(Inf, n), s1 = numeric(n), s2 = numeric(n), k = integer(n))
    }
    ndvi_dates <- list(); ndre_dates <- list(); dates_used <- character(0)
    tseries <- lapply(targets, function(t) data.frame(date = as.Date(character(0)), ndvi = numeric(0), ndre = numeric(0)))
    prows <- list()

    stats <- for_scenes(s$scenes, tmpl, bands, NULL, label, function(r) {
        m <- r$vals
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
    site_out[[si]] <- list(id = s$id, name = s$name, dates_found = length(s$scenes), dates_hidden = as.integer(s$hidden %||% 0), dates_used = stats$used,
                           dates_cloudy = stats$skipped, dates_failed = stats$failed, size_m = s$size_m)
    site_data[[si]] <- list(tmpl = tmpl, acc = acc, ndvi = ndvi_dates, ndre = ndre_dates, dates = as.Date(dates_used),
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
if (STANDARD) {
    # ------------------------------------------------------------ the stored crop curve
    sfile <- grep("^--file=", commandArgs(FALSE), value = TRUE)
    script_dir <- if (length(sfile)) dirname(normalizePath(sub("^--file=", "", sfile[1]))) else "R/satellite"
    stdf <- file.path(script_dir, "standards", paste0(inp$standard %||% "maize", ".json"))
    std <- fromJSON(stdf)
    ru <- std$rules
    say("crop map: matching every pixel to the %s standard curve (%s)", std$crop, basename(stdf))
    tmpl_at <- function(das) approx(std$das, std$ndvi, das, rule = 2)$y
    rmax <- max(std$das)
    ph <- std$phases
    for (si in seq_along(sites)) {
        sd <- site_data[[si]]
        if (is.null(sd$tmpl) || !length(sd$ndvi)) next
        X <- do.call(cbind, sd$ndvi) / 10000
        dates <- sd$dates
        M <- !is.na(X); X0 <- X; X0[!M] <- 0; X2 <- X0^2
        N <- nrow(X)
        best <- rep(-Inf, N); b_r <- rep(NA_real_, N); b_rmse <- rep(NA_real_, N); b_sow <- rep(NA_real_, N); b_k <- rep(NA_real_, N); covered <- rep(FALSE, N)
        sows <- seq(season_start - 60, season_end - 60, by = ru$sow_step_days)
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
            if (any(up)) {
                best[up] <- score[up]; b_r[up] <- r[up]; b_rmse[up] <- rmse[up]; b_sow[up] <- as.numeric(s0); b_k[up] <- k
            }
        }
        peak <- suppressWarnings(apply(X, 1, max, na.rm = TRUE)); peak[!is.finite(peak)] <- NA
        is_crop <- covered & !is.na(b_r) & b_r >= ru$min_r & b_rmse <= ru$max_rmse & !is.na(peak) & peak >= ru$min_peak
        code <- ifelse(!covered, 3L, ifelse(is_crop, 1L, 2L))
        r <- sd$tmpl; values(r) <- code
        if (SMOOTH) { r2 <- focal(r, w = 3, fun = "modal", na.rm = TRUE); r <- r2 }
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
                     accuracy = NULL, uncertain_code = 3L, min_confidence = NA, smoothed = SMOOTH)
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
            rf_fit <- function(x, y) {
                y <- droplevels(y)
                if (BALANCE) randomForest(x, y, ntree = NTREE, strata = y, sampsize = rep(min(table(y)), nlevels(y)))
                else randomForest(x, y, ntree = NTREE)
            }
            # cross-validation by drawn area
            area_class <- tapply(train$class, train$area, function(x) x[1])
            per_class <- table(area_class)
            k <- min(CV_FOLDS, min(per_class[present]))
            cv <- NULL
            if (k >= 2) {
                fold <- setNames(integer(length(area_class)), names(area_class))
                for (cl in present) {
                    a <- names(area_class)[area_class == cl]
                    fold[a] <- sample(rep_len(seq_len(k), length(a)))
                }
                pred <- factor(rep(NA, nrow(train)), levels = present)
                for (f in seq_len(k)) {
                    test <- fold[train$area] == f
                    if (length(unique(ty[!test])) < 2) next
                    m <- rf_fit(tx[!test, , drop = FALSE], ty[!test])
                    pred[test] <- as.character(predict(m, tx[test, , drop = FALSE]))
                }
                ok <- !is.na(pred)
                cm <- table(observed = factor(ty[ok], levels = present), predicted = factor(pred[ok], levels = present))
                oa <- sum(diag(cm)) / sum(cm)
                pe <- sum(rowSums(cm) * colSums(cm)) / sum(cm)^2
                cv <- list(folds = k, pixels = sum(cm), overall = oa, kappa = if (pe < 1) (oa - pe) / (1 - pe) else NA,
                           classes = present, matrix = unname(lapply(seq_len(nrow(cm)), function(i) as.integer(cm[i, ]))),
                           producer = unname(diag(cm) / pmax(rowSums(cm), 1)), user = unname(diag(cm) / pmax(colSums(cm), 1)))
                say("crop map: cross-validated accuracy %.1f%% (%d folds by drawn area)", 100 * oa, k)
            } else {
                note("crop map: accuracy not measured - draw at least 2 example areas of each class")
            }
            say("crop map: training the random forest on %d pixels of %d areas", nrow(tx), length(area_class))
            model <- rf_fit(tx, ty)
            imp <- importance(model)[, 1]
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
                             uncertain_code = length(class_ids) + 1L, min_confidence = MIN_CONFIDENCE * 100)
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
                    pr <- predict(model, impute(fm[ch, , drop = FALSE]), type = "prob")
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
                site_data[[si]]$map <- r
                v <- values(r, mat = FALSE)
                ha <- res(r)[1] * res(r)[2] / 10000
                site_out[[si]]$classes <- lapply(seq_along(class_ids), function(i) list(id = class_ids[i], name = class_names[i], ha = sum(v == i, na.rm = TRUE) * ha))
                site_out[[si]]$uncertain_ha <- sum(v == length(class_ids) + 1L, na.rm = TRUE) * ha
                site_out[[si]]$unclassified_ha <- sum(is.na(v)) * ha
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
if (do_yield) {
    say(if (INDEX_MODE) "yield: relative index (no known yields)" else "yield: calibration fields")
    calib <- if (INDEX_MODE) list() else inp$calibration %||% list()
    # fields with the same season (same images) and close together are read as
    # one window per date: trials of one location and year cost one read, not one per trial
    ring_ll <- function(r) ring_matrix(r)
    span_m <- function(m) { lat <- mean(range(m[, 2])); max(diff(range(m[, 1])) * 111320 * cos(lat * pi / 180), diff(range(m[, 2])) * 110574) }
    key <- vapply(calib, function(cf) paste(cf$start, cf$end, paste(sort(vapply(cf$scenes %||% list(), function(x) as.character(x$id), "")), collapse = ",")), "")
    groups <- list()
    for (k in unique(key)) {
        pending <- which(key == k)
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
    say("yield: %d calibration field(s) read in %d group(s)", length(calib), length(groups))
    series_of <- lapply(calib, function(cf) data.frame(date = as.Date(character(0)), ndvi = numeric(0), ndre = numeric(0)))
    reason_of <- vector("list", length(calib))
    for (gi in seq_along(groups)) {
        g <- groups[[gi]]
        lab <- sprintf("calibration group %d/%d (%s)", gi, length(groups), paste(vapply(calib[g], function(cf) as.character(cf$name), ""), collapse = ", "))
        tmpl <- tryCatch(grid_rings(lapply(calib[g], function(cf) cf$ring)), error = function(e) NULL)
        if (is.null(tmpl)) { for (ci in g) reason_of[[ci]] <- "the field outline cannot be read"; next }
        cws <- ring_cells(lapply(calib[g], function(cf) cf$ring), tmpl)
        for (j in seq_along(g)) if (!length(cws[[j]]$cells)) reason_of[[g[j]]] <- "the field is smaller than one pixel"
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
    crow <- list()
    for (ci in seq_along(calib)) {
        cf <- calib[[ci]]
        start <- as.Date(cf$start); end <- as.Date(cf$end)
        series <- series_of[[ci]]
        reason <- reason_of[[ci]]
        f <- season_features(series, start, end)
        if (is.null(reason) && f[["n_dates"]] < MIN_DATES) reason <- sprintf("only %d clear date(s) in its season (at least %d needed)", f[["n_dates"]], MIN_DATES)
        if (is.null(reason) && any(is.na(f[PREDICTORS]))) reason <- "a predictor could not be computed"
        crow[[ci]] <- data.frame(id = as.character(cf$id), name = as.character(cf$name), source = as.character(cf$source), site = as.character(cf$site %||% ""),
                                 observed = as.numeric(cf$yield), start = as.character(start), end = as.character(end), t(f),
                                 used = is.null(reason), reason = reason %||% "", stringsAsFactors = FALSE)
        crow[[ci]]$series <- list(series)
    }
    cal <- if (length(crow)) do.call(rbind, crow) else NULL
    used <- if (!is.null(cal)) cal[cal$used, , drop = FALSE] else NULL
    nused <- if (is.null(used)) 0 else nrow(used)
    yield <- list(mode = if (INDEX_MODE) "index" else "calibrated",
                  trait = inp$yield$trait %||% "", unit = inp$yield$unit %||% "", per_ha = isTRUE(inp$yield$per_ha) && !INDEX_MODE,
                  season = list(start = as.character(crop_start), end = as.character(crop_end)),
                  model = YIELD_MODEL, predictors = as.list(PREDICTORS), predictor_labels = as.list(unname(PRED_LABEL[PREDICTORS])),
                  min_fields = MIN_FIELDS, n_calibration = if (is.null(cal)) 0 else nrow(cal), n_used = nused)
    fit <- NULL
    if (INDEX_MODE) {
        # no model: the fields are compared with each other below
    } else if (nused < MIN_FIELDS) {
        note("yield: %d calibration field(s) usable, at least %d are needed; no yield model", nused, MIN_FIELDS)
    } else {
        X <- as.matrix(used[, PREDICTORS, drop = FALSE]); y <- used$observed
        fit_one <- function(X, y) {
            if (YIELD_MODEL == "lasso") {
                suppressPackageStartupMessages(library(glmnet))
                if (ncol(X) < 2) X <- cbind(X, .const = 0)
                m <- cv.glmnet(X, y, alpha = 1, nfolds = min(10, nrow(X)), grouped = FALSE)
                list(type = "lasso", m = m, cols = colnames(X))
            } else if (YIELD_MODEL == "random_forest") {
                suppressPackageStartupMessages(library(randomForest))
                list(type = "random_forest", m = randomForest(X, y, ntree = 500))
            } else {
                d <- data.frame(y = y, X, check.names = FALSE)
                list(type = "linear", m = lm(reformulate(sprintf("`%s`", colnames(X)), "y"), data = d))
            }
        }
        pred_one <- function(fm, X) {
            if (fm$type == "lasso") { if (!".const" %in% colnames(X) && ".const" %in% fm$cols) X <- cbind(X, .const = 0); as.numeric(predict(fm$m, X[, fm$cols, drop = FALSE], s = "lambda.min")) }
            else if (fm$type == "random_forest") as.numeric(predict(fm$m, X))
            else as.numeric(predict(fm$m, data.frame(X, check.names = FALSE)))
        }
        loo <- vapply(seq_len(nused), function(i) pred_one(fit_one(X[-i, , drop = FALSE], y[-i]), X[i, , drop = FALSE]), 0)
        err <- loo - y
        rmse <- sqrt(mean(err^2)); mae <- mean(abs(err))
        r2 <- 1 - sum(err^2) / sum((y - mean(y))^2)
        fit <- fit_one(X, y)
        z <- qnorm((1 + LEVEL) / 2)
        coefs <- NULL
        if (fit$type == "linear") {
            cf <- summary(fit$m)$coefficients
            coefs <- lapply(seq_len(nrow(cf)), function(i) list(term = gsub("`", "", rownames(cf)[i]), estimate = cf[i, 1], se = cf[i, 2], p = cf[i, 4]))
        } else if (fit$type == "lasso") {
            b <- as.matrix(coef(fit$m, s = "lambda.min"))
            coefs <- lapply(seq_len(nrow(b)), function(i) list(term = rownames(b)[i], estimate = b[i, 1]))
            coefs <- Filter(function(x) x$term != ".const", coefs)
        }
        cal$loo <- NA_real_; cal$loo[cal$used] <- loo
        yield$metrics <- list(r2 = r2, rmse = rmse, mae = mae, bias = mean(err), n = nused, observed_mean = mean(y))
        yield$coefficients <- coefs
        yield$level <- LEVEL
        yield$ranges <- lapply(PREDICTORS, function(p) list(predictor = p, min = min(X[, p]), max = max(X[, p])))
        say("yield: leave-one-field-out R2 %.2f, RMSE %.3g (%d fields)", r2, rmse, nused)
        predict_target <- function(f) {
            x <- matrix(f[PREDICTORS], nrow = 1, dimnames = list(NULL, PREDICTORS))
            est <- pred_one(fit, x)
            if (fit$type == "linear") {
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
        add_target <- function(id, name, source, series, ha) {
            f <- season_features(series, crop_start, crop_end)
            t <- list(id = id, name = name, source = source, site = s$name, site_id = s$id, area_ha = ha, n_dates = f[["n_dates"]],
                      ndvi_auc = f[["ndvi_auc"]], ndvi_max = f[["ndvi_max"]], ndre_max = f[["ndre_max"]], peak_day = f[["peak_day"]])
            if (!is.null(fit) && f[["n_dates"]] >= MIN_DATES && !any(is.na(f[PREDICTORS]))) t <- c(t, predict_target(f))
            else if (!is.null(fit)) t$reason <- if (f[["n_dates"]] < MIN_DATES) sprintf("only %d clear date(s)", f[["n_dates"]]) else "a predictor could not be computed"
            targets_out[[length(targets_out) + 1]] <<- t
        }
        targets <- s$targets %||% list()
        for (k in seq_along(targets)) {
            m <- ring_matrix(targets[[k]]$ring)
            add_target(as.character(targets[[k]]$id), targets[[k]]$name, "drawn", sd$tseries[[k]], area_ha_ring(m))
        }
        if (need_maps && !is.null(sd$map)) {
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
                }
            }
            say("%s: %d %s area(s) of at least %.1f ha", s$name, length(big), class_names[ci], MIN_PATCH_HA)
        }
    }
    if (INDEX_MODE) {
        # relative yield index: NDVI area under the season curve, 100 = mean of the fields with enough clear dates
        ok <- vapply(targets_out, function(t) t$n_dates >= MIN_DATES && !is.na(t$ndvi_auc), TRUE)
        m <- if (any(ok)) mean(vapply(targets_out[ok], function(t) t$ndvi_auc, 0)) else NA
        idx <- vapply(seq_along(targets_out), function(i) if (ok[i] && !is.na(m) && m > 0) 100 * targets_out[[i]]$ndvi_auc / m else NA_real_, 0)
        rk <- rank(-idx, na.last = "keep", ties.method = "min")
        for (i in seq_along(targets_out)) {
            targets_out[[i]]$index <- idx[i]
            targets_out[[i]]$rank <- if (is.na(rk[i])) NA else as.integer(rk[i])
            if (!ok[i]) targets_out[[i]]$reason <- sprintf("only %d clear date(s)", targets_out[[i]]$n_dates)
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
                m_k <- mean(vapply(targets_out[members], function(t) t$ndvi_auc, 0))
                for (i in members) {
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
        fields_rows[[length(fields_rows) + 1]] <- data.frame(site = t$site, field = t$name, source = t$source, area_ha = round(t$area_ha, 3),
            clear_dates = t$n_dates, ndvi_auc = t$ndvi_auc, ndvi_peak = t$ndvi_max, ndre_peak = t$ndre_max,
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
    models = inp$models, sites = site_out, crop_map = crop_map, yield = yield, indices = indices,
    fields_file = if (length(fields_rows)) basename(paste0(out_base, ".fields.csv")) else NULL,
    notes = as.list(notes), software = list(R = R.version.string, terra = as.character(packageVersion("terra")),
        randomForest = if (do_map) as.character(packageVersion("randomForest")) else NULL, GDAL = gdal()))
writeLines(toJSON(results, auto_unbox = TRUE, null = "null", na = "null", digits = NA), paste0(out_base, ".results.json"))
say("done in %.0f s", as.numeric(difftime(Sys.time(), t_start, units = "secs")))
