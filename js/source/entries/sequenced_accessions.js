
import '../../legacy/jquery.js';
import '../../legacy/jquery/dataTables.js';

export function init(main_div){
  if (!(main_div instanceof HTMLElement)){
    main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
  }  

    main_div.innerHTML = `

	<div id="sequenced_stocks_div">
	
	<h4>Sequenced Organisms</h4>
	
	<table id="sequenced_stocks_table">
	<thead>
            <tr>
                <th>Name</th>
                <th>Position</th>
                <th>Office</th>
                <th>Age</th>
                <th>Start date</th>
                <th>Salary</th>
            </tr>
        </thead>
	</table>

    </div>
    

    <script>

    $.window.ready( function() { 
	$('#sequenced_stocks_table').DataTable(
	    ajax: '/ajax/sequenced_accessions/list'

	);
    });

    
    
    </script>
    
    });
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
