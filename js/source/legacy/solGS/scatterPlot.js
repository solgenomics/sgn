


var solGS = solGS || function solGS(){};

solGS.scatterPlot = {

    plotRegression: function (regData) {
  
    var breedingValues      = regData.breeding_values;
    var phenotypeDeviations = regData.phenotype_deviations;
    var heritability        = regData.heritability;
    var phenotypeValues     = regData.phenotype_values;
    var regPlotDivId = regData.gebv_pheno_regression_div_id;
    var canvas = regData.canvas;
    var downloadLinks = regData.download_links;

    if (!canvas.match(/#/)) {canvas = '#' + canvas;}
    if (!regPlotDivId.match(/#/)) {regPlotDivId = '#' + regPlotDivId;}

     var phenoRawValues = phenotypeValues.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });

    var phenoXValues = phenotypeDeviations.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });

     var breedingYValues = breedingValues.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });
  
    var lsData      = [];
    var scatterData = [];
   
    phenotypeDeviations.map( function (pv) {
      
        var sD = [];
        var lD = []; 
        jQuery.each(breedingValues, function(i, gv) {
            
            if ( pv[0] === gv[0] ) {
         
                sD.push({'name' : gv[0], 'gebv' : gv[1], 'pheno_dev': pv[1]} );
                
                var ptY = parseFloat(gv[1]);
                var ptX = parseFloat(pv[1]);
                lD.push(ptX, ptY);
                
                return false;
            }
            
        });
        lsData.push(lD);
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
   
    var phenoMin = d3.min(phenoXValues);
    var phenoMax = d3.max(phenoXValues); 
    
    var xLimits = d3.max([Math.abs(d3.min(phenoXValues)), d3.max(phenoXValues)]);
    var yLimits = d3.max([Math.abs(d3.min(breedingYValues)), d3.max(breedingYValues)]);
    
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

     const regColor = '#86B404';
 
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
        .style({"text-anchor":"start", "fill": regColor});
       
    regPlot.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(" + yAxisMid +  "," + pad.top  + ")")
        .call(yAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("fill", "green")
        .style("fill", regColor);

    regPlot.append("g")
        .attr("id", "x_axis_label")
        .append("text")
        .text("Phenotype deviations")
        .attr("y", (pad.top + (height/2)) + 50)
        .attr("x", (width - 110))
        .attr("font-size", 10)
        .style("fill", regColor)

    regPlot.append("g")
        .attr("id", "y_axis_label")
        .append("text")
        .text("GEBVs")
        .attr("y", (pad.top -  10))
        .attr("x", ((width/2) - 80))
        .attr("font-size", 10)
        .style("fill", regColor)

    regPlot.append("g")
        .selectAll("circle")
        .data(scatterData)
        .enter()
        .append("circle")
        .attr("fill", "#9A2EFE")
        .attr("r", 3)
        .attr("cx", function(d) {
            var xVal = d[0].pheno_dev;
           
            if (xVal >= 0) {
                return  (pad.left + (width/2)) + xAxisScale(xVal);
            } else {   
                return (pad.left + (width/2)) - (-1 * xAxisScale(xVal));
           }
        })
        .attr("cy", function(d) {             
            var yVal = d[0].gebv;
            
            if (yVal >= 0) {
                return ( pad.top + (height/2)) - yAxisScale(yVal);
            } else {
                return (pad.top + (height/2)) +  (-1 * yAxisScale(yVal));                  
            }
        })        
        .on("mouseover", function(d) {
            d3.select(this)
                .attr("r", 5)
                .style("fill", regColor)
            regPlot.append("text")
                .attr("id", "dLabel")
                .style("fill", regColor)              
                .text( d[0].name + "(" + d[0].pheno_dev + "," + d[0].gebv + ")")
                .attr("x", pad.left + 1)
                .attr("y", pad.top + 80);
        })
        .on("mouseout", function(d) { 
            d3.select(this)
                .attr("r", 3)
                .style("fill", "#9A2EFE")
            d3.selectAll("text#dLabel").remove();            
        });
  
    var line = ss.linear_regression()
        .data(lsData)
        .line(); 
   
    var lineParams = ss.linear_regression()
        .data(lsData)
     
    var alpha = lineParams.b();
    alpha     =  Math.round(alpha*100) / 100;
    
    var beta = lineParams.m();
    beta     = Math.round(beta*100) / 100;
    
    var sign; 
    if (beta > 0) {
        sign = ' + ';
    } else {
        sign = ' - ';
    };

    var equation = 'y = ' + alpha  + sign  +  beta + 'x'; 

    var rq = ss.r_squared(lsData, line);
    rq     = Math.round(rq*100) / 100;
    rq     = 'R-squared = ' + rq;

    var lsLine = d3.line()
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
     
    
   
    var lsPoints = [];          
    jQuery.each(phenotypeDeviations, function (i, x)  {
       
        var  y = line(parseFloat(x[1])); 
        lsPoints.push([x[1], y]); 
   
    });
    
   
    regPlot.append("svg:path")
        .attr("d", lsLine(lsPoints))
        .attr('stroke', regColor)
        .attr('stroke-width', 2)
        .attr('fill', 'none');

     regPlot.append("g")
        .attr("id", "equation")
        .append("text")
        .text(equation)
        .attr("x", 20)
        .attr("y", 30)
        .style("fill", regColor)
        .style("font-weight", "bold");  
    
     regPlot.append("g")
        .attr("id", "rsquare")
        .append("text")
        .text(rq)
        .attr("x", 20)
        .attr("y", 50)
        .style("fill", regColor)
        .style("font-weight", "bold");  

        if (downloadLinks) {
            if (!regPlotDivId.match('#')) {
                regPlotDivId = '#' + regPlotDivId;
            }
            jQuery(regPlotDivId).append('<p style="margin-left: 40px">' + downloadLinks + '</p>');
        }
   
}

}










