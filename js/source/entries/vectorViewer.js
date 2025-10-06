import "../legacy/jquery.js";
import "../legacy/jqueryui.js";
import "../legacy/d3/d3v4Min.js";
import "../legacy/jquery/dataTables.js";
import "../legacy/jquery/dataTables-buttons-min.js";

var metadata;
//var vectorLength;
var vectorName;
var sequence;
var table_data = [];
//var table_data_RESites = [];
var svgWidth, svgHeight;
var margin, width, height, radius;
var svg;
//var data = [];
var re_sites_table = new Array();

export function init(vector_id) {

    console.log('INIT VECTORVIEWER ??');
  
    sequence = "";
    
    // append the svg object to the body of the page
    margin = {top: 100, right: 100, bottom: 100, left: 100},
    width = 1000 - margin.left - margin.right,
    height = 1000 - margin.top - margin.bottom,
    radius = Math.min(width, height) / 4;
    
    svgWidth = width + margin.left + margin.right;
    svgHeight = height + margin.top + margin.bottom;
    
    svg = d3.select("#vector_div")
	.append("svg")
	.attr("width", svgWidth)
	.attr("height", svgHeight)
	.append("g")
	.attr("class", "mainGroup")
	.attr("transform", "translate(" + width/2 + "," + height/2 + ")");

    console.log('cp 2');
    
    //attaching the function to a button
    d3.select('#update_vector').on("click", function() {
	var feature_table = getFeatureDataFromDataTable();
	var re_sites_table = getREsitesDataFromDataTable();
//	alert('RE_SITES_TABLE = '+JSON.stringify(re_sites_table));
	var metadata = getMetadataFromDataTable();
	
	updateVector(metadata, feature_table, re_sites_table)
    });
    
    jQuery('#zoomIn').on('click', function() {
	radius *= 1.2;
	svgWidth *= 1.2;
	svgHeight *= 1.2;
	
	var feature_table = getFeatureDataFromDataTable();
	var re_sites_table = getREsitesDataFromDataTable();
	var metadata = getMetadataFromDataTable();
	    
	updateVector(metadata, feature_table, re_sites_table);  
    });
    
    jQuery('#zoomOut').on('click', function() {
	radius /= 1.2;
	svgWidth /= 1.2;
	svgHeight /= 1.2;
	
	var feature_table = getFeatureDataFromDataTable();
	var re_sites_table = getREsitesDataFromDataTable();
	var metadata = getMetadataFromDataTable();
	
	updateVector(metadata, feature_table, re_sites_table);  
    });
    
    var columnDefs = [{
	title: "Feature Name",
	type: "string-utf8",
    }, {
	title: "Start Coord",
	type: "num",
    }, {
	title: "End Coord",
	type: "num", 
    }, {
	title: "Color",
	type: "string-utf8",
    }, {
	title: "Orientation",
	type: "string-utf8"
    }, {
        title: "Actions",
        type: "string-utf8"
    }
		     ];

//    alert('formatting vector table');
//     var myTable = jQuery('#vector_table').DataTable({
// 	"sPaginationType": "full_numbers",
// 	data: table_data,
// //	columns: columnDefs,
// 	dom: 'Bfrtip',        // Needs button container
// 	select: 'single',
// 	responsive: true,
// 	altEditor: true,     // Enable altEditor
// 	buttons: [
//         //     {
// 	// 	text: 'Add',
// 	// 	name: 'add'        // do not change name
//         //     },
//         //     {
// 	// 	extend: 'selected', // Bind to Selected row
// 	// 	text: 'Edit',
// 	// 	name: 'edit'        // do not change name
//         //     },
//         //     {
// 	// 	extend: 'selected', // Bind to Selected row
// 	// 	text: 'Delete',
// 	// 	name: 'delete'      // do not change name
//         //     }
// 	]
//     });
    
//     //RE sites table
//     var columnDefs2 = [{
// 	title: "Restriction Enzyme Site",
// 	type: "string-utf8"
//     }, {
// 	title: "Cut Coord",
// 	type: "num",
//     }, {
//         title: "Actions",
//         type: "string-utf8"  }];

//     //alert('formatting re sites table');
//     var myTable2 = jQuery('#re_sites_table').DataTable({
// 	"sPaginationType": "full_numbers",
// 	data: [ [ ] ],
// //	columns: columnDefs2,
// 	//dom: 'Bfrtip',        // Needs button container
// 	select: 'single',
// 	responsive: true,
// 	//altEditor: true,     // Enable altEditor
// 	//buttons: [
//         //     {
// 	// 	text: 'Add',
// 	// 	name: 'add'        // do not change name
//         //     },
//         //     {
// 	// 	extend: 'selected', // Bind to Selected row
// 	// 	text: 'Edit',
// 	// 	name: 'edit'        // do not change name
//         //     },
//         //     {
// 	// 	extend: 'selected', // Bind to Selected row
// 	// 	text: 'Delete',
// 	// 	name: 'delete'      // do not change name
//         //     }
// 	//]
//     });
    
    //alert('done');

//    jQuery('#add_feature_dialog').dialog({
//	autoOpen: false,
	
	
  //  });
	
    
    //If this isn't here, the dialog appears when we dont want it to
    jQuery("#saveDialog").dialog({
	autoOpen: false
    });
    
    //when someone clicks save the dialog is opened
    jQuery("#saveVector").click(function () {
	jQuery('#saveDialog').dialog('open');
    });
    
    
    //Making data that can be stored
    jQuery("#dialogSaveButton").click(function () {
	var table_data = getFeatureDataFromDataTable();
	var re_sites_table = getREsitesDataFromDataTable();
	var metadata = getMetadataFromDataTable();
	var sequence = getSequenceDataFromDataTable();
	
	//	var id = jQuery("#saveInput").val();

//	alert(JSON.stringify(metadata) + " AND " + JSON.stringify(table_data) + " AND "+ JSON.stringify(re_sites_table) + " AND "+ sequence);
	
	var data = { 
	    'metadata' : metadata, 
	    'features' : table_data,
	    're_sites' : re_sites_table,
	    'sequence' : ""
	};

//	alert("NOW STRINGIFIED: "+ JSON.stringify(data) );
	
	var string_data = JSON.stringify(data);
	console.log(vector_id);
	console.log('Data as string: '+string_data);
	
	//This is the link where the data should be stored
	jQuery.ajax({
	    url: '/vectorviewer/' + vector_id + '/store?data='+string_data,
	    'method' : "POST"
	}).then(
	    function() {  alert('Sequence successfully saved!');},
	    function() { alert('An error occurred while trying to save the vector data.');
		       }
	);
	
    });

    jQuery('#open_add_feature_dialog_button').click( function() {
	jQuery('#feature_table_row_id').val("");
	jQuery('#feature_name').val("");
	jQuery('#feature_start_coord').val("");
	jQuery('#feature_end_coord').val("");
	jQuery('#feature_color_select').val("");
	jQuery('#feature_orientation_select').val("");

	jQuery('#manage_feature_dialog_title').html('Add feature');


	jQuery('#add_feature_dialog').modal('show');
	jQuery('#feature_name').focus();
    });
    
    //If this isn't here, the dialog appears when we dont want it to
    jQuery("#loadDialog").dialog({
	autoOpen: false
    });
    
    //when someone clicks load the dialog is opened
    jQuery("#loadVector").click(function () {
	jQuery('#loadDialog').dialog('open');
    });
    
//    jQuery("#dialogLoadButton").click(function () {
//	console.log('HELLO!');
	
//	var id = jQuery("#loadInput").val();
	
//	console.log(id);
//	retrieveVector(id);
//    });

//    alert('Retrieving vector '+vector_id);
    jQuery.ajax({
	url: '/vectorviewer/' + vector_id + '/retrieve',
    }).then(function(r) {
//	alert("RETRIEVED DATA: "+JSON.stringify(r));
	updateFeatureDataTable(r.features);
	updateREsitesDataTable(r.re_sites);
	updateMetadataDataTable(r.metadata);
	if (r.sequence) { updateSequenceDataTable(r.sequence); } 

//	alert("NOW HERE!");
	metadata = r.metadata;
	var feature_table = r.features;
	//re_sites_table = r.re_sites;
	//	alert("GOING TO UPDATE VECTOR USING "+JSON.stringify(r));


	var re_sites_table = getREsitesDataFromDataTable();
	
	updateVector(metadata, feature_table, re_sites_table);
    },
	    function(r) {
		alert('An error occurred! '+JSON.stringify(r));
	    } );
    
    jQuery('#add_feature_data_submit_button').click( function() {
//	alert('clicked add feature data!');
	
	var feature_name = jQuery('#feature_name').val();
	var start_coord = jQuery('#feature_start_coord').val();
	var end_coord = jQuery('#feature_end_coord').val();
	var feature_color = jQuery('#feature_color_select option:selected').text();
	var orientation = jQuery('#feature_orientation_select option:selected').text();
	var row = [ feature_name, start_coord, end_coord, feature_color, orientation ];

	
//	alert(JSON.stringify(row));
	featureDataTableAddRow(row);
	jQuery('#add_feature_dialog').modal("hide");
    });

    jQuery('#add_restriction_site_submit_button').click( function() {
//	alert('clicked add restriction site!');

	var feature_name = jQuery('#re_site_name').val();
	var start_coord = jQuery('#re_site_cut_coord').val();

	var row = [ feature_name, start_coord ];

//	alert('ADDING ROW '+JSON.stringify(row));
	re_site_datatable_add_row(row);
    });

    jQuery('#add_re_site_button').click( function() {
	jQuery('#re_site_name').val("");
	jQuery('#re_site_cut_coord').val("");
	jQuery('#re_site_table_row_id').val("");

	jQuery('#add_re_dialog').modal('show');

	jQuery('#re_site_name').focus();
    });

//    alert('now activating the delete click');
    jQuery('#vector_table tbody').on('click', '.delete_row_button', function() {
	delete_feature_table_row(jQuery(this).data('id'));
//	var rowId = $(this).data('id'); // Get the ID from the clicked button's data-id attribute
//	alert('Button clicked for row ID: ' + rowId);
	// Perform desired actions here, e.g., open a modal, redirect, etc.	
    });

    jQuery('#vector_table tbody').on('click', '.edit_row_button', function() {
	var rowId = jQuery(this).data('id'); // Get the ID from the clicked button's data-id attribute
//	alert('Opening dialog edit for id '+rowId);

	var data = getFeatureDataFromDataTable();

	jQuery('#feature_table_row_id').val(rowId);
	jQuery('#feature_name').val(data[rowId][0]);
	jQuery('#feature_start_coord').val(data[rowId][1]);
	jQuery('#feature_end_coord').val(data[rowId][2]);
	jQuery('#feature_color_select').val(data[rowId][3]);
	jQuery('#feature_orientation_select').val(data[rowId][4]);

	jQuery('#manage_feature_dialog_title').html('Edit feature');

	jQuery('#add_feature_dialog').modal("show");

	jQuery('#feature_name').focus();
	
    });

    jQuery('#re_sites_table tbody').on('click', '.delete_re_row_button', function() {

	var data = jQuery(this).data();
//	alert('RETRIEVED: '+JSON.stringify(data));
	var yes = confirm('Are you sure that you would like to delete this row with id ? ');
	if (yes) { 
	    delete_re_table_row(jQuery(this).data('id'));
	}
	jQuery('#add_feature_dialog').modal("hide");
    });

    jQuery('#re_sites_table tbody').on('click', '.edit_re_row_button', function() {
	var rowId = jQuery(this).data('id');
	var data = getREsitesDataFromDataTable();
	jQuery('#re_site_name').val(data[rowId][0]);
	jQuery('#re_site_cut_coord').val(data[rowId][1]);
	jQuery('#re_site_table_row_id').val(rowId);
					 
	jQuery('#add_re_dialog').modal("show");

	jQuery('#re_site_name').focus();
    });



//    alert('INIT completed.');
    
}



export function updateFeatureDataTable(table_data) {
    //alert('TABLE DATA: '+JSON.stringify(table_data));

    var formatted = new Array();
    for (var i=0; i < table_data.length; i++) {
	formatted.push( { no : i, feature : table_data[i][0], start : table_data[i][1], end : table_data[i][2], color: table_data[i][3], orientation: table_data[i][4] });
    }
    
    jQuery('#vector_table').DataTable({
	data: formatted,
	destroy: true,
	columns: [
	    { title: 'No.', data : 'no' },
	    { title: 'Feature', data : 'feature' }, //data: table_data[0] },
	    { title: 'Start', data: 'start' },
	    { title: 'End', data: 'end' },
	    { title: 'Color', data: 'color' },
	    { title: 'Orientation', data: 'orientation' },
	    { data: null,
	      render: function(data, type, row) {
		  var formatted = '<button class="edit_row_button" data-id="'+row.no+'">Edit</button>&nbsp;<button class="delete_row_button" data-id="'+row.no+'">Delete</button>';
		  //alert('Formatted: '+formatted);
		  return formatted;
	      },
	      title: "Actions",
	    }
	]
    });
}

function featureDataTableAddRow(row) {

    var data = getFeatureDataFromDataTable();

    var row_id = jQuery('#feature_table_row_id').val(); 
    if (row_id === undefined) {
	data.push(row);
    }
    else {
	data[row_id] = row;
    }

    updateFeatureDataTable(data);
}

export function re_site_datatable_add_row(row){

    var data = getREsitesDataFromDataTable();

    var row_id = jQuery('#re_site_table_row_id').val();

    if (row_id === undefined) { 
//    alert('RE Sites data now: '+JSON.stringify(data));
	data.push(row);
    }
    else {
	data[row_id] = row;
    }
    updateREsitesDataTable(data);
    jQuery('#add_re_dialog').modal("hide");
}

export function delete_feature_table_row(row_no) {
    //alert('delete_feature_table_row!');
    var yes = confirm('Delete row '+row_no+'?');
    if (yes) {
//	alert('Deleting it.');
	var data = getFeatureDataFromDataTable();

//	alert('BEfore delete: '+JSON.stringify(data));
	data.splice(row_no, 1);
//    	alert('After delete: '+JSON.stringify(data));
	
	updateFeatureDataTable(data);
//	alert('Done!');
    }
}

export function delete_re_table_row(row_no) {
    var yes = confirm('Delete row '+row_no+'?');
    if (yes) { 
	var data = getREsitesDataFromDataTable();
	data.splice(row_no, 1);
	updateREsitesDataTable(data);
    }
}

export function getFeatureDataFromDataTable() {
//    alert('getFeatureDataFromDataTable');
    
    var table_hash_rows = jQuery('#vector_table').DataTable().rows().data().toArray();

    var table_data = new Array();
    for (var i=0; i<table_hash_rows.length; i++) {
	table_data.push( [ table_hash_rows[i].feature, table_hash_rows[i].start, table_hash_rows[i].end, table_hash_rows[i].color, table_hash_rows[i].orientation ]);
    }
    return table_data;
}

export function getREsitesDataFromDataTable() {
 
    var table_data = jQuery('#re_sites_table').DataTable().rows().data().toArray();
    var table_data_array = structuredClone(table_data);
//    alert('getREsitesDataFromDataTable '+JSON.stringify(table_data_array));
    delete(table_data_array.context);
    delete(table_data_array.selector);
    delete(table_data_array.ajax);
//    alert('BEFORE: '+JSON.stringify(table_data_array));
    //remove actions and index columns
    for (let i = 0; i < table_data_array.length; i++) {
	table_data_array[i].splice(3, 1); // Remove 1 element starting from columnIndex
	table_data_array[i].shift(); // remove index column
    }
//    alert('AFTER: '+JSON.stringify(table_data_array));
    return table_data_array;
}

export function getMetadataFromDataTable() {
    var table_data = jQuery('#metadata_table').DataTable().rows().data().toArray();
    delete(table_data.context);
    delete(table_data.selector);
    delete(table_data.ajax);
    
    //remove actions column
    for (let i = 0; i < table_data.length; i++) {
	table_data[i].splice(2, 1); // Remove 1 element starting from columnIndex
    }

//    alert('getMetadataFromDataTable return data: '+JSON.stringify(table_data));
    return table_data;
}

export function getSequenceDataFromDataTable() {
    var table_data = jQuery('#sequence_table').DataTable().rows().data().toArray();
    delete(table_data.context);
    delete(table_data.selector);
    delete(table_data.ajax);

//    alert('getSequenceDataFromDataTable '+JSON.stringify(table_data));
    

}
    
export function updateREsitesDataTable(re_sites) {
//    alert('RESITES FOR TABLE: '+JSON.stringify(re_sites));
    for (var i=0; i < re_sites.length; i++) {
	re_sites[i][2] = '<button class="edit_re_row_button" data-id="'+i+'">Edit</button>&nbsp;<button class="delete_re_row_button" data-id="'+i+'">Delete</button>';
	//alert(JSON.stringify(re_sites[i]));
	re_sites[i].unshift(i);
    }
//    alert('RESITES FORMATTED: '+JSON.stringify(re_sites));
    jQuery('#re_sites_table').DataTable({
	destroy: true,
	data: re_sites
    });
}
	
export function updateMetadataDataTable(metadata) {

    var row = new Array();
    row.push(metadata[0][0]);
    row.push(metadata[0][1]);
//    row.push('<button>Edit</button>');

    var data = new Array();
    data.push(row);
    
    jQuery('#metadata_table').DataTable({
	destroy: true,
	data: data,
	"bLengthChange" : false,
	"bFilter" : false,
	"bInfo" : false
    });
}

export function updateSequenceDataTable(sequence) {

    var seq_array = new Array();
//    for(var i=0; i<sequence.length; i++) {
//	seq_array.push(sequence.substring(i * 60, i * 60+60));
//    }
//    var formatted_seq = seq_array.join("<br />");
//    var data = [ [ formatted_seq ] ];
//    jQuery('#sequence_table').DataTable({
//	destroy: true,
//	data: data
//    });
}

// drawing / updating the vector as a function
//export function updateVector(metadata, table_data, re_sites) {
export function updateVector(metadata, feature_table, re_sites_table) { 
    
 //  alert('METADATA HERE: '+JSON.stringify(metadata));

    var metadata = getMetadataFromDataTable();
    var feature_table = getFeatureDataFromDataTable();
    var re_sites_table = getREsitesDataFromDataTable();

//    alert('TABLE DATA HERE '+JSON.stringify(feature_table));
//    alert('METADATA HERE: '+JSON.stringify(metadata));

//    alert('metadata: '+JSON.stringify(metadata));
//    alert('feature_table: '+JSON.stringify(feature_table));
//    alert('re_sites_table: '+JSON.stringify(re_sites_table));

    d3.selectAll("svg").selectAll("*").remove();
    var data = [];

//    alert('starting to draw...');
	
    d3.select("svg")
	.attr("width", svgWidth)
	.attr("height", svgHeight);
    
    //Calling the function with all the parameters
    draw_vector("vector_div", metadata, radius, re_sites_table, feature_table, svgWidth, svgHeight);
}

export function draw_vector(vector_div, metadata, radius, re_sites_table, feature_table, svgWidth, svgHeight) { 

    const centerTranslationWidth = svgWidth/2;
    const centerTranslationHeight = svgHeight/2;

    var vectorLength = parseInt(metadata[0][1]); // in bp
    var vectorName = metadata[0][0];

//    alert('vectorLength='+vectorLength+' vectorName='+vectorName);
    var data = new Array();
    
    for (var i = 0; i < feature_table.length; i++) {	
	//setting up the orientation
	// var orientation = '>';
	// if (
	//     (feature_table[i][2] / vectorLength * Math.PI * 2 > Math.PI / 2) &&
	// 	(feature_table[i][1] / vectorLength * Math.PI * 2 < Math.PI * 1.5)
	// ) {
	//     orientation = (feature_table[i][4] === 'R') ? ">" : "<";
	// } else {
	//     if (feature_table[i][4] === 'R') orientation = '<';
	// }
	
	//defining a variable that is used to draw vectors that wrap around 0 -- if they do, you need to add 2 pi to the end angle otherwise it draws the arc the wrong direction
	
	var wrapAround = 0;
	
	if (parseInt(feature_table[i][1]) > parseInt(feature_table[i][2])) {
	    console.log('1 '+feature_table[i][1]+' 2 '+feature_table[i][2]);
	    var wrapAround = 2 * Math.PI;
	    console.log('wraparound for '+JSON.stringify(feature_table[i]));
	}
	
	console.log('Wraparound is '+wrapAround);

//	alert('VectorLength = '+vectorLength);
	//Convert the data from feature_table into a useable form inside the "data" dataset
	data.push({
	    name: feature_table[i][0],
	    startAngle: parseInt(feature_table[i][1]) / vectorLength * Math.PI * 2,
	    endAngle: parseInt(feature_table[i][2]) / vectorLength * Math.PI * 2 + wrapAround,
	    color: feature_table[i][3]
	});
    }

    
//    alert("NOW HERE 2 with data = "+JSON.stringify(data));
    /////// note the re_sites array should have the correct format?
    //Anoter for each loop, this time for the RE sites

    var re_sites = new Array();
    for (var i = 0; i < re_sites_table.length; i++) {
     	var name = re_sites_table[i][0];
     	var cutCoord = re_sites_table[i][1];
	
	//Convert the data from feature_table_RESites into a useable form inside the "re_sites" dataset
	re_sites.push({
	    name: name,
	    cutCoord: cutCoord
	});
    };

//    alert('RE SITES NOW: '+JSON.stringify(re_sites));
    
    d3.select("body").selectAll("svg").selectAll("*").remove();
    
    var vectorLengthLabelG = d3.select("body").select("svg").append("g").attr("class", "labelLengthGroup").attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")");
    const vectorLengthLabel = vectorLengthLabelG.append("path")
	  .attr("id", "lengthLabel")
	  .attr("stroke", "black")
	  .attr("stroke-width", 2)
	  .attr("fill", "none")
	  .style("display", "none");


    //vectorLength = metadata[1];
    
    var backbonearcgen = d3.arc()
	.outerRadius(radius + (.05 * radius))
	.innerRadius(radius - (.05 * radius) );
    
    var backbonedata = [ { startAngle: 0, endAngle: Math.PI * 2 } ];

    var baseArcG = d3.select("body").select("svg").append("g").attr("class", "baseArc").attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")");
    
    baseArcG.selectAll("path")
	.data(backbonedata)
	.enter()
	.append("path")
	.attr("d", backbonearcgen)
	.attr("fill", "gray")
	.attr("stroke", "black")
	.attr("stroke-width", 1);

    
    var geneOuterRadius = radius + (20/200 * radius);
    var geneInnerRadius = radius - (20/200 * radius);
    
    var geneArc = d3.arc()
	.outerRadius(geneOuterRadius)
	.innerRadius(geneInnerRadius);
    
    var vectorGeneBlockG = d3.select("body").select("svg").append("g").attr("class", "vectorGeneBlock").attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")");
    
    data.forEach(function(d, i) {
	vectorGeneBlockG
	    .append("path")
	    .datum(d)
	    .attr("d", geneArc)
	    .attr("stroke", "gray")
	    .attr("class", "featureClass")
	    .attr("stroke-width", 4)
	    .attr("id", function(d,i) { return "featureClass_"+i; }) //Unique id for each slice
	    .attr("fill", function(d,i) { return d.color; }  );
    });

    d3.selectAll(".featureClass")
	.each(function(d, i) {
	    
	    var path = d3.select(this);
	    var pathD = path.attr("d");

	    var firstArcSection = /(^.+?)L/;
	    var arcs = firstArcSection.exec(pathD);
	    if (arcs === null) { console.log('no match!'); return false; }
	    var newArc = firstArcSection.exec(pathD)[1];

	    newArc = newArc.replace(/,/g, " ");

	    var midAngle = (d.startAngle + d.endAngle) / 2;
	    
	    if (d.startAngle > d.endAngle) {
		var midAngle = ((d.endAngle - 2 * Math.PI) + d.startAngle + 2 * Math.PI) % (2 * Math.PI);
	    }

	    var flipText = false;
	    
	    if ((d.endAngle < d.startAngle && (midAngle < Math.PI / 2 || midAngle > 3 * Math.PI / 2)) ||
		(d.endAngle > d.startAngle && (midAngle > Math.PI / 2 && midAngle < 3 * Math.PI / 2))) {
		var startLoc = /M(.*?)A/;
		var middleLoc = /A(.*?)0 0 1/;
		var endLoc = /0 0 1 (.*?)$/;
		var newStart = endLoc.exec(newArc)[1];
		var newEnd = startLoc.exec(newArc)[1];
		var middleSec = middleLoc.exec(newArc)[1];
		newArc = "M" + newStart + "A" + middleSec + "0 0 0 " + newEnd;
		flipText = true;
	    }
	    // Create a group for each gene's label
	    const labelGroup = d3.select("body").select("svg")
		  .append("g")
		  .attr("class", "geneLabel")
		  .attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")");
	    
	    // Append invisible arc path inside this group
	    labelGroup.append("path")
		.attr("id", "labelClass_" + i)
		.attr("d", newArc)
		.style("fill", "none");
	    
	    // Append text inside the same group, so it uses the correct path
	    labelGroup.append("text")
		.attr("class", "labelClass")
		.attr("dy", flipText 
		      ? (geneOuterRadius - geneInnerRadius) / 2 - 0.15*radius 
		      : (geneOuterRadius - geneInnerRadius) / 2 + 0.05*radius)
		.attr("stroke", "darkgray")
		.attr("font-family", "arial")
		.style("font-size", 0.60 * (geneOuterRadius - geneInnerRadius))
		.append("textPath")
		.attr("text-anchor", "middle")
		.attr("startOffset", "50%")
		.attr("xlink:href", "#labelClass_" + i)
		.text(d.name ?? `unnamed_gene_${i + 1}`);
	    
	    console.log(`Label for gene ${i}:`, d.name);
	    
	});

//    alert('table data now '+JSON.stringify(feature_table));
//    alert('data now: '+JSON.stringify(data));
    
    data.forEach(function(d,i) {
	// Label the Beginning of each gene

//	alert('label gene start '+JSON.stringify(d));
	
	var directionLabelOffset = (50 / vectorLength) * 2 * Math.PI;
	var directionLabelFlip = 0;
	var directionLabelStartAngle = d.endAngle + 1.5 * Math.PI;
	
	if (feature_table[i][4] === 'R') {
	    directionLabelStartAngle = d.endAngle + 1.5 * Math.PI;
	    directionLabelFlip = 0;
	    directionLabelOffset = (50 / vectorLength) * 2 * Math.PI;
	}
	else if (feature_table[i][4] === 'F')  {
	    directionLabelStartAngle = d.startAngle + 1.5 * Math.PI;
	    directionLabelFlip = 0;
	    directionLabelOffset = -(50 / vectorLength) * 2 * Math.PI;
	}
	else {
	    directionLabelStartAngle = d.startAngle * Math.PI;
	    directionLabelFlip = 0;
	    directionLabelOffset = 0;
	}
	
	// else if (feature_table[i][4] === undefined) {
	//     directionLabelStartAngle = d.startAngle;
	//     directionLabelFlip = 0;
	//     directionLabelOffset = (50 / vectorLength) * 2 * Math.PI;
	// }
	// else {
	//     alert('unknown orientation '+feature_table[i][4]);
	// }
	var directionLabelBackStartX = geneOuterRadius * Math.cos(directionLabelStartAngle + directionLabelFlip);
	var directionLabelBackStartY = geneOuterRadius * Math.sin(directionLabelStartAngle + directionLabelFlip);
	
	var directionLabelBackMiddleX = radius * Math.cos(directionLabelStartAngle - directionLabelOffset);
	var directionLabelBackMiddleY = radius * Math.sin(directionLabelStartAngle - directionLabelOffset);
	
	var directionLabelBackEndX = geneInnerRadius * Math.cos(directionLabelStartAngle + directionLabelFlip);
	var directionLabelBackEndY = geneInnerRadius * Math.sin(directionLabelStartAngle + directionLabelFlip);
	
	const directionLabelData = [
	    { x: directionLabelBackStartX, y: directionLabelBackStartY },
	    { x: directionLabelBackMiddleX, y: directionLabelBackMiddleY },
	    { x: directionLabelBackEndX, y: directionLabelBackEndY }
	];
	
	const lineFunctionLabelDirection = d3.line()
	      .x(function (d) { return d.x; })
	      .y(function (d) { return d.y; });
	
	d3.select("body").select("svg")
	    .append("g")
	    .attr("class", "directionLabel")
	    .attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")")
	    .append("path")
	    .datum(directionLabelData)
	    .attr("d", lineFunctionLabelDirection)
	    .attr("stroke", "gray")
	    .attr("stroke-width", "1")
	    .attr("fill", "gray");
	
	// Label the END of each gene
	var directionLabelOffsetEnd = (50 / vectorLength) * 2 * Math.PI;
	var directionLabelFlipEnd = 0;
	var directionLabelStartAngleEnd = d.endAngle + 1.5 * Math.PI;
	
	if (feature_table[i][4] === 'R') {
	    directionLabelStartAngleEnd = d.startAngle + 1.5 * Math.PI;
	    directionLabelFlipEnd = (50 / vectorLength) * 2 * Math.PI;
	    directionLabelOffsetEnd = 0;
	} else if (feature_table[i][4] === 'F') {
	    directionLabelStartAngleEnd = d.endAngle + 1.5 * Math.PI;
	    directionLabelFlipEnd = -(50 / vectorLength) * 2 * Math.PI;
	    directionLabelOffsetEnd = 0;
	    
	}
	else {  // for features without direction
	    directionLabelStartAngle = d.startAngle * Math.PI;
	    directionLabelFlip = 0;
	    directionLabelOffset = 0;
	}
	
	var directionLabelBackStartXEnd = geneOuterRadius * Math.cos(directionLabelStartAngleEnd + directionLabelFlipEnd);
	var directionLabelBackStartYEnd = geneOuterRadius * Math.sin(directionLabelStartAngleEnd + directionLabelFlipEnd);
	
	var directionLabelBackMiddleXEnd = radius * Math.cos(directionLabelStartAngleEnd - directionLabelOffsetEnd);
	var directionLabelBackMiddleYEnd = radius * Math.sin(directionLabelStartAngleEnd - directionLabelOffsetEnd);
	
	var directionLabelBackEndXEnd = geneInnerRadius * Math.cos(directionLabelStartAngleEnd + directionLabelFlipEnd);
	var directionLabelBackEndYEnd = geneInnerRadius * Math.sin(directionLabelStartAngleEnd + directionLabelFlipEnd);
	
	const directionLabelDataEnd = [
	    { x: directionLabelBackStartXEnd, y: directionLabelBackStartYEnd },
	    { x: directionLabelBackMiddleXEnd, y: directionLabelBackMiddleYEnd },
	    { x: directionLabelBackEndXEnd, y: directionLabelBackEndYEnd },
	    {x: geneInnerRadius * Math.cos(directionLabelStartAngleEnd), y: geneInnerRadius * Math.sin(directionLabelStartAngleEnd)},
	    {x: geneOuterRadius * Math.cos(directionLabelStartAngleEnd), y: geneOuterRadius * Math.sin(directionLabelStartAngleEnd)},
	    { x: directionLabelBackStartXEnd, y: directionLabelBackStartYEnd }
	    
	];
	
	const lineFunctionLabelDirectionEnd = d3.line()
	      .x(function (d) { return d.x; })
	      .y(function (d) { return d.y; });
	
	
	d3.select("body").select("svg")
	    .append("g")
	    .attr("class", "directionLabel")
	    .attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")")
	    .append("path")
	    .datum(directionLabelDataEnd)
	    .attr("d", lineFunctionLabelDirectionEnd)
	    .attr("stroke", "gray")
	    .attr("stroke-width", "1")
	    .attr("fill", "gray");
		
	//// Create invisible arc path for the label
	//d3.select("body").select("svg")
	//  .append("g")
	//  .attr("class", "geneLabel")
	//  .attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")")
	//  .append("path")
	//  .attr("id", "labelClass_" + i)
	//  .attr("d", newArc)
	//  .style("fill", "none");
	//
	//// Append gene label text to follow arc
	//d3.select("body").select("svg")
	//  .select(".geneLabel")
	//  .append("text")
	//  .attr("class", "labelClass")
	//  .attr("dy", flipText 
	//    ? (geneOuterRadius - geneInnerRadius) / 2 - .15*radius 
	//    : (geneOuterRadius - geneInnerRadius) / 2 + .05*radius)
	//  .attr("stroke", "darkgray")
	//  .attr("font-family", "arial")
	//  .style("font-size", 0.15 * radius)
	//  .append("textPath")
	//  .attr("text-anchor", "middle")
	//  .attr("startOffset", "50%")
	//  .attr("xlink:href", "#labelClass_" + i)
	//  .text(d.name);
    });
//}
//});

    //Highlight Group placed here for layering reasons
    const clickHighlightG = d3.select("svg").append("g")
	  .attr("class", "clickHighlight");
    
    const circleRadius = radius;
    const circleCenter = { x: 0, y: 0 };
    
    var vectorLabelG = d3.select("body").select("svg").append("g").attr("class", "labelGroup").attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")");

//    alert("METADATA NOW " + JSON.stringify(metadata));
    
    var vectorNameElement = vectorLabelG.selectAll("text")
	.data(metadata)
	.enter()
	.append("text")
	.attr("class", "labelVectorClass")
	.attr("text-anchor", "middle")
	.attr("x", 0)
	.attr("y", 0);
    
    vectorNameElement.each(function(d) {
//        alert('D = '+JSON.stringify(d));
        d3.select(this)
            .append("tspan")
            .attr("class", "vectorName")
            .attr("x", 0)
            .attr("dy", "0em")
            .attr("font-size", 0.1 * radius)
            .text("Name: " + d[0]);
	
        d3.select(this)
            .append("tspan")
            .attr("class", "vectorLength") 
            .attr("x", 0)
            .attr("dy", "1.2em")
            .attr("font-size", 0.1 * radius)
            .text("Length (bp): " + d[1]);
    });
    
    //// Paths for labeling RE sites
///    alert('X8');
    const vectorRadius = radius
    const lengthPastVector = .75 * radius
    const leftLabels = [];
    const rightLabels = [];

//    alert('X9');
    var vectorLabelREGroup = d3.select("body")
	.select("#"+vector_div)
	.select("svg")
	.append("g")
	.attr("class", "vectorLabelRE").attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")");
//        .lower();

//    alert('X10');
    re_sites.forEach(function(site, i) {
//	alert('working on re site '+JSON.stringify(site));
	const RELabelRads = (((site.cutCoord + 0.75 * vectorLength) % vectorLength) / vectorLength) * 2 * Math.PI;
	const RELabelX = (vectorRadius + lengthPastVector) * Math.cos(RELabelRads);
	const RELabelY = (vectorRadius + lengthPastVector) * Math.sin(RELabelRads);
	
	site._angle = RELabelRads;
	site._x = RELabelX;
	site._y = RELabelY;
	
	if (RELabelX >= 0) {
	    rightLabels.push(site);
	} else {
	    leftLabels.push(site);
	}
    });
    
//    alert('rightLabels: '+JSON.stringify(rightLabels));
    

    spaceLabelsWithCollisionAvoidance(leftLabels, "left");
    spaceLabelsWithCollisionAvoidance(rightLabels, "right");
    
    //// THIS IS FOR THE SQUARE SHAPED RE LABELS!!
    //  [...leftLabels, ...rightLabels].forEach((site, i) =>{
    //    const RELabelSideX = site._x > 0 ? 400 : -400;
    //    const RELabelTextOffset = RELabelSideX > 0 ? -40 : 40;
    //    
    //    const vectorLabelStartPointX = circleRadius * Math.cos(site._angle); 
    //    const vectorLabelStartPointY = circleRadius * Math.sin(site._angle);
    //
    //  const RELabelData = [
    //    {x: vectorLabelStartPointX, y: vectorLabelStartPointY},
    //    {x: site._x, y: site.labelY},
    //    {x: RELabelSideX, y: site.labelY}
    //  ];
    
//    alert('X11');
    [...leftLabels, ...rightLabels].forEach((site, i) =>{
	const RELabelSideX = site._x > 0 ? (.2 * radius) : (-.2 * radius);
	var RELabelOffset = (.75 * radius);
	
	const vectorLabelStartPointX = circleRadius * Math.cos(site._angle); 
	const vectorLabelStartPointY = circleRadius * Math.sin(site._angle);

	if ( vectorLabelStartPointX > 0) {
	    RELabelOffset = (.75 * radius);
	} else {
	    RELabelOffset = (-.75 * radius);
	};
	
	const RELabeXPos = site._x + RELabelOffset;
	
	
	const RELabelData = [
	    {x: vectorLabelStartPointX, y: vectorLabelStartPointY},
	    {x: site._x, y: site.labelY},
	    {x: site._x + RELabelOffset, y: site.labelY},
	    //    {x: RELabelSideX, y: site.labelY}
	];
	
	//FINDME
	
	const lineFunctionLabelRE = d3.line()
	      .x(function (d) {return d.x;})
	      .y(function (d) {return d.y;});
	
	
	const sharedIDVectorLabel = "re-label-" + i;

//	alert('X12');
	
	vectorLabelREGroup.insert("path")
            .datum(RELabelData)
            .attr("class", "labelVectorClass " + sharedIDVectorLabel)
            .attr("d", lineFunctionLabelRE)
            .attr("stroke", "gray").attr("stroke-width", "3").attr("fill", "none")
            .on("mouseover", function(){
		d3.selectAll("." + sharedIDVectorLabel)
		    .style("font-size", 0.15 * radius)
		    .attr("stroke", "black")
		    .attr("stroke-width", "7")
		    .style("font-weight", "bold")
            })
            .on("mouseout", function () {
		d3.selectAll("." + sharedIDVectorLabel)
		    .style("font-size", 0.2 * radius)
		    .attr("stroke", "gray")
		    .style("font-weight", "normal")
		    .attr("stroke-width", "3")
            });
	
//	alert('X13');
        var vectorLabelTextREElement = vectorLabelREGroup.insert("text")
            .text(site.name)
            .attr("x", RELabeXPos)
            .attr("y", site.labelY - (.02 * radius))
            .attr("font-size", 0.1 * radius)
            .style("fill", "black")
	//        .attr("text-anchor", RELabelSideX > 0 ? "start" : "end")
            .on("mouseover", function(){
		d3.selectAll("." + sharedIDVectorLabel)
		    .style("font-size", 0.15 * radius)
		    .attr("stroke", "black")
		    .attr("stroke-width", "7")
		    .style("font-weight", "bold")
            })
            .on("mouseout", function () {
		d3.selectAll("." + sharedIDVectorLabel)
		    .style("font-size", 0.1 * radius)
		    .attr("stroke", "gray")
		    .style("font-weight", "normal")
		    .attr("stroke-width", "3")
            });
        if (RELabeXPos >= 0) {
            vectorLabelTextREElement.attr("text-anchor", "end");
        } else {
            vectorLabelTextREElement.attr("text-anchor", "start");
        };
	
	vectorLabelTextREElement.lower();
	vectorLabelREGroup.lower();	
    }); 
    
    // Arc that displays where you are on the vector (in BP)
    
//    alert('X14');
    //var vectorLengthLabelG = d3.select("body").select("svg").append("g").attr("class", "labelLengthGroup").attr("transform", "translate(500,500)");
    var mouseOverEventArc = vectorLengthLabelG.append("path")
	.datum({startAngle: 0, endAngle: 2*Math.PI})
	.attr("d", d3.arc().innerRadius(radius-(.1 * radius)).outerRadius(radius+(.1 * radius)))
	.attr("fill", "transparent")
	.attr("stroke", "transparent")
	.attr("strokewidth", "2")
	.attr("strokewidth", (.15 * radius))
	.style("pointer-events", "all");
    //  .on("mousemove", handleMouseMove);

//    alert('X15');
    const valueText =   vectorLengthLabelG.append("text")
	  .attr("x", circleCenter.x)
	  .attr("y", circleCenter.y + "2.4em")
	  .attr("text-anchor", "middle")
	  .style("fill", "black")
	  .style("font-size", 0.1 * radius);
    
    const valueTextRotatingLabel = vectorLengthLabelG.append("text")
	  .style("fill", "black")
	  .style("font-size", 0.1 * radius);


    mouseOverEventArc
	.on("mousemove", function () {
    
	    const [mouseX, mouseY] = d3.mouse(this);

	    const deltaX = mouseX - circleCenter.x;
	    const deltaY = mouseY - circleCenter.y;


	    let angleInRadians = Math.atan2(-deltaY, -deltaX);

	    angleInRadians -= Math.PI / 2;  
	    if (angleInRadians < 0) {
		angleInRadians += 2*Math.PI
	    }

	    const arcLengthDisplay = angleInRadians * circleRadius; // Arc length = angle (in radians) * radius

	    const circumference = 2 * Math.PI * circleRadius; // Calculate the circle's circumference

	    const valueLength = Math.round((arcLengthDisplay / circumference) * (vectorLength - 1)) + 1;

	    valueText.text("Location: "+valueLength);

	    var halfPi = 1/2 * Math.PI;

	    var extraLengthForLengthLabel = 40;
	    var labelLengthLabelX2 = (circleRadius + extraLengthForLengthLabel) * Math.cos(angleInRadians - halfPi);
	    var labelLengthLabelY2 = (circleRadius + extraLengthForLengthLabel) * Math.sin(angleInRadians - halfPi);
	    var labelLengthOffset = 40;

	    if (labelLengthLabelX2 >= 0) {
		labelLengthOffset = (.2 * radius);
	    } else {
		labelLengthOffset = (-.2 * radius);
	    };

	    var  labelLengthLabelX3 = labelLengthLabelX2 + labelLengthOffset;

	    const lengthLabelData = [
		{x: circleRadius * Math.cos(angleInRadians - halfPi), y: circleRadius * Math.sin(angleInRadians - halfPi)},
		{x: labelLengthLabelX2, y: labelLengthLabelY2},
		{x: labelLengthLabelX3, y: labelLengthLabelY2}
	    ]; 

	    const lengthLabelLine = d3.line()
		  .x(function (d) {return d.x})
		  .y(function (d) {return d.y});

	    vectorLengthLabel
		.datum(lengthLabelData)
		.attr("d", lengthLabelLine)
		.style("display", "block");

	    var rotatingLabelLengthOffset = (.2 * radius);

	    if (labelLengthLabelX2 >= 0) {
		rotatingLabelLengthOffset = (-.175 * radius);
	    } else {
		rotatingLabelLengthOffset = (.175 * radius);
	    };

	    valueTextRotatingLabel
		.attr("x", labelLengthLabelX3 + rotatingLabelLengthOffset)
		.attr("y", labelLengthLabelY2 - (.01 * radius));

	    valueTextRotatingLabel.text(valueLength).attr("font-weight", "bold");

	    if (labelLengthLabelX3 >= 0) {
		valueTextRotatingLabel.attr("text-anchor", "start");
	    } else {
		valueTextRotatingLabel.attr("text-anchor", "end");
	    };

	})
	.on("mouseout", function () {
	    vectorLengthLabel.style("display", "none");
	    valueText.text("");
	    valueTextRotatingLabel.text("");
	});

    d3.select(".labelLengthGroup").each(function() {
	this.parentNode.appendChild(this); // moves it to bottom of <svg> = top visually
    });

    ///var buttonG = d3.select("svg").append("g").attr("class", "buttonClass")
    ///
    ///var zoomOut = buttonG.append("foreignObject");
    ///
    ///zoomOut.attr("x", svgWidth - 110/200 * radius) // offset from right
    ///  .attr("y", svgHeight - 50/200 * radius) // offset from bottom
    ///  .attr("width", 40/200 * radius)
    ///  .attr("height", 40/200 * radius)
    ///  .attr("id", "zoomOut")
    ///  .append("xhtml:button") 
    ///  .style("width", "100%")
    ///  .style("height", "100%")
    ///  .style("font-size", 30/200 * radius)
    ///  .text("-");
    //d3.select("#"+vector_div).select("#zoomOut").on("click", function() {
    //    console.log("Zoom Out");
    //    svgHeight = svgHeight / 1.2;
    //    svgWidth = svgWidth / 1.2;
    //    console.log(svgHeight, svgWidth);
    //    console.log(centerTranslationHeight);
    //});
    
    ///var zoomIn = buttonG.append("foreignObject");
    ///
    ///zoomIn.attr("x", svgWidth - 50/200 * radius) // offset from right
    ///  .attr("y", svgHeight - 50/200 * radius) // offset from bottom
    ///  .attr("width", 40/200 * radius)
    ///  .attr("height", 40/200 * radius)
    ///  .attr("id", "zoomIn")
    ///  .append("xhtml:button") 
    ///  .style("width", "100%")
    ///  .style("height", "100%")
    ///  .style("font-size", 30/200 * radius)
    ///  .text("+");
    //  d3.select("#"+vector_div).select("#zoomOut").on("click", function() {
    //    console.log("Zoom In");
    //    svgHeight = svgHeight * 1.2;
    //    svgWidth = svgWidth * 1.2;
    //    console.log(svgHeight, svgWidth);
    //    console.log(centerTranslationHeight);
    //  });
    
    
    let currentHighlightPath = null;
    let selectedRegions = [];
    let isDragging = false;
    
    d3.select("svg").on("mousedown", function () {
	
	if (currentHighlightPath) {
	    currentHighlightPath.remove();
	    currentHighlightPath = null;
	}
	
	selectedRegions = [];
	
	d3.selectAll(".clickHighlightText").remove();
	
	
	const [mouseX, mouseY] = d3.mouse(this);
	const angle = calculateAngle(mouseX, mouseY);
	
	d3.select()
	
	const path = clickHighlightG.append("path")
	      .attr("class", "highlightArc")
	//    .attr("fill", "rgba(255, 200, 0, 0.4)") // Highlight color
	      .attr("fill", "pink") // Highlight color
	      .attr("stroke", "orange")
	      .attr("stroke-width", 1);
	
	selectedRegions.push({
	    startAngle: angle,
	    endAngle: angle,
	    path: path
	});
	currentHighlightPath = path;
	
	isDragging = true;
    })
	.on("mousemove", function () {
	    if (!isDragging) return;
	    
	    const [mouseX, mouseY] = d3.mouse(this);
	    const currentAngle = calculateAngle(mouseX, mouseY);
	    
	    const lastRegion = selectedRegions[selectedRegions.length - 1];
	    
	    let start = lastRegion.startAngle;
	    let end = currentAngle;
	    if (end < start) end += 2 * Math.PI;
	    
	    const arcHighlightGen = d3.arc()
		  .innerRadius(radius - 20/200 * radius)
		  .outerRadius(radius + 20/200 * radius)
		  .startAngle(start)
		  .endAngle(end);
	    
	    
	    
	    lastRegion.endAngle = currentAngle;
	    const highlightArc = lastRegion.path
		  .datum({ startAngle: start, endAngle: end })
		  .attr("d", arcHighlightGen)
		  .attr("transform", `translate(${svgWidth / 2}, ${svgHeight / 2})`)
		  .attr("fill", "rgba(255, 0, 255, 0.3)")  
		  .attr("stroke", "#000000")              
		  .attr("stroke-width", 2);    
	    
	    highlightArc.attr("class", "highlightArc")
	    
	});
    
    
    d3.select("svg").on("mouseup", function () {
	if (!isDragging) return;
	isDragging = false;
	
	const lastRegion = selectedRegions[selectedRegions.length - 1];
	const startBP = angleToBasePair(lastRegion.startAngle);
	const endBP = angleToBasePair(lastRegion.endAngle);
	
	console.log('Selected region: BP ${startBP} to BP ${endBP}');
	
	
	console.log(lastRegion.startAngle, lastRegion.endAngle)
	
	
	// Display start point
	var clickHighlightTextG = d3.select("svg").append("g").attr("class", "clickHighlightText").attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")")
	clickHighlightTextG
	    .append("text")
	    .attr("x", 0)
	    .attr("dy", "-2.4em")
	    .attr("text-anchor", "middle")
	    .attr("fill", "black")
	    .attr("font-size", 20/200 * radius)
	    .attr("class", "clickHighlightText")
	    .text("Start: " + startBP + ", " + "End: " + endBP);
	
	
	var lengthHighlight = endBP - startBP;
	
	
	if (lengthHighlight < 0) {
	    lengthHighlight = lengthHighlight * -1;
	};
	
	if (startBP > endBP) {
	    lengthHighlight = (4000-startBP) + endBP;
	}
	
	clickHighlightTextG
	    .append("text")
	    .attr("x", 0)
	    .attr("dy", "-1.2em")
	    .attr("text-anchor", "middle")
	    .attr("fill", "black")
	    .attr("font-size", 20/200 * radius)
	    .attr("class", "clickHighlightText")
	    .text("Length: " + lengthHighlight);
	
	
	
    });
    
}


function spaceLabelsWithCollisionAvoidance(labels, side) {
    labels.sort((a, b) => a._y - b._y);
    //    const spacing = RELabelY > 0 ? 24/200 * radius : -24/200 * radius;
    const spacing =  24/200 * radius;
    let lastY = null;
    
    labels.forEach((site) => {
	const targetY = site._y;
	if (lastY === null) {
	    site.labelY = targetY;
	} else {
	    site.labelY = Math.max(targetY, lastY + spacing);
	}
	lastY = site.labelY;
	site.labelX = side === "right" ? (2 * radius) : (-2*radius);
    });
} 


   
function calculateAngle(x, y) {
    const dx = x - svgWidth / 2;
    const dy = y - svgHeight / 2;
    let angle = Math.atan2(-dy, -dx) - Math.PI / 2;
    if (angle < 0) angle += 2 * Math.PI;
    return angle;
}

function angleToBasePair(angle) {
    const arcLength = angle * radius;
    const circumference = 2 * Math.PI * radius;
    return Math.round((arcLength / circumference) * (vectorLength - 1)) + 1;
}


