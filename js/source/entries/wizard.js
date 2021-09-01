import "../legacy/CXGN/List.js";
import {Wizard} from "../modules/wizard-search.js";
import {WizardDatasets} from "../modules/wizard-datasets.js";
import {WizardDownloads} from "../modules/wizard-downloads.js";

const initialtypes = [
  "accessions",
  "breeding_programs", 
  "genotyping_protocols",
  "genotyping_projects",
  "locations",
  "seedlots",
  "trait_components",
  "traits",
  "trials",
  "trial_designs",
  "trial_types",
  "years"
];

const types = { 
  "accessions":"Accessions",
  "breeding_programs":"Breeding Programs",
  "genotyping_protocols":"Genotyping Protocols",
  "genotyping_projects":"Genotyping Projects",
  "locations":"Locations",
  "plots":"Plots",
  "plants":"Plants",
  "seedlots":"Seedlots",
  "trait_components":"Trait Components",
  "traits":"Traits",
  "trials":"Trials",
  "trial_designs":"Trial Designs",
  "trial_types":"Trial Types",
  "years":"Years"
};

function makeURL(target,id){
  switch (target) {
    case "accessions":
    case "plants":
    case "plots":
      return document.location.origin+`/stock/${id}/view`;
      break;
    case "seedlots":
      return document.location.origin+`/breeders/seedlot/${id}`;
      break;
    case "breeding_programs":
      return document.location.origin+`/breeders/manage_programs`;
      break;
    case "locations":
      return document.location.origin+`/breeders/locations`;
      break;
    case "traits":
    case "trait_components":
      return document.location.origin+`/cvterm/${id}/view`;
      break;
    case "trials":
      return document.location.origin+`/breeders/trial/${id}`;
      break;
    case "genotyping_protocols":
      return document.location.origin+`/breeders_toolbox/protocol/${id}`;
      break;
    case "genotyping_projects":
      return document.location.origin+`/breeders/trial/${id}`;
      break;
    case "trial_designs":
    case "trial_types":
    case "years":
    default:
      return null;
  }
}

export function WizardSetup(main_id){
  var list = new CXGN.List();
  var wiz = new Wizard(d3.select(main_id).select(".wizard-main").node(),4)
    .types(types)
    .initial_types(initialtypes) 
    // Function which returns the first column contents for a given target type
    // Returns list of of unique names or objects with a "name" key 
    // ["name","name",...]|[{"name":"example"},...]
    .load_initial((target)=>{
      var formData = new FormData();
      formData.append('categories[]', target);
      formData.append('data', '');
      return fetch(window.location.origin+"/ajax/breeder/search",{
        method:"POST",
        credentials: 'include',
        body:formData
      }).then(resp=>resp.json())
        .then(json=>{
          return json.list.map(d=>({id:d[0],name:d[1],url:makeURL(target,d[0])}))
        })
    })
    // Function which returns column contents for a given target type
    // and list of constraints spedified by categories order (["type",...])
    // selections ({"type":[id1,id2,id3],...}) and 
    // operations ({"type":intersect?1:0,...})
    // Returns list of of unique names or objects with a "name" key 
    // ["name","name",...]|["name","name",...]|[{"name":"example"},...]
    .load_selection((target,categories,selections,operations)=>{
      if(categories.some(c=>selections[c].length<1)) return []
      var formData = new FormData();
      categories.forEach((c,i)=>{
        formData.append('categories[]', c);
        formData.append('querytypes[]', operations[c]?1:0);
        (selections[c]||[]).forEach(s=>{
          formData.append(`data[${i}][]`, s.id);
        })
      });
      formData.append('categories[]', target);
      return fetch(window.location.origin+"/ajax/breeder/search",{
        method:"POST",
        credentials: 'include',
        body:formData
      }).then(resp=>resp.json())
        .then(json=>{
          return json.list.map(d=>({id:d[0],name:d[1],url:makeURL(target,d[0])}))
        })
    })
    // Function which returns the list contents for a given listID
    // // Returns type and list of of unique names or objects with a "name" key 
    // {"type":"typeID","items":["name","name",...]|[{"name":"example"},...]}
    .load_list((listID)=>{
        return new Promise(res=>{
           var ids = list.transform2Ids(listID);
           var ldata = list.getListData(listID);
           if(initialtypes.indexOf(ldata.type_name)==-1){
               setTimeout(()=>alert("List is not of an appropriate type."),1);
           }
           res({
            "type":ldata.type_name,
            "items":!ids.error?ids.map((ele_id,i)=>({
                "id":ele_id,
                "name":ldata.elements[i][1]
            })):[]
           });
        })
    });
    
    var load_lists = ()=>(new Promise((resolve,reject)=>{
      var private_lists = list.availableLists(initialtypes);
      var public_lists = list.publicLists(initialtypes);
      if(public_lists.error) public_lists = [];
      if(private_lists.error) private_lists = [];
      resolve(private_lists.concat(public_lists))
    })).then(lists=>lists.reduce((acc,cur)=>{
        acc[cur[0]] = { name: cur[1], type: cur[5] }
        return acc;
      },{}
    )).then(listdict=>{
      // Dictionary of {"listID":{name:"listName",type:"typeName"}} pairs, sets or resets lists show in dropdowns
      wiz.lists(listdict)
    });
    
    load_lists();
    
    wiz.add_to_list((listID,items)=>{
      var count = list.addBulk(listID,items.map(i=>i.name));
      if(count) alert(`${count} items added to list.`);
      load_lists();
    })
    // Function which creates a new list from items
    .create_list((listName,colType,items)=>{
        var newID = list.newList(listName,"");
      if(newID){
        list.setListType(newID, colType);
        var count = list.addBulk(newID,items.map(i=>i.name));
        if(count) alert(`${count} items added to list ${listName}.`);
      } 
      load_lists();
    });
    
    var down = new WizardDownloads(d3.select(main_id).select(".wizard-downloads").node(),wiz);
    var dat = new WizardDatasets(d3.select(main_id).select(".wizard-datasets").node(),wiz);

    var lo = new CXGN.List();
    jQuery('#wizard-download-genotypes-marker-set-list-id').html(lo.listSelect('wizard-download-genotypes-marker-set-list-id', ['markers'], 'Select a marker set', 'refresh', undefined));

    return {
      wizard:wiz,
      reload_lists: load_lists
    };
}

export function updateStatus(element) {
  return fetch(
    document.location.origin+'/ajax/breeder/check_status',
    {
      method: 'POST',
      credentials: 'include'
    }
  ).then(resp=>resp.json())
   .then(json=>{
      var innerhtml = "";
      if (json.refreshing) {
        innerhtml = json.refreshing;
      } else if (json.timestamp) {
        innerhtml = json.timestamp;
      } else {
        throw new Error(json.error);
      }
      d3.select(element).html(innerhtml);
      return !!json.refreshing;
   })
   .catch(err=>{
     d3.select(element).html(`<font color="red">${err.message} - If this problem persists, please <a href="../../contact/form">contact developers</a></font>`);
     return false;
   })
}

// "fullview" for refreshing materialized phenoview, genoview, traits, and stockprop
// "stockprop" for refreshing materialized stockprop
export function refreshMatviews(matview_select, button){
  d3.select(button).attr("disabled",true);
  fetch(
    document.location.origin+`/ajax/breeder/refresh?matviews=${matview_select}`,
    {
      method: 'POST',
      credentials: 'include'
    }
  ).then(resp=>resp.json())
   .then(json=>{
      if (json.error) {
        throw new Error(json.error);
      } else {
        d3.select("#update_wizard_error")
        .style("display",null)
        .html('<font color="green">'+json.message+'</font></div>');
      }
   })
   .catch(err=>{
     d3.select("#update_wizard_error")
     .style("display",null)
     .html('<font color="red">'+err.message+'</font>');
   });
}
