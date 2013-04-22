/** 
* for graphical presentation of phenotype data of a trait
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
      
        var params = 'pop_id' + '=' + popId + '&' + 'trait_id' + '=' + traitId;
        var action = '/phenotype/graph';
     
        var phenoDataRenderer = function() {
            var graphArray = [];
            graphArray[0] = [];
           
            jQuery.ajax({
                    async: false,
                        url: action,
                        dataType:"json",
                        data: params,
                        success: function(data) {
                        traitData = data.trait_data;
                        var state = data.status;
                     
                        if (state == 'success') {
                            for (var i=0; i < traitData.length; i++) {
                                var xd = traitData[i][0];
                                xd = xd.toString();
                                var yd = traitData[i][1];
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
  
        var phenoData = phenoDataRenderer();          
        if (phenoData == 'undefined') {
            var message = 'There is no phenotype data to plot. Please report this problem';  
            jQuery('#phenoHistogram').append(message).show();
        } else {        
            var graph = jQuery.jqplot('phenoHistogram', {
                    title: "Phenotype data",
                    dataRenderer: phenoDataRenderer,
                    seriesDefaults: {
                        showLine: false,
                        shadow: false,
                        markerOptions: {
                            size: 6,
                            shadow: false,                  
                        },
                    },
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
                        showTooltip: false,
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
                            label: 'Trait values',
                        },
                    }
                });
       }
     
////
});
////




   
