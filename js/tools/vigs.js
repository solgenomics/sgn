

function show_help_dialog(msg_id_num) {
    var msg_id;
    if (msg_id_num == 0) {
	alert(
	    "• The score value indicates how good is the yellow region to silence only the targets and avoiding off-targets. The closer to 100 the better is the value. In the same way, the custom score indicates the value of the custom region, represented by the transparent grey rectangle.\n\n"
	    +"• Set Custom Region button will activate a draggable and resizable transparent grey rectangle to select a custom region.\n\n"
	    +"• Change button will recalculate the results using the new parameters chosen. In case of changing the n-mer size, the algorithm will run Bowtie 2 again, so this process could take a while.\n\n"
	);
    }
    if (msg_id_num == 1) {
	alert(
	    "• Targets are shown in blue, off-targets in red, the yellow area highlights the region of highest score (for the selected fragment size).\n\n"
    	    +"• At the bottom the score graph shows score values in a red line over a black background. Score value = 0 is represented by the green line, under this line are represented the regions with more off-targets than targets, and the opposite when the score is over the green line.\n\n"

	    +"• Expand graph button will display every siRNA fragment aligned over the query for each subject.\n\n"
	    +"• Zoom button will zoom in/out the VIGS map representation.\n"
	);
    }
    if (msg_id_num == 2) {
	alert(
	    "• This section shows the best or the custom region sequence in FASTA format.\n\n"
	    +"• The custom region will update as the grey selection rectangle is moved.\n"
	);
    }
    if (msg_id_num == 3) {
        alert(
            "• In this section is shown your query sequence, highlighting in yellow the best or custom region.\n\n"
	    +"• The custom region will update as the grey selection rectangle is moved.\n"
	);
    }
    if (msg_id_num == 4) {
        alert(
            "• In this section is displayed each subject name, their number of matches over the query and their gene functional description.\n\n"
	    +"• The View link will open a draggable dialog with this information."
	);
    }
}


jQuery(document).ready(function () {
    var score_array;
    var seq;
    var seq_length;
    var bt2_file;
    var best_start;
    var best_end;
    var best_seq;
    var expr_msg;
    var expr_f;
    var ids;
    var m_aoa;


    jQuery('#upload_expression_file').click(function () {
	     
        seq = jQuery("#sequence").val();
	seq_length = seq.length;
        si_rna = jQuery("#si_rna").val();
        f_length = jQuery("#f_length").val();
	mm = jQuery("#mm").val();
        db = jQuery("#bt2_db").val();
	expr_f = jQuery('#expression_file').val();

	if (expr_f === '') {
	    bt2_file = runBt2(seq, si_rna, f_length, mm, db);
	    res = getResults(1, bt2_file, seq, si_rna, f_length, mm, 0, db, expr_f);    
  	    score_array = res[0];
	    seq = res[1];
	    best_seq = res[2];
	    expr_msg = res[3];
	    ids = res[4];
	    m_aoa = res[5];
	} else {
            jQuery("#upload_expression_form").submit();
	}
    });

    jQuery('#upload_expression_form').iframePostForm({
	json: true,
	post: function () {
    	},
        complete: function (response) {
            if (response.error) {
	        alert("The expression file could not be uploaded"+response.error);
		return;
            }
            if (response.success) {
        	expr_f = response.expr_file;

            	seq = jQuery("#sequence").val();
            	si_rna = jQuery("#si_rna").val();
            	f_length = jQuery("#f_length").val();
	    	mm = jQuery("#mm").val();
            	db = jQuery("#bt2_db").val();

		bt2_file = runBt2(seq, si_rna, f_length, mm, db);
		res = getResults(1, bt2_file, seq, si_rna, f_length, mm, 0, db, expr_f);
		score_array = res[0];
		seq = res[1];
		best_seq = res[2];
		expr_msg = res[3];
    		ids = res[4];
 		m_aoa = res[5];
            }
    	}
    });

    jQuery('#collapse').click(function () {
	activateCollapse(score_array,best_seq,seq,expr_msg,ids,m_aoa);
    });

    jQuery('#zoom').click(function () {
	activateZoom(score_array,best_seq,seq,expr_msg,ids,m_aoa);
    });

    jQuery('#set_custom').click(function () {
	getCustomRegion(score_array,best_seq,seq);
    });

    jQuery('#change_par').click(function () {
	res = changeTargets(seq,bt2_file,score_array,seq,best_seq,expr_f,ids,m_aoa);
	score_array = res[0];
	seq = res[1];
	best_seq = res[2];
	expr_msg = res[3];
	ids = res[4];
	m_aoa = res[5];
    });

    jQuery('#region_square').mouseup(function () {
	getSquareCoords(score_array,best_seq,seq);
    });
        
    jQuery('#open_descriptions_dialog').click(function () {
	jQuery('#dialog_info').replaceWith(jQuery('#target_info').clone());

        jQuery('#desc_dialog').dialog({
	    draggable:true,
	    resizable:false,
	    width:900,
	    minWidth:400,
	    maxHeight:400,
	    closeOnEscape:true,
	    title: "Gene Functional annotation",
	});
    });

    jQuery('#clear_form').click(function () {
        jQuery("#sequence").val(null);
        jQuery("#si_rna").val(21);
        jQuery("#f_length").val(300);
	jQuery("#mm").val(0);
        jQuery("#expression_file").val(null);
    });

    jQuery('#params_dialog').click(function () {
	alert(
	    "• Fragment size: "+jQuery("#help_fsize").val()+"\n"
	    +"• n-mer: "+jQuery("#help_nmer").val()+"\n"
	    +"• Mismatches: "+jQuery("#help_mm").val()+"\n"
	    +"• Database: "+jQuery("#db_name").val()+"\n"
	);
    });

    function runBt2(seq, si_rna, f_length, mm, db) {
	disable_ui();
	var bt2_file;
	var db_name;
	jQuery("#no_results").html("");

        //alert("seq: "+seq.length+", si_rna: "+si_rna+", f_length: "+f_length+", mm: "+mm+", db: "+db+", expr_file: "+expr_file);
   	jQuery.ajax({
      	    url: '/tools/vigs/result/',
      	    async: false,
      	    method: 'POST',
      	    data: { 'sequence': seq, 'fragment_size': si_rna, 'seq_fragment': f_length, 'missmatch': mm, 'database': db },
	    success: function(response) { 
	        if (response.error) { 
		    alert("ERROR: "+response.error);
		    enable_ui();
		} else {                        
		    db_name = response.db_name;
		    bt2_file = response.jobid;
                }
            },
      	    error: function(response) { alert("An error occurred. The service may not be available right now. Bowtie2 could not be executed");enable_ui();}
	});

	jQuery("#help_fsize").val(f_length);
	jQuery("#help_nmer").val(si_rna);
	jQuery("#help_mm").val(mm);
	jQuery("#db_name").val(db_name);

	return bt2_file;
    }


    function getResults(status, bt2_res, seq, si_rna, f_length, mm, coverage, db, expr_file) {
	var score_array;
	var best_seq;
	var expr_msg;
	var ids;
	var m_aoa;
	var t_info = "<tr><th>Gene</th><th>matches</th><th>Functional Description</th></tr>";
	jQuery("#no_results").html("");

        //alert("seq: "+seq.length+", si_rna: "+si_rna+", f_length: "+f_length+", mm: "+mm+", coverage: "+coverage+" db: "+db+", expr_file: "+expr_file);

   	jQuery.ajax({
      	    url: '/tools/vigs/view/',
      	    async: false,
      	    method: 'POST',
      	    data: {'id': bt2_res, 'sequence': seq, 'fragment_size': si_rna, 'seq_fragment': f_length, 'missmatch': mm, 'targets': coverage, 'expr_file': expr_file, 'status': status, 'database': db},
	    success: function(response) { 
	        if (response.error) { 
		     alert("ERROR: "+response.error);
		     enable_ui();
		} else {              
		    //alert("SCORE: "+response.score);      
		    hide_ui();

		    //assign values to global variables
    		    score_array = response.all_scores;
		    best_seq = response.best_seq;
    		    expr_msg = response.expr_msg;
		    var best_score = response.score;
		    var best_start = response.cbr_start;
		    var best_end = response.cbr_end;
		    seq = response.query_seq;
		    var seq_length = seq.length;
		    coverage = response.coverage;
		    ids = response.ids;
    		    m_aoa = response.matches_aoa;


		    if (+response.score > 0) {
		     	jQuery("#score_p").html("<b>Score:</b> "+best_score+" &nbsp;&nbsp;(-&infin;&mdash;100)<br />");
		     	jQuery("#t_num").val(coverage);
		    } else {
		        jQuery("#no_results").html("Note: No results found! Try again increasing the number of targets, decreasing the fragment size or modifing other parameters");
		    }
		    
		    //show result sections
		    jQuery("#hide1").css("display","inline");
		    
		    //assign values to html variables
		    jQuery("#coverage_val").val(coverage);
		    jQuery("#seq_length").val(seq_length);
		    jQuery("#f_size").val(response.f_size);
		    jQuery("#n_mer").val(si_rna);
		    jQuery("#align_mm").val(response.missmatch);
		    jQuery("#best_start").val(best_start);
		    jQuery("#best_end").val(best_end);
		    jQuery("#cbr_start").val(best_start);
		    jQuery("#cbr_end").val(best_end);
		    jQuery("#best_score").val(best_score);
		    jQuery("#img_height").val(response.img_height);
		    
		    //set collapse and zoom buttons
		    jQuery("#collapse").val(1);
		    jQuery("#collapse").html("Expand Graph");
		    jQuery("#zoom").val(0);
       		    jQuery("#zoom").html("Zoom In");

		    createMap(1,0,score_array,expr_msg,ids,m_aoa);

		    if (+best_seq.length > 10) {
		     	jQuery("#best_seq").html("<b>>best_target_region_("+best_start+"-"+best_end+")</b><br />"+best_seq);
		    } else {
		        jQuery("#best_seq").html("<b>No results were found</b>");
		    }
 		    jQuery("#query").html(seq);
		    hilite_sequence(best_start,best_end);
		    
		    var desc="";
		    var gene_name="";

		    for (var i=0; i<ids.length; i=i+1) {
			if (ids[i][2].match(/Niben/)) {
			    desc = ids[i][2].replace(/Niben\d+Scf[\:\.\d]+/,"");
			    gene_name = ids[i][0];
			} else if (ids[i][0].match(/Solyc/)) {
			    desc = ids[i][2].replace(/.+functional_description:/,"");
			    desc = desc.replace(/\"/g,"");
			    gene_name = ids[i][0].replace(/lcl\|/,"");
			}
		     	    t_info += "<tr><td>"+gene_name+"</td><td style='text-align:right;'>"+ids[i][1]+"</td><td>"+desc+"</td></tr>";
		    }

		    jQuery("#target_info").html(t_info);
		    jQuery("#hide2").css("display","inline");
		    jQuery("#hide3").css("display","inline");
                }
            },
      	    error: function(response) { alert("An error occurred. The service may not be available right now.");enable_ui();}
	});
	jQuery("#help_fsize").val(f_length);
	jQuery("#help_mm").val(mm);

	return [score_array,seq,best_seq,expr_msg,ids,m_aoa];
    }


    function createMap(collapsed,zoom,score_array,expr_msg,ids,m_aoa) {
        var img_height = +jQuery("#img_height").val();
    	var best_start = +jQuery("#best_start").val();
	var best_end = +jQuery("#best_end").val();
	var seq_length = +jQuery("#seq_length").val();
	var img_width = 700;
    	var xscale = +(700/seq_length); // to transform sequence length to pixels
    	var vline_tag = 100;

    	var c=document.getElementById("myCanvas");
    	var ctx=c.getContext("2d");

	if (collapsed) {
	    c.height = +(((ids.length)*35)+73);
	    img_height = c.height;
        } else {
	    c.height = +img_height;
        }
        if (seq_length < 700 || zoom) {
	    xscale = 1;
	    img_width = seq_length;
        }

        c.width = img_width;

        var cbr_start = +(best_start*xscale);
        var cbr_width = +((best_end-best_start)*xscale);
    
	//print black background
    	ctx.beginPath();
    	ctx.rect(0,(img_height-52),img_width,102);
    	ctx.fillStyle='rgb(30,30,30)';
    	ctx.fill();
    	ctx.stroke();

    	//print yellow rectangle for the best region
    	ctx.beginPath();
    	ctx.rect(cbr_start,0,cbr_width,img_height);
    	ctx.strokeStyle='yellow';
    	ctx.fillStyle='yellow';
    	ctx.fill();
    	ctx.stroke();
    
	//print the rectangles
        off_set_array = printSquares(collapsed,zoom,ids,m_aoa);

    	//print vertical lines and tick values
    	ctx.fillStyle='black';
    	ctx.lineWidth=1;
    	ctx.strokeStyle='rgb(200,200,200)';
    	ctx.font="10px Arial";
    	if (seq_length >=2700) {ctx.font="8px Arial";}
    	if (seq_length >=4500) {ctx.font="6px Arial";}

    	for (var l=100; l<seq_length; l+=100) {
    	    var i = l*xscale;
            ctx.beginPath();
    	    ctx.moveTo(i,15);
    	    ctx.lineTo(i,img_height);
    	    ctx.fillText(vline_tag,i-14,12);
    	    ctx.stroke();

    	    vline_tag+=100;
        }

        // print horizontal line under ticks
    	ctx.beginPath();
    	ctx.moveTo(0,20);
    	ctx.lineTo(img_width,20);
    	ctx.lineWidth=2;
    	ctx.strokeStyle='#000000';
    	ctx.stroke();

    	//print subject names
    	var ids_aoa = expr_msg; //aoa with subject ids
    	for (var t=0; t<ids_aoa.length;t++) {
            ctx.beginPath();
  	    ctx.fillStyle='#000000';
	    ctx.font="12px Arial";
  	    ctx.fillText(ids_aoa[t][0],5,off_set_array[t]+17);
    	    ctx.stroke();
        }
        printScoreGraph(collapsed,zoom,score_array,ids);    
    }  


    function printSquares(collapsed,zoom,ids,m_aoa) {
        var coverage = jQuery("#coverage_val").val();
	var seq_length = jQuery("#seq_length").val();

    	var xscale = +(700/seq_length); // to transform sequence length to pixels
        var img_width = 700;
    	var off_set = 20; //just under the horizontal line
	var coord_y = 0;
	
	var before_block = 20;
	var after_block = 10;
	
	if (collapsed) {
	    before_block = 25;
        }
	if (seq_length < 700 || zoom) {
	    xscale = 1;
	    img_width = seq_length;
        }

	var off_set_array = []; //to print names
	
    	var c=document.getElementById("myCanvas");
    	var ctx=c.getContext("2d");
	
	ctx.lineWidth=1;

        // each track
        for (var t=0; t<ids.length;t++) {
	    var max_row_num = 0; //to calculate the height of every track
	    off_set_array.push(off_set);
	    
	    off_set += before_block; //add some space for the names

    	    //target and off-target colors
	    if (t < coverage) {
    	        ctx.strokeStyle='rgb(0,0,180)';
    	        ctx.fillStyle='rgb(0,120,255)';
	    } else {
	        ctx.strokeStyle='rgb(150,0,0)';
		ctx.fillStyle='rgb(255,0,0)';
	    }
	    var row = 1;
	    var prev_match_end = 9999;
	    var prev_match_start = 0;
	    var collapsed_start = 0;
	    var collapsed_end = 0;

	    //each match (rectangles)
            for (var i=0; i<m_aoa[t].length;i++) {

    	    	var coord = m_aoa[t][i].split("-"); //array with start and end for every match
	    	m_width = +((+coord[1] - +coord[0] +1)*xscale); //rectangle width in pixels
	    	m_start = +(+coord[0]*xscale); //rectangle start in pixels
		
		//to allow as many rows as the n-mer size
		var match_distance = +(+coord[0] - +prev_match_start);
		if ((row < si_rna -1) && (coord[0] <= prev_match_end) && prev_match_end != 9999) {
		   if ((match_distance > 1) && ((+row + match_distance) > si_rna)) {
		       row = 1;
		   } else {
		       row++;
		   }
		} else {
		   row = 1;
		}
		
		if (!collapsed) {
		   coord_y = off_set + row*4;

 		   //print rectangles		
            	   ctx.beginPath();
    	    	   ctx.rect(m_start,coord_y,m_width,4);
    	    	   ctx.fill();
    	    	   ctx.stroke();

		} else {
		   if (collapsed_start == 0) {
		       collapsed_start = +coord[0];
		   }
		   if (+coord[0] < +prev_match_end) {
		       collapsed_end = prev_match_end;
		   } else {

 		       coord_y = off_set; //to collapse all rectangles of the track
		       if (collapsed_end == 9999) {collapsed_end = prev_match_end;}
		       var collapsed_width = (+collapsed_end - +collapsed_start + 1)*xscale;		      
		       
  		       //print rectangles		
            	       ctx.beginPath();
    	    	       ctx.rect(collapsed_start*xscale,coord_y,collapsed_width,4);
    	    	       ctx.fill();
    	    	       ctx.stroke();
		       
		       collapsed_start = coord[0];
		       collapsed_end = coord[1];
		   }
		}
		prev_match_end = +coord[1];
		prev_match_start = +coord[0];

		if (row > max_row_num) {max_row_num = row;} //get maximum number of rows per track to calculate the track height
	    }

	    if (!collapsed) {
	    	var track_height = (max_row_num*4)+after_block; 
	    	off_set += track_height; //add space for next track
     	    } else {
	        if (collapsed_end == 9999) {collapsed_end = prev_match_end;}
 		coord_y = off_set; //to collapse all rectangles of the track
		var collapsed_width = (+collapsed_end - +collapsed_start + 1)*xscale;

  		//print rectangles		
            	ctx.beginPath();
    	    	ctx.rect(collapsed_start*xscale,coord_y,collapsed_width,4);
    	    	ctx.fill();
    	    	ctx.stroke();

	        off_set += 10;
	    }

	    // print horizontal line under tracks
    	    ctx.beginPath();
    	    ctx.moveTo(0,off_set);
    	    ctx.lineTo(img_width,off_set);
    	    ctx.lineWidth=1;
    	    ctx.strokeStyle='rgb(200,200,200)';
    	    ctx.stroke();
        }
	return off_set_array;
    }


    function printScoreGraph(collapsed,zoom,score_array,ids) {
        var img_height = document.getElementById("img_height").value;
        var coverage = jQuery("#coverage_val").val();
	var seq_length = jQuery("#seq_length").val();

    	var xscale = +(700/seq_length); // to transform sequence legth to pixels
    	var img_h = +(img_height-52);
    	var img_width = 700;

    	if (collapsed) {
            img_h = +((ids.length*35)+21);
    	}
        if (seq_length < 700 || zoom) {
       	    xscale = 1;
       	    img_width = seq_length;
        }

    	var c=document.getElementById("myCanvas");
    	var ctx=c.getContext("2d");
    
	//print black background
    	ctx.beginPath();
    	ctx.rect(0,img_h,img_width,52);
    	ctx.globalAlpha = 0.7;
    	ctx.fillStyle='rgb(30,30,30)';
    	ctx.fill();
    	ctx.stroke();
    	ctx.globalAlpha = 1;

    	//print x axis (green line)
    	ctx.lineWidth=1;
    	ctx.beginPath();
    	ctx.strokeStyle='rgb(0,200,0)';
    	ctx.moveTo(0,(img_h+26));
    	ctx.lineTo(img_width,(img_h+26));
    	ctx.stroke();

        if (score_array) { 
    	    ctx.beginPath();
    	    ctx.moveTo(0,+img_h+25);
    	    ctx.strokeStyle='rgb(255,0,0)';
    
	    for (var i=0; i<score_array.length; i++) {
	        var xpos = (i+1)*xscale;
	    	var ypos = 0;
	 
		var final_score = (+score_array[i]*100/coverage).toFixed(2);

	        if (+final_score >= 0) {
	            ypos = 25-(+final_score*25/100)+2;
	        } else {
	            ypos = 50-(+final_score*25/100);
	        }
	        if (ypos > 50) {
	            ypos = 50;
	        }
  	        ctx.lineTo(xpos,img_h+ypos);
    	        ctx.stroke();
            }
        }
    }


// Highlights best region in Sequence Overview section
    function hilite_sequence(cbr_start,cbr_end) {
	 
	 var markup = new Text.Markup( { 'highlight' : [ '<span class="highlighted">', '</span>' ], 'break' : [ '<br />', '' ], 'space' : [ '<span>&nbsp;</span>', '' ] });

	 var source_el = document.getElementById('query');
	 var markup_el = document.getElementById('markup');

	 var hilite_regions=[];

	 if (cbr_end > 10) {
	     cbr_start = cbr_start-1;
	     if (cbr_start < 1) {
	 	cbr_start = 1;
	     }
	     hilite_regions.push(['highlight', cbr_start, cbr_end]);
	 }

	 var sequence = source_el.innerHTML;

	 var break_regions = [];
	 for (var i=0; i<sequence.length; i=i+60) {
	     break_regions.push([ 'break', i, i ]);
	 }

         var space_regions = [];
	 for (var i =0; i<sequence.length; i=i+10) {
	     space_regions.push(['space', i, i]);
         }

	 var all_regions = break_regions.concat(hilite_regions, space_regions);
	 var markedup_seq = markup.markup(all_regions, sequence);

         //insert line numbers
         var line_length = 60;
         var current_pos = 1;
	 var lines = markedup_seq.split('<br />');
         var final_seq = '';
	 var leading_spaces = new Array('', '', '', '', '', '');
	 
	 for (var i=1; i<lines.length; i++) {
             leading_str = leading_spaces.slice(0,Math.ceil(6-(Math.log(current_pos)/Math.log(10)))).join('&nbsp;'); // poor man's sprintf
	     leading_str2 = leading_spaces.slice(0,Math.ceil(6-(Math.log(current_pos +line_length -1)/Math.log(10)))).join('&nbsp;');

	     if (current_pos + line_length < sequence.length) {
	     	final_seq = final_seq + leading_str + current_pos +' '+ lines[i] +' '+ leading_str2 + ( current_pos + line_length - 1) +'<br />';
	     } else {
	        final_seq = final_seq + leading_str + current_pos + ' ' + lines[i] + ' ' + leading_str2 + sequence.length + '<br />';
	     }

             current_pos += line_length;
          }

	  markup_el.innerHTML='<font face="courier" size="2">'+final_seq+'</font>';
    }


    function activateCollapse(score_array,best_seq,seq,expr_msg,ids,m_aoa) {
 	document.getElementById("region_square").style.height="0px";
        var collapsed = jQuery("#collapse").val();
        var zoom = jQuery("#zoom").val();
	var seq_length = jQuery("#seq_length").val();

        if (collapsed == 0) {
           jQuery("#collapse").html("Expand Graph");
       	   jQuery("#collapse").val(1);
	   collapsed = 1;
        } else {
       	    jQuery("#collapse").html("Collapse Graph");
       	    jQuery("#collapse").val(0);
	   collapsed = 0;
        }
        createMap(+collapsed,+zoom,score_array,expr_msg,ids,m_aoa);
        getCustomRegion(score_array,best_seq,seq);
    }

    function activateZoom(score_array,best_seq,seq,expr_msg,ids,m_aoa) {
        var collapsed = jQuery("#collapse").val();
        var zoom = jQuery("#zoom").val();
	var seq_length = jQuery("#seq_length").val();

        if (zoom == 0) {
            jQuery("#zoom").html("Zoom Out");
       	    jQuery("#zoom").val(1);
	    zoom = 1;
        } else {
       	    jQuery("#zoom").html("Zoom In");
       	    jQuery("#zoom").val(0);
	    zoom = 0;
        }
        createMap(+collapsed,+zoom,score_array,expr_msg,ids,m_aoa);
        getCustomRegion(score_array,best_seq,seq);
    }

//Function to change values of custom region by dragging the selection square
    function getSquareCoords(score_array,best_seq,seq) {
	var img_width = 700;
	var seq_length = jQuery("#seq_length").val();
	var zoom = jQuery("#zoom").val();
    	var rev_xscale = +(seq_length/img_width); // to transform sequence length to pixels
	jQuery("#cbr_p").html("");

	if (+zoom || seq_length < 700) {
	   rev_xscale = 1;
	   img_width = seq_length;
	}

	var r_left = document.getElementById("region_square").style.left;
	var r_width = document.getElementById("region_square").style.width;
	var left_num = r_left.replace("px","");
	var right_num = r_width.replace("px","");
	var sqr_left = Math.round(+left_num*rev_xscale);
	var sqr_right = Math.round((+left_num + +right_num)*rev_xscale);

	var cbr_start = (+sqr_left + 1);
	var cbr_end = (+sqr_right);
	var fragment = (+cbr_end - +cbr_start +1);
		
	if (+cbr_end > seq_length) {cbr_end = seq_length;}
	if (+cbr_start < 1) {cbr_start = 1;}

	jQuery("#cbr_start").val(cbr_start);
	jQuery("#cbr_end").val(cbr_end);
	jQuery("#f_size").val(fragment);

	var best_region = [cbr_start,cbr_end];
	hilite_sequence(cbr_start,cbr_end);
        printCustomSeq(best_seq,seq);
	
	if (score_array) {
	    printCustomScore(cbr_start,cbr_end,score_array);
	}
    }

//Prints custom sequence in Best Region field
    function printCustomSeq(best_seq,seq) {
	var best_seq_el = document.getElementById("best_seq");
    	var cbr_start = +jQuery("#cbr_start").val();
	var cbr_end = +jQuery("#cbr_end").val();
    	var best_start = +jQuery("#best_start").val();
	var best_end = +jQuery("#best_end").val();

	best_seq_el.innerHTML = "<b>>custom_region_("+cbr_start+"-"+cbr_end+")</b><br />";

	for (var i=cbr_start; i<cbr_end; i=i+60) {
	    if (cbr_end<i+61) {
		best_seq_el.innerHTML += seq.substring(i-1,cbr_end)+"<br />";
	    } else {
		best_seq_el.innerHTML += seq.substring(i-1,i+59)+"<br />";
	    }
	}
	best_seq_el.innerHTML += "<br /><b>>best_target_region_("+best_start+"-"+best_end+")</b><br />";
	best_seq_el.innerHTML += best_seq+"<br />";
    }


// Prints Scores
    function printCustomScore(start,end,score_array){
	var custom_score = 0;
	var coverage = +jQuery("#coverage_val").val();
	var seq_length = +jQuery("#seq_length").val();
	var best_score = +jQuery("#best_score").val();

	if (+end > seq_length) {end = seq_length;}
	if (+start < 1) {start = 1;}
		 
	if (score_array) {
	    for (var i= +start-1; i< +end; i++) {
	        custom_score += +score_array[i];
	    }
	}

	var fragment_length = (+end - +start + 1);

	if (coverage > 0 && fragment_length > 0) {
	    var final_score = ((custom_score*100/fragment_length)/coverage).toFixed(2)
	    jQuery("#score_p").html("<b>Score:</b> "+best_score+" &nbsp;&nbsp; <b> Custom Score: </b>"+final_score+" &nbsp;&nbsp; (-&infin;&mdash;100)");
	}
    }


// Creates the draggable selection square and modifies custom region when push a button
    function getCustomRegion(score_array,best_seq,seq) {
	var cbr_start = +jQuery("#cbr_start").val();
	var cbr_end = +jQuery("#cbr_end").val();
	var map_el = document.getElementById('myCanvas');
	var seq_length = +jQuery("#seq_length").val();

	var img_width = 700;
    	var xscale = +(+img_width/+seq_length); // to transform sequence length to pixels

        var zoom = jQuery("#zoom").val();

	if (zoom == 1 || seq_length < 700) {
	    xscale = 1;
	    img_width = seq_length;
	}
	if (seq_length < 700) {document.getElementById("seq_map").style.width=""+seq_length+"px";}


	if ((cbr_start > 0) && (cbr_end <= seq_length) && (cbr_end >= cbr_start+99)) {
	    var cbr_left = Math.round((+cbr_start-1)*xscale);
	    var cbr_width = ((+cbr_end - +cbr_start +1)*xscale);

	    var cbr_height = (map_el.height - 21);

	    //a border will add pixels to all end coordinates
	    jQuery("#region_square").css("border","0px solid #000000");
	    jQuery("#region_square").css("top","21px");
	    jQuery("#region_square").css("background","rgba(80,100,100,0.3)");
	    jQuery("#region_square").css("left",cbr_left+"px");
	    jQuery("#region_square").css("width",cbr_width+"px");
	    jQuery("#region_square").css("height",cbr_height+"px");

    	    jQuery("#region_square").resizable({
		containment:map_el,
		handles: 'e, w',
		minWidth: 100*xscale,
	    });

	    jQuery("#region_square").draggable({
		axis: 'x',
		containment:map_el,
		cursor: "move"
	    });
			
	    jQuery("#cbr_p").html("");
	    var fragment = (+cbr_end - +cbr_start +1);
	    jQuery("#f_size").val(fragment);

	    hilite_sequence(cbr_start,cbr_end);

	    printCustomSeq(best_seq,seq);
			
	    if (score_array) {
		printCustomScore(cbr_start,cbr_end,score_array);
	    }

	} else {
	    jQuery("#cbr_p").html("Values must be between 1 and "+seq_length+", getting a sequence not shorter than 100 bp!");
	}
    }	


    function changeTargets(seq,bt2_file,score_array,seq,best_seq,expr_f,ids,m_aoa) {
        var t_num = jQuery("#t_num").val();
        var coverage = jQuery("#coverage_val").val();
        var f_size = jQuery("#f_size").val();
        var f_length = jQuery("#f_length").val();
        var n_mer = jQuery("#n_mer").val();
        var si_rna = jQuery("#si_rna").val();
        var align_mm = jQuery("#align_mm").val();
	var mm = jQuery("#mm").val();
        var db = jQuery("#bt2_db").val();
	var expr_msg;

	if (n_mer != si_rna) {
	    jQuery("#f_length").val(f_size);
	    jQuery("#mm").val(align_mm);
	    jQuery("#si_rna").val(n_mer);
	    jQuery("#coverage_val").val(t_num);

	    bt2_file = runBt2(seq, n_mer, f_size, align_mm, db);	            
	    res = getResults(1, bt2_file, seq, n_mer, f_size, align_mm, t_num, db, expr_f);
	    score_array = res[0];
	    seq = res[1];   
	    best_seq = res[2];
	    expr_msg = res[3];
       	    ids = res[4];
	    m_aoa = res[5];

	    document.getElementById("region_square").style.height="0px";
     
        } else if (align_mm != mm) {
	    jQuery("#f_length").val(f_size);
	    jQuery("#mm").val(align_mm);
	    jQuery("#coverage_val").val(t_num);

	    res = getResults(1, bt2_file, seq, n_mer, f_size, align_mm, t_num, db, expr_f);
	    score_array = res[0];
	    seq = res[1];   
	    best_seq = res[2];
	    expr_msg = res[3];
	    ids = res[4];
	    m_aoa = res[5];

	    getCustomRegion(score_array,best_seq,seq)
        } else if (t_num != coverage || f_size != f_length) {
	    jQuery("#f_length").val(f_size);
	    jQuery("#coverage_val").val(t_num);

	    res = getResults(0, bt2_file, seq, n_mer, f_size, align_mm, t_num, db, expr_f);
	    score_array = res[0];
	    seq = res[1];   
	    best_seq = res[2];
	    expr_msg = res[3];
	    ids = res[4];
	    m_aoa = res[5];

	    getCustomRegion(score_array,best_seq,seq)
	} else {
	    alert("there are no parameters to change");
	}
	return [score_array,seq,best_seq,expr_msg,ids,m_aoa]
    }

    function disable_ui() {
        jQuery("input").prop("disabled", true);
	jQuery('#status_wheel').html('<img src="/static/documents/img/wheel.gif" />');
    }

    function enable_ui() {
        jQuery("input").prop("disabled", false);
	jQuery('#status_wheel').html("");
    }


    function hide_ui() {
        document.getElementById("status_wheel").style.display="none";
	Effects.swapElements('vigs_input_offswitch', 'vigs_input_onswitch');
	Effects.hideElement('vigs_input_content');
	Effects.swapElements('vigs_usage_offswitch', 'vigs_usage_onswitch');
	Effects.hideElement('vigs_usage_content');
	jQuery("input").prop("disabled", false);
    }



});



