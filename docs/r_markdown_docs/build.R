library(bookdown)
library(xfun)
is_abs_path <- FALSE

# The default English build remains the original Bookdown command.
args <- commandArgs(trailingOnly = TRUE)
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
setwd(source_dir)

render_language <- function(locale, output_dir, single_page = FALSE) {
    if (!locale %in% c("en", "uk", "es", "ar")) stop("Unsupported manual locale")
    chapter_files <- yaml::read_yaml("_bookdown.yml")$rmd_files
    locale_dir <- if (locale == "en") source_dir else file.path(source_dir, "i18n", locale)
    required <- c(chapter_files, "_bookdown.yml", "_output.yml")
    if (!all(file.exists(file.path(locale_dir, required)))) stop("Incomplete manual language source")
    output_dir <- normalizePath(output_dir, mustWork = FALSE)
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    stage <- tempfile(paste0("breedbase-manual-", locale, "-"))
    dir.create(stage)
    previous <- getwd()
    on.exit({setwd(previous); unlink(stage, recursive = TRUE)}, add = TRUE)
    if (!all(file.copy(file.path(locale_dir, required), stage))) stop("Cannot stage manual sources")
    if (!all(file.copy(file.path(source_dir, c("conditional-content.lua", "hypothesis.html")), stage))) stop("Cannot stage manual includes")
    # Real copies keep knitr image URLs relative and never modify the shared originals.
    if (!file.copy(file.path(source_dir, "assets"), stage, recursive = TRUE)) stop("Cannot stage manual figures")
    if (locale != "en") {
        support <- c("manual-locale.css", "manual-locale.js")
        if (!all(file.copy(file.path(source_dir, "i18n", support), stage))) stop("Cannot stage locale presentation")
        if (!file.copy(file.path(locale_dir, "locale-header.html"), stage)) stop("Cannot stage locale metadata")
    }
    setwd(stage)
    bookdown::render_book("index.Rmd", "bookdown::gitbook", output_dir = output_dir,
        output_options = list(split_by = if (single_page) "none" else "chapter", mathjax = NULL,
            pandoc_args = c("--lua-filter=conditional-content.lua", "--mathml")), clean = FALSE)
}

if (!length(args)) {
    render_book("index.Rmd", "bookdown::gitbook")
} else {
    locale <- args[1]
    output_dir <- if (length(args) >= 2) args[2] else file.path(dirname(source_dir), if (locale == "en") "" else locale)
    mode <- if (length(args) >= 3) args[3] else "split"
    if (!mode %in% c("split", "single")) stop("Manual mode must be split or single")
    render_language(locale, output_dir, mode == "single")
}
