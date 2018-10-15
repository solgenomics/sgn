# Javascript in SGN

## Modern JS
Modern (modularized) code is in the `source` folder. The code here uses import/export statements to keep the global scope clean. Modules in the `$REPO/js/entry` folder can be imported into a mason component, but cannot be tree shaken. Modules in the `$REPO/js/modules` folder can be tree shaken but not imported into a mason competent directly. Node modules can also be included from the node_modules folder using typical JS import syntax. Authors should prefer `import` over `require`, however, `require` is available (but not future-proof). Modules in the entry folder can be included into mason components using `<& /import_javascript, entries => ["myEntryName"] &>` where the array contains the relative path to the entry file from `$REPO/js/entry` without the `js` file extension. Once imported into a mason competent, Modern JS module exports are available within the window-scope variable`jsMod` as `jsMod[name]` where `name` is the same string used to import the entry module. (i.e. `jsMod["myEntryName"]`).

## Legacy JS

Legacy (no-module) code is in the `legacy` folder. **Legacy code is executed in the global scope, and adding to it should be avoided.** To include legacy JS on a page, one should use the mason `<& /util/import_javascript, legacy => ["CXGN.Effects", "CXGN.Phenome.Locus", "MochiKit.DOM"] &>` Where a file is specified by the relative path to a js file from the `$REPO/js/legacy` folder with slashes replaced by periods and no file extension (e.g. "$REPO/js/legacy/CXGN/Phenome/Locus.js" -> "CXGN.Phenome.Locus").

## Combining Legacy and Modern JS.

Legacy JS cannot import or depend on Modern JS and is always executed first. Modern JS can import legacy code for global effects (aka side-effects) by specifying the relative path to the file. `import "../../legacy/CXGN/Phenome/Locus.js";`. JSAN dependencies declared in legacy code _will_ be resolved. 

`/util/import_javascript` can import legacy code and entry modules in one statement. `<& /import_javascript, entries => [], legacy => [] &>`

## Testing

Testing is a work in progress.
