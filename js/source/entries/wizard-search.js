import "../../legacy/CXGN/List.js";
import {Wizard} from "../modules/wizard.js";

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

export function WizardSetup(main_id){
  var list = new CXGN.List();
  var wiz = Wizard(main_id,4)
    // Dictionary of {typeId:typeName}
    .types(types)
    // List of types to show in first column
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
          return json.list.map(d=>({id:d[0],name:d[1]}))
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
          return json.list.map(d=>({id:d[0],name:d[1]}))
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
      alert(["add",listID,items])
    })
    // Function which creates a new list from items
    .create_list((listName,items)=>{
      alert(["create",listName,items])
    });
    return {
      wizard:wiz,
      reload_lists: load_lists
    };
}
