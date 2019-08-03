

import '../legacy/jquery.js';
import '../legacy/jquery/dataTables.js';

export function init(main_div, stock_id, stockprop_id){

    if (!(main_div instanceof HTMLElement)){
	main_div = document.getElementById(
	    main_div.startsWith("#") ? main_div.slice(1) : main_div
	);
    }  
    
    main_div.innerHTML = `
     <div>
	<table class="table table-condensed" cellspacing="20px" id="sequenced_stocks_table" >
	<thead>
        <tr>
        <th>Accession</th>
        <th>Year</th>
	<th>Organization</th>
        <th>Website</th>
	<th>Analyze</th>   
	<th>Manage</th>
        </tr>
	</thead>
	</table>
     </div>

	<!-- Dialog for adding sequencing info -->

    
      <div class="modal fade" id="edit_sequencing_info_dialog" role="dialog">
	<div class="modal-dialog" role="modal">

	  <div class="modal-content">
	
	    <div class="modal-header">
	      <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                 <div aria-hidden="true">&times;</div>
	      </button>
	
              <h5 class="modal-title">Enter sequencing info for accession:</h5>

	    </div> <!-- modal-header -->
	<form id="sequencing_info_form">
	    <div class="modal-body">

              <div class="form-search">
                <input type="text" class="form-control" alt="Organization" placeholder="Sequencing organization" name="organization" id="organization" size="30"/>
<br />
	        <input type="text" class="form-control mb-4" placeholder="Sequencing year" name="sequencing_year" id="sequencing_year" size="6"></input><br />
	        <div class="input-group">
                  <span class="input-group-addon" id="https-prefix">https:&sol;&sol;</span>
	          <input type="text" class="form-control" placeholder="Website" aria-label="https-prefix" aria-describedby="https-prefix" name="website"  id="website" size="10" />
	</div> <!-- input-group -->
	<br />
    	<input type="text" class="form-control" placeholder="Contact email" name="contact_email"  id="contact_email" size="10" />
	<br />
	<input type="text" class="form-control" placeholder="Genbank Accession" name="genbank_accession"  id="genbank_accession" size="10" />
	<br />
	<input type="text" class="form-control" placeholder="Funding organization" name="funded_by"  id="funded_by" size="10" />
	<br />
	<input type="text" class="form-control" placeholder="Funding organization project ID"  name="funder_project_id" id="funder_project_id" size="10" />
        <br />
               <div class="input-group mb-3">
	         <input type="text" class="form-control" placeholder="Jbrowse link" name="jbrowse_link" id="jbrowse_link" size="20"></input><br />
	       </div> <!-- input group -->
               <br />	
	       <div class="input-group mb-3">
	         <input type="text" class="form-control" placeholder="BLAST link" name="blast_link" id="blast_link" size="20"></input><br />
	</div> <!-- input group -->

    <input type="hidden" name="stock_id" value="`+stock_id+`" />
	<input type="hidden" name="stockprop_id" value="`+stockprop_id+`" />
             </div> <!-- form-search -->

	   </div> <!-- modal-body -->
	   <div class="modal-footer">
             <button id="save_sequencing_info_button" type="submit" class="btn btn-primary">Save changes</button>
             <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
	   </div> <!-- modal-footer -->
 	</form> <!-- sequencing_info form -->	
	 </div> <!-- modal-content -->
	</div> <!-- modal-dialog -->
	</div> <!-- modal -->


    `;

    var stock_param = "";
    if (stock_id !== undefined && stock_id !== null) {
	stock_param = "/"+stock_id;
	jQuery('#sequenced_stocks_table').DataTable( {
	    "ajax": '/ajax/genomes/sequenced_stocks'+stock_param
	});
    }
    else {
	jQuery('#sequenced_stocks_table').DataTable( {
	    "ajax": '/ajax/genomes/sequenced_stocks'
	});
    }

    jQuery("#sequencing_info_form").submit(function(event) {
	event.preventDefault();
	
	var formdata = jQuery("#sequencing_info_form").serializeArray();
	alert("FORMDATA = "+formdata);
	jQuery.ajax( {
	    url : '/ajax/genomes/store_sequencing_info',
	    data: formdata

	});
    });
	
}


