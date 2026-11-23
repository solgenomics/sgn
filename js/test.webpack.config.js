const rootConfig = require("./build.webpack.config.js");
const merge = require('deepmerge');
const isPlainObject = require('is-plain-object');
const path = require('path');
const glob = require("glob");

const testPath = path.resolve(__dirname, "test");
// JavaScript tests also live in t/js, next to the other test files
const tPath = path.resolve(__dirname, "../t/js");
const testBuildPath = path.resolve(__dirname, "test_build/");

// Use the same config as the main build but change the settings below
module.exports = merge(rootConfig,{
  entry: (() => {
      var entries = {};
      [testPath, tPath].forEach(dir => {
          glob.sync(path.resolve(dir, "**/*.test.js")).forEach(val => {
              var prekey = val.replace(dir+"/","");
              var key = prekey.match(/(.*)\.js$/)[1];
              entries[key] = val;
          });
      });
      Object.setPrototypeOf(entries,null); //Make not a plain object
      return entries;
  })(),
  output: {
    path: testBuildPath
  },
  // tests in t/js find their modules here
  resolve: {
    modules: [path.resolve(__dirname, "node_modules"), "node_modules"]
  },
  externals: {
    tape: 'tape',
    nock: 'nock'
  }
},{
	isMergeableObject: isPlainObject
});
