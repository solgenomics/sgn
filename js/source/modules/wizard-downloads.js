import "../legacy/d3/d3v4Min.js";
import "../legacy/CXGN/Dataset.js";

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
    
    // Genotype downloads
    var accessions = catagories.indexOf("accessions")!=-1?
      selections["accessions"]:
      [];
    var protocols = catagories.indexOf("genotyping_protocols")!=-1?
      selections["genotyping_protocols"]:
      [];
    main.select(".wizard-download-genotypes-info")
      .attr("value",`${accessions.length||"Too few"} accessions, ${
        protocols.length==1?"selected protocol":
        protocols.length>1?"too many protocols selected":
        "default protocol"
      }`);
    main.selectAll(".wizard-download-genotypes")
      .attr("disabled",!!accessions.length&&protocols.length<=1?null:true)
      .on("click",()=>{
        event.preventDefault();
        var accession_ids = accessions.map(d=>d.id);
        var trial_ids = (selections["trials"]||[]).map(d=>d.id);
        var protocol_id = protocols.length==1?protocols[0].id:'';
        var chromosome_number = d3.select(".wizard-download-genotypes-chromosome-number").node().value;
        var start_position = d3.select(".wizard-download-genotypes-start-position").node().value;
        var end_position = d3.select(".wizard-download-genotypes-end-position").node().value;
        var url = document.location.origin+`/breeders/download_gbs_action/?ids=${accession_ids.join(",")}&protocol_id=${protocol_id}&format=accession_ids&chromosome_number=${chromosome_number}&start_position=${start_position}&end_position=${end_position}&trial_ids=${trial_ids.join(",")}`;
        window.open(url,'_blank');
      });
    
    // Download Trial Metadata
    var trials = catagories.indexOf("trials")!=-1 ? selections["trials"] : [];
    main.selectAll(".wizard-download-tmetadata-info")
      .attr("value",`${trials.length||"Too few"} trials`);
    main.selectAll(".wizard-download-tmetadata")
      .attr("disabled",trials.length>0?null:true)
      .on("click",()=>{
        var t_ids = JSON.stringify(trials.map(d=>d.id));
        var format = d3.select(".wizard-download-tmetadata-format").node().value;
        var url = document.location.origin+`/breeders/trials/phenotype/download?trial_list=${t_ids}&format=${format}&dataLevel=metadata`;
        window.open(url,'_blank');
      });
      
    // Download Trial Phenotypes
    var trials = catagories.indexOf("trials")!=-1 ? selections["trials"] : [];
    var traits = catagories.indexOf("traits")!=-1 ? selections["traits"] : [];
    var comps = catagories.indexOf("trait_components")!=-1 ? selections["trait_components"] : [];
    var plots = catagories.indexOf("plots")!=-1 ? selections["plots"] : [];
    var plants = catagories.indexOf("plants")!=-1 ? selections["plants"] : [];
    var locations = catagories.indexOf("locations")!=-1 ? selections["locations"] : [];
    var years = catagories.indexOf("years")!=-1 ? selections["years"] : [];
    
    
    main.selectAll(".wizard-download-phenotypes-info")
      .attr("value",`${trials.length||"Too few"} trials`);
    main.selectAll(".wizard-download-phenotypes")
      .attr("disabled",trials.length>0?null:true)
      .on("click",()=>{
        var trial_ids = JSON.stringify(trials.map(d=>d.id));
        var trait_ids = JSON.stringify(traits.map(d=>d.id));
        var comp_ids = JSON.stringify(comps.map(d=>d.id));
        var accession_ids = JSON.stringify(accessions.map(d=>d.id));
        var plot_ids = JSON.stringify(plots.map(d=>d.id));
        var plant_ids = JSON.stringify(plants.map(d=>d.id));
        var location_ids = JSON.stringify(locations.map(d=>d.id));
        var year_ids = JSON.stringify(years.map(d=>d.id));
        
        var format = d3.select(".wizard-download-phenotypes-format").node().value;
        var level = d3.select(".wizard-download-phenotypes-level").node().value;
        var timestamp = d3.selectAll('.wizard-download-phenotypes-timestamp').property('checked')?1:0;
        var outliers = d3.selectAll('.wizard-download-phenotypes-outliers').property('checked')?1:0;
        var names = JSON.stringify(d3.select(".wizard-download-phenotypes-name").node().value.split(","));
        var min = d3.select(".wizard-download-phenotypes-min").node().value;
        var max = d3.select(".wizard-download-phenotypes-max").node().value;
        
        var url = document.location.origin+
        `/breeders/trials/phenotype/download?trial_list=${trial_ids}`+
        `&format=${format}&trait_list=${trait_ids}&trait_component_list=${comp_ids}`+
        `&accession_list=${accession_ids}&plot_list=${plot_ids}&plant_list=${plant_ids}&location_list=${location_ids}`+
        `&year_list=${year_ids}&dataLevel=${level}&phenotype_min_value=${min}&phenotype_max_value=${max}`+
        `&timestamp=${timestamp}&trait_contains=${names}`+
        `&include_row_and_column_numbers=1&exclude_phenotype_outlier=${outliers}`;
        window.open(url,'_blank');
      });
});
  
  
}
