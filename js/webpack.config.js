const path = require('path');
const glob = require("glob");
const filemap = require(path.resolve(__dirname,"./webpack-filemap-plugin.js"));
const webpack = require("webpack");
const exec = require('child_process').exec;


module.exports = {
    // context: __dirname,
    mode: "production",
    entry: (() => {
        var entries = {};
        glob.sync(path.resolve(__dirname, "source/*.expose.js")).forEach(val => {
            var key = val.match(/([^\/]*)\.expose\.js$/)[1];
            entries[key] = val;
        });
        return entries;
    })(),
    output: {
        path: path.resolve(__dirname, "build"),
        publicPath: '/js',
        filename: '[name].js',
        library: ["jsMod", "[name]"],
        sourceMapFilename: "[name].js.map",
        libraryTarget: "umd"
    },
    module: {
        rules: [{
                test: path.resolve(__dirname, 'legacy'),
                use: {
                    loader: path.resolve(__dirname,"./webpack-legacy-jsan-adaptor.js"),
                }
            },
            {
                test: /\.js$/,
                exclude: /(node_modules|bower_components)/,
                include: path.resolve(__dirname, "source/"),
                use: {
                    loader: 'babel-loader',
                    options: {
                        presets: ['@babel/preset-env']
                    }
                }
            }
        ]
    },
    optimization: {
        minimize: false,
        splitChunks: {
            cacheGroups: {
                default: false,
                shared: {
                    minChunks: 2,
                    test: path.resolve(__dirname, "source/"),
                    chunks: "initial",
                    minSize: 1
                },
                async: {
                    minChunks: 2,
                    test: path.resolve(__dirname, "source/"),
                    chunks: "async",
                    minSize: 1
                }
            }
        }
    },
    devtool: false,
    plugins: [
        new filemap(),
        new webpack.SourceMapDevToolPlugin({})
    ],
};

// console.log(module.exports.entry())
//
