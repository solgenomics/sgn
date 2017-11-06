
var barcode_types = [
    { name:"Code 128 (1D) Size 1", type: "128_1"},
    { name:"Code 128 (1D) Size 2", type: "128_2"},
    { name:"Code 128 (1D) Size 3", type: "128_3"},
    { name:"Code 128 (1D) Size 4", type: "128_4"},
    { name:"QR Code (2D) Size 4", type: "QR_4"},
    { name:"QR Code (2D) Size 5", type: "QR_5"},
    { name:"QR Code (2D) Size 6", type: "QR_6"},
    { name:"QR Code (2D) Size 7", type: "QR_7"},
    { name:"QR Code (2D) Size 8", type: "QR_8"},
    { name:"QR Code (2D) Size 9", type: "QR_9"},
    { name:"QR Code (2D) Size 10", type: "QR_10"}
];

var label_sizes = [
  // {name:'1" x 2 5/8"',width:189,height:72,value:30},
  // {name:'1" x 4"',width:288,height:72,value:20},
  // {name:'1 1/3" x 4"',width:288,height:96,value:14},
  {name:'1" x 2 5/8"',width:533.4,height:203.2,value:30},
  {name:'1" x 4"',width:812.8,height:203.2,value:20},
  {name:'1 1/3" x 4"',width:812.8,height:270.93,value:14},
  {name:'Custom',value:'Custom'}
];

var text_fields = [
    { value: "", name: "Custom" },
    { value: "{$Accession}", name: "Accession" },
    { value: "{$Plot_Name}", name: "Plot Name" },
    { value: "{$Plot_Number}", name: "Plot #" },
    { value: "{$Rep_Number}", name: "Rep #" },
    { value: "{$Row_Number}", name: "Row #" },
    { value: "{$Col_Number}", name: "Col #" },
    { value: "{$Trial_Name}", name: "Trial Name" },
    { value: "{$Year}", name: "Year" },
    { value: "{$Pedigree_String}", name: "Pedigree String" },
];

//set up drag behaviour
var drag_behaviour = d3.behavior.drag().on(
  "drag", function(){
    var o = d3.select(this)
      .call(doTransform,function(state,selection){
        state.translate[0]+=d3.event.dx;
        state.translate[1]+=d3.event.dy;
      });
});
function draggable(d,i){
  var bb = this.node().getBBox();
  this.attr({
      "s-x": bb.x,
      "s-y": bb.y
    })
    .call(doTransform,function(state,selection){
      state.translate = [-bb.x,-bb.y]
    })
    .call(drag_behaviour);
}

resizer_behaviour = d3.behavior.drag().on(
  "drag", function(d,i){
    var target = d;
    var bb = getTransGroupBounds(target.node())
    var mx = d3.event.x;
    var my = d3.event.y;
    if (d3.select("#d3-snapping-check").property("checked")){
      mx = Math.round(mx/doSnap.size)*doSnap.size
      my = Math.round(my/doSnap.size)*doSnap.size
    }
    var xexpand = (mx - bb.x)/bb.width
    var yexpand = (my - bb.y)/bb.height
    expand = Math.max(xexpand,yexpand)
    if (!isNaN(expand)){
      target.call(doTransform,function(state,selection){
          var expX = state.scale[0]*expand;
          var expY = state.scale[1]*expand;
          var mi = Math.min(expX*bb.width,expY*bb.height);
          if (mi<=3) {
            expX = state.scale[0];
            expY = state.scale[1];
          }
          state.scale[0] = expX;
          state.scale[1] = expY;
      });
    }
    var newbb = getTransGroupBounds(target.node())
    d3.select(this.parentNode).select(".selection-tool-outline")
      .attr({
        x:newbb.x,
        y:newbb.y,
        width:newbb.width,
        height:newbb.height,
      })
    d3.select(this.parentNode).select(".selection-tool-resizer")
      .attr({
        x:newbb.x+newbb.width-3,
        y:newbb.y+newbb.height-3,
      })
    d3.select(this.parentNode).select(".selection-tool-remover")
      .attr({
        x:newbb.x-3,
        y:newbb.y-3,
      })
});
function selectable(selection,resizeable){
  this.on("mousedown",function(){
    d3.select(".selection-tools").remove();
  })
  this.on("click", function(){
    var o = d3.select(".d3-draw-svg");
    var bb = getTransGroupBounds(this);
    var target = d3.select(this);
    var tools = o.append('g')
      .classed("selection-tools",true)
      .datum(target);
    tools.append("rect")
      .classed("selection-tool-outline",true)
      .attr({
        x:bb.x,
        y:bb.y,
        width:bb.width,
        height:bb.height,
        fill:"none",
        stroke: "black",
        "stroke-dasharray": ("3,3"),
        "stroke-width":"1"
      })
    tools.append("rect")
      .classed("selection-tool-remover",true)
      .attr({
        x:bb.x-4,
        y:bb.y-4,
        width:8,
        height:8,
        fill: "red",
        stroke: "none"
      })
      .on("click",function(){
        d3.event.stopPropagation();
        target.remove();
        clearSelection();
      })
    if (resizeable){
      tools.append("rect")
        .classed("selection-tool-resizer",true)
        .on("click",function(){d3.event.stopPropagation();})
        .attr({
          x:bb.x+bb.width-4,
          y:bb.y+bb.height-4,
          width:8,
          height:8,
          fill: "green",
          stroke: "none"
        }).call(resizer_behaviour);
    }
  })
}
function clearSelection(){
  d3.select(".selection-tools").remove();
}


function doTransform(selection,transformFunc){
  var state = d3.transform(selection.attr("transform"));
  transformFunc(state,selection);
  selection.attr("transform",state.toString());
}

function getTransGroupBounds(node){
  var bb = node.getBBox()
  var state = d3.transform(d3.select(node).attr("transform"));
  bb.x = bb.x*state.scale[0]
  bb.y = bb.y*state.scale[1]
  bb.width = bb.width*state.scale[0]
  bb.height = bb.height*state.scale[1]
  bb.x += state.translate[0]
  bb.y += state.translate[1]
  return bb
}

function changeLabelSize(width,height,scale) {
    d3.select(".label-template").attr("viewBox", "0 0 "+width+" "+height);
    var grid_size = d3.select("#d3-grid-number").node().value;
    updateGrid(scale.invert(grid_size));
}

function doSnap(state,selection){
  var bb = getTransGroupBounds(selection.node());
  var left_snap_d = (Math.round(bb.x/doSnap.size))*doSnap.size-bb.x
  var right_snap_d = (Math.round((bb.x+bb.width)/doSnap.size)*doSnap.size-bb.width)-bb.x
  var top_snap_d = (Math.round(bb.y/doSnap.size))*doSnap.size-bb.y
  var bottom_snap_d = (Math.round((bb.y+bb.height)/doSnap.size)*doSnap.size-bb.height)-bb.y
  state.translate[0] += Math.abs(left_snap_d) < Math.abs(right_snap_d) ? left_snap_d: right_snap_d
  state.translate[1] += Math.abs(top_snap_d) < Math.abs(bottom_snap_d) ? top_snap_d: bottom_snap_d
}
doSnap.size = 12;

$(document).ready(function($) {

  var width = 533.4; 
  var height = 203.2; 

  //scales to allow for conversion between "real" pts and SVG pts
  var _x = d3.scale.linear().domain([0,width]).range([0,width]);
  var _y = d3.scale.linear().domain([0,height]).range([0,height]);
  
  get_select_box('trials', 'trial_select_div', { 'name' : 'trial_select', 'id' : 'trial_select' });
  
  //create svg canvas
  var svg = d3.select(".d3-draw-area")
    .append('svg')
    .classed("label-template",true)
    .attr({
        id: "d3-label-area",
    //  width: "100%",
      viewBox: "0 0 "+width+" "+height
    }).classed("d3-draw-svg",true);

  //set up background
  svg.append('rect')
    .classed("d3-bg",true)
    .attr({
      x:0,
      y:0,
      width:width,
      height:height,
      fill:"#eee"
    })
    .on("click",clearSelection);
  
  //set up grid and grid slider/input
  var grid = svg.append("g").classed("d3-bg-grid",true);
  grid.append('g').classed("d3-bg-grid-vert",true);
  grid.append('g').classed("d3-bg-grid-horz",true);
  var grid_slider = d3.select("#d3-grid-slider");
  var grid_number = d3.select("#d3-grid-number");
  var grid_max = 0.5*(height<width ? height : width)
  var grid_range_attrs = {
    min: 2,
    max: Math.round(_x(grid_max)),
    step: 1
  }
  grid_slider.attr(grid_range_attrs);
  grid_number.attr(grid_range_attrs);
  grid_number.property("value",12);
  grid_slider.property("value",12);
  grid_slider.on("input",function(){
    grid_number.property("value",this.value)
    updateGrid(_x.invert(this.value));
  });
  grid_number.on("change",function(){
    var value = Math.max(grid_range_attrs.min,Math.min(grid_range_attrs.max,this.value));
    grid_slider.node().value=value;
    this.value = value;
    grid_number.property("value",this.value)
    updateGrid(_x.invert(this.value));
  });
  updateGrid(_x.invert(12));
  
  // add select so users can resize draw area accorinding to label size
  var label_size_select = d3.select("#d3-label-size-select");
  
  label_size_select.selectAll("option")
    .data(label_sizes)
    .enter().append("option")
    .text(function(d){return d.name})
    .attr("value",function(d,i){return i});
    
    label_size_select.on("input",function(){ //adjust label size, or if custom show width and height inputs
        var index = d3.select(this).node().value;
        var val =  label_sizes[index].value;
        //console.log("value is "+val);
        if (val == 'Custom') {
            document.getElementById("d3-label-custom-dimensions").style.display = "inline";
        } else {
            document.getElementById("d3-label-custom-dimensions").style.display = "none";
            var width = label_sizes[index].width;
            var height = label_sizes[index].height;
            changeLabelSize(width,height,_x);
        }
      });
    
      d3.select("#d3-apply-custom-label-size").on("click",function(){ //apply custom label size
          width = document.getElementById("d3-label-custom-width").value;
          width = width * 8; //2.835 // convert to pixels at 72 / inch
          height = document.getElementById("d3-label-custom-height").value;
          height = height * 8; //2.835 // convert to pixels at 72 / inch
          changeLabelSize(width,height,_x);
        });

  //set up text and barcode select
  var text_field_select = d3.select("#d3-text-field-input");
  text_field_select.selectAll("option")
    .data(text_fields)
    .enter().append("option")
    .text(function(d){return d.name})
    .attr("value",function(d){return d.value});
    
    var size_slider = d3.select("#d3-text-size-slider");
    var size_input= d3.select("#d3-text-size-input");
    var size_range = {
      min: 1,
      max: 72,
      step: 1
  };
    size_slider.attr(size_range);
    size_input.attr(size_range);
    size_slider.property("value",12);
    size_input.property("value",12);
    size_slider.on("input",function(){
      size_input.property("value",this.value)
    });
    size_input.on("change",function(){
      grid_slider.node().value = this.value;
    });
    
    var barcode_text_select = d3.select("#d3-barcode-text-input");
    barcode_text_select.selectAll("option")
      .data(text_fields)
      .enter().append("option")
      .text(function(d){return d.name})
      .attr("value",function(d){return d.value});
      
      var barcode_type_select = d3.select("#d3-barcode-type-input");
      barcode_type_select.selectAll("option")
        .data(barcode_types)
        .enter().append("option")
        .text(function(d){return d.name})
        .attr("type",function(d){return d.type})
        .attr("size",function(d){return d.size});

  //set up text options
  
  $('#d3-text-field-input').change(function(){
      console.log("Change noticed, text is "+$(this).find('option:selected').text());
    if ($(this).find('option:selected').text() == 'Custom') {
          $('#customTextModal').modal('show');
      }
});

$('#d3-custom-field-input').change(function(){
    console.log("Change noticed, text is "+$(this).find('option:selected').text());
    $('#d3-text-content').append($(this).find('option:selected').val());
});
  
  $("#d3-add-text").on("click",function() {
    var text_value = document.getElementById("d3-text-field-input").value;
    var text_select = document.getElementById("d3-text-field-input");//.getAttribute("value");
    var selected_text = text_select.options[text_select.selectedIndex];
    var text = selected_text.text;
    var font_select = document.getElementById("d3-text-font-input");
    var selected_font = font_select.options[font_select.selectedIndex];
    var fontName = selected_font.text;
    var style = selected_font.getAttribute("value");
    var fontSize = document.getElementById("d3-text-size-input").value;//.getAttribute("value");  
    console.log("Text add includes text: "+text+"\nfontName: "+fontName+"\nfontSize: "+fontSize);
    fontSize = _x.invert(fontSize);
    addText(text,text_value,style,fontName,fontSize);
});    
  
  $("#d3-add-barcode").on("click",function() {
    var barcode = document.getElementById("d3-barcode-text-input").value;
    var type_select = document.getElementById("d3-barcode-type-input");
    addBarcode(barcode, type_select.selectedIndex);
});   

  d3.select(".d3-add-custom-text")
    .style("margin-left","1em");
  d3.select("#d3-custom-text")
    .on("click",function(){
    var text_content = d3.select("#d3-text-content").text();
    //$("#d3-text-field-input").find('option:selected').text(text_content);
    $("#d3-text-field-input").find('option:selected').val(text_content);
    $("#d3-text-field-input").find('option:selected').text(text_content);
    // text_content.selectAll(".d3-text-placeholder").each(function(d,i){
    //   var th = d3.select(this)
    //   th.html("").text(th.attr("key"))
    //   
    // });
    // var text = text_content.text();
    // var fontSize = _x.invert(d3.select("#d3-font-size-input").node().value);
    // addText(text,fontSize)
});

function addText(text,text_value,style,fontName,fontSize){
  svg = d3.select(".d3-draw-svg");
  var newTB = svg.append("g")
    .classed("text-box",true);
  var newText = newTB
    .append("text")
    .attr({
      "font-size":fontSize,
      "style":style,
      "dominant-baseline": "mathematical",
      text:text,
      value:text_value,
      size:fontName+"_"+fontSize,
      class:"label-element",
    })
    .text(text);
  newTB.classed("draggable",true)
    .classed("selectable",true)
    .call(draggable)
    .call(selectable,false)
    .on("mouseup", dragSnap);
}

function addBarcode (barcode, index) {
    // console.log("type is "+type);
    svg = d3.select(".d3-draw-svg");
    // var width = document.getElementById("d3-label-area").viewBox.baseVal.width;
    // var height = document.getElementById("d3-label-area").viewBox.baseVal.height;
    var new_barcode = svg.append("g")
    .classed("barcode",true)
    .classed("draggable",true)
    .classed("selectable",true)
    .call(draggable)
    .call(selectable,true)
    .call(doTransform,function(state,selection){
      state.translate[0] += (width/2)-(100/2)
      state.translate[1] += (height/2)-(100/2)
    })
    .on("mouseup", dragSnap)
    .append("svg:image")
    .attr({
        x:0,
        y:0,
        // width:_x.invert(barcode_types[index].width),
        // height:_y.invert(barcode_types[index].height),
        class: "label-element",
        value: barcode,
        size: barcode_types[index].type
    })
    .attr("xlink:href","/barcode/preview?content="+encodeURIComponent(barcode)+"&type="+encodeURIComponent(barcode_types[index].type));
    new_barcode.call(doTransform,doSnap);
}

function dragSnap(){
  if (d3.select("#d3-snapping-check").property("checked")){
    d3.select(this).call(doTransform,doSnap);
  }
}

function updateGrid(size){
  //set snapping distance
  doSnap.size = size;
  //make x-lines
  var width = document.getElementById("d3-label-area").viewBox.baseVal.width;//.getBoundingClientRect().width();
  var height = document.getElementById("d3-label-area").viewBox.baseVal.height;//.getBoundingClientRect().height();
  //console.log("width is "+width+" and height is "+height);
  var x_lines = [];
  for (var x = size; x < width; x+=size) {
    x_lines.push(x);
  }
  var vert = d3.select(".d3-bg-grid-vert").selectAll("line")
    .data(x_lines);
  vert.exit().remove()
  vert.enter().append('line')
  vert.attr({
    y1: 0,
    y2: height,
    stroke: "rgba(0,0,0,0.2)",
    "stroke-width": 1
  })
  .attr("x1",function(d){return d})
  .attr("x2",function(d){return d})
  .on("click",clearSelection);
  //make y-lines
  var y_lines = [];
  for (var y = size; y < height; y+=size) {
    y_lines.push(y);
  }
  var horz = d3.select(".d3-bg-grid-horz").selectAll("line")
    .data(y_lines);
  horz.exit().remove()
  horz.enter().append('line')
  horz.attr({
    x1: 0,
    x2: width,
    stroke: "rgba(0,0,0,0.2)",
    "stroke-width": 1
  })
  .attr("y1",function(d){return d})
  .attr("y2",function(d){return d})
  .on("click",clearSelection);
}

$("#d3-save-button").on("click",function(event) {
  clearSelection();
  $(".label-template").clone().appendTo("#savingplace");
  var img = d3.select("#savingplace .label-template")
    .attr("id","d3-to-save")
  img.select(".d3-bg").remove();
  img.select(".d3-bg-grid").remove();
  var svg = document.getElementById("d3-to-save");

  //get svg source.
  var serializer = new XMLSerializer();
  var source = serializer.serializeToString(svg);
console.log("SVG is "+source);
  //add name spaces.
  if(!source.match(/^<svg[^>]+xmlns="http\:\/\/www\.w3\.org\/2000\/svg"/)){
      source = source.replace(/^<svg/, '<svg xmlns="http://www.w3.org/2000/svg"');
  }
  if(!source.match(/^<svg[^>]+"http\:\/\/www\.w3\.org\/1999\/xlink"/)){
      source = source.replace(/^<svg/, '<svg xmlns:xlink="http://www.w3.org/1999/xlink"');
  }

  //add xml declaration
  source = '<?xml version="1.0" standalone="no"?>\r\n' + source;
    
  //convert svg source to URI data scheme.
  var url = "data:image/svg+xml;charset=utf-8,"+encodeURIComponent(source);


  //set url value to a element's href attribute.
  document.getElementById("link").href = url;
  //you can download svg file by right click menu.
  img.remove();
});

function getLabelDetails(element, index) {
    
    //var transform = element.parentNode.getAttribute('transform');
    var transform_attributes = parseTransform(element.parentNode.getAttribute('transform'));
    console.log("Transform attributes are: "+JSON.stringify(transform_attributes));
    var coords = transform_attributes.translate;  //transform.split(')')[0].substring(10, transform.length).split(','); // extract x,y coords from translate(10,10)rotate(0)skewX(0)scale(1,1) format
    
    var scale = transform_attributes.scale || [1,1];
    console.log("Scale is "+scale);
    //also extract scale to multiply by width and height
    console.log("X is "+coords[0]+" and y is "+coords[1]);
    var format = element.getAttribute("size").split('_'); //get size and type from size attribute
    var rect = element.getBBox();//getBoundingClientRect(); // get the bounding rectangle
    var width = rect.width * scale[0]; //parseInt(scale[0]);
    var height = rect.height * scale[1]; //parseInt(scale[1]);
    console.log("Base width is "+rect.width+" and height is "+rect.height);
    console.log("Adjusted width is "+width+" and height is "+height);

    return { 
        x: coords[0], 
        y: coords[1],
        height: height, 
        width: width,
        value: element.getAttribute("value"),
        type: format[0],
        size: format[1],
    };
}

function parseTransform (transform) {
    var attribute_object = {};
    var attributes = transform.split(')');
    for (var i = 0; i < attributes.length; i++) {
        console.log ("Attribute is "+attributes[i]);
        var attribute = attributes[i];
        var parts = attribute.split('(');
        var name = parts.shift();
        console.log ("Name is "+name+" and parts are "+parts+" and type of parts is "+typeof parts);
        var values = parts.join(',');
        attribute_object[name] = values.split(',');
    }                                                            
    return attribute_object;
}

$("#d3-pdf-button").on("click",function(event) {
    console.log("You clicked the download pdf button.");

    var label_elements = document.getElementsByClassName('label-element');
    label_elements = Array.prototype.slice.call(label_elements); // convert to array
    var element_objects = label_elements.map(getLabelDetails);
    var label_json = JSON.stringify(element_objects);

    //Get additional Params
    var trial_id = document.getElementById("trial_select").value;
    var num_labels = document.getElementById("num_labels").value;

    //send to server to build pdf file
    jQuery.ajax( {
        url: '/barcode/download/pdf',
        timeout: 60000,
        method: 'POST',
        data: {'trial_id': trial_id, 'num_labels': num_labels, 'label_json': label_json},
        success: function(response) {
            if (response.error) {
            } else {
                window.location.href = "/download/"+response.filename;
            }
        },
        error: function(request, status, err) {
        
        }
    });
});    
 });
