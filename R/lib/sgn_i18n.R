# Plain request/job-local message presentation. Catalogs are JSON data only.
.sgn_i18n_error <- function(message) stop(message, call. = FALSE)
.sgn_i18n_max <- 9007199254740991

.sgn_i18n_string <- function(value, label, empty = TRUE) {
    if (!is.character(value) || is.object(value) || length(value) != 1L || is.na(value) || (!empty && !nzchar(value))) .sgn_i18n_error(paste("Invalid", label))
    value <- enc2utf8(value)
    if (!validUTF8(value)) .sgn_i18n_error(paste("Invalid UTF-8", label))
    value
}
.sgn_i18n_count <- function(value) {
    if (!is.numeric(value) || is.object(value) || is.complex(value) || length(value) != 1L || !is.finite(value) || value < 0 || value != trunc(value) || value > .sgn_i18n_max) .sgn_i18n_error("Plural count must be a nonnegative safe integer")
    as.numeric(value)
}
.sgn_i18n_locale <- function(value) {
    value <- .sgn_i18n_string(value, "locale", FALSE)
    if (!grepl("^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$", value)) .sgn_i18n_error("Invalid locale")
    parts <- strsplit(value, "-", fixed = TRUE)[[1L]]
    parts[[1L]] <- tolower(parts[[1L]])
    if (length(parts) > 1L) for (index in 2:length(parts)) {
        part <- parts[[index]]
        parts[[index]] <- if (nchar(part) == 4L) paste0(toupper(substr(part, 1L, 1L)), tolower(substr(part, 2L, 4L))) else if (nchar(part) == 2L) toupper(part) else tolower(part)
    }
    paste(parts, collapse = "-")
}
.sgn_i18n_domain <- function(value) {
    value <- .sgn_i18n_string(value, "catalog domain", FALSE)
    if (!grepl("^[a-z][a-z0-9_-]*$", value)) .sgn_i18n_error("Invalid catalog domain")
    value
}
.sgn_i18n_object <- function(value, label) {
    if (!is.list(value) || is.object(value) || is.null(names(value)) || anyDuplicated(names(value))) .sgn_i18n_error(paste("Invalid", label))
    value
}
.sgn_i18n_name <- function(value) {
    value <- .sgn_i18n_string(value, "native language name", FALSE)
    points <- utf8ToInt(value)
    if (!nzchar(trimws(value)) || nchar(value, type = "chars") > 200L || any(points <= 31L | (points >= 127L & points <= 159L) | points %in% c(8232L,8233L))) .sgn_i18n_error("Invalid native language name")
    value
}
.sgn_i18n_copy <- function(value) unserialize(serialize(value, NULL, version = 3L))

# R's floating modulo can round the quotient at the safe-integer boundary.
# Binary subtraction keeps every intermediate a representable safe integer.
.sgn_i18n_mod <- function(value, divisor) {
    step <- divisor
    while (step <= value / 2) step <- step * 2
    result <- value
    while (step >= divisor) {
        if (result >= step) result <- result - step
        step <- step / 2
    }
    result
}
.sgn_i18n_ast <- function(ast, nplurals) {
    size <- 0L
    visit <- function(node, depth = 0L) {
        .sgn_i18n_object(node, "plural AST")
        size <<- size + 1L
        if (size > 128L || depth > 24L) .sgn_i18n_error("Invalid or oversized plural AST")
        type <- .sgn_i18n_string(node[["type"]], "plural AST type", FALSE)
        keys <- NULL
        bounds <- NULL
        if (type == "VAR") { keys <- "type"; bounds <- c(0, .sgn_i18n_max) }
        else if (type == "NUM") { keys <- c("type", "val"); number <- .sgn_i18n_count(node[["val"]]); bounds <- c(number, number) }
        else if (type == "GROUP") { keys <- c("type", "expr"); bounds <- visit(node[["expr"]], depth + 1L) }
        else if (type == "TERNARY") {
            keys <- c("type", "expr", "truthy", "falsey")
            visit(node[["expr"]], depth + 1L)
            yes <- visit(node[["truthy"]], depth + 1L); no <- visit(node[["falsey"]], depth + 1L)
            bounds <- c(min(yes[[1L]], no[[1L]]), max(yes[[2L]], no[[2L]]))
        } else if (type %in% c("OR", "AND", "LT", "GT", "LTE", "GTE", "EQ", "NEQ", "MOD")) {
            keys <- c("type", "left", "right")
            left <- visit(node[["left"]], depth + 1L); visit(node[["right"]], depth + 1L)
            if (type == "MOD") {
                right <- node[["right"]]
                while (identical(right[["type"]], "GROUP")) right <- right[["expr"]]
                if (!identical(right[["type"]], "NUM") || .sgn_i18n_count(right[["val"]]) == 0) .sgn_i18n_error("Plural modulo requires a positive constant divisor")
                bounds <- c(0, min(left[[2L]], right[["val"]] - 1))
            } else bounds <- c(0, 1)
        } else .sgn_i18n_error("Unsupported plural AST operator")
        if (!identical(sort(names(node)), sort(keys))) .sgn_i18n_error("Unexpected plural AST field")
        bounds
    }
    bounds <- visit(ast)
    if (bounds[[1L]] < 0 || bounds[[2L]] >= nplurals) .sgn_i18n_error("Plural index outside catalog forms")
    ast
}
.sgn_i18n_evaluate <- function(node, count) {
    type <- node[["type"]]
    if (type == "VAR") return(count)
    if (type == "NUM") return(node[["val"]])
    if (type == "GROUP") return(.sgn_i18n_evaluate(node[["expr"]], count))
    if (type == "TERNARY") return(.sgn_i18n_evaluate(if (.sgn_i18n_evaluate(node[["expr"]], count) != 0) node[["truthy"]] else node[["falsey"]], count))
    left <- .sgn_i18n_evaluate(node[["left"]], count)
    if (type == "OR") return(as.numeric(left != 0 || .sgn_i18n_evaluate(node[["right"]], count) != 0))
    if (type == "AND") return(as.numeric(left != 0 && .sgn_i18n_evaluate(node[["right"]], count) != 0))
    right <- .sgn_i18n_evaluate(node[["right"]], count)
    switch(type, LT = as.numeric(left < right), GT = as.numeric(left > right), LTE = as.numeric(left <= right),
           GTE = as.numeric(left >= right), EQ = as.numeric(left == right), NEQ = as.numeric(left != right), MOD = .sgn_i18n_mod(left, right),
           .sgn_i18n_error("Unsupported plural AST operator"))
}
.sgn_i18n_placeholders <- function(text) {
    matched <- gregexpr("%\\{[A-Za-z_][A-Za-z0-9_]*\\}", text, perl = TRUE)[[1L]]
    if (matched[[1L]] < 0L) return(character())
    lengths <- attr(matched, "match.length")
    vapply(seq_along(matched), function(index) substr(text, matched[[index]] + 2L, matched[[index]] + lengths[[index]] - 2L), character(1L))
}
.sgn_i18n_catalog <- function(catalog, expected_locale) {
    .sgn_i18n_object(catalog, "catalog")
    # List `$` performs partial field matching in R. Catalog fields are an exact
    # data protocol, so every read uses `[[` without partial matching.
    if (!is.numeric(catalog[["schema"]]) || is.object(catalog[["schema"]]) || is.complex(catalog[["schema"]]) || !identical(as.numeric(catalog[["schema"]]), 1) || !is.numeric(catalog[["api"]]) || is.object(catalog[["api"]]) || is.complex(catalog[["api"]]) || !identical(as.numeric(catalog[["api"]]), 1)) .sgn_i18n_error("Unsupported catalog schema")
    if (.sgn_i18n_locale(catalog[["locale"]]) != expected_locale) .sgn_i18n_error("Catalog locale mismatch")
    catalog[["locale"]] <- expected_locale
    if (!identical(catalog[["direction"]], "ltr") && !identical(catalog[["direction"]], "rtl")) .sgn_i18n_error("Invalid direction")
    if ("languageName" %in% names(catalog)) catalog[["languageName"]] <- .sgn_i18n_name(catalog[["languageName"]])
    if (!is.numeric(catalog[["nplurals"]]) || is.object(catalog[["nplurals"]]) || is.complex(catalog[["nplurals"]]) || length(catalog[["nplurals"]]) != 1L || !is.finite(catalog[["nplurals"]]) || catalog[["nplurals"]] != trunc(catalog[["nplurals"]]) || !catalog[["nplurals"]] %in% 1:6) .sgn_i18n_error("Invalid plural form count")
    header <- .sgn_i18n_string(catalog[["pluralForms"]], "Plural-Forms metadata", FALSE)
    if (nchar(header) > 2048L || !grepl(paste0("^\\s*nplurals\\s*=\\s*", catalog[["nplurals"]], "\\s*;\\s*plural\\s*=\\s*[^;]+;?\\s*$"), header, perl = TRUE)) .sgn_i18n_error("Invalid Plural-Forms metadata")
    # The informational expression text is never parsed or evaluated.
    .sgn_i18n_ast(catalog[["pluralAst"]], catalog[["nplurals"]])
    messages <- catalog[["messages"]]
    if (!is.list(messages) || is.object(messages) || (length(messages) && (is.null(names(messages)) || anyDuplicated(names(messages))))) .sgn_i18n_error("Invalid catalog messages")
    for (key in names(messages)) {
        if (length(strsplit(key, "\004", fixed = TRUE)[[1L]]) != 2L) .sgn_i18n_error("Invalid catalog message key")
        message <- .sgn_i18n_object(messages[[key]], "catalog message")
        if (!"plural" %in% names(message)) .sgn_i18n_error("Invalid catalog plural source")
        if (!is.null(message[["plural"]])) .sgn_i18n_string(message[["plural"]], "catalog plural source", FALSE)
        expected <- if (is.null(message[["plural"]])) 1L else catalog[["nplurals"]]
        if (!is.list(message[["forms"]]) || is.object(message[["forms"]]) || length(message[["forms"]]) != expected) .sgn_i18n_error("Incomplete catalog message")
        source <- strsplit(key, "\004", fixed = TRUE)[[1L]][[2L]]
        variables <- sort(unique(.sgn_i18n_placeholders(source)))
        if (!is.null(message[["plural"]]) && !identical(variables, sort(unique(.sgn_i18n_placeholders(message[["plural"]]))))) .sgn_i18n_error("Catalog named variables do not match")
        for (form in message[["forms"]]) {
            form <- .sgn_i18n_string(form, "catalog form", FALSE)
            if (!identical(variables, sort(unique(.sgn_i18n_placeholders(form))))) .sgn_i18n_error("Catalog named variables do not match")
        }
    }
    .sgn_i18n_copy(catalog)
}
.sgn_i18n_value <- function(value) {
    if (is.object(value) || length(value) != 1L || is.na(value) || !is.atomic(value) || is.complex(value) || is.raw(value)) .sgn_i18n_error("Missing or invalid named variable")
    if (is.numeric(value)) {
        if (!is.finite(value)) .sgn_i18n_error("Missing or invalid named variable")
        if (value == trunc(value) && abs(value) <= .sgn_i18n_max) return(sprintf("%.0f", value))
    }
    .sgn_i18n_string(as.character(value), "named variable")
}
.sgn_i18n_format <- function(text, vars) {
    text <- .sgn_i18n_string(text, "presentation text")
    if (!is.list(vars) || is.object(vars) || (length(vars) && (is.null(names(vars)) || anyDuplicated(names(vars))))) .sgn_i18n_error("Named variables must be a named list")
    matched <- gregexpr("%\\{[A-Za-z_][A-Za-z0-9_]*\\}", text, perl = TRUE)[[1L]]
    if (matched[[1L]] < 0L) return(text)
    lengths <- attr(matched, "match.length"); parts <- character(); cursor <- 1L
    for (index in seq_along(matched)) {
        start <- matched[[index]]; end <- start + lengths[[index]] - 1L
        name <- substr(text, start + 2L, end - 1L)
        if (!name %in% names(vars) || is.null(vars[[name]])) .sgn_i18n_error("Missing or invalid named variable")
        parts <- c(parts, if (start > cursor) substr(text, cursor, start - 1L) else "", .sgn_i18n_value(vars[[name]]))
        cursor <- end + 1L
    }
    paste0(c(parts, substr(text, cursor, nchar(text))), collapse = "")
}
.sgn_i18n_make <- function(requested, domain, catalogs) {
    state <- new.env(parent = emptyenv())
    state$catalogs <- .sgn_i18n_copy(catalogs)
    state$requested <- requested; state$domain <- domain
    state$locale <- if (length(catalogs)) catalogs[[1L]][["locale"]] else "en"
    state$direction <- if (length(catalogs)) catalogs[[1L]][["direction"]] else "ltr"
    state$name <- if (length(catalogs) && !is.null(catalogs[[1L]][["languageName"]])) catalogs[[1L]][["languageName"]] else if (state$locale == "en") "English" else state$locale
    lockEnvironment(state, bindings = TRUE)
    object <- new.env(parent = emptyenv())
    object$p <- function(context, source, vars = list()) {
        context <- .sgn_i18n_string(context, "translation context"); source <- .sgn_i18n_string(source, "English source")
        key <- paste0(context, "\004", source); text <- source
        for (catalog in state$catalogs) if (key %in% names(catalog[["messages"]])) {
            message <- catalog[["messages"]][[key]]
            if (is.null(message[["plural"]])) { text <- message[["forms"]][[1L]]; break }
        }
        .sgn_i18n_format(text, vars)
    }
    object$np <- function(context, singular, plural, count, vars = list()) {
        count <- .sgn_i18n_count(count)
        context <- .sgn_i18n_string(context, "translation context"); singular <- .sgn_i18n_string(singular, "English singular"); plural <- .sgn_i18n_string(plural, "English plural")
        key <- paste0(context, "\004", singular); text <- if (count == 1) singular else plural
        for (catalog in state$catalogs) if (key %in% names(catalog[["messages"]])) {
            message <- catalog[["messages"]][[key]]
            if (!is.null(message[["plural"]]) && identical(message[["plural"]], plural)) { text <- message[["forms"]][[as.integer(.sgn_i18n_evaluate(catalog[["pluralAst"]], count)) + 1L]]; break }
        }
        .sgn_i18n_format(text, vars)
    }
    object$locale <- function() state$locale
    object$requested_locale <- function() state$requested
    object$dir <- function() state$direction
    object$language_name <- function() state$name
    object$export_catalog <- function() .sgn_i18n_copy(list(locale = state$locale, requestedLocale = state$requested, dir = state$direction, languageName = state$name, domain = state$domain, catalogs = state$catalogs))
    class(object) <- "sgn_i18n"
    lockEnvironment(object, bindings = TRUE)
    object
}
.sgn_i18n_read <- function(path, limit) {
    if (file.info(path)$size > limit) .sgn_i18n_error("Oversized catalog")
    bytes <- readBin(path, "raw", n = limit + 1L)
    if (length(bytes) > limit) .sgn_i18n_error("Oversized catalog")
    value <- tryCatch(jsonlite::fromJSON(rawToChar(bytes), simplifyVector = FALSE),
        error = function(error) .sgn_i18n_error("Invalid catalog JSON"))
    list(bytes = bytes, value = value)
}
.sgn_i18n_bundle <- function(directory, locale, domain) {
    path <- file.path(directory, "index.json")
    if (!file.exists(path)) return(NULL)
    index <- .sgn_i18n_read(path, 2L * 1024L * 1024L)$value
    .sgn_i18n_object(index, "partition index")
    if (!is.numeric(index[["schema"]]) || !identical(as.numeric(index[["schema"]]), 1) || !identical(index[["domain"]], domain) ||
        !is.list(index[["partitions"]]) || length(index[["partitions"]]) > 64L) .sgn_i18n_error("Invalid partition index")
    if (!requireNamespace("digest", quietly = TRUE)) .sgn_i18n_error("Catalog SHA256 validation is unavailable")
    merged <- NULL; seen <- character()
    for (part in index[["partitions"]]) {
        .sgn_i18n_object(part, "catalog partition")
        name <- .sgn_i18n_string(part[["name"]], "partition name", FALSE)
        hash <- .sgn_i18n_string(part[["sha256"]], "partition hash", FALSE)
        if (!grepl("^[a-z][a-z0-9_]*$", name) || name %in% seen || !grepl("^[a-f0-9]{64}$", hash)) .sgn_i18n_error("Invalid catalog partition")
        seen <- c(seen, name); file <- file.path(directory, paste0(name, ".json"))
        if (!file.exists(file)) next
        data <- .sgn_i18n_read(file, 2L * 1024L * 1024L)
        if (!identical(digest::digest(data$bytes, algo = "sha256", serialize = FALSE), hash)) .sgn_i18n_error("Catalog partition hash mismatch")
        catalog <- .sgn_i18n_catalog(data$value, locale)
        if (is.null(merged)) { merged <- catalog; merged[["messages"]] <- list() }
        for (key in names(catalog[["messages"]])) {
            if (key %in% names(merged[["messages"]])) {
                if (!identical(merged[["messages"]][[key]], catalog[["messages"]][[key]])) .sgn_i18n_error("Conflicting catalog partitions")
            } else merged[["messages"]][[key]] <- catalog[["messages"]][[key]]
        }
    }
    if (!is.null(merged)) merged[["sourceRevision"]] <- index[["sourceRevision"]]
    list(catalog = merged)
}
sgn_i18n <- function(locale = "en", catalog_root = NULL, domain = "sgn") {
    requested <- .sgn_i18n_locale(locale); domain <- .sgn_i18n_domain(domain); catalogs <- list()
    if (!is.null(catalog_root)) {
        catalog_root <- .sgn_i18n_string(catalog_root, "catalog root", FALSE)
        candidate <- requested
        repeat {
            bundle <- .sgn_i18n_bundle(file.path(catalog_root, candidate, domain), candidate, domain)
            if (!is.null(bundle)) {
                if (!is.null(bundle$catalog)) catalogs[[length(catalogs) + 1L]] <- bundle$catalog
            } else {
                path <- file.path(catalog_root, candidate, paste0(domain, ".json"))
                if (file.exists(path)) catalogs[[length(catalogs) + 1L]] <- .sgn_i18n_catalog(
                    .sgn_i18n_read(path, 4L * 1024L * 1024L)$value, candidate)
            }
            if (!grepl("-", candidate, fixed = TRUE)) break
            candidate <- sub("-[^-]+$", "", candidate)
        }
    }
    .sgn_i18n_make(requested, domain, catalogs)
}
sgn_i18n_from_payload <- function(payload) {
    .sgn_i18n_object(payload, "translation payload")
    payload_locale <- .sgn_i18n_locale(payload[["locale"]])
    requested <- .sgn_i18n_locale(if (!is.null(payload[["requestedLocale"]])) payload[["requestedLocale"]] else payload_locale)
    if (!is.null(payload[["dir"]]) && !payload[["dir"]] %in% c("ltr", "rtl")) .sgn_i18n_error("Invalid payload direction")
    if (!is.null(payload[["languageName"]])) .sgn_i18n_name(payload[["languageName"]])
    domain <- .sgn_i18n_domain(payload[["domain"]])
    if (!is.list(payload[["catalogs"]]) || is.object(payload[["catalogs"]])) .sgn_i18n_error("Invalid payload catalogs")
    validated <- lapply(payload[["catalogs"]], function(catalog) {
        .sgn_i18n_object(catalog, "payload catalog")
        .sgn_i18n_catalog(catalog, .sgn_i18n_locale(catalog[["locale"]]))
    })
    locales <- vapply(validated, function(catalog) catalog[["locale"]], character(1L))
    if (anyDuplicated(locales)) .sgn_i18n_error("Duplicate payload catalog locale")
    catalogs <- list(); candidate <- requested
    repeat {
        for (catalog in validated) if (.sgn_i18n_locale(catalog[["locale"]]) == candidate) catalogs[[length(catalogs) + 1L]] <- .sgn_i18n_catalog(catalog, candidate)
        if (!grepl("-", candidate, fixed = TRUE)) break
        candidate <- sub("-[^-]+$", "", candidate)
    }
    .sgn_i18n_make(requested, domain, catalogs)
}
