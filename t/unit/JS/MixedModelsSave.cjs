const fs = require('fs');
const vm = require('vm');
const sourcePath = process.argv[2] || require('path').resolve(__dirname,'../../../js/source/entries/mixedmodels.js');
const outputPath = process.argv[3];
const handlers = new Map();
const values = new Map();
let dataset = '1';
let engine = 'sommer';
let modelText = 'Yield ~ replicate , random = ~vsr(germplasmName)';
const fittedProtocol = modelText;
let fixed = ['replicate'];
const ajaxRequests = [];
function wrap(target) {
  const key = typeof target === 'string' ? target : target?.key || '__document';
  const element = {
    val(value) {
      if (arguments.length) { values.set(key, value); return proxy; }
      if (key.includes('select_engine')) return engine;
      if (target?.value !== undefined) return target.value;
      return values.get(key) || '';
    },
    text(value) {
      if (arguments.length) { if (key === '#model_string') modelText = value; else values.set(key,value); return proxy; }
      return key === '#model_string' ? modelText : target?.text || values.get(key) || '';
    },
    html(value) {
      if (arguments.length) { values.set(key,value); return proxy; }
      return key === '#model_string' ? modelText : values.get(key) || '';
    },
    children() {
      if(key === '#fixed_factors') return fixed.map(text=>({text}));
      if(key === '#random_factors') return [{text:'germplasmName'}];
      return [];
    },
    each(callback) {
      const selected = key.includes('mixed_model_dataset_select_checkbox') ? [dataset]
        : key.includes('dependent_variable_select') ? ['Yield|CO_343:0000001'] : [];
      selected.forEach(value=>callback.call({value}));
      return proxy;
    },
    click(...args) { if(typeof args.at(-1)==='function') handlers.set(key,args.at(-1)); return proxy; },
    on(event,selector,handler) { if(typeof handler==='function') handlers.set(selector,handler); return proxy; },
    is() {return true;}
  };
  const proxy = new Proxy(element,{get(object,property){return property in object ? object[property] : ()=>proxy;}});
  return proxy;
}
const $ = wrap;
$.ajax = request => {
  ajaxRequests.push({url:request.url,data:request.data});
  if(request.url==='/ajax/mixedmodels/prepare') request.success({factors:['replicate','blockNumber','germplasmName'],dependent_variable:'trait',tempfile:'prepared_dataset_1_phenotype.txt'});
  if(request.url==='/ajax/mixedmodels/run') request.success({
    method:'random',accession_names:['G1'],traits:['Yield|CO_343:0000001'],input_file:'/tmp/prepared_dataset_1_phenotype.txt',
    adjusted_blups_data:{G1:{'Yield|CO_343:0000001':[55,'2026-11-03T00:00:00','test','','']}},
    blups_data:{G1:{'Yield|CO_343:0000001':[2,'2026-11-03T00:00:00','test','','']}},
    adjusted_blups_html:'result',blups_html:'deviation'
  });
  if(request.url==='/ajax/mixedmodels/modelstring') request.success({engine,model:engine==='sommer'?['Yield ~ blockNumber','~vsr(germplasmName)']:'blockNumber + (1|germplasmName)'});
};
class HTMLElement {}
const sandbox = {$,jQuery:$,document:{},HTMLElement,get_select_box(){},alert(message){throw new Error(message);},console:{log(){}}};
let source = fs.readFileSync(sourcePath,'utf8').replace(/^import .*;\s*$/mg,'').replace('export function init','function init');
vm.runInNewContext(source+'\ninit(new HTMLElement());',sandbox,{filename:sourcePath});
const trigger = selector => { if(!handlers.has(selector))throw new Error('Missing actual handler '+selector);handlers.get(selector).call({}); };
trigger('#mixed_model_analysis_prepare_button');
trigger('#run_mixed_model_button');
trigger('#open_store_adjusted_blups_dialog_button');
const before = Object.fromEntries(values);
dataset='2';engine='lme4';fixed=['blockNumber'];
sandbox.get_model_string();
trigger('#open_store_adjusted_blups_dialog_button');
const after = Object.fromEntries(values);
const properties = JSON.parse(after['#generic_save_analysis_model_properties']);
const checks = [
  {contract:'actual run used the prepared first dataset file',pass:ajaxRequests.find(x=>x.url.endsWith('/run')).data.tempfile==='prepared_dataset_1_phenotype.txt'},
  {contract:'unchanged preview saves the executed protocol',pass:before['#generic_save_analysis_protocol']===fittedProtocol},
  {contract:'edited preview cannot replace the executed protocol',pass:after['#generic_save_analysis_protocol']===fittedProtocol},
  {contract:'selection changes cannot replace the executed dataset ID',pass:String(after['#generic_save_analysis_dataset_id'])==='1'},
  {contract:'saved metadata records the executed sommer engine',pass:(properties.engine||properties.properties?.engine)==='sommer'},
  {contract:'saved result uses the existing Sommer statistical ontology term',pass:after['#generic_save_analysis_statistical_ontology_term']==='Adjusted means from BLUPs using Sommer R|SGNSTAT:0000039'}
];
const genericSource=fs.readFileSync(require('path').resolve(__dirname,'../../../mason/analyses/store_new_analysis_values_and_model.mas'),'utf8');
const genericStart=genericSource.indexOf('success: function(response){',genericSource.indexOf("url : '/ajax/analysis/store/json'"));
const genericEnd=genericSource.indexOf('error: function(response)',genericStart);
const callbackSource=genericSource.slice(genericStart,genericEnd).replace(/^success:\s*/,'').replace(/,\s*$/,'').trim();
const notices=[];let savedLinks='';
const callback=vm.runInNewContext('('+callbackSource+')',{jQuery(){return {modal(){},html(value){savedLinks=value;}};},console:{log(){}},alert(value){notices.push(value);},Workflow:{complete(){},focus(){}}});
callback({success:1,analysis_id:12,model_id:777,archive_pending:1,warnings:['Supporting-file archive pending']});
checks.push({contract:'generic save hook displays a pending archive warning',pass:notices.some(value=>value.includes('Supporting-file archive pending'))});
checks.push({contract:'partial archive success retains links to saved IDs',pass:savedLinks.includes('/analyses/12')&&savedLinks.includes('/analyses_model/777')});
const result={sourcePath,kind:'Actual JS handlers, controlled backend response; no browser/DB claim',fittedProtocol,before,after,ajaxRequests,checks};
if(outputPath) fs.writeFileSync(outputPath,JSON.stringify(result,null,2)+'\n');
checks.forEach(x=>console.log(x.pass?'PASS':'FAIL',x.contract));
process.exitCode=checks.every(x=>x.pass)?0:1;
