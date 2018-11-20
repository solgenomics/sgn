const path = require('path');
const fs = require('fs');

const JSAN_adaptor = path.resolve(__dirname, 'adaptor.js');
const common_js_regex = /(?<=(?:[\r\n]+|^))\s*require *\( *(?:"(.*?)"|'(.*?)') *\) *;?\s*/g;
const import_regex = /(?<=(?:[\r\n]+|^))\s*import +(?:"(.*?)"|'(.*?)') *;?\s*/g;

function src_path_to_JSAN(legacy,src_path){
	src_path = path.resolve(__dirname, src_path);
	var relative_src_path = path.relative(legacy, src_path);
	var JSAN_id = relative_src_path
		.replace(/\.js$/,"")
		.replace(/\//g,".")
		.replace(/^\.*/,"");
	return `JSAN.use("${JSAN_id}");\n`;
}

function JSAN_to_src_path(legacy,jsan){
	var JSAN_path = jsan
		.replace(/^JSAN\.use\(["']/,"")
		.replace(/["']\);\s*$/,"")
		.replace(/\./g,"/")
		.replace(/(\.js)?$/,".js");
	src_path = path.resolve(legacy, JSAN_path);	
	return src_path;
}

function isChildOf(child, parent){
	child = path.resolve(__dirname, child);
	parent = path.resolve(__dirname, parent);
	if (child === parent) return false
	const parentTokens = parent.split('/').filter(i => i.length)
	const childTokens = child.split('/').filter(i => i.length)
	return parentTokens.every((t, i) => childTokens[i] === t)
}

module.exports = {
	'JSAN_adaptor':JSAN_adaptor,
	'common_js_regex':common_js_regex,
	'import_regex':import_regex,
	'src_path_to_JSAN':src_path_to_JSAN,
	'JSAN_to_src_path':JSAN_to_src_path,
	'isChildOf':isChildOf
};
