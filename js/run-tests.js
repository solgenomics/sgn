'use strict';

const process = require('process');
process.chdir( __dirname );

const webpack = require('webpack');
const JSDOM = require("jsdom").JSDOM;
const test = require('tape');
var fs = require('fs');
const del = require('del');
const path = require('path');
const glob = require("glob");
const nock = require('nock');
const fetch = require('node-fetch');

const { JSAN_to_src_path } = require("./webpack_util/utils.js");

const webpackConfig = require('./test.webpack.config');
const buildPath = path.resolve(__dirname, "./build_test/");
const legacyPath = path.resolve(__dirname, "./legacy/");

// Default DOM contents within which a test script is excecuted in.
const empty_html = `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <title></title>
  </head>
  <body></body>
  </html>
`;

// If the user provided globs, use them instead of running all tests.
if(process.argv.length>2){
  var targets = [].concat(...process.argv.slice(2).map(gt=>glob.sync(gt)))
    .map(p=>path.resolve(p));
  if(!targets.length) return console.error("No tests specified.");
  webpackConfig.entry = targets.reduce((dict,elt)=>{
    dict[elt] = elt
    return dict;
  },{});
}

// First test is always that the scripts build!
test('Webpack Build '+Object.keys(webpackConfig.entry).join(", "), function (t) {
  t.plan(1);
  // Remove old built tests
  del.sync([path.resolve(buildPath)]);
  // Run webpack
  webpack(webpackConfig).run((err,stats)=>{
    if(err) t.fail(err);
    else {
      var st = JSON.stringify(stats.toJson("minimal"));
      if(st.errors) t.fail(st);
      t.pass(st);
      // Once the scripts build, we can run the rest of the tests.
      runTests(JSON.parse(fs.readFileSync('./build_test/mapping.json')));
    }
  });
});

// Run each test file in a mapping (generated from webpack-filemap-plugin.js)
function runTests(mapping){
  // For each test file:
  Object.entries(mapping).map(kv=>{
    // Make unique list of all JSAN Deps resolved to their paths and chunk files
    return [...new Set(kv[1].legacy
      .map(jsan=>JSAN_to_src_path(legacyPath,jsan))
      .concat(kv[1].files.map(fn=>path.resolve(buildPath,fn))))];
  }).forEach(scrptList=>{
    // Run a JSDOM Virtual instance with all scripts and deps for each test file
    const dom = new JSDOM(empty_html, {
      url:"https://cassavabase.org/test.html",
      contentType: "text/html",
      includeNodeLocations: true,
      runScripts: "dangerously"
    });
    // Add window.test function to JSDOM window which hooks to the instance of
    // tape that is running in Node.js
    dom.window.test = test;
    // Add window.nock function to JSDOM window which allows for us to spoof AJAX calls
    // also clean up current mocked responses from previous tests
    dom.window.nock = nock;
    dom.window.fetch = fetch;
    nock.cleanAll();
    // Add script tags to JSDOM, these excute upon insertion (thereby running
    // the contained tests).
    scrptList.forEach(file=>{
      var src = fs.readFileSync(file)+'';
      var scrpt = dom.window.document.createElement('script');
      scrpt.innerHTML = src;
      dom.window.document.head.appendChild(scrpt);
    })
  });
}
