


    function clearForm() {
        document.getElementById("sequence").value = null;
        document.getElementById("si_rna").value = 21;
        document.getElementById("f_length").value = 300;
	document.getElementById("mm").value = 0;
        document.getElementById("expr_file").value = null;
    }

    function openWin() {
        document.getElementById("tabs").style.display="inline";

	document.getElementById("help_fsize").innerHTML=f_length;
	document.getElementById("help_nmer").innerHTML=si_rna;
	document.getElementById("help_mm").innerHTML=mm;
	document.getElementById("help_db").innerHTML=db_name;

    	$(function() {
    	    $( "#tabs" ).tabs();
    	    $( "#tabs" ).dialog({
		draggable:true,
		resizable:false,
	        width:450,
		height:400,
	    	closeOnEscape:true,
	    	title: "SGN VIGS Tool Help",
	    });
        });
    }

    function runBt2(n_mer) {
	disable_ui();
	alert("hi");
        var seq = document.getElementById("sequence").value;
        document.getElementById("si_rna").value = n_mer;
        si_rna = n_mer;
        f_length = document.getElementById("f_length").value;
	mm = document.getElementById("mm").value;
        db = document.getElementById("bt2_db").value;
        expr_file = document.getElementById("expr_file").value;
	
	disable_ui();
//alert("seq: "+seq.length+", si_rna: "+si_rna+", f_length: "+f_length+", mm: "+mm+", db: "+db);

   	jQuery.ajax({
      	    url: '/tools/vigs/result/',
      	    async: false,
      	    method: 'POST',
      	    data: { 'sequence': seq, 'fragment_size': si_rna, 'seq_fragment': f_length, 'missmatch': mm, 'expr_file': expr_file, 'database': db },
	    success: function(response) { 
	        if (response.error) { 
		    alert("ERROR: "+response.error);
		} else {                             
//alert("EXPR: "+response.expr_file);
		    db_name = response.db_name;
		    bt2_res = response.jobid;
		    expr_file = response.expr_file;

		    getResults(1);
                }
            },
      	    error: function(response) { alert("An error occurred. The service may not be available right now.");}
	});
    }

    function getResults(status) {
	var t_info = "";

   	jQuery.ajax({
      	    url: '/tools/vigs/view/',
      	    async: false,
      	    method: 'POST',
      	    data: {'id': bt2_res, 'sequence': seq, 'fragment_size': si_rna, 'seq_fragment': f_length, 'missmatch': mm, 'targets': coverage, 'expr_file': expr_file, 'status': status},
	    success: function(response) { 
	        if (response.error) { 
		     alert("ERROR: "+response.error);
		} else {              
		    //alert("SCORE: "+response.score);      
		    hide_ui();

		    document.getElementById("hide1").style.display="inline";

		    if (+response.score > 0) {
		     	document.getElementById("score_p").innerHTML= "<b>Score:</b> "+response.score+" &nbsp;&nbsp;(-&infin;&mdash;100)<br />";
		     	document.getElementById("t_num").value = response.coverage
		    } else {
		        document.getElementById("no_results").innerHTML="Note: No results found!";
		    }

		    document.getElementById("hide2").style.display="inline";
		    document.getElementById("hide3").style.display="inline";
		     
		    //assign values to global variables
		    ids = response.ids;
    		    m_aoa = response.matches_aoa;
    		    score_array = response.all_scores;
		    best_score = response.score;
    		    expr_msg = response.expr_msg;
		    query_seq = response.query_seq;
		    seq_length = +query_seq.length;
		    best_start = response.cbr_start;
		    best_end = response.cbr_end;
		    best_seq = response.best_seq;
		    coverage = response.coverage;

		    document.getElementById("f_size").value = response.f_size;
		    document.getElementById("n_mer").value = si_rna;
		    document.getElementById("align_mm").value = response.missmatch;
		    document.getElementById("cbr_start").value = best_start;
		    document.getElementById("cbr_end").value = best_end;
		    document.getElementById("img_height").value = response.img_height;
		    
		    document.getElementById("collapse").value = 1;
		    document.getElementById("collapse").innerHTML = "Expand Graph";

		    document.getElementById("zoom").value = 0;
       		    document.getElementById("zoom").innerHTML = "Zoom In";
 
		    createMap(1,0);		     

		    if (+response.best_seq.length > 10) {
		     	document.getElementById("best_seq").innerHTML="<b>>best_target_region_("+best_start+"-"+best_end+")</b><br />"+best_seq;
		    } else {
		        document.getElementById("best_seq").innerHTML="<b>No results were found</b>";
		    }
 		    document.getElementById("query").innerHTML=response.query_seq;
		    hilite_sequence(response.cbr_start,response.cbr_end);

		    for (var i=0; i<response.ids.length; i=i+1) {
		     	t_info += response.ids[i][0]+" ("+response.ids[i][1]+")";
			t_info += "<br />";
		    }
		    document.getElementById("target_info").innerHTML=t_info;
		    document.getElementById("hide4").style.display="inline";
		    document.getElementById("hide5").style.display="inline";
                }
            },
      	    error: function(response) { alert("An error occurred2. The service may not be available right now.");}
	});
    }


    function createMap(collapsed,zoom) {
        var img_height = document.getElementById("img_height").value;
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
    	off_set_array = printSquares(collapsed,zoom);

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
//alert("expr: "+expr_msg[0][0]);
    	var ids_aoa = expr_msg; // aoa with subject ids
    	for (var t=0; t<ids_aoa.length;t++) {
            ctx.beginPath();
  	    ctx.fillStyle='#000000';
	    ctx.font="12px Arial";
  	    ctx.fillText(ids_aoa[t][0],5,off_set_array[t]+17);
    	    ctx.stroke();
        }
    	printScoreGraph(collapsed,zoom);    
    }  


    function printSquares(collapsed,zoom) {
        var coverage = document.getElementById("t_num").value;
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


    function printScoreGraph(collapsed,zoom) {
        var img_height = document.getElementById("img_height").value;

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
	     	final_seq = final_seq + leading_str + current_pos + ' ' + lines[i] + ' ' + leading_str2 + ( current_pos + line_length - 1) + '<br />';
	     } else {
	        final_seq = final_seq + leading_str + current_pos + ' ' + lines[i] + ' ' + leading_str2 + sequence.length + '<br />';
	     }

             current_pos += line_length;
          }

	  markup_el.innerHTML='<font face="courier" size="2">'+final_seq+'</font>';
    }


    function activateCollapse() {
 	document.getElementById("region_square").style.height="0px";
        var collapsed = document.getElementById("collapse").value;
        var zoom = document.getElementById("zoom").value;

        if (collapsed == 0) {
           document.getElementById("collapse").innerHTML = "Expand Graph";
       	   document.getElementById("collapse").value = 1;
	   collapsed = 1;
        } else {
       	   document.getElementById("collapse").innerHTML = "Collapse Graph";
       	   document.getElementById("collapse").value = 0;
	   collapsed = 0;
        }
    	createMap(+collapsed,+zoom);
	getCustomRegion();
    }

    function activateZoom() {
        var collapsed = document.getElementById("collapse").value;
        var zoom = document.getElementById("zoom").value;

        if (zoom == 0) {
           document.getElementById("zoom").innerHTML = "Zoom Out";
       	   document.getElementById("zoom").value = 1;
	   zoom = 1;
        } else {
       	   document.getElementById("zoom").innerHTML = "Zoom In";
       	   document.getElementById("zoom").value = 0;
	   zoom = 0;
        }
    	createMap(+collapsed,+zoom);
	getCustomRegion();
    }

//Function to change values of custom region by dragging the selection square

    function getSquareCoords() {
	var img_width = 700;
	var zoom = document.getElementById("zoom").value
    	var rev_xscale = +(seq_length/img_width); // to transform sequence length to pixels

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

	document.getElementById("cbr_start").value = cbr_start;
	document.getElementById("cbr_end").value = cbr_end;
	document.getElementById("f_size").value = fragment;

	var best_region = [cbr_start,cbr_end];
	hilite_sequence(cbr_start,cbr_end);
	printCustomSeq(cbr_start,cbr_end);
	
	if (score_array) {
	    printCustomScore(cbr_start,cbr_end);
	}
    }

//Prints custom sequence in Best Region field

    function printCustomSeq(cbr_start,cbr_end) {
	var best_seq_el = document.getElementById("best_seq");

	best_seq_el.innerHTML = "<b>>custom_region_("+cbr_start+"-"+cbr_end+")</b><br />";

	for (var i=cbr_start; i<cbr_end; i=i+60) {
	    if (cbr_end<i+61) {
		best_seq_el.innerHTML += query_seq.substring(i-1,cbr_end)+"<br />";
	    } else {
		best_seq_el.innerHTML += query_seq.substring(i-1,i+59)+"<br />";
	    }
	}
	best_seq_el.innerHTML += "<br /><b>>best_target_region_("+best_start+"-"+best_end+")</b><br />";
	best_seq_el.innerHTML += best_seq+"<br />";
    }


// Prints Scores
    function printCustomScore(start,end){
	var custom_score = 0;

	if (+end > seq_length) {end = seq_length;}
	if (+start < 1) {start = 1;}
		 
	if (score_array) {
	    for (var i=start-1; i<end; i++) {
	        custom_score += +score_array[i];
	    }
	}
	var fragment_length = (+end - +start + 1);

	if (coverage > 0 && fragment_length > 0) {
	    var final_score = ((custom_score*100/fragment_length)/coverage).toFixed(2)
	    document.getElementById("score_p").innerHTML= "<b>Score:</b> "+best_score+" &nbsp;&nbsp; <b> Custom Score: </b>"+final_score+" &nbsp;&nbsp; (-&infin;&mdash;100)";
	}
    }

// Creates the draggable selection square and modifies custom region when push a button

    function getCustomRegion() {
	var cbr_start = parseInt(document.getElementById("cbr_start").value);
	var cbr_end = parseInt(document.getElementById("cbr_end").value);
	var map_el = document.getElementById('myCanvas');

	var img_width = 700;
    	var xscale = +(+img_width/+seq_length); // to transform sequence length to pixels

	var zoom = document.getElementById("zoom").value;

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
	    document.getElementById("region_square").style.border="0px solid #000000";
	    document.getElementById("region_square").style.top="21px";
	    document.getElementById("region_square").style.background="rgba(80,100,100,0.3)";
	    document.getElementById("region_square").style.left=""+cbr_left+"px";
	    document.getElementById("region_square").style.width=""+cbr_width+"px";
	    document.getElementById("region_square").style.height=""+cbr_height+"px";

	   $(document).ready(function() {
    		$("div.region_square").resizable({
		    containment:map_el,
		    handles: 'e, w',
		    minWidth: 100*xscale,
		});

		$("div.region_square").draggable({
		    axis: 'x',
		    containment:map_el,
		    cursor: "move"
		});
	    });

			
	    document.getElementById("cbr_p").innerHTML = "";
	    var best_region = [cbr_start,cbr_end];
	    var fragment = (+cbr_end - +cbr_start +1);
	    document.getElementById("f_size").value = fragment;

	    hilite_sequence(cbr_start,cbr_end);

	    printCustomSeq(cbr_start,cbr_end);
			
	    if (score_array) {
		printCustomScore(cbr_start,cbr_end);
	    }

	} else {
	    document.getElementById("cbr_p").innerHTML = "Values must be between 1 and "+seq_length+", getting a sequence not shorter than 100 bp!";
	}
    }	


    function changeTargets() {
        var t_num = document.getElementById("t_num").value;
        var f_size = document.getElementById("f_size").value;
        var n_mer = document.getElementById("n_mer").value;
        var align_mm = document.getElementById("align_mm").value;

	if (n_mer != si_rna) {
	   // alert("I will run bowtie2 again");
	    mm = align_mm;
	    f_length = f_size;
	    coverage = t_num;

	    document.getElementById("f_length").value = f_length;
	    document.getElementById("mm").value = mm;
	    runBt2(n_mer);	            
	
	    document.getElementById("region_square").style.height="0px";
     
        } else if (align_mm != mm) {
	    mm = align_mm;
	    f_length = f_size;
	    coverage = t_num;
	    getResults(1);
	    getCustomRegion();		     
        } else if (t_num != coverage || f_size != f_length) {
	    f_length = f_size;
	    coverage = t_num;
	    getResults(0);
	    getCustomRegion();		     
	} else {
	    alert("there are no parameters to change");
	}
    }

function disable_ui() {
    $("input").prop("disabled", true);
    //$("usage_view").prop("disabled", true);
    $('#status_wheel').html('<img src="/static/documents/img/wheel.gif" />');
}

function hide_ui() {
    document.getElementById("status_wheel").style.display="none";
    $("#input_view").hide("blind");
    $("#usage_view").hide("blind");
    $("input").prop("disabled", false);

}


