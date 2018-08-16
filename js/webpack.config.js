const path = require('path');
const glob = require("glob");
const filemap = require(path.resolve(__dirname,"./webpack-filemap-plugin.js"));
const webpack = require("webpack");
const exec = require('child_process').exec;
const UglifyWebpackPlugin = require("uglifyjs-webpack-plugin");

const sourcePath = path.resolve(__dirname, "source/");
const legacyPath = path.resolve(__dirname, "legacy/");

module.exports = {
    mode: "production",
    entry: (() => {
        var entries = {};
        glob.sync(path.resolve(sourcePath, "**/*.expose.jsm")).forEach(val => {
            var prekey = val.replace(sourcePath+"/","");
            var key = prekey.match(/(.*)\.expose\.jsm$/)[1];
            entries[key] = val;
        });
        return entries;
    })(),
    output: {
        path: path.resolve(__dirname, "build/"),
        publicPath: '/js',
        filename: '[name].min.js',
        library: ["jsMod","[name]"],
        libraryTarget: "umd"
    },
    module: {
        rules: [
            {
                test: /\.jsm$/,
                exclude: /(node_modules|bower_components)/,
                include: sourcePath,
                use: [{
                    loader: 'babel-loader',
                    options: {
                        presets: ['@babel/preset-env']
                    }
                },{
                    loader: path.resolve(__dirname,"./JSAN/jsan-preprocess-loader.js"),
                    options:{'legacyPath':legacyPath}
                }]
            },
            {
                test: legacyPath,
                use: [{
                    loader: path.resolve(__dirname,"./JSAN/jsan-error-loader.js")
                }]
            }
        ]
    },
    optimization: {
        minimize: true,
        minimizer: [new UglifyWebpackPlugin({ 
            'sourceMap': true,
            'parallel': 4,
            
        })],
        splitChunks: {
            cacheGroups: {
                default: false,
                shared: {
                    minChunks: 2,
                    test: sourcePath,
                    chunks: "initial",
                    minSize: 1
                },
                async: {
                    minChunks: 2,
                    test: sourcePath,
                    chunks: "async",
                    minSize: 1
                }
            }
        }
    },
    devtool: "source-map",
    plugins: [new filemap({'legacy_regex':"./JSAN/dependency.regex"})],
};
