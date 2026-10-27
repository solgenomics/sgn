"use strict";
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
