'use strict';
// Whole actual inline source with controlled transport and a recording DOM API.
// This is a source unit, not native browser, HTTP, database or layout evidence.
const assert=require('node:assert/strict'),test=require('node:test');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../../..');
const file=path.join(root,'mason/breeders_toolbox/seedlot_maintenance/tools/overdue_events.mas');
const source=fs.readFileSync(file,'utf8');
const literal='Owned_é_Жито_試験_دفعة_<br>_<strong>_&amp;_%{names}_%2F_+_&_#_"\'';
const plain=value=>JSON.parse(JSON.stringify(value));
const translated=source=>'Переклад_é_دفعة_<img src=x onerror="injected=1">_'+source;
function inline(text){const blocks=[...text.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)];assert.equal(blocks.length,1,'Execute the complete original inline component');assert(!blocks[0][1].includes('<%'),'No invented Mason or script bindings');return blocks[0][1];}
function harness({text=source,locale='uk',translate=false}={}){
    const elements=new Map(),requests=[],htmlWrites=[],alerts=[],listCalls=[],translationCalls=[];let serial=0;
    const document={documentElement:{lang:locale,getAttribute:name=>name==='data-sgn-locale'?locale:null}};
    function make(key,tag='div'){return {key,tag,value:'',text:'',html:'',attrs:{},props:{},children:[],handlers:{}};}
    function element(key){if(!elements.has(key))elements.set(key,make(key));return elements.get(key);}
    function textOf(node){return node.text+node.children.map(textOf).join('');}
    function jq(value){
        if(value===document)return {ready:callback=>callback()};
        const tag=typeof value==='string' && /^<([a-z][a-z0-9]*)\s*\/?\s*>$/i.exec(value);
        const node=tag?make('created-'+(++serial),tag[1].toLowerCase()):typeof value==='string'?element(value):value.e || value;
        const api={e:node,
            val(value){if(arguments.length){node.value=String(value??'');return api;}return node.value;},
            text(value){if(arguments.length){node.text=String(value??'');node.children=[];node.html='';return api;}return textOf(node);},
            html(value){if(arguments.length){node.html=String(value??'');node.children=[];node.text='';htmlWrites.push({selector:node.key,value:node.html});return api;}return node.html;},
            attr(name,value){if(typeof name==='object'){Object.assign(node.attrs,name);return api;}if(arguments.length>1){node.attrs[name]=String(value);return api;}return node.attrs[name];},
            prop(name,value){if(arguments.length>1){node.props[name]=value;return api;}return node.props[name];},
            css(name,value){node.css=typeof name==='object'?name:{[name]:value};return api;},
            click(callback){node.handlers.click=callback;return api;},
            empty(){node.children=[];node.text='';node.html='';return api;},
            append(...children){for(const child of children)node.children.push(child.e || child);return api;},
            appendTo(target){jq(target).e.children.push(node);return api;}
        };return api;
    }
    jq.ajax=options=>{const request={options,deliver(data){if(options.success)options.success(data);if(options.complete)options.complete();},fail(){if(options.error)options.error({});if(options.complete)options.complete();}};requests.push(request);return request;};
    let scientificList=[literal,literal+'_second'];
    function List(){}
    List.prototype.listSelect=function(...args){listCalls.push({kind:'select',args:plain(args)});return '<select data-source-unit="list-provider"></select>';};
    List.prototype.getList=function(id){listCalls.push({kind:'contents',id});return scientificList;};
    const window={location:{href:'http://127.0.0.1:18335/breeders/seedlot/maintenance?lang='+locale,origin:'http://127.0.0.1:18335'}};
    if(translate)window.SGN={i18n:{requestedLocale:'ar',p(context,source,variables){translationCalls.push({context,source});return translated(source).replace(/%\{([A-Za-z0-9_]+)\}/g,(match,key)=>variables && Object.hasOwn(variables,key)?String(variables[key]):match);}}};
    const context=vm.createContext({window,document,jQuery:jq,CXGN:{List},URL,URLSearchParams,Date,alert:message=>alerts.push(message)});
    vm.runInContext(inline(text),context,{filename:file});
    function trigger(){const callback=element('#overdue_events_find_seedlots').handlers.click;assert.equal(typeof callback,'function');return callback();}
    function fill({list='42',event='7801',date='2026-10-11'}={}){element('#overdue_events_filter_seedlot_list_select').value=list;element('#overdue_events_event_select').value=event;element('#overdue_events_date').value=date;}
    return {context,element,requests,htmlWrites,alerts,listCalls,translationCalls,trigger,fill,textOf,scientificList};
}
function descendants(node,tag){return node.children.flatMap(child=>[...(child.tag===tag?[child]:[]),...descendants(child,tag)]);}

test('whole ready handler retains the exact List type and original ontology GET with page-owned locale',()=>{
    const h=harness();assert.equal(h.requests.length,1);const o=h.requests[0].options;
    assert.equal(o.url,'/ajax/breeders/seedlot/maintenance/ontology');assert.equal(o.type,'GET');assert.equal(o.dataType,'json');assert.deepEqual(plain(o.headers),{'X-SGN-Locale':'uk'});
    assert.equal(h.listCalls[0].args[0],'overdue_events_filter_seedlot');assert.deepEqual(h.listCalls[0].args[1],['seedlots']);
    assert.equal(h.htmlWrites.length,1,'Only the existing List provider builds HTML during setup');assert.equal(h.htmlWrites[0].selector,'#overdue_events_seedlot_list');
});

test('actual ontology callback keeps canonical names and IDs in text/attribute carriers',()=>{
    const h=harness({translate:true}),ontology=[{cvterm_id:11,name:literal,children:[{cvterm_id:7801,name:literal+'_event',children:[{cvterm_id:999,name:'Scientific value'}]}]},{cvterm_id:12,name:literal+'_empty',children:null}];
    const before=JSON.stringify(ontology);h.requests[0].deliver({ontology});
    const select=h.element('#overdue_events_event_select'),options=descendants(select,'option'),groups=descendants(select,'optgroup');
    assert.equal(options.length,2,'Only native category children become event choices');assert.equal(options[0].value,'');assert.equal(options[0].text,translated('...Select Maintenance Event...'));
    assert.deepEqual(groups.map(g=>g.attrs.label),[literal,literal+'_empty']);assert.equal(options[1].value,'7801');assert.equal(options[1].text,literal+'_event');assert.equal(select.props.disabled,false);
    assert.equal(JSON.stringify(ontology),before,'Ontology scientific values stay unchanged');assert.equal(h.htmlWrites.length,1,'Scientific options never reach an HTML string sink');
});

test('real find click keeps exact raw scientific JSON body and original readonly POST',()=>{
    const h=harness();h.fill();const before=JSON.stringify(h.scientificList);assert.equal(h.trigger(),false);assert.equal(h.requests.length,2);
    const o=h.requests[1].options;assert.equal(o.type,'POST');assert.equal(o.url,'/ajax/breeders/seedlot/maintenance/overdue');assert.equal(o.contentType,'application/json; charset=utf-8');assert.equal(o.dataType,'json');assert.deepEqual(plain(o.headers),{'X-SGN-Locale':'uk'});
    assert.deepEqual(JSON.parse(o.data),{seedlots:h.scientificList,event:'7801',date:'2026-10-11'});assert.equal(o.data,JSON.stringify({seedlots:h.scientificList,event:'7801',date:'2026-10-11'}));assert.equal(JSON.stringify(h.scientificList),before);
    assert.equal(h.element('#overdue_events_find_seedlots').attrs.disabled,'true');
    o.complete();assert.equal(h.element('#overdue_events_find_seedlots').attrs.disabled,'false');assert.equal(h.element('#overdue_events_results').css.display,'block');
});

test('every original required/date branch sends no overdue POST and retains fallback English alerts',()=>{
    for(const [fields,message] of [[{list:''},'Select a list of seedlots'],[{event:''},'Select a maintenance event'],[{date:''},'Select a date'],[{date:'11/10/2026'},'Incorrect date format - the date must be in the format of YYYY-MM-DD']]){
        const h=harness();h.fill(fields);assert.equal(h.trigger(),false);assert.equal(h.requests.length,1);assert.deepEqual(h.alerts,[message]);assert.equal(h.element('#overdue_events_find_seedlots').attrs.disabled,undefined);
    }
});

test('actual result renderer keeps classification, literal names and once-encoded record navigation',()=>{
    const h=harness({translate:true});h.fill();h.trigger();
    const timestamp='2026-10-11T04:05:06Z',results=[{seedlot:literal,overdue:1,timestamp:null},{seedlot:literal+'_other',overdue:0,timestamp}];const before=JSON.stringify(results);
    h.requests[1].deliver({results});const late=h.element('#overdue_events_results_overdue'),timely=h.element('#overdue_events_results_not_overdue');
    assert.equal(late.children.length,1);assert.equal(timely.children.length,1);assert.equal(late.children[0].children[0].text,literal);assert.equal(timely.children[0].children[0].text,literal+'_other');
    const links=descendants(late,'a');assert.equal(links.length,1);assert.equal(links[0].text,translated('Record Maintenance Event'));assert.equal(links[0].attrs.target,'_blank');
    const target=new URL(links[0].attrs.href,'http://127.0.0.1:18335');assert.equal(target.pathname,'/breeders/seedlot/maintenance/record');assert.equal(target.searchParams.get('seedlot_name'),literal);assert.equal(target.searchParams.get('lang'),'uk');assert.deepEqual([...target.searchParams.keys()],['seedlot_name','lang']);
    assert.equal(timely.children[0].children[1].text,h.context.parseTS(timestamp));assert.equal(JSON.stringify(results),before);assert.equal(h.htmlWrites.length,1,'Own scientific/translated result rows never pass through HTML strings');
    h.context.displayOverdueSeedlots([]);assert.equal(late.children.length,0);assert.equal(timely.children.length,0,'A second result replaces both previous tables');
});

test('date display preserves original Date/getters/component order while translating day and month only',()=>{
    const ts='2026-10-11T04:05:06Z',d=new Date(ts),days=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],months=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const tail=d.getDate()+' '+[d.getHours(),d.getMinutes(),d.getSeconds()].map(x=>String(x).padStart(2,'0')).join(':')+' '+d.getFullYear();
    assert.equal(harness().context.parseTS(ts),days[d.getDay()]+' '+months[d.getMonth()]+' '+tail);
    const h=harness({translate:true});assert.equal(h.context.parseTS(ts),translated(days[d.getDay()])+' '+translated(months[d.getMonth()])+' '+tail);
    for(const name of [...days,...months])assert(h.translationCalls.some(c=>c.source===name),'Every original calendar abbreviation has its own translation boundary: '+name);
});

test('locale admission stays inside the two original same-origin endpoints and failure alerts remain plain text',()=>{
    const h=harness({locale:'en',translate:true});for(const url of ['/ajax/breeders/seedlot/maintenance/ontology','/ajax/breeders/seedlot/maintenance/overdue'])assert.deepEqual(plain(h.context.overdueLocaleHeaders(url)),{'X-SGN-Locale':'en'});
    for(const url of ['https://foreign.test/ajax/breeders/seedlot/maintenance/overdue','/ajax/breeders/seedlot/maintenance/record','/ajax/breeders/seedlot/maintenance/upload','/ajax/unknown'])assert.deepEqual(plain(h.context.overdueLocaleHeaders(url)),{});
    h.requests[0].fail();assert.deepEqual(h.alerts,[translated('ERROR: Could not fetch ontology terms')]);h.fill();h.trigger();h.requests[1].fail();assert.equal(h.alerts[1],translated('ERROR: Could not find overdue seedlots!'));assert.equal(h.htmlWrites.length,1);
});

if(process.env.I18N_OVERDUE_BEFORE_SOURCE)test('original whole source reproduces unescaped scientific result HTML and raw href query',()=>{
    const before=fs.readFileSync(process.env.I18N_OVERDUE_BEFORE_SOURCE,'utf8'),h=harness({text:before});h.context.displayOverdueSeedlots([{seedlot:literal,overdue:1,timestamp:null}]);
    const rendered=h.htmlWrites.find(w=>w.selector==='#overdue_events_results_overdue');assert(rendered);assert(rendered.value.includes('<td>'+literal+'</td>'));assert(rendered.value.includes('seedlot_name='+literal),'Original raw ampersand/hash/quotes enter the href without URI encoding');
});
