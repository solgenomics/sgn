import "../legacy/d3/d3v4Min.js";
import "../legacy/CXGN/Dataset.js";

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

  main.select(".wizard-dataset-load").on("click",function(){
    var val = main.select(".wizard-dataset-select").node().value;
    if(val!=""){
        d3.select(this).attr("disabled",true);
        setTimeout(()=>(new Promise((resolve,reject)=>{
          resolve(datasets.getDataset(val));
          d3.select(this).attr("disabled",null);
        })).then(dataset_data=>{
          // console.log(dataset_data);
          dataset_data.category_order.forEach((c,i)=>{
            var items = (dataset_data.categories[c]||[]).map(d=>d+"");
            wizard.setColumn(i,c,null,(d)=>{
              return items.indexOf(d.id+"")!=-1;
            })
          })
        }),1);
    }
  });

  main.select(".wizard-dataset-delete").on("click",function(){
    var name = main.select(".wizard-dataset-select option:checked").text();
    var val = main.select(".wizard-dataset-select").node().value;
    if(val!=""){
        var dataset = datasets.getDataset(val);
        var details = '';
        dataset.category_order.forEach(function(cat) {
            var contents = dataset.categories[cat];
	    if(contents) {
                details+= `\n    ${contents.length} ${cat}`;
	    }
        })
        if ( confirm(`Dataset ${name} contains\: ${details}\nAre you sure you would like to delete it? Deletion cannot be undone.`)) {
            datasets.deleteDataset(val);
            load_datasets();
        }
    }
  });

  main.select(".wizard-dataset-public").on("click",function(){
    var name = main.select(".wizard-dataset-select option:checked").text();
    var val = main.select(".wizard-dataset-select").node().value;
    if(val!==""){
        var dataset = datasets.getDataset(val);
        var details = "";
        dataset.category_order.forEach(function(cat) {
            var contents = dataset.categories[cat];
	    if(contents) {
                details+= `\n    ${contents.length} ${cat}`;
	    }
        });
        datasets.makePublicDataset(val);
	load_datasets();
    }
  });

  main.select(".wizard-dataset-private").on("click",function(){
    var name = main.select(".wizard-dataset-select option:checked").text();
    var val = main.select(".wizard-dataset-select").node().value;
    if(val!==""){
        var dataset = datasets.getDataset(val);
        var details = "";
        dataset.category_order.forEach(function(cat) {
            var contents = dataset.categories[cat];
            details+= `\n    ${contents.length} ${cat}`;
        });
        datasets.makePrivateDataset(val);
    }
  });

  main.select(".wizard-dataset-create").on("click",function(){
    var name = main.select(".wizard-dataset-name").node().value;
    if(name!=""){
      d3.select(this).attr("disabled",true);
      var cols = wizard.getColumns();
      var first_irrelevant_col = cols.findIndex(c=>{
        return !c.type || c.items.filter(d=>d.selected).length<1
      });
      if(first_irrelevant_col==0) {
          alert(`Dataset creation failed. No data is selected.`);
          d3.select(this).attr("disabled",null);
          return;
      }
      if(first_irrelevant_col==-1) {
          first_irrelevant_col = cols.length; // retain all columns if no irrelevant ones are found
      }
      cols = cols.slice(0, first_irrelevant_col);
      var order = cols.map(c=>c.type);
      var params = `?name=${name}&category_order=${JSON.stringify(order)}`
      cols.forEach(c=>{
        params+=`&${c.type}=${JSON.stringify(c.items.filter(d=>d.selected).map(d=>d.value.id))}`;
      })
      console.log(document.location.origin+'/ajax/dataset/save'+params);
      fetch(document.location.origin+'/ajax/dataset/save'+params,{
        method:'post',
        credentials: 'include'
      }).then(()=>{
          var details = '';
          cols.forEach(c=>{
            details+= `\n    ${c.items.filter(d=>d.selected).length} ${c.type}`;
          })
        alert(`Dataset ${name} created with\: ${details}`);
        load_datasets();
        d3.select(this).attr("disabled",null);
        if ( DSP_ENABLED ) {
          returnToSource();
        }
      })
    }
  });

  var load_datasets = ()=>(new Promise((resolve,reject)=>{
    resolve(datasets.getDatasets());
  })).then(datasets_data=>{
    if(datasets_data.error){
      main.selectAll(".wizard-dataset-load, .wizard-dataset-delete, .wizard-dataset-create").attr("disabled",true);
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

  load_datasets();

}
