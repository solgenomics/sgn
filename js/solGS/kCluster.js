/** 
* K-means cluster analysis and vizualization 
* using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use("CXGN.List");
JSAN.use("jquery.blockUI");
JSAN.use('solGS.solGS')

jQuery(document).ready( function() {
    
    var url = window.location.pathname;
    
    if (url.match(/kcluster\/analysis/) != null) {
    
        var list = new CXGN.List();
        
        var listMenu = list.listSelect("kcluster_genotypes", ['accessions', 'trials']);
       
	if (listMenu.match(/option/) != null) {
            
            jQuery("#kcluster_genotypes_list").append(listMenu);

        } else {            
            jQuery("#kcluster_genotypes_list").append("<select><option>no lists found - Log in</option></select>");
        }
    }
               
});


jQuery(document).ready( function() { 
   
    var url = window.location.pathname;

    if (url.match(/solgs\/trait|breeders_toolbox\/trial|breeders\/trial\/|solgs\/selection\//)) {
       checkKClusterResult();  
    } 
 
});


function checkKClusterResult () {

    var listId = jQuery('#list_id').val();
  
    var popId = solGS.getPopulationDetails();
    
    var comboPopsId = jQuery('#combo_pops_id').val();
    //console.log('combo ' + comboPopsId)
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
	data: {'list_id': listId,
	       'combo_pops_id' : comboPopsId,
	       'training_pop_id' : popId.training_pop_id,
	       'selection_pop_id': popId.selection_pop_id},
        url: '/kcluster/check/result/',
        success: function(response) {
            if (response.result) {
		
		if (response.list_id) {		    
		    setListId(response.list_id);
		}
		console.log('calling kcluster combo id ' + response.combo_pops_id)
		console.log('calling kcluster result ' + response.result)
		kClusterResult();
	    } else { 
		jQuery("#run_kcluster").show();	
            }
	},
	
	});
    
}


jQuery(document).ready( function() { 

    jQuery("#run_kcluster").click(function() {
        kClusterResult();
    }); 
  
});


jQuery(document).ready( function() { 
     
    var url = window.location.pathname;
    
    if (url.match(/kcluster\/analysis/) != null) {  
        var listId;
        
        jQuery("<option>", {value: '', selected: true}).prependTo("#kcluster_genotypes_list_select");
        
        jQuery("#kcluster_genotypes_list_select").change(function() {        
            listId = jQuery(this).find("option:selected").val();              
                                
            if (listId) {                
                jQuery("#kcluster_genotypes_list_upload").click(function() {
                    loadKClusterGenotypesList(listId);
                });
            }
        });

	checkKClusterResult();
    }      
});


function loadKClusterGenotypesList(listId) {     
    
    var genoList = getKClusterGenotypesListData(listId);
    var listName = genoList.name;
    var listType = genoList.listType;  
   
    if ( listId.length === 0) {       
        alert('The list is empty. Please select a list with content.' );
    } else {
	jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait..'});
               
        var kClusterGenotypes = jQuery("#list_kcluster_populations_table").doesExist();
                       
        if (kClusterGenotypes == false) {                              
            kClusterGenotypes = getKClusterGenotypesListData(listId);                    
            jQuery("#list_pca_populations").append(kClusterGenotypes).show();                           
        }
        else {
            var addRow = '<tr><td>'
                + '<a href="#"  onclick="javascript:setListId(' + listId + ');javascript:kClusterResult(); return false;">' 
                + listName + '</a>'
                + '</td>'
		+ '<td>' + listType + '</td>'
                + '<td id="list_kcluster_page_' + listId +  '">'
                + '<a href="#" onclick="setListId(' + listId + ');kClusterResult();return false;">' 
                + '[ Run K-means Cluster ]' + '</a>'          
                + '</td><tr>';

            var tdId = '#list_kcluster_page_' + listId;
            var addedRow = jQuery(tdId).doesExist();

            if (addedRow == false) {
                jQuery("#list_kcluster_populations_table tr:last").after(addRow);
            }                          
        }       
	jQuery.unblockUI();                                
    }

}


function kClusterResult () {

    var popId  = solGS.getPopulationDetails();
    var listId = getListId();
 
    if (listId) {
	popId['training_pop_id'] = 'list_' + listId;
    }
  
    var listName;
    var listType;
    
    if (listId) {
	var genoList = getKClusterGenotypesListData(listId);
	listName = genoList.name;
	listType = genoList.listType;
    }
    
    if (listId || popId.training_pop_id || popId.selection_pop_id) {
	jQuery("#kcluster_message").html("Running K-means clustering... please wait...");
	jQuery("#run_kcluster").hide();
    }  

    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'training_pop_id': popId.training_pop_id,
	       'selection_pop_id': popId.selection_pop_id,
	       'combo_pops_id': popId.combo_pops_id,
	       'list_id': listId, 
	       'list_name': listName, 
	       'list_type': listType,
	      },
        url: '/kcluster/result',
        success: function(response) {
            if (response.status === 'success') {
		
		if (response.pop_id) {
		    var popId = response.pop_id;
		}
		
		var plotData = { 'scores': response.pca_scores, 
				 'variances': response.pca_variances, 
				 'pop_id': popId, 
				 'list_id': listId,
				 'list_name': listName,
				 'trials_names': response.trials_names,
				 'output_link' : response.output_link
			       };
					
                plotKCluster(plotData);
		jQuery("#kcluster_message").empty();
		jQuery("#run_kcluster").hide();

            } else {                
		jQuery("#pca_message").html(response.status);
		jQuery("#run_kcluster").show();
            }
	},
        error: function(response) {                    
            jQuery("#kcluster_message").html('Error occured running K-means clustering.');
	    jQuery("#run_kcluser").show();
        }  
    });
  
}


function getKClusterPopsList (listId) {
   
    var genoList       = getKClusterGenotypesListData(listId);
    var listName       = genoList.name;
    var listType       = genoList.listType;
   
    var pcaPopsList ='<table id="list_kcluster_populations_table" style="width:100%; text-align:left"><tr>'
                                + '<th>Population</th>'
                                + '<th>List type</th>'
                                + '<th>Run K-means</th>'
                                +'</tr>'
                                + '<tr>'
                                + '<td>'
                                + '<a href="#"  onclick="setListId('+ listId +');kClusterResult(); return false;">' 
                                + listName + '</a>'
                                + '</td>'
    	                        + '<td>' + listType + '</td>'
                                + '<td id="list_pca_page_' + listId +  '">'
                                + '<a href="#" onclick="setListId(' + listId + ');kClusterResult();return false;">' 
                                + '[ Run K-means]'+ '</a>'
                                + '</td></tr></table>';

    return kClusterPopsList;
}


jQuery.fn.doesExist = function(){

        return jQuery(this).length > 0;

 };


function getKClusterGenotypesListData(listId) {   
    
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
    console.log(listId)
    //listId = listId.replace('list_', '');
     console.log(listId)
    if (existingListId) {
	jQuery("#list_id").remove();
    }
    
    jQuery("#kcluster_canvas").append('<input type="hidden" id="list_id" value=' + listId + '></input>');

}


function getListId () {

    var listId = jQuery("#list_id").val();
    return listId;  
      
}


function plotKCluster(plotData){

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
        .append("svg")
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
    if (plotData.pop_id)  {
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
	.text("[Share plot ]")
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









