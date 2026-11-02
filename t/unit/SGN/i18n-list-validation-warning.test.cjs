"use strict";
const I18N = require('../../../static/js/sgn-i18n.js');
const assert=require('node:assert/strict');
const test=require('node:test');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const source=fs.readFileSync(process.env.I18N_LIST_VALIDATION_SOURCE || path.join(__dirname,'../../../js/source/legacy/CXGN/List.js'),'utf8');
function run(response,type='seedlots') {
 const alerts=[],calls=[];
 const jq=()=>({ready(){return this;},on(){return this;},draggable(){return this;}});
 jq.ajax=options=>{calls.push({url:options.url,async:options.async});options.success(response);};
 const sandbox={CXGN:function(){},jQuery:jq,document:{},window:{},alert:value=>alerts.push(String(value)),console};
 I18N.install(sandbox.window); sandbox.SGN=sandbox.window.SGN;
 vm.runInNewContext(source,sandbox,{filename:'CXGN/List.js'});
 const valid=new sandbox.CXGN.List().legacy_validate(317,type,true);
 assert.deepEqual(calls,[{url:'/list/validate/317/'+type,async:false}]);
 return {valid,alerts};
}
test('native successful seedlot response may omit optional warnings',()=>{
 assert.deepEqual(run({missing:[]}),{valid:1,alerts:[]});
});
test('native invalid response without optional warnings preserves invalidity',()=>{
 assert.deepEqual(run({missing:['literal_é_<br>_&amp;_%{names}']}),{valid:0,alerts:[]});
});
test('present warning representations preserve original alerts and validity',()=>{
 for(const warning of [0,'0',[]])assert.deepEqual(run({missing:[],warning}),{valid:1,alerts:[]});
 assert.throws(()=>run({missing:[],warning:null}),/join/,'Original malformed null-warning response remains separately classified');
 const warning=['literal_é_<br>_&amp;_%{names}','دفعة'];
 assert.deepEqual(run({missing:[],warning}),{valid:1,alerts:[warning.join(', ')]});
 assert.deepEqual(run({missing:['unknown'],warning}),{valid:0,alerts:[warning.join(', ')]});
});
test('accession valid branch and native errors retain exact behavior',()=>{
 assert.deepEqual(run({valid:1,warning:['unused']},'accessions'),{valid:1,alerts:[]});
 assert.deepEqual(run({valid:0},'accessions'),{valid:0,alerts:[]});
 assert.deepEqual(run({error:'native_é_<strong>_&amp;'}),{valid:0,alerts:['native_é_<strong>_&amp;']});
});


test('current upstream discarded-seedlot notice preserves literal names and successful validation',()=>{
 const alerts=[];
 const jq=()=>({ready(){return this;},on(){return this;},draggable(){return this;}});
 const sandbox={CXGN:function(){},jQuery:jq,document:{},window:{},alert:value=>alerts.push(String(value)),console};
 I18N.install(sandbox.window);sandbox.SGN=sandbox.window.SGN;
 vm.runInNewContext(source,sandbox,{filename:'CXGN/List.js'});
 const names=['Seed_é_<img>_&_%{names}','دفعة 0'];
 sandbox.validate_interactive({missing:[],warning:[],discarded:names},'seedlots',317);
 assert.deepEqual(alerts,['WARNING: The following seedlots have been discarded: '+names.join(', '),'This list passed validation.']);
});

test('maintenance upload uses the current upstream endpoint and preserves multipart data and locale',()=>{
 const {JSDOM}=require('jsdom');
 const root=path.resolve(__dirname,'../../..');
 const component=fs.readFileSync(path.join(root,'mason/breeders_toolbox/seedlot_maintenance/upload_dialog.mas'),'utf8');
 const script=component.match(/<script[^>]*>([\s\S]*?)<\/script>/)[1];
 const dom=new JSDOM('<html data-sgn-locale="uk-UA"><input id="maintenance_events_upload_file" type="file"><div id="working_modal"></div><div id="working_msg"></div></html>',{url:'https://example.invalid/breeders/seedlots',runScripts:'outside-only'});
 try {
  const w=dom.window,requests=[];
  w.eval(fs.readFileSync(path.join(root,'js/source/legacy/jquery.js'),'utf8'));
  w.jQuery.fn.ready=function(callback){callback();return this;};
  w.jQuery.fn.modal=function(){return this;};
  w.jQuery.ajax=options=>{requests.push(options);return {};};
  w.eval(script);
  const file=new w.File(['synthetic maintenance rows'],'Seed_é_دفعة.xlsx',{type:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'});
  const input=w.document.getElementById('maintenance_events_upload_file');
  Object.defineProperty(input,'value',{get:()=>'/synthetic/'+file.name});
  Object.defineProperty(input,'files',{value:[file]});
  w.uploadMaintenanceEvents();
  const upload=requests.find(request=>request.type==='POST');
  assert.equal(upload.url,'/ajax/breeders/seedlot/maintenance/upload');
  assert.equal(upload.headers['X-SGN-Locale'],'uk-UA');
  assert.deepEqual([...upload.data.keys()],['file']);
  assert.equal(upload.data.get('file').name,file.name);
  assert.equal(upload.data.get('file').size,file.size);
  assert.equal(upload.contentType,false);assert.equal(upload.processData,false);
 } finally {dom.window.close();}
});
