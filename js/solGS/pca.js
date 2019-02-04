/** 
* Principal component analysis and scores plotting 
* using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use("CXGN.List");
JSAN.use("jquery.blockUI");
JSAN.use('solGS.solGS')

jQuery(document).ready( function() {
    
    var url = window.location.pathname;
    
    if (url.match(/pca\/analysis/)) {
    
        var list = new CXGN.List();
        
        var listMenu = list.listSelect("pca_genotypes", ['accessions', 'trials']);
       
	if (listMenu.match(/option/) != null) {
            
            jQuery("#pca_genotypes_list").append(listMenu);

        } else {            
            jQuery("#pca_genotypes_list").append("<select><option>no lists found - Log in</option></select>");
        }
    }
               
});


function checkPcaResult () {

    var listId = jQuery('#list_id').val();
  
    var popDetails = solGS.getPopulationDetails();
    var url =  window.location.pathname;
    var pcaShareId;
     if (url.match(/pca\/analysis\//)) {
	// console.log('checkresult pca analyis id extract ', url)
	pcaShareId = url.replace(/\/pca\/analysis\//g, '');
	 console.log('checkresult pca analyis id ' + pcaShareId)

	 if (pcaShareId.match(/list/)) {
	     listId = pcaShareId;
	     setListId(pcaShareId);
	 }
     }
    
    var comboPopsId = jQuery('#combo_pops_id').val();
    console.log('combo pop id: ' + comboPopsId)    
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
	data: {'list_id': listId,
	       'combo_pops_id' : comboPopsId,
	       'pca_share_id'  : pcaShareId,
	       'training_pop_id' : popDetails.training_pop_id,
	       'selection_pop_id': popDetails.selection_pop_id},
        url: '/pca/check/result/',
        success: function(response) {
            if (response.result) {
		 setListId(response.list_id);
	//	console.log('response.result ' + response.pca_scores)
		 var url =  window.location.pathname;
		if (url.match(/pca\/analysis/)) {		    		   

		    var plotData = { 'scores': response.pca_scores, 
				     'variances': response.pca_variances, 
				     'pop_id': response.pop_id, 
				     'list_id': response.list_id,
				     'list_name': response.list_name,
				     'trials_names': response.trials_names,
				     'output_link' : response.output_link
				   };
		    
		    plotPca(plotData);  
		} else {
		    pcaRun();
		}
	    } else { 
		jQuery("#run_pca").show();	
            }
	},
	
	});
    
}


jQuery(document).ready( function() { 

    jQuery("#run_pca").click(function() {
	pcaRun();
    }); 
  
});


jQuery(document).ready( function() { 
     
    var url = window.location.pathname;
    
    if (url.match(/pca\/analysis/)) {  
        var listId;
        
        jQuery("<option>", {value: '', selected: true}).prependTo("#pca_genotypes_list_select");
        
        jQuery("#pca_genotypes_list_select").change(function() {        
            listId = jQuery(this).find("option:selected").val();              
                                
            if (listId) {                
                jQuery("#pca_go_btn").click(function() {
                    loadPcaGenotypesList(listId);
                });
            }
        });
    } 

    //if (url.match(/pca\/analysis\/|solgs\/trait\/|breeders\/trial\/|solgs\/selection\//)) {
	checkPcaResult();  
    // }
    
});


function loadPcaGenotypesList(listId) {     
    
    var genoList = getPcaGenotypesListData(listId);
    var listName = genoList.name;
    var listType = genoList.listType;  
   
    if ( listId.length === 0) {       
        alert('The list is empty. Please select a list with content.' );
    } else {
	jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait..'});
               
        var pcaGenotypes = jQuery("#list_pca_populations_table").doesExist();
                       
        if (pcaGenotypes == false) {                              
            pcaGenotypes = getPcaPopsList(listId);                    
            jQuery("#list_pca_populations").append(pcaGenotypes).show();                           
        }
        else {
            var addRow = '<tr><td>'
                + '<a href="#"  onclick="setListId(' + listId + ');pcaRun(); return false;">' 
                + listName + '</a>'
                + '</td>'
		+ '<td>' + listType + '</td>'
                + '<td id="list_pca_page_' + listId +  '">'
                + '<a href="#" onclick="setListId(' + listId + ');pcaRun();return false;">' 
                + '[ Run PCA ]' + '</a>'          
                + '</td><tr>';

            var tdId = '#list_pca_page_' + listId;
            var addedRow = jQuery(tdId).doesExist();

            if (addedRow == false) {
                jQuery("#list_pca_populations_table tr:last").after(addRow);
            }                          
        }       
	jQuery.unblockUI();                                
    }

}


function pcaRun () {

    var popDetails  = solGS.getPopulationDetails();
    var listId = getListId();

    if (listId) {
	popDetails['training_pop_id'] = 'list_' + listId;
    }
  
    var listName;
    var listType;
    
    if (listId) {
	var genoList = getPcaGenotypesListData(listId);
	listName = genoList.name;
	listType = genoList.listType;
    }
    
    if (listId || popDetails.training_pop_id || popDetails.combo_pops_id || popDetails.selection_pop_id) {
	jQuery("#pca_message").prependTo(jQuery("#pca_canvas"));					 
	jQuery("#pca_message").html("Running PCA... please wait...");
	jQuery("#run_pca").hide();
    }  

    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'training_pop_id': popDetails.training_pop_id,
	       'selection_pop_id': popDetails.selection_pop_id,
	       'combo_pops_id': popDetails.combo_pops_id,
	       'list_id': listId, 
	       'list_name': listName, 
	       'list_type': listType,
	      },
        url: '/pca/run',
        success: function(response) {
	    
            if (response.pca_scores) {	
		var popId = response.pop_id;
		
		var plotData = { 'scores': response.pca_scores, 
				 'variances': response.pca_variances, 
				 'pop_id': popId, 
				 'list_id': listId,
				 'list_name': listName,
				 'trials_names': response.trials_names,
				 'output_link' : response.output_link
			       };
					
                plotPca(plotData);
		jQuery("#pca_message").empty();
		jQuery("#run_pca").hide();

            } else {                
		jQuery("#pca_message").html(response.status);
		jQuery("#run_pca").show();
            }
	},
        error: function(response) {                    
            jQuery("#pca_message").html('Error occured running population structure analysis (PCA).');
	    jQuery("#run_pca").show();
        }  
    });
  
}


function getPcaPopsList (listId) {
   
    var genoList       = getPcaGenotypesListData(listId);
    var listName       = genoList.name;
    var listType       = genoList.listType;
   
    var pcaPopsList ='<table id="list_pca_populations_table" style="width:100%; text-align:left"><tr>'
                                + '<th>Population</th>'
                                + '<th>List type</th>'
                                + '<th>Run PCA</th>'
                                +'</tr>'
                                + '<tr>'
                                + '<td>'
                                + '<a href="#"  onclick="setListId('+ listId +');pcaRun(); return false;">' 
                                + listName + '</a>'
                                + '</td>'
    	                        + '<td>' + listType + '</td>'
                                + '<td id="list_pca_page_' + listId +  '">'
                                + '<a href="#" onclick="setListId(' + listId + ');pcaRun();return false;">' 
                                + '[ Run PCA ]'+ '</a>'
                                + '</td></tr></table>';

    return pcaPopsList;
}


jQuery.fn.doesExist = function(){

        return jQuery(this).length > 0;

 };


function getPcaGenotypesListData(listId) {   
    
    var list = new CXGN.List();
    
    if (! listId == "") {
	var listName = list.listNameById(listId);
        var listType = list.getListType(listId);
	
	return {'name'     : listName,
		'listType' : listType,
               };
    } else {
	return;
    }
   
}


function setListId (listId) {
     
    var existingListId = jQuery("#list_id").doesExist();
 
    if (existingListId) {
	jQuery("#list_id").remove();
    }
    
    jQuery("#pca_canvas").append('<input type="hidden" id="list_id" value=' + listId + '></input>');

}


function getListId () {

    var listId = jQuery("#list_id").val();
    return listId;  
      
}


function plotPca(plotData){

    var scores      = plotData.scores;
    var variances   = plotData.variances;
    var trialsNames = plotData.trials_names;
   
    var pc12 = [];
    var pc1  = [];
    var pc2  = []; 
    var trials = [];

    jQuery.each(scores, function(i, pc) {
        pc12.push( [{'name' : pc[0], 'pc1' : parseFloat(pc[2]), 'pc2': parseFloat(pc[3]), 'trial':pc[1] }]);
	pc1.push(parseFloat(pc[2]));
	pc2.push(parseFloat(pc[3]));
	trials.push(pc[1]);
    });
   
    var height = 300;
    var width  = 500;
    var pad    = {left:40, top:20, right:40, bottom:20}; 
    var totalH = height + pad.top + pad.bottom + 200;
    var totalW = width + pad.left + pad.right + 400;
   
    var svg = d3.select("#pca_canvas")
        .insert("svg", ":first-child")
        .attr("width", totalW)
        .attr("height", totalH);

    var pcaPlot = svg.append("g")
        .attr("id", "#pca_plot")
        .attr("transform", "translate(" + (pad.left) + "," + (pad.top) + ")");
   
    var pc1Min = d3.min(pc1);
    var pc1Max = d3.max(pc1); 
   
    var pc1Limits = d3.max([Math.abs(d3.min(pc1)), d3.max(pc1)]);
    var pc2Limits = d3.max([Math.abs(d3.min(pc2)), d3.max(pc2)]);
  
    var pc1AxisScale = d3.scale.linear()
        .domain([0, pc1Limits])
        .range([0, width/2]);
    
    var pc1AxisLabel = d3.scale.linear()
        .domain([(-1 * pc1Limits), pc1Limits])
        .range([0, width]);

    var pc2AxisScale = d3.scale.linear()
        .domain([0, pc2Limits])
        .range([0, (height/2)]);

    var pc1Axis = d3.svg.axis()
        .scale(pc1AxisLabel)
        .tickSize(3)
        .orient("bottom");
          
    var pc2AxisLabel = d3.scale.linear()
        .domain([(-1 * pc2Limits), pc2Limits])
        .range([height, 0]);
    
   var pc2Axis = d3.svg.axis()
        .scale(pc2AxisLabel)
        .tickSize(3)
        .orient("left");
   
    var pc1AxisMid = (0.5 * height) + pad.top; 
    var pc2AxisMid = (0.5 * width) + pad.left;
  
    var yMidLineData = [
	{"x": pc2AxisMid, "y": pad.top}, 
	{"x": pc2AxisMid, "y": pad.top + height}
    ];

    var xMidLineData = [
	{"x": pad.left, "y": pad.top + height/2}, 
	{"x": pad.left + width, "y": pad.top + height/2}
    ];

    var lineFunction = d3.svg.line()
        .x(function(d) { return d.x; })
        .y(function(d) { return d.y; })
        .interpolate("linear");

    pcaPlot.append("path")
        .attr("d", lineFunction(yMidLineData))
        .attr("stroke", "red")
        .attr("stroke-width", 1)
        .attr("fill", "none");

    pcaPlot.append("path")
        .attr("d", lineFunction(xMidLineData))
        .attr("stroke", "green")
        .attr("stroke-width", 1)
        .attr("fill", "none");

    pcaPlot.append("g")
        .attr("class", "PC1 axis")
        .attr("transform", "translate(" + pad.left + "," + (pad.top + height) +")")
        .call(pc1Axis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", 10)
        .attr("dy", ".1em")         
        .attr("transform", "rotate(90)")
        .attr("fill", "green")
        .style({"text-anchor":"start", "fill": "#86B404"});
      
    pcaPlot.append("g")
        .attr("class", "PC2 axis")
        .attr("transform", "translate(" + pad.left +  "," + pad.top  + ")")
        .call(pc2Axis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("fill", "green")
        .style("fill", "#86B404");

    pcaPlot.append("g")
        .attr("id", "pc1_axis_label")
        .append("text")
        .text("PC1: " + variances[0][1] + "%" )
        .attr("y", pad.top + height + 55)
        .attr("x", width/2)
        .attr("font-size", 12)
        .style("fill", "green")

    pcaPlot.append("g")
        .attr("id", "pc2_axis_label")
        .append("text")
        .text("PC2: " + variances[1][1] + "%" )
	.attr("transform", "rotate(-90)")
	.attr("y", -5)
        .attr("x", -((pad.left + height/2) + 10))
        .attr("font-size", 12)
        .style("fill", "red")

    var grpColor = d3.scale.category10();

    pcaPlot.append("g")
        .selectAll("circle")
        .data(pc12)
        .enter()
        .append("circle")
        .style("fill", function(d) {return grpColor(d[0].trial); })
        .attr("r", 3)
        .attr("cx", function(d) { 
            var xVal = d[0].pc1;            
	    if (xVal >= 0) {
                return  (pad.left + (width/2)) + pc1AxisScale(xVal);
            } else {
                return (pad.left + (width/2)) - (-1 * pc1AxisScale(xVal));
           }
        })
        .attr("cy", function(d) {             
            var yVal = d[0].pc2;
            
            if (yVal >= 0) {
                return ( pad.top + (height/2)) - pc2AxisScale(yVal);
            } else {
                return (pad.top + (height/2)) +  (-1 * pc2AxisScale(yVal));                  
            }
        })        
        .on("mouseover", function(d) {
            d3.select(this)
                .attr("r", 5)
                .style("fill", "#86B404")
            pcaPlot.append("text")
                .attr("id", "dLabel")
                .style("fill", "#86B404")              
                .text( d[0].name + "(" + d[0].pc1 + "," + d[0].pc2 + ")")
                .attr("x", pad.left + 1)
                .attr("y", pad.top + 80);
        })
        .on("mouseout", function(d) { 
            d3.select(this)
                .attr("r", 3)
                .style("fill", function(d) {return grpColor(d[0].trial); })
            d3.selectAll("text#dLabel").remove();            
        });

    pcaPlot.append("rect")
	.attr("transform", "translate(" + pad.left + "," + pad.top + ")")
        .attr("height", height)
        .attr("width", width)
        .attr("fill", "none")
        .attr("stroke", "#523CB5")
        .attr("stroke-width", 1)
        .attr("pointer-events", "none");
    
    var id;   
    if ( plotData.pop_id) {
    	id = plotData.pop_id;
    } else {
	id = plotData.list_id;
    }

    var popName = "";
    if (plotData.list_name) {
	popName = ' -- ' + plotData.list_name;
    }

    var pcaDownload;
    if (id)  {
	pcaDownload = "/download/pca/scores/population/" + id;
    }

     pcaPlot.append("a")
	.attr("xlink:href", pcaDownload)
	.append("text")
	.text("[ Download PCA scores ]" + popName)
	.attr("y", pad.top + height + 75)
        .attr("x", pad.left)
        .attr("font-size", 14)
        .style("fill", "#954A09")


    var shareLink;
    if (plotData.output_link)  {
	    shareLink = plotData.output_link;
    }

    pcaPlot.append("a")
	.attr("xlink:href", shareLink)
	.append("text")
	.text("[Share plot]")
	.attr("y", pad.top + height + 100)
        .attr("x", pad.left)
        .attr("font-size", 14)
        .style("fill", "#954A09")
    
    if (trialsNames && Object.keys(trialsNames).length > 1) {
	var trialsIds = jQuery.unique(trials);
	trialsIds = jQuery.unique(trialsIds);

	var legendValues = [];
	var cnt = 0;

	var allTrialsNames = [];

	for (var tr in trialsNames) {
	    allTrialsNames.push(trialsNames[tr]);
	};

	trialsIds.forEach( function (id) {
	    var trialName = trialsNames[id];
	    if (isNaN(id)) {trialName = allTrialsNames.join(' & ');}
	    legendValues.push([cnt, id, trialName]);
	    cnt++;
	});
	
	var recLH = 20;
	var recLW = 20;

	var legend = pcaPlot.append("g")
            .attr("class", "cell")
            .attr("transform", "translate(" + (width + 60) + "," + (height * 0.25) + ")")
            .attr("height", 100)
            .attr("width", 100);

	legend = legend.selectAll("rect")
            .data(legendValues)  
            .enter()
            .append("rect")
            .attr("x", function (d) { return 1;})
            .attr("y", function (d) {return 1 + (d[0] * recLH) + (d[0] * 5); })   
            .attr("width", recLH)
            .attr("height", recLW)
            .style("stroke", "black")
            .attr("fill", function (d) { 
		return  grpColor(d[1]); 
            });
	
	var legendTxt = pcaPlot.append("g")
            .attr("transform", "translate(" + (width + 90) + "," + ((height * 0.25) + (0.5 * recLW)) + ")")
            .attr("id", "legendtext");

	legendTxt.selectAll("text")
            .data(legendValues)  
            .enter()
            .append("text")              
            .attr("fill", "#523CB5")
            .style("fill", "#523CB5")
            .attr("x", 1)
            .attr("y", function (d) { return 1 + (d[0] * recLH) + (d[0] * 5); })
            .text(function (d) { 
		return d[2]; 
            })  
            .attr("dominant-baseline", "middle")
	    .attr("text-anchor", "start");
    }
    
}









