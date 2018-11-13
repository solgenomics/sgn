(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
  typeof define === 'function' && define.amd ? define(factory) :
  (global.BrAPIBoxPlotter = factory());
}(this, (function () { 'use strict';

  /**
   * [BoxPlotter description]
   */
  class BoxPlotter {
    /**
     * [constructor description]
     * @param {Array|BrAPINode} phenotypes
     */
    constructor(container) {
      this.container = d3.select(container);
      this.data = Promise.resolve({});
    }
    setData(phenotypes){
      this.data = new Promise((resolve,reject)=>{
        if(phenotypes.forEach){
          resolve({raw:phenotypes});
        }
        else{
          phenotypes.all(data=>{
            resolve({raw:data});
          });
        }
      }).then(d=>{
        // prepare data
        d.obs = d.raw.reduce((obs,ou)=>{
          ou.observations.forEach(o=>{
            o.value = parseFloat(o.value);
            if(o.value==Math.floor(o.value)) o.value=Math.floor(o.value);
            o._obsUnit=ou;
          });
          ou.treatments.sort((a,b)=>{
            if(a.factor!=b.factor) return a.factor<b.factor?-1:1;
            if(a.modality!=b.modality) return a.modality<b.modality?-1:1;
            return 0;
          });
          return obs.concat(ou.observations);
        },[]);
        return d;
      });
      this.getVariables().then(vs=>{
        if(!this.variable ||!vs.some(v=>v.key==this.variable)) this.setVariable(vs[0].key);
      });
      this.setGroupings(this.groupings||[]);
    }
    getGroupings(){
      return Promise.resolve(d3.entries(BoxPlotter.groupAccessors));
    }
    getVariables(cb){
      var out = this.data.then(d=>{
        return d3.entries(d.obs.reduce((vars,o)=>{
          if(!vars[o.observationVariableDbId]) vars[o.observationVariableDbId] = o.observationVariableName;
          return vars;
        },{}));
      });
      if(cb) return out.then(cb);
      else return out
    }
    setVariable(variable){
      this.variable = [variable];
      this.draw();
    }
    draw(){
      var plt = {
        vm:30,
        w:400,
        bh:20,
        h:55,
        ts:10,
        scale:d3.scaleLinear(),
        f: d3.format(".3g")
      };
      plt.scale.range([30,plt.w-10]);
      plt.axis = d3.axisTop(plt.scale);
      
      this.data.then(d=>{
        if(!this.variable) return;
        var curSvg = this.container.selectAll("svg.boxplots").data([{
          label:null,values:d.groups
        }]);
        var newSvg = curSvg.enter().append("svg").classed("boxplots",true);
        newSvg.append("g").classed("axis",true);
        newSvg.append("g").classed("groups",true);
        var svg = newSvg.merge(curSvg);
        
        var groups = svg.select("g.groups");
        groups.attr("transform","translate(0,"+plt.vm+")");
        var variableGroups = null;
        var grouplevel = 0;
        while(true){
          groups.each(g=>{
            if(g.values[0].variable) variableGroups = groups;
          });
          if(variableGroups) break;
          groups.selectAll(function(){
              return this.childNodes;
            }).filter(".boxplot").remove();
          var curSubgroups = groups.selectAll(function(){
              return this.childNodes;
            }).filter(".plot-group").data(g=>{
              return g.values
          });
          curSubgroups.exit().remove();
          var newSubgroups = curSubgroups.enter().append("g")
            .classed("plot-group",true);
          var ginfo = newSubgroups.append("g").classed("group-info",true);
          ginfo.append("text");
          ginfo.append("path").attr("stroke","#444").attr("fill","none");
          newSubgroups.append("g").classed("plot-group_contents",true);
          groups = newSubgroups.merge(curSubgroups).select(".plot-group_contents");
          groups.each(g=>g.level=grouplevel);
          grouplevel+=1;
        }
        variableGroups.selectAll(".plot-group").remove();
        var curBP = variableGroups.selectAll(".boxplot").data(d=>{
            return d.values.filter(v=>this.variable.indexOf(v.key)!=-1)
              .map(v=>{
                v.q1 = d3.quantile(v.value, 0.25, o=>o.value);
                v.q2 = d3.quantile(v.value, 0.5, o=>o.value);
                v.q3 = d3.quantile(v.value, 0.75, o=>o.value);
                v.max = v.q3+1.5*(v.q3-v.q1);
                v.min = v.q1-1.5*(v.q3-v.q1);
                plt.scale.domain(d3.extent(plt.scale.domain().concat([
                  v.min,v.max,v.q1,v.q2,v.q3,
                  d3.min(v.value,o=>o.value),
                  d3.max(v.value,o=>o.value)
                ])));
                return v;
              });
          });
        plt.scale.nice();
        curBP.exit().remove();
        var newBP = curBP.enter().append("g").classed("boxplot",true);
        newBP.append("rect").classed("iqr",true)
          .attr("fill","steelblue")
          .attr("y",plt.h/2-(plt.bh/2)).attr("height",plt.bh);
        newBP.append("text").classed("mintext",true).classed("infotext",true)
          .attr("font-size",plt.ts)
          .attr("text-anchor","middle")
          .attr("y",plt.h/2-(plt.bh/4+5));
        newBP.append("text").classed("maxtext",true).classed("infotext",true)
          .attr("font-size",plt.ts)
          .attr("text-anchor","middle")
          .attr("y",plt.h/2-(plt.bh/4+5));
        newBP.append("text").classed("q2text",true).classed("infotext",true)
          .attr("font-size",plt.ts)
          .attr("text-anchor","middle")
          .attr("y",plt.h/2-(plt.bh/2+5));
        newBP.append("text").classed("q1text",true).classed("infotext",true)
          .attr("font-size",plt.ts)
          .attr("text-anchor","middle")
          .attr("alignment-baseline","hanging")
          .attr("y",plt.h/2+(plt.bh/2+3));
        newBP.append("text").classed("q3text",true).classed("infotext",true)
          .attr("font-size",plt.ts)
          .attr("text-anchor","middle")
          .attr("alignment-baseline","hanging")
          .attr("y",plt.h/2+(plt.bh/2+3));
        newBP.append("path").classed("minend",true).attr("stroke","#444").attr("stroke-width","1");
        newBP.append("path").classed("maxend",true).attr("stroke","#444").attr("stroke-width","1");
        newBP.append("path").classed("minwhisk",true).attr("stroke","#444").attr("stroke-width","1");
        newBP.append("path").classed("maxwhisk",true).attr("stroke","#444").attr("stroke-width","1");
        var newQ2 = newBP.append("g").classed("q2",true);
        newQ2.append("rect").attr("fill","#444")
          .attr("y",plt.h/2-(plt.bh/2)).attr("height",plt.bh).attr("width",2);
        newQ2.append("circle").attr("fill","#444")
          .attr("stroke","white")
          .attr("cy",plt.h/2).attr("cx",1).attr("r",4);
        var allBP = curBP.merge(newBP);
        allBP.select(".label text").text(v=>v.label);
        allBP.select(".label").attr("transform",function(){
          var w = this.getBBox().width;
          var scale = plt.w/(w+20);
          scale = 1/scale>1?scale:1;
          return `scale(${scale})translate(${plt.w/2/scale})`
        });
        allBP.select(".q2")
          .attr("transform",v=>`translate(${plt.scale(v.q2)-1},0)`);
        allBP.select(".mintext").attr("x",v=>plt.scale(v.min)).text(v=>plt.f(v.min))
          .attr("visibility",function(v){
            return this.getBBox().width<(plt.scale(v.q2)-plt.scale(v.min))?null:"hidden";
          });
        allBP.select(".maxtext").attr("x",v=>plt.scale(v.max)).text(v=>plt.f(v.max))
          .attr("visibility",function(v){
            return this.getBBox().width<(plt.scale(v.max)-plt.scale(v.q2))?null:"hidden";
          });
        allBP.select(".q2text").attr("x",v=>plt.scale(v.q2)).text(v=>plt.f(v.q2));
        allBP.select(".q1text").attr("x",v=>plt.scale(v.q1)).text(v=>plt.f(v.q1))
          .attr("visibility",function(v){
            return this.getBBox().width<(plt.scale(v.q3)-plt.scale(v.q1))?null:"hidden";
          });
        allBP.select(".q3text").attr("x",v=>plt.scale(v.q3)).text(v=>plt.f(v.q3))
          .attr("visibility",function(v){
            return this.getBBox().width<(plt.scale(v.q3)-plt.scale(v.q1))?null:"hidden";
          });
        allBP.select(".minend")
          .attr("d",v=>`M${plt.scale(v.min)} ${plt.h/2-(plt.bh/4)} v${plt.bh/2}`);
        allBP.select(".maxend")
          .attr("d",v=>`M${plt.scale(v.max)} ${plt.h/2-(plt.bh/4)} v${plt.bh/2}`);
        allBP.select(".minwhisk")
          .attr("d",v=>`M${plt.scale(v.min)} ${plt.h/2} H${plt.scale(v.q1)}`);
        allBP.select(".maxwhisk")
          .attr("d",v=>`M${plt.scale(v.max)} ${plt.h/2} H${plt.scale(v.q3)}`);
        allBP.select(".iqr")
          .attr("x",v=>plt.scale(v.q1))
          .attr("width",v=>plt.scale(v.q3)-plt.scale(v.q1));
        var outliers = allBP.selectAll(".outlier").data(
          v=>v.value.filter(o=>o.value>v.max||o.value<v.min)
        );
        outliers.exit().remove();
        outliers.enter().append("circle").classed("outlier",true)
          .attr("fill","none").attr("stroke","#444")
          .attr("r",4).attr("cy",plt.h/2)
          .merge(outliers)
          .attr("cx",o=>plt.scale(o.value));
        
        svg.selectAll(".boxplot").attr("transform",(v,i)=>"translate(0,"+(plt.h*i)+")");
        var plotGroups = svg.selectAll(".plot-group");
        plotGroups.select(".group-info").select("text").text("");
        plotGroups.nodes().reverse().forEach(plotGroupsNode=>{
          var thisPG = d3.select(plotGroupsNode);
          var bboxs = thisPG.selectAll(".plot-group_contents")
            .nodes().map(n=>n.getBBox());
          var bbox = bboxs.slice(1).reduce((tot,box)=>{
            var x = d3.extent([tot.x,box.x,tot.x+tot.width,box.x+box.width]);
            var y = d3.extent([tot.y,box.y,tot.y+tot.height,box.y+box.height]);
            return {x:x[0],y:y[0],width:x[1]-x[0],height:y[1]-y[0]};
          },bboxs[0]) || {x:0,y:0,width:0,height:0};
          console.log(plotGroupsNode,bbox);
          if(bbox.height<1) return d3.select(plotGroupsNode).remove();
          thisPG.select(".group-info")
            .select("text")
            .attr("x",g=>Math.max(plt.w,bbox.x+bbox.width))
            .attr("y",g=>bbox.y+(bbox.height/2))
            .text(g=>"\u00A0"+g.label+"\u00A0")
            .attr("transform",function(g){
              var bbox = this.getBBox();
              var factor = bbox.width/bbox.width < 1 ? bbox.width/bbox.width : 1;
              console.log(this.x);
              return `translate(${-d3.select(this).attr("x")*(factor-1)}, ${-d3.select(this).attr("y")*(factor-1)})
            scale(${factor})`
            });
          thisPG.select(".group-info").select("path")
            .attr("d",function(g){
              return `
            M ${Math.max(plt.w,bbox.x+bbox.width)-8} ${bbox.y}
            l 8 0
            l 0 ${bbox.height}
            l -8 0
            `
            });
        });
        
        var svgbbox = svg.select("g.groups").node().getBBox();
        svg.select("g.axis").attr("transform","translate(0,"+(plt.vm-5)+")").call(plt.axis);
        svg.attr("width",svgbbox.width+svgbbox.x);
        svg.attr("height",svgbbox.height+svgbbox.y+plt.vm*2);
      });
    }
    setGroupings(groupings){
      this.groupings = groupings;
      var group_nest = d3.nest();
      this.data = this.data.then(d=>{
        d.labelFunc = ()=>[];
        groupings.forEach(g=>{
          if(!g) return;
          group_nest = group_nest.key(BoxPlotter.groupAccessors[g].key);
          var lastLabel = d.labelFunc;
          d.labelFunc = (o)=>{
            var l = lastLabel(o);
            var label = BoxPlotter.groupAccessors[g].label||BoxPlotter.groupAccessors[g].key;
            return l.concat([label(o)]);
          };
        });
        d.groups = group_nest.key(o=>o.observationVariableDbId)
          .rollup(g=>g.sort((a,b)=>d3.ascending(a.value, b.value)))
          .entries(d.obs);
        function getSetLabels(groups){
          if(groups.every(g=>!!g.value)){
            // Variable Group
            groups.forEach(g=>{
              g.variable = true;
              g.labels = d.labelFunc(g.value[0]).concat([g.value[0].observationVariableName]);
              g.label = g.labels[g.labels.length-1];
            });
          }
          else{
            groups.forEach(g=>{
              getSetLabels(g.values);
              g.labels = g.values[0].labels.slice(0,-1);
              g.label = g.labels[g.labels.length-1];
            });
          }
        }
        getSetLabels(d.groups);
        return d;
      });
      this.draw();
    }
  }

  BoxPlotter.groupAccessors = {
    study:{
      name:"Study",
      key:(o)=>o._obsUnit.studyDbId,
      label:(o)=>o._obsUnit.studyName
    },
    studyLocation:{
      name:"Study Location",
      key:(o)=>o._obsUnit.studyLocationDbId,
      label:(o)=>o._obsUnit.studyLocation
    },
    block:{
      name:"Block",
      key:(o)=>o._obsUnit.blockNumber,
      label:(o)=>"Block #"+o._obsUnit.blockNumber
    },
    replicate:{
      name:"Replicate",
      key:(o)=>o._obsUnit.replicate,
      label:(o)=>"Replicate #"+o._obsUnit.replicate
    },
    program:{
      name:"Program",
      key:(o)=>o._obsUnit.programName
    },
    germplasm:{
      name:"Germplasm",
      key:(o)=>o._obsUnit.germplasmDbId,
      label:(o)=>o._obsUnit.germplasmName
    },
    treatment:{
      name:"Treatment",
      key:(o)=>{
        return (o._obsUnit.treatments||[]).reduce((v,t)=>{
          v+="Factor: \""+t.factor+"\". ";
          v+="Modality: \""+t.modality+"\". ";
          return v;
        },"");
      }
    },
    season:{
      name:"Season",
      key:(o)=>o.season
    },
    collector:{
      name:"Collector",
      key:(o)=>o.collector
    }
  };

  function boxPlotter(){
    return new BoxPlotter(...arguments);
  }

  return boxPlotter;

})));
//# sourceMappingURL=BrAPIBoxPlotter.js.map
