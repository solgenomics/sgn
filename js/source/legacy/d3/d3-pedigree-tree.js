(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('d3-scale'), require('d3-collection'), require('d3-array')) :
  typeof define === 'function' && define.amd ? define(['exports', 'd3-scale', 'd3-collection', 'd3-array'], factory) :
  (factory((global.d3 = global.d3 || {}),global.d3,global.d3,global.d3));
}(this, function (exports,d3Scale,d3Collection,d3Array) { 'use strict';

  function d3PedigreeTree() {
    var data = [],
        excludeFromGrouping = {},
        groupChildless = false,
        id = function(d){
          return d.id;
        },
        iterations = 1,
        levelWidth = 100,
        levelMidpoint = 50,
        linkPadding = 10,
        minGroupSize = 3,
        nodePadding = 10, 
        nodeWidth = 0,
        parents = function(d){
          return d.parents;
        },
        parentsOrdered = true,
        value = function(d){
          return d;
        },
        vertical = false;
    
    
    function pdgtree(){
      //create working nodes from input data (we dont want to modify the input) 

      var node_list = _wrap_nodes(data);
      node_list.forEach(function(d){_setNodeLevels(d);});
      _setBestRootNodeLevels(node_list);

      //create intermediate nodes for intergenerational links
      var intermediates = {};
      for (var n = node_list.length-1; n > -1; n--) {
        var node = node_list[n];
        
        for (var i = node.children.length-1; i > -1; i--) {
          var child = node.children[i];
          
          // If the child is beyond the next level from the parent, insert link
          // intermediates on each layer between them.
          if (node.level<child.level-1){
            node.children.splice(i,1); // break parent->child relationship
            child.parents.splice(child.parents.indexOf(node),1); //break child->parent relationship
            
            //create and chain link intermediates
            var current = node;
            while (current.level<child.level-1){
              var next_level = current.level+1;
              //we want to use the same link intermediates for siblings!
              var intermediate_id = "LI::"+next_level+"::"+node.id+"->"+child.sib_group_id;
              if (!intermediates[intermediate_id]){
                intermediates[intermediate_id] = {
                  'type':'link-intermediate', 
                  'id':intermediate_id,
                  'sib_group_id':intermediate_id, 
                  'level':next_level,
                  'children':[], 
                  'parents':[current]
                };
                current.children.push(intermediates[intermediate_id]);
                node_list.push(intermediates[intermediate_id]);
              }
              current = intermediates[intermediate_id];
            }
            current.children.push(child);
            child.parents.push(current);
          }
        }
      }
      
      var levels = _getLevels(node_list);
      _sortTree(levels);
      
      var xrange = [0,levelWidth*(levels.length-1)+(nodeWidth)]
      var x = d3Scale.scaleLinear()
        .domain([0,levels.length-1+nodeWidth/levelWidth])
        .range(xrange);
        
      var yrange = [Number.POSITIVE_INFINITY,Number.NEGATIVE_INFINITY];
      levels.forEach(function(level,i){
        var level_x = x(i);
        level.forEach(function(node,j){
          if (node.sort_ypos < yrange[0]) yrange[0] = node.sort_ypos;
          if (node.sort_ypos > yrange[1]) yrange[1] = node.sort_ypos;
        });
      });
      var yoffset = yrange[0];
      yrange = [yrange[0]-yoffset,yrange[1]-yoffset];
      if (yrange[0]==Number.POSITIVE_INFINITY || isNaN(yrange[0])) yrange[0]=-nodePadding;
      if (yrange[1]==Number.NEGATIVE_INFINITY || isNaN(yrange[0])) yrange[1]= nodePadding;
      
      levels.forEach(function(level,i){
        var level_x = x(i);
        level.forEach(function(node,j){
          node.y = node.sort_ypos-yoffset;
          delete node.sort_ypos;
          node.x = level_x;
        });
      });
      
      //we dont want to return the temporary link-intermediates, so remove them
      node_list = [].concat.apply([], levels)
        .filter(function(node){
          return node.type!="link-intermediate";
        });
      
      //find position (average) for the sibling branchpoint
      var sibling_points = d3Collection.nest()
        .key(function(node){return node.sib_group_id})
        .entries(node_list).reduce(function(sibling_points,sib_group){
          var sibling_points_x = x(sib_group.values[0].level-(levelMidpoint/levelWidth))+(nodeWidth/2);
          var sibling_points_y = d3Array.mean(sib_group.values,function(n){return n.y});
          sibling_points[sib_group.key] = [sibling_points_x,sibling_points_y];
          return sibling_points;
        },{});
      
      //remove intergenerational link intermediates and make link paths
      var inner_link = _inner_link_layer(5,0.25,0.75);
      var links = d3Collection.values(node_list.reduce(function(links,node){
        for (var i = node.children.length-1; i > -1 ; i--) {
          var child = node.children[i];
          if (child.type == "link-intermediate"){
            node.children.splice(i,1);
            var curr = child;
            var last = node;
            var prepath = [];
            while (curr.type == "link-intermediate"){
              prepath = prepath.concat(
                inner_link(
                  last.x+nodeWidth,last.y,
                  x(curr.level-0.5)+(nodeWidth/2),curr.y,
                  curr.level
                )
              );
              last = curr;
              curr = curr.children[0];
            }
            last.children.forEach(function(end_child){
              node.children.push(end_child);
              end_child.parents.splice(end_child.parents.indexOf(last),1);
              end_child.parents.push(node);
              
              var path = prepath.concat(
                inner_link(
                  last.x+nodeWidth, last.y,
                  sibling_points[end_child.sib_group_id][0],
                  sibling_points[end_child.sib_group_id][1],
                  end_child.level
                )
              );
              path.push(sibling_points[end_child.sib_group_id].slice());
              parent_link_id = "LINK::"+node.id+"-->--"+end_child.sib_group_id;
              if (!links[parent_link_id]){
                links[parent_link_id] = {
                  'source':node,
                  'sinks':[end_child],
                  'type':'parent->mid',
                  'id':parent_link_id,
                  'path':path
                };
              } else {
                links[parent_link_id].sinks.push(end_child);
              }
              child_link_id = "LINK::parents-->--"+end_child.id;
              if(!links[child_link_id]){
                links[child_link_id] = {
                  'sources':[node],
                  'sink':end_child,
                  'type':'mid->child',
                  'id':child_link_id,
                  'path':[
                    sibling_points[end_child.sib_group_id].slice(),
                    [end_child.x,end_child.y]
                  ]
                };
              } else {
                links[child_link_id].sources.push(node);
              }
            });
          }
          else {
            var parent_link_id = "LINK::"+node.id+"-->--"+child.sib_group_id;
            if (!links[parent_link_id]){
              var path = inner_link(
                node.x+nodeWidth,node.y,
                sibling_points[child.sib_group_id][0],
                sibling_points[child.sib_group_id][1],
                node.level+1
              )
              links[parent_link_id] = {'source':node,'sinks':[child],'type':'parent->mid','id':parent_link_id,'path':path};
            } else {
              links[parent_link_id].sinks.push(child);
            }
            var child_link_id = "LINK::parents-->--"+child.id
            if (!links[child_link_id]){
              links[child_link_id] = {'sources':[node],'sink':child,'type':'mid->child','id':child_link_id,'path':[sibling_points[child.sib_group_id].slice(),[child.x,child.y]]};
            } else {
              links[child_link_id].sources.push(node);
            }
          }
        }
        return links;
      },{}));

      if(vertical){
        var tmp = xrange;
        xrange = yrange;
        yrange = tmp;
        links.forEach(function(link){
          link.path.forEach(function(ppoint){
            var tmp = ppoint[0];
            ppoint[0] = ppoint[1];
            ppoint[1] = tmp;
          });
        });
        node_list.forEach(function(node){
          var tmp = node.x;
          node.x = node.y;
          node.y = tmp;
        })
      }
        
      return {'nodes':node_list, 'links':links, 'x':xrange,'y':yrange, 'pdgtree':pdgtree}
    }
    pdgtree.add = function(arr){
      var added = {};
      data.forEach(function(d){
        added[id(d)] = true;
      });
      [].push.apply(data, arr.filter(function(d){
        return !added[id(d)];
      }));
      return pdgtree;
    };
    pdgtree.data = function(arr){
      data = arr;
      return pdgtree;
    };
    pdgtree.excludeFromGrouping = function(ids){
      ids.forEach(function(node_id){excludeFromGrouping[node_id] = true;});
      return pdgtree;
    };
    pdgtree.groupChildless = function(bool){
      groupChildless = bool;
      return pdgtree;
    };
    pdgtree.id = function(func){
      id=func;
      return pdgtree;
    };
    pdgtree.iterations = function(runs){
      iterations = runs;
      return pdgtree;
    };
    pdgtree.levelWidth = function(val){
      levelWidth = val;
      return pdgtree;
    };
    pdgtree.levelMidpoint = function(val){
      levelMidpoint = val;
      return pdgtree;
    };
    pdgtree.linkPadding = function(val){
      linkPadding = val;
      return pdgtree;
    };
    pdgtree.minGroupSize = function(val){
      minGroupSize = val;
      return pdgtree;
    };
    pdgtree.nodePadding = function(val){
      nodePadding = val;
      return pdgtree;
    };
    pdgtree.nodeWidth = function(val){
      nodeWidth = val;
      return pdgtree;
    };
    pdgtree.parents = function(func){
      parents=func;
      return pdgtree;
    };
    pdgtree.parentsOrdered = function(bool){
      parentsOrdered = bool;
      return pdgtree;
    };
    pdgtree.resetGroups = function(){
      excludeFromGrouping = {};
      return pdgtree;
    };
    pdgtree.value = function(func){
      value = func;
      return pdgtree;
    };
    pdgtree.vertical = function(bool){
      vertical = bool;
      return pdgtree;
    };
    
    
    function _array_sort(a,b){
      var diff_len = a.length!=b.length;
      var min_length = a.length<b.length?a.length:b.length;
      var longer = a.length>b.length?a:b;
      var i = 0;
      while (i < min_length && a[i] == b[i]){
        i+=1;
      }
      if (i==min_length){
        return diff_len?(longer==a?1:-1):0;
      }
      return d3Array.ascending(a[i],b[i]);
    }
    
    
    function _getLevels(nodes){
      var levels = [];
      nodes.forEach(function(n){
        if (!levels[n.level]) levels[n.level] = [];
        levels[n.level].push(n);
      });
      return levels;
    }
    
    
    function _inner_link_layer(linewidth,source_ratio,sink_ratio){
      var counts = {};
      return function(x1,y1,x2,y2,sink_level){
        // if(!counts.hasOwnProperty(""+sink_level)){
        //   counts[sink_level] = 0;
        // } else {
        //   counts[sink_level]+=1;
        // }
        //var offset_level = counts[sink_level];
        var offset_level = Math.abs((y2-y1) / nodePadding);
        //console.log(offset_level);
        var start = x2-(x2-x1)*(1-sink_ratio);
        var end = x1+(x2-x1)*(source_ratio);
        var width = (end-start);
        var mid = width/2 + start;
        var offset = (offset_level*linewidth);//*Math.pow(-1,offset_level%2));
        var pos = (offset%(width/2))+mid;
        return [
          [x1,y1],
          [pos,y1],
          [pos,y2],
          [x2,y2]
        ];
      }
    }
    
    
    function _setBestRootNodeLevels(nodes){
      nodes.filter(function(node){
        return node.parents.filter(Boolean).length==0;
      }).forEach(function(node){
        if(node.children.length>0){
          node.level = d3Array.min(node.children,function(child){
            return child.level-1;
          });
        }
        //console.log(node.level);
      });
    }
    
    
    function _setNodeLevels(node,set_level){
      if (!node.level) {
        node.level = (!set_level) ? 0 : set_level;
        node.children.forEach(function(child){
          _setNodeLevels(child,node.level+1)
        });
      } else if (set_level){
        if (set_level>node.level) {
          node.level = set_level;
          node.children.forEach(function(child){
            _setNodeLevels(child,node.level+1)
          });
        }
      }
    }
    
    
    function _sortTree(levels){
      //determine the max possible height
      var height  = d3Array.max(levels,function(level){
        return (level.length+1)*nodePadding;
      });
      
      //evenly distribute nodes in each level
      levels.forEach(function(level){
        level.forEach(function(node,i){
          node.sort_ypos = i/(level.length-1||0.5)*height;
        });
      });
      
      //sorting & layout loop (even when sorting is off, this runs once but does not sort)
      for (var run = 0; run < (iterations||1); run++){
        // only run sorting if sort is not off (0)
        if(iterations!=0){ 
          var sortlevel = function(level){
            level.forEach(function(node,i){
              var node_parents = node.parents.filter(Boolean);
              // assign each node a sort value which is the average of 
              // all immediate relative's sort values from the last round
              var new_sort_ypos = 0;
              for (var j = 0; j < node.children.length; j++) {
                new_sort_ypos+=node.children[j].sort_ypos;
              }
              for (var j = 0; j < node_parents.length; j++) {
                new_sort_ypos+=node_parents[j].sort_ypos;
              }
              if (new_sort_ypos!=0){
                new_sort_ypos = new_sort_ypos/(node.children.length+node_parents.length);
              }
              node.sort_ypos = new_sort_ypos;
            });
          };
          for (var m = levels.length-1; m > -1 ; m--) {
            sortlevel(levels[m])
          }
        }
        
        //group by sibling group and lay out the tree
        levels.forEach(function(level){
          // sort the nodes in each level by grouping them into their sibling groups
          // sorting them first by average sortval of the sib group
          // then sorting grouped nodes to the bottom
          // then sorting by their individual scores.
          var sib_group_scores = d3Collection.nest().key(function(node){return node.sib_group_id})
            .entries(level).reduce(function(scores,group){
              scores[group.key] = d3Array.mean(group.values,function(node){return node.sort_ypos});
              return scores;
            },{});
          level.sort(function(a,b){
            return _array_sort(
              [sib_group_scores[a.sib_group_id],a.sib_group_id,a.type=="node-group"?1:0,a.sort_ypos,a.id],
              [sib_group_scores[b.sib_group_id],b.sib_group_id,b.type=="node-group"?1:0,b.sort_ypos,b.id]
            );
          });
          
          //now determine the best arrangement side-toside in the level for the nodes
          //based on wether each node is a link or not, determine padding and center for each node
          var padding = function(anode,bnode){
            if ((typeof anode == 'undefined') || (typeof bnode == 'undefined')){
              return 0;
            } else if (anode.type!=bnode.type){
              return nodePadding/2.0;
            } else if (anode.type=="link-intermediate") {
              return linkPadding/2.0;
            } else {
              return nodePadding/2.0;
            }
          }
          var total_pos = 0;
          //build segments by determining padding require between adjacent nodes
          var segments = [];
          for (var i = 0; i < level.length; i++) {
            var nextSeg = {
              'lpad':padding(level[i-1],level[i]),
              'rpad':padding(level[i],level[i+1]),
              'ideal':level[i].sort_ypos
            };
            nextSeg.pos = total_pos+nextSeg.lpad;
            total_pos = nextSeg.pos+nextSeg.rpad;
            segments.push(nextSeg);
          }
          //two passes (leftwards and rightwards)
          // push nodes *wards if doing so decreases avgerage distance
          // to the ideal point (if there were no collisions) for each node
          for (var i = 0; i < segments.length; i++) {
            var partial = segments.slice(i);
            var push_ideal = partial[0].ideal-partial[0].pos;
            if (push_ideal < 0) continue;
            var push_average = d3Array.mean(partial,function(seg){return seg.ideal-seg.pos});
            if (push_average>0){
              var push = d3Array.min([push_ideal,push_average]);
              partial.forEach(function(seg){
                seg.pos+=push;
              });
            }
          }
          for (var i = 0; i < segments.length; i++) {
            var rev = segments.slice(0);
            rev.reverse();
            var partial = rev.slice(i);
            var push_ideal = partial[0].ideal-partial[0].pos;
            if (push_ideal > 0) continue;
            var push_average = d3Array.mean(partial,function(seg){return seg.ideal-seg.pos});
            if (push_average < 0){
              var push = d3Array.max([push_ideal,push_average]);
              partial.forEach(function(seg){
                seg.pos+=push;
              });
            }
          }
          
          //move nodes to position
          level.forEach(function(node,i){
            node.sort_ypos = segments[i].pos;
          });
        });
      }
      return levels;
    }
    
    
    function _wrap_nodes(data){
      var idmap = {};
      var wrapped_nodes = data.map(function(node_data){
          var node_id = id(node_data);
          idmap[node_id] = {
            'type':'node', 
            'id':id(node_data), 
            'value':value(node_data), 
            'children':[], 
            '_node_data':node_data
          };
          return idmap[node_id];
        });
      wrapped_nodes.forEach(function(wrapped){
          var parent_ids = parents(wrapped._node_data).map(id);
          delete wrapped._node_data;
          if (!parentsOrdered) parent_ids.sort();
          wrapped.sib_group_id = parent_ids.length>0 ? "S::"+parent_ids.join("++M++") : "S::_ROOT_";
          wrapped.parents = parent_ids.map(function(p_id){return idmap[p_id];});
          wrapped.parents.forEach(function(parent){
            if (parent){
              parent.children.push(wrapped);
            }
          });
        });
      if (groupChildless){
        var sibling_groups = d3Collection.nest().key(function(wrapped){
            return wrapped.sib_group_id;
          })
          .entries(wrapped_nodes);
        var grouped = sibling_groups.reduce(function(grouped, sibling_group){
          var groupable = sibling_group.values.filter(function(wrapped){
            return wrapped.children.length==0 && !excludeFromGrouping[wrapped.id];
          });
          if (groupable.length>=minGroupSize) {
            var group_id = "G::"+sibling_group.key;
            grouped[group_id] = {
              'type':'node-group', 
              'id':group_id, 
              'sib_group_id':sibling_group.key,
              'value':groupable, 
              'children':[]
            };
            grouped[group_id].parents = groupable[0].parents.map(function(p){
              p.children.push(grouped[group_id]);
              return p;
            })
            sibling_group.values.forEach(function(wrapped){
              if (wrapped.children.length>0 || excludeFromGrouping[wrapped.id]){
                grouped[wrapped.id] = wrapped;
              }
            });
          }
          else {
            sibling_group.values.forEach(function(wrapped){
              grouped[wrapped.id] = wrapped;
            });
          }
          return grouped;
        },{});
        var grouped_nodes = d3Collection.values(grouped);
        grouped_nodes.forEach(function(wrapped){
          if (wrapped.type=='node') {
            wrapped.children = wrapped.children.filter(function(c){
              return !!grouped[c.id];
            });
          }
        });
        return grouped_nodes;
      } 
      else {
        return wrapped_nodes;
      }
    }

    return pdgtree;
  };

  exports.pedigreeTree = d3PedigreeTree;

  Object.defineProperty(exports, '__esModule', { value: true });

}));