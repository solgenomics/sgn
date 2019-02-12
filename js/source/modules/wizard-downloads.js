import "../../legacy/d3/d3v4Min.js";

const main_html = `
  <div class="wizard-download">
    <div class="col-sm-12 col-md-6">
      <div class="panel panel-default wizard-panel">
      <div class="panel-heading">
        Download Related Data
      </div>
      <div class="panel-body wizard-download-genotypes">
        <div class="input-group">
          <input class="form-control input-sm" type="text" disabled></input>
          <span class="input-group-btn">
            <span><button style="width:9em;margin-left:4px;" class="btn btn-sm btn-primary">
              <span class="glyphicon glyphicon-download" aria-hidden="true"></span> Genotypes
            </button></span>
          </span>
        </div>
      </div>
      <div class="panel-body wizard-download-trial_data">
        <div class="input-group">
          <input class="form-control input-sm" type="text" disabled value="No Trials Selected"></input>
          <span class="input-group-btn">
            <span><button style="width:9em;margin-left:4px;" class="btn btn-sm btn-primary wizard-download-trial_data-metadata">
              <span class="glyphicon glyphicon-download" aria-hidden="true"></span> Metadata
            </button></span>
          </span>
          <span class="input-group-btn">
            <span><button style="width:9em;margin-left:4px;" class="btn btn-sm btn-primary wizard-download-trial_data-phenotypes">
              <span class="glyphicon glyphicon-download" aria-hidden="true"></span> Phenotypes
            </button></span>
          </span>
        </div>
      </div>
    </div>
  </div>
`;

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
  
  main.html(main_html);
  
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
      .attr("disabled",!!accessions.length&&protocols.length<=1?null:true);
      
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
