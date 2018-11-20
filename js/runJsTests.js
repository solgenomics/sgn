'use strict';

const JSDOM = require("jsdom").JSDOM;
const test = require('tape');
var fs = require('fs');
const path = require('path');
const mapping = require('./build/mapping.json');
const { JSAN_to_src_path } = require("./webpack_util/utils.js");
const legacyPath = path.resolve(__dirname, "legacy/");

Object.entries(mapping).filter(kv=>{
  return /^_tests\//.test(kv[0]);
}).map(kv=>{
  return kv[1].legacy
    .map(jsan=>JSAN_to_src_path(legacyPath,jsan))
    .concat(kv[1].files.map(fn=>path.resolve("./build/",fn)))
}).forEach(evalist=>{
  const dom = new JSDOM(`<body></body>`, {
    url: "https://testbase.org/",
    contentType: "text/html",
    includeNodeLocations: true,
    runScripts: "outside-only"
  });
  dom.window.test = test;
  evalist.forEach(file=>{
    var src = fs.readFileSync(file)+'';
    dom.window.eval(src);
  })
})
