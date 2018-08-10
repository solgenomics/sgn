
module.exports = function(import_text) {
	throw_err(this,import_text);
};

module.exports.pitch = function(import_text) {
	throw_err(this,import_text);
};

function throw_err(loader,import_text){
	var callback = loader.async();	
	var message = "Incorrectly included legacy code. (`"+import_text+"`) use ";
	message +=    "(`import \""+loader.resourcePath+"\";` or `require(\""+loader.resourcePath+"\");`)";
	callback(Error(message), null);
}
