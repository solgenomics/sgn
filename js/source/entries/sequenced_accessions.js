
import '../../legacy/jquery.js';

export function init(main_div){
  if (!(main_div instanceof HTMLElement)){
    main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
  }  

    main_div.innerHTML = `

	<div id="sequenced_organism_div">
	
	<h4>Sequenced Organisms</h4>
	
	<table id="sequenced_organisms_table">
	</table>

    </div>
    
    

    `;



}

function get_accession_data() {
    $.ajax( {
	url : '/ajax/sequenced_stocks',
	success: function(e) {
	    alert('Success!');
	},
	error: function(e) {
	    alert('Error!');
	}
    };

	    


}
