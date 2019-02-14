import "../../legacy/d3/d3v4Min.js";
import "../../legacy/CXGN/Dataset.js";

/**
 * WizardDownloads - Creates a new WizardDownloads object.
 *
 * @class
 * @classdesc links to a wizard and manages showing relavant related data
 * @param  {type} main_id div to draw within 
 * @param  {type} wizard wizard to link to 
 * @returns {Object}
 */ 
export function WizardDownloads(main_id,wizard){
  var main = d3.select(main_id);
  var datasets = new CXGN.Dataset();
  
  var catagories = [];
  var selections = {};
  var operations = {};
  wizard.on_change((c,s,o)=>{
    catagories = c;
    selections = s;
    operations = o;
    
    var accessions = catagories.indexOf("accessions")!=-1?
      selections["accessions"]:
      [];
    var protocols = catagories.indexOf("genotyping_protocols")!=-1?
      selections["genotyping_protocols"]:
      [];
    main.select(".wizard-download-genotypes")
      .select("input")
      .attr("value",`${accessions.length||"Too few"} accessions, ${
        protocols.length==1?"selected protocol":
        protocols.length>1?"too many protocols selected":
        "default protocol"
      }`);
    main.select(".wizard-download-genotypes")
      .select("button")
      .attr("disabled",!!accessions.length&&protocols.length<=1?null:true)
      .on("click",()=>{
        
      });
      
    var trials = catagories.indexOf("trials")!=-1?
      selections["trials"]:
      [];
    main.select(".wizard-download-trial_data")
      .select("input")
      .attr("value",`${trials.length||"Too few"} trials`);
    main.select(".wizard-download-trial_data")
      .selectAll("button")
      .attr("disabled",!!trials.length?null:true);
    main.select(".wizard-download-trial_data-metadata").on("click",()=>{
      var t = JSON.stringify(trials);
      var f = d3.select(".wizard-download-trial_data-format").node().value;
      var d = d3.select(".wizard-download-trial_data-level").node().value;
      window.open(`/breeders/trials/phenotype/download?trial_list=${t}&format=${f}&dataLevel=${d}`);
    })
  });
}
