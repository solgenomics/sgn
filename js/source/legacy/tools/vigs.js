

$(document).ready(function () {
	
	//safari_alert();
	
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
	var temp_file;
	var n_mer;
	var si_rna;
	
	//start the tool when click on Run VIGS Analysis
	$('#upload_expression_file').click(function () {
		
		//get the expression file from the web input form
		expr_f = $('#expression_file').val();
		$("#region_square").css("height","0px");
		
		//submit the form
		$("#upload_expression_form").submit();
    });

	//get the expression file from the form (in a iframe) and start the analysis
	$('#upload_expression_form').iframePostForm({
		json: true,
		post: function () {
		},
		complete: function (response) {
			if (response.error) {
				alert("The expression file could not be uploaded"+response.error);
			}
			if (response.success) {
				expr_f = response.expr_file;
				
				//get the arguments from the HTML elements
				seq = $("#sequence").val();
				si_rna = $("#si_rna").val();
				f_length = $("#f_length").val();
				mm = $("#mm").val();
				db = $("#bt2_db").val();
				
				//Run Bowtie2
				runBt2(si_rna, f_length, mm, db);
			}
		}
	});

	//expand/collapse the n-mers graph when click on 'Collapse Graph' button
	$('#collapse').click(function () {
		activateCollapse(score_array,best_seq,seq,expr_msg,ids,m_aoa);
	});

	//zoom in/out the n-mers graph when click on 'Zoom' button
	$('#zoom').click(function () {
		activateZoom(score_array,best_seq,seq,expr_msg,ids,m_aoa);
	});

	//display custom region selection rectangle when click on 'Set Custom Region' button
	$('#set_custom').click(function () {
		getCustomRegion(score_array,best_seq,seq);
	});

	$('#change_par').click(function () {
		res = changeTargets(bt2_file,score_array,seq,best_seq,expr_f,ids,m_aoa);
		score_array = res[0];
		seq = res[1];
		best_seq = res[2];
		expr_msg = res[3];
		ids = res[4];
		m_aoa = res[5];
	});

	$('#region_square').mouseup(function () {
		getSquareCoords(score_array,best_seq,seq);
	});
        
	$('#open_descriptions_dialog').click(function () {
		$('#dialog_info').replaceWith($('#target_info').clone());

		$('#desc_dialog').dialog({
			draggable:true,
			resizable:true,
			width:900,
			minWidth:400,
			maxHeight:400,
			closeOnEscape:true,
			title: "Gene Functional annotation",
		});
	});

	$('#params_dialog').click(function () {
		
		$('#params').html("&bull;&nbsp;<b>Fragment size: </b>"+$("#help_fsize").val()+"<br /> \
		&bull;&nbsp;<b>n-mer: </b>"+$("#help_nmer").val()+"<br /> \
		&bull;&nbsp;<b>Mismatches: </b>"+$("#help_mm").val()+"<br />\
		&bull;&nbsp;<b>Database: </b>"+$("#db_name").val());

		$('#params').dialog({
			draggable:true,
			resizable:false,
			width:500,
			closeOnEscape:true,
			title: "Parameters used",
		});
	});

	$('#help_dialog_1').click(function () {
		
		$('#help_dialog_tmp').html("&bull;&nbsp;The best target region score value indicates how good the yellow highlighted region is, taking into account the number of target and off-target n-mers. \
			The closer to 100 the better is the value. In the same way, the custom region score indicates the value of the custom region, represented by the transparent grey rectangle.<br/> \
			&bull;&nbsp;Set Custom Region button will activate a draggable and resizable transparent grey rectangle to manually select a custom region.<br/> \
			&bull;&nbsp;Change button will recalculate the results using the new parameters chosen. In case of changing the n-mer size, the algorithm will run Bowtie 2 again, so this process could take a while.");

		$('#help_dialog_tmp').dialog({
			draggable:true,
			resizable:false,
			width:500,
			closeOnEscape:true,
			title: "Modify parameters help",
		});
	});

	$('#help_dialog_2').click(function () {
		
		$('#help_dialog_tmp').html("&bull;&nbsp;N-mers mapping to the target/s are shown in blue and to off-targets in red. The yellow area highlights the region with the highest score using the selected parameters<br/> \
			&bull;&nbsp;The bottom graph represents in red the score values along the sequence. The score value = 0 is indicated with a green line. \
			Below this line are represented the regions with more off-targets than targets, and the opposite when the score is above the green line.<br/> \
			&bull;&nbsp;Expand graph button will display every n-mer fragment aligned over the query for each subject.<br /> \
			&bull;&nbsp;Zoom button will zoom in/out the VIGS map representation.");

		$('#help_dialog_tmp').dialog({
			draggable:true,
			resizable:false,
			width:500,
			closeOnEscape:true,
			title: "Distribution of n-mers help",
		});
	});

	$('#help_dialog_3').click(function () {
		
		$('#help_dialog_tmp').html("&bull;&nbsp;This section shows the best or the custom region sequence in FASTA format.<br/> \
			&bull;&nbsp;The custom region will update as the grey selection rectangle is moved.");

		$('#help_dialog_tmp').dialog({
			draggable:true,
			resizable:false,
			width:500,
			closeOnEscape:true,
			title: "Best region help",
		});
	});

	$('#help_dialog_4').click(function () {
		
		$('#help_dialog_tmp').html("&bull;&nbsp;In this section is shown the query sequence, highlighting the best target region in yellow or the custom region in grey.<br/> \
			&bull;&nbsp;The custom region will be updated as the grey selection rectangle is moved.");

		$('#help_dialog_tmp').dialog({
			draggable:true,
			resizable:false,
			width:500,
			closeOnEscape:true,
			title: "Sequence overview help",
		});
	});

	$('#help_dialog_5').click(function () {
		
		$('#help_dialog_tmp').html("&bull;&nbsp;Number of n-mer matches and gene functional description are shown for each matched gene.<br/> \
			&bull;&nbsp;The View link will open a draggable dialog with this information.");

		$('#help_dialog_tmp').dialog({
			draggable:true,
			resizable:false,
			width:500,
			closeOnEscape:true,
			title: "Description of genes mapped help",
		});
	});

	$('#clear_form').click(function () {
		$("#sequence").val(null);
		$("#si_rna").val(21);
		$("#f_length").val(300);
		$("#mm").val(0);
		$("#expression_file").val(null);
	});

	$('#working').dialog( { 
		height: 100,
		width:  50,
		modal: true,
		autoOpen: false,
		closeOnEscape: false,
		draggable: false,
		resizable: false,
		open: function() { $(this).closest('.ui-dialog').find('.ui-dialog-titlebar-close').hide(); },
		title: 'Working...'
	});
	
	// sent the data to the controller to run bowtie2 and parse the results
	function runBt2(si_rna, f_length, mm, db) {
		var db_name;
		
		$("#no_results").html("");
		// alert("seq: "+seq.length+", si_rna: "+si_rna+", f_length: "+f_length+", mm: "+mm+", db: "+db+", expr_file: "+expr_file);
		$.ajax({
			url: '/tools/vigs/result/',
			// async: false,
			timeout: 600000,
			method: 'POST',
			data: { 'tmp_file_name': temp_file, 'sequence': seq, 'fragment_size': si_rna, 'seq_fragment': f_length, 'missmatch': mm, 'database': db },
			beforeSend: function(){
				disable_ui();
			},
			success: function(response) {
				if (response.error) { 
					alert("ERROR: "+response.error);
					enable_ui();
				} else {
					db_name = response.db_name;
					bt2_file = response.jobid;
					
					$("#help_fsize").val(f_length);
					$("#help_nmer").val(si_rna);
					$("#help_mm").val(mm);
					$("#db_name").val(db_name);
					
					getResults(1, bt2_file, si_rna, f_length, mm, 0, db, expr_f);
				}
			},
			error: function(response) {
				alert("An error occurred. The service may not be available right now. Bowtie2 could not be executed");
				//safari_alert();
				enable_ui();
			}
		});
	}


	function getResults(status, bt2_res, si_rna, f_length, mm, coverage, db, expr_file) {
		
		var t_info = "<tr><th>Gene</th><th>Matches</th><th>Functional Description</th></tr>";
		$("#no_results").html("");

		$.ajax({
			url: '/tools/vigs/view/',
			// async: false,
			timeout: 600000,
			method: 'POST',
			data: {'id': bt2_res, 'sequence': seq, 'fragment_size': si_rna, 'seq_fragment': f_length, 'missmatch': mm, 'targets': coverage, 'expr_file': expr_file, 'status': status, 'database': db},
			complete: function(){
				enable_ui();
				hide_ui();
			},
			success: function(response) { 
				if (response.error) { 
					alert("ERROR: "+response.error);
					enable_ui();
				} else {
					
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
					
					$("#score_p").html("<b>Best target region score:</b> "+best_score+" &nbsp;&nbsp;(-&infin;&mdash;100)<br />");
					$("#t_num").val(coverage);

					if (+response.score < 0) {
						$("#no_results").html("Note: The score value is very low!. Increasing the number of targets or the n-mer length, or decreasing the mismatches the score value will increase");
					}
					
					//show result sections
					$("#hide1").css("display","inline");

					//assign values to html variables
					$("#coverage_val").val(coverage);
					$("#seq_length").val(seq_length);
					$("#f_size").val(response.f_size);
					$("#n_mer").val(si_rna);
					$("#align_mm").val(response.missmatch);
					$("#best_start").val(best_start);
					$("#best_end").val(best_end);
					$("#cbr_start").val(best_start);
					$("#cbr_end").val(best_end);
					$("#best_score").val(best_score);
					$("#img_height").val(response.img_height);

					//set collapse and zoom buttons
					$("#collapse").val(1);
					$("#collapse").html("Expand Graph");
					$("#zoom").val(0);
					$("#zoom").html("Zoom In");

					createMap(1,0,score_array,expr_msg,ids,m_aoa);

					if (+best_seq.length > 10) {
						$("#best_seq").html("<b>>best_target_region_("+best_start+"-"+best_end+")</b><br />"+best_seq);
					} else {
						$("#best_seq").html("<b>No results were found</b>");
					}
					$("#query").html(seq);
					hilite_sequence(best_start,best_end,0);

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
						} else {
							gene_name = ids[i][0];
							desc = ids[i][2];
						}
						t_info += "<tr><td>"+gene_name+"</td><td style='text-align:right;'>"+ids[i][1]+"</td><td>"+desc+"</td></tr>";
					}

					$("#target_info").html(t_info);
					$("#hide2").css("display","inline");
					$("#hide3").css("display","inline");
					
					$("#help_fsize").val(f_length);
					$("#help_mm").val(mm);
				}
			},
			error: function(response) {
				alert("An error occurred. The service may not be available right now.");
				//safari_alert();
				enable_ui();
			}
		});
	}


	function createMap(collapsed,zoom,score_array,expr_msg,ids,m_aoa) {
		var img_height = +$("#img_height").val();
		var best_start = +$("#best_start").val();
		var best_end = +$("#best_end").val();
		var seq_length = +$("#seq_length").val();
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
		var coverage = $("#coverage_val").val();
		var seq_length = $("#seq_length").val();

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
		var coverage = $("#coverage_val").val();
		var seq_length = $("#seq_length").val();

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

				// var final_score = (+score_array[i]/+si_rna/coverage*100).toFixed(2); //using coverage in algorithm
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
	function hilite_sequence(cbr_start,cbr_end,color) {

		if (color) {
			var markup = new Text.Markup( { 'highlight' : [ '<span class="highlighted2" style="background:#D2D4D6;">', '</span>' ], 'break' : [ '<br />', '' ], 'space' : [ '<span>&nbsp;</span>', '' ] });
		} else {
			var markup = new Text.Markup( { 'highlight' : [ '<span class="highlighted">', '</span>' ], 'break' : [ '<br />', '' ], 'space' : [ '<span>&nbsp;</span>', '' ] });
		}

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
		var collapsed = $("#collapse").val();
		var zoom = $("#zoom").val();
		var seq_length = $("#seq_length").val();

		if (collapsed == 0) {
			$("#collapse").html("Expand Graph");
			$("#collapse").val(1);
			collapsed = 1;
		} else {
			$("#collapse").html("Collapse Graph");
			$("#collapse").val(0);
			collapsed = 0;
		}
		createMap(+collapsed,+zoom,score_array,expr_msg,ids,m_aoa);
		getCustomRegion(score_array,best_seq,seq);
	}

	function activateZoom(score_array,best_seq,seq,expr_msg,ids,m_aoa) {
		var collapsed = $("#collapse").val();
		var zoom = $("#zoom").val();
		var seq_length = $("#seq_length").val();

		if (zoom == 0) {
			$("#zoom").html("Zoom Out");
			$("#zoom").val(1);
			zoom = 1;
		} else {
			$("#zoom").html("Zoom In");
			$("#zoom").val(0);
			zoom = 0;
		}
		createMap(+collapsed,+zoom,score_array,expr_msg,ids,m_aoa);
		getCustomRegion(score_array,best_seq,seq);
	}

	//Function to change values of custom region by dragging the selection square
	function getSquareCoords(score_array,best_seq,seq) {
		var img_width = 700;
		var seq_length = $("#seq_length").val();
		var zoom = $("#zoom").val();
		var rev_xscale = +(seq_length/img_width); // to transform sequence length to pixels
		$("#cbr_p").html("");

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

		$("#cbr_start").val(cbr_start);
		$("#cbr_end").val(cbr_end);
		$("#f_size").val(fragment);

		var best_region = [cbr_start,cbr_end];
		hilite_sequence(cbr_start,cbr_end,1);
		printCustomSeq(best_seq,seq);

		if (score_array) {
			printCustomScore(cbr_start,cbr_end,score_array);
		}
	}

	//Prints custom sequence in Best Region section
	function printCustomSeq(best_seq,seq) {
		var best_seq_el = document.getElementById("best_seq");
		var cbr_start = +$("#cbr_start").val();
		var cbr_end = +$("#cbr_end").val();
		var best_start = +$("#best_start").val();
		var best_end = +$("#best_end").val();

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
		var coverage = +$("#coverage_val").val();
		var seq_length = +$("#seq_length").val();
		var best_score = +$("#best_score").val();

		if (+end > seq_length) {end = seq_length;}
		if (+start < 1) {start = 1;}

		if (score_array) {
			for (var i= +start-1; i< +end; i++) {
				custom_score += +score_array[i];
			}
		}

		var fragment_length = (+end - +start + 1);

		if (coverage > 0 && fragment_length > 0) {
			var final_score = ((custom_score*100/fragment_length)/coverage).toFixed(2); 
			// var final_score = (custom_score*100/+si_rna/fragment_length/coverage).toFixed(2); //using coverage
			$("#score_p").html("<b>Best target region score:</b> "+best_score+" &nbsp;&nbsp; <b> Custom region score: </b>"+final_score+" &nbsp;&nbsp; (-&infin;&mdash;100)");
		}
	}


	// Creates the draggable selection square and modifies custom region when push a button
	function getCustomRegion(score_array,best_seq,seq) {

		var cbr_start = +$("#cbr_start").val();
		var cbr_end = +$("#cbr_end").val();
		var map_el = document.getElementById('myCanvas');
		var seq_length = +$("#seq_length").val();

		var img_width = 700;
		var xscale = +(+img_width/+seq_length); // to transform sequence length to pixels

		var zoom = $("#zoom").val();

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
			$("#region_square").css("border","0px solid #000000");
			$("#region_square").css("top","21px");
			$("#region_square").css("background","rgba(80,100,100,0.3)");
			$("#region_square").css("left",cbr_left+"px");
			$("#region_square").css("width",cbr_width+"px");
			$("#region_square").css("height",cbr_height+"px");

    	    $("#region_square").resizable({
				containment:map_el,
				handles: 'e, w',
				minWidth: 100*xscale,
			});

			$("#region_square").draggable({
				axis: 'x',
				containment:map_el,
				cursor: "move"
			});
			
			$("#cbr_p").html("");
			var fragment = (+cbr_end - +cbr_start +1);
			$("#f_size").val(fragment);

			hilite_sequence(cbr_start,cbr_end,1);
		
		
			printCustomSeq(best_seq,seq);

			if (score_array) {
				printCustomScore(cbr_start,cbr_end,score_array);
			}

		} else {
			$("#cbr_p").html("Values must be between 1 and "+seq_length+", getting a sequence not shorter than 100 bp!");
		}
	}


	function changeTargets(bt2_file,score_array,seq,best_seq,expr_f,ids,m_aoa) {
		
		var t_num = $("#t_num").val();
		var coverage = $("#coverage_val").val();
		var f_size = $("#f_size").val();
		var f_length = $("#f_length").val();
		var n_mer = $("#n_mer").val();
		si_rna = $("#si_rna").val();
		var align_mm = $("#align_mm").val();
		var mm = $("#mm").val();
		var db = $("#bt2_db").val();
		var expr_msg;
		var seq_length = $("#seq_length").val();
		
		if (n_mer != si_rna) {
			$("#f_length").val(f_size);
			$("#mm").val(align_mm);
			$("#si_rna").val(n_mer);
			si_rna = n_mer;
			$("#coverage_val").val(t_num);
			$("#region_square").css("height","0px");
			
			//check values before recalculate
			if (+n_mer >= 18 && +n_mer <= 30) {
				disable_ui();
				runBt2(n_mer, f_size, align_mm, db);
			} else {
				alert("n-mer value must be between 18-30");
			}
		} else if (align_mm != mm) {
			$("#f_length").val(f_size);
			$("#mm").val(align_mm);
			$("#coverage_val").val(t_num);
			
			// if (!align_mm || +align_mm < 0 || +align_mm > 1) {
			if (!align_mm || +align_mm < 0 || +align_mm > 2) {
				alert("miss-match value ("+align_mm+") must be between 0-2");
			} else {
				disable_ui();
				getResults(1, bt2_file, n_mer, f_size, align_mm, t_num, db, expr_f);
				$("#region_square").css("height","0px");
				//getCustomRegion(score_array,best_seq,seq)
			}
		} else if (t_num != coverage || f_size != f_length) {
			$("#f_length").val(f_size);
			$("#coverage_val").val(t_num);
			
			//check values before recalculate
			if (!f_size || +f_size < 100 || +f_size > +seq_length) {
				alert("Wrong fragment size ("+f_size+"), it must be 100 bp or higher, and lower than sequence length");
			} else {
				disable_ui();
				getResults(0, bt2_file, n_mer, f_size, align_mm, t_num, db, expr_f);
				$("#region_square").css("height","0px");
				//getCustomRegion(score_array,best_seq,seq)
			}
		} else {
			alert("there are no parameters to change");
		}
		return [score_array,seq,best_seq,expr_msg,ids,m_aoa]
	}

	function disable_ui() {
		$('#working').dialog("open");
	}

	function enable_ui() {
		$('#working').dialog("close");
	}

	function hide_ui() {
		Effects.swapElements('vigs_input_offswitch', 'vigs_input_onswitch');
		Effects.hideElement('vigs_input_content');
		Effects.swapElements('vigs_usage_offswitch', 'vigs_usage_onswitch');
		Effects.hideElement('vigs_usage_content');
	}
	
	// function safari_alert() {
	// 	if (navigator.appVersion.match(/Safari/i) && !navigator.appVersion.match(/chrome/i)) {
	// 		alert("SGN VIGS Tool does not support Safari, please use a different browser like Firefox (recommended) or Google chrome.");
	// 	}
	// }
});

