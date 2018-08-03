const path = require('path');
const JSAN_adaptor = path.resolve(__dirname, 'adaptor.js');

module.exports = function(src_path) {
	this.cacheable();
	return src_path_to_JSAN(src_path);
};
module.exports.pitch = function(src_path) {
	this.cacheable();
	return src_path_to_JSAN(src_path);
};

function src_path_to_JSAN(src_path){
	var relative_src_path = path.relative(path.resolve(__dirname, '../legacy'), src_path);
	var JSAN_id = relative_src_path.replace(/\.js$/,"").replace("/",".").replace(/^\.*/,"");
	return `
	require("${JSAN_adaptor}");
	JSAN.use("${JSAN_id}");
	`;
}
