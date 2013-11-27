

function run_blast() { 
   var status = "Initializing run... ";
   jQuery('blast_status').html(status);

   var program  = jQuery('#program_select').val();
   var sequence = jQuery('#sequence').val();
   var database = jQuery('#database').val();
   var evalue   = jQuery('#evalue').val();
   var matrix   = jQuery('#matrix').val();
   var graphics = jQuery('#graphics').val();
   var maxhits  = jQuery('#maxhits').val();
   var filterq  = jQuery('#filterq').val();
   var input_option = jQuery('#input_options').val();
   var format   = jQuery('#parse_options').val() || [ 'Basic' ];

   if (sequence == '') { 
      alert("Please enter a sequence :-)"); 
      jQuery('blast_status').html('');
      return; 
   }

   if (!blast_program_ok(program,  input_option_types[input_option], database_types[database])) { 
      alert("The BLAST program does not match the selected database and query.");
      return;
   }

   status += "Submitting job... ";
   jQuery('#blast_status').html(status);

   disable_ui();

   var jobid ="";
   var seq_count = 0;

   jQuery.ajax( { 
      url:     '/tools/blast/run/',
      async:   false,
      method:  'POST',
      data:    { 'sequence': sequence, 'matrix': matrix, 'evalue': evalue, 'maxhits': maxhits, 
                 'filterq': filterq, 'database': database, 'program': program, 
                  'input_options': input_option 
               },
      success: function(response) { if (response.error) { alert("ERROR: "+response.error);
                                     enable_ui();
                                     return;
}
                                    else{ 
                                      
                                      jobid = response.jobid; 
                                      seq_count = response.seq_count;
            
                          // alert("JOB ID: "+jobid);
                                     }

                                  },

      error:   function(response) { alert("An error occurred. The service may not be available right now."); enable_ui(); return; }
   });

   status += 'id='+jobid+' ';
   jQuery('#blast_status').html(status);

   var done = false;
   var error = false;
   //alert("JOBID:   "+jobid);
   while (done == false) { 
      jQuery.ajax( { 
          url: '/tools/blast/check/'+jobid,
	  beforeSend: disable_ui(),
          success: function(response) { 
             if (response.status == "complete") { 
                //alert("DONE!!!!");
                done = true; 
             }
             else { 
                //alert("Status "+response.status);
            }
          },
          error: function(response) { alert("An  error occurred. "); enable_ui(); done=true; error=true;  }
     });
     status += '.';
     if (status.length > 80) { status += '<br />'; }
     jQuery('#blast_status').html(status);      

   }

   if (error) { return; }

   status = status +  " Run complete.";
   jQuery('#blast_status').html(status);
   jQuery('#blast_report').html('');

   var blast_reports = new Array();
   var prereqs = new Array();


   if (seq_count > 1) { 
     format = [ "Basic" ];
     alert("Multiple sequences were detected. The output will be shown in the basic format");
   }

   for (var n in format) { 
     //alert("Parsing format "+format[n]);

     jQuery.ajax( { 
       url: '/tools/blast/result/'+jobid,
       data: { 'format': format[n], 'db_id': database },
       
       success: function(response) { 
          if (response.blast_report) { 
              blast_reports.push(response.blast_report);
              //alert("BLAST report: "+response.blast_report);
          }
          if (response.prereqs) { 
              prereqs.push(response.prereqs);
	      jQuery('#prereqs').html(prereqs.join("\n\n<br />\n\n"));

	      jQuery('#blast_report').html(blast_reports.join("<hr />\n"));
	      
	      jQuery('#jobid').html(jobid);
	      
	      Effects.swapElements('input_parameter_section_offswitch', 'input_parameter_section_onswitch'); 
	      Effects.hideElement('input_parameter_section_content');
	      
	      enable_ui();

          }

       },
       error: function(response) { alert("Parse BLAST: An error occurred. "+response.error); }
     });
   }


}

function disable_ui() { 
   //jQuery('#program_select').attr("disabled", "disabled");
   //jQuery('#sequence').attr("disabled", "disabled");
   //jQuery('#database').attr("disabled", "disabled");
   //jQuery('#evalue').attr("disabled", "disabled");
   //jQuery('#matrix').attr("disabled", "disabled");
   //jQuery('#graphics').attr("disabled", "disabled");
   //jQuery('#maxhits').attr("disabled", "disabled");
   //jQuery('#filterq').attr("disabled", "disabled");
   //jQuery('#submit_button').attr("disabled", "disabled");
   //jQuery('#input_options').attr("disabled", "disabled");
   //jQuery('#dataset_select').attr("disabled", "disabled");
   //jQuery('#clear_button').attr("disabled", "disabled");
   //jQuery('#status_wheel').html('<img src="/static/documents/img/wheel.gif" />'); 

   jQuery('#working').dialog("open");

}

function enable_ui() { 
   //jQuery('#program_select').removeAttr("disabled");
   //jQuery('#sequence').removeAttr("disabled");
   //jQuery('#database').removeAttr("disabled");
   //jQuery('#evalue').removeAttr("disabled");
   //jQuery('#matrix').removeAttr("disabled");
   //jQuery('#graphics').removeAttr("disabled");
   //jQuery('#maxhits').removeAttr("disabled");
   //jQuery('#filterq').removeAttr("disabled");
   //jQuery('#submit_button').removeAttr("disabled");
   //jQuery('#input_options').removeAttr("disabled");
   //jQuery('#dataset_select').removeAttr("disabled");
   //jQuery('#clear_button').removeAttr("disabled");
   //jQuery('#status_wheel').html('');
    jQuery('#working').dialog("close");
}

function clear_input_sequence() { 
   jQuery('#sequence').val('');
}

function blast_program_ok(program, query_type, database_type) { 
   var ok = new Array();
   // query database program
   
   ok = { 'protein': { nucleotide : { tblastn: 1 }, protein : { 'blastp': 1 } }, 
          'nucleotide' : { nucleotide : { blastn: 1, tblastx: 1}, protein: { blastx: 1 } } };

   return ok[query_type][database_type][program];
}

function download() { 
   var jobid = jQuery('#jobid').html();

   if (jobid == '') { alert("No BLAST has been run yet. Please run BLAST before downloading."); return; }

   window.location.href= '/documents/tempfiles/blast/'+jobid+'.out';

}
