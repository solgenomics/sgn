const path = require('path');

const sourcePath = path.resolve(__dirname, "source");
const testPath = path.resolve(__dirname, "tests");
const legacyPath = path.resolve(__dirname, "legacy/");

module.exports = {
    mode: "production",
    target: "web",
    entry: path.resolve(testPath, "bundleTests.js"),
    output: {
        path: path.resolve(__dirname, "test-build/"),
        filename: '[name].js'
    },
    module: {
        rules: [
            {
                test: /\.js$/,
                exclude: /(node_modules|bower_components)/,
                include: [sourcePath,testPath],
                use: [{
                    loader: 'babel-loader',
                    options: {
                        presets: ['@babel/preset-env']
                    }
                }]
            },
            {
                test: legacyPath,
                use: [{
                    loader: 'script-loader'
                }]
            }
        ]
    },
    optimization: {
        minimize: false,
    },
    node: {fs: 'empty'},
    devtool: "inline-source-map"
};
