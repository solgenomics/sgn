


var solGS = solGS || function solGS(){};

solGS.scatterPlot = {

    plotRegression: function (regData) {
  

    var xData      = regData.x_data;
    var yData = regData.y_data;
    var yLabel            = regData.y_label || 'Y values';
    var xLabel            = regData.x_label || 'X values';
    var heritability        = regData.heritability;
    var phenotypeValues     = regData.phenotype_values;
    var regPlotDivId = regData.gebv_pheno_regression_div_id;
    var canvas = regData.canvas;
    var downloadLinks = regData.download_links;

    if (!canvas.match(/#/)) {canvas = '#' + canvas;}
    if (!regPlotDivId.match(/#/)) {regPlotDivId = '#' + regPlotDivId;}

    var xyData      = [];
    var scatterData = [];

    xValues = [];
    yValues = [];
    xData.map( function (xd) {
      
        var sD = [];
        var lD = []; 
        jQuery.each(yData, function(i, yd) {

            if ( xd[0] === yd[0] ) {

                sD.push({'name' : yd[0], 'y_val' : yd[1], 'x_val': xd[1]} );

                var ptY = parseFloat(yd[1]);
                var ptX = parseFloat(xd[1]);
                xValues.push(ptX);
                yValues.push(ptY);

                lD.push(ptX, ptY);

                return false;
            }
            
        });
        xyData.push(lD);
        scatterData.push(sD);       
    });
     
    var height = 300;
    var width  = 500;
    var pad    = {left:20, top:20, right:20, bottom: 40}; 
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;

    var svg = d3.select(regPlotDivId)
        .append("svg")
        .attr("width", totalW)
        .attr("height", totalH);

    var regPlot = svg.append("g")
        .attr("id", regPlotDivId)
        .attr("transform", "translate(" + (pad.left - 5) + "," + (pad.top - 5) + ")");
   

    var phenoMin = d3.min(xValues);
    var phenoMax = d3.max(yValues); 

    console.log('x values: ', xValues);
    console.log('y values: ', yValues);
    var xLimits = d3.max([Math.abs(d3.min(xValues)), d3.max(xValues)]);
    var yLimits = d3.max([Math.abs(d3.min(yValues)), d3.max(yValues)]);

    var xAxisScale = d3.scaleLinear()
        .domain([0, xLimits])
        .range([0, width/2]);
    
    var xAxisLabel = d3.scaleLinear()
        .domain([(-1 * xLimits), xLimits])
        .range([0, width]);

    var yAxisScale = d3.scaleLinear()
        .domain([0, yLimits])
        .range([0, (height/2)]);

    var xAxis = d3.axisBottom(xAxisLabel)
        .tickSize(3);
          
    var yAxisLabel = d3.scaleLinear()
        .domain([(-1 * yLimits), yLimits])
        .range([height, 0]);
    
   var yAxis = d3.axisLeft(yAxisLabel)
        .tickSize(3);

    var xAxisMid = 0.5 * (totalH); 
    var yAxisMid = 0.5 * (totalW);

 
    regPlot.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(" + pad.left + "," + xAxisMid +")")
        .call(xAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", 10)
        .attr("dy", ".1em")         
        .attr("transform", "rotate(90)")
        .attr("fill", "green")
        .style({"text-anchor":"start", "fill": "#86B404"});
       
    regPlot.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(" + yAxisMid +  "," + pad.top  + ")")
        .call(yAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("fill", "green")
        .style("fill", "#86B404");

    regPlot.append("g")
        .attr("id", "x_axis_label")
        .append("text")
        .text(xLabel)
        .attr("y", (pad.top + (height/2)) + 50)
        .attr("x", (width - 110))
        .attr("font-size", 10)
        .style("fill", "#86B404")

    regPlot.append("g")
        .attr("id", "y_axis_label")
        .append("text")
        .text(yLabel)
        .attr("y", (pad.top -  10))
        .attr("x", ((width/2) - 80))
        .attr("font-size", 10)
        .style("fill", "#86B404")

    regPlot.append("g")
        .selectAll("circle")
        .data(scatterData)
        .enter()
        .append("circle")
        .attr("fill", "#9A2EFE")
        .attr("r", 3)
        .attr("cx", function(d) {
            var xVal = d[0].x_val;
           
            if (xVal >= 0) {
                return  (pad.left + (width/2)) + xAxisScale(xVal);
            } else {   
                return (pad.left + (width/2)) - (-1 * xAxisScale(xVal));
           }
        })
        .attr("cy", function(d) {             
            var yVal = d[0].y_val;
            
            if (yVal >= 0) {
                return ( pad.top + (height/2)) - yAxisScale(yVal);
            } else {
                return (pad.top + (height/2)) +  (-1 * yAxisScale(yVal));                  
            }
        })        
        .on("mouseover", function(d) {
            d3.select(this)
                .attr("r", 5)
                .style("fill", "#86B404")
            regPlot.append("text")
                .attr("id", "dLabel")
                .style("fill", "#86B404")              
                .text( d[0].name + "(" + d[0].x_val + "," + d[0].y_val + ")")
                .attr("x", pad.left + 1)
                .attr("y", pad.top + 80);
        })
        .on("mouseout", function(d) { 
            d3.select(this)
                .attr("r", 3)
                .style("fill", "#9A2EFE")
            d3.selectAll("text#dLabel").remove();            
        });
  
    var regEquation = ss.linear_regression()
        .data(xyData)
        .line(); 
   
    var regParams = ss.linear_regression()
        .data(xyData)
     
    var intercept = regParams.b();
    intercept     =  Math.round(intercept*100) / 100;
    
    var slope = regParams.m();
    slope     = Math.round(slope*100) / 100;
    
    var sign; 
    if (slope > 0) {
        sign = ' + ';
    } else {
        sign = ' - ';
    };

    var equation = 'y = ' + intercept  + sign  +  slope + 'x'; 

    var rSquared = ss.r_squared(xyData, regEquation);
    rSquared     = Math.round(rSquared*100) / 100;
    rSquared     = 'R-squared = ' + rSquared;

    var regLine = d3.line()
        .x(function(d) {
            if (d[0] >= 0) {
                return  (pad.left + (width/2)) + xAxisScale(d[0]);
            } else {   
                return (pad.left + (width/2)) - (-1 * xAxisScale(d[0]));
            }})
        .y(function(d) { 
            if (d[1] >= 0) {
                return ( pad.top + (height/2)) - yAxisScale(d[1]);
            } else {
                return  (pad.top + (height/2)) +  (-1 * yAxisScale(d[1]));                  
            }});
     
    
    var fittedData = [];          
    xData.forEach(function (x) {
        var predictedValue = regEquation(parseFloat(x[1]));
        fittedData.push([parseFloat(x[1]), predictedValue]);
    });   

    regPlot.append("svg:path")
        .attr("d", regLine(fittedData))
        .attr('stroke', '#86B404')
        .attr('stroke-width', 2)
        .attr('fill', 'none');

     regPlot.append("g")
        .attr("id", "equation")
        .append("text")
        .text(equation)
        .attr("x", 20)
        .attr("y", 30)
        .style("fill", "#86B404")
        .style("font-weight", "bold");  
    
     regPlot.append("g")
        .attr("id", "rsquare")
        .append("text")
        .text(rSquared)
        .attr("x", 20)
        .attr("y", 50)
        .style("fill", "#86B404")
        .style("font-weight", "bold");  

        if (downloadLinks) {
            if (!regPlotDivId.match('#')) {
                regPlotDivId = '#' + regPlotDivId;
            }
            jQuery(regPlotDivId).append('<p style="margin-left: 40px">' + downloadLinks + '</p>');
        }
   }

}










