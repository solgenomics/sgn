import "../legacy/jquery.js";
import "../legacy/CXGN/List.js";
import BrAPI from '@solgenomics/brapijs';

import GraphicalFilter from "@solgenomics/brapi-graphical-filtering";
// Importing CSS will inject the file's content into a script tag on run
// this is useful for cases like this where the CSS is a dep of the JS and not the page it runs on
import "../../node_modules/@solgenomics/brapi-graphical-filtering/css/GraphicalFilter.css";

var existing = {};

export function init(filter_div,filtered_results){
  'use strict';
  
  var gf = {}; 
  var name = filter_div+","+filtered_results;
  if(existing[name]) return existing[name];
  existing[name] = gf;
  
  var list = new CXGN.List();
  var brapi = BrAPI(document.location.origin+"/brapi/v1");
  var update_callback = ()=>{};
    
  gf.update = function(group,params){
    var data = {"pageSize":10000000};
    d3.entries(params).forEach(function(entry){
        data[entry.key] = data[entry.key]||entry.value;
    });
    var brapi_node = brapi.phenotypes_search(data);
    
    var finished = new Promise(res=>{
      brapi_node.all(function(a){
        res(a);
      })  
    });
    
    if (gf.current!==undefined){
      $(filtered_results).DataTable().destroy();
      $(filtered_results).html("");
    }
    
    gf.current = GraphicalFilter(
        brapi_node,
        obsTraits,
        group? groupCols : obsCols,
        group? ["Accession"] : ["Study","Unit","Accession"],
        group? groupByAccession : undefined
      );
      
    gf.current.draw(filter_div,filtered_results);
    
    finished.then(update_callback);
    return finished;
  }
  
  gf.onUpdate = function(f){
    if(f===null) update_callback = ()=>{};
    else {
      var prev = update_callback;
      update_callback = (...args)=>{prev(...args);f(...args);}
    }
  }
  
  return gf
}

function obsTraits(d) { // traits/values
  var traits = {}
  d.observations.forEach(function(obs){
    traits[obs.observationVariableName] = obs.value;
  });
  return traits;
}

function obsCols(d){ // header columns accessor
  return {
    'Study':d.studyName,
    'Unit':d.observationUnitName,
    'Accession':d.germplasmName,
  }
}

function groupCols(d) {
  return {
    'Accession':d.germplasmName
  }
}

function groupByAccession(d) {
  return d.germplasmDbId
}
