const path = require('path');
const fs = require('fs');
const jsan_re = RegExp(
  fs.readFileSync(
    path.resolve(__dirname,"./JSAN/dependency.regex"), 
    "utf8"
  ).replace(/^[\s\n]+|[\s\n]+$/,""),
  'g'
);

function path_inside(parent, dir) {
    var relative_path = path.relative(parent, dir);
    return !!relative_path && !relative_path.startsWith('..') && !path.isAbsolute(relative_path);
}

function FileMapPlugin(options) {}

FileMapPlugin.prototype.apply = function(compiler) {
  compiler.plugin('emit', function(compilation,callback) {
    // Insert this list into the webpack build as a new file asset:
    var entrypoints = {};
    var legacy_lists = {};
    [...compilation.entrypoints].forEach((kvpair)=>{
      entrypoints[kvpair[0]] = {
        files: kvpair[1].chunks.reduce((a,chunk)=>a.concat(chunk.files),[]),
        legacy: []
      };
      entrypoints[kvpair[0]].files.forEach(f=>{
        legacy_lists[f] = legacy_lists[f] || [];
        legacy_lists[f].push(entrypoints[kvpair[0]].legacy);
      })
    });
    compilation.chunks.forEach(chunk=>{
      chunk.files.forEach(f=>{
        compilation.assets[f].source().replace(jsan_re,function(m,g1,g2){
          legacy_lists[f].forEach(leg_list=>leg_list.push(g1||g2))
        })
      });
    })
    var entrypoints_string = JSON.stringify(entrypoints,null,2);
    compilation.assets['mapping.json'] = {
      source: function() {
        return entrypoints_string;
      },
      size: function() {
        return entrypoints_string.length;
      }
    };
    
    callback();
  });
};

module.exports = FileMapPlugin;
