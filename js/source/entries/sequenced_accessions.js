
import '../legacy/jquery.js';
import '../legacy/jquery/dataTables.js';
import '../legacy/CXGN/Login.js';

export function init(main_div, stock_id, stockprop_id){

    if (!(main_div instanceof HTMLElement)){
	main_div = document.getElementById(
	    main_div.startsWith("#") ? main_div.slice(1) : main_div
	);
    }

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
			<div class="form-search">
	<form id="sequencing_info_form">

	  <div class="modal-content">

	    <div class="modal-header">
	      <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                 <div aria-hidden="true">&times;</div>
	      </button>

              <h5 class="modal-title">Enter sequencing info for accession:</h5>
	
    </div> <!-- modal-header -->

    <div class="modal-body">
	


        <div class="row">
     
            <label class="col-sm-3 control-label">Organization: </label>
            <div class="col-sm-9">                                  
                <input type="text" class="form-control" alt="Organization" placeholder="Sequencing organization" name="organization" id="organization" size="30" /><br />
 	    </div>

        </div>

       <div class="row">
    
	    <label class="col-sm-3 control-label">Year: </label>
	    <div class="col-sm-9">
	        <input type="text" class="form-control" placeholder="Sequencing year" name="sequencing_year" id="sequencing_year" size="6" /><br />
	    </div>
	</div>

    
	<div class="row">
    	    <label class="col-sm-3 control-label">Website: </label>
	    <div class="col-sm-9">
	        <div class="input-group">
                    <span class="input-group-addon" id="https-prefix">https:&sol;&sol;</span>
                    <input type="text" class="form-control" placeholder="Website" aria-label="https-prefix" aria-describedby="https-prefix" name="website"  id="website" size="10" />
        	</div>
	</div> <!-- input-group -->

         <br />
        </div>

    
	<div class="row">
    	    	    <label class="col-sm-3 control-label">Contact email: </label>
	    <div class="col-sm-9">	
    	        <input type="text" class="form-control" placeholder="Contact email" name="contact_email"  id="contact_email" size="10" /><br />
	    </div>
	</div>

    
	<div class="row">
   	    <label class="col-sm-3 control-label">Genbank accession: </label>
	    <div class="col-sm-9">
  	        <input type="text" class="form-control" placeholder="Genbank Accession" name="genbank_accession"  id="genbank_accession" size="10" /><br />
	    </div>
	</div>


    <div class="row">
	    <label class="col-sm-3 control-label">Funding agency: </label>
	    <div class="col-sm-9">
	        <input type="text" class="form-control" placeholder="Funding organization" name="funded_by"  id="funded_by" size="10" /><br />
   	    </div>
     </div>


    <div class="row">
    	<label class="col-sm-3 control-label">Funding agency project id: </label>
	    <div class="col-sm-9">
	        <input type="text" class="form-control" placeholder="Funding organization project ID"  name="funder_project_id" id="funder_project_id" size="10" /><br />
	    </div>

    </div>

    <div class="row">
    
        <label class="col-sm-3 control-label">JBrowse link: </label>
	<div class="col-sm-9">    
	    <input type="text" class="form-control" placeholder="Jbrowse link" name="jbrowse_link" id="jbrowse_link" size="20" /><br />
	</div>
     </div>
	

    <div class="row">

    	<label class="col-sm-3 control-label">BLAST link</label>
	<div class="col-sm-9">
	    <input type="text" class="form-control" placeholder="BLAST link" name="blast_link" id="blast_link" size="20" /><br />
	</div> 

    </div>
	
	
	<div>
	    <input type="hidden" id="stock_id"  name="stock_id" value="`+stock_id+`" />
	    <input type="hidden" id="stockprop_id"  name="stockprop_id" value="`+stockprop_id+`" />
	</div>



    </div> <!-- modal-body -->

       <div class="modal-footer">
             <button type="submit"  class="btn btn-primary">Save changes</button>
             <button id="dismiss_sequencing_info_dialog" type="button" class="btn btn-secondary" >Close</button>
       </div> <!-- modal-footer -->

    </div> <!-- modal-content -->

    
    </form> <!-- sequencing_info form -->
	       </div> <!-- form-search -->
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

    jQuery('#sequencing_info_form').submit(function(event) {

     	event.preventDefault();

     	var formdata = jQuery("#sequencing_info_form").serialize();
	//alert(formdata);
     	jQuery.ajax( {
     	    url : '/ajax/genomes/store_sequencing_info?'+formdata,
     	    success: function(r) {
     		if (r.error) { alert(r.error + r); }
     		else {
     		    alert("The entry has been saved. Thank you!");
     		    jQuery('#edit_sequencing_info_dialog').modal('toggle');
		    clear_dialog_entries();
		    jQuery('#sequenced_stocks_table').DataTable().ajax.reload();
     		}
     	    },
     	    error: function(r,e) {
		alert("An error occurred. (" +r.responseText+")" );
		var err = eval("(" + r.responseText + ")");
     	    }
     	});
    });

    jQuery('#dismiss_sequencing_info_dialog').click( function() {
	jQuery('#edit_sequencing_info_dialog').modal('toggle');
	clear_dialog_entries();
    });
}


function clear_dialog_entries() {
    jQuery('#organization').val(undefined);
    jQuery('#website').val(undefined);
    jQuery('#genbank_accession').val(undefined);
    jQuery('#funded_by').val(undefined);
    jQuery('#funder_project_id').val(undefined);
    jQuery('#contact_email').val(undefined);
    jQuery('#sequencing_year').val(undefined);
    jQuery('#publication').val(undefined);
    jQuery('#jbrowse_link').val(undefined);
    jQuery('#blast_db_id').val(undefined);
    jQuery('#stockprop_id').val(undefined);
    jQuery('#website').val(undefined);
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
		    jQuery('#sequenced_stocks_table').DataTable().ajax.reload();
		}
	    },
	    error: function(r) {
		alert("An error occurred. The entry was not deleted.");
	    }
	});
    }
}

export function edit_sequencing_info(stockprop_id) {
    //alert(stockprop_id);
    jQuery.ajax( {
	url : '/ajax/genomes/sequencing_info/'+stockprop_id,
	success : function(r) {
	    if (r.error) { alert(r.error); }
	    else {
		//alert(JSON.stringify(r));
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
