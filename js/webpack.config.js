const path = require('path');
const glob = require("glob");
const filemap = require(path.resolve(__dirname,"./webpack-filemap-plugin.js"));
const webpack = require("webpack");
const exec = require('child_process').exec;

const sourcePath = path.resolve(__dirname, "source/");

module.exports = {
    mode: "production",
    entry: (() => {
        var entries = {};
        glob.sync(path.resolve(sourcePath, "*.expose.js")).forEach(val => {
            var key = val.match(/([^\/]*)\.expose\.js$/)[1];
            entries[key] = val;
        });
        return entries;
    })(),
    output: {
        path: path.resolve(__dirname, "build/"),
        publicPath: '/js',
        filename: '[name].min.js',
        library: ["jsMod", "[name]"],
        libraryTarget: "umd"
    },
    module: {
        rules: [
            {
                test: /\.js$/,
                exclude: /(node_modules|bower_components)/,
                include: sourcePath,
                use: {
                    loader: 'babel-loader',
                    options: {
                        presets: ['@babel/preset-env']
                    }
                }
            },
            {
                test: path.resolve(__dirname, 'legacy/'),
                use: {
                    loader: path.resolve(__dirname,"./JSAN/adaptor-loader.js"),
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
    plugins: [new filemap()],
};
