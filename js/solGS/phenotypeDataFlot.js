/** 
* for graphical presentation of phenotype data of a trait
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

//JSAN.use('MochiKit.LoggingPane');
JSAN.use('jquery');
JSAN.use('Prototype');
//JSAN.use('jquery.flot');


jQuery(window).load( function() {

        var popId   = jQuery('input[name=population_id]').val();
        var traitId = jQuery('input[name=trait_id]').val();
      
        var params = 'pop_id' + '=' + popId + '&' + 'trait_id' + '=' + traitId;
        var action = '/phenotype/graph';
     
        var phenoPlotData        = [];
        phenoPlotData[0]         = [];  
        var xAxisTickPhenoValues = [];
        var yAxisTickPhenoValues = [];
        var yPhenoValues         = [];
      
        var phenoDataRenderer = function() {            
            jQuery.ajax({
                    async: false,
                        url: action,
                        dataType:"json",
                        data: params,
                        success: function(data) {
                        var phenoData  = data.trait_data;
                        var state     = data.status;
                     
                        if (state == 'success') {
                            for (var i=0; i < phenoData.length; i++) {
                                var xPD = phenoData[i][0];
                                xPD     = xPD.toString();
                                var yPD = phenoData[i][1];
                                yPD     = yPD.replace(/\s/, '');
                                yPD     = Number(yPD);
                                                              
                                xAxisTickPhenoValues.push([i, xPD]);                               
                                yAxisTickPhenoValues.push([i, yPD]);
                                yPhenoValues.push(yPD);
                                                        
                                phenoPlotData[0][i]    = [];
                                phenoPlotData[0][i][0] = xPD;
                                phenoPlotData[0][i][1] = yPD; 
                                 
                            }
                        }
                    }
                });
                
            return {'bothAxisPhenoValues' : phenoPlotData, 
                    'xAxisPhenoValues'    : xAxisTickPhenoValues,
                    'yAxisPhenoValues'    : yAxisTickPhenoValues,
                    'yPhenoValues'        : yPhenoValues 
                    };
            
        };
          
        var allPhenoData     = phenoDataRenderer();   
        var xAxisPhenoValues = allPhenoData.xAxisPhenoValues; 
        var yAxisPhenoValues = allPhenoData.yAxisPhenoValues;
        var yPhenoValues     = allPhenoData.yPhenoValues;         
        var minYPheno        = Math.min.apply(Math, yPhenoValues); 
        var maxYPheno        = Math.max.apply(Math, yPhenoValues);       
        var minYPhenoLabel   = minYPheno - (0.2*minYPheno);        
        var maxYPhenoLabel   = maxYPheno + (0.2*maxYPheno);         
        var plotPhenoData    = allPhenoData.bothAxisPhenoValues;
        
        if (plotPhenoData == 'undefined') {
            var message = 'There is no phenotype data to plot. Please report this problem';  
            jQuery('#phenoPlot').append(message).show();
        } else { 
            var optionsPheno = { 
                series: {
                    lines: { 
                        show: false 
                    },
                    points: { 
                        show: true 
                    },                
                },              
                grid: {
                    show: true,
                    clickable: true,
                    hoverable: true,               
                },
                selection: {
                    mode: 'xy',
                    color: '#0066CC',
                },
                xaxis:{
                    mode: 'categories',
                    tickColor: '#ffffff',
                    ticks: xAxisPhenoValues, 
                    axisLabel: 'Genotypes',
                    position: 'bottom',
                    axisLabelPadding: 10,
                    color: '#0066CC',
                },
                yaxis: {                                
                    min: null,
                    max: null, 
                    axisLabel: 'Trait phenotype values',
                    position: 'left',
                    color: '#0066CC',                    
                },
                zoom: {
                    interactive: true,
                    amount: 1.5,
                    trigger: 'dblclick',
                },
                pan: {
                    interactive: false,                
                },                        
            };

            var plotPheno = jQuery.plot('#phenoPlot', plotPhenoData, optionsPheno);
            
            var overviewPheno = jQuery.plot($("#phenoPlotOverview"), plotPhenoData, {
                    series: {
                        lines: { 
                            show: true, 
                            lineWidth: 2 
                        },
                        shadowSize: 0
                    },
                    xaxis: { 
                        ticks: [], 
                        mode: "categories", 
                        label: 'Genotypes',
                    },                  
                    selection: { 
                        mode: "xy", 
                    },
                    colors: ["#cc0000", "#0066CC"],
                });

            jQuery("#phenoPlot").bind("plotselected", function (event, ranges) {
                    //zoom in
                    plotPheno = jQuery.plot(jQuery("#phenoPlot"), plotPhenoData,
                                       jQuery.extend(true, {}, optionsPheno, {
                                               xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
                                               yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to },                    
                                           }));
        
                    plotPheno.setSelection(ranges, true);
                    overviewPheno.setSelection(ranges, true);
                });

            //highlight selected area on the overview plot
            jQuery("#phenoPlotOverview").bind("plotselected", function (event, ranges) {
                    plotPheno.setSelection(ranges);
                }); 
        
            //reset zooming. Need to figure out zooming out
            jQuery("#phenozoom-reset").click(function (e) { 
                    //jQuery.plot("#phenoPlot", plotPhenoData, optionsPheno);
                    location.reload();
                    // plot.zoomOut();
                });
            
            //given datapoint position and content, displays a styled tooltip
             var showTooltipPheno = function(lt, tp, content) {                              
                jQuery('<div id="phenotooltip">' + content + '</div>').css({ 
                        position: 'absolute',
                        display: 'none',
                        'font-weight': 'bold',
                        top: tp + 10,
                        left: lt + 10, 
                        border: '1px solid #ffaf55',
                        padding: '2px'              
                    }).appendTo("body").show();                
             };

             var zoomHelp = function (lt, tp) {
                 var help_txt = 'To zoom in, select an area on the plot' + 
                                ' and release or double click at any' +
                                ' point on the plot.';
                 
                 jQuery('<div id="tooltipZoomPheno">' + help_txt  + '</div>').css({ 
                         position: 'absolute',
                         display: 'none',
                         'font-weight': 'bold',
                         top: tp + 35,
                         left: lt + 30, 
                         border: '1px solid #C9BE62',
                         padding: '2px'              
                    }).appendTo("body").show(); 
             }; 

            //calls the tooltip display function and binds the 'plotover' event to
            //the plot
            var previousPoint = null;
            var useTooltipPheno = jQuery("#phenoPlot").bind("plothover", function (event, pos, item) {            
                    if (item) {
                        if (previousPoint != item.dataIndex) {
                            previousPoint = item.dataIndex;
                   
                            jQuery("#phenotooltip").remove();
                            jQuery("#tooltipZoomPheno").remove();

                            var x = item.datapoint[0];
                            var y = item.datapoint[1].toFixed(2);
                            var content = xAxisTickPhenoValues[x][1] + ', ' + y;
                            
                            showTooltipPheno(item.pageX, item.pageY, content); 
                            zoomHelp(item.pageX, item.pageY);
                        }
                    }
                    else {
                        jQuery("#phenotooltip").remove();
                        jQuery("#tooltipZoomPheno").remove();

                        previousPoint = null;            
                    }          
                });           
        }
     
////
});
////




   
