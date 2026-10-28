'use strict';
// Execute the entire actual legacy page. Controlled jQuery/DataTables transport
// stores native handlers and completes actual asynchronous callbacks on demand.
// No product function is extracted, rewritten, or substituted.
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../../..');
const sourcePath=process.env.I18N_CROSS_PROPERTIES_SOURCE||path.join(root,'js/source/legacy/CXGN/BreedersToolbox/CrossDetailPage.js');
const source=fs.readFileSync(sourcePath,'utf8');
const plain=value=>JSON.parse(JSON.stringify(value));
// Exact native cross_properties option/column order from sgn.conf.
const propertyOrder=['Tag Number','Pollination Date','Number of Bags','Number of Flowers','Number of Fruits','Number of Seeds'];
const property='Number of Seeds';
const literal='17.25 kg / Ділянка / 试验 / ورقة / <b>A & B</b> / &amp;';
function harness(confirmAnswer=true){
 const elements=new Map(),tables=[],requests=[],events=[],alerts=[];
 const document={documentElement:{lang:'uk',getAttribute:name=>name==='data-sgn-locale'?'uk':null},getElementById:id=>element('#'+id)};
 function element(selector){if(!elements.has(selector))elements.set(selector,{selector,value:'',html:'',handlers:{},dialogState:null,selectedIndex:0});return elements.get(selector);}
 element('#cross_id').html='\n1745\r\n';element('#cross_name').html='Cross_Дослід_试验';element('#properties_select').value=property;element('#properties_select').selectedIndex=5;
 function jquery(selector){if(selector===document)return{ready:callback=>callback()};const selected=typeof selector==='string'?selector.split(',').map(x=>element(x.trim())):[selector];const el=selected[0];
  const api={length:selected.length,html(value){if(arguments.length){el.html=value;return api;}return el.html;},val(value){if(arguments.length){el.value=value==null?'':String(value);if(el.selector==='#properties_select')el.selectedIndex=propertyOrder.indexOf(el.value);return api;}return el.value;},text(value){if(arguments.length){el.text=value;return api;}return el.text||'';},attr(name){return name==='id'?el.selector.slice(1):null;},prop(name,value){if(arguments.length>1){for(const item of selected)item[name]=value;return api;}return el[name];},focus(){return api;},click(fn){el.handlers.click=fn;return api;},change(fn){el.handlers.change=fn;return api;},dblclick(fn){el.handlers.dblclick=fn;return api;},dialog(arg){if(typeof arg==='string'){el.dialogState=arg;events.push({kind:'dialog',selector:el.selector,state:arg});}else el.dialogConfig=arg;return api;},DataTable(config){
   const ajax=typeof config.ajax==='string'?{url:config.ajax}:config.ajax;
   const table={selector:el.selector,config,ajax:{reload(){events.push({kind:'reload',selector:el.selector});}},deliver(response){const before=JSON.stringify(response);const rows=typeof ajax.dataSrc==='function'?ajax.dataSrc(response):response.data;assert.strictEqual(rows,response.data,'Actual dataSrc returns the exact original response.data array');assert.equal(JSON.stringify(response),before,'Property response arrays/scientific data remain untouched');table.rows=rows;return rows;},finish(status='success'){events.push({kind:'table-completed',selector:el.selector,status});if(typeof ajax.complete==='function')ajax.complete({},status);},complete(response){const rows=table.deliver(response);table.finish();return rows;}};
   tables.push(table);events.push({kind:'table-request',selector:el.selector,url:ajax.url,method:ajax.type||'GET',headers:plain(ajax.headers||{}),data:plain(ajax.data||{})});return table;
  }};return api;
 }
 jquery.ajax=config=>{const req={config,done:[],fail:[],complete(response){events.push({kind:'ajax-completed',url:config.url});if(config.success)config.success(response);for(const fn of req.done)fn(response);},reject(...args){for(const fn of req.fail)fn(...args);}};requests.push(req);events.push({kind:'ajax-request',url:config.url,method:config.type||'GET',headers:plain(config.headers||{}),data:plain(config.data||{})});const deferred={done(fn){req.done.push(fn);return deferred;},fail(fn){req.fail.push(fn);return deferred;}};return deferred;};
 const context=vm.createContext({window:{location:{href:'http://127.0.0.1:18335/cross/1745',origin:'http://127.0.0.1:18335'},open(){}},document,jQuery:jquery,$:jquery,URL,console:{log(){}},alert:value=>alerts.push(value),confirm:()=>confirmAnswer,format_options_list:()=>'',show_list_counts(){},addToListMenu(){},selectAllOptions(){}});
 vm.runInContext(source,context,{filename:sourcePath});
 function response(value){return vm.runInContext('('+JSON.stringify(value)+')',context);}
 function trigger(selector,event){const e=element(selector);assert.equal(typeof e.handlers[event],'function','Native '+event+' handler is registered: '+selector);if(event==='click'&&e.disabled)return false;return e.handlers[event].call(e);}
 const propertyTables=()=>tables.filter(t=>t.selector==='#cross_properties');
 return{element,trigger,response,tables,propertyTables,requests,events,alerts};
}
test('initial property dataSrc preserves canonical endpoint/default GET and exact raw data',()=>{
 const h=harness();const table=h.propertyTables()[0];const request=h.events.find(e=>e.kind==='table-request'&&e.selector==='#cross_properties');assert.deepEqual(request,{kind:'table-request',selector:'#cross_properties',url:'/ajax/cross/properties/1745',method:'GET',headers:{'X-SGN-Locale':'uk'},data:{}});
 const r=h.response({data:[['TAG_é','2026-10-09',17.25,-76.5,literal,0]]});assert.strictEqual(table.complete(r),r.data);assert.equal(h.element('#property_value').value,'','No optional editor callback is invoked by initial read');
});
test('real edit click loads the selected canonical property via the optional trusted dataSrc callback',()=>{
 const h=harness();h.element('#property_value').value='old editor data';h.trigger('#edit_properties_link','click');assert.equal(h.element('#edit_properties_dialog').dialogState,'open');const table=h.propertyTables().at(-1);const r=h.response({data:[['TAG_é','2026-10-09',17.25,-76.5,0,literal]]});table.complete(r);assert.equal(h.element('#property_value').value,literal,'Real editor callback loads exact Unicode/scientific/literal data');assert.equal(h.propertyTables().length,2);
});
test('real type-change callback follows native column order for Unicode, zero and null',()=>{
 const h=harness();h.element('#property_value').value=literal;h.element('#properties_select').value='Pollination Date';h.element('#properties_select').selectedIndex=1;h.trigger('#properties_select','change');h.propertyTables().at(-1).complete(h.response({data:[['TAG',null,17.25,-76.5,0,literal]]}));assert.equal(h.element('#property_value').value,'','Null selected column clears the editor');
 h.element('#properties_select').value=property;h.element('#properties_select').selectedIndex=5;for(const value of [0,'0',literal,null]){h.trigger('#properties_select','change');h.propertyTables().at(-1).complete(h.response({data:[['TAG',null,17.25,-76.5,0,value]]}));assert.equal(h.element('#property_value').value,value==null?'':String(value),'Native selected scalar remains exact');}
 h.trigger('#properties_select','change');h.propertyTables().at(-1).complete(h.response({data:[]}));assert.equal(h.element('#property_value').value,'','Absent native row clears the editor');
});
test('real check/save handlers keep canonical payloads and refresh only after completed save',()=>{
 const h=harness();h.element('#property_value').value=literal;const before=h.propertyTables().length;h.trigger('#property_submit','click');const check=h.requests.find(r=>r.config.url==='/cross/property/check/1745');assert(check);assert.deepEqual(plain(check.config.data),{cross_id:'1745',type:property,value:literal});assert.equal(check.config.type||'GET','GET');assert.deepEqual(plain(check.config.headers),{'X-SGN-Locale':'uk'});
 assert.doesNotThrow(()=>check.complete(h.response({success:1})),'No nonexistent/early reload is invoked by check success');const save=h.requests.find(r=>r.config.url==='/cross/property/save/1745');assert(save);assert.deepEqual(plain(save.config.data),{cross_id:'1745',type:property,value:literal,data_type:'crossing_metadata_json'});assert.equal(save.config.type||'GET','GET');assert.deepEqual(plain(save.config.headers),{'X-SGN-Locale':'uk'});assert.equal(h.propertyTables().length,before,'No refresh before the real save completes');assert.equal(h.events.filter(e=>e.kind==='reload').length,0);
 save.complete(h.response({success:1}));assert.equal(h.propertyTables().length,before+1,'Successful native save triggers exactly one property refresh');const completion=h.events.findIndex(e=>e.kind==='ajax-completed'&&e.url==='/cross/property/save/1745');const refresh=h.events.findIndex((e,i)=>i>completion&&e.kind==='table-request'&&e.url==='/ajax/cross/properties/1745');assert(refresh>completion);assert(h.alerts.includes('The property was successfully saved.'));
});
test('native confirmation cancel performs no save or refresh',()=>{
 const h=harness(false);h.element('#property_value').value='-76.5';const before=h.propertyTables().length;h.trigger('#property_submit','click');const check=h.requests.find(r=>r.config.url==='/cross/property/check/1745');check.complete(h.response({message:'Existing raw value: 17.25 kg'}));assert.equal(h.requests.filter(r=>r.config.url==='/cross/property/save/1745').length,0);assert.equal(h.propertyTables().length,before);assert(h.alerts.includes('Not saving.'));
});

const editorControls=['#properties_select','#property_value','#property_submit'];
function assertEditorEnabled(h,enabled){for(const id of editorControls)assert.equal(Boolean(h.element(id).disabled),!enabled,'Native disabled state '+id);}
function rowResponse(h,value){return h.response({data:[['TAG_é','2026-10-09',17.25,-76.5,0,value]]});}
test('editor controls block native submit until latest data delivery and Ajax completion',()=>{
 const h=harness();assertEditorEnabled(h,true);h.trigger('#edit_properties_link','click');assertEditorEnabled(h,false);const table=h.propertyTables().at(-1);h.element('#property_value').value='17';h.trigger('#property_submit','click');assert.equal(h.requests.filter(r=>r.config.url.includes('/property/check/')).length,0,'Disabled native submit cannot send a partially loaded value');
 table.deliver(rowResponse(h,0));assert.equal(h.element('#property_value').value,'0');assertEditorEnabled(h,false);table.finish();assertEditorEnabled(h,true);h.element('#property_value').value='17';h.trigger('#property_submit','click');const req=h.requests.find(r=>r.config.url.includes('/property/check/'));assert.equal(req.config.data.value,'17','Typed value is checked after completed native loading');
});
test('stale editor response and completion cannot overwrite a newer typed value',()=>{
 const h=harness();h.trigger('#edit_properties_link','click');const older=h.propertyTables().at(-1);h.trigger('#edit_properties_link','click');const latest=h.propertyTables().at(-1);assert.notEqual(older,latest);assertEditorEnabled(h,false);latest.complete(rowResponse(h,literal));assertEditorEnabled(h,true);h.element('#property_value').value='17';older.deliver(rowResponse(h,'stale value'));assert.equal(h.element('#property_value').value,'17','Late old callback does not overwrite the latest editor');older.finish();assertEditorEnabled(h,true);assert.equal(h.element('#property_value').value,'17');
});
test('stale completion cannot enable controls while the latest request is pending',()=>{
 const h=harness();h.trigger('#edit_properties_link','click');const older=h.propertyTables().at(-1);h.trigger('#edit_properties_link','click');const latest=h.propertyTables().at(-1);older.complete(rowResponse(h,'stale'));assertEditorEnabled(h,false);latest.deliver(rowResponse(h,'0'));assert.equal(h.element('#property_value').value,'0');assertEditorEnabled(h,false);latest.finish();assertEditorEnabled(h,true);
});
test('editor transport completion reenables controls without replacing native DataTables error behavior',()=>{
 const h=harness();h.trigger('#edit_properties_link','click');const table=h.propertyTables().at(-1);assertEditorEnabled(h,false);assert.equal(table.config.ajax.error,undefined,'Native DataTables error owner is preserved');table.finish('error');assertEditorEnabled(h,true);
});
