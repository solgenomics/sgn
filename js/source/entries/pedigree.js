import '../legacy/d3/d3v4Min.js';
import PedigreeViewer from '@solgenomics/brapi-pedigree-viewer';
import BrAPI from '@solgenomics/brapijs';

export function pedigreeTree(){
  
  var pdg = PedigreeViewer(
    BrAPI(document.location.origin+"/brapi/v1"),
    function(dbId){
      return document.location.origin+"/stock/"+dbId+"/view";
    }
  );
  
  return pdg
}
