const path = require('path');
const glob = require("glob");
const filemap = require(path.resolve(__dirname,"./webpack_util/webpack-filemap-plugin.js"));
const TerserPlugin = require("terser-webpack-plugin");

const sourcePath = path.resolve(__dirname, "source");
const entryPath = path.resolve(sourcePath, "entries");
const legacyPath = path.resolve(sourcePath, "legacy");

module.exports = {
    mode: "production",
    target: 'web',
    entry: (() => {
        var entries = {};
        glob.sync(path.resolve(entryPath, "**/*.js")).forEach(val => {
            var prekey = val.replace(entryPath+"/","");
            var key = prekey.match(/(.*)\.js$/)[1];
            entries[key] = val;
        });
        return entries;
    })(),
    // Give entries a common library name
    output: {
        path: path.resolve(__dirname, "build/"),
        publicPath: '/js',
        filename: '[name].min.js',
        chunkFilename: `chunk.[chunkhash].js`,
        library: ["jsMod","[name]"],
        libraryTarget: "umd"
    },
    // Set up babel and JSAN processing
    module: {
        rules: [
            {
                test: /\.js$/,
                exclude: /(node_modules|bower_components)/,
                use: [{
                    loader: 'babel-loader',
                    options: {
                        sourceType: "unambiguous",
                        presets: [['@babel/preset-env',{
                            "useBuiltIns": "usage",
			                "corejs": "3"
                        }]]
                    }
                },{
                    loader: path.resolve(__dirname,"./webpack_util/jsan-preprocess-loader.js"),
                    options:{'legacyPath':legacyPath}
                }]
            },
            {
                test: legacyPath,
                use: [{
                    loader: path.resolve(__dirname,"./webpack_util/jsan-error-loader.js")
                }]
            }
        ]
    },
    // Chunks and Minimization settings
    optimization: {
        minimize: true,
        namedChunks: true,
        minimizer: [new TerserPlugin({
            'sourceMap': true,
            'parallel': 4,
        })],
        runtimeChunk: {
            name: 'runtime'
        },
        splitChunks: {
            cacheGroups: {
                default: false,
                shared: {
                    minChunks: 2,
                    test: sourcePath,
                    chunks: "initial",
                    minSize: 1000
                },
                jsan: {
                    minChunks: 2,
                    test: path.resolve(__dirname, "webpack_util/adaptor.js"),
                    chunks: "all",
                    minSize: 1000
                },
                async: {
                    minChunks: 2,
                    test: sourcePath,
                    chunks: "async",
                    minSize: 1000
                }
            }
        }
    },
    devtool: "source-map",
    plugins: [new filemap({'legacy_regex':"./webpack_util/dependency.regex"})]
};
