'use strict';

const webpack = require('webpack');
const JSDOM = require("jsdom").JSDOM;
const test = require('tape');
var fs = require('fs');
const del = require('del');
const path = require('path');
const glob = require("glob");

const { JSAN_to_src_path } = require("./webpack_util/utils.js");

const webpackConfig = require('./test.webpack.config');
const buildPath = path.resolve(__dirname, "./build_test/");
const legacyPath = path.resolve(__dirname, "./legacy/");

if(process.argv.length>2){
  var targets = [].concat(...process.argv.slice(2).map(gt=>glob.sync(gt)))
    .map(p=>path.resolve(p));
  webpackConfig.entry = targets;
}

console.log(webpackConfig.entry)



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

test('Webpack Build', function (t) {
  t.plan(1);
  del.sync([path.resolve(buildPath,"/**")]);
  webpack(webpackConfig).run((err,stats)=>{
    if(err) t.fail(err);
    else {
      t.pass(JSON.stringify(stats.toJson("minimal")));
      runTests(JSON.parse(fs.readFileSync('./build_test/mapping.json')));
    }
  });
});

function runTests(mapping){
  Object.entries(mapping).map(kv=>{
    return kv[1].legacy
      .map(jsan=>JSAN_to_src_path(legacyPath,jsan))
      .concat(kv[1].files.map(fn=>path.resolve(buildPath,fn)))
  }).forEach(evalist=>{
    const dom = new JSDOM(empty_html, {
      contentType: "text/html",
      includeNodeLocations: true,
      runScripts: "dangerously"
    });
    dom.window.test = test;
    evalist.forEach(file=>{
      var src = fs.readFileSync(file)+'';
      var scrpt = dom.window.document.createElement('script');
      scrpt.innerHTML = src;
      dom.window.document.head.appendChild(scrpt);
    })
  });
}
