# The default English build remains the original Bookdown command.
args <- commandArgs(trailingOnly = TRUE)
usage <- "Usage: Rscript build.R LOCALE /absolute/output [split|single]"
if (identical(args, "--help") || identical(args, "-h")) {
    cat(usage, "\nLocales: en, uk, es, ar. Default mode: split.\n",
        "No arguments: original English Bookdown build.\n", sep = "")
    quit(status = 0)
}
if (length(args) && (length(args) < 2L || length(args) > 3L)) stop(usage)
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
setwd(source_dir)

# Resolve existing symlink prefixes and missing output components without writes.
resolve_output <- function(path) {
    if (dir.exists(path)) return(normalizePath(path, mustWork = TRUE))
    parent <- resolve_output(dirname(path))
    leaf <- basename(path)
    if (leaf == ".") return(parent)
    if (leaf == "..") return(dirname(parent))
    resolved <- file.path(parent, leaf)
    if (dir.exists(resolved)) normalizePath(resolved, mustWork = TRUE) else resolved
}

render_language <- function(locale, output_dir, single_page = FALSE) {
    if (!locale %in% c("en", "uk", "es", "ar")) stop("Unsupported manual locale")
    if (!startsWith(output_dir, "/")) stop("Manual output must be an absolute path outside the source directory")
    output_dir <- resolve_output(output_dir)
    output_prefix <- paste0(sub("/+$", "", output_dir), "/")
    source_prefix <- paste0(source_dir, "/")
    if (startsWith(output_prefix, source_prefix) || startsWith(source_prefix, output_prefix)) {
        stop("Manual output must not overlap the source directory")
    }
    chapter_files <- yaml::read_yaml("_bookdown.yml")$rmd_files
    locale_dir <- if (locale == "en") source_dir else file.path(source_dir, "i18n", locale)
    required <- c(chapter_files, "_bookdown.yml", "_output.yml")
    if (!all(file.exists(file.path(locale_dir, required)))) stop("Incomplete manual language source")
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    stage <- tempfile(paste0("breedbase-manual-", locale, "-"))
    dir.create(stage)
    previous <- getwd()
    on.exit({setwd(previous); unlink(stage, recursive = TRUE)}, add = TRUE)
    if (!all(file.copy(file.path(locale_dir, required), stage))) stop("Cannot stage manual sources")
    if (!all(file.copy(file.path(source_dir, c("conditional-content.lua", "hypothesis.html")), stage))) stop("Cannot stage manual includes")
    # Real copies keep knitr image URLs relative and never modify the shared originals.
    if (!file.copy(file.path(source_dir, "assets"), stage, recursive = TRUE)) stop("Cannot stage manual figures")
    support <- c("manual-locale.css", "manual-locale.js")
    if (!all(file.copy(file.path(source_dir, "i18n", support), stage))) stop("Cannot stage locale presentation")
    header_dir <- file.path(source_dir, "i18n", locale)
    if (!file.copy(file.path(header_dir, "locale-header.html"), stage)) stop("Cannot stage locale metadata")
    if (locale == "en") {
        output <- yaml::read_yaml(file.path(stage, "_output.yml"))
        output[["bookdown::gitbook"]]$css <- c("assets/style.css", "manual-locale.css")
        output[["bookdown::gitbook"]]$includes$in_header <- c("hypothesis.html", "locale-header.html")
        yaml::write_yaml(output, file.path(stage, "_output.yml"))
    }
    setwd(stage)
    rendered <- bookdown::render_book("index.Rmd", "bookdown::gitbook", output_dir = output_dir,
        output_options = list(split_by = if (single_page) "none" else "chapter", mathjax = NULL,
            pandoc_args = c("--lua-filter=conditional-content.lua", "--mathml", paste0("--metadata=lang:", locale))), clean = FALSE)
    # Bookdown copies referenced GIFs only. Ship their static print alternatives
    # too, so PDF export can read an immutable HTML bundle without modifying it.
    print_figures <- file.path(source_dir, "assets", "gifs", paste0("gif", 1:4, ".png"))
    print_dir <- file.path(output_dir, "assets", "gifs")
    dir.create(print_dir, recursive = TRUE, showWarnings = FALSE)
    if (!all(file.copy(print_figures, print_dir, overwrite = TRUE))) stop("Cannot stage static print figures")
    rendered
}

if (!length(args)) {
    bookdown::render_book("index.Rmd", "bookdown::gitbook")
} else {
    locale <- args[1]
    output_dir <- args[2]
    mode <- if (length(args) >= 3) args[3] else "split"
    if (!mode %in% c("split", "single")) stop("Manual mode must be split or single")
    render_language(locale, output_dir, mode == "single")
}
