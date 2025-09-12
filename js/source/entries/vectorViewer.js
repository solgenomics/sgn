import "../legacy/jquery.js";
import "../legacy/jqueryui.js";
import "../legacy/d3/d3v4Min.js";


var vector_metadata;
var vectorLength;
var sequence;
var table_data;
var table_data_RESites;
var svgWidth, svgHeight;
var margin, width, height, radius;
var svg;
var data;
var re_sites;

export function init() {
    alert('INIT VECTORVIEWER ??');


    
    vector_metadata = [
	{ vector_length_bp : 4000, vector_name : 'pBR322',}
    ];
    
    vectorLength = vector_metadata[0].vector_length_bp; // in bp

    alert('checkpoint x. VectorLenght = '+ vectorLength);
    
    data = [
	{ "name" : "Gene2", "color" : "yellow", "startAngle" : 1200/vectorLength * Math.PI *2, "endAngle" : 1600/vectorLength * Math.PI *2 },
	{ "name" : "an extremely long name for Gene3", "color" : "yellow", "startAngle" : 2000/vectorLength * Math.PI *2, "endAngle" : 3000/vectorLength * Math.PI *2 },
	{ "name" : "Gene1", "color": "yellow", "startAngle" : 3400/vectorLength * Math.PI *2, "endAngle" : 3800/vectorLength * Math.PI *2 },
	{ "name" : "Gene3", "color" : "yellow", "startAngle" : 100/vectorLength * Math.PI *2, "endAngle" : 800/vectorLength * Math.PI *2 }
    ];

    alert("checkpoint y");

    sequence = "";
    
    table_data = [
	[ 'Gene1', 3700, 400, 'yellow', 'R' ],
	[ 'Gene2', 1500, 2200, 'red', 'F' ],
	[ 'Gene3', 2400, 3000, 'lightblue', 'R' ],
	[ 'Gene4', 3200, 3500, 'lightgreen', 'F' ]
    ];

    alert("checkpoint z");
    
    table_data_RESites = [
	['EcoRI', 1504],
	['BamHI', 1804],
	['Test', 1425],
	['Test1', 2750],
	['Test2', 312],
	['Test3', 3812],
	['Test4', 2934],
	['Test5', 1247],
	['Test6', 937],
	['Test7', 564],
	['Test8', 2987],
	['Test9', 3243],
	['Test10', 2100]
    ];
    
    alert('checkpoint 1');
    
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

    alert('cp 2');
    
    //attaching the function to a button
    d3.select('#update_vector').on("click", function() { updateVector(data,table_data_RESites) });
    
    alert('cp 2.1');
    //zoom in and zoom out buttons
//    $(document).ready(function () {
	$('#zoomIn').on('click', function() {
	    radius *= 1.2;
	    svgWidth *= 1.2;
	    svgHeight *= 1.2;  
	    updateVector(data, table_data_RESites);  
	});
	$('#zoomOut').on('click', function() {
	    radius /= 1.2;
	    svgWidth /= 1.2;
	    svgHeight /= 1.2;  
	    updateVector(data, table_data_RESites);  
	});
    //});
    
    var columnDefs = [{
	title: "Feature Name",
	type: "text"
    }, {
	title: "Start Coord",
	type: "text"
    }, {
	title: "End Coord"
	//no type = text
    }, {
	title: "Color",
	type: "text"
    }, {
	title: "Orientation",
	type: "text"
    }];
    
    alert('cp3');
    var myTable = $('#vector_table').DataTable({
	"sPaginationType": "full_numbers",
	data: table_data,
	columns: columnDefs,
	dom: 'Bfrtip',        // Needs button container
	select: 'single',
	responsive: true,
	altEditor: true,     // Enable altEditor
	buttons: [
            {
		text: 'Add',
		name: 'add'        // do not change name
            },
            {
		extend: 'selected', // Bind to Selected row
		text: 'Edit',
		name: 'edit'        // do not change name
            },
            {
		extend: 'selected', // Bind to Selected row
		text: 'Delete',
		name: 'delete'      // do not change name
            }
	]
    });											
    
    
    
    
    
    //RE sites table
    var columnDefs2 = [{
	title: "Restriction Enzyme Site",
	type: "text"
    }, {
	title: "Cut Coord",
	type: "text"
    }];
    
    alert('cp4');
    
    var myTable2 = $("#vector_table2").DataTable({
	"sPaginationType": "full_numbers",
	data: table_data_RESites,
	columns: columnDefs2,
	dom: 'Bfrtip',        // Needs button container
	select: 'single',
	responsive: true,
	altEditor: true,     // Enable altEditor
	buttons: [
            {
		text: 'Add',
		name: 'add'        // do not change name
            },
            {
		extend: 'selected', // Bind to Selected row
		text: 'Edit',
		name: 'edit'        // do not change name
            },
            {
		extend: 'selected', // Bind to Selected row
		text: 'Delete',
		name: 'delete'      // do not change name
            }
	]
    });	
    
    
    re_sites = [
	{name: "EcoRI", cutCoord: 1504},
	{name: "BamHI", cutCoord: 1804}
    ];
    
    
    //If this isn't here, the dialog appears when we dont want it to
    jQuery("#saveDialog").dialog({
	autoOpen: false
    });
    
    //when someone clicks save the dialog is opened
    jQuery("#saveVector").click(function () {
	$('#saveDialog').dialog('open');
    });
    
    
    //Making data that can be stored
    jQuery("#dialogSaveButton").click(function () {
	var id = jQuery("#saveInput").val();
	var data = { 
	    'vector_metadata' : vector_metadata, 
	    'features' : table_data,
	    'restriction_enzymes' : table_data_RESites,
	    'sequence' : sequence
	};
	
	alert(id);
	alert(JSON.stringify(data));
	
	//This is the link where the data should be stored
	jQuery.ajax({
	    url: '/vectorviewer/' + id + '/store',
	    'data': data,
	    'method' : "POST"
	});
	
    });
    
    //If this isn't here, the dialog appears when we dont want it to
    jQuery("#loadDialog").dialog({
	autoOpen: false
    });
    
    
    //when someone clicks load the dialog is opened
    jQuery("#loadVector").click(function () {
	$('#loadDialog').dialog('open');
    });
    
    jQuery("#dialogLoadButton").click(function () {
	alert('HELLO!');
	
	var id = jQuery("#loadInput").val();
	
	alert(id);
	
	jQuery.ajax({
	    url: '/vectorviewer/' + id + '/retrieve',
	}).then(function(r) { data = r; }, function(r) { alert('A very severe error occurred! '+JSON.stringify(r)); } );
	
    });
    
}


// drawing / updating the vector as a function
export function updateVector(data, re_sites) {
    
    d3.selectAll("svg").selectAll("*").remove();
    data = [];
    re_sites = [];
    
    
    //Doing a function that happens for each table_data index
    for (var i = 0; i < table_data.length; i++) {
	
	//setting up the orientation
	var orientation = '>';
	if (
	    table_data[i][2] / vectorLength * Math.PI * 2 > Math.PI / 2 &&
		table_data[i][1] / vectorLength * Math.PI * 2 < Math.PI * 1.5
	) {
	    orientation = (table_data[i][4] === 'R') ? ">" : "<";
	} else {
	    if (table_data[i][4] === 'R') orientation = '<';
	}
	
	//defining a variable that is used to draw vectors that wrap around 0 -- if they do, you need to add 2 pi to the end angle otherwise it draws the arc the wrong direction
	var wrapAround = 0
	
	if (table_data[i][1] > table_data[i][2]) {
	    var wrapAround = 2 * Math.PI;
	}
	
	
	//Convert the data from table_data into a useable form inside the "data" dataset
	data.push({
	    name: table_data[i][0],
	    startAngle: table_data[i][1] / vectorLength * Math.PI * 2,
	    endAngle: table_data[i][2] / vectorLength * Math.PI * 2 + wrapAround,
	    color: table_data[i][3]
	});
	
	
	
	d3.select("svg")
	    .attr("width", svgWidth)
	    .attr("height", svgHeight);
	
    }
    
    //Anoter for each loop, this time for the RE sites
    for (var i = 0; i < table_data_RESites.length; i++) {
	var name = table_data_RESites[i][0];
	var cutCoord = table_data_RESites[i][1];
	
	//Convert the data from table_data_RESites into a useable form inside the "re_sites" dataset
	re_sites.push({
	    name: name,
	    cutCoord: cutCoord
	});
    };
    
    //Calling the function with all the parameters
    draw_vector("vector_div", vector_metadata, data, radius, re_sites, table_data, svgWidth, svgHeight);
}



export function draw_vector(vector_div, vector_metadata, data, radius, re_sites, table_data, svgWidth, svgHeight) { 

  const centerTranslationWidth = svgWidth/2;
  const centerTranslationHeight = svgHeight/2;

    alert('width and height = '+ svgWidth + ' ' + svgHeight);
//d3.select("body").selectAll("svg").selectAll("*").remove();

var vectorLengthLabelG = d3.select("body").select("svg").append("g").attr("class", "labelLengthGroup").attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")");
const vectorLengthLabel = vectorLengthLabelG.append("path")
  .attr("id", "lengthLabel")
  .attr("stroke", "black")
  .attr("stroke-width", 2)
  .attr("fill", "none")
  .style("display", "none");


  const pBR322VectorLength = vector_metadata[0].vector_length_bp; // Ths will need to be different

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
//  if (d.startAngle > d.endAngle) {
//vectorGeneBlockG.append("path")
//      .datum({ startAngle: d.startAngle, endAngle: d.endAngle + 2 * Math.PI})
//      .attr("d", geneArc)
//      .attr("stroke", "gray")
//      .attr("stroke-width", 4)
//      .attr("class", "featureClass")
//      .attr("id", "featureClass_" + i)
//      .attr("fill", d.color);
//
//  } else if (d.startAngle < d.endAngle) {
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
  .style("font-size", 0.15 * radius)
  .append("textPath")
  .attr("text-anchor", "middle")
  .attr("startOffset", "50%")
  .attr("xlink:href", "#labelClass_" + i)
  .text(d.name ?? `unnamed_gene_${i + 1}`);

  console.log(`Label for gene ${i}:`, d.name);

  });


data.forEach(function(d,i) {
// Label the Beginning of each gene

  var directionLabelOffset = (50 / pBR322VectorLength) * 2 * Math.PI;
  var directionLabelFlip = 0;
  var directionLabelStartAngle = d.endAngle + 1.5 * Math.PI;

  if (table_data[i][4] === 'R') {
    directionLabelStartAngle = d.endAngle + 1.5 * Math.PI;
    directionLabelFlip = 0;
    directionLabelOffset = (50 / pBR322VectorLength) * 2 * Math.PI;
  } else {
    directionLabelStartAngle = d.startAngle + 1.5 * Math.PI;
    directionLabelFlip = 0;
    directionLabelOffset = -(50 / pBR322VectorLength) * 2 * Math.PI;

  }

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
  var directionLabelOffsetEnd = (50 / pBR322VectorLength) * 2 * Math.PI;
  var directionLabelFlipEnd = 0;
  var directionLabelStartAngleEnd = d.endAngle + 1.5 * Math.PI;

  if (table_data[i][4] === 'R') {
    directionLabelStartAngleEnd = d.startAngle + 1.5 * Math.PI;
    directionLabelFlipEnd = (50 / pBR322VectorLength) * 2 * Math.PI;
    directionLabelOffsetEnd = 0;
  } else {
    directionLabelStartAngleEnd = d.endAngle + 1.5 * Math.PI;
    directionLabelFlipEnd = -(50 / pBR322VectorLength) * 2 * Math.PI;
    directionLabelOffsetEnd = 0;

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
  var vectorNameElement = vectorLabelG.selectAll("text")
      .data(vector_metadata)
      .enter()
      .append("text")
      .attr("class", "labelVectorClass")
      .attr("text-anchor", "middle")
      .attr("x", 0)
      .attr("y", 0)
      vectorNameElement.each(function(d){
          d3.select(this)
              .append("tspan")
              .attr("class", "vectorName")
              .attr("x", 0)
              .attr("dy", "0em")
              .attr("font-size", 0.1 * radius)
              .text("Name: " + d.vector_name);

          d3.select(this)
                  .append("tspan")
                  .attr("class", "vectorLength") 
                  .attr("x", 0)
                  .attr("dy", "1.2em")
                  .attr("font-size", 0.1 * radius)
                  .text("Length (bp): " + d.vector_length_bp);
      });

//// Paths for labeling RE sites

const vectorRadius = radius
const lengthPastVector = .75 * radius
const leftLabels = [];
const rightLabels = [];

var vectorLabelREGroup = d3.select("body")
   .select("#"+vector_div)
   .select("svg")
   .append("g")
   .attr("class", "vectorLabelRE").attr("transform", "translate(" + centerTranslationWidth + "," + centerTranslationHeight + ")")
//   .lower();
  
   re_sites.forEach(function(site, i) {
    const RELabelRads = (((site.cutCoord + 0.75 * pBR322VectorLength) % pBR322VectorLength) / pBR322VectorLength) * 2 * Math.PI;
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

  const valueLength = Math.round((arcLengthDisplay / circumference) * (pBR322VectorLength - 1)) + 1;

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


  labelLengthLabelX3 = labelLengthLabelX2 + labelLengthOffset;


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
  return Math.round((arcLength / circumference) * (pBR322VectorLength - 1)) + 1;
}

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

  console.log(`Selected region: BP ${startBP} to BP ${endBP}`);


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
