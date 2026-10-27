'use strict';
// Source unit only: execute every actual inline statement and callback, with
// controlled native DataTables transport. No browser, HTTP or database claim.
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {execFileSync} = require('node:child_process');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const sourcePath = process.env.I18N_POPULATION_MEMBERS_SOURCE || path.join(root, 'mason/stock/population_members.mas');
const source = fs.readFileSync(sourcePath, 'utf8');
const stockId = 1745;
const literal = 'Population_é_Жито_試験_دفعة_<br>_<strong>_&amp;_%{names}_"\'_<img src=x onerror="window.injected=1">_</ScRiPt><script>window.injected=1</script>_\u2028_\u2029';
const plain = value => JSON.parse(JSON.stringify(value));
function fixtureJSON(value) {
    return JSON.stringify(value).replace(/[<>&\u2028\u2029]/g, c => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0'));
}
function harness(text=source, {populationName=literal, serializedName=fixtureJSON(populationName), translator}={}) {
    const tables=[],listCalls=[],values=new Map(),htmlWrites=[];
    const document={};
    const tableElement={id:'population_members_table'};
    function jquery(selector) {
        const api={
            ready(callback) {callback();return api;},
            DataTable(options) {tables.push(options);return {ajax:{reload(){throw new Error('Unexpected source reload');}}};},
            val(value) {if(arguments.length){values.set(selector,value);return api;}return values.get(selector);},
            html(value) {htmlWrites.push({selector,value});return api;}
        };
        return api;
    }
    const window={};
    if(translator)window.SGN={i18n:translator};
    const context=vm.createContext({document,window,jQuery:jquery,population_members_table:tableElement,
        addToListMenu:(menu,data,options)=>listCalls.push({menu,data,options:plain(options)})});
    const scripts=[...text.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)];
    assert.equal(scripts.length,1,'Execute the complete actual inline component script');
    const body=scripts[0][1].replace(/<%\s*\$stock_id\s*%>/g,String(stockId))
        .replace(/<%\s*\$population_name_json\s*%>/g,serializedName);
    assert(!body.includes('<%'),'Only declared numeric ID/scientific JSON Mason bindings occur');
    vm.runInContext(body,context,{filename:sourcePath});
    assert.equal(tables.length,1);
    return {context,table:tables[0],listCalls,values,htmlWrites,
        finish:response=>tables[0].fnInitComplete({},response)};
}
function cell(column,row,type) {
    const raw=column.data===null ? row : column.data==='synonyms[, ]' ? (Array.isArray(row.synonyms)?row.synonyms.join(', '):'') : row[column.data];
    return typeof column.render==='function' ? column.render(raw,type,row) : raw;
}
function escaped(value) {
    return String(value==null?'':value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

test('whole native component initializes its exact scientific name and List carrier',()=>{
    const h=harness();
    assert.equal(h.table.ajax,'/ajax/manage_accessions/population_members/'+stockId);
    assert.equal(h.table.autoWidth,false);assert.equal(h.table.destroy,true);
    const rows=[{name:literal},{name:'Second_é_Жито_試験_دفعة_&amp;_<br>'}];
    const snapshot=JSON.stringify(rows);
    assert.doesNotThrow(()=>h.finish({data:rows}),'Actual complete callback needs no external population_name global');
    const data='populations_members_add_to_list_data_'+stockId;
    assert.equal(h.values.get('#'+data),rows.map(r=>r.name+'\n').join(''));
    assert.deepEqual(h.htmlWrites,[],'Scientific list values never pass through an HTML sink');
    assert.deepEqual(h.listCalls,[{menu:'populations_members_add_to_list_menu_'+stockId,data,options:{selectText:true,listType:'accessions',listName:literal}}]);
    assert.equal(JSON.stringify(rows),snapshot,'Native response and member order stay exact');
    assert.equal(h.context.population_name,undefined,'The component creates no name global');
    assert.match(source,/<textarea\b[^>]*id="populations_members_add_to_list_data_<%\s*\$stock_id\s*%>"[^>]*\breadonly/);
    assert.match(source,/<div\b[^>]*id="populations_members_add_to_list_menu_<%\s*\$stock_id\s*%>"/);
});

test('display and filter escaping preserve names, canonical getters, links and raw other render types',()=>{
    const h=harness();
    assert.deepEqual(plain(h.table.columns.map(c=>c.data)),[null,'stock_type','description','synonyms[, ]',null]);
    const row={stock_id:1848,stock_relationship_id:9123,name:literal,stock_type:'accession',description:literal,synonyms:['First_é_<br>_&amp;','Second_試験_دفعة_<strong>']};
    const before=JSON.stringify(row);
    assert.equal(cell(h.table.columns[0],row,'display'),"<a href='/stock/1848/view'>"+escaped(row.name)+"</a>");
    for(const type of ['sort','type','export',undefined]) {
        assert.equal(cell(h.table.columns[0],row,type),row.name);
        assert.equal(cell(h.table.columns[1],row,type),row.stock_type);
        assert.equal(cell(h.table.columns[2],row,type),row.description);
        assert.equal(cell(h.table.columns[3],row,type),row.synonyms.join(', '));
    }
    assert.deepEqual(plain(h.table.columns.slice(0,4).map(c=>c.type)),['string','string','string','string'],'The native HTML type formatter cannot strip scientific tags');
    for(let index=0;index<4;index++)assert.equal(cell(h.table.columns[index],row,'filter'),escaped(index===0?row.name:index===1?row.stock_type:index===2?row.description:row.synonyms.join(', ')),'Renderer prepares escaped text for the actual one-decode native search boundary');
    assert.equal(cell(h.table.columns[1],row,'display'),'accession');
    assert.equal(cell(h.table.columns[2],row,'display'),escaped(literal));
    assert.equal(cell(h.table.columns[3],row,'display'),escaped(row.synonyms.join(', ')));
    for(const type of ['display','filter','sort','type'])assert.equal(cell(h.table.columns[4],row,type),"<a name='populations_member_remove' data-stock_relationship_id='9123'>X</a>",'Native remove branch and exact relationship ID are retained');
    assert.equal(JSON.stringify(row),before);
});

test('null and zero display and filter values stay usable while raw values remain exact',()=>{
    const columns=harness().table.columns;
    for(const index of [1,2,3])for(const value of [null,undefined,0,'0',literal]) {
        for(const type of ['display','filter'])assert.equal(columns[index].render(value,type),escaped(value));
        for(const type of ['sort','type','export'])assert.strictEqual(columns[index].render(value,type),value);
    }
});

test('all five authored headers use exact contexts and safe optional translation',()=>{
    const identities=[['population.members.member_name','Member Name'],['population.members.member_type','Member Type'],['accessions.column.description','Description'],['accessions.column.synonyms','Synonyms'],['population.members.remove_from_population','Remove From Population']];
    assert.deepEqual(plain(harness().table.columns.map(c=>c.title)),identities.map(r=>r[1]),'Missing locale assets retain original usable English captions');
    const calls=[];
    const h=harness(source,{translator:{p:(context,text)=>{calls.push([context,text]);return 'ترجمة_é_<img src=x onerror="window.injected=1">_&amp;_'+text;}}});
    assert.deepEqual(calls,identities);
    assert.deepEqual(plain(h.table.columns.map(c=>c.title)),identities.map(r=>escaped('ترجمة_é_<img src=x onerror="window.injected=1">_&amp;_'+r[1])));
    assert.equal(h.context.window.injected,undefined);
});

test('actual Perl Mason initializer serializes scientific JSON safely without changing its value',()=>{
    const init=source.match(/<%init>([\s\S]*?)<\/%init>/)?.[1];assert(init,'Compile the complete actual Mason initializer');
    for(const name of [literal,'',null]) {
        const program='use strict;use warnings;use JSON::PP;binmode STDOUT, ":encoding(UTF-8)";my $stock_uniquename=JSON::PP->new->utf8->decode($ARGV[0]);\n'+init+'\nprint $population_name_json;';
        const command=JSON.parse(process.env.I18N_POPULATION_MEMBERS_PERL_COMMAND||'["perl"]');
        assert(Array.isArray(command)&&command.length&&command.every(item=>typeof item==='string'&&item.length),'Trusted serializer argv required; no shell is used');
        const encoded=execFileSync(command[0],[...command.slice(1),'-e',program,JSON.stringify(name)],{encoding:'utf8',shell:false});
        assert(!/[<>&\u2028\u2029]/.test(encoded),'Script boundaries and separators cannot occur in serialized source');
        assert.equal(JSON.parse(encoded),name==null?'':name,'The raw scientific name survives exact JSON decoding');
        const h=harness(source,{populationName:name==null?'':name,serializedName:encoded});h.finish({data:[]});
        assert.equal(h.listCalls[0].options.listName,name==null?'':name);
        assert.equal(h.context.window.injected,undefined);
    }
});

test('stock population page passes its current uniquename through the existing argument chain',()=>{
    const page=fs.readFileSync(path.join(root,'mason/stock/index.mas'),'utf8');
    const section=fs.readFileSync(path.join(root,'mason/page/detail_page_2_col_section.mas'),'utf8');
    const call=page.split('\n').find(line=>line.includes('info_section_id => "population_members_section"'));
    assert.match(call,/stock_uniquename\s*=>\s*\$uniquename/);
    assert.match(section,/<&\s*\/stock\/population_members\.mas,\s*stock_id\s*=>\s*\$stock_id,\s*stock_uniquename\s*=>\s*\$stock_uniquename\s*&>/);
    assert.match(source,/\$stock_uniquename\s*=>\s*undef/,'Other callers may retain the original optional-name boundary');
});

if(process.env.I18N_POPULATION_MEMBERS_BEFORE_SOURCE)test('unchanged original whole callback reproduces the reported ReferenceError',()=>{
    const before=fs.readFileSync(process.env.I18N_POPULATION_MEMBERS_BEFORE_SOURCE,'utf8');
    const h=harness(before);
    assert.throws(()=>h.finish({data:[{name:literal}]}),error=>error.name==='ReferenceError'&&/population_name is not defined/.test(error.message));
});


test('actual vendored DataTables offline render keeps final search cache literal', {
    skip: process.env.I18N_POPULATION_MEMBERS_RENDER_BROWSER!=='1' ? 'An explicit exclusive browser window is required for this offline render unit' : false
}, async()=>{
    // This is a rendering unit with controlled transport. It loads complete
    // vendored jQuery/DataTables and the complete authored component script,
    // without a running SGN application, HTTP fixture or database claim.
    const {chromium}=require(process.env.I18N_PLAYWRIGHT_PATH||'playwright');
    const browser=await chromium.launch({headless:true});
    const errors=[],network=[];
    const context=await browser.newContext();
    await context.route('**/*',async route=>{network.push(route.request().url());await route.abort();});
    try {
        const page=await context.newPage();
        page.on('pageerror',error=>errors.push(error.message));
        const markup=source.replace(/<%args>[\s\S]*?<\/%args>/g,'')
            .replace(/<%init>[\s\S]*?<\/%init>/g,'')
            .replace(/<&[\s\S]*?&>/g,'')
            .replace(/<script\b[^>]*>[\s\S]*?<\/script>/g,'')
            .replace(/<%\s*\$stock_id\s*%>/g,String(stockId));
        assert(!markup.includes('<%'),'Offline markup retains actual component elements with a numeric Mason ID');
        await page.setContent(markup);
        await page.addScriptTag({path:path.join(root,'js/source/legacy/jquery.js')});
        await page.addScriptTag({path:path.join(root,'js/source/legacy/jquery/dataTables.js')});
        const rows=[
            {stock_id:1848,stock_relationship_id:9123,name:literal,stock_type:'accession',description:literal,synonyms:['First_é_<br>_&amp;','Second_試験_دفعة_<strong>']},
            {stock_id:1849,stock_relationship_id:9124,name:'Zero_é_0',stock_type:'accession',description:0,synonyms:[0]},
            {stock_id:1850,stock_relationship_id:9125,name:'Blank_دفعة',stock_type:'accession',description:null,synonyms:null},
            {stock_id:1851,stock_relationship_id:9126,name:'PureTags_<br>_<strong>',stock_type:'accession',description:'OnlyTags_<b>literal</b>',synonyms:['Tag_<br>']},
            {stock_id:1852,stock_relationship_id:9127,name:'MissingSynonyms_é_試験',stock_type:'accession',description:0}
        ];
        await page.evaluate(({rows,stockId})=>{
            window.populationMembersRenderRows=rows;
            window.populationMembersRenderRequests=[];
            window.populationMembersRenderListCalls=[];
            window.addToListMenu=(menu,data,options)=>window.populationMembersRenderListCalls.push({menu,data,options});
            jQuery.fn.dataTable.ext.errMode='throw';
            jQuery.ajax=options=>{
                if(options.url!=='/ajax/manage_accessions/population_members/'+stockId)throw new Error('Unexpected offline fixture transport URL');
                window.populationMembersRenderRequests.push({url:options.url,method:options.type||'GET'});
                const request={readyState:1,status:0,abort(){throw new Error('Unexpected offline fixture abort');}};
                setTimeout(()=>{request.readyState=4;request.status=200;options.success({data:rows});if(options.complete)options.complete(request,'success');},0);
                return request;
            };
        },{rows,stockId});
        const body=source.match(/<script\b[^>]*>([\s\S]*?)<\/script>/)[1]
            .replace(/<%\s*\$stock_id\s*%>/g,String(stockId))
            .replace(/<%\s*\$population_name_json\s*%>/g,fixtureJSON(literal));
        await page.addScriptTag({content:body});
        await page.waitForFunction(()=>window.populationMembersRenderListCalls.length===1);
        const observed=await page.evaluate(()=>{
            const table=jQuery('#population_members_table').DataTable(),settings=table.settings()[0];
            const records=settings.aoData.map((row,index)=>({
                raw:row._aData,search:row._aFilterData,
                rendered:['sort','type','export'].map(type=>({type,values:[0,1,2,3].map(column=>table.cell(index,column).render(type))})),
                display:[...row.nTr.cells].map(cell=>cell.textContent)
            }));
            table.column(0).search(window.populationMembersRenderRows[0].name,false,false,false).draw();
            return {version:jQuery.fn.dataTable.version,types:settings.aoColumns.slice(0,4).map(column=>column.sType),records,
                filtered:table.rows({filter:'applied'}).data().toArray().map(row=>row.stock_id),
                requests:window.populationMembersRenderRequests,listCalls:window.populationMembersRenderListCalls,
                carrier:document.getElementById('populations_members_add_to_list_data_1745').value,
                activeDescendants:document.querySelectorAll('#population_members_table tbody img,#population_members_table tbody script,#population_members_table tbody strong,#population_members_table tbody br').length,
                injected:window.injected||0,nameGlobal:typeof window.population_name};
        });
        const receiptPath=process.env.I18N_POPULATION_MEMBERS_RENDER_EVIDENCE;
        const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
        const receipt={schema:1,status:'OBSERVED',scope:'Offline source rendering unit with controlled transport',nativeSGNWorkflowQualified:false,
            sourceSHA:hash(sourcePath),jquerySHA:hash(path.join(root,'js/source/legacy/jquery.js')),dataTablesSHA:hash(path.join(root,'js/source/legacy/jquery/dataTables.js')),fixtureRows:rows,observed};
        if(receiptPath) {
            const target=path.resolve(receiptPath);assert(target!==root&&!target.startsWith(root+path.sep),'Render evidence stays outside the source checkout');
            fs.writeFileSync(target,JSON.stringify(receipt,null,2)+'\n');
        }
        assert.equal(observed.version,'1.10.12','Qualify the actual reviewed vendored DataTables version');
        assert.deepEqual(observed.types,['string','string','string','string']);
        assert.deepEqual(observed.requests,[{url:'/ajax/manage_accessions/population_members/'+stockId,method:'GET'}]);
        assert.equal(observed.records.length,rows.length);
        for(let index=0;index<rows.length;index++) {
            const row=rows[index],record=observed.records[index];
            const raw=[row.name,row.stock_type,row.description,Array.isArray(row.synonyms)?row.synonyms.join(', '):''];
            assert.deepEqual(record.raw,row,'Actual vendored table retains every raw row and synonym order');
            assert.deepEqual(record.search.slice(0,4),raw.map(value=>value==null?'':String(value)),'Actual final native search cache decodes escaped literals exactly once');
            assert.deepEqual(record.display.slice(0,4),raw.map(value=>value==null?'':String(value)),'Actual DOM displays scientific literal tags/entities without interpreting them');
            for(const render of record.rendered)assert.deepEqual(render.values,raw,'Actual vendored raw '+render.type+' getters remain unchanged');
        }
        assert.deepEqual(observed.filtered,[1848],'Actual vendored search can find the full unchanged literal scientific name');
        assert.equal(observed.carrier,rows.map(row=>row.name+'\n').join(''));
        assert.deepEqual(observed.listCalls,[{menu:'populations_members_add_to_list_menu_'+stockId,data:'populations_members_add_to_list_data_'+stockId,options:{selectText:true,listType:'accessions',listName:literal}}]);
        assert.equal(observed.activeDescendants,0);assert.equal(observed.injected,0);assert.equal(observed.nameGlobal,'undefined');
        assert.deepEqual(errors,[]);assert.deepEqual(network,[],'The offline render unit performs no HTTP requests');
        if(receiptPath){receipt.status='PASS';fs.writeFileSync(path.resolve(receiptPath),JSON.stringify(receipt,null,2)+'\n');}
    } finally {await context.close();await browser.close();}
});
