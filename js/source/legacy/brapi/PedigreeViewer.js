(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
  typeof define === 'function' && define.amd ? define(factory) :
  (global.PedigreeViewer = factory());
}(this, (function () { 'use strict';

function PedigreeViewer(server,auth,version,urlFunc){
        var pdgv = {};
        var brapijs = BrAPI(server,version,auth);
        var root = null;
        var access_token = null;
        var loaded_nodes = {};
        var myTree = null;
        var locationSelector = null;
        var pedigrees =null;

        var load_markers = function(){return []};
        var marker_data = {};
        var getTextSize = TextSizer("14","sans-serif");
        
        var tree_node_padding_default = 220;
        var tree_node_padding = tree_node_padding_default;
        
        var tree_level_padding_default = 200;
        var tree_level_padding = tree_level_padding_default;
        
        urlFunc = urlFunc!=undefined?urlFunc:function(){return null};
                
        pdgv.newTree = function(stock_id,callback){
            root = stock_id;
            loaded_nodes = {};
            var all_nodes = [];
            var levels =0;
            var number_ancestors;
            if(version=='v1.3' || version=='v2.0'){ number_ancestors =3; }
            else {number_ancestors = 3; }

            var germplasm = brapijs.data([stock_id]);
            pedigrees = germplasm.pedigree(function(d){return {'germplasmDbId':d,'pedigreeDepth':number_ancestors,'progenyDepth':number_ancestors}});

            load_node_and_all_ancestors([stock_id]);
            function load_node_and_all_ancestors(ids){
                load_nodes(ids, function(nodes){
                    if(!(version=='v1.3' || version=='v2.0')) nodes = nodes[0];
                    [].push.apply(all_nodes,nodes);
                    var mothers = nodes.map(function(d){return d.mother_id});
                    var fathers = nodes.map(function(d){return d.father_id});
                  
                    var parents = mothers.concat(fathers).filter(function(d, index, self){
                        return d!==undefined &&
                               d!==null &&
                               loaded_nodes[d]===undefined &&
                               self.indexOf(d) === index;
                    });
                    if (parents.length>0 && levels < number_ancestors){
                        load_node_and_all_ancestors(parents);
                        levels++;
                    }
                    else {
                        createNewTree(all_nodes);
                        callback.call(pdgv);
                    }
                });
            }
        };
        
        pdgv.drawViewer = function(loc,draw_width,draw_height){
            locationSelector = loc;
            drawTree(undefined,draw_width,draw_height);
        };
        
        pdgv.data = function(accessor){
            tree_node_padding = tree_node_padding_default;
            tree_level_padding = tree_level_padding_default;
            marker_data = {};
            marker_data.__widths = [0];
            var widths = marker_data.__widths;
            load_markers = function(germplasmID){
                if(marker_data[germplasmID]) return Promise.resolve(marker_data[germplasmID]);
                var marker_val = Promise.resolve(accessor(germplasmID));
                marker_val.then((md)=>{
                    marker_data[germplasmID] = md;
                    md.forEach(mv=>{
                        widths[0] = Math.max(widths[0]||0,getTextSize(mv.name)+10);
                        mv.values.forEach((v,i)=>{
                            if(v.value.length<2){
                                widths[i+1] = Math.max(widths[i+1]||0,22);
                                return 
                            }
                            else{
                                widths[i+1] = Math.max(widths[i+1]||0,getTextSize(v.value)+10);
                            }
                        });
                        if(widths[0]){
                            var p = tree_node_padding_default+15;
                            p += d3.sum(widths);
                            p += (widths.length-1)*(5);
                            if(p>tree_node_padding){
                                tree_node_padding = p;
                                if(myTree) myTree.nodePadding(tree_node_padding);
                            }
                        }      
                    });
                    if(md.length){
                        var h = tree_level_padding_default+md.length*25;
                        if(h>tree_level_padding){
                            tree_level_padding = h;
                            if(myTree) myTree.levelWidth(tree_level_padding);
                        }
                    }    
                    drawTree(d3.transition().duration(700));  
                });
                return marker_val;
            };
            Object.keys(loaded_nodes).forEach(id=>{
                load_markers(id);
            });
        };
        
        function createNewTree(start_nodes) {  
            myTree = d3.pedigreeTree()
              .levelWidth(tree_level_padding)
              .levelMidpoint(50)
              .nodePadding(tree_node_padding)
              .nodeWidth(10)
              .linkPadding(25)
              .vertical(true)
              .parentsOrdered(true)
              .parents(function(node){
                return [loaded_nodes[node.mother_id],loaded_nodes[node.father_id]].filter(Boolean);
              })
              .id(function(node){
                return node.id;
              })
              .groupChildless(true)
              .iterations(50)
              .data(start_nodes)
              .excludeFromGrouping([root]);
        }
        
        function load_nodes(stock_ids,callback){

          if(version=='v1.3' || version=='v2.0'){

            var germplasm = brapijs.data(stock_ids);
            var pedigrees1 = germplasm.germplasm_pedigree(function(d){return {'germplasmDbId':d,'pageSize':1000}});
            var progenies = germplasm.germplasm_progeny(function(d){return {'germplasmDbId':d, 'pageSize':1000}},"map");
            pedigrees1.join(progenies,germplasm).filter(function(ped_pro_germId){
                if (ped_pro_germId[0]===null || ped_pro_germId[1]===null) {
                    console.log("Failed to load progeny or pedigree for "+ped_pro_germId[2]);
                    return false;
                }
                return true;
            }).map(function(ped_pro_germId){
                var mother = null, 
                    father = null;
                
                if(version=='v1.3'){
                    if(ped_pro_germId[0].parent1Type=="FEMALE"){
                        mother = ped_pro_germId[0].parent1DbId;
                    }
                    if(ped_pro_germId[0].parent1Type=="MALE"){
                        father = ped_pro_germId[0].parent1DbId;
                    }
                    if(ped_pro_germId[0].parent2Type=="FEMALE"){
                        mother = ped_pro_germId[0].parent2DbId;
                    }
                    if(ped_pro_germId[0].parent2Type=="MALE"){
                        father = ped_pro_germId[0].parent2DbId;
                    }
                    return {
                        'id':ped_pro_germId[2],
                        'mother_id':mother,
                        'father_id':father,
                        'name':ped_pro_germId[1].defaultDisplayName,
                        'children':ped_pro_germId[1].progeny.filter(Boolean).map(function(d){
                            return d.germplasmDbId;
                        })
                    };
                } else {
                    var i = ped_pro_germId[0].parents.map(function(e) { return e.parentType; }).indexOf('FEMALE');
                    var j = ped_pro_germId[0].parents.map(function(e) { return e.parentType; }).indexOf('MALE');

                    if(i>=0) mother = ped_pro_germId[0].parents[i].germplasmDbId;
                    if(j>=0) father = ped_pro_germId[0].parents[j].germplasmDbId;

                    return {
                        'id':ped_pro_germId[2],
                        'mother_id':mother,
                        'father_id':father,
                        'name':ped_pro_germId[1].germplasmName,
                        'children':ped_pro_germId[1].progeny.filter(Boolean).map(function(d){
                            return d.germplasmDbId;
                        })
                    };
                }
            }).each(function(node){
                loaded_nodes[node.id] = node;
                load_markers(node.id);
            }).all(function(nodes){
                callback(nodes);
            });
            
          } else {
            pedigrees.map(function(ped_pro_germId){
              return ped_pro_germId.data;

            }).map(function(ped_pro_germId){
                
                var nodes = stock_ids.map(stock_id => {

                    var mother = null, 
                        father = null;

                    var x = ped_pro_germId.findIndex(x => x.germplasmDbId === stock_id);
                    
                    if(x<0) { return null } 

                    var i = ped_pro_germId[x].parents.map(function(e) { return e.parentType; }).indexOf('FEMALE');
                    var j = ped_pro_germId[x].parents.map(function(e) { return e.parentType; }).indexOf('MALE');

                    if(i>=0) mother = ped_pro_germId[x].parents[i].germplasmDbId;
                    if(j>=0) father = ped_pro_germId[x].parents[j].germplasmDbId;
                  
                    var node = {
                        'id':ped_pro_germId[x].germplasmDbId,
                        'mother_id':mother,
                        'father_id':father,
                        'name': ped_pro_germId[x].germplasmName,
                        'children':ped_pro_germId[x].progeny.filter(Boolean).map(function(d){
                            return d.germplasmDbId;
                        })
                    };

                    loaded_nodes[node.id] = node;
                    load_markers(node.id);
                    return node;  

                } );
  
                return nodes.filter(v => v != null);  

            }).all(function(nodes){
              callback(nodes);
            });
          }
        }
        
        function drawTree(trans,draw_width,draw_height){
            console.log("redraw");
            if(!myTree) return;
            var layout = myTree();
                        
            //set default change-transtion to no duration
            trans = trans || d3.transition().duration(0);
            
            //make wrapper(pdg)
            var wrap = d3.select(locationSelector);
            var canv = wrap.select("svg.pedigreeViewer");
            if (canv.empty()){
                canv = wrap.append("svg").classed("pedigreeViewer",true)
                    .attr("width",draw_width)
                    .attr("height",draw_height)
                    .attr("viewbox","0 0 "+draw_width+" "+draw_height);
            }
            if(!canv.node()) return;
            var cbbox = canv.node().getBoundingClientRect();
            var canvw = cbbox.width, 
                canvh = cbbox.height;
            var pdg = canv.select('.pedigreeTree');
            if (pdg.empty()){
              pdg = canv.append('g').classed('pedigreeTree',true);
            }
          
            //make background
            var bg = pdg.select('.pdg-bg');
            if (bg.empty()){
              bg = pdg.append('rect')
                .classed('pdg-bg',true)
                .attr("x",-canvw*500)
                .attr("y",-canvh*500)
                .attr('width',canvw*1000)
                .attr('height',canvh*1000)
                .attr('fill',"white")
                .attr('opacity',"0.00001")
                .attr('stroke','none');
            }
            
            //make scaled content/zoom groups
            var padding = 50;
            var pdgtree_width = d3.max([500,layout.x[1]-layout.x[0]]);
            var pdgtree_height = d3.max([500,layout.y[1]-layout.y[0]]);
            var centeringx = d3.max([0,(500 - (layout.x[1]-layout.x[0]))/2]);
            var centeringy = d3.max([0,(500 - (layout.y[1]-layout.y[0]))/2]);
            var scale = get_fit_scale(canvw,canvh,pdgtree_width,pdgtree_height,padding);
            var offsetx = (canvw-(pdgtree_width)*scale)/2 + centeringx*scale;
            var offsety = (canvh-(pdgtree_height)*scale)/2 + centeringy*scale;
            
            var content = pdg.select('.pdg-content');
            if (content.empty()){
              var zoom = d3.zoom();
              var zoom_group = pdg.append('g').classed('pdg-zoom',true).data([zoom]);
              
              content = zoom_group.append('g').classed('pdg-content',true);
              content.datum({'zoom':zoom});
              zoom.on("zoom",function(){
                zoom_group.attr('transform',d3.event.transform);
              });
              bg.style("cursor", "all-scroll").call(zoom).call(zoom.transform, d3.zoomIdentity);
              bg.on("dblclick.zoom",function(){
                zoom.transform(bg.transition(),d3.zoomIdentity);
                return false;
              });
              
              content.attr('transform',
                  d3.zoomIdentity
                    .translate(offsetx,offsety)
                    .scale(scale)
                );
            }
            content.datum().zoom.scaleExtent([0.5,d3.max([pdgtree_height,pdgtree_width])/200]);
            content.transition(trans)
              .attr('transform',
                d3.zoomIdentity
                  .translate(offsetx,offsety)
                  .scale(scale)
              );
            
            
            //set up draw layers
            var linkLayer = content.select('.link-layer');
            if(linkLayer.empty()){
                linkLayer = content.append('g').classed('link-layer',true);
            }
            var nodeLayer = content.select('.node-layer');
            if(nodeLayer.empty()){
                nodeLayer = content.append('g').classed('node-layer',true);
            }
            
            //link curve generators
            var stepline = d3.line().curve(d3.curveStepAfter);
            var curveline = d3.line().curve(d3.curveBasis);
            var build_curve = function(d){
              if (d.type=="parent->mid") return curveline(d.path);
              if (d.type=="mid->child") return stepline(d.path);
            };
            
            //draw nodes
            var nodes = nodeLayer.selectAll('.node')
              .data(layout.nodes,function(d){return d.id;});
            var newNodes = nodes.enter().append('g')
              .classed('node',true)
              .attr('transform',function(d){
                var begin = d;
                if(d3.event && d3.event.type=="click"){
                  begin = d3.select(d3.event.target).datum();
                }
                return 'translate('+begin.x+','+begin.y+')'
              });
            var nodeNodes = newNodes.filter(function(d){
                return d.type=="node";
            });
            var groupNodes = newNodes.filter(function(d){
                return d.type=="node-group";
            });
            //draw node group expanders
            groupNodes.append("circle")
              .style("cursor","pointer")
              .attr("fill","purple")
              .attr("stroke","purple")
              .attr("cy",0)
              .attr("r",10);
            groupNodes.append('text')
              .style("cursor","pointer")
              .attr('y',6.5)
              .attr("font-size","14px")
              .attr("font-weight","bold")
              .attr('text-anchor',"middle")
              .attr('class', 'glyphicon')
              .html("&#xe092;")
              .attr('fill',"white");
            //create expander handles on nodes
            var expanders = nodeNodes.append('g').classed("expanders",true);
            var child_expander = expanders.append("g").classed("child-expander",true);
            child_expander.append("path")
              .attr("fill","none")
              .attr("stroke","purple")
              .attr("stroke-width",4)
              .attr("d",curveline([[0,20],[0,40]]));
            child_expander.append("circle")
              .style("cursor","pointer")
              .attr("fill","purple")
              .attr("stroke","purple")
              .attr("cy",45)
              .attr("r",10);
            child_expander.append('text')
              .style("cursor","pointer")
              .attr('y',52)
              .attr('x',-0.5)
              .attr("font-size","14px")
              .attr("font-weight","bold")
              .attr('text-anchor',"middle")
              .attr('class', 'glyphicon')
              .html("&#xe094;")
              .attr('fill',"white");
            child_expander.on("click",function(d){
              d3.select(this).on('click',null);
              var end_blink = load_blink(d3.select(this).select("circle").node());
              var to_load = d.value.children.filter(Boolean).map(String);
              load_nodes(to_load,function(nodes){
                  end_blink();
                  if(!(version=='v1.3' || version=='v2.0')) nodes = nodes[0];
                  layout.pdgtree.add(nodes);
                  drawTree(d3.transition().duration(700));
              });
            });
            var parent_expander = expanders.append("g").classed("parent-expander",true);
            parent_expander.append("path")
              .attr("fill","none")
              .attr("stroke","purple")
              .attr("stroke-width",4)
              .attr("d",curveline([[0,0],[0,-40]]));
            parent_expander.append("circle")
              .style("cursor","pointer")
              .attr("fill","purple")
              .attr("stroke","purple")
              .attr("cy",-45)
              .attr("r",10);
            parent_expander.append('text')
              .style("cursor","pointer")
              .attr('y',-39)
              .attr('x',-0.5)
              .attr("font-size","14px")
              .attr("font-weight","bold")
              .attr('text-anchor',"middle")
              .attr('class', 'glyphicon')
              .html("&#xe093;")
              .attr('fill',"white");
            parent_expander.on("click",function(d){
              d3.select(this).on('click',null);
              var end_blink = load_blink(d3.select(this).select("circle").node());
              var to_load = [d.value.mother_id,d.value.father_id].filter(Boolean).map(String);
              load_nodes(to_load,function(nodes){
                  end_blink();
                  if(!(version=='v1.3' || version=='v2.0')) nodes = nodes[0];
                  layout.pdgtree.add(nodes);
                  drawTree(d3.transition().duration(700));
              });
            });
            nodeNodes.append('rect').classed("node-name-highlight",true)
              .attr('fill',function(d){
                  return d.id==root?"pink":"none";
              })
              .attr('stroke-width',0)
              .attr("width",220)
              .attr("height",30)
              .attr("y",-5)
              .attr("rx",15)
              .attr("ry",15)
              .attr("x",-105);
            nodeNodes.append('rect').classed("node-name-wrapper",true)
              .attr('fill',"white")
              .attr('stroke',"grey")
              .attr('stroke-width',2)
              .attr("width",200)
              .attr("height",20)
              .attr("y",0)
              .attr("rx",10)
              .attr("ry",10)
              .attr("x",-100);
              var nodeUrlLinks = nodeNodes.filter(function(d){
                  var url = urlFunc(d.id);
                  if (url!==null){
                    d.url = url;
                    return true;
                  }
                  return false;
                })
                .append('a')
                .attr('href',function(d){
                  return urlFunc(d.id);
                })
                .attr('target','_blank')
                .append('text').classed('node-name-text',true)
                .attr('y',15)
                .attr('text-anchor',"middle")
                .text(function(d){
                  return d.value.name;
                })
                .attr('fill',"black");
              nodeNodes.filter(function(d){return d.url===undefined;})
                .append('text').classed('node-name-text',true)
                .attr('y',15)
                .attr('text-anchor',"middle")
                .text(function(d){
                  return d.value.name;
                })
                .attr('fill',"black");
            
            //create marker_groups on nodes
            nodeNodes.append('g').classed("marker_group",true)
                .append("rect")
                .classed("marker-connector",true)
                .attr('stroke',"none")
                .attr('fill',"gray")
                .attr("y",9)
                .attr("x",0)
                .attr("height",2)
                .attr("width",20);
                
            //set node width to text width
            nodeNodes.each(function(d){
                var nn = d3.select(this);
                var ctl = nn.select('.node-name-text').node().getComputedTextLength();
                var w = ctl+20;
                nn.select('.node-name-wrapper')
                    .attr("width",w)
                    .attr("x",-w/2);
                nn.select('.node-name-highlight')
                    .attr("width",w+10)
                    .attr("x",-(w+10)/2);
                nn.select('.marker_group').attr("transform",`translate(${w/2},0)`);
            });
            
            
            
            var allNodes = newNodes.merge(nodes);
            
            //add markers
            var marker_groups = allNodes.select(".marker_group");
            marker_groups.select(".marker-connector")
                .attr("opacity",d=>(marker_data[d.id]||[]).length>0?1:0);
            var mks = marker_groups.selectAll(".marker").data(d=>marker_data[d.id]||[]);
            mks.exit().remove();
            var newmks = mks.enter().append("g").classed("marker",true);
            newmks.append("g").classed("marker-vals",true);
            newmks.append("rect")
                .classed("marker-bg",true)
                .attr('fill',"white")
                .attr('stroke',"gray")
                .attr('stroke-width',2)
                .attr("height",20)
                .attr("y",0)
                .attr("rx",10)
                .attr("ry",10)
                .attr("x",0);
            newmks.append("text")
                .attr("fill","black")
                .attr("stroke","none")
                .attr("text-anchor","middle")
                .attr("alignment-baseline","middle")
                .attr("y",10);
            var allmks = newmks.merge(mks);
            allmks.attr("transform",(d,i)=>`translate(15,${i*25})`);
            console.log(marker_data);
            allmks.select(".marker-bg").attr("width",d=>marker_data.__widths[0]);
            allmks.select("text")
                .attr("x",d=>marker_data.__widths[0]/2)
                .text((d)=>d.name);
            var vals = allmks.select(".marker-vals").selectAll(".marker-val").data(d=>d.values);
            vals.exit().remove();
            var newvals = vals.enter().append("g").classed("marker-val",true);
            newvals.append("rect")
                .attr("rx",11)
                .attr("ry",11)
                .attr("height",22)
                .attr("y",-1)
                .attr("x",0)
                .attr("stroke","none");
            newvals.append("text")
                .attr("fill","black")
                .attr("stroke","none")
                .attr("text-anchor","middle")
                .attr("alignment-baseline","middle")
                .attr("y",11);
            var allvals = newvals.merge(vals);
            allvals.attr("transform",(d,i)=>{
                return `translate(${d3.sum(marker_data.__widths.slice(0,i+1))+(i+1)*5},0)`
            });
            allvals.select("rect")
                .attr("width",(d,i)=>marker_data.__widths[i+1])
                .attr("fill",d=>d.color);
            allvals.select("text")
                .attr("x",(d,i)=>marker_data.__widths[i+1]/2)
                .text(d=>d.value);
            
            //remove expander handles for nodes without unloaded relatives.
            allNodes.each(function(d){
                if (d.type=="node"){
                    var parents_unloaded = [d.value.mother_id,d.value.father_id]
                        .filter(function(node_id){
                            return !!node_id && !loaded_nodes.hasOwnProperty(node_id);
                        });
                    var children_unloaded = d.value.children
                        .filter(function(node_id){
                            return !!node_id && !loaded_nodes.hasOwnProperty(node_id);
                        });
                    if (parents_unloaded.length<1){
                        d3.select(this).selectAll(".parent-expander").remove();
                    }
                    if (children_unloaded.length<1){
                        d3.select(this).selectAll(".child-expander").remove();
                    }
                }
            });
            allNodes.transition(trans).attr('transform',function(d){
              return 'translate('+d.x+','+d.y+')'
            });
            allNodes.filter(function(d){return d.type=="node-group"})
              .style("cursor", "pointer")
              .on("click",function(d){
                layout.pdgtree.excludeFromGrouping(d.value.slice(0,10).map(function(d){return d.id;}));
                drawTree(d3.transition().duration(700).ease(d3.easeLinear));
            });
            var oldNodes = nodes.exit().remove();

            
            //link colors
            var link_color = function(d){
              if (d.type=="mid->child") return 'purple';
              if (d.type=="parent->mid"){
                //if its the first parent, red. Otherwise, blue.
                var representative = d.sinks[0].type=="node-group"?
                        d.sinks[0].value[0].value 
                        : d.sinks[0].value;
                if (representative.mother_id == d.source.id){
                    return "red";
                } 
                else {
                    return "blue";
                }
              }
              return 'gray';
            };
            
            //make links
            var links = linkLayer.selectAll('.link')
              .data(layout.links,function(d){return d.id;});
            var newLinks = links.enter().append('g')
              .classed('link',true);
            newLinks.append('path')
              .attr('d',function(d){
                var begin = (d.sink || d.source);
                if(d3.event && d3.event.type=="click"){
                  begin = d3.select(d3.event.target).datum();
                }
                return curveline([[begin.x,begin.y],[begin.x,begin.y],[begin.x,begin.y],[begin.x,begin.y]]);
              })
              .attr('fill','none')
              .attr('stroke',link_color)
              .attr('opacity',function(d){
                if (d.type=="parent->mid") return 0.7;
                return 0.999;
              })
              .attr('stroke-width',4);
            var allLinks = newLinks.merge(links);
            allLinks.transition(trans).select('path').attr('d',build_curve);
            var oldNodes = links.exit().remove();
        }
        
        return pdgv;
    }
    
    function load_blink(node){
        var stop = false;
        var original_fill = d3.select(node).style("fill");
        var original_sw = d3.select(node).style("stroke-width");
        function blink(){
            if (!stop) d3.select(node)
                .transition()
                .duration(300)
                .style("fill", "white")
                .style("stroke-width", "5")
                .transition()
                .duration(300)
                .style("fill", original_fill)
                .style("stroke-width", original_sw)
                .on("end", blink);
        }
        blink();
        return function(){
            stop = true;
        }
    }
      
    function get_fit_scale(w1,h1,w2,h2,pad){
        w1 -= pad*2;
        h1 -= pad*2;  
        if (w1/w2<h1/h2){
            return w1/w2;
        } else {
            return h1/h2;
        }
    }
    
    function TextSizer(fontSize, fontFace){
        var canvas = document.createElement('canvas');
        var context = canvas.getContext('2d');
        return function (text) {
            context.font = fontSize + 'px ' + fontFace;
            return context.measureText(text).width;
        };
    }

return PedigreeViewer;

})));
