const path = require('path');
const fs = require('fs');
const loaderUtils = require('loader-utils');
const {
	JSAN_adaptor,
	common_js_regex,
	import_regex,
	src_path_to_JSAN,
	isChildOf } = require("./utils.js");
	
module.exports = function() {
	this.cacheable();
	const callback = this.async();	
	const options = loaderUtils.getOptions(this);
	var rpath = this.resourcePath;
	fs.readFile(rpath, function read(err, data) {
	    if (err) {
	        callback(err);
	    }
		var JSAN_adapt = "require('"+JSAN_adaptor+"');\n";
		var head = "";
		var replac_func = function(match,group1,group2){
			head = head || JSAN_adapt;
			var relpath = group1||group2;
			var src_path = path.resolve(path.dirname(rpath),relpath);
			return isChildOf(src_path,options.legacyPath) ? src_path_to_JSAN(options.legacyPath,src_path) : match;
		};
		var out = String(data).replace(import_regex,replac_func)
							  .replace(common_js_regex,replac_func);
		callback(null, head+out);
	});
};
