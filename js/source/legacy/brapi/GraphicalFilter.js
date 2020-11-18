(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
  typeof define === 'function' && define.amd ? define(factory) :
  (global.GraphicalFilter = factory());
}(this, (function () { 'use strict';

function GraphicalFilter(brapi_node,trait_accessor,table_col_accessor,table_col_order,group_key_accessor){
  "use strict";
  
  //statics
  var gfilter = {};
  var colors = ["#ffffff","#b3e2cd","#f1e2cc","#fff2ae","#f4cae4","#e6f5c9","#cbd5e8","#fdcdac"];
  var color = d3.scaleOrdinal()
    .range(colors.map(d3.color));
  var filterID = (function(){
    var i = 0;
    return function(){return i++;};
  })();
  
  // parse data
  var tableCols = table_col_order.map(function(key){
        return {title:key,data:"meta."+key.replace(".","\\.")}
      }),
      allTraits = {},
      rangeTraits = [];
  var data_node = brapi_node.map(function(d){
    var traits = trait_accessor(d);
    for (var key in traits) {
      if (traits.hasOwnProperty(key)) {
        allTraits[key]=null;
      }
    }
    return {
      'traits':traits,
      'meta':table_col_accessor(d),
      'data':d
    };
  }).all(function(data){
    data.forEach(function(d){
      d.traits = Object.assign({},allTraits,d.traits);
    });
    for (var key in allTraits) {
      if (allTraits.hasOwnProperty(key)) {
        rangeTraits.push(key);
      }
    }
  });
  
  if (group_key_accessor!=undefined){
    tableCols.push({title:"Count",data:"count"});
    data_node = data_node.reduce().fork(function(all){
      var key_map = {};
      all.forEach(function(d){
        var key = group_key_accessor(d.data);
        if (key_map[key]){
          key_map[key].push(d);
        } else {
          key_map[key] = [d];
        }
      });
      var groups = [];
      for (var key in key_map) {
        if (key_map.hasOwnProperty(key)) {
          groups.push(key_map[key]);
        }
      }
      return groups;
    }).map(function(arr){
      var grouped = {
        "traits":{},
        "meta":Object.assign({}, arr[0].meta),
        data:arr,
        "count":arr.length
      };
      var trait_counts = {};
      arr.forEach(function(d){
        for (var key in d.traits) {
          if (d.traits.hasOwnProperty(key)) {
            if(grouped.traits[key]){
              grouped.traits[key]+= +d.traits[key];
              trait_counts[key]+=1;
            } else {
              grouped.traits[key] = +d.traits[key];
              trait_counts[key] = 1;
            }
          }
        }
      });
      for (var key in grouped.traits) {
        if (grouped.traits.hasOwnProperty(key)) {
          grouped.traits[key] = grouped.traits[key]/trait_counts[key];
        }
      }
      return grouped;
    });
  }
  
  data_node.all(function(data){
    for (var key in allTraits) {
      if (allTraits.hasOwnProperty(key)) {
        tableCols.push({title:key,data:"traits."+key.replace(".","\\.")});
      }
    }
  });
  
  /**  
   * gfilter.draw - creates a new graphical filter and table
   *    
   * @param  {string/selector} filter_selector selector of filter div   
   * @param  {string/selector} table_selector  selector of datatable div    
   */   
  gfilter.draw = function(filter_selector,table_selector){
    data_node.all(function(data){
      var canv = d3.select(filter_selector);
      canv.html("");
      
      //create the root filter group
      gfilter.root = new FilterGroup(null,0,"init");
      gfilter.rangeTraits = rangeTraits;
      
      //draw the filter
      gfilter.root.draw(canv.node());
      
      //create the output table
      gfilter.results_table = $(table_selector).DataTable({
        data: data,
        "columns": tableCols
      });
      
      gfilter.data = data;
      
      
      /**    
       * gfilter - Redraws everything      
       */     
      gfilter.redraw = function(){
        gfilter.root.updateData(gfilter.data);
        gfilter.root.draw();

        var currentFilter = gfilter.root.getFilter();
        $.fn.dataTableExt.afnFiltering.push(function( _1, _2, dataIndex ){
          return currentFilter(gfilter.data[dataIndex]);
        });
        gfilter.results_table.draw();
        $.fn.dataTableExt.afnFiltering.pop();
      };
      gfilter.redraw();
    });
  };
  
  /**  
   * Filter - constructor for the base Filter class
   *    
   * @param  {Filter} parent      
   * @param  {integer} depth       
   * @param  {string} operator    
   */   
  function Filter(parent,depth,operator){
    this.filterID = filterID();
    this.type = "default";
    this.parent = parent || null;
    this.depth = depth || 0;
    this.operator = operator || "init";
  }
  //static, representations for each possible operator
  Filter.operators = [{
      name:"and",
      "class":"filter-operator-and",
      next:1
    },{
      name:"and not",
      "class":"filter-operator-and filter-operator-not",
      next:2
    },{
      name:"or",
      "class":"filter-operator-or",
      next:3
    },{
      name:"or not",
      "class":"filter-operator-or filter-operator-not",
      next:0
    },{
      name:"init",
      "class":"filter-operator-init",
      next:5
    },{
      name:"init not",
      "class":"filter-operator-init filter-operator-not",
      next:4
  }];
  Filter.operator_map = d3.map(Filter.operators,function(d){return d.name});
  
  Filter.prototype.getFilter = function(){return null;};
  Filter.prototype.updateData = function(data){};
  
  /**  
   * Filter.prototype.draw - redraws componants shared by both filter groups and range filters (all filter types).
   *    
   * @param  {DOM node} node where to draw   
   */   
  Filter.prototype.draw = function(node){
    if (node) this.node = node;
    if (!this.node) return false;
    this.updateOperator();
    var negate = (this.operator.indexOf("not", this.operator.length - 3) != -1);
    var n = this;
    var negated_from_root = negate;
    while(n.parent){
      negated_from_root ^= (n.parent.operator.indexOf("not", n.parent.operator.length - 3) != -1);
      n = n.parent;
    }
    d3.select(this.node).classed("filter-negated",negated_from_root);
  };
  
  Filter.prototype.updateRemoveButton = function(){
    var f = d3.select(this.node);
    //because everything is nested, we want to only select things at the current depth
    var remove = f.select(".filter-wrapper,.filter-panel").selectAll(".filter-remove[depth = '"+(this.depth)+"']")
      .data(this.parent?[this]:[]);
    remove.exit().remove();
    remove.enter().append("div")
      .classed("filter-remove",true)
      .attr("depth",this.depth)
      .on("click",function(d){
        var chIndex = d.parent.children.indexOf(d);
        d.parent.children.splice(chIndex, 1);
        gfilter.redraw();
      });
  };
  
  Filter.prototype.updateOperator = function(){
    var f = d3.select(this.node);
    var operator = f.selectAll(".filter-operator[depth = '"+(this.depth)+"']")
      .data([this]);
    operator = operator.enter().append("div")
      .classed("filter-operator",true)
      .attr("depth",this.depth)
      .classed(Filter.operator_map.get(this.operator).class,true)
      .on("click",function(d){
        var preoperator = Filter.operator_map.get(d.operator);
        var newindex = preoperator.next;
        var newoperator = Filter.operators[newindex];
        d3.select(this)
          .classed(preoperator.class,false)
          .classed(newoperator.class,true);
        d.operator = newoperator.name;
        gfilter.redraw();
      })
      .merge(operator);
    if (this.parent && this.parent.children.indexOf(this)==0){
      operator.classed(Filter.operator_map.get(this.operator).class,true)
        .classed(Filter.operator_map.get("init").class,true);
      this.operator = Filter.operator_map.get("init").name;
    }
  };

  function FilterGroup(parent,depth,operator){
    //constructor
    Filter.call(this,parent,depth,operator);
    this.type = "filtergroup";
    this.children = [];
  }
  FilterGroup.prototype = Object.create(Filter.prototype);
  FilterGroup.prototype.constructor = FilterGroup;
  FilterGroup.prototype.getFilter = function(){
    var negate = (this.operator.indexOf("not", this.operator.length - 3) != -1);
    var conjointGs = this.getConjointGroups(true);
    return function(d){
      var result = false;
      var anyFiltered = false;
      for (var i = 0; i < conjointGs.length; i++) {
        var groupval = true;
        var filtered = false;
        //set groupval to false if any conjoint filter is false
        for (var j = 0; j < conjointGs[i].length; j++) {
          if (conjointGs[i][j]){
            filtered = true;
            if(!conjointGs[i][j](d)){
              groupval = false;
              break;
            }
          }
        }
        // OR-join the result of each conjoint group
        if (filtered) result = result || groupval;
        anyFiltered = anyFiltered || filtered;
      }
      if (anyFiltered) return negate ? !result : result;
      return true;
    }
  };
  FilterGroup.prototype.updateData = function(data){
    this.data = data;
    var childgroups = this.getConjointGroups();
    var filtergroups = this.getConjointGroups(true);
    for (var i = 0; i < childgroups.length; i++) {
      var group = childgroups[i];
      for (var j = 0; j < group.length; j++) {
        var childData = data;
        group[j].group = this.depth+i;
        for (var k = 0; k < group.length; k++) {
          if (k!=j && filtergroups[i][k]) {
            childData = childData.filter(filtergroups[i][k]);
          }
        }
        group[j].updateData(childData);
      }
    }
  };
  FilterGroup.prototype.draw = function(node){
    Filter.prototype.draw.call(this,node);
    var f = d3.select(this.node);
    var fg = f.selectAll(".filter-wrapper").data([this]);
    var fgenter = fg.enter().append("div")
      .classed("filter-wrapper",true);
    fgenter.append("span")
      .classed("filter-wrapper-children",true);

    var dropID = this.filterID+"dropdown";
    var newFilterMenu = fgenter.append("div")
      .classed("dropdown",true);
    newFilterMenu.append("button")
      .classed("btn btn-secondary dropdown-toggle",true)
      .attr("type","button")
      .attr("id",dropID)
      .attr("data-toggle","dropdown")
      .attr("aria-haspopup","true")
      .attr("aria-expanded","false");
    var newFilterMenuContents = newFilterMenu.append("ul")
      .classed("dropdown-menu",true)
      .attr("aria-labelledby",dropID);

    newFilterMenuContents.append("li").append("a").text("New Range")
      .attr("href","")
      .classed("dropdown-item",true)
      .on("click",function(d){
        d3.event.preventDefault();
        d3.event.stopPropagation();
        var op = d.children.length==0 ? "init" : "and";
        d.children.push(new FilterRange(d,d.depth+1,op));
        gfilter.redraw();
        return false;
      });
    newFilterMenuContents.append("li").append("a").text("New Group")
      .attr("href","")
      .classed("dropdown-item",true)
      .on("click",function(d){
        d3.event.preventDefault();
        d3.event.stopPropagation();
        var op = d.children.length==0 ? "init" : "and";
        d.children.push(new FilterGroup(d,d.depth+1,op));
        gfilter.redraw();
        return false;
      });

    //draw children
    fgenter.merge(fg)
      .style("background",function(d){
        var c = color(d.depth%color.range().length);
        c.opacity = 0.2;
        return c;
      })
      .select(".filter-wrapper-children")
      .each(function(d){
        var subfilters = d3.select(this)
          .selectAll("[depth = '"+(d.depth+1)+"'].filter-item")
          .data(d.children,function(d){return d.filterID;});
        subfilters.exit()
          .style("opacity",1)
          .transition()
          .style("opacity",0)
          .remove();
        subfilters.enter()
          .append("div")
          .classed("filter-item",true)
          .attr("depth",d.depth+1)
          .style("opacity",0)
          .transition()
          .style("opacity",1)
          .selection()
        .merge(subfilters)
          .each(function(d){
            d.draw(this);
          });
      });
    this.updateRemoveButton();
  };
  
  FilterGroup.prototype.getConjointGroups = function(returnFilters){
    // returns arrays of filters connected by ANDs or AND-NOTs
    var cjGroups = [[]];
    if (this.children[0]){
      if (returnFilters){
        cjGroups[cjGroups.length-1].push(this.children[0].getFilter());
      } else {
        cjGroups[cjGroups.length-1].push(this.children[0]);
      }
    }
    for (var i = 1; i < this.children.length; i++) {
      var op = this.children[i].operator;
      var disjunct = !op.lastIndexOf("or", 0);
      if (disjunct) cjGroups.push([]);
      if (returnFilters) {
        cjGroups[cjGroups.length-1].push(this.children[i].getFilter());
      } else {
        cjGroups[cjGroups.length-1].push(this.children[i]);
      }
    }
    return cjGroups;
  };

  function FilterRange(parent,depth,operator){
    //constructor
    Filter.call(this,parent,depth,operator);
    this.type = "filterrange";
    this.brushRange = [null,null];
    this.centerVal = 0;
    this.centerID = 0;
    this.b_width = this.width - (this.margin.left+this.margin.right);
    this.b_height = this.height - (this.margin.top+this.margin.bottom);
    this.filterTrait = null;
    this.valueAccessor = null;
    this.data = [];
  }
  
  FilterRange.prototype = Object.create(Filter.prototype);
  FilterRange.prototype.constructor = FilterRange;
  //FilterRange layout
  $.extend(FilterRange.prototype,{
    ttime:200,
    bin_count_range:[10,10],
    width:300,
    height:150,
    margin:{top:4,bottom:20,left:4,right:4}
  });

  FilterRange.prototype.getFilter = function(){
    if (this.brushRange[0]==null) return null;
    var hist = this;
    var negate = (this.operator.indexOf("not", this.operator.length - 3) != -1);
    // if (this.brushRange[0]==null) return function(){return !negate;};
    return function(d){
      var val = hist.valueAccessor(d);
      var res = val!=null?(val >= hist.brushRange[0] && val <= hist.brushRange[1]):false;
      return (negate? !res : res);
    };
  };
  FilterRange.prototype.updateData = function(data){
    this.data = data;
  };
  FilterRange.prototype.refreshSelect = function(){
    var select = d3.select(this.select);
    this.selectableTraits = ["Select a Trait..."].concat(gfilter.rangeTraits);
    var ops = select.selectAll("option").data(this.selectableTraits);
    ops.exit().remove();
    var opsE = ops.enter().append("option");
    opsE.filter(function(d,i){return !i;})
      .attr("selected",true);
    opsE.merge(ops)
      .text(function(d,i){return d;})
      .property("value",function(d,i){return d;})
      .filter(function(d,i){return !i;})
      .property("value",null)
      .attr("disabled",true);
  };
  FilterRange.prototype.draw = function(node){
    Filter.prototype.draw.call(this,node);
    var panel = d3.select(this.node).selectAll(".filter-panel")
      .data([this]);
    if (!panel.enter().empty()){
      var pe = panel.enter().append('div')
        .classed("filter-panel-range filter-panel panel panel-default",true);
      var heading = pe.append('div')
        .classed("panel-heading",true);
      var body = pe.append('div')
        .classed("panel-body",true);
      var select = heading.append("select")
        .classed("form-control",true)
        .on("change",function(){
          var fr = d3.select(this).datum();
          fr.filterTrait = $(this).val();
          fr.valueAccessor = function(d){
            return parseFloat(d.traits[fr.filterTrait]);
          };
          gfilter.redraw();
        });
      this.select = select.node();
      panel = pe.merge(panel);
      this.panel = panel.node();
    }
    this.refreshSelect();
    if (this.valueAccessor && this.filterTrait){
      var body = panel.select(".panel-body");
      var svg = body.selectAll("svg").data([this]);
      this.body = panel.select(".panel-body").node();
      if (!svg.enter().empty()){
        var svgE = svg.enter().append("svg");
        svgE.attr("width","100%")
          .attr("shape-rendering","geometricPrecision")
          .attr("viewBox","0 0 "+this.width+" "+this.height);
        svgE.append("rect")
          .classed("svg-bg",true)
          .attr("x",this.margin.left)
          .attr("y",this.margin.top)
          .attr("width",this.b_width)
          .attr("height",this.b_height)
          .attr("fill","none")
          .attr("stroke","#eee");
        this.x = d3.scaleLinear()
          .range([0, this.b_width-1]);
        this.y = d3.scaleLinear()
          .range([this.b_height, 11]);
        this.xAxis = d3.axisBottom(this.x);
        svgE.append("g")
          .attr("transform","translate("+this.margin.left+","+(this.height-this.margin.bottom)+")")
          .classed("x-axis",true);
        var plotgroup = svgE.append("g")
          .attr("transform","translate("+this.margin.left+","+this.margin.top+")");
        this.plotgroup = plotgroup.node();
        this.brushed = this.getBrushCallback();
        this.brush = d3.brushX()
          .extent([[this.margin.left,this.margin.top],[this.margin.left+this.b_width,this.margin.top+this.b_height]])
          .on("end",this.brushed)
          .on("brush",this.brushed);
        svgE.append("g")
          .classed("brush",true)
          .call(this.brush);
        this.svg = svgE.node();
      }
      this.drawHistogram();
    } else {
      panel.selectAll("svg").remove();
    }
    this.updateRemoveButton();
  };

  FilterRange.prototype.drawHistogram = function(){
    var frself = this;
    var visible_data = this.data.filter(function(d){
      var v = frself.valueAccessor(d);
      return v!=null && !isNaN(v);
    });
    console.log(visible_data);
    var negate = (this.operator.indexOf("not", this.operator.length - 3) != -1);
    var extent = d3.extent(visible_data, this.valueAccessor);
    if (visible_data.length<2) extent = [-1,1];
    this.x.domain(extent);
    var thresholds = [];
    var bin_count = d3.thresholdFreedmanDiaconis(visible_data.map(this.valueAccessor), extent[0], extent[1]);
    var bin_count = Math.min(Math.max(bin_count,this.bin_count_range[0]),this.bin_count_range[1]);
    for (var i = 0; i < bin_count+1; i++) {
      thresholds.push(extent[0]+((extent[1]-extent[0])*i/bin_count));
    }
    var bins = d3.histogram()
      .domain(this.x.domain())
      .thresholds(thresholds.slice(0,thresholds.length-1))
      .value(this.valueAccessor)(visible_data);
    this.y.domain([0, d3.max(bins, function(d) { return d.length; })]);

    //order bins to be ID'd by distance to the centerVal. (sorted by *signed* distance)
    var cvBisector = d3.bisector(function(bin){return d3.mean([bin.x0,bin.x1]);}).left;
    var splitI = cvBisector(bins,this.centerVal);
    var sortedBins = bins.slice(splitI).concat(bins.slice(0,splitI).reverse());

    //give the bins IDs based on position.
    var positiveID = parseInt(this.centerID);
    var negativeID = parseInt(this.centerID)-1;
    for (var i = 0; i < sortedBins.length; i++) {
      var bin = sortedBins[i];
      if (d3.mean([bin.x0,bin.x1])<this.centerVal){
        bin.keyID = negativeID;
        bin.enterleft = true;
        negativeID -= 1;
      } else {
        bin.keyID = positiveID;
        positiveID += 1;
      }
    }
    this.centerVal = sortedBins[0].x0;
    this.centerID = sortedBins[0].keyID;

    var hist = this;
    var bars = d3.select(this.plotgroup).selectAll(".bar")
      .data(sortedBins,function(d,i){
        return hist.name+" "+d.keyID;
      });
    var entered = bars.enter().append("g")
      .attr("class", "bar");
    var bar_height = this.b_height;
    entered.append("rect")
      .attr("fill","#c9c")
      .attr("y", function(d){return hist.y(d.length)})
      .attr("height", function(d) { return bar_height-hist.y(d.length); })
      .attr("width", 0)
      .attr("x", this.b_width)
      .filter(function(d){return d.keyID<hist.centerID})
      .attr("x", 0);
    entered.append("text")
      .attr("text-anchor","middle")
      .attr("font-size",8)
      .attr("fill","#999")
      .attr("opacity",0)
      .attr("y",function(d){return hist.y(d.length)-2})
      .text("")
      .attr("x", this.b_width)
      .filter(function(d){return d.keyID<hist.centerID})
      .attr("x", 0);
    var newBars = entered.merge(bars);
    newBars.select("rect")
      .transition().duration(this.ttime).ease(d3.easeLinear)
      .attr("y", function(d){return hist.y(d.length)})
      .attr("width", this.x(bins[0].x1) - this.x(bins[0].x0) - 1)
      .attr("height", function(d) { return bar_height-hist.y(d.length); })
      .attr("x", function(d){return hist.x(d.x0)+1});
    newBars.select("text")
      .transition().duration(this.ttime)
      .attr("opacity",1)
      .attr("x", function(d){return hist.x((d.x0+d.x1)/2)})
      .attr("y", function(d){return hist.y(d.length)-2})
      .text(function(d){return d.length>0?d.length:""});
    bars.exit().transition().duration(this.ttime).remove();
    bars.exit().select("rect")
      .transition().duration(this.ttime)
      .attr("width", 0)
      .attr("x", this.b_width)
      .filter(function(d){return d.keyID<hist.centerID})
      .attr("x", 0);
    bars.exit().select("text")
        .transition().duration(this.ttime)
        .attr("opacity",0)
        .attr("x", this.b_width)
        .filter(function(d){return d.keyID<hist.centerID})
        .attr("x", 0);

    var inputs = d3.select(this.body)
      .selectAll("input")
      .raise()
      .data([[0,this.brushRange,"from..."],[1,this.brushRange,"...to"]]);
    var rangeFormat = d3.format(".5s");
    inputs.enter()
      .append("input")
      .classed("form-control input-sm filter-range-form",true)
      // .attr("type","number")
      .attr("step","0.1")
      .attr("placeholder",function(d){
        return d[2];
      })
      .on("change",function(d){
        d[1][d[0]] = this.value;
        hist.brushed();
      })
    .merge(inputs)
      .each(function(d){
        this.value = d[1][d[0]]==null?null:rangeFormat(d[1][d[0]]);
      });
    var status = d3.select(this.body)
      .selectAll(".filter-status").raise().data([0]);
    status = status.enter().append("div")
      .classed("filter-status",true)
      .merge(status);
    var svg = d3.select(this.svg);
    svg.select(".brush-out-indicator").remove();
    if (hist.brushRange[0]!==null){
      var total = visible_data.length;
      var sFilter = this.getFilter();
      var filtered = visible_data.filter(function(d){
        return negate ? !sFilter(d) : sFilter(d);
      }).length;
      status.text(filtered+"/"+total);
      var transition = svg.select(".brush")
        .transition().duration(this.ttime);
      var bscale = this.x.copy()
        .range(this.x.range()
          .map(function(d){return d+hist.margin.left;}))
        .clamp(true);
      var brushExtent = this.brushRange.map(bscale);
      var bg = svg.select(".svg-bg");
      if (brushExtent[0]==brushExtent[1]){
        var bgx = parseFloat(bg.attr("x"));
        var bgy = parseFloat(bg.attr("y"));
        var bgw = parseFloat(bg.attr("width"));
        var bgh = parseFloat(bg.attr("height"));
        if (brushExtent[0]==bscale.range()[0]){
          svg.append("line").classed("brush-out-indicator",true)
            .attr("x1",bgx)
            .attr("y1",bgy)
            .attr("x2",bgx)
            .attr("y2",bgy+bgh);
          brushExtent[1]+=1;
        } else {
          svg.append("line").classed("brush-out-indicator",true)
            .attr("x1",bgx+bgw)
            .attr("y1",bgy)
            .attr("x2",bgx+bgw)
            .attr("y2",bgy+bgh);
          brushExtent[0]-=1;
        }
      }
      console.log(brushExtent);
      this.brush.move(transition,brushExtent);
    } else {
      status.text("Nothing");
    }

    var d = this.x.domain();
    var ticks = [d3.min(d),d3.mean(d),d3.max(d)];
    this.xAxis = d3.axisBottom(this.x)
      .tickValues(ticks)
      .tickFormat(d3.format("1.2"));
    d3.select(this.svg).select(".x-axis")
      .transition()
      .duration(this.ttime)
      .call(this.xAxis);
  };

  FilterRange.prototype.getBrushCallback = function(){
    var hist = this;
    return function(d,i){
      if (d3.event.sourceEvent){
        if (d3.event.type!="change" && !d3.event.selection){
          clearTimeout(hist.brush_timeout);
          hist.brushRange = [null,null];
          gfilter.redraw();
        } else {
          clearTimeout(hist.brush_timeout);
          var lastSelectedRange = d3.event.selection;
          hist.brush_timeout = setTimeout(function(){
            if(lastSelectedRange){
              hist.brushRange = lastSelectedRange
              .map(function(d){return d-hist.margin.left;})
              .map(hist.x.invert);
            }
            //if there arent enough items in the selection (2) expand the selection to include the nearest ones.
            if (hist.getFilter()&&hist.data.filter(hist.getFilter()).length<2){
              console.log("adjusted");
              var values = hist.data.map(hist.valueAccessor);
              values.sort(function(a,b){return a-b;});
              var midVal = d3.mean(hist.brushRange);
              var midI = d3.bisect(values.slice(1),midVal);
              hist.brushRange = [values[midI],values[midI+1]];
            }
            gfilter.redraw();
            clearTimeout(hist.brush_timeout);
          },d3.event.type=="end"?0:hist.ttime);
        }
      }
    }
  };
  return gfilter;
}

return GraphicalFilter;

})));
