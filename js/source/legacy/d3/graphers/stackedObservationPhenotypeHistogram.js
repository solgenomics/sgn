(function(exports){

  //check for d3 and check to use d3v4
  var d3 = typeof d3v4 !== 'undefined'? d3v4 : d3;
  if (typeof d3 === 'undefined'){
    throw "d3 not imported";
  }

  /**
  * Draws a Histogram from a phenotype matrix of observations containing a single trait.
  * @param {Array} data - a 2D array containing a single-trait phenotype matrix where data[0] is the header row and all following rows are plot/plant matrix rows stored as a list.
  * @param {HTMLElement|Node|String} loc - an target for where the histogram should be drawn ie: `"#trait_histogram"` or `d3.select(".hist_div").node()`
  * @param {Object} [layout={...}] - (OPTIONAL) an object containing the layout information for this histogram. Default: {"width":700,"height":300,"margin":{"top":24,"left":36,"bottom":36,"right":24}}
  *   @param {Number} width
  *   @param {Number} height
  *   @param {Object} margin
  *     @param {Number} top
  *     @param {Number} left - Set a strict left margin (>0)
  *     @param {Number} left_per_digit - If !left, expand left margin by this amount per y-axis digit
  *     @param {Number} left_base - If !left, minimum left margin.
  *     @param {Number} bottom
  *     @param {Number} right
  */
  exports.draw = function(data,loc,layout){
    var layout = layout || {
      "width":700,
      "height":300,
      "margin":{
        "top":24,
        "left_per_digit":12,
        "left_base":12,
        "bottom":36,
        "right":24
      }
    }
    var histLoc = d3.select(loc);
    var header = data[0];

    // var traitName = header[header.length-(header[header.length-1]!="notes"?1:2)];

    // Find the index of the "notes" column
    var notesIndex = header.indexOf("notes");

    if (notesIndex !== -1 && notesIndex > 0) {
      // Get the column before "notes"
      var traitName = header[notesIndex - 1];
    } else {
      // Handle the case where "notes" is the first column or not found
      var traitName = null; // You can use a default value or handle this case as needed
    }


    // The `traitName` variable contains the column before "notes" or null if "notes" is the first column or not found
    console.log(traitName);


    var observations = data.slice(1).map(function(d){
      var o = {};
      header.forEach(function(h,i){
        o[h==traitName?"value":h] = h==traitName?parseFloat(d[i]):d[i];
      });
      return o;
    }).filter(function(o){
      return (!!o.value || o.value === 0 || o.value === -0.0) && (!isNaN(o.value));
    });
    if (observations.length<3){
      histLoc.html("<center><h4>This trait is not numeric, or there are fewer than 3 values. Unable to draw a histogram.</h4></center>");
      return;
    } else {
      histLoc.selectAll(function(s){return this.children;})
        .filter("*:not(.histogram)").remove();
    }
    var allValues = observations.map(function(d){
      return d.value;
    });

    if (allValues.every( (val, i, arr) => val === arr[0] )){
      histLoc.html("<center><h4>All values are the same ("+allValues[0]+") for this trait. Unable to draw a histogram.</h4></center>");
      return;
    }

    var accessions = {};
    var emptyBlocks = {};
    observations.forEach(function(observation){
      accessions[observation.germplasmDbId] = observation.germplasmName;
      emptyBlocks[observation.germplasmDbId] = 0;
    })

    var extent = d3.extent(allValues);
    var x = d3.scaleLinear()
      .domain(extent)
      .nice(11);
    var boundaries = x.ticks(11);
    var xaxis = d3.axisBottom(x).tickValues(boundaries);
    var binner = d3.histogram()
      .domain(x.domain())
      .thresholds(boundaries.slice(0,boundaries.length-1))
      .value(function(d){
        return d.value;
      });

    var bins = binner(observations).map(function(bin){
      var blocks = accNest
        .rollup(function(v){return v.length})
        .object(bin);
      var empty = Object.assign({"bin":bin},emptyBlocks);
      return Object.assign(empty,blocks);
    });

    var ymax = d3.max(bins,function(d){
      return d.bin.length;
    });

    var y_digits = Math.log(ymax) * Math.LOG10E + 1 | 0;
    layout.margin.left = layout.margin.left || layout.margin["left_base"]+layout.margin["left_per_digit"]*y_digits;
    x.range([layout.margin.left,layout.width-layout.margin.right]);

    var y = d3.scaleLinear()
      .domain([0,ymax])
      .range([layout.height-layout.margin.bottom, layout.margin.top]);
    var yaxis = d3.axisLeft(y).ticks(ymax<6?ymax:6);

    var stacker = d3.stack()
      .keys(Object.keys(accessions))
      .order(function(series){
        var sort1 = series.map(function(s,i){
          var count = 0;
          var totVal = 0;
          s.forEach(function(b,i){
            count += b[1]-b[0];
            totVal += (i+1)*(b[1]-b[0]);
          });
          s.sortVal = totVal/count;
          return [s.sortVal,i];
        });
        sort1.sort(function(a,b){
          return d3.ascending(a[0],b[0]);
        })
        return sort1.map(function(d){return d[1];});
      })
      .offset(d3.stackOffsetNone);

    var series = stacker(bins);
    series.forEach(function(s){
      s.forEach(function(b,i){
        b.key = s.key;
      });
    });
    series.sort(function(a,b){
      return d3.ascending(a.sortVal,b.sortVal);
    });

    var color = d3.scaleSequential(d3.interpolateViridis)
      .domain([0,series.length]);

    histLoc.style("overflow-x","auto");
    var hist = histLoc.selectAll(".histogram").data([series]);
    newHist = hist.enter()
      .append("svg")
      .classed("histogram",true)
      .style("width",layout.width+"px")
      .style("min-width",layout.width)
      .style("margin","auto")
      .attr("viewBox","-10 0 "+layout.width+" "+(layout.height+30))
      .style("background","#fff");
    newHist.append("g").classed("series-groups",true);
    newHist.append("g").classed("xaxis",true);
    newHist.append("g").classed("yaxis",true);
    hist = hist.merge(newHist);

    hist.select(".xaxis")
      .attr('transform', 'translate(0,' + (layout.height-layout.margin.bottom) + ')')
      .call(xaxis)
      .attr("font-size",16);
    hist.select(".yaxis")
      .attr('transform', 'translate(' + layout.margin.left + ',0)')
      .call(yaxis)
      .attr("font-size",16);

    hist.select("#ylabel").remove();
    hist.select("#xlabel").remove();
    hist.append("text")
      .attr("id","xlabel")
      .attr("transform", "translate(" + (layout.width/2) + "," + (layout.height + layout.margin.top - 7 ) + ")")
      .style("text-anchor", "middle")
      .text(traitName);

    hist.append("text")
      .attr("id","ylabel")
      .attr("transform", "rotate(-90)")
      .attr("y", -10)
      .attr("x",0 - (layout.height / 2))
      .attr("dy", "1em")
      .style("text-anchor", "middle")
      .text("Frequency (Count)");


    var groups = hist.select(".series-groups").selectAll(".series")
      .data(function(d){return d;},function(d){return d.key;});
    groups.exit().remove();
    var newGroups = groups.enter().append("g").classed("series",true);
    var allGroups = newGroups.merge(groups).style("fill",function(d,i){
        return color(i);
      }).on("mouseover",function(d,i){
        var c = d3.rgb(color(i));
        d3.select(this).raise()
          .style("fill",c.brighter(2));
      }).on("mouseout",function(d,i){
        var c = d3.rgb(color(i));
        d3.select(this)
          .style("fill",c);
      });

    var bits = allGroups.selectAll(".bit").data(function(d){return d;});
    bits.exit().remove()
    var newBits = bits.enter().append("rect").classed("bit",true);
    var allBits = newBits.merge(bits)
      .attr("x",function(d){return x(d.data.bin.x0)+1})
      .attr("width",function(d){return x(d.data.bin.x1)-x(d.data.bin.x0)-1})
      .attr("y",function(d){return y(d[1])})
      .attr("height",function(d){return y(d[0])-y(d[1])})
      .on("mouseover",function(d){
        drawToolTip(hist,x,y,accessions,d);
      })
      .on("mouseout",function(d){
        drawToolTip(hist,x,y,accessions);
      });
  }

  var accNest = d3.nest().key(function(d){
    return d.germplasmDbId;
  }).rollup(function(observations){
    return observations.map(function(d){
      return d.value;
    });
  });

  function drawToolTip(field,x,y,accessions,d){
    var tt = field.selectAll(".ttip").data(d?[d]:[]);
    var newtt = tt.enter().append("g").classed("ttip",true);
    newtt.append("rect").attr("fill","black");
    newtt.append("text").attr("fill","white")
      .attr("text-anchor","middle")
      .attr("y","-4");
    tt.exit().remove();
    var alltt = newtt.merge(tt);
    alltt.attr('transform', function(d){
      return 'translate(' + ((x(d.data.bin.x1)+x(d.data.bin.x0))/2) + ',' + y(d[1]) + ')'
    });
    alltt.select("text").text(function(d){
      return accessions[d.key];
    }).each(function(d){
      d.ttbbox = this.getBBox();
    });
    alltt.select("rect").attr("width",function(d){
        return d.ttbbox.width+4;
      })
      .attr("height",function(d){
        return d.ttbbox.height+2;
      })
      .attr("y",function(d){
        return -(d.ttbbox.height+2);
      })
      .attr("x",function(d){
        return -d.ttbbox.width/2-2;
      })
  }

}(typeof exports === 'undefined' ? this.stackedObservationPhenotypeHistogram = {} : exports));
