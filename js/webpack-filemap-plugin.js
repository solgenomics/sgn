const path = require('path');
const fs = require('fs');

function path_inside(parent, dir) {
    var relative_path = path.relative(parent, dir);
    return !!relative_path && !relative_path.startsWith('..') && !path.isAbsolute(relative_path);
}

function FileMapPlugin(options) {
  this.jsan_re = RegExp(
    fs.readFileSync(
      options.legacy_regex, 
      "utf8"
    ).replace(/^[\s\n]+|[\s\n]+$/,""),
    'g'
  );
};

FileMapPlugin.prototype.apply = function(compiler) {
  var self = this;
  compiler.hooks.emit.tapAsync('SGNFileMapPlugin', function(compilation,callback) {
    var entrypoints = {};
    var legacy_lists = {};
    [...compilation.entrypoints].forEach((kvpair)=>{
      entrypoints[kvpair[0]] = {
        'files': kvpair[1].chunks.reduce((a,chunk)=>a.concat(chunk.files),[]).filter(f=>f.endsWith(".js")),
        'legacy': []
      };
      entrypoints[kvpair[0]].files.forEach(f=>{
        legacy_lists[f] = legacy_lists[f] || [];
        legacy_lists[f].push(entrypoints[kvpair[0]].legacy);
      })
    });
    compilation.chunks.forEach(chunk=>{
      chunk.files.forEach(f=>{
        compilation.assets[f].source().replace(self.jsan_re,function(m,g1,g2){
          legacy_lists[f].forEach(leg_list=>leg_list.push(g1||g2));
        })
      });
    });
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
