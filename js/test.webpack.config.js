const rootConfig = require("./build.webpack.config.js");
const merge = require('deepmerge');
const isPlainObject = require('is-plain-object');
const path = require('path');
const glob = require("glob");

const testPath = path.resolve(__dirname, "test");
const testBuildPath = path.resolve(__dirname, "build_test/");

module.exports = merge(rootConfig,{
  entry: (() => {
      var entries = [];
      glob.sync(path.resolve(testPath, "**/*.js")).forEach(val => {
          entries.push(val);
      });
      return entries;
  })(),
  output: {
    path: testBuildPath
  }
},{
	isMergeableObject: isPlainObject
});
