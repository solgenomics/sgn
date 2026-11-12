// Creates JSON dependency mapping from webpack compilation.

const fs = require('fs');

const PLUGIN_NAME = 'SGNFileMapPlugin';

class FileMapPlugin {
  constructor(options) {
    this.jsan_re = new RegExp(
      fs.readFileSync(options.legacy_regex, "utf8").replace(/^[\s\n]+|[\s\n]+$/g, ""),
      'g'
    );
  }

  apply(compiler) {
    const { Compilation } = compiler.webpack;
    const { RawSource } = compiler.webpack.sources;

    compiler.hooks.thisCompilation.tap(PLUGIN_NAME, (compilation) => {
      compilation.hooks.processAssets.tap(
        {
          name: PLUGIN_NAME,
          stage: Compilation.PROCESS_ASSETS_STAGE_REPORT
        },
        () => {
          const entrypoints = {};
          const legacy_lists = {};

          for (const [name, entrypoint] of compilation.entrypoints) {
            const files = entrypoint.chunks
              .reduce((a, chunk) => a.concat([...chunk.files]), [])
              .filter(f => f.endsWith(".js"));

            entrypoints[name] = { files, legacy: [] };

            files.forEach(f => {
              legacy_lists[f] = legacy_lists[f] || [];
              legacy_lists[f].push(entrypoints[name].legacy);
            });
          }

          for (const chunk of compilation.chunks) {
            for (const f of chunk.files) {
              const lists = legacy_lists[f];
              if (!lists) continue;

              const asset = compilation.getAsset(f);
              asset.source.source().replace(this.jsan_re, (m, g1, g2) => {
                lists.forEach(leg_list => leg_list.push(g1 || g2));
              });
            }
          }

          compilation.emitAsset(
            'mapping.json',
            new RawSource(JSON.stringify(entrypoints, null, 2))
          );
        }
      );
    });
  }
}

module.exports = FileMapPlugin;
