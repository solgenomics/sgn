'use strict';
// Execute the entire actual inline component and its registered handlers.
// Controlled transport/getters below are source-unit boundaries; the separately
// armed vendored-jQuery DOM test qualifies the HTML/text carrier itself.
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../../..');
const file=path.join(root,'mason/breeders_toolbox/seedlot_maintenance/tools/split_seedlot.mas');
const source=fs.readFileSync(file,'utf8');
const literal='Owned_é_Жито_試験_دفعة_<br>_<strong>_&amp;_%{names}_%2F_+_&_#_"';
const accession='Accession_é_Жито_試験_دفعة_<br>_<strong>_&amp;_%{names}';
const plain=x=>JSON.parse(JSON.stringify(x));
const escape=x=>String(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function inline(text){const blocks=[...text.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)];assert.equal(blocks.length,1);assert(!blocks[0][1].includes('<%'));return blocks[0][1];}
function harness({text=source,query='',locale='uk',translator}={}) {
    const elements=new Map(),requests=[],selectors=[],contents=new Map(),calls=[];
    const document={documentElement:{lang:locale,getAttribute:name=>name==='data-sgn-locale'?locale:null}};
    function element(key){if(!elements.has(key))elements.set(key,{key,value:'',text:'',html:'',props:{},attrs:{},handlers:{},children:[]});return elements.get(key);}
    function jq(key){if(key===document)return {ready:fn=>fn()};const e=typeof key==='string'?element(key):key.e;
        const api={e,first(){return api;},val(value){if(arguments.length){e.value=String(value??'');return api;}return e.value;},text(value){if(arguments.length){e.text=String(value??'');calls.push(['text',e.key,e.text]);return api;}if(contents.has(e.key))return contents.get(e.key).raw;return e.text;},html(value){if(arguments.length){e.html=value;calls.push(['html',e.key,value]);return api;}if(contents.has(e.key))return contents.get(e.key).escaped;return e.html;},attr(name,value){if(arguments.length>1){e.attrs[name]=value;return api;}return e.attrs[name];},prop(name,value){if(arguments.length>1){e.props[name]=value;return api;}return e.props[name];},css(...args){e.css=args;return api;},click(fn){e.handlers.click=fn;return api;},change(fn){e.handlers.change=fn;return api;},autocomplete(options){e.autocomplete=options;return api;},modal(value){e.modal=value;return api;},empty(){e.children=[];e.text='';e.html='';return api;},appendTo(target){target.e.children.push(e);return api;},append(child){e.children.push(child.e);return api;}};return api;
    }
    jq.ajax=options=>{const request={options,deliver(response){if(options.success)options.success(response);if(options.complete)options.complete();},fail(){if(options.error)options.error({});if(options.complete)options.complete();}};requests.push(request);return request;};
    const window={location:{href:'http://127.0.0.1:18335/breeders/seedlot/maintenance'+query,origin:'http://127.0.0.1:18335',search:query}};
    if(translator)window.SGN={i18n:translator};
    const context=vm.createContext({window,document,jQuery:jq,URL,URLSearchParams,get_select_box:(type,id,options)=>selectors.push({type,id,options:plain(options)})});
    vm.runInContext(inline(text),context,{filename:file});
    function trigger(id,event='click'){const e=element(id);assert.equal(typeof e.handlers[event],'function');return e.handlers[event].call(e);}
    function fill(){for(const [id,value] of Object.entries({seedlot_split_name:literal,seedlot_split_new_name:literal+'-LOTA',seedlot_split_new_location:'test_location',seedlot_split_new_box:'Box_é_<br>',seedlot_split_new_contents:accession,seedlot_split_new_organization:'Org_دفعة',seedlot_split_new_timestamp:'2026-10-11_13:00:00',seedlot_split_new_description:'Desc_<br>_&amp;',seedlot_split_new_breeding_program_id:'42',seedlot_split_new_quality_issues:'ok',seedlot_split_new_material_type:'seed'}))element('#'+id).value=value;}
    return {context,element,requests,selectors,contents,calls,trigger,fill};
}
function query(name){return '?'+new URLSearchParams({tool:'split_seedlot',seedlot_name:name,lang:'uk'}).toString();}

test('direct typed/prefilled scientific names are decoded once and carried in native structured GET data',()=>{
    for(const name of [literal,'literal_seedlot_name=part_+_&_%','%2F_%{names}']) {
        const h=harness({query:query(name)});assert.equal(h.element('#seedlot_split_name').value,name);
        assert.equal(h.requests.length,1);const o=h.requests[0].options;
        assert.equal(o.url,'/ajax/breeders/seedlots');assert.equal(o.type,'GET');assert.deepEqual(plain(o.data),{seedlot_name:name});assert.deepEqual(plain(o.headers),{'X-SGN-Locale':'uk'});
    }
});
test('legacy full-URL scanner tail keeps encoded values and raw plus/ampersand/hash without double-decoding ordinary names',()=>{
    for(const scanned of ['https://example.test/path?seedlot_name='+encodeURIComponent(literal),'/path?seedlot_name='+literal]) {
        const h=harness({query:query(scanned)});assert.equal(h.element('#seedlot_split_name').value,literal);
    }
    const h=harness();h.trigger('#seedlot_split_name_barcode');const url=new URL(h.context.window.location,'http://127.0.0.1:18335');
    assert.equal(url.pathname,'/barcode/read');assert.equal(url.searchParams.get('param'),'seedlot_name');assert.equal(url.searchParams.get('lang'),'uk');
    const returned=new URL(url.searchParams.get('return'),'http://127.0.0.1:18335');assert.equal(returned.pathname,'/breeders/seedlot/maintenance');assert.equal(returned.searchParams.get('tool'),'split_seedlot');assert.equal(returned.searchParams.get('lang'),'uk');
});
test('whole update handler retains original metadata/zero/NA and reads the existing scientific text carrier',()=>{
    const h=harness();h.element('#seedlot_split_name').value=literal+'-LOTY';
    const html='<a href="/stock/17/view">'+escape(accession)+'</a> (accession)';h.contents.set(html,{raw:accession,escaped:escape(accession)});
    h.trigger('#seedlot_split_name_update');h.requests[0].deliver({data:[{seedlot_stock_uniquename:(literal+'-LOTY').toLowerCase(),contents_html:html,breeding_program_id:42,material_type:'seed',default_seedlot_material_type:'root',location:'test_location',box:'Box_é',organization:'Org_دفعة',count:0,weight_gram:'NA',description:'not inherited',seedlot_quality:'not inherited'}]});
    assert.equal(h.element('#seedlot_split_new_contents').value,accession);assert.equal(h.element('#seedlot_split_new_description').value,'');assert.equal(h.element('#seedlot_split_new_quality_issues').value,'');
    assert.equal(h.element('#seedlot_split_original_contents_count').text,'0');assert.equal(h.element('#seedlot_split_original_contents_weight').text,'NA');
    assert.equal(h.element('#seedlot_split_new_material_type').value,'seed');assert.equal(h.element('#seedlot_split_new_material_type').props.disabled,true);
    assert.equal(h.requests[1].options.data.seedlot_name,literal+'-LOTZ');
    h.requests[1].deliver({data:[{seedlot_stock_uniquename:(literal+'-LOTZ').toLowerCase()}]});assert.equal(h.requests[2].options.data.seedlot_name,literal+'-LOTZ-LOTA');
    h.requests[2].deliver({data:[]});assert.equal(h.element('#seedlot_split_new_name').value,literal+'-LOTZ-LOTA');assert.equal(h.element('#seedlot_split_name').attrs.disabled,false);
    assert(!h.calls.some(row=>row[0]==='html'),'Current scientific/output text uses no HTML sink');
});
test('real create click keeps exact canonical GET field schema, one dimension and origin checkbox semantics',()=>{
    for(const dimension of ['amount','weight'])for(const checked of [false,true]) {
        const h=harness();h.fill();h.element('#seedlot_split_new_contents_type').value=dimension;h.element('#seedlot_split_new_contents_value').value=dimension==='amount'?'0':'3.5';h.element('#seedlot_split_new_contents_transaction').props.checked=checked;
        h.trigger('#seedlot_split_new_create');assert.equal(h.requests.length,1);const o=h.requests[0].options,data=plain(o.data);
        assert.equal(o.url,'/ajax/breeders/seedlot-create');assert.equal(o.type,undefined,'Original default GET remains');assert.deepEqual(plain(o.headers),{'X-SGN-Locale':'uk'});
        assert.equal(data.seedlot_accession_uniquename,accession);assert.equal(data.seedlot_name,literal+'-LOTA');assert.equal(data.seedlot_material_type,'seed');assert.equal(data['seedlot_'+dimension],dimension==='amount'?'0':'3.5');
        assert(!Object.hasOwn(data,dimension==='amount'?'seedlot_weight':'seedlot_amount'));assert.equal(Object.hasOwn(data,'origin_seedlot_uniquename'),checked);if(checked)assert.equal(data.origin_seedlot_uniquename,literal);
        const keys=['seedlot_name','seedlot_location','seedlot_box_name','seedlot_accession_uniquename','seedlot_organization','seedlot_timestamp','seedlot_description','seedlot_breeding_program_id','seedlot_quality','seedlot_material_type','seedlot_'+dimension];if(checked)keys.push('origin_seedlot_uniquename');assert.deepEqual(Object.keys(data).sort(),keys.sort());
        o.success({error:'Server_é_<img src=x onerror="x">_&amp;'});const body=h.element('#seedlot_split_modal_body');assert.equal(body.children[0].text,'Error');assert.equal(body.children[1].text,'Could not create Seedlot:');assert.equal(body.children[1].children[1].text,'Server_é_<img src=x onerror="x">_&amp;');assert(!h.calls.some(row=>row[0]==='html'));
    }
});
test('locale belongs only to declared same-origin source routes and autocomplete preserves raw suggestions',()=>{
    const h=harness({locale:'en',translator:{requestedLocale:'ar',p:(context,source)=>'ترجمة_<img>_'+source}});
    assert.deepEqual(plain(h.context.splitLocaleHeaders('/ajax/breeders/seedlots')),{'X-SGN-Locale':'en'},'Disabled English document policy takes priority');
    for(const url of ['https://foreign.test/ajax/breeders/seedlots','/ajax/breeders/seedlot/1/edit','/ajax/unknown'])assert.deepEqual(plain(h.context.splitLocaleHeaders(url)),{});
    let suggestions;h.element('#seedlot_split_name').autocomplete.source({term:literal},data=>{suggestions=data;});const o=h.requests[0].options;assert.equal(o.url,'/ajax/stock/seedlot_name_autocomplete');assert.deepEqual(plain(o.data),{term:literal});o.success([literal]);assert.deepEqual(suggestions,[literal]);
    h.context.displayError('literal_<img>');assert.equal(h.element('#seedlot_split_modal_body').children[0].text,'ترجمة_<img>_Error');assert(!h.calls.some(row=>row[0]==='html'));
});
if(process.env.I18N_SPLIT_BEFORE_SOURCE)test('original whole inline source reproduces malformed percent query before correction',()=>{
    const before=fs.readFileSync(process.env.I18N_SPLIT_BEFORE_SOURCE,'utf8');assert.throws(()=>harness({text:before,query:query(literal)}),error=>error.name==='URIError');
});

test('vendored jQuery whole-source DOM reads exact escaped content text and shows plain translated errors',{
    skip:process.env.I18N_SPLIT_BROWSER!=='1'?'Explicit exclusive browser window required':false,timeout:30000
},async()=>{
    const {chromium}=require(process.env.I18N_PLAYWRIGHT_PATH||'playwright');const browser=await chromium.launch({headless:true});const context=await browser.newContext();
    try {
        const page=await context.newPage(),errors=[],network=[];page.on('pageerror',error=>errors.push(error.message));await context.route('**/*',async route=>{network.push(route.request().url());await route.abort();});
        const markup=source.replace(/<%args>[\s\S]*?<\/%args>/g,'').replace(/<script\b[^>]*>[\s\S]*?<\/script>/g,'')
            .replace(/<%\s*\$c->i18n->p\('([^']+)',\s*'((?:\\.|[^'])*)'\)\s*\|h\s*%>/g,(_,context,text)=>escape(text.replace(/\\'/g,"'")))
            .replace(/<%\s*\$timestamp\s*%>/g,'2026-10-11_13:00:00');assert(!markup.includes('<%'));
        await page.setContent(markup+'<div id="working_modal" class="modal"></div>');for(const file of ['jquery.js','jquerymigrate.js','jqueryui.js','bootstrap_min.js'])await page.addScriptTag({path:path.join(root,'js/source/legacy',file)});
        await page.evaluate(()=>{window.splitRequests=[];window.get_select_box=(type,id,options)=>{const select=jQuery('<select>').attr('id',options.id);select.append(jQuery('<option>').val(type==='material_types'?'seed':'42').text(type));jQuery('#'+id).append(select);};jQuery.ajax=options=>{splitRequests.push(options);return {};};});
        await page.addScriptTag({content:inline(source)});await page.waitForFunction(()=>document.getElementById('seedlot_split_new_material_type'));
        await page.locator('#seedlot_split_name').fill(literal);await page.locator('#seedlot_split_name_update').click();
        await page.evaluate(({literal,accession})=>{splitRequests[0].success({data:[{seedlot_stock_uniquename:literal,contents_html:'<a href="/stock/17/view">'+accession.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))+'</a> (accession)',breeding_program_id:42,material_type:'seed',location:'test_location',box:'Box_é',organization:'Org',count:0,weight_gram:'NA'}]});splitRequests[0].complete();splitRequests[1].success({data:[]});splitRequests[1].complete();}, {literal,accession});
        assert.equal(await page.locator('#seedlot_split_new_contents').inputValue(),accession);assert.equal(await page.locator('#seedlot_split_original_contents_count').textContent(),'0');
        const serverError='Помилка_é_<img src=x onerror="window.injected=1">_<br>_&amp;';await page.evaluate(error=>displayError('Переклад_<strong>_&amp;',error),serverError);
        assert.equal(await page.locator('#seedlot_split_modal_body p code').textContent(),serverError);assert.equal(await page.locator('#seedlot_split_modal_body h1').textContent(),'Error');assert.equal(await page.locator('#seedlot_split_modal_body img,#seedlot_split_modal_body strong,#seedlot_split_modal_body script').count(),0);assert.deepEqual(errors,[]);assert.deepEqual(network,[]);
        if(process.env.I18N_SPLIT_EVIDENCE){const target=path.resolve(process.env.I18N_SPLIT_EVIDENCE);assert(!target.startsWith(root+path.sep));fs.writeFileSync(target,JSON.stringify({schema:1,status:'PASS',scope:'Whole-source offline DOM unit with controlled transport',nativeSGNWorkflowQualified:false,sourceSHA:crypto.createHash('sha256').update(source).digest('hex'),scientificContentsExact:true,errorTextExact:true,noActiveDescendants:true},null,2)+'\n');}
    } finally {await context.close();await browser.close();}
});
