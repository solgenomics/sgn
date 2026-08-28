import "../legacy/d3/d3v4Min.js"; // provides global `d3` (select/append/event); datum-first event handlers
import "../legacy/jquery.js";
import { sankey as d3sankey, sankeyCenter, sankeyLinkHorizontal } from "d3-sankey";

// BrAPI v2 on this instance requires login (brapi_require_login), so browser
// XHRs must carry the session token as a bearer header. Same pattern as
// js/source/legacy/CXGN/BreedersToolbox/UploadImages.js.
function sgnSessionToken() {
    var m = document.cookie.match(/(?:^|;\s*)sgn_session_id=([^;]+)/);
    return m ? decodeURIComponent(m[1]) : "";
}
function brapiAjax(url) {
    var token = sgnSessionToken();
    var opts = {
        url: url,
        error: function(xhr) {
            console.error("BrAPI request failed (" + (xhr && xhr.status) + "): " + url);
        }
    };
    // Only send the bearer header when logged in. Instances with
    // `brapi_require_login 0` ignore it; instances that require login need it.
    if (token) opts.headers = { "Authorization": "Bearer " + token };
    return jQuery.ajax(opts);
}
// BrAPI defaults to pageSize=10; request one page large enough to hold every
// accession in a trial so germplasm matching is not silently truncated.
var GERMPLASM_PAGE_SIZE = 100000;
function studyGermplasmXhr(studyId) {
    return brapiAjax('/brapi/v2/germplasm?pageSize=' + GERMPLASM_PAGE_SIZE + '&studyDbId=' + studyId);
}

// Pull the germplasm list out of a settled /brapi/v2/germplasm jqXHR, tolerating
// error/empty responses (result may be null on 401 or other failures).
function germplasmNames(xhr) {
    var result = xhr && xhr.responseJSON && xhr.responseJSON.result;
    var data = (result && Array.isArray(result.data)) ? result.data : [];
    return data.map(function(g){ return g.germplasmName; });
}

// Renders the "Field Trial to Field Trial Linkage" section (tables + Sankey diagram)
// on the field trial detail page. Invoked lazily from
// mason/breeders_toolbox/trial/field_trial_from_field_trial_linkage.mas
export function init(trial_id, trial_name) {

    jQuery.ajax({
        url : '/ajax/breeders/trial/'+trial_id+'/field_trial_from_field_trial',
        beforeSend: function() {
                     jQuery("#working_modal").modal("show");
        },
        success: function(r){
          jQuery('#working_modal').modal("hide");

          var html1 = '<table class="table table-hover table-bordered"><thead><tr><th>Source Field Trial(s) For This Field Trial</th></tr></thead><tbody>';
          var html2 = '<table class="table table-hover table-bordered"><thead><tr><th>Field Trial(s) Sourced From This Field Trial</th></tr></thead><tbody>';
          for (var i=0; i<r.source_field_trials.length; i++){
              html1 = html1 + '<tr><td><a href="/breeders/trial/'+r.source_field_trials[i][0]+'">'+r.source_field_trials[i][1]+'</a></td></tr>';
          }
          for (var i=0; i<r.field_trials_sourced.length; i++){
              html2 = html2 + '<tr><td><a href="/breeders/trial/'+r.field_trials_sourced[i][0]+'">'+r.field_trials_sourced[i][1]+'</a></td></tr>';
          }
          html1 = html1 + '</tbody></table>';
          html2 = html2 + '</tbody></table>';
          jQuery('#field_trial_to_field_trial_html').html(html1+html2);


          // BEGIN: Code for sankey visualizer


          var nodeMap = {}; //Hash of nodes, runs parallel to array of nodes
          var nodes = [];
          var primitiveLinks = [];
          var linkMap = {};
          var links = []; //List to be used for all connections at the accession level
          var linkAjaxCallsMap = {}; // Map of ajax calls for links
          var nodeAjaxCallsMap = {}; // Map of ajax calls for nodes

          var graph;
          var sankey;
          var svgnodes;
          var svglinks;
          var svglabels;
          var data;

          //Need to check that there's actually data to render before making a big svg canvas
          if (!(r.source_field_trials.length == 0 && r.field_trials_sourced.length == 0)){

            //Set margins and set up svg area
            var margin = {top: 100, right: 100, bottom: 100, left: 100};
            var width = 800//document.querySelector('#field_trial_to_field_trial_html').offsetWidth*0.90;
            var height = 400;//document.querySelector('#field_trial_to_field_trial_html').offsetHeight*0.90;

            var svg = d3.select("#field_trial_to_field_trial_html").append("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .attr("style","overflow-x: auto;")
            .append("g")
            .attr("transform","translate(" + (margin.left + 0) + "," + (margin.top + 0) + ")")
            .attr("id", "sankeycanvas");


            // The primitive graph is the graph with the nodes and just the links between nodes but without any information regarding accessions
            construct_primitive_graph(parseInt(trial_id), trial_name, r);

            receive_JSONs(parseInt(trial_id));

          }


          function construct_primitive_graph(base_node_id, base_trial_name, response){

            nodeMap[base_node_id] = {"name": base_node_id, "id": base_trial_name, "trialType":null}; //Initialize the node hash

            linkAjaxCallsMap[base_node_id] = studyGermplasmXhr(base_node_id);
            nodeAjaxCallsMap[base_node_id] = brapiAjax('/brapi/v2/studies/'+base_node_id);

            //Send ajax calls for studies that are the source of this study
            for (var i = 0; i < response.source_field_trials.length; i++){

              linkAjaxCallsMap[ response.source_field_trials[i][0] ] = studyGermplasmXhr(response.source_field_trials[i][0]);
              nodeAjaxCallsMap[response.source_field_trials[i][0]] = brapiAjax('/brapi/v2/studies/'+response.source_field_trials[i][0]);

              nodeMap[response.source_field_trials[i][0]] = {"name":response.source_field_trials[i][0], "id":response.source_field_trials[i][1], "trialType":null};
              primitiveLinks.push({"source":nodeMap[response.source_field_trials[i][0]], "target": nodeMap[base_node_id], "value":1});
            }

            //Send ajax calls for studies that are sourced from this trial
            for (var i = 0; i < response.field_trials_sourced.length; i++){

              linkAjaxCallsMap[ response.field_trials_sourced[i][0] ] = studyGermplasmXhr(response.field_trials_sourced[i][0]);
              nodeAjaxCallsMap[response.field_trials_sourced[i][0]] = brapiAjax('/brapi/v2/studies/'+response.field_trials_sourced[i][0]);

              nodeMap[response.field_trials_sourced[i][0]] = {"name":response.field_trials_sourced[i][0], "id":response.field_trials_sourced[i][1], "trialType":null};
              primitiveLinks.push({"source":nodeMap[base_node_id], "target": nodeMap[response.field_trials_sourced[i][0]], "value":1});
            }

          }//end of construct_primitive_graph

          function receive_JSONs(base_node_id){

            var reportSankeyError = function(err){
              console.error("Could not build the field trial linkage diagram.", err);
              jQuery('#field_trial_to_field_trial_html').append(
                '<p class="text-danger">Unable to load the linkage diagram (see the browser console for details).</p>');
            };

            //Wait for all study JSONs to be collected, then construct the nodes with them.
            Promise.all(Object.values(nodeAjaxCallsMap)).then((values1) => {

              for (var i = 0; i < values1.length; i++){
                var study = values1[i] && values1[i].result;
                if (!study || !study.studyDbId || !nodeMap[study.studyDbId]) continue;
                nodeMap[study.studyDbId].trialType = study.studyType;
                nodeMap[study.studyDbId].id = study.studyName;
              }

              nodes = Object.values(nodeMap);

              //Now that the nodes are constructed, wait for all the germplasm JSONs to be collected, then construct the links
              return Promise.all(Object.values(linkAjaxCallsMap)).then((values2) => {

                //For each trial-to-trial edge, draw one sub-link per accession shared
                //between the edge's two endpoints (its source trial and its target trial).
                for (var i = 0; i < primitiveLinks.length; i++){

                  var sourceGermplasm = germplasmNames(linkAjaxCallsMap[primitiveLinks[i].source.name]);
                  var targetGermplasm = new Set(germplasmNames(linkAjaxCallsMap[primitiveLinks[i].target.name]));

                  for (var j = 0; j < sourceGermplasm.length; j++){
                    if (targetGermplasm.has(sourceGermplasm[j])){
                      linkMap[primitiveLinks[i].source.name+","+primitiveLinks[i].target.name+","+sourceGermplasm[j]] = {"source": primitiveLinks[i].source, "target":primitiveLinks[i].target, "value":1, "name": sourceGermplasm[j]};
                    }
                  }
                }

                console.log("linkMap:");
                console.log(linkMap);

                links = Object.values(linkMap);

                data={nodes, links};
                console.log("Here is the sankey data: ");
                console.log(data);

                sankey = d3sankey()
                  .size([width-100, height-100])
                  .nodeId(d => d.id)
                  .nodeWidth(20)
                  .nodePadding(10)
                  .nodeAlign(sankeyCenter);
                var graph = sankey(data);

                svglinks = svg
                  .append("g")
                  .classed("links", true)
                  .selectAll("path")
                  .data(graph.links)
                  .enter()
                  .append("path")
                  .classed("link", true)
                  .attr("d", sankeyLinkHorizontal())
                  .attr("fill", "none")
                  .attr("stroke", "#D3D3D3")
                  .attr("stroke-width", d => d.width)
                  .attr("marker-end", "url(#triangle)")
                  .attr("stoke-opacity", 0.3)
                  .on("mouseover", function(d){
                    d3.select(this).attr("stroke", "#808080");
                  })
                  .on("mouseout", function(d){
                    d3.select(this).attr("stroke", "#D3D3D3");
                  });


                  svgnodes = svg
                   .append("g")
                   .classed("nodes", true)
                   .selectAll("rect")
                   .data(graph.nodes)
                   .enter()
                   .append("rect")
                   .classed("node", true)
                   .attr("x", d => d.x0)
                   .attr("y", d => d.y0)
                   .attr("width", d => d.x1 - d.x0)
                   .attr("height", d => d.y1 - d.y0)
                   .attr("fill", "#add8e6")
                   .attr("opacity", 0.8)
                   .on("mouseover", function(d){
                     d3.select(this).attr("fill", "#6699cc");
                     tooltip_region.selectAll("*").remove();
                     tooltip_region.attr("transform", "translate("+ ((d.x1+d.x0)/2 - 5 - 110) +", "+ (d.y0 - 5 - 70) +")" );
                     var tooltip = tooltip_region
                       .append("path")
                       .attr('fill', 'white')
                       .attr('stroke', 'black')
                       .attr('stroke-width', '1.5');
                     var pathString = "M "+(  115  )+" "+( 75 )+" l 10 -10 h 90 c 10 0 10 0 10 -10 v -40 c 0 -10 0 -10 -10 -10 h -200 c -10 0 -10 0 -10 10 v 40 c 0 10 0 10 10 10 h 90 l 10 10 z";
                     tooltip.attr("d", pathString);
                     var tooltip_text1 = tooltip_region.append("text")
                     .attr("text-anchor", "middle")
                     .attr("transform", "translate(110,20)");
                     tooltip_text1.text("Trial: "+d.id);
                     var tooltip_text2 = tooltip_region.append("text")
                     .attr("text-anchor", "middle")
                     .attr("transform", "translate(110,40)");
                     tooltip_text2.text("Trial Type: "+d.trialType);
                   })
                   .on("mouseout", function(d){
                     d3.select(this).attr("fill", "#add8e6");
                     tooltip_region.selectAll("*").remove();
                   })
                   .on("click", function(d){
                     jQuery.ajax({
                       url : '/ajax/breeders/trial/'+d.name+'/field_trial_from_field_trial',
                       success: function(res){

                         jQuery("#sankeycanvas").empty();

                         nodeMap = {}; //Hash of nodes, runs parallel to array of nodes
                         nodes = [];
                         primitiveLinks = [];
                         linkMap = {};
                         links = []; //List to be used for all connections at the accession level
                         linkAjaxCallsMap = {}; // Map of ajax calls for links
                         nodeAjaxCallsMap = {}; // Map of ajax calls for nodes

                         construct_primitive_graph(d.name, d.id, res);

                         receive_JSONs(d.name);

                       }
                     });
                   })
                   .on("dblclick",function(d){
                     if (d.name == trial_id){

                     } else {
                       window.open("/breeders/trial/"+d.name);
                     }
                   });


                svglabels = svg
                  .append("g")
                  .classed("text", true)
                  .selectAll("text")
                  .data(graph.links)
                  .enter()
                  .append("text")
                  .classed("link", true)
                  .attr("x", d => d.source.x1 + 5)
                  .attr("y", d => d.y0 + 5)
                  .text(d => d.name);


                //These are placed here for the drawing order. This ensures that they are on top of other DOM elements, so I don't have to do any extra footwork to bring them to the foreground
                var tooltip_region = svg.append("g").attr("id", "tooltip_region_g");


              });
            }).catch(reportSankeyError);
          }//End of receive_JSONs

        },
        error: function(r){
          jQuery("#working_modal").modal("hide");
          alert("Error retrieving field trial to field trial linkage.");
        }
      });
}
