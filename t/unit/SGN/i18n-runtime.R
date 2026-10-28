# Trusted tiny test fixture for the new presentation runtime; no app scripts.
suppressPackageStartupMessages(library(jsonlite))
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(root, "R/lib/sgn_i18n.R"), local = .GlobalEnv)
fixtures <- fromJSON(file.path(root, "t/unit/SGN/i18n-fixtures.json"), simplifyVector = FALSE)
checks <- 0L
check <- function(actual, expected, label) {
    if (!identical(actual, expected)) stop(paste("Failed:", label), call. = FALSE)
    checks <<- checks + 1L
}
reject <- function(action, label) {
    result <- tryCatch({action(); FALSE}, error = function(error) TRUE)
    check(result, TRUE, label)
}
clone <- function(value) unserialize(serialize(value, NULL))
payload <- function(locale, catalogs = if (locale %in% names(fixtures$catalogs)) list(fixtures$catalogs[[locale]]) else list()) list(locale = locale, domain = "sgn", catalogs = catalogs)
create <- function(locale) sgn_i18n_from_payload(payload(locale))
environment_before <- Sys.getenv(); locale_before <- Sys.getlocale()
uk <- create("uk"); en <- create("en"); ar <- create("ar")
check(uk$p("controls.save", "Save"), "Зберегти", "Ukrainian message")
check(uk$p("seedlots.save", "Save"), "Зберегти партію", "context identity")
check(uk$p("", "Save"), "Зберегти без контексту", "empty context")
check(uk$p("data", "Wheat"), "Wheat", "scientific data fallback")
check(uk$p("controls.save", "Save changes"), "Save changes", "stale singular source")
suffix <- list("0"="дослідів","1"="дослід","2"="досліди","5"="дослідів","11"="дослідів","21"="дослід","22"="досліди","25"="дослідів","101"="дослід")
for (key in names(suffix)) check(uk$np("trials.count", "%{count} trial found", "%{count} trials found", as.numeric(key), list(count=as.numeric(key))), paste("Знайдено",key,suffix[[key]]), paste("Ukrainian plural",key))
for (pair in list(c(0,0),c(1,1),c(2,2),c(3,3),c(11,4),c(100,5),c(102,5))) check(ar$np("trials.count", "%{count} trial found", "%{count} trials found",pair[[1L]],list(count=pair[[1L]])),paste0("ar[",pair[[2L]],"] ",pair[[1L]]),"Arabic plural")
check(create("pt-BR")$np("trials.count","%{count} trial found","%{count} trials found",0,list(count=0)),"pt-BR[0] 0","Brazil zero")
check(create("pt-PT")$np("trials.count","%{count} trial found","%{count} trials found",0,list(count=0)),"pt-PT[1] 0","Portugal zero")
check(uk$np("missing","%{count} trial","%{count} trials",21,list(count=21)),"21 trials","English plural fallback")
check(uk$np("trials.count","%{count} trial found","%{count} records found",1,list(count=1)),"1 trial found","whole stale plural fallback")
check(uk$p("trial.named","Created trial %{name}.",list(name="𝛂</script><img src=x>")),"Створено дослід 𝛂</script><img src=x>.","Unicode/plain named value")
check(en$p("literal","Value: %{name}",list(name="%{other}")),"Value: %{other}","single-pass parameters")
check(en$p("literal","Keep {braces} and %{name}.",list(name="value")),"Keep {braces} and value.","bare braces")
for (iteration in 1:5) {
    check(en$p("controls.save","Save"),"Save","independent English")
    check(uk$p("controls.save","Save"),"Зберегти","independent Ukrainian")
    check(ar$np("trials.count","%{count} trial found","%{count} trials found",3,list(count=3)),"ar[3] 3","independent Arabic")
}
check(en$language_name(),"English","source native name")
reject(function() uk$locale <- function() "mutated", "locked metadata getter")
reject(function() uk$p <- function(...) "mutated", "locked methods")
exported <- uk$export_catalog(); exported$catalogs[[1L]]$messages[["controls.save\004Save"]]$forms[[1L]] <- "changed"
check(uk$p("controls.save","Save"),"Зберегти","export data copy")
original <- payload("uk"); detached <- sgn_i18n_from_payload(original); original$catalogs[[1L]]$messages[["controls.save\004Save"]]$forms[[1L]] <- "changed"
check(detached$p("controls.save","Save"),"Зберегти","caller catalog copy")
root <- tempfile("sgn-R-catalogs-"); dir.create(root)
for (tag in names(fixtures$catalogs)) {dir.create(file.path(root,tag));writeLines(toJSON(fixtures$catalogs[[tag]],auto_unbox=TRUE,null="null"),file.path(root,tag,"sgn.json"),useBytes=TRUE)}
regional <- sgn_i18n("UK-ua",root)
check(regional$requested_locale(),"uk-UA","normalized request")
check(regional$locale(),"uk","parent disk fallback")
check(sgn_i18n("zz",root)$locale(),"en","missing installed language")
child <- clone(fixtures$catalogs$uk); child$locale <- "uk-UA";child$messages <- list("controls.save\004Save"=list(plural=NULL,forms=list("Регіональне збереження")))
parent <- sgn_i18n_from_payload(payload("uk-UA",list(fixtures$catalogs$uk,child)))
check(parent$p("controls.save","Save"),"Регіональне збереження","child overrides")
check(parent$p("seedlots.save","Save"),"Зберегти партію","parent missing-message fallback")
for (bad in list(-1,1.2,NA_real_,NaN,Inf,TRUE,"21",9007199254740992,1+0i,structure(1,class="owned_callback"))) reject(function() en$np("ctx","one","many",bad),"invalid count")
reject(function() uk$p("trial.named","Created trial %{name}.",list()),"missing variable")
reject(function() en$p("ctx","%{name}",list(name=c("a","b"))),"vector variable")
reject(function() sgn_i18n("../../secret",root),"unsafe locale")
reject(function() sgn_i18n("en",root,"../domain"),"unsafe domain")
bad <- clone(fixtures$catalogs$uk);bad$pluralAst <- list(type="EVAL",code="system('application code')")
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"executable AST rejected")
bad <- clone(fixtures$catalogs$uk);bad$pluralAst <- list(type="MOD",left=list(type="VAR"),right=list(type="NUM",val=0))
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"zero modulo rejected")
bad <- clone(fixtures$catalogs$uk);bad$pluralAst <- list(type="TERNARY",expr=list(type="VAR"),truthy=list(type="NUM",val=5),falsey=list(type="NUM",val=0))
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"all-count plural bounds")
bad <- clone(fixtures$catalogs$uk);bad$messages[["controls.save\004Save"]]$forms <- list()
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"incomplete singular rejected")
bad <- clone(fixtures$catalogs$uk);bad$messages[["trials.count\004%{count} trial found"]]$forms <- list("only one")
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"incomplete plural rejected")
bad <- clone(fixtures$catalogs$uk);bad$schema <- TRUE
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"boolean schema rejected")
for (field in c("schema","api","locale","direction","nplurals","pluralForms","pluralAst","messages")) {
    bad <- clone(fixtures$catalogs$uk)
    names(bad)[names(bad) == field] <- paste0(field,"Unexpected")
    reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),paste("exact required catalog field",field))
}
for (field in c("locale","domain","catalogs")) {
    bad_payload <- payload("uk")
    names(bad_payload)[names(bad_payload) == field] <- paste0(field,"Unexpected")
    reject(function() sgn_i18n_from_payload(bad_payload),paste("exact required payload field",field))
}
bad <- clone(fixtures$catalogs$uk)
record <- bad$messages[["controls.save\004Save"]]
names(record)[names(record) == "forms"] <- "formsUnexpected"
bad$messages[["controls.save\004Save"]] <- record
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"exact message forms field")
unnamed <- clone(fixtures$catalogs$uk);unnamed$languageNamesUnexpected <- list(secret="invalid")
check(sgn_i18n_from_payload(payload("uk",list(unnamed)))$language_name(),"uk","similar optional name field ignored")
normalized <- clone(fixtures$catalogs$uk);normalized$locale <- "UK"
check(sgn_i18n_from_payload(payload("uk",list(normalized)))$locale(),"uk","normalized effective locale")
reject(function() sgn_i18n_from_payload(payload("uk",list(normalized,fixtures$catalogs$uk))),"normalized duplicate catalog locale")
invalid_utf8 <- rawToChar(as.raw(c(195L,40L)));Encoding(invalid_utf8) <- "UTF-8"
reject(function() en$p("ctx",invalid_utf8),"invalid UTF-8 source")
reject(function() en$p("ctx","%{name}",list(name=invalid_utf8)),"invalid UTF-8 variable")
bad <- clone(fixtures$catalogs$uk);bad$messages[["controls.save\004Save"]]$forms <- list(invalid_utf8)
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"invalid UTF-8 catalog form")
bad <- clone(fixtures$catalogs$uk);bad$languageName <- invalid_utf8
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"invalid UTF-8 native name")
# Deliberately executable-looking metadata remains unused text. Its validated
# AST is still interpreted for plurals and no metadata expression is run.
bad <- clone(fixtures$catalogs$uk);bad$pluralForms <- "nplurals=3; plural=stop('CATALOG_TEXT_MUST_NOT_RUN');"
check(sgn_i18n_from_payload(payload("uk",list(bad)))$np("trials.count","%{count} trial found","%{count} trials found",2,list(count=2)),"Знайдено 2 досліди","informational plural text never evaluated")
# Payloads are data: S3-classed scalars/lists must be rejected before R can
# dispatch an application callback during coercion or message selection.
callback_ran <- FALSE
as.double.owned_callback <- function(...) { callback_ran <<- TRUE; 1 }
`[[.owned_callback` <- function(...) { callback_ran <<- TRUE; "modified" }
for (field in c("schema","api","nplurals")) {
    bad <- clone(fixtures$catalogs$uk);bad[[field]] <- structure(bad[[field]],class="owned_callback")
    reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),paste("classed catalog scalar rejected",field))
}
bad <- clone(fixtures$catalogs$uk);bad$messages[["controls.save\004Save"]]$forms <- structure(list("Зберегти"),class="owned_callback")
reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"classed catalog forms rejected")
check(callback_ran,FALSE,"catalog callback never invoked")
named <- clone(fixtures$catalogs$uk); named$languageName <- "Français"
check(sgn_i18n_from_payload(payload("uk",list(named)))$language_name(),"Français","valid native name")
named$languageName <- paste(rep("🌱",200),collapse="")
check(sgn_i18n_from_payload(payload("uk",list(named)))$language_name(),named$languageName,"Unicode native-name limit")
for (name in list("", " ",paste(rep("x",201),collapse=""),"bad\nname",list("name"))) {
    bad <- clone(fixtures$catalogs$uk);bad$languageName <- name
    reject(function() sgn_i18n_from_payload(payload("uk",list(bad))),"invalid native name")
}
for (type in c("OR","AND")) {
    logical <- clone(fixtures$catalogs[["pt-PT"]]); logical$locale <- "zz"
    logical$pluralForms <- if (type=="OR") "nplurals=2; plural=(n || 0);" else "nplurals=2; plural=(n && 5);"
    logical$pluralAst <- list(type=type,left=list(type="VAR"),right=list(type="NUM",val=if(type=="OR")0 else 5))
    translator <- sgn_i18n_from_payload(payload("zz",list(logical)))
    check(translator$np("trials.count","%{count} trial found","%{count} trials found",3,list(count=3)),"pt-PT[1] 3","GNU boolean operator")
}
maximum <- 9007199254740991
for (count in c(maximum,maximum-1,maximum-2,maximum-91,maximum-99,maximum-100)) {
    check(.sgn_i18n_mod(count,100), as.numeric(substr(sprintf("%.0f",count),15L,16L)),"exact safe-integer modulo100")
    check(.sgn_i18n_mod(count,2),if(substr(sprintf("%.0f",count),16L,16L)%in%c("0","2","4","6","8"))0 else 1,"exact safe-integer modulo2")
}
# Indexed files preserve the native R presentation contract and export shape.
bundle_root <- tempfile("sgn-i18n-sections-"); dir.create(file.path(bundle_root, "uk", "sgn"), recursive = TRUE)
parts <- list(); directory <- file.path(bundle_root, "uk", "sgn")
for (spec in list(c("common", "controls.save\004Save"), c("trial_card", "trials.count\004%{count} trial found"))) {
    catalog <- clone(fixtures$catalogs$uk); catalog$messages <- catalog$messages[spec[[2L]]]
    bytes <- charToRaw(toJSON(catalog, auto_unbox = TRUE, null = "null", digits = NA))
    writeBin(bytes, file.path(directory, paste0(spec[[1L]], ".json")))
    parts[[length(parts) + 1L]] <- list(name = spec[[1L]], sha256 = digest::digest(bytes, algo = "sha256", serialize = FALSE))
}
writeLines(toJSON(list(schema = 1, domain = "sgn", partitions = parts), auto_unbox = TRUE), file.path(directory, "index.json"), useBytes = TRUE)
sectioned <- sgn_i18n("uk-UA", bundle_root)
check(sectioned$p("controls.save", "Save"), "Зберегти", "R shared section")
check(sectioned$np("trials.count", "%{count} trial found", "%{count} trials found", 2, list(count = 2)), "Знайдено 2 досліди", "R own section and regional fallback")
check(length(sectioned$export_catalog()$catalogs), 1L, "R export remains one catalog per locale")
unlink(file.path(directory, "trial_card.json"))
check(sgn_i18n("uk", bundle_root)$np("trials.count", "%{count} trial found", "%{count} trials found", 2, list(count = 2)), "2 trials found", "R missing section English fallback")
check(sectioned$np("trials.count", "%{count} trial found", "%{count} trials found", 2, list(count = 2)), "Знайдено 2 досліди", "R active section snapshot")
writeLines("{}", file.path(directory, "common.json"))
reject(function() sgn_i18n("uk", bundle_root), "R partition hash mismatch")
unlink(bundle_root, recursive = TRUE)
# Tiny owned numerical fixture. Translation is presentation after calculation.
stocks <- data.frame(stock=c("𝛂_Seed_1","𝛃 Seed 2","Stock/A"),value=c(1.25,3.5,8.75),stringsAsFactors=FALSE)
before <- serialize(stocks,NULL); numerical <- mean(stocks$value); total <- sum(stocks$value)
invisible(uk$p("fixture.summary","Calculated %{count} stocks.",list(count=nrow(stocks))))
invisible(ar$np("fixture.count","%{count} stock","%{count} stocks",nrow(stocks),list(count=nrow(stocks))))
check(serialize(stocks,NULL),before,"numerical/stock data byte identity")
check(mean(stocks$value),numerical,"mean invariant");check(sum(stocks$value),total,"sum invariant")
check(Sys.getenv(),environment_before,"environment invariant");check(Sys.getlocale(),locale_before,"process locale invariant")
cat(toJSON(list(ok=TRUE,assertions=checks,numericalStockFixtureUnchanged=TRUE,environmentUnchanged=TRUE,processLocaleUnchanged=TRUE),auto_unbox=TRUE),"\n",sep="")
