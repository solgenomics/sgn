
function run_blast(database_types, input_option_types) { 
  clear_status();
  update_status("Initializing run... ");

  jQuery('#prereqs').html('');
  jQuery('#blast_report').html('');

  var program  = jQuery('#program_select').val();
  var sequence = jQuery('#sequence').val();
  
  var msie = window.navigator.userAgent.indexOf("MSIE ");

  if (msie) {
    sequence = sequence.replace(/\s+/g, "\n");
  }

  var database = jQuery('#database').val();
  var evalue   = jQuery('#evalue').val();
  var matrix   = jQuery('#matrix').val();
  // var graphics = jQuery('#graphics').val(); //graphics?
  var maxhits  = jQuery('#maxhits').val();
  var filterq  = jQuery('#filterq').val();
  var input_option = jQuery('#input_options').val(); //input option is the format of the pasted sequenced
  
  if (sequence === '') { 
    alert("Please enter a sequence :-)"); 
    return;
  }
  
  if (!blast_program_ok(program,  input_option_types[input_option], database_types[database])) { 
    alert("The BLAST program does not match the selected database and query.");
    return;
  }
  
  update_status("Submitting job... ");
  
  var jobid ="";
  var seq_count = 0;
  disable_ui(); 

  jQuery.ajax( { 
    //async: false,
    url: '/tools/blast/run/',

    method: 'POST',
    data: { 'sequence': sequence, 'matrix': matrix, 'evalue': evalue, 'maxhits': maxhits, 'filterq': filterq, 'database': database, 'program': program, 'input_options': input_option, 'db_type': database_types[database]},
    success: function(response) { 
      if (response.error) { 
        enable_ui();
        alert(response.error);
        return;
      }
      else{
        jobid = response.jobid; 
        seq_count = response.seq_count;
        //alert("SEQ COUNT = "+seq_count);
        wait_result(jobid, seq_count);
      }
    },
    error: function(response) {
      alert("An error occurred. The service may not be available right now.");
      enable_ui();
      return;
    }
  });
}

function wait_result(jobid, seq_count) { 
  update_status('id='+jobid+' ');
  var done = false;
  var error = false;

  while (done == false) {
    
    jQuery.ajax({ 
      async: false,
      url: '/tools/blast/check/'+jobid,
      success: function(response) { 
        if (response.status === "complete") { 
          //alert("DONE!!!!");
          done = true;
          finish_blast(jobid, seq_count);
        }
        else { 
          update_status('.');
        }
      },
      error: function(response) { 
        alert("An  error occurred. "); 
        enable_ui(); 
        done=true; 
        error=true; 
      }
    });

  }
}

function finish_blast(jobid, seq_count) { 	

  update_status('Run complete.<br />');
  
  var format   =  jQuery('#parse_options').val() || [ 'Basic' ];
  
  //alert("FORMAT IS: "+format + " seqcount ="+ seq_count + "jobid = "+jobid);

  var blast_reports = new Array();
  var prereqs = new Array();

  if (seq_count > 1) { 
    format = [ "Table", "Basic" ];
    alert("Multiple sequences were detected. The output will be shown in the tabular and basic format");
  }

  var database = jQuery('#database').val();

  for (var n in format) { 
    update_status('Formatting output ('+format[n]+')<br />');

    jQuery.ajax( { 
      url: '/tools/blast/result/'+jobid,
      data: { 'format': format[n], 'db_id': database },
    
      success: function(response) { 
        if (response.blast_report) {
          var out_id = "#"+response.blast_format+"_output";
          // var out_id = "#"+response.blast_format.replace(" graph", "")+"_output";
          
          jQuery(out_id).html(response.blast_report+"<br><br>\n");
        }
        if (response.prereqs) { 
            prereqs.push(response.prereqs);
            jQuery('#prereqs').html(prereqs.join("\n\n<br />\n\n"));
        }

        jQuery('#jobid').html(jobid);

        Effects.swapElements('input_parameter_section_offswitch', 'input_parameter_section_onswitch'); 
        Effects.hideElement('input_parameter_section_content');
        jQuery('#download_basic').css("display", "inline");
        
        if (response.blast_format == "Table") {
          jQuery('#download_table').css("display", "inline");
        }
        jQuery('#notes').css("width","75%")
        enable_ui();
      },
      error: function(response) { alert("Parse BLAST: An error occurred. "+response.error); }
    });
  }
}

function disable_ui() { 
  jQuery('#myModal').modal({
    show: true,
    keyboard: false,
    backdrop: 'static'
  })
    // jQuery('#working').dialog("open");
}

function enable_ui() { 
  jQuery('#myModal').modal('hide');
    // jQuery('#working').dialog("close");
    clear_status();
}

function clear_input_sequence() { 
   jQuery('#sequence').val('');
}

function blast_program_ok(program, query_type, database_type) { 
  var ok = new Array();
  // query database program

  ok = { 'protein': { nucleotide : { tblastn: 1 }, protein : { blastp: 1 } }, 
          'nucleotide' : { nucleotide : { blastn: 1, tblastx: 1}, protein: { blastx: 1 } },
          'autodetect' : { nucleotide : { blastn: 1, tblastx: 1, tblastn: 1}, protein: { blastx: 1, blastp: 1 } } };

  return ok[query_type][database_type][program];
}

function download() { 
  var jobid = jQuery('#jobid').html();
  window.location.href= '/documents/tempfiles/blast/'+jobid+'.out';
}

function download_table() { 
  var jobid = jQuery('#jobid').html();
  window.location.href= '/documents/tempfiles/blast/'+jobid+'.out_tabular.txt';
}

function update_status(message) { 
  jQuery('#bs_working_msg').html(message);
}

function clear_status() { 
  jQuery('#bs_working_msg').html('');
}
