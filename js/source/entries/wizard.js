import "../../legacy/CXGN/List.js";
import {Wizard} from "../modules/wizard-search.js";
import {WizardDatasets} from "../modules/wizard-datasets.js";
import {WizardDownloads} from "../modules/wizard-downloads.js";

const initialtypes = [
  "accessions",
  "breeding_programs", 
  "genotyping_protocols",
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
    case "seedlots":
      return document.location.origin+`/stock/${id}/view`;
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
        body:formData
      }).then(resp=>resp.json())
        .then(json=>{
          return json.list.map(d=>({id:d[0],name:d[1],url:makeURL(target,d[0])}))
        })
    })
    // Function which returns column contents for a given target type
    // and list of constraints spedified by catagories order (["type",...])
    // selections ({"type":[id1,id2,id3],...}) and 
    // operations ({"type":intersect?1:0,...})
    // Returns list of of unique names or objects with a "name" key 
    // ["name","name",...]|["name","name",...]|[{"name":"example"},...]
    .load_selection((target,catagories,selections,operations)=>{
      if(catagories.some(c=>selections[c].length<1)) return []
      var formData = new FormData();
      catagories.forEach((c,i)=>{
        formData.append('categories[]', c);
        formData.append('querytypes[]', operations[c]?1:0);
        (selections[c]||[]).forEach(s=>{
          formData.append(`data[${i}][]`, s.id);
        })
      });
      formData.append('categories[]', target);
      return fetch(window.location.origin+"/ajax/breeder/search",{
        method:"POST",
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
      return fetch(window.location.origin+`/list/desynonymize?list_id=${listID}`)
        .then(resp=>resp.json())
        .then(list_data=>{
        var l = {
          type:list_data.list_type,
          items:list_data.list||[]
        };
        console.log(l)
        return l 
      })
    });
    
    var load_lists = ()=>(new Promise((resolve,reject)=>{
      var private_lists = list.availableLists(initialtypes);
      var public_lists = list.availableLists(initialtypes);
      if(public_lists.error) public_lists = [];
      if(private_lists.error) private_lists = [];
      resolve(private_lists.concat(public_lists))
    })).then(lists=>lists.reduce((acc,cur)=>{
        acc[cur[0]] = cur[1];
        return acc;
      },{}
    )).then(listdict=>{
      // Dictionary of {"listID":"listName"} pairs, sets or resets lists show in dropdowns
      wiz.lists(listdict)
    });
    
    load_lists();
    
    wiz.add_to_list((listID,items)=>{
      var count = list.addBulk(listID,items.map(i=>i.name));
      if(count) alert(`${count} items added to list.`);
    })
    // Function which creates a new list from items
    .create_list((listName,items)=>{
      var newID = list.newList(listName,"");
      if(newID){
        var count = list.addBulk(newID,items.map(i=>i.name));
        if(count) alert(`${count} items added to list ${listName}.`);
      } 
    });
    
    var down = new WizardDownloads(d3.select(main_id).select(".wizard-downloads").node(),wiz);
    var dat = new WizardDatasets(dataset_span.node(),wiz);
    
    return {
      wizard:wiz,
      reload_lists: load_lists
    };
}
