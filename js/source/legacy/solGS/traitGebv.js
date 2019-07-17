/** 
* for graphical presentation of GEBVs of a trait
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

//JSAN.use('MochiKit.LoggingPane');
JSAN.use('jquery');
JSAN.use('Prototype');
JSAN.use('jquery.jqplot');


jQuery(window).load( function() {

        var popId   = jQuery('input[name=population_id]').val();
        var traitId = jQuery('input[name=trait_id]').val();
        // document.write(popId, traitId);
        var params = 'pop_id' + '=' + popId + '&' + 'trait_id' + '=' + traitId;
        var action = '/trait/gebv/graph';
     
        var gebvDataRenderer = function() {
            var graphArray = [];
            graphArray[0] = [];
           
            jQuery.ajax({
                    async: false,
                        url: action,
                        dataType:"json",
                        data: params,
                        success: function(data) {
                        gebvData = data.gebv_data;
                        var state = data.status;
                     
                        if (state == 'success') {
                            for (var i=0; i < gebvData.length; i++) {
                                var xd = gebvData[i][0];
                                xd = xd.toString();
                                var yd = gebvData[i][1];
                                yd = yd.replace(/\s/, '');
                                yd = Number(yd);
                             
                                graphArray[0][i]    = [];
                                graphArray[0][i][0] = xd;
                                graphArray[0][i][1] = yd;                                 
                            }
                        }
                    }
                });
            
            return graphArray;
            
        };
  
        var gebvData = gebvDataRenderer();          
        if (gebvData == 'undefined') {
            var message = 'There is no GEBV data to plot. Please report this problem';  
            jQuery('#gebvPlot').append(message).show();
        } else {        
            var graph = jQuery.jqplot('gebvPlot', {
                    title: "GEBV",
                    dataRenderer: gebvDataRenderer,
                    seriesDefaults: {
                        showLine: false,
                        shadow: false,
                        markerOptions: {
                            size: 6,
                            shadow: false,                  
                        },
                    },
                    series: [{
                            label: 'gebv',
                            neighborThreshold: -1
                        }], 
                    grid: { 
                        drawGridLines: false,
                        gridLineColor: '#ffffff',
                        background: '#ffffff',
                        shadow: false,
                    },
                    highlighter: {
                        show: true,
                        sizeAdjust: 10,
                        tooltipAxes: 'xy',
                        useXTickMarks: true,
                        useYTickMarks: true,        
                    },
                    cursor: {
                        show: true,
                        useAxesFormatters: true,
                        showTooltip: true,
                        zoom: true,
                    },
                    axes: {
                        xaxis: {
                            renderer:jQuery.jqplot.CategoryAxisRenderer,
                            tickRenderer: jQuery.jqplot.CanvasAxisTickRenderer,
                            tickOptions: {
                                angle: -90, 
                                fontSize:5,
                            },
                            labelRenderer: jQuery.jqplot.CanvasAxisLabelRenderer,
                            label: 'Genotypes',
                        },
                        yaxis: {
                            tickRenderer: jQuery.jqplot.CanvasAxisTickRenderer,
                            tickOptions: { 
                                fontSize: 10,
                            },                           
                            labelRenderer: jQuery.jqplot.CanvasAxisLabelRenderer,
                            label: 'GEBV values',
                        },
                    }
                });
        }
        
        jQuery('.gebvbutton-reset').click( function() { 
                graph.resetZoom() 
        });
////
});
////




   
