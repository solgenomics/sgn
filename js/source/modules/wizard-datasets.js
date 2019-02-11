import "../../legacy/d3/d3v4Min.js";
import "../../legacy/CXGN/Dataset.js";

const main_html = `
  <div class="wizard-dataset">
    <div class="col-sm-12 col-md-6">
      <div class="panel panel-default wizard-panel">
      <div class="panel-heading">
        Load/Save <button class="btn btn-xs btn-default disabled wizard-btn-tag">Match</button> Columns as Dataset
      </div>
      <div class="panel-body">
        <div class="input-group">
          <select class="form-control input-sm wizard-dataset-select">
            <option selected value="" disabled>Load Dataset</option>
            <optgroup class="wizard-dataset-group" label="--------------------"></optgroup>
          </select>
          <span class="input-group-btn">
            <span><button style="width:5em;margin-left:4px;" class="btn btn-sm btn-primary wizard-dataset-load">Load</button></span>
          </span>
        </div>
      </div>
        <div class="panel-body" style="margin-top:-1px;">
          <div class="input-group">
            <input type="text" placeholder="Create New Dataset" class="form-control input-sm wizard-dataset-name"/>
            <span class="input-group-btn">
              <span><button style="width:5em;margin-left:4px;" class="btn btn-sm btn-primary wizard-dataset-create">Create</button></span>
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
`;

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
  
  main.html(main_html);
  
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
