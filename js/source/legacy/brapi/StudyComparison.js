(function (global, factory) {
	typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
	typeof define === 'function' && define.amd ? define(factory) :
	(global.StudyComparison = factory());
}(this, (function () { 'use strict';

// creates a new comparison object
function main(){
        
        var scomp = {};
        // size options and things
        var opts = {
            'size':570,
            'axes':30,
            'margins':10,
            'trait':""
        };
        
        var link_maker = null;
        
        var rsquare_format = d3.format(".3f");
        
        function accessionAccessor(a){
            return d3.mean(a.variables[opts.trait])
        }
        
        var observationUnit_data = [];
        var hist_data = [];
        var grid_data = [];
        
        // sets the variable to be used for the histogram and comparison grid
        scomp.setVariable = function(variable){
            opts.trait = variable;
            return scomp;
        };
        
        scomp.links = function(link_m){
            link_maker = link_m;
            return scomp;
        };
        
        // sets an option
        scomp.setOpt = function(opt,val){
            opts[opt] = val;
        };
        
        // gets an option
        scomp.getOpt = function(opt){
            return opts[opt];
        };
        
        // loads and parses an array of observationUnits to be displayed in the comparison
        // returns a list of compareable (shared) traits.
        scomp.loadData = function(observationUnits){
            console.log("loads",observationUnits);
            observationUnit_data = observationUnits.slice(0);
            
            var nester = d3.nest().key(function(unit){
                return unit.studyDbId;
            }).key(function(unit){
                return unit.germplasmDbId;
            });
            
            var studyVariables = {};
            var nested = nester.entries(observationUnits);
            nested.forEach(function(study){
                study.accessions = {};
                var thisStudyVariables = {};
                study.values.forEach(function(accession){
                    study.accessions[accession.key] = accession;
                    accession.variables = {};
                    accession.values.forEach(function(unit){
                        unit.observations.forEach(function(obs){
                            if (accession.variables[obs.observationVariableName]==undefined) {
                                accession.variables[obs.observationVariableName] = [];
                                thisStudyVariables[obs.observationVariableName] = true;
                            }
                            accession.variables[obs.observationVariableName].push(obs.value);
                        });
                    });
                });
                d3.keys(thisStudyVariables).forEach(function(k){
                    studyVariables[k] = studyVariables[k]?studyVariables[k]+1:1;
                });
                delete study.values;
            });
            
            var sharedVars = d3.keys(studyVariables).filter(function(k){
                return studyVariables[k]==nested.length;
            });
            
            var paired_grid = [];
            for (var row = 0; row < nested.length-1; row++) {
                paired_grid.push([]);
                for (var col = 1; col < nested.length; col++) {
                    if (row<col){
                        paired_grid[row].push([nested[row],nested[col]]);
                    }
                    else {
                        paired_grid[row].push(null);
                    }
                    
                }
            }
            
            hist_data = nested;
            grid_data = paired_grid;
            return sharedVars;
        };
        
        // draws a histogram.
        scomp.multiHist = function(selector){
            // set up svg canvas and create layers
            var prev = d3.select(selector)
                .selectAll(".mulhst-svg")
                .data([hist_data]);
            prev.exit().remove();
            var newSvg = prev.enter()
                .append("svg")
                .classed("mulhst-svg",true)
                .attr("width",opts.size+opts.axes)
                .attr("height",opts.size+opts.axes)
                .attr("viewBox","0 0 "+(opts.size+opts.axes)+" "+(opts.size+opts.axes));
            newSvg.append("g")
                .classed("mulhst-main",true)
                .attr("transform","translate(0,"+opts.axes+")");
            newSvg.append("g").classed("mulhst-xaxis",true)
                .attr("transform","translate(0,"+(opts.size)+")");            newSvg.append("g")
                .classed("mulhst-yaxis",true)
                .attr("transform","translate("+opts.axes+","+opts.axes+")");
            var lgnd = newSvg.append("g")
                .classed("mulhst-legend",true);
            lgnd.append("rect").classed("mulhst-legend-bg",true)
                .attr("fill","white").attr("fill-opacity",0.65)
                .attr("stroke","black")
                .attr("x",-opts.margins).attr("y",-opts.margins);
            lgnd.append("g").classed("mulhst-legend-main",true);
            var builtSvg = newSvg.merge(prev);
            var main = builtSvg.select(".mulhst-main");
            scomp.mhist = builtSvg.node();
            var xaxis = builtSvg.select(".mulhst-xaxis");
            var yaxis = builtSvg.select(".mulhst-yaxis");
            var legend = builtSvg.select(".mulhst-legend");
            
            
            // filter and bin accessions
            var allaccessions = hist_data.reduce(function(a,d){return a.concat(d3.values(d.accessions))},[]);
            var total_extent = d3.extent(allaccessions,accessionAccessor);
            var bin_guess = 15;
            var x = d3.scaleLinear().domain(total_extent).range([opts.axes,(opts.size-opts.margins)]).nice(bin_guess);
            var histogram = d3.histogram().domain(x.domain()).thresholds(x.ticks(bin_guess)).value(accessionAccessor);
            
            // create bins for each study at each position
            var bins = [];
            var kernels = [];
            var study_ids = [];
            hist_data.forEach(function(study){
                var studyAccessions = d3.values(study.accessions);
                var studyBins = histogram(studyAccessions)
                    .filter(function(bin){return bin.length!=0;});
                studyBins.forEach(function(bin){
                    bin.study = study;
                });
                study_ids.push(study.key);
                bins.push.apply(bins, studyBins);
            });
            
            // set up colors and the y-axis
            var color = d3.scaleOrdinal(d3.schemeCategory10).domain(study_ids);
            var y = d3.scaleLinear().domain([0,d3.max(bins,function(bin){return bin.length})])
                .range([(opts.size-opts.axes),opts.margins]);
            
            // Perform kernel estimations. Values are normalized to prevent the 
            // order of magnitude from affecting the smoothing degree.    
            var kernelNormY = y.copy();
            kernelNormY.range([0,100]);
            var kernelNormX = x.copy();
            kernelNormX.range([0,100]);
            hist_data.forEach(function(study){
                var studyAccessions = d3.values(study.accessions);
                console.log("a",x.ticks(bin_guess).map(kernelNormX));
                console.log("b",studyAccessions.map(accessionAccessor).map(kernelNormX));
                kernels.push({
                    'study':study,
                    'path':kernelDensityEstimator(kernelEpanechnikov(10), x.ticks(bin_guess).map(kernelNormX))
                        (studyAccessions.map(accessionAccessor).map(kernelNormX)).map(function(d){
                            return [d[0],d[1]*1000]
                        })
                });
            });
            
            // draw axes
            var xax = d3.axisBottom(x);
            xaxis.call(xax);
            var yax = d3.axisLeft(y);
            yaxis.call(yax);
        
            // draw bars and lower
            var bars = main.selectAll(".mulhst-bar").data(bins);
            bars.exit().remove();
            var newBars = bars.enter().append("g").classed("mulhst-bar",true);
            newBars.append("rect").attr("opacity",0.5);
            var allBars = newBars.merge(bars).order();
            allBars.select("rect")
                .attr("x",function(d){
                    return x(d.x0)+1
                })
                .attr("y",function(d){
                    return y(d.length)
                })
                .attr("width",function(d){
                    return x(d.x1) - x(d.x0)-1
                })
                .attr("height",function(d){
                    return y(0)-y(d.length)
                })
                .attr("fill",function(d){
                    return color(d.study.key);
                })
                .lower();
            
            // kernel line function
            var kernelCurve = d3.line().curve(d3.curveBasis)
                .x(function(d){return x(kernelNormX.invert(d[0]));})
                .y(function(d){return y(kernelNormY.invert(d[1]));});
            
            // draw kernel estimation backgrounds (white border)
            var lineBGs = main.selectAll(".mulhst-kernel-bg").data(kernels);
            lineBGs.exit().remove();
            var newLines = lineBGs.enter().append("path").classed("mulhst-kernel-bg",true);
            var allLines = newLines.merge(lineBGs)
                .attr("d",function(d){
                    console.log(d.path);
                    return kernelCurve(d.path);
                })
                .attr("stroke","white")
                .attr("fill","none")
                .attr("stroke-width",4)
                .attr("stroke-opacity",0.75)
                .raise();
                
            // draw kernel estimation curves
            var lines = main.selectAll(".mulhst-kernel").data(kernels);
            lines.exit().remove();
            var newLines = lines.enter().append("path").classed("mulhst-kernel",true);
            var allLines = newLines.merge(lines)
                .attr("d",function(d){
                    console.log(d.path);
                    return kernelCurve(d.path);
                })
                .attr("stroke",function(d){
                    return color(d.study.key);
                })
                .attr("fill","none")
                .attr("stroke-width",2)
                .attr("stroke-opacity",0.8)
                .raise();
            
            // draw legend items
            var legents = legend.select(".mulhst-legend-main").selectAll(".mulhst-legend-entry").data(hist_data);
            legents.exit().remove();
            var newLegents = legents.enter().append("g").classed("mulhst-legend-entry",true);
            newLegents.append("circle")
                .attr("fill-opacity",0.6)
                .attr("stroke-width",2)
                .attr("cx",8).attr("cy",8).attr("r",8);
            newLegents.append("text").attr("font-size",12).attr("x",22).attr("y",13);
            var allLegents = newLegents.merge(legents);
            allLegents.attr("transform",function(d,i){
                    return d3.zoomIdentity.translate(0,22*i);
                })
                .on("click",scomp.multiHist.toggle);
            allLegents.select("circle").attr("fill",function(d){
                return color(d.key);
            })
            .attr("stroke",function(d){
                return color(d.key);
            });
            allLegents.select("text").text(function(d){
                return d3.values(d.accessions)[0].values[0].studyName
            });
            
            // transform legend into upper-right corner
            var bbox = legend.select(".mulhst-legend-main").node().getBBox();
            var bgwidth = bbox.width+opts.margins*2;
            var bgheight = bbox.height+opts.margins*2;
            legend.select(".mulhst-legend-bg")
                .attr("width",bgwidth)
                .attr("height",bbox.height+opts.margins*2);
            legend.attr("transform","translate("+(opts.size-bgwidth)+","+(opts.margins*2+opts.axes)+")");
        };
        
        // set the histogram to show specfic studies
        scomp.multiHist.showStudies = function(studies){
            if(!scomp.mhist)return; // this function affects the histogram, if it doesnt exist, exit
            
            var fadet = d3.transition();
            d3.select(scomp.mhist).selectAll(".mulhst-bar")
                .transition(fadet)
                .style("opacity",function(d){
                    return studies.indexOf(d.study)!=-1?null:0;
                });
            d3.select(scomp.mhist).selectAll(".mulhst-bar,.mulhst-kernel,.mulhst-kernel-bg")
                .transition(fadet)
                .style("opacity",function(d){
                    return studies.indexOf(d.study)!=-1?null:0;
                });
            d3.select(scomp.mhist).selectAll(".mulhst-legend-entry")
                .attr("isNotShown",function(d){
                    return studies.indexOf(d)!=-1?null:true;
                })
                .select("circle")
                .transition(fadet)
                .style("fill-opacity",function(d){
                    return studies.indexOf(d)!=-1?null:0;
                });
        };
        
        // toggle the visibility of a study (this is a click event on the legend item)
        scomp.multiHist.toggle = function(toggleTo){
            if(!scomp.mhist)return; // this function affects the histogram, if it doesnt exist, exit
            
            // resets attributes to match selected.
            d3.select(scomp.mhist).selectAll(".mulhst-legend-entry")
                .attr("isDeselected",function(){
                    var curr = d3.select(this).attr("isNotShown");
                    return curr?true:null;
                });
                
            var entry = d3.select(this); 
            if (!(toggleTo===true||toggleTo===false)){
                toggleTo = !entry.attr("isDeselected");
            }
            entry.attr("isDeselected",function(){
                return toggleTo?true:null;
            });
            scomp.multiHist.showSelected();
        };
        
        // resets the histogram to what the user manually selected (via clicking)
        scomp.multiHist.showSelected = function(){
            if(!scomp.mhist)return; // this function affects the histogram, if it doesnt exist, exit
            
            var selected = d3.select(scomp.mhist).selectAll(".mulhst-legend-entry")
                .filter(function(){
                    return !d3.select(this).attr("isDeselected");
                })
                .nodes().map(function(node){
                    return d3.select(node).datum()
                });
            scomp.multiHist.showStudies(selected);
            return scomp;
        };
        
        // draws the comparison grid
        scomp.graphGrid = function(selector){
            
            // set up svg canvas
            var prev = d3.select(selector)
                .selectAll(".grapgr-svg")
                .data([grid_data]);
            prev.exit().remove();
            var newSvg = prev.enter()
                .append("svg")
                .classed("grapgr-svg",true)
                .attr("width",opts.size+opts.axes)
                .attr("height",opts.size+opts.axes)
                .attr("viewBox","0 0 "+(opts.size+opts.axes)+" "+(opts.size+opts.axes));
            newSvg.append("g")
                .attr("transform","translate("+opts.axes+","+opts.axes+")")
                .append("g")
                .classed("grapgr-main",true);
            newSvg.append("g")
                .classed("grapgr-topaxis",true)
                .attr("transform","translate("+(opts.axes+opts.margins)+","+(opts.axes+opts.margins)+")");
            newSvg.append("g")
                .classed("grapgr-leftaxis",true)
                .attr("transform","translate("+(opts.axes+opts.margins)+","+(opts.axes+opts.margins)+")");
            var builtSvg = newSvg.merge(prev);
            var main = builtSvg.select(".grapgr-main")
                .attr("transform","translate(0, 0) scale(1,1)");
            scomp.ggrid = main;
            var taxis = builtSvg.select(".grapgr-topaxis");
            var laxis = builtSvg.select(".grapgr-leftaxis");
            
            var tooltip = newSvg.append("a")
                .classed("grapgr-tooltip",true)
                .attr('opacity',0)
                .attr('transform', 'translate(' + 0 + ',' + -100 + ')')
                .attr("target","_blank");
            tooltip.append('rect')
                .attr('x',-2).attr('y',-15)
                .attr('width',100)
                .attr('height',16)
                .attr('fill','black');
            tooltip.append('text')
                .attr('fill','white')
                .attr('text-decoration','underline')
                .attr('y',-3)
                .attr('x',1)
                .attr('font-size','12');
            tooltip = tooltip.merge(d3.select('.grapgr-tooltip'));
            var tooltip_timeout = false;
            var tooltip_hold = false;
            function set_tooltip(viz,x,y,text,link){
                if (tooltip_hold) return;
                console.log(viz,x,y,text);
                var tt = d3.select('.grapgr-tooltip');
                var ttrect = tt.select('rect');
                var tttext = tt.select('text');
                if (!viz){
                    if (!tooltip_timeout) tooltip_timeout = setTimeout(function(){
                        tooltip_timeout = false;
                        if (tooltip_hold) return;
                        tt.attr('opacity',0);
                        tt.attr('transform', 'translate(' + 0 + ',' + -100 + ')');
                    },200);
                    return
                }
                clearTimeout(tooltip_timeout);
                tooltip_timeout = false;
                if (tt.attr('opacity')==1 && text!==undefined && tttext.text()==text) return;
                tt.attr('opacity',1);
                tt.attr('transform', 'translate(' + x + ',' + y + ')');
                tttext.text(text);
                ttrect.attr('width',tttext.node().getComputedTextLength()+6);
                if(link){
                    tt.attr('href',link).style('cursor','pointer');
                } else {
                    tt.attr('href',null).on('click',function(){return false;}).style('cursor','auto');
                }
            }
            tooltip.on('mousemove',function(){
                tooltip_hold=true;
            });
            tooltip.on('mouseout',function(){
                tooltip_hold=false;
                set_tooltip(false);
            });
                    
            // calculate grid size
            var cellSize = (opts.size-(opts.margins*(grid_data.length+1)))/grid_data.length;
            var cellOffset = (opts.size-opts.margins)/grid_data.length;
            
            // make rows
            var rows = main.selectAll(".grapgr-row").data(function(d){return d;});
            var newRows = rows.enter().append("g").classed("grapgr-row",true);
            rows.exit().remove();
            var allRows = newRows.merge(rows)
                .attr("ryp",function(d,i){return i;})
                .attr("transform",function(d,i){
                    var y = opts.margins+cellOffset*i;
                    var x = opts.margins;
                    return "translate("+x+","+y+")";
                });
                
            // add cells to rows
            var cells = allRows.selectAll(".grapgr-cell").data(function(d){return d;});
            var newCells = cells.enter().append("g").classed("grapgr-cell",true);
            newCells.append("rect").classed("grapgr-cell-bg",true)
                .attr("fill","white")
                .attr("width",opts.size)
                .attr("height",opts.size)
                .attr("stroke","black");
            newCells.append("g").classed("grapgr-graph-points",true);
            newCells.append("g").classed("grapgr-graph-xaxis",true)
                .attr('transform', 'translate(0,'+(opts.size-opts.axes)+')');
            newCells.append("g").classed("grapgr-graph-yaxis",true)
                .attr('transform', 'translate('+(opts.axes)+',0)');
            cells.exit().remove();
            var allCells = newCells.merge(cells)
                .attr("opacity",1)
                .attr("cxp",function(d,i){return i;})
                .attr("cyp",function(d,i){return d3.select(this.parentNode).attr("ryp");})
                .attr("transform",function(d,i){
                    var x = cellOffset*i;
                    var y = 0;
                    var s = cellSize/opts.size;
                    return "translate("+x+","+y+") scale("+s+")";
                });
            
            // sort null and drawable cells
            var nullCells = allCells.filter(function(d){return d==null;});
            var drawCells = allCells.filter(function(d){return d!=null;});
                
            // draw graphs
            drawCells.each(function(d,i){
                var xStudy = d[0];
                var yStudy = d[1];
                var accessions = {};
                
                // find accessions which are measured in both studies
                d3.entries(xStudy.accessions).forEach(function(kv){
                    accessions[kv.key] = {'xObs':kv.value};
                    accessions[kv.key].xVals = kv.value.variables[opts.trait];
                    if (accessions[kv.key].xVals){
                        accessions[kv.key].xAvg = d3.mean(accessions[kv.key].xVals);
                    }
                });
                d3.entries(yStudy.accessions).forEach(function(kv){
                    if (accessions[kv.key]){
                        accessions[kv.key].yObs = kv.value;
                        accessions[kv.key].yVals = kv.value.variables[opts.trait];
                        if (accessions[kv.key].yVals){
                            accessions[kv.key].yAvg = d3.mean(accessions[kv.key].yVals);
                        }
                    }
                });
                var accessions = d3.values(accessions).filter(function(a){
                    return a.xVals&&a.yVals&&a.xAvg!=undefined&&a.yAvg!=undefined;
                });
                
                // set the cell to null if there are no matching accessions.
                if (accessions.length<2){
                    d3.select(this).datum(null);
                    return
                }
                
                // find the x/y extents and the total extent, create scales
                var xtent = d3.extent(accessions,function(d){return d.xAvg});
                var ytent = d3.extent(accessions,function(d){return d.yAvg});
                var ttent = d3.extent(xtent.concat(ytent));
                var x = d3.scaleLinear().domain(ttent).range([opts.axes,(opts.size-opts.margins)]);
                var y = d3.scaleLinear().domain(ttent).range([opts.size-opts.axes,opts.margins]);
                
                // draw cell axes
                var xaxF = d3.axisBottom(x);
                var xaxis = d3.select(this).select(".grapgr-graph-xaxis").call(xaxF);
                var yaxF = d3.axisLeft(y);
                var yaxis = d3.select(this).select(".grapgr-graph-yaxis").call(yaxF);
                
                // draw data points
                var pointLayer = d3.select(this).select(".grapgr-graph-points");
                var points = pointLayer.selectAll(".grapgr-graph-point").data(accessions);
                var newPoints = points.enter().append("circle")
                    .classed("grapgr-graph-point",true)
                    .attr("fill","red")
                    .attr("stroke","red")
                    .attr("stroke-width",4)
                    .attr("stroke-opacity",0.1)
                    .attr("r",3);
                points.exit().remove();
                var allPoints = newPoints.merge(points)
                    .attr("cx",function(d){
                        return x(d.xAvg);
                    })
                    .attr("cy",function(d){
                        return y(d.yAvg);
                    });
                
                allPoints.on('mouseover',function(d){
                    var newLoc = d3.mouse(d3.select('.grapgr-tooltip').node().parentNode);
                    var name = d.xObs.values[0].germplasmName;
                    var link = link_maker?link_maker(d.xObs.values[0].germplasmDbId):undefined;
                    set_tooltip(true,newLoc[0],newLoc[1],name,link);
                }).on('mouseout',function(){
                    set_tooltip(false);
                });
                    
                // draw trendline
                var regression = leastSquares(
                    accessions.map(function(d){return d.xAvg}),
                    accessions.map(function(d){return d.yAvg}));
                var line = d3.line()
                    .x(function(d){return x(d[0]);})
                    .y(function(d){return y(d[1]);});
                var pathd = [];
                var yentint = regression.slope*ttent[0]+regression.yintercept;
                var xentint = (ttent[0]-regression.yintercept)/regression.slope;
                
                if ((yentint < xentint && regression.slope>0) || (yentint > xentint && regression.slope<0) ){
                    pathd.push([xentint,ttent[0]]);
                } 
                else {
                    pathd.push([ttent[0],yentint]);
                }
                var youtint = regression.slope*ttent[1]+regression.yintercept;
                var xoutint = (ttent[1]-regression.yintercept)/regression.slope;
                if ((xoutint < youtint && regression.slope>0) || (xoutint > youtint && regression.slope<0) ){
                    pathd.push([xoutint,ttent[1]]);
                } 
                else {
                    pathd.push([ttent[1],youtint]);
                }
                var tline = d3.select(this).selectAll(".grapgr-graph-tline").data([pathd]);
                tline.exit().remove();
                tline.enter().append("path")
                    .classed("grapgr-graph-tline",true).merge(tline)
                    .attr("stroke","blue")
                    .attr("d",function(d){return line(d)});
                
                var rsquare = d3.select(this).selectAll(".grapgr-graph-rsquare").data([regression.rSquare]);
                rsquare.exit().remove();
                rsquare.enter().append("text")
                    .classed("grapgr-graph-rsquare",true).merge(rsquare)
                    .attr("stroke","none")
                    .attr("fill","blue")
                    .attr("transform","translate("+(opts.axes+14)+","+(opts.margins+14)+")")
                    .text(function(d){return "r\u00B2 = "+rsquare_format(d)});
            });
            
            // sort null and drawable cells again, accounting for missmatched studies
            nullCells = allCells.filter(function(d){return d==null;});
            drawCells = allCells.filter(function(d){return d!=null;});
            
            // color placeholder and recolor former placeholders
            nullCells.selectAll(".grapgr-cell>* *, .grapgr-graph-tline, .grapgr-graph-rsquare").remove();
            nullCells.on("click",null)
                .select(".grapgr-cell-bg")
                .attr("fill","#f8f8f8")
                .attr("stroke","#ddd");
            drawCells.select(".grapgr-cell-bg")
                .attr("fill","white")
                .attr("stroke","black");
            
            // makes comparison axes
            var topLabels = grid_data[0].map(function(d){
                return d3.values(d[1].accessions)[0].values[0].studyName
            });
            var topLabelPos = grid_data[0].map(function(d,i){
                return cellOffset*i + cellSize/2;
            });
            var topScale = d3.scaleOrdinal()
                .domain(topLabels)
                .range(topLabelPos);
            var topaxis = d3.axisTop(topScale);
            taxis.selectAll("*").remove();
            taxis.call(topaxis).attr("font-size",12);
            taxis.select(".domain").style("opacity",0);
            taxis.selectAll(".tick>line").style("opacity",0);
            taxis.selectAll(".tick>line").style("opacity",0);
            var leftLabels = grid_data.map(function(d){
                return d3.values(d[d.length-1][0].accessions)[0].values[0].studyName
            });
            var leftLabelPos = grid_data.map(function(d,i){
                return cellOffset*i + cellSize/2;
            });
            var leftScale = d3.scaleOrdinal()
                .domain(leftLabels)
                .range(leftLabelPos);
            var leftaxis = d3.axisLeft(leftScale);
            laxis.selectAll("*").remove();
            laxis.call(leftaxis).attr("font-size",12);
            laxis.select(".domain").style("opacity",0);
            laxis.selectAll(".tick>line").style("opacity",0);
            laxis.selectAll(".tick>text")
                .attr("text-anchor","middle")
                .attr("transform","rotate(-90) translate(9,-12)");
            
            // if we have a grid larger than 1x1, enable zooming/selecting!
            if(grid_data.length>1){
                drawCells.on("click",cellZoomIn);
            }
            
            // zooms in on a cell and selects the relevant histogram series
            function cellZoomIn(d){
                var self=this;
                drawCells.on("click",null);
                var k = (opts.size-2*opts.margins)/cellSize;
                var margin_offset = opts.margins - opts.margins/k;
                var xPos = d3.select(this).attr("cxp")*cellOffset + margin_offset;
                var yPos = d3.select(this).attr("cyp")*cellOffset + margin_offset;
                main.transition()
                    .on("end",function(){
                        drawCells.on("click",cellZoomOut);
                    })
                    .attr("transform",d3.zoomIdentity.scale(k).translate(-xPos,-yPos))
                    .selectAll(".grapgr-cell")
                    .filter(function(d){return self!=this;})
                    .attr("opacity",0);
                topScale.range(topLabelPos.map(function(v){return (v-xPos+margin_offset)*k}));
                taxis.transition().call(topaxis);
                leftScale.range(leftLabelPos.map(function(v){return (v-yPos+margin_offset)*k}));
                laxis.transition().call(leftaxis);
                scomp.multiHist.showStudies(d);
            }
            
            // zooms out, resets histogram
            function cellZoomOut(d){
                drawCells.on("click",null);
                main.transition()
                    .on("end",function(){
                        drawCells.on("click",cellZoomIn);
                    })
                    .attr("transform",d3.zoomIdentity)
                    .selectAll(".grapgr-cell")
                    .attr("opacity",1);
                topScale.range(topLabelPos);
                taxis.transition().call(topaxis);
                leftScale.range(leftLabelPos);
                laxis.transition().call(leftaxis);
                scomp.multiHist.showSelected();
            }
            return scomp;
        };
        
        return scomp;
    }

    // regression (http://bl.ocks.org/benvandyke/8459843)
    function leastSquares(xSeries, ySeries) {
        var reduceSumFunc = function(prev, cur) { return prev + cur; };
        
        var xBar = xSeries.reduce(reduceSumFunc) * 1.0 / xSeries.length;
        var yBar = ySeries.reduce(reduceSumFunc) * 1.0 / ySeries.length;

        var ssXX = xSeries.map(function(d) { return Math.pow(d - xBar, 2); })
            .reduce(reduceSumFunc);
        
        var ssYY = ySeries.map(function(d) { return Math.pow(d - yBar, 2); })
            .reduce(reduceSumFunc);
            
        var ssXY = xSeries.map(function(d, i) { return (d - xBar) * (ySeries[i] - yBar); })
            .reduce(reduceSumFunc);
        
        var slope = ssXY / ssXX;
        var yintercept = yBar - (xBar * slope);
        var xintercept = (-yintercept)/slope;
        var rSquare = Math.pow(ssXY, 2) / (ssXX * ssYY);
        
        return {'slope':slope, 'yintercept':yintercept, 'xintercept':xintercept, 'rSquare':rSquare};
    }

    // kernel estimation (https://bl.ocks.org/mbostock/4341954)
    function kernelDensityEstimator(kernel, X) {
        return function(V) {
            return X.map(function(x) {
                return [x, d3.mean(V, function(v) { return kernel(x - v); })];
            });
        };
    }
    function kernelEpanechnikov(k) {
        return function(v) {
            return Math.abs(v /= k) <= 1 ? 0.75 * (1 - v * v) / k : 0;
        };
    }

return main;

})));
