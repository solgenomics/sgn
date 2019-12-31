/** 
* Principal component analysis and scores plotting 
* using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/



var solGS = solGS || function solGS () {};

solGS.pca = {

    loadPcaPops: function(selectId, selectName, dataStructure) {
	  
	if ( selectId.length === 0) {       
            alert('The list is empty. Please select a list with content.' );
	} else {
	              
            var pcaTable = jQuery("#pca_pops_table").doesExist();
            
            if (pcaTable == false) {
                pcaTable = this.createTable();
		jQuery("#pca_pops_section").append(pcaTable).show();                           
            }
	    var onClickVal =  '<a href="#" onclick="solGS.pca.pcaRun('
		+ selectId + ",'" + selectName + "'" +  ",'" + dataStructure
		+ "'" + ');return false;">';

	    var dataType = ['Genotype', 'Phenotype'];
	    var dataTypeOpts = this.createDataTypeSelect(dataType);
	    
	    var addRow = '<tr  name="' + dataStructure + '"' + ' id="' + selectId +  '">'
                + '<td>' + selectName + '</td>'
		+ '<td>' + dataStructure + '</td>'
		+ '<td>' + dataTypeOpts + '</td>'
                + '<td id="list_pca_page_' + selectId +  '">' + onClickVal + '[ Run PCA ]' + '</a></td>'          
                + '<tr>';

	    var tdId = '#list_pca_page_' + selectId;
	    var addedRow = jQuery(tdId).doesExist();

	    if (addedRow == false) {
                jQuery("#pca_pops_table tr:last").after(addRow);
	    }                                                        
	}

    },

    pcaRun: function (selectId, selectName, dataStructure) {

	var dataType;

	if (selectId) {
	    dataType = jQuery('#'+selectId + ' #pca_data_type_select').val();
	} else {
	  dataType = jQuery('#pca_data_type_select').val();  
	}

	var popDetails = solGS.getPopulationDetails();
	
	var listId;
	var datasetId;
	var datasetName;
	
	if (dataStructure == 'list') {
	    listId = selectId;
	    popDetails['training_pop_id'] = 'list_' + selectId;
	} else if (dataStructure == 'dataset') {
	    popDetails['training_pop_id'] = 'dataset_' + selectId;
	    datasetId = selectId;
	    datasetName = selectName;
	}

	var validateArgs =  {
	    'data_id': selectId,
	    'data_structure': dataStructure,
	    'data_type': dataType,
	};

	
	var message = this.validatePcaParams(validateArgs);

	if (message != undefined) {
	    jQuery("#pca_message")
		.prependTo(jQuery("#pca_canvas"))
		.html(message)
		.show().fadeOut(9400);
	    
	} else {

	    var pcaArgs = {
		'training_pop_id': popDetails.training_pop_id,
		'selection_pop_id': popDetails.selection_pop_id,
		'combo_pops_id': popDetails.combo_pops_id,
		'list_id': listId, 
		'data_type': dataType,
		'data_structure': dataStructure,
		'dataset_id': datasetId,
		'dataset_name': datasetName
	    };
	    
	    this.runPcaAnalysis(pcaArgs);
    }
  
    },

    runPcaAnalysis: function (pcaArgs) {

	console.log('runpcaanalysis')
	
	jQuery("#pca_canvas .multi-spinner-container").prependTo("#pca_canvas");
	jQuery("#pca_canvas .multi-spinner-container").show();
	jQuery("#pca_message").prependTo(jQuery("#pca_canvas"));
	jQuery("#pca_message").html("Running PCA... please wait...it may take minutes.");
	jQuery("#run_pca").hide();

	 console.log('calling pca ajax')

	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: pcaArgs,
            url: '/pca/run',
            success: function(res) {

		jQuery("#pca_canvas .multi-spinner-container").hide();
		if (res.pca_scores) {	
		  
		    var listId = res.list_id;
		    var listName; 

		    if (listId != undefined) {
			var list = new CXGN.List();
			listName = list.listNameById(listId);
		    }
		
		    var plotData = {
			'scores': res.pca_scores, 
			'variances': res.pca_variances, 
			'pop_id': res.pop_id, 
			'list_id': listId,
			'list_name': listName,
			'trials_names': res.trials_names,
			'output_link' : res.output_link,
			'data_type' : res.data_type
		    };

		  
                    solGS.pca.plotPca(plotData);
		    jQuery("#pca_message").empty();
		    jQuery("#run_pca").show();

		} else {
                    jQuery("#pca_canvas .multi-spinner-container").hide();
		    jQuery("#pca_message").html(res.status);
		    //jQuery("#pca_message").html('Error occured running the PCA.');
		    jQuery("#run_pca").show();
		}
	    },
            error: function(response) {
                jQuery("#pca_canvas .multi-spinner-container").hide();
		jQuery("#pca_message").html('Error occured running the PCA.');
		jQuery("#run_pca").show();
		
            }  
	});
	
    },

     validatePcaParams: function(valArgs) {

	var dataType = valArgs.data_type;
	var dataStr = valArgs.data_structure;
	var dataId = valArgs.data_id;
	
	var msg;

	if (dataStr && dataStr.match('list')) {
	    var list = new CXGN.List();
	    var listType = list.getListType(dataId);
	   
	    if (listType.match(/accessions/)
		&& dataType.match(/Phenotype/i)) {
		msg = 'With list of clones, you can only do PCA based on <em>genotype</em>.';		
	    }
	    
	    if (listType.match(/plots/)
		&& dataType.match(/Genotype/i)) {
		msg = 'With list of plots, you can only do PCA based on <em>phenotype</em>.';		
	    }
	}
	
	return msg;
    },

    createTable: function () {
	var pcaTable ='<table id="pca_pops_table" class="table table-striped"><tr>'
            + '<th>Population</th>'
            + '<th>Data structure type</th>'
	    + '<th>Data type</th>'
            + '<th>Run PCA</th>'
            +'</tr>'
            + '</td></tr></table>';
	
	return pcaTable;
    },

     createDataTypeSelect: function(opts) {
	var dataTypeGroup = '<select class="form-control" id="pca_data_type_select">';

	for (var i=0; i < opts.length; i++) {
	    
	    dataTypeGroup += '<option value="'
		+ opts[i] + '">'
		+ opts[i]
		+ '</option>';
	}
	  dataTypeGroup +=  '</select>';
	
	return dataTypeGroup;
     },
    

    getPcaGenotypesListData: function(listId) {   
    
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
   
    },


    setListId: function (listId) {
	
	var existingListId = jQuery("#list_id").doesExist();
	
	if (existingListId) {
	    jQuery("#list_id").remove();
	}
	
	jQuery("#pca_canvas").append('<input type="hidden" id="list_id" value=' + listId + '></input>');

    },


    getListId: function () {

	var listId = jQuery("#list_id").val();
	return listId;  
      
    },


    plotPca: function(plotData){

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
	var totalH = height + pad.top + pad.bottom + 100;
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
	    .text("[ Download PCA scores ]" + popName + ' -- ' + plotData.data_type)
	    .attr("y", pad.top + height + 75)
            .attr("x", pad.left)
            .attr("font-size", 14)
            .style("fill", "#954A09")


	// var shareLink;
	// if (plotData.output_link)  {
	//     shareLink = plotData.output_link;
	// }

	// pcaPlot.append("a")
	//     .attr("xlink:href", shareLink)
	//     .append("text")
	//     .text("[Share plot]")
	//     .attr("y", pad.top + height + 100)
        //     .attr("x", pad.left)
        //     .attr("font-size", 14)
        //     .style("fill", "#954A09")
	
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
	
    },

////////
}
/////

jQuery(document).ready( function() {
    
    var url = document.URL;
    
    if (url.match(/pca\/analysis/)) {
    
        var list = new CXGN.List();
        var listMenu = list.listSelect("pca_pops", ['accessions', 'plots', 'trials'], undefined, undefined, undefined);

	var dType = ['accessions', 'trials'];	
	var dMenu = solGS.dataset.getDatasetsMenu(dType);
	
	if (listMenu.match(/option/) != null) {
            
            jQuery("#pca_pops_list").append(listMenu);
	    jQuery("#pca_pops_list_select").append(dMenu);

        } else {            
            jQuery("#pca_pops_list").append("<select><option>no lists found - Log in</option></select>");
        }
    }
               
});


jQuery(document).ready( function() { 

    jQuery("#run_pca").click(function() {
	solGS.pca.pcaRun();
    }); 
  
});


jQuery(document).ready( function() { 
     
    var url = document.URL;
    
    if (url.match(/pca\/analysis/)) {  
        var selectId;
	var selectName;
        var dataStructure;
	
        jQuery("<option>", {value: '', selected: true}).prependTo("#pca_pops_list_select");
        
        jQuery("#pca_pops_list_select").change(function() {        
            selectId = jQuery(this).find("option:selected").val();
            selectName = jQuery(this).find("option:selected").text();    
            dataStructure  = jQuery(this).find("option:selected").attr('name');
	    
	    if (dataStructure == undefined) {
		dataStructure = 'list';
	    }
	   
            if (selectId) {                
                jQuery("#pca_go_btn").click(function() {
                    solGS.pca.loadPcaPops(selectId, selectName, dataStructure);
                });
            }
        });
    } 

    // if (url.match(/pca\/analysis\/|solgs\/trait\/|breeders\/trial\/|solgs\/selection\//)) {
    // 	checkPcaResult();  
    // }
    
});

jQuery.fn.doesExist = function(){

        return jQuery(this).length > 0;

 };




