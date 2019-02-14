import "../../legacy/d3/d3v4Min.js";
import "../../legacy/CXGN/Dataset.js";

/**
 * WizardDatasets - Creates a new WizardDatasets object.
 *
 * @class
 * @classdesc links to a wizard and manages loading/saving datasets
 * @param  {type} main_id div to draw within 
 * @param  {type} wizard wizard to link to 
 * @returns {Object}
 */ 
export function WizardDatasets(main_id,wizard){
  var main = d3.select(main_id);
  var datasets = new CXGN.Dataset();
    
  var catagories = [];
  var selections = {};
  var operations = {};
  wizard.on_change((c,s,o)=>{
    catagories = c;
    selections = s;
    operations = o;
  });
  
  main.select(".wizard-dataset-load").on("click",()=>{
    var val = main.select(".wizard-dataset-select").node().value;
    if(val!=""){
      ;(new Promise((resolve,reject)=>{
        resolve(datasets.getDataset(val));
      })).then(dataset_data=>{
        console.log(dataset_data);
        dataset_data.category_order.forEach((c,i)=>{
          var items = (dataset_data.categories[c]||[]).map(d=>d+"");
          wizard.setColumn(i,c,null,(d)=>{
            return items.indexOf(d.id+"")!=-1;
          })
        })
      })
    }
  });
  
  main.select(".wizard-dataset-create").on("click",()=>{
    var name = main.select(".wizard-dataset-name").node().value;
    if(name!=""){
      var cols = wizard.getColumns();
      var last_relevant = cols.findIndex(c=>{
        return !c.type || c.items.filter(d=>d.selected).length<1
      });
      console.log(last_relevant);
      if(last_relevant==0) return;
      cols = cols.slice(0,last_relevant,cols.length-1);
      var order = cols.map(c=>c.type);
      var params = `?name=${name}&category_order=${JSON.stringify(order)}`
      cols.forEach(c=>{
        params+=`&${c.type}=${JSON.stringify(c.items.filter(d=>d.selected).map(d=>d.value.id))}`;
      })
      console.log(document.location.origin+'/ajax/dataset/save'+params);
      fetch(document.location.origin+'/ajax/dataset/save'+params,{
        method:'post'
      })
    }
  });
  
  ;(new Promise((resolve,reject)=>{
    resolve(datasets.getDatasets());
  })).then(datasets_data=>{
    if(datasets_data.error){
      main.selectAll("button").attr("disabled",true);
      main.select(".wizard-dataset-select")
        .attr("disabled",true)
        .select("option[selected]")
        .text(datasets_data.error);
      main.select(".wizard-dataset-name")
        .attr("disabled",true)
        .attr("placeholder","");
    }
    else {
      var opt = main.select(".wizard-dataset-group")
        .selectAll("option").data(datasets_data,d=>d[0]);
      opt.exit().remove();
      opt.enter().append("option")
        .merge(opt)
        .attr("value",d=>d[0])
        .text(d=>d[1]);
    }
  })
}
