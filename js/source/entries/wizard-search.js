import "../../legacy/CXGN/BreederSearch.js";
import {Wizard} from "../modules/wizard.js";
export default function WizardSetup(main_id){
  Wizard(main_id,4)
    // Dictionary of {typeId:typeName}
    .types({ 
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
    })
    // List of types to show in first column
    .initial_types([
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
    ])
    // Function which returns the first column contents for a given target type
    // Returns list of of unique names or objects with a "name" key 
    // ["name","name",...]|[{"name":"example"},...]
    .load_initial((target)=>{
      return fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        redirect: "follow", // manual, *follow, error
        referrer: "no-referrer", // no-referrer, *client
        body: JSON.stringify({'categories': [categories], 'data': data, 'querytypes': get_querytypes(this_section)}), // body data type must match "Content-Type" header
      })
    })
    // Function which returns column contents for a given target type
    // and list of constraints spedified by catagories order (["type",...])
    // selections ({"type":[id1,id2,id3],...}) and 
    // operations ({"type":intersect?1:0,...})
    // Returns list of of unique names or objects with a "name" key 
    // ["name","name",...]|["name","name",...]|[{"name":"example"},...]
    .load_selection((target,catagories,selections,operations)=>{
      return new Promise(function(resolve, reject){
        setTimeout(function(){resolve(true)},Math.random()*4000)
      }).then(()=>{
        console.log(target,catagories,selections,operations);
        var results = [];
        catagories.forEach((catagory,c_i)=>{
          var cat_results = [];
          selections[catagory].forEach((item,i_i)=>{
            var item_results = [];
            var n = parseInt(item.split("_").pop());
            for (var f = 1; f <= 10; f++) {
              item_results.push(target+"_"+(n*f))
            }
            if(!operations[catagory]){
              cat_results = cat_results.concat(item_results.filter(d=>cat_results.indexOf(d)==-1));
            }
            else if (i_i==0){
              cat_results = item_results;
            }
            else {
              cat_results = item_results.filter(d=>cat_results.indexOf(d)!=-1)
            }
          })
          if (c_i==0){
            results = cat_results;
          } else {
            results = cat_results.filter(d=>results.indexOf(d)!=-1);
          }
          console.log("crex",cat_results,results)
        })
        console.log("rex",results)
        return results
      })
    })
    // Function which returns the list contents for a given listID
    // // Returns type and list of of unique names or objects with a "name" key 
    // {"type":"typeID","items":["name","name",...]|[{"name":"example"},...]}
    .load_list((listID)=>{
      return {
        items:initiallist.slice(2,4).map(n=>"accessions_"+n),
        type:"accessions"
      }
    })
    // Dictionary of {"listID":"listName"} pairs, sets or resets lists show in dropdowns
    .lists({123:"A123",142:"B142"})
    // Function which adds items to a list
    .add_to_list((listID,items)=>{
      alert(["add",listID,items])
    })
    // Function which creates a new list from items
    .create_list((listName,items)=>{
      alert(["create",listName,items])
    });
}
