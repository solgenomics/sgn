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
    
    if (url.match(/pca\/analysis/) != null) {
    
        var list = new CXGN.List();
        
        var listMenu = list.listSelect("pca_genotypes", ['accessions', 'trials']);
       
	if (listMenu.match(/option/) != null) {
            
            jQuery("#pca_genotypes_list").append(listMenu);

        } else {            
            jQuery("#pca_genotypes_list").append("<select><option>no lists found - Log in</option></select>");
        }
    }
               
});


jQuery(document).ready( function() { 
   
    var url = window.location.pathname;

    if (url.match(/solgs\/trait|breeders_toolbox\/trial|breeders\/trial\/|solgs\/selection\//)) {
       checkPcaResult();  
    } 
 
});


function checkPcaResult () {
    
    var popId = solGS.getPopulationDetails();
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
	data: {'training_pop_id' : popId.training_pop_id, 'selection_pop_id': popId.selection_pop_id},
        url: '/pca/check/result/',
        success: function(response) {
            if (response.result) {
		pcaResult();					
            } else { 
		jQuery("#run_pca").show();	
            }
	}
    });
    
}


jQuery(document).ready( function() { 

    jQuery("#run_pca").click(function() {
        pcaResult();
    }); 
  
});


jQuery(document).ready( function() { 
     
    var url = window.location.pathname;
    
    if (url.match(/pca\/analysis/) != null) {  
        var listId;
        
        jQuery("<option>", {value: '', selected: true}).prependTo("#pca_genotypes_list_select");
        
        jQuery("#pca_genotypes_list_select").change(function() {        
            listId = jQuery(this).find("option:selected").val();              
                                
            if (listId) {                
                jQuery("#pca_genotypes_list_upload").click(function() {
                    loadPcaGenotypesList(listId);
                });
            }
        }); 
    }      
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
               
        var pcaGenotypes = jQuery("#uploaded_pca_populations_table").doesExist();
                       
        if (pcaGenotypes == false) {                              
            pcaGenotypes = getPcaPopsList(listId);                    
            jQuery("#uploaded_pca_populations").append(pcaGenotypes).show();                           
        }
        else {
            var addRow = '<tr><td>'
                + '<a href="#"  onclick="javascript:setListId(' + listId + ');javascript:pcaResult(); return false;">' 
                + listName + '</a>'
                + '</td>'
		+ '<td>' + listType + '</td>'
                + '<td id="list_pca_page_' + listId +  '">'
                + '<a href="#" onclick="setListId(' + listId + ');pcaResult();return false;">' 
                + '[ Run PCA ]' + '</a>'          
                + '</td><tr>';

            var tdId = '#list_pca_page_' + listId;
            var addedRow = jQuery(tdId).doesExist();

            if (addedRow == false) {
                jQuery("#uploaded_pca_populations_table tr:last").after(addRow);
            }                          
        }       
	jQuery.unblockUI();                                
    }

}


function pcaResult () {

    var popId  = solGS.getPopulationDetails();
    var listId = getListId();
 
    if (listId) {
	popId['training_pop_id'] = 'uploaded_' + listId;
    }
   
    var listName;
    var listType;
    
    if (listId) {
	var genoList = getPcaGenotypesListData(listId);
	listName = genoList.name;
	listType = genoList.listType;
    }
    
    if (listId || popId.training_pop_id || popId.selection_pop_id) {
	jQuery("#pca_message").html("Running PCA... please wait...");
	jQuery("#run_pca").hide();
    }  
  
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'training_pop_id': popId.training_pop_id,
	       'selection_pop_id': popId.selection_pop_id,
	       'list_id': listId, 
	       'list_name': listName, 
	       'list_type': listType,
	      },
        url: '/pca/result',
        success: function(response) {
            if (response.status === 'success') {
	
		var scores = response.pca_scores;
		var variances = response.pca_variances;
		
		if (response.pop_id) {
		    var popId = response.pop_id;
		}
		
		var plotData = { 'scores': scores, 
				 'variances': variances, 
				 'pop_id': popId, 
				 'list_id': listId,
				 'list_name': listName
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
   
    var pcaPopsList ='<table id="uploaded_pca_populations_table" style="width:100%; text-align:left"><tr>'
                                + '<th>Population</th>'
                                + '<th>List type</th>'
                                + '<th>Run PCA</th>'
                                +'</tr>'
                                + '<tr>'
                                + '<td>'
                                + '<a href="#"  onclick="setListId('+ listId +');pcaResult(); return false;">' 
                                + listName + '</a>'
                                + '</td>'
    	                        + '<td>' + listType + '</td>'
                                + '<td id="list_pca_page_' + listId +  '">'
                                + '<a href="#" onclick="setListId(' + listId + ');pcaResult();return false;">' 
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

    var scores = plotData.scores;
    var variances = plotData.variances;
   
    var pc12 = [];
    var pc1  = [];
    var pc2  = []; 

    jQuery.each(scores, function(i, pc) {
                   
	pc12.push( [{'name' : pc[0], 'pc1' : parseFloat(pc[2]), 'pc2': parseFloat(pc[3]), 'trial':pc[1] }]);
	pc1.push(parseFloat(pc[2]));
	pc2.push(parseFloat(pc[3]));

    });
    //console.log(pc12);
    var height = 300;
    var width  = 500;
    var pad    = {left:40, top:20, right:40, bottom:100}; 
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;
   
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
   
    var pc1AxisMid = 0.5 * (totalH); 
    var pc2AxisMid = 0.5 * (totalW);
  
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
      
}









