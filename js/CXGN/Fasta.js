/**

=head1 Fasta.js

AJAX object for building an AGI list and getting a Fasta file back, in XML format within <fasta> tags


=head1 AUTHOR

Chris Carpita <csc32@cornell.edu>

=cut

*/

JSAN.use("CXGN.Request");

//Hotlist is defined as a single object instead of a class. We can't have more than one!
var Fasta = window.Fasta || {};
Fasta = { //buttonId: id of the clicked button, for changing the button
	_agis: new Object,
	_agi_list: "",
	addAgi: function (agi) {
		Fasta._agis[agi] = 1;	
	},
	removeAgi: function (agi) {
		Fasta._agis[agi] = 0;
	},
	_build_string: function () {
		var new_string = '';
		var i = 0;
		for (var agi in Fasta._agis){
			if(Fasta._agis[agi] == 1){
				if(i>0) new_string += "::";
				new_string += agi;
				i++;
			}
		}
		Fasta._agi_list = new_string;
	},
	request: function (type){
		var req = new Request();
		if(req.isValid()){
			Fasta._build_string();
			var param = "agi_list=" + Fasta._agi_list + "&type=" + type;
			req.send("/scraps/fasta.pl", param, "POST");
		}
	},
	_response: function(doc) {
		doc.normalize();
		var fasta = doc.getElementsByTagName("fasta")[0].firstChild.nodeValue;
		var type = doc.getElementsByTagName("type")[0].firstChild.nodeValue;
		document.getElementById("hotlist_fasta_textarea").value = fasta;
		document.getElementById("hotlist_fasta_content").style.display = "block";
		
	}
}



