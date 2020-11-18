'use strict';

const process = require('process');
process.chdir( __dirname );

const webpack = require('webpack');
const JSDOM = require("jsdom").JSDOM;
const test = require('tape');
const { Console } = require('console');
var fs = require('fs');
const del = require('del');
const path = require('path');
const glob = require("glob");
const nock = require('nock');
const node_fetch = require('node-fetch');

const { JSAN_to_src_path } = require("./webpack_util/utils.js");

const webpackConfig = require('./test.webpack.config');
const buildPath = webpackConfig.output.path;
const legacyPath = path.resolve(__dirname, "./source/legacy/");

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
      runTests(JSON.parse(fs.readFileSync(path.resolve(buildPath,'./mapping.json'))));
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
    // Reference tape from the JSDOM window, by name defined in test.webpack.config
    dom.window[webpackConfig.externals.tape] = test;
    // Reference nock from the JSDOM window, by name defined in test.webpack.config
    // also clean up current mocked responses from previous tests
    dom.window[webpackConfig.externals.nock] = nock;
    nock.cleanAll();
    nock.disableNetConnect();
    // Polyfill JSDOM fetch using node-fetch
    dom.window.fetch = node_fetch;
    // Ensure console.log/info/debug statements inside virtual DOM print to stderr
    // by replacing the default console with one which routes to stderr
    // This ensures "pure" tap stdout
    dom.window.console = new Console({ stdout: process.stderr, stderr: process.stderr });
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
