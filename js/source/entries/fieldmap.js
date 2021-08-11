import '../legacy/d3/d3Min.js';
import '../legacy/jquery.js';
import '../legacy/brapi/BrAPI.js';


export function init() {
    class FieldMap {
        constructor (trial_id) {
            this.trial_id = String;
            this.field_map_hash = Object;
            this.brapi_plots = Array;
        }

        set_id(trial_id) {
            this.trial_id = trial_id;
        }

        make_map(data) {
            console.log(data);
            var field_map_hash;
            var entryType;
            var studyName;
            var checks = {};
            var rows = [];
            var cols = [];
            var blocks = [];
            var check = [];
            var accession_ids = [];
            var accession_names = [];
            var plot_ids = [];
            var plot_names = [];
            var replicates = [];
            var plot_mums = [];
            var seedlot_names = [];
            var design;
            var plotImageDbIds = [];
            var plant_names = [];
            var entryType = [];
            var lowest_row = 10000;
            var lowest_col = 10000;
            var highest_row = 0;
            var highest_col = 0;

            jQuery.each(data, function(key_obj, value_obj) {
                jQuery.each(value_obj, function(key, value) {
                    if (key == 'Y'){
                        value = parseInt(value);
                        if (value < lowest_row) {
                            lowest_row = value;
                        } else if (value > highest_row) {
                            highest_row = value;
                        }
                        rows.push(value);
                    }
                    if (key == 'X'){
                        value = parseInt(value);
                        if (value < lowest_col) {
                            lowest_col =  value;
                        } else if (value > highest_col) {
                            highest_col = value;
                        }
                        cols.push(value);
                    }
                    if (key == 'blockNumber'){
                        blocks.push(value);
                    }
                    if (key == 'entryType'){
                        entryType.push(value);
                    }
                    if (key == 'germplasmDbId'){
                        accession_ids.push(value);
                    }
                    if (key == 'germplasmName'){
                        accession_names.push(value);
                    }
                    if (key == 'observationUnitDbId'){
                        plot_ids.push(value);
                    }
                    if (key == 'observationUnitName'){
                        plot_names.push(value);
                    }
                    if (key == 'replicate'){
                        replicates.push(value);
                    }
                    if (key == 'additionalInfo'){
                        jQuery.each(value, function(key_add, value_add){
                            if (key_add == 'plotNumber'){
                                plot_mums.push(value_add);
                            }
                            if (key_add == 'designType'){
                                design = value_add;
                                trialStudyDesign = value_add;
                            }
                            if (key_add == 'plotImageDbIds'){
                                plotImageDbIds.push(value_add);
                            }
                            if (key_add == 'plantNames'){
                                var s = value_add.length;
                                plant_names.push(s); 
                            }
                            if (key_add == 'seedLotName'){
                                seedlot_names.push(value_add);
                            }
                        });
                    }
                });

                num_real_plots = plot_names.length;

                
                if (changed_dim_rows) {
                    rows = [];
                    cols = [];
                    let count = 0;
                    for (let i=0; i<changed_dim_rows; i++) {
                        for (let j=0; j<changed_dim_cols; j++) {
                            rows[count] = lowest_row + i;
                            cols[count] = lowest_col + j;
                            count++;
                        }
                    }
                }

                lowest_row = Math.min.apply(Math, rows);
                lowest_col = Math.min.apply(Math, cols);
                highest_row = Math.max.apply(Math, rows);
                highest_col = Math.max.apply(Math, cols);
            
            });


            field_map_hash = {
                'rows': rows,
                'cols': cols,
                'blocks': blocks,
                'entryType': entryType,
                'check': entryType,
                'accession_ids': accession_ids,
                'accession_names': accession_names,
                'plot_ids': plot_ids,
                'plot_names': plot_names,
                'replicates': replicates,
                'plot_mums': plot_mums,
                'seedlot_names': seedlot_names,
                'design': design,
                'plotImageDbIds': plotImageDbIds,
                'plant_names': plant_names,
                'lowest_row': lowest_row,
                'highest_row': highest_row,
                'lowest_col': lowest_col,
                'highest_col': highest_col,
            }
        
            this.field_map_hash = field_map_hash;
        }



        field_view() {
            var trial_id = this.trial_id;
            var image = [];
            var image_ids = [];
            function btnClick(n){
            if (n.length == 0){
                jQuery("#hm_view_plot_image_submit").addClass("disabled");
            } else {
                jQuery("#hm_view_plot_image_submit").removeClass("disabled");
            }
            return true; 
            }
            var list_of_checks;
            var checks = {};

            var field_map_hash = this.field_map_hash;
            var rows = field_map_hash['rows'];
            var cols = field_map_hash['cols'];
            var blocks = field_map_hash['blocks'];
            var entryType = field_map_hash['entryType'];
            var check = field_map_hash['check'];
            var accession_ids = field_map_hash['accession_ids'];
            var accession_names = field_map_hash['accession_names'];
            var plot_ids = field_map_hash['plot_ids'];
            var plot_names = field_map_hash['plot_names'];
            var replicates = field_map_hash['replicates'];
            var plot_mums = field_map_hash['plot_mums'];
            var seedlot_names = field_map_hash['seedlot_names'];
            var design = field_map_hash['design'];
            var plotImageDbIds = field_map_hash['plotImageDbIds'];
            var plant_names = field_map_hash['plant_names'];
            var lowest_col = field_map_hash['lowest_col'];
            var highest_col = field_map_hash['highest_col'];
            var lowest_row = field_map_hash['lowest_row'];
            var highest_row = field_map_hash['highest_row'];
            var list_of_checks;
            invert_rows = document.getElementById("invert_row_checkmark").checked ? "yes" : "no";
            var psudo_rows = [];
            var map_option = 0;
            for (i=0; i<plot_names.length; i++){ 
                if (rows[i] != '') {}
                else if (rows[i] == '') {
                    map_option = 1;
                    if (blocks[i] && design != 'splitplot'){
                        var r = blocks[i];
                        psudo_rows.push(r);
                    }
                    else if (replicates[i] && !blocks[i] && design != 'splitplot'){
                        var s = replicates[i];
                        psudo_rows.push(s);
                    }
                    else if (design == 'splitplot'){
                        var s = replicates[i];
                    }
                        psudo_rows.push(s);
                }
            }

            var false_coord;
            if (map_option == 1){
                rows = psudo_rows;
                false_coord = 'false_coord';
            }
            var unique_rows = [];
            var unique_cols = [];
            var unique = rows.filter(function(itm, i, rows) {
                if (i == rows.indexOf(itm)){
                    unique_rows.push(itm);
                }
            });
            
            function makeArray(count, content) {
                var result = [];
                var counting = 0;
                if(typeof(content) == "function") {
                    counting = 1;
                    for(var i=0; i<count; i++) {
                        result.push(counting);
                        counting++;
                    }
                } else {
                    counting = 1;
                    for(var i=0; i<count; i++) {
                        result.push(counting);
                        counting++;
                    }
                }
                return result;
            }

            var psudo_cols = [];
            var psudo_columns = [];
            var counts = {};
            if (map_option == 1){
                for (var i = 0; i < rows.length; i++) {
                    counts[rows[i]] = 1 + (counts[rows[i]] || 0);
                }
                jQuery.each(counts, function(key, value){
                    psudo_cols.push(makeArray(value, key));
                });
                var psudo_columns = [].concat.apply([], psudo_cols);
                cols = psudo_columns;
            }
            var unique = cols.filter(function(itm, i, cols) {
                if (i == cols.indexOf(itm)){
                    unique_cols.push(itm);
                }
            });
            
            var plot_popUp;
            var result = [];
            for (var i=0; i<plot_names.length; i++){
                if (plant_names[i] < 1) { 
                    plot_popUp = plot_names[i]+"\nplot_No: "+plot_mums[i]+"\nblock_No: "+blocks[i]+"\nrep_No:"+replicates[i]+"\nstock:"+accession_names[i]+"\nseedlot:"+seedlot_names[i];
                }
                else {
                    plot_popUp = plot_names[i]+"\nplot_No: "+plot_mums[i]+"\nblock_No: "+blocks[i]+"\nrep_No:"+replicates[i]+"\nstock:"+accession_names[i]+"\nnumber_of_plants:"+plant_names[i]+"\nseedlot:"+seedlot_names[i];
                }
                result.push({plotname:plot_names[i], entryType: entryType[i], accession_id: accession_ids[i], plot_id:plot_ids[i], stock:accession_names[i], plotn:plot_mums[i], blkn:blocks[i], rep:replicates[i], row:rows[i], plot_image_ids:plotImageDbIds[i], col:cols[i], plot_msg:plot_popUp, seedlot:seedlot_names[i]});
            }

            if (plot_names.length < ((highest_col - lowest_col + 1) * (highest_row - lowest_row + 1))) {
                let num_dummy_plots = (changed_dim_rows * changed_dim_cols) - plot_names.length;
                for (let i = 1; i <= num_dummy_plots; i++) {
                    result.push({plotname:"filler plot" + String(i), row:rows[rows.length-i], blkn: blocks[0], plot_image_ids:plotImageDbIds[0], col:cols[cols.length-i], plot_msg:plot_popUp});
                }
            }

            var col_max = Math.max.apply(Math,unique_cols);
            var row_max = Math.max.apply(Math,unique_rows);
            var rep_max = Math.max.apply(Math,replicates);
            var block_max = Math.max.apply(Math,blocks);          
            var col_length = cols[0]; 
            var row_length = rows[0];

            num_cols = col_max;
            num_rows = row_max;

            unique_rows = [];
            unique_cols = [];

            for (let i=1; i<=row_max; i++){
                unique_rows.push(i);
            }

            for (let i=1; i<=col_max; i++){
                unique_cols.push(i);
            }
            
            var controls = [];
            var design_type;
            var datasets;
            var color;
            var old_plot_id;
            var old_plot_accession;
            var modifiedRowLabels;
            var modifiedColLabels;
            var unique_ctrl = [];
            var plots = plot_mums;
            var stocks = accession_names;
            for (var i = 0; i < check.length; i++) {
                if ( check[i] == "Check") {
                    var s = stocks[i];
                    controls.push(s);
                }
            }
            
            if (controls){
                var unique = controls.filter(function(itm, i, controls) {
                    if (i == controls.indexOf(itm)){
                        unique_ctrl.push(itm);
                    }
                });
                
                list_of_checks = unique_ctrl;
                for (var i = 0; i < stocks.length; i++) {
                    for (var n = 0; n < unique_ctrl.length; n++){
                        if ( unique_ctrl[n] == stocks[i]) {
                            var p = plots[i];
                            var s = stocks[i];
                            checks[p] = s;
                        }
                    }
                }
            }
            
            design_type = design;
            if (col_length && row_length) {
                jQuery("#working_modal").modal("hide");
                jQuery("#chart_fm").css({"display": "inline-block"});
                jQuery("#container_fm").css({"display": "inline-block", "overflow": "auto"});
                jQuery("#trait_heatmap").css("display", "none");
                jQuery("#d3legend").css("display", "inline-block");
                jQuery("#container_heatmap").css("display", "none");
                jQuery("#trait_heatmap").css("display", "none");

                var margin = { top: 50, right: 0, bottom: 100, left: 30 },
                    width = 50 * (col_max + 3) + 30 - margin.left - margin.right,
                    height = 50 * (row_max + 3) + 100 - margin.top - margin.bottom,
                    gridSize = 50,
                    legendElementWidth = gridSize*2,
                    buckets = 9,
                    colors = ["#ffffd9","#edf8b1","#c7e9b4","#7fcdbb","#41b6c4","#1d91c0","#225ea8","#253494","#081d58"], // alternatively colorbrewer.YlGnBu[9]
                    rows = unique_rows,
                    columns = unique_cols.sort((a,b)=>a-b);
                    datasets = result;
                    
                var svg = d3.select("#container_fm").append("svg")
                    .attr("width", width + margin.left + margin.right)
                    .attr("height", height + margin.top + margin.bottom)
                    .append("g")
                    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
                                    
                var rowLabels = svg.selectAll(".rowLabel")
                    .data(rows)
                    .enter().append("text")
                    .text(function (d) {
                        
                        if (invert_rows == "yes") {
                            return highest_row + 1 - d;
                        } else {
                            return d;
                        }
                    })
                    .attr("x", 0 )
                    .attr("y", function (d, i) { return i * gridSize; })
                    .style("text-anchor", "end")
                    .attr("transform", "translate(-6," + gridSize / 1.5 + ")")
                    .attr("class", function (d, i) { return ((i >= 0 && i <= 4) ? "rowLabel mono axis axis-workweek" : "rowLabel mono axis"); });

                var columnLabels = svg.selectAll(".columnLabel")
                    .data(columns)
                    .enter().append("text")
                    .text(function(d) { return d; })
                    .attr("x", function(d, i) { return i * gridSize; })
                    .attr("y", 0 )
                    .style("text-anchor", "middle")
                    .attr("transform", "translate(" + gridSize / 2 + ", -6)")
                    .attr("class", function(d, i) { return ((i >= 7 && i <= 16) ? "columnLabel mono axis axis-worktime" : "columnLabel mono axis"); });                
                    

                var fieldmapChart = function(datasets) {
                    datasets.forEach(function(d) { 
                        d.row = +d.row;
                        d.col = +d.col;
                        d.blkn = +d.blkn;   
                    });

                    if (top_border_selection == "yes") {
                        datasets.forEach(function(d) { 
                            if (d.stock != border_accession_name) {
                                d.row += 1;
                            }
                        });
                        
                        if (left_border_selection == "yes") {
                            highest_col += 1;
                        }
                        for (let i = lowest_col; i <= highest_col; i++) {
                            datasets.push({plotname:plot_names[i] + "_top_border", plot_id:plot_ids[i] + plot_ids[i], stock:border_accession_name,
                            blkn:blocks[i], row:lowest_row, plot_image_ids:plotImageDbIds[lowest_col], col:i, plot_msg:plot_popUp});
                        }
                        highest_row += 1;

                        modifiedRowLabels = svg.selectAll(".rowLabel");
                        modifiedRowLabels.attr("y", function(d, i) { return (i+1) * gridSize; });
                    }
                    if (left_border_selection == "yes") {
                        datasets.forEach(function(d) {
                            if (d.stock != border_accession_name) {
                                d.col += 1;
                            }
                        });
                        if (top_border_selection == "yes") {
                            lowest_row += 1;
                        }
                        for (let i = lowest_row; i <= highest_row; i++) {
                            datasets.push({plotname:plot_names[i] + "_left_border", plot_id:plot_ids[i] + 2 * plot_ids[i], stock:border_accession_name,
                            blkn:blocks[i], row:i, plot_image_ids:plotImageDbIds[lowest_row], col:lowest_col, plot_msg:plot_popUp});
                        }
                        lowest_col += 1;
                        modifiedColLabels = svg.selectAll(".columnLabel");
                        modifiedColLabels.attr("x", function(d, i) { return (i+1) * gridSize; });                    
                    }

                    if (right_border_selection == "yes") {
                        if (top_border_selection == "yes" && left_border_selection == "yes") {
                            lowest_row -= 1;
                        } else if (left_border_selection == "yes") {
                            highest_col += 1;
                        }
                        for (let i = lowest_row; i <= highest_row; i++) {
                            datasets.push({plotname:plot_names[i] + "_right_border", plot_id:plot_ids[i] + 2 * plot_ids[i], stock:border_accession_name,
                            blkn:blocks[i], row:i, plot_image_ids:plotImageDbIds[lowest_row], col:highest_col + 1, plot_msg:plot_popUp});
                        }
                    }

                    if (bottom_border_selection == "yes") {
                        if (left_border_selection == "yes") {
                            lowest_col -= 1;
                            if (right_border_selection == "no" && top_border_selection == "no") {
                                highest_col += 1;
                            }
                        }
                        if (right_border_selection == "yes") {
                            highest_col += 1;
                        }
                        for (let i = lowest_col; i <= highest_col; i++) {
                            datasets.push({plotname:plot_names[i] + "_bottom_border", plot_id:plot_ids[i] + 2 * plot_ids[i], stock:border_accession_name,
                            blkn:blocks[i], row:highest_row + 1, plot_image_ids:plotImageDbIds[lowest_row], col:i, plot_msg:plot_popUp});
                        }
                    }
                    
                    if (invert_rows == "yes") {
                        datasets.forEach(function (d) {
                            if (!d.plotname.includes("border")) {
                                d.row = highest_row + 1 - d.row;
                                if (top_border_selection == "yes") {
                                    d.row = d.row + 1;
                                }
                            }
                        })
                    }
                    
                    

                    var cards = svg.selectAll(".col")
                    .data(datasets, function(d) {return d.row+':'+d.col;});

                    cards.append("title");
                    var image_icon = function (d, i){
                        image = d.plot_image_ids; 
                        var plot_image;
                        if (image.length > 0){
                            plot_image = "/static/css/images/plot_images.png"; 
                        }else{
                            plot_image = "";
                        }
                        return plot_image;
                    }
                    
                    var colors = function (d, i){
                        if (block_max == 1){
                            color = '#41b6c4';
                        }
                        else if (block_max > 1){
                            if (d.blkn % 2 == 0){
                                color = '#c7e9b4';
                            }
                            else{
                                color = '#41b6c4'
                            }
                        }
                        else{
                            color = '#c7e9b4';
                        }
                        if (unique_ctrl) {
                            for (var i = 0; i < unique_ctrl.length; i++) {
                                if ( unique_ctrl[i] == d.stock) {
                                    color = '#081d58';
                                }
                            }
                        }
                        if (d.stock == border_accession_name) {
                            color = "lightgrey";
                        }
                        if (d.plotname.indexOf("dummy") !== -1) {
                            color = 'lightgrey';
                        }
                        return color;
                    }
                    
                    var strokes = function (d, i){
                        var stroke;
                        if (rep_max == 1){
                            stroke = 'green';
                        }
                        else if (rep_max > 1){
                            if (d.rep % 2 == 0){
                                stroke = 'red';
                            }
                            else{
                                stroke = 'green'
                            }
                        }
                        else{
                            stroke = 'red';
                        }
                        return stroke;
                        }
                        
                        function clickcancel() {
                        var event = d3.dispatch('click', 'dblclick');
                        function cc(selection) {
                            var down,
                                tolerance = 5,
                                last,
                                wait = null;
                            function dist(a, b) {
                                return Math.sqrt(Math.pow(a[0] - b[0], 2), Math.pow(a[1] - b[1], 2));
                            }
                            selection.on('mousedown', function() {
                                down = d3.mouse(document.body);
                                last = +new Date();
                            });
                            selection.on('mouseup', function() {
                                if (dist(down, d3.mouse(document.body)) > tolerance) {
                                    return;
                                } else {
                                    if (wait) {
                                        window.clearTimeout(wait);
                                        wait = null;
                                        event.dblclick(d3.event);
                                    } else {
                                        wait = window.setTimeout((function(e) {
                                            return function() {
                                                event.click(e);
                                                wait = null;
                                            };
                                        })(d3.event), 300);
                                    }
                                }
                            });
                        };
                        return d3.rebind(cc, event, 'on');
                        }
                    var cc = clickcancel();
                    
                    cards.enter().append("rect")
                        .attr("x", function(d) { return (d.col - 1) * gridSize; })
                        .attr("y", function(d) { return (d.row - 1) * gridSize; })
                        .attr("rx", 4)
                        .attr("ry", 4)
                        .attr("class", "col bordered")
                        .attr("width", gridSize)
                        .attr("height", gridSize)
                        .style("stroke-width", 2)
                        .style("stroke", strokes)
                        .style("fill", colors)
                        
                        .on("mouseover", function(d) { d3.select(this).style('fill', 'green').style('cursor', 'pointer'); })
                        .on("mouseout", function(d) { 
                                                        var cards = svg.selectAll(".col")
                                                            .data(datasets, function(d) {return d.row+':'+d.col;});

                                                        cards.append("title");
                                                        
                                                        cards.enter().append("rect")
                                                        .attr("x", function(d) { return (d.col - 1) * gridSize; })
                                                        .attr("y", function(d) { return (d.row - 1) * gridSize; })
                                                        .attr("rx", 4)
                                                        .attr("ry", 4)
                                                        .attr("class", "col bordered")
                                                        .attr("width", gridSize)
                                                        .attr("height", gridSize)
                                                        .style("stroke-width", 2)
                                                        .style("stroke", strokes)
                                                        .style("fill", colors); 
                                                        
                                                        cards.style("fill", colors) ;                          

                                                        cards.select("title").text(function(d) { return d.plot_msg; }) ;
                                                        
                                                        cards.exit().remove();
                                                        //console.log('out');
                                                        })                                
                        .call(cc);                                
                                                    
                        cc.on("dblclick", function(el) { var me = d3.select(el.srcElement);
                                                            var d = me.data()[0];
                                                            window.location.href = '/stock/'+d.plot_id+'/view';
                                                        });
                        cc.on("click", function(el) {  
                                                        var me = d3.select(el.srcElement);
                                                        var d = me.data()[0];
                                                        image_ids = d.plot_image_ids;
                                                        var replace_accession = d.stock;
                                                        var replace_plot_id = d.plot_id;
                                                        var replace_plot_name = d.plotname;
                                                        var replace_plot_number = d.plotn;
                                                        
                                                        jQuery('#plot_image_ids').html(image_ids);
                                                        jQuery('#hm_replace_accessions_link').find('button').trigger('click');
                                                        jQuery("#hm_replace_accessions_link").on("click", function(){ btnClick(image_ids); });
                                                        jQuery('#hm_edit_plot_information').html('<b>Selected Plot Information: </b>');
                                                        jQuery('#hm_edit_plot_name').html(replace_plot_name);
                                                        jQuery('#hm_edit_plot_number').html(replace_plot_number);
                                                        old_plot_id = jQuery('#hm_edit_plot_id').html(replace_plot_id);
                                                        old_plot_accession = jQuery('#hm_edit_plot_accession').html(replace_accession);
                                                        jQuery('#hm_replace_plot_accessions_dialog').modal('show');
                                                        
                                                        new jQuery.ajax({
                                                            type: 'POST',
                                                            url: '/ajax/breeders/trial/'+ trial_id +'/retrieve_plot_images',
                                                            dataType: "json",
                                                            data: {
                                                                    'image_ids': JSON.stringify(image_ids),
                                                                    'plot_name': replace_plot_name,
                                                                    'plot_id': replace_plot_id,
                                                            },
                                                            success: function (response) {
                                                            jQuery('#working_modal').modal("hide");
                                                            var images = response.image_html;
                                                            if (response.error) {
                                                                alert("Error Retrieving Plot Images: "+response.error);
                                                            }
                                                            else {
                                                                jQuery("#show_plot_image_ids").html(images);
                                                            
                                                            // jQuery('#view_plot_image_dialog').modal("show"); 
                                                            }
                                                            },
                                                            error: function () {
                                                                jQuery('#working_modal').modal("hide");
                                                                alert('An error occurred retrieving plot images');
                                                            }
                                                        });
                                                    
                                                        });
                                                        
                    //cards.transition().duration(1000)
                    cards.style("fill", colors) ;  

                    cards.select("title").text(function(d) { return d.plot_msg; }) ;
                    
                    cards.append("text");
                    cards.enter().append("text")
                    .attr("x", function(d) { return (d.col - 1) * gridSize + 10; })
                    .attr("y", function(d) { return (d.row - 1) * gridSize + 20 ; })
                    .text(function(d) { return d.plotn; });
                    
                    cards.select("text").text(function(d) { return d.plotn; }) ;
                        
                    cards.append("image");
                    cards.enter().append("image")
                    .attr("xlink:href", image_icon)
                    .attr("x", function(d) { return (d.col - 1) * gridSize + 2; })
                    .attr("y", function(d) { return (d.row - 1) * gridSize + 3 ; })
                    .attr('width', 10)
                    .attr('height', 10)
                                                
                    cards.exit().remove();
                
                } ; 
                
                fieldmapChart(datasets);
                if (false_coord){
                    alert("Psudo row and column numbers have been used in displaying the heat map. Plots row and column numbers were generated from block_number and displayed in zigzag format. You can upload row and column numbers for this trial to reflect the field layout.");
                }
            }
            else  {
                jQuery("#working_modal").modal("hide");
                jQuery("#container_heatmap").css("display", "none");
                jQuery("#trait_heatmap").css("display", "none");
                jQuery("#trial_no_rowColMSG").css("display", "inline-block");
            }

            this.brapi_plots = datasets;

        }
    }

    const mapObj = new FieldMap();
    return mapObj;
}