#!/usr/bin/env Rscript
# Developer discovery only. Parse source as data; never source/eval it.
suppressPackageStartupMessages(library(jsonlite))

if (!paste(as.character(getRversion()), as.character(packageVersion("jsonlite")), sep = "/") %in% c("4.5.0/2.0.0", "4.5.1/1.8.7")) {
    stop("R discovery requires a qualified R/jsonlite pair", call. = FALSE)
}
input <- paste(readLines(file("stdin"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
if (nchar(input, type = "bytes") > 16L * 1024L * 1024L) stop("R discovery request exceeds limit", call. = FALSE)
request <- tryCatch(suppressWarnings(fromJSON(input, simplifyVector = FALSE)), error = function(error) stop("Invalid R discovery JSON", call. = FALSE))
if (!is.list(request) || !identical(request$schema, 1L) || !is.list(request$files) || length(request$files) > 256L) {
    stop("Invalid R discovery request", call. = FALSE)
}

parse_file <- function(file) {
    if (!is.list(file) || !is.character(file$file) || length(file$file) != 1L || !nzchar(file$file)
        || !is.character(file$source) || length(file$source) != 1L
        || nchar(file$source, type = "bytes") > 2L * 1024L * 1024L) stop("Invalid R source record", call. = FALSE)
    # Match parse(file=...) line input while keeping the original byte/line
    # mapping on the caller side. Physical CRLF is a source line ending; an
    # escaped \r inside a literal remains untouched.
    source_lines <- strsplit(file$source, "\n", fixed = TRUE)[[1L]]
    source_lines <- sub("\r$", "", source_lines)
    parsed <- tryCatch(suppressWarnings(parse(text = source_lines, keep.source = TRUE)), error = identity)
    if (inherits(parsed, "error")) {
        # Parser error text can echo source lines. Return a disposition rather
        # than copying potentially sensitive source into the discovery report.
        position <- regmatches(conditionMessage(parsed), regexec("^[^\\n]*?:([0-9]+):([0-9]+):", conditionMessage(parsed), perl = TRUE))[[1L]]
        line <- if (length(position) == 3L) as.integer(position[[2L]]) else NULL
        column <- if (length(position) == 3L) as.integer(position[[3L]]) else NULL
        return(list(file = file$file, ok = FALSE, error = "R parser rejected source syntax", errorLine = line, errorColumn = column, records = list()))
    }
    data <- getParseData(parsed, includeText = TRUE)
    if (is.null(data)) return(list(file = file$file, ok = TRUE, records = list()))
    if (nrow(data) > 200000L) return(list(file = file$file, ok = FALSE, error = "R parse-data limit exceeded", records = list()))
    indexes <- setNames(seq_len(nrow(data)), as.character(data$id))
    children <- split(data$id, data$parent)
    descendants <- function(id) {
        pending <- id
        seen <- integer()
        while (length(pending)) {
            current <- pending[[1L]]
            pending <- pending[-1L]
            seen <- c(seen, current)
            if (length(seen) > 200000L) stop("R source tree limit exceeded", call. = FALSE)
            pending <- c(pending, children[[as.character(current)]])
        }
        data[unname(indexes[as.character(seen)]), , drop = FALSE]
    }
    sensitive_assignment <- function(id) {
        current <- data$parent[[indexes[[as.character(id)]]]]
        depth <- 0L
        while (current > 0L) {
            depth <- depth + 1L
            if (depth > 128L) return("sensitive_context_depth_review")
            direct <- data[unname(indexes[as.character(children[[as.character(current)]])]), , drop = FALSE]
            direct <- direct[order(direct$line1, direct$col1, direct$line2, direct$col2), , drop = FALSE]
            # This reviewed external-integration call uses opaque positional
            # arguments. Protect every literal subnode before any serialization.
            if (nrow(direct) && any(direct$text == "(")) {
                function_data <- descendants(direct$id[[1L]])
                if (any(function_data$token == "SYMBOL_FUNCTION_CALL" & function_data$text == "onaDownload")) return("external_credential_call_review")
            }
            # Named arguments can carry credentials too. Inspect only the
            # argument branch containing this literal, without invoking calls.
            named <- which(direct$token == "EQ_SUB")
            for (operation in named) {
                if (operation > 1L && operation < nrow(direct)) {
                    target <- direct[operation - 1L, , drop = FALSE]
                    branch <- descendants(direct$id[[operation + 1L]])
                    if (id %in% branch$id && grepl("password|dbpass|api[._]?key|secret|access[._]?token", target$text[[1L]], ignore.case = TRUE)) return("sensitive_named_argument")
                }
            }
            operators <- which(direct$token %in% c("LEFT_ASSIGN", "EQ_ASSIGN", "RIGHT_ASSIGN"))
            if (length(operators) == 1L) {
                operation <- operators[[1L]]
                target <- if (direct$token[[operation]] == "RIGHT_ASSIGN") direct$id[seq.int(operation + 1L, nrow(direct))] else direct$id[seq_len(operation - 1L)]
                target_data <- do.call(rbind, lapply(target, descendants))
                target_text <- target_data$text[target_data$token %in% c("SYMBOL", "SYMBOL_SUB", "STR_CONST")]
                if (any(grepl("password|dbpass|api[._]?key|secret|access[._]?token", target_text, ignore.case = TRUE))) return("sensitive_assignment")
            }
            current <- data$parent[[indexes[[as.character(current)]]]]
        }
        NULL
    }
    literals <- data[data$token == "STR_CONST" & data$terminal, , drop = FALSE]
    literals <- literals[order(literals$line1, literals$col1), , drop = FALSE]
    records <- lapply(seq_len(nrow(literals)), function(index) {
        token <- literals[index, , drop = FALSE]
        protection_reason <- sensitive_assignment(token$id[[1L]])
        sensitive <- !is.null(protection_reason)
        value <- NULL
        if (!sensitive) {
            # A STR_CONST is a parser-qualified constant. Its expression node
            # contains the decoded character value without any evaluation.
            constant <- suppressWarnings(parse(text = token$text[[1L]], keep.source = FALSE))
            if (length(constant) != 1L || !is.character(constant[[1L]]) || length(constant[[1L]]) != 1L) {
                stop("R parser returned a nonconstant string token", call. = FALSE)
            }
            value <- constant[[1L]]
        }
        list(line = token$line1[[1L]], column = token$col1[[1L]], value = value, sensitiveAssignment = sensitive, protectionReason = protection_reason)
    })
    list(file = file$file, ok = TRUE, records = records)
}

result <- list(schema = 1L, parser = "R parseData", parserVersion = as.character(getRversion()),
               jsonVersion = as.character(packageVersion("jsonlite")), files = lapply(request$files, parse_file))
cat(toJSON(result, auto_unbox = TRUE, null = "null", digits = NA), "\n", sep = "")
