#!/usr/bin/env Rscript
# Explicit R message extraction. Application source is parsed, never evaluated.
suppressPackageStartupMessages(library(jsonlite))
fail <- function(message) stop(message, call. = FALSE)
qualified <- c("4.5.0/2.0.0", "4.5.1/1.8.7")
parser_version <- as.character(getRversion()); json_version <- as.character(packageVersion("jsonlite"))
if (!paste(parser_version, json_version, sep = "/") %in% qualified) fail("Qualified R parser unavailable")
raw <- paste(readLines(file("stdin"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
if (nchar(raw, type = "bytes") > 8L * 1024L * 1024L) fail("R extraction request exceeds limit")
request <- tryCatch(fromJSON(raw, simplifyVector = FALSE), error = function(error) fail("Invalid R extraction JSON"))
if (!is.list(request) || !identical(request[["schema"]], 1L) || !is.character(request[["file"]]) || length(request[["file"]]) != 1L || !is.character(request[["source"]]) || length(request[["source"]]) != 1L) fail("Invalid R extraction request")
lines <- sub("\r$", "", strsplit(request[["source"]], "\n", fixed = TRUE)[[1L]])
ast <- tryCatch(suppressWarnings(parse(text = lines, keep.source = TRUE)), error = function(error) fail("R source syntax is unsupported"))
data <- getParseData(ast, includeText = TRUE)
if (is.null(data)) {
    cat(toJSON(list(schema = 1L, parser = "R explicit messages", parserVersion = parser_version, jsonVersion = json_version, records = list()), auto_unbox = TRUE), "\n", sep = "")
    quit(status = 0L)
}
if (nrow(data) > 200000L) fail("R extraction parse-data limit exceeded")
indexes <- setNames(seq_len(nrow(data)), as.character(data$id))
children <- split(data$id, data$parent)
row <- function(id) data[indexes[[as.character(id)]], , drop = FALSE]
kids <- function(id) {
    values <- children[[as.character(id)]]
    if (!length(values)) return(data[FALSE, , drop = FALSE])
    result <- data[unname(indexes[as.character(values)]), , drop = FALSE]
    result[order(result$line1, result$col1, result$line2, result$col2, result$id), , drop = FALSE]
}
scope_count <- 0L
new_scope <- function(parent = NULL) {
    scope_count <<- scope_count + 1L
    scope <- new.env(parent = emptyenv()); scope$parent <- parent; scope$bindings <- new.env(parent = emptyenv()); scope$id <- scope_count
    scope
}
root_scope <- new_scope(); node_scopes <- new.env(parent = emptyenv()); definitions <- list(); mutations <- list()
constructors <- c("sgn_i18n", "sgn_i18n_from_payload")
identifier <- function(text) {
    # Parse-data retains backticks; native R treats their contents as the name.
    if (startsWith(text, "`")) as.character(parse(text = text, keep.source = FALSE)[[1L]]) else text
}
symbol <- function(id) {
    direct <- kids(id)
    if (nrow(direct) == 1L && direct$token[[1L]] %in% c("SYMBOL", "SYMBOL_FUNCTION_CALL")) return(identifier(direct$text[[1L]]))
    NULL
}
binding <- function(scope, name, create = FALSE) {
    if (exists(name, envir = scope$bindings, inherits = FALSE)) return(get(name, envir = scope$bindings, inherits = FALSE))
    if (create) {
        result <- new.env(parent = emptyenv()); result$name <- name; result$scope <- scope; result$defs <- list(); result$parameter <- FALSE; result$busy <- FALSE
        assign(name, result, envir = scope$bindings); return(result)
    }
    if (!is.null(scope$parent)) return(binding(scope$parent, name))
    NULL
}
map_scopes <- function(id, scope) {
    assign(as.character(id), scope, envir = node_scopes)
    direct <- kids(id)
    nested <- scope
    if (any(direct$token == "FUNCTION")) {
        nested <- new_scope(scope)
        for (name in direct$text[direct$token == "SYMBOL_FORMALS"]) { parameter <- binding(nested, identifier(name), TRUE); parameter$parameter <- TRUE }
    }
    for (child in direct$id) map_scopes(child, nested)
}
for (id in kids(0L)$id) map_scopes(id, root_scope)
scope_of <- function(id) get(as.character(id), envir = node_scopes, inherits = FALSE)
assignment <- function(id) {
    direct <- kids(id); operators <- which(direct$token %in% c("LEFT_ASSIGN", "EQ_ASSIGN", "RIGHT_ASSIGN"))
    if (length(operators) != 1L) return(NULL)
    operator <- operators[[1L]]
    if (operator == 1L || operator == nrow(direct)) return(NULL)
    reversed <- direct$token[[operator]] == "RIGHT_ASSIGN"
    list(lhs = direct$id[[if (reversed) operator + 1L else operator - 1L]], rhs = direct$id[[if (reversed) operator - 1L else operator + 1L]], op = direct$text[[operator]])
}
for (id in data$id[data$token == "expr"]) {
    write <- assignment(id)
    if (!is.null(write)) {
        name <- symbol(write$lhs)
        if (!is.null(name)) {
            target <- binding(scope_of(id), name, TRUE)
            target$defs[[length(target$defs) + 1L]] <- list(rhs = write$rhs, op = write$op, node = id)
            definitions[[length(definitions) + 1L]] <- list(target = target, op = write$op, node = id)
        } else mutations[[length(mutations) + 1L]] <- list(lhs = write$lhs, scope = scope_of(id))
    }
    direct <- kids(id)
    if (any(direct$token == "FOR")) {
        condition <- direct$id[direct$token == "forcond"]
        if (length(condition)) {
            variable <- kids(condition[[1L]])
            name <- variable$text[variable$token == "SYMBOL"]
            if (length(name)) { target <- binding(scope_of(id), identifier(name[[1L]]), TRUE); target$defs[[length(target$defs) + 1L]] <- list(rhs = NULL, op = "loop", node = id) }
        }
    }
}
call_info <- function(id) {
    direct <- kids(id)
    opening <- which(direct$text == "(" & direct$terminal)
    if (length(opening) != 1L || opening[[1L]] != 2L || direct$token[[1L]] != "expr") return(NULL)
    list(callee = direct$id[[1L]], direct = direct)
}
member <- function(id) {
    direct <- kids(id)
    if (nrow(direct) == 3L && direct$text[[2L]] == "$" && direct$token[[3L]] %in% c("SYMBOL", "SYMBOL_FUNCTION_CALL", "STR_CONST")) {
        method <- if (direct$token[[3L]] == "STR_CONST") parse(text = direct$text[[3L]], keep.source = FALSE)[[1L]] else identifier(direct$text[[3L]])
        return(list(receiver = direct$id[[1L]], method = method))
    }
    NULL
}
state <- function(kind, origin = NULL) list(kind = kind, origin = origin)
resolve <- NULL
resolve_binding <- function(value) {
    if (is.null(value)) return(state("unsupported_unbound"))
    if (value$busy) return(state("ambiguous"))
    value$busy <- TRUE; on.exit(value$busy <- FALSE)
    parent <- if (!is.null(value$scope$parent)) binding(value$scope$parent, value$name) else NULL
    outer <- if (!is.null(parent)) resolve_binding(parent) else state("unknown")
    if (value$parameter) return(state(if (outer$kind == "known") "shadowed" else "unsupported_injected"))
    results <- lapply(value$defs, function(definition) if (is.null(definition$rhs)) state("unknown") else resolve(definition$rhs, value$scope))
    kinds <- vapply(results, function(result) result$kind, character(1L))
    if (length(value$defs) != 1L || !value$defs[[1L]]$op %in% c("<-", "=")) {
        if (any(kinds == "known") || outer$kind == "known") return(state("ambiguous"))
        return(state("unsupported_binding"))
    }
    if (!length(results)) return(state("unsupported_binding"))
    if (results[[1L]]$kind == "known") return(state("known", results[[1L]]$origin %||% value))
    if (outer$kind == "known") return(state("shadowed"))
    results[[1L]]
}
`%||%` <- function(left, right) if (is.null(left)) right else left
resolve <- function(id, scope) {
    name <- symbol(id)
    if (!is.null(name)) return(resolve_binding(binding(scope, name)))
    info <- call_info(id)
    if (!is.null(info)) {
        name <- symbol(info$callee)
        if (!is.null(name) && name %in% constructors) {
            if (!is.null(binding(scope, name))) return(state("shadowed_constructor"))
            return(state("known", list(node = id, scope = scope)))
        }
        if (!is.null(name) && name == "list" && is.null(binding(scope, name))) return(state("widget"))
        access <- member(info$callee)
        if (!is.null(access) && resolve(access$receiver, scope)$kind == "known") return(state("unsupported_chain"))
        return(state("unsupported_return"))
    }
    access <- member(id)
    if (!is.null(access) && resolve(access$receiver, scope)$kind == "known") return(state("unsupported_method_alias"))
    direct <- kids(id)
    if (nrow(direct) == 3L && direct$text[[1L]] == "(" && direct$text[[3L]] == ")") return(resolve(direct$id[[2L]], scope))
    state("unknown")
}
same_origin <- function(first, second) identical(first$origin, second$origin)
for (write in definitions) if (write$op %in% c("<<-", "->>")) {
    outer <- if (!is.null(write$target$scope$parent)) binding(write$target$scope$parent, write$target$name) else NULL
    if (!is.null(outer) && resolve_binding(outer)$kind == "known") outer$defs[[length(outer$defs) + 1L]] <- list(rhs = NULL, op = "superassignment", node = write$node)
}
for (write in mutations) {
    access <- member(write$lhs)
    if (!is.null(access) && resolve(access$receiver, write$scope)$kind == "known") fail("Unsupported mutation of an R translator receiver")
    direct <- kids(write$lhs)
    if (any(direct$text %in% c("[[", "["))) {
        receiver <- direct$id[direct$token == "expr"]
        if (length(receiver) && resolve(receiver[[1L]], write$scope)$kind == "known") fail("Unsupported mutation of an R translator receiver")
    }
}
arguments <- function(info) {
    direct <- info$direct; result <- list(); pending <- ""; current <- NULL
    if (nrow(direct) == 3L) return(result)
    for (index in seq.int(3L, nrow(direct) - 1L)) {
        token <- direct$token[[index]]
        if (token == "SYMBOL_SUB") pending <- identifier(direct$text[[index]])
        if (token == "expr") { current <- list(name = pending, node = direct$id[[index]]); pending <- "" }
        if (direct$text[[index]] == ",") {
            if (is.null(current)) fail("Unsupported missing R message argument")
            result[[length(result) + 1L]] <- current; current <- NULL
        }
    }
    if (is.null(current)) fail("Unsupported missing R message argument")
    result[[length(result) + 1L]] <- current
    result
}
literal <- function(id) {
    direct <- kids(id)
    if (nrow(direct) != 1L || direct$token[[1L]] != "STR_CONST") fail("R marked message arguments must be whole literal strings")
    parsed <- parse(text = direct$text[[1L]], keep.source = FALSE)
    if (length(parsed) != 1L || !is.character(parsed[[1L]]) || length(parsed[[1L]]) != 1L) fail("Invalid R marked literal")
    value <- parsed[[1L]]
    if (grepl("[\\x{0000}\\x{0004}]", value, perl = TRUE)) fail("Invalid R message context or source")
    enc2utf8(value)
}
records <- list()
constructor_intent <- any(vapply(data$text[data$token == "SYMBOL_FUNCTION_CALL"], identifier, character(1L)) %in% constructors)
for (id in data$id[data$token == "expr"]) {
    info <- call_info(id)
    if (is.null(info)) next
    access <- member(info$callee)
    direct_name <- symbol(info$callee)
    if (constructor_intent && !is.null(direct_name) && direct_name %in% c("eval", "evalq", "eval.parent", "do.call", "get", "assign", "rm", "remove")) fail("Unsupported reflective R translator environment")
    if (!is.null(direct_name) && direct_name %in% c("assign", "rm", "remove")) {
        direct_args <- kids(id)
        literals <- direct_args$id[direct_args$token == "expr"]
        for (candidate in literals[-1L]) {
            leaf <- kids(candidate)
            if (nrow(leaf) == 1L && leaf$token[[1L]] == "STR_CONST") {
                constant <- parse(text=leaf$text[[1L]],keep.source=FALSE)[[1L]]
                target <- binding(scope_of(id),constant)
                if (!is.null(target) && resolve_binding(target)$kind == "known") fail("Unsupported reflective R translator binding mutation")
            }
        }
    }
    if (is.null(access)) {
        direct <- kids(info$callee)
        if (any(direct$text %in% c("[[", "["))) {
            receiver <- direct$id[direct$token == "expr"]
            if (length(receiver) && resolve(receiver[[1L]], scope_of(id))$kind == "known") fail("Unsupported computed R translator method")
        }
        name <- symbol(info$callee)
        if (!is.null(name)) {
            value <- binding(scope_of(id), name)
            if (!is.null(value) && resolve_binding(value)$kind == "unsupported_method_alias") fail("Unsupported R translator method alias")
        }
        next
    }
    receiver <- resolve(access$receiver, scope_of(id))
    if (receiver$kind == "widget") next
    if (!access$method %in% c("p", "np")) next
    if (receiver$kind != "known") fail(paste("Unsupported or ambiguous R translator binding:", receiver$kind))
    needed <- if (access$method == "p") c("context", "source") else c("context", "singular", "plural")
    allowed <- c(needed, if (access$method == "np") "count", "vars")
    args <- arguments(info); assigned <- list(); position <- 1L
    # R first matches all exactly named arguments, then matches unnamed
    # arguments to the remaining formals, independently of source order.
    for (arg in args) if (nzchar(arg$name)) {
        if (!arg$name %in% allowed || arg$name %in% names(assigned)) fail("Unsupported partial or duplicate R message argument")
        assigned[[arg$name]] <- arg$node
    }
    for (arg in args) if (!nzchar(arg$name)) {
        while (position <= length(allowed) && allowed[[position]] %in% names(assigned)) position <- position + 1L
        if (position > length(allowed)) fail("Unsupported extra R message argument")
        assigned[[allowed[[position]]]] <- arg$node; position <- position + 1L
    }
    if (!all(needed %in% names(assigned)) || (access$method == "np" && !"count" %in% names(assigned))) fail("Missing R literal message arguments")
    text <- lapply(needed, function(name) literal(assigned[[name]]))
    if (!nzchar(text[[2L]]) || (access$method == "np" && !nzchar(text[[3L]]))) fail("Empty R English source")
    records[[length(records) + 1L]] <- list(context = text[[1L]], source = text[[2L]], plural = if (access$method == "np") text[[3L]] else NULL,
        reference = paste0(request[["file"]], ":", row(id)$line1[[1L]]))
}
records <- records[order(vapply(records, function(record) as.integer(sub(".*:", "", record$reference)), integer(1L)))]
cat(toJSON(list(schema = 1L, parser = "R explicit messages", parserVersion = parser_version, jsonVersion = json_version, records = records), auto_unbox = TRUE, null = "null"), "\n", sep = "")
