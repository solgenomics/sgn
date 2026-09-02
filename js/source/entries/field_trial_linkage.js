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

            //Set margins and set up svg area. Wide left/right margins leave room for the
            //trial-name labels that sit outside the first and last columns.
            var margin = {top: 50, right: 150, bottom: 30, left: 150};
            var width = 620;
            var height = 320;
            var sankeyWidth = width;
            var sankeyHeight = height;

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

                //One link per trial-to-trial edge, its value (and rendered width) is the
                //number of accessions shared between the edge's source and target trials.
                for (var i = 0; i < primitiveLinks.length; i++){

                  var src = primitiveLinks[i].source;
                  var tgt = primitiveLinks[i].target;

                  var sourceGermplasm = germplasmNames(linkAjaxCallsMap[src.name]);
                  var targetGermplasm = new Set(germplasmNames(linkAjaxCallsMap[tgt.name]));
                  var shared = sourceGermplasm.filter(function(n){ return targetGermplasm.has(n); });
                  if (shared.length === 0) continue; //no shared accessions -> no link, as before

                  linkMap[src.name+","+tgt.name] = {
                    "source": src,
                    "target": tgt,
                    "value": shared.length,
                    "names": shared.sort()
                  };
                }

                links = Object.values(linkMap);

                data={nodes, links};

                sankey = d3sankey()
                  .size([sankeyWidth, sankeyHeight])
                  .nodeId(d => d.id)
                  .nodeWidth(18)
                  .nodePadding(22)
                  .nodeAlign(sankeyCenter);
                var graph = sankey(data);

                //d3-sankey uses one scale factor per diagram, fixed by the busiest column,
                //so a link/node carrying only a few accessions can shrink below a usable
                //size next to a link carrying hundreds. Floor both so a small link stays a
                //visible, clickable ribbon; anything above the floor is still proportional.
                var MIN_LINK_PX = 6;
                var MIN_NODE_PX = 16;
                var nodeHeight = d => Math.max(MIN_NODE_PX, d.y1 - d.y0);
                var nodeTop = d => (d.y0 + d.y1) / 2 - nodeHeight(d) / 2;

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
                  .attr("stroke", "#a6bddb")
                  .attr("stroke-opacity", 0.6)
                  .attr("stroke-width", d => Math.max(MIN_LINK_PX, d.width))
                  .on("mouseover", function(d){
                    d3.select(this).attr("stroke", "#3182bd").attr("stroke-opacity", 0.9);
                    show_link_tooltip(d);
                  })
                  .on("mouseout", function(d){
                    d3.select(this).attr("stroke", "#a6bddb").attr("stroke-opacity", 0.6);
                    tooltip_region.selectAll("*").remove();
                  });

                //Shared white callout used for both the link and node hovers. Anchored at
                //(leftX, centerY) in plot coordinates and clamped to stay inside the
                //drawing so it never gets cut off at an edge.
                var TOOLTIP_WIDTH = 220;
                function draw_tooltip(leftX, centerY, lines){
                  tooltip_region.selectAll("*").remove();

                  var lineHeight = 15;
                  var boxHeight = lines.length * lineHeight + 12;
                  var x = Math.max(0, Math.min(leftX, sankeyWidth - TOOLTIP_WIDTH));
                  var y = Math.max(0, Math.min(centerY - boxHeight / 2, sankeyHeight - boxHeight));

                  tooltip_region.attr("transform", "translate(" + x + "," + y + ")");
                  tooltip_region.append("rect")
                    .attr("width", TOOLTIP_WIDTH)
                    .attr("height", boxHeight)
                    .attr("rx", 4)
                    .attr("fill", "white")
                    .attr("stroke", "#333")
                    .attr("stroke-width", 1);
                  lines.forEach(function(line, i){
                    tooltip_region.append("text")
                      .attr("x", 10)
                      .attr("y", 17 + i * lineHeight)
                      .style("font-size", "11px")
                      .style("font-weight", i === 0 ? "bold" : "normal")
                      .text(line);
                  });
                }

                //Lists the accessions shared across a trial-to-trial link, capped so a
                //big overlap does not blow up the tooltip.
                var LINK_TOOLTIP_MAX_NAMES = 15;
                function show_link_tooltip(d){
                  var shown = d.names.slice(0, LINK_TOOLTIP_MAX_NAMES);
                  var header = d.value + " shared accession" + (d.value === 1 ? "" : "s");
                  var lines = [header].concat(shown);
                  if (d.names.length > shown.length){
                    lines.push("…and " + (d.names.length - shown.length) + " more");
                  }
                  draw_tooltip((d.source.x1 + d.target.x0) / 2 + 10, (d.y0 + d.y1) / 2, lines);
                }

                function show_node_tooltip(d){
                  var lines = ["Trial: " + d.id, "Trial Type: " + (d.trialType || "—")];
                  var leftX = d.x1 + 12;
                  if (leftX + TOOLTIP_WIDTH > sankeyWidth) leftX = d.x0 - 12 - TOOLTIP_WIDTH;
                  draw_tooltip(leftX, (d.y0 + d.y1) / 2, lines);
                }


                  svgnodes = svg
                   .append("g")
                   .classed("nodes", true)
                   .selectAll("rect")
                   .data(graph.nodes)
                   .enter()
                   .append("rect")
                   .classed("node", true)
                   .attr("x", d => d.x0)
                   .attr("y", nodeTop)
                   .attr("width", d => d.x1 - d.x0)
                   .attr("height", nodeHeight)
                   .attr("fill", "#6baed6")
                   .attr("opacity", 1)
                   .on("mouseover", function(d){
                     d3.select(this).attr("fill", "#3182bd");
                     show_node_tooltip(d);
                   })
                   .on("mouseout", function(d){
                     d3.select(this).attr("fill", "#6baed6");
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


                //Persistent trial-name labels, kept clear of the link ribbons: first column
                //labelled to its left, last column to its right, any middle column above the
                //node. The current trial is bold so the user keeps their bearing after
                //clicking through to a neighbor.
                var xExtent = d3.extent(graph.nodes, function(d){ return d.x0; });
                var labelSide = function(d){
                  if (d.x0 <= xExtent[0]) return "left";
                  if (d.x0 >= xExtent[1]) return "right";
                  return "above";
                };

                svglabels = svg
                  .append("g")
                  .classed("node-labels", true)
                  .selectAll("text")
                  .data(graph.nodes)
                  .enter()
                  .append("text")
                  .classed("node-label", true)
                  .attr("x", d => labelSide(d) === "left" ? d.x0 - 8
                                : labelSide(d) === "right" ? d.x1 + 8
                                : (d.x0 + d.x1) / 2)
                  .attr("y", d => labelSide(d) === "above" ? nodeTop(d) - 8 : (d.y0 + d.y1) / 2)
                  .attr("dy", d => labelSide(d) === "above" ? 0 : "0.35em")
                  .attr("text-anchor", d => labelSide(d) === "left" ? "end"
                                          : labelSide(d) === "right" ? "start"
                                          : "middle")
                  .style("font-size", "12px")
                  .style("font-weight", d => (String(d.name) === String(trial_id) ? "bold" : "normal"))
                  .text(d => d.id);

                //Shared-accession count on each link, with a white halo so it stays legible
                //where it crosses a ribbon.
                svg
                  .append("g")
                  .classed("link-counts", true)
                  .selectAll("text")
                  .data(graph.links)
                  .enter()
                  .append("text")
                  .attr("x", d => (d.source.x1 + d.target.x0) / 2)
                  .attr("y", d => (d.y0 + d.y1) / 2 - 4)
                  .attr("text-anchor", "middle")
                  .style("font-size", "11px")
                  .style("paint-order", "stroke")
                  .attr("stroke", "white")
                  .attr("stroke-width", 3)
                  .attr("fill", "#555")
                  .text(d => d.value);


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
