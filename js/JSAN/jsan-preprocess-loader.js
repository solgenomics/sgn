const path = require('path');
const fs = require('fs');
const loaderUtils = require('loader-utils');
const {
	JSAN_adaptor,
	common_js_regex,
	import_regex,
	src_path_to_JSAN,
	isChildOf } = require("./jsan-utils.js");
	
module.exports = function() {
	this.cacheable();
	const callback = this.async();	
	const options = loaderUtils.getOptions(this);
	fs.readFile(this.resourcePath, function read(err, data) {
	    if (err) {
	        callback(err);
	    }
		var JSAN_adapt = "require('"+JSAN_adaptor+"');\n";
		var head = "";
		var replac_func = function(match,group1,group2){
			head = head || JSAN_adapt;
			var path = group1||group2;
			return isChildOf(path,options.legacyPath) ? src_path_to_JSAN(options.legacyPath,path) : match;
		};
		var out = String(data).replace(import_regex,replac_func)
							  .replace(common_js_regex,replac_func);
		callback(null, head+out);
	});
};
