/** 
* for graphical presentation of GEBVs of a trait.
* With capability for zooming in for selected area. 
* Double clicking zooms in by 50%.
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

//JSAN.use('MochiKit.LoggingPane');
JSAN.use('jquery');
JSAN.use('Prototype');


jQuery(window).load( function() {

        var popId   = jQuery('input[name=population_id]').val();
        var traitId = jQuery('input[name=trait_id]').val();
   
        var params = 'pop_id' + '=' + popId + '&' + 'trait_id' + '=' + traitId;
        var action = '/trait/gebv/graph';
       
        var graphArray      = [];
        graphArray[0]       = [];  
        var xAxisTickValues = [];
        var yAxisTickValues = [];
        var yValues         = [];
       
        var gebvDataRenderer = function() {            
            jQuery.ajax({
                    async: false,
                        url: action,
                        dataType:"json",
                        data: params,
                        success: function(data) {
                        var gebvData  = data.gebv_data;
                        var state     = data.status;
                     
                        if (state == 'success') {
                            for (var i=0; i < gebvData.length; i++) {
                                var xD = gebvData[i][0];
                                xD     = xD.toString();
                                var yD = gebvData[i][1];
                                yD     = yD.replace(/\s/, '');
                                yD     = Number(yD);
                                                              
                                xAxisTickValues.push([i, xD]);                               
                                yAxisTickValues.push([i, yD]);
                                yValues.push(yD);
                                                                     
                                graphArray[0][i]    = [];
                                graphArray[0][i][0] = xD;
                                graphArray[0][i][1] = yD; 
                                 
                            }
                        }
                    }
                });
           
            return {'bothAxisValues' : graphArray, 
                    'xAxisValues'    : xAxisTickValues,
                    'yAxisValues'    : yAxisTickValues,
                    'yValues'        : yValues 
                    };
            
        };
               
        var allData     = gebvDataRenderer();
           
        var xAxisValues = allData.xAxisValues;
        var yAxisValues = allData.yAxisValues;
        var yValues     = allData.yValues;         
        var minY        = Math.min.apply(Math, yValues);
        var maxY        = Math.max.apply(Math, yValues);      
        var minYLabel   = minY - (0.2*minY);
        var maxYLabel   = maxY + (0.2*maxY);
        var plotData    = allData.bothAxisValues;
          
        if (plotData == 'undefined') {
             var message = 'There is no GEBV data to plot. Please report this problem';  
             jQuery('#gebvPlot2').append(message).show();
         } else {
            var options = { 
                series: {
                    lines: { 
                        show: true 
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
                    ticks: xAxisValues,
                    tickColor: '#ffffff',
                    axisLabel: 'Genotypes',
                    position: 'bottom',
                    axisLabelPadding: 10,
                    color: '#0066CC',
                },
                yaxis: {                                
                    min: null,
                    max: null, 
                    axisLabel: 'Trait GEBVs',
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
                   
            var plot = jQuery.plot('#gebvPlot2', plotData, options);

            var overview = $.plot($("#gebvPlotOverview"), plotData, {
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
       
            jQuery("#gebvPlot2").bind("plotselected", function (event, ranges) {
                    //zoom in
                    plot = jQuery.plot(jQuery("#gebvPlot2"), plotData,
                                       jQuery.extend(true, {}, options, {
                                               xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
                                               yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to },                    
                                           }));
        
                    plot.setSelection(ranges, true);
                    overview.setSelection(ranges, true);
                });

            //highlight selected area on the overview plot
            jQuery("#gebvPlotOverview").bind("plotselected", function (event, ranges) {
                    plot.setSelection(ranges);
                }); 
        
            //reset zooming. Need to figure out zooming out
            jQuery("#gebvzoom-reset").click(function (e) { 
                    // var plot = jQuery.plot("#gebvPlot2", plotData, options);
                    location.reload();
                    // plot.zoomOut();
                });
            
            //given datapoint position and content, displays a styled tooltip
             var showTooltip = function(lt, tp, content) {                              
                jQuery('<div id="tooltip">' + content + '</div>').css({ 
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
                                ' and release or just double click at any' +
                                ' point on the plot.';
                 
                 jQuery('<div id="tooltip_zoom">' + help_txt  + '</div>').css({ 
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
            var useTooltip = jQuery("#gebvPlot2").bind("plothover", function (event, pos, item) {            
                    if (item) {
                        if (previousPoint != item.dataIndex) {                            
                            previousPoint = item.dataIndex;
                            
                            jQuery("#tooltip").remove();
                            jQuery("#tooltip_zoom").remove();
 
                            var x = item.datapoint[0];
                            var y = item.datapoint[1].toFixed(2);
                            var content = xAxisTickValues[x][1] + ', ' + y;
                  
                            showTooltip(item.pageX, item.pageY, content);
                            zoomHelp(item.pageX, item.pageY);
                        }
                    }
                    else {
                        jQuery("#tooltip").remove();
                        jQuery("#tooltip_zoom").remove();                   
                        previousPoint = null;                      
                    }          
                });
            
 ////
        }
 //////
////
});
////




   
