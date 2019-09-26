
import '../legacy/jquery.js';
import '../legacy/jquery/dataTables.js';
import '../legacy/CXGN/Login.js';

export function init(main_div, stock_id, stockprop_id){

    if (!(main_div instanceof HTMLElement)){
	main_div = document.getElementById(
	    main_div.startsWith("#") ? main_div.slice(1) : main_div
	);
    }  

    alert("NOW: "+stock_id);
    // show the add button if the user is logged and and there we are on a stock page
    var button_html = "";
    if (isLoggedIn() && stock_id!==undefined) {
	button_html = `<button id="show_sequencing_info_dialog_button" class="btn btn-primary" data-toggle="modal" data-target="#edit_sequencing_info_dialog">Add sequencing info</button>`;
    }
    else {
	if (stock_id !== undefined) { 
	    button_html = `<button disabled id="show_sequencing_info_dialog_button" class="btn btn-primary" data-toggle="modal" data-target="#edit_sequencing_info_dialog">Add sequencing info</button>`;
	}
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
	
	<input id="stock_id"  name="stock_id" value="`+stock_id+`" />
	<input type="hidden" id="stockprop_id"  name="stockprop_id" value="`+stockprop_id+`" />
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


    `+button_html;

    
    
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
	
	var formdata = jQuery("#sequencing_info_form").serialize();
	alert(formdata);
	jQuery.ajax( {
	    url : '/ajax/genomes/store_sequencing_info?'+formdata
	});
    });


}

export function delete_sequencing_info(stockprop_id) {
    var answer = confirm("Are you sure you want to delete this entry? (stockprop_id= "+stockprop_id+"). This action cannot be undone.");
    if (answer) {
	jQuery.ajax( {
	    url : '/ajax/genomes/sequencing_info/delete/'+stockprop_id,
	    success: function(r) {
		if (r.error) { alert(r.error); }
		else { 
		    alert("The entry has been deleted.");
		}
	    },
	    error: function(r) {
		alert("An error occurred. The entry was not deleted.");
	    }
	});
    }
}

export function edit_sequencing_info(stockprop_id) {
    alert(stockprop_id);
    jQuery.ajax( {
	url : '/ajax/genomes/sequencing_info/'+stockprop_id,
	success : function(r) {
	    if (r.error) { alert(r.error); }
	    else {
		alert(JSON.stringify(r));
		jQuery('#organization').val(r.data.organization);
		jQuery('#website').val(r.data.website);
		jQuery('#genbank_accession').val(r.data.genbank_accession);
		jQuery('#funded_by').val(r.data.funded_by);
		jQuery('#funder_project_id').val(r.data.funder_project_id);
		jQuery('#contact_email').val(r.data.contact_email);
		jQuery('#sequencing_year').val(r.data.sequencing_year);
		jQuery('#publication').val(r.data.publication);
		jQuery('#jbrowse_link').val(r.data.jbrowse_link);
		jQuery('#blast_db_id').val(r.data.blast_db_id);
		jQuery('#stockprop_id').val(r.data.stockprop_id);
		jQuery('#stock_id').val(r.data.stock_id);
		jQuery('#website').val(r.data.website);
		jQuery('#edit_sequencing_info_dialog').modal("show");
	    }
	},
	error : function(r) { alert("an error occurred"); }
    });
    


}

