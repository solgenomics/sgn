'use strict';
// Render the complete actual Mason component with its real serializer/translator,
// then execute the complete emitted recorder script and registered handlers.
// The recording DOM and controlled transport are explicit source-unit boundaries;
// this provides no native browser, HTTP, database, authentication or layout proof.
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../../..');
const file=path.join(root,'mason/breeders_toolbox/seedlot_maintenance/record.mas');
const source=fs.readFileSync(file,'utf8');
const info=fs.readFileSync(path.join(root,'mason/page/info_section.mas'),'utf8');
const pageTitle=fs.readFileSync(path.join(root,'mason/page/page_title.mas'),'utf8');
const plain=value=>JSON.parse(JSON.stringify(value));
const literal='Owned_é_Жито_試験_دفعة_<br>_<strong>_&amp;_%{names}_%2F_+_&_#_"\'';
const canonical='Canonical_é_Жито_試験_دفعة_<br>_&amp;_%{names}_+&#/\'';
const adverse=' <img src=x onerror="injected=1"> <script data-record-injection="x">bad()</script> &amp; {names}';
const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const entityCache=new Map();
function decode(value){
    const text=String(value);if(!text.includes('&'))return text;
    if(entityCache.has(text))return entityCache.get(text);
    const program="use strict;use warnings;use JSON::PP;use HTML::Entities;binmode STDIN,':raw';binmode STDOUT,':raw';my $text=JSON::PP->new->utf8->allow_nonref->decode(do{local $/;<STDIN>});print STDOUT JSON::PP->new->utf8->allow_nonref->encode(HTML::Entities::decode_entities($text));";
    const result=JSON.parse(execFileSync(command[0],[...command.slice(1),'-e',program],{input:JSON.stringify(text),encoding:'utf8',shell:false,maxBuffer:1024*1024}));
    entityCache.set(text,result);return result;
}

const ontology=[{cvterm_id:9,name:'Category_'+canonical+' </script><img src=x onerror="ontologyInjected=1">',children:[
    {cvterm_id:41,name:'Enum_'+canonical,definition:'Definition '+canonical,children:[{cvterm_id:411,name:canonical},{cvterm_id:412,name:'Not Recorded'}]},
    {cvterm_id:42,name:'Free_'+canonical,children:[]}
]}];
const command=JSON.parse(process.env.I18N_MAINTENANCE_RECORD_PERL_COMMAND||'["perl"]');
assert(Array.isArray(command)&&command.length&&command.every(v=>typeof v==='string'&&v.length),'Trusted explicit Perl argv; shell:false');
const perlProgram=[
    'use strict;use warnings;use utf8;use JSON::PP;use File::Temp qw(tempdir);use File::Path qw(make_path);use HTML::Mason::Interp;use SGN::I18N;',
    "binmode STDIN,':raw';binmode STDOUT,':raw';my $q=JSON::PP->new->utf8->decode(do{local $/;<STDIN>});my $tmp=tempdir(CLEANUP=>1);",
    "sub save_file{my($path,$text)=@_;my $dir=$path;$dir=~s{/[^/]+$}{};make_path($dir);open my $f,'>:encoding(UTF-8)',$path or die $!;print {$f} $text;close $f;}",
    'save_file("$tmp/comp/breeders_toolbox/seedlot_maintenance/record.mas",$q->{source});save_file("$tmp/comp/page/info_section.mas",$q->{info});save_file("$tmp/comp/page/page_title.mas",$q->{pageTitle});',
    '# Only the unrelated script import is inert; reviewed Mason, serializer, translator and shared section helper remain real.',
    'save_file("$tmp/comp/util/import_javascript.mas",\'<%args>$classes => []</%args><!-- controlled import boundary -->\');make_path("$tmp/catalog");',
    'if($q->{catalog}){make_path("$tmp/catalog/$q->{locale}");open my $f,">:raw","$tmp/catalog/$q->{locale}/sgn.json" or die $!;print {$f} JSON::PP->new->canonical->utf8->encode({schema=>1,api=>1,locale=>$q->{locale},direction=>$q->{locale} eq "ar"?"rtl":"ltr",sourceRevision=>"0"x64,nplurals=>1,pluralForms=>"nplurals=1; plural=0;",pluralAst=>{type=>"NUM",val=>0},messages=>$q->{catalog}});close $f;}',
    '{package Unit::Recorder::Context;sub new{bless{translator=>$_[1]},$_[0]}sub i18n{$_[0]->{translator}}}',
    'my $translator=SGN::I18N->new(locale=>$q->{locale},catalog_root=>"$tmp/catalog");my $c=Unit::Recorder::Context->new($translator);my $html="";',
    'my $interp=HTML::Mason::Interp->new(comp_root=>"$tmp/comp",data_dir=>"$tmp/cache",allow_globals=>[\'$c\'],preamble=>"use utf8;",out_method=>\\$html,autohandler_name=>"__unit_no_autohandler__");$interp->set_global(\'$c\',$c);srand(734);',
    '$interp->exec("/breeders_toolbox/seedlot_maintenance/record.mas",ontology=>$q->{ontology},info_event_cvterms=>$q->{info_event_cvterms},operator=>$q->{operator});',
    'print JSON::PP->new->canonical->utf8->encode({html=>$html,locale=>$translator->locale});'
].join('\n');
function identities(text){
    const quoted='("(?:\\\\.|[^"\\\\])*"|\'(?:\\\\.|[^\'\\\\])*\')';
    const expression=new RegExp('(?:\\$c->i18n->p|recordI18n\\.p)\\(\\s*'+quoted+'\\s*,\\s*'+quoted,'g');
    const unquote=token=>token[0]==='"'?JSON.parse(token):token.slice(1,-1).replace(/\\(['\\])/g,'$1');
    return [...text.matchAll(expression)].map(m=>({context:unquote(m[1]),source:unquote(m[2])}));
}
function translate(locale,text,variables={}){return ('TR['+locale+'] '+text+adverse).replace(/%\{([a-zA-Z0-9_]+)\}/g,(token,key)=>Object.hasOwn(variables,key)?String(variables[key]):token);}
const renderCache=new Map();
function render({text=source,locale='en',catalog=false,eventOntology=ontology,operator='Operator_'+canonical,infoCvterms=[41]}={}){
    const request={source:text,info,pageTitle,locale,ontology:eventOntology,operator,info_event_cvterms:infoCvterms};
    if(catalog){request.catalog={};for(const m of identities(text))request.catalog[m.context+'\u0004'+m.source]={plural:null,forms:[translate(locale,m.source)]};}
    const input=JSON.stringify(request);if(renderCache.has(input))return renderCache.get(input);
    const output=execFileSync(command[0],[...command.slice(1),'-e',perlProgram],{input,encoding:'utf8',shell:false,maxBuffer:8*1024*1024});
    const result=JSON.parse(output);renderCache.set(input,result);return result;
}
function inline(html){const blocks=[...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].filter(m=>m[1].includes('function submitEvents('));assert.equal(blocks.length,1,'Run the complete actual recorder script, not extracted handler substitutes');assert(!blocks[0][1].includes('<%'));return blocks[0][1];}
function node(tag='div',attrs={}){return {tag,attrs:{...attrs},props:{},data:{},classes:new Set(String(attrs.class||'').split(/\s+/).filter(Boolean)),children:[],parent:null,value:attrs.value||'',text:'',styles:{},handlers:{}};}
function descendants(n){return n.children.flatMap(child=>[child,...descendants(child)]);}
function textOf(n){return n.text+n.children.map(textOf).join('');}
function serialize(n){if(n.tag==='#text')return escape(n.text);const attrs={...n.attrs};if(n.classes.size)attrs.class=[...n.classes].join(' ');return '<'+n.tag+Object.entries(attrs).map(([k,v])=>' '+k+'="'+escape(v)+'"').join('')+'>'+escape(n.text)+n.children.map(serialize).join('')+'</'+n.tag+'>';}
function parseMarkup(html){
    const container=node('#fragment'),stack=[container];const parts=String(html).match(/<!--[\s\S]*?-->|<[^>]*>|[^<]+|</g)||[];
    for(const part of parts){if(part.startsWith('<!--'))continue;if(/^<\//.test(part)){const tag=/^<\/\s*([^\s>]+)/.exec(part)?.[1].toLowerCase();while(stack.length>1){if(stack.pop().tag===tag)break;}continue;}
        const opening=/^<\s*([a-z][a-z0-9]*)\b([\s\S]*?)\/?\s*>$/i.exec(part);
        if(opening){const attrs={};for(const m of opening[2].matchAll(/([\w:-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g))attrs[m[1]]=decode(m[2]??m[3]??m[4]??'');const child=node(opening[1].toLowerCase(),attrs);child.parent=stack.at(-1);child.parent.children.push(child);if(!/^(?:br|img|input|hr|meta|link|area|base|embed|param|source|track|wbr)$/.test(child.tag))stack.push(child);}
        else {const child=node('#text');child.text=decode(part);child.parent=stack.at(-1);child.parent.children.push(child);}
    }return container;
}
function matches(n,selector){
    if(n.tag==='#text')return false;const attrs=[...selector.matchAll(/\[([^\]=\s]+)(?:\s*=\s*['"]?([^\]'"\s]+)['"]?)?\]/g)];selector=selector.replace(/\[[^\]]*\]/g,'');
    for(const [,key,value]of attrs){if(!Object.hasOwn(n.attrs,key)||value!==undefined&&String(n.attrs[key])!==value)return false;}
    const id=/#([\w-]+)/.exec(selector);if(id&&n.attrs.id!==id[1])return false;for(const m of selector.matchAll(/\.([\w-]+)/g))if(!n.classes.has(m[1]))return false;
    const tag=/^([a-z][\w-]*)/i.exec(selector);return !tag||n.tag===tag[1].toLowerCase();
}
function select(nodes,selector){return [...new Set(selector.split(',').flatMap(part=>{const steps=part.trim().split(/\s+/);let current=nodes;for(const step of steps)current=current.flatMap(n=>descendants(n).filter(child=>matches(child,step)));return current;}))];}
function harness({text=source,query='',locale='uk',translator=false,eventOntology=ontology}={}){
    const rendered=render({text,eventOntology}),forest=parseMarkup(rendered.html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'').replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi,''));
    function inertNodes(html){const fragment=parseMarkup(html);for(const n of [fragment,...descendants(fragment)]){Object.defineProperties(n,{nodeType:{get:()=>n.tag==='#text'?3:1},tagName:{get:()=>n.tag.toUpperCase()},textContent:{get:()=>textOf(n)},childNodes:{get:()=>n.children}});n.getAttribute=key=>n.attrs[key]??null;}return fragment;}
    const document={documentElement:{lang:locale,getAttribute:key=>key==='data-sgn-locale'?locale:null},createTextNode(value){const n=node('#text');n.text=String(value);return n;},createElement(tag){assert.equal(tag,'template','Actual inert-template adapter is an explicit controlled DOM boundary');let content=inertNodes('');return {get content(){return content;},set innerHTML(html){content=inertNodes(html);}};}},documentNode=node('#document'),windowNode=node('#window');
    const requests=[],htmlWrites=[],translationCalls=[],delegated=[],scrollCalls=[];
    const window={location:{href:'http://127.0.0.1:18335/breeders/seedlot/maintenance/record'+query,origin:'http://127.0.0.1:18335',search:query},scrollTo:(...args)=>scrollCalls.push(args)};
    if(translator)window.SGN={i18n:{requestedLocale:'ar',p(context,source,variables){translationCalls.push({context,source,variables:plain(variables||{})});return translate(locale,source,variables);}}};
    function jq(value){let nodes;if(value===document)nodes=[documentNode];else if(value===window)nodes=[windowNode];else if(value?.nodes)nodes=value.nodes;else if(typeof value==='string')nodes=value.startsWith('<')?parseMarkup(value).children:select([forest],value);else nodes=value?[value]:[];
        const api={nodes,e:nodes[0],length:nodes.length};nodes.forEach((n,i)=>api[i]=n);
        const mutate=fn=>{nodes.forEach(fn);return api;};
        api.ready=callback=>{callback();return api;};api.first=()=>jq(nodes[0]);
        api.val=function(value){if(arguments.length)return mutate(n=>{n.value=String(value??'');});return nodes[0]?.value;};
        api.text=function(value){if(arguments.length)return mutate(n=>{n.text=String(value??'');n.children=[];});return nodes.map(textOf).join('');};
        api.html=function(value){if(arguments.length)return mutate(n=>{htmlWrites.push({node:n,value:String(value??'')});n.text='';n.children=parseMarkup(value??'').children;for(const child of n.children)child.parent=n;});return nodes[0]?escape(nodes[0].text)+nodes[0].children.map(serialize).join(''):undefined;};
        api.attr=function(key,value){if(typeof key==='object')return mutate(n=>{Object.assign(n.attrs,key);if(key.class!==undefined)n.classes=new Set(String(key.class).split(/\s+/).filter(Boolean));});if(arguments.length>1)return mutate(n=>{if(value===false||value===null){delete n.attrs[key];n.props[key]=false;}else{n.attrs[key]=String(value);if(key==='disabled')n.props.disabled=!!value;if(key==='class')n.classes=new Set(String(value).split(/\s+/).filter(Boolean));}});return nodes[0]?.attrs[key];};
        api.removeAttr=key=>mutate(n=>{delete n.attrs[key];});
        api.prop=function(key,value){if(arguments.length>1)return mutate(n=>{n.props[key]=value;});return nodes[0]?.props[key]??Object.hasOwn(nodes[0]?.attrs||{},key);};
        api.data=function(key,value){if(arguments.length>1)return mutate(n=>{n.data[key]=value;});const n=nodes[0];if(!n)return undefined;if(Object.hasOwn(n.data,key))return n.data[key];const raw=n.attrs['data-'+key];if(raw===undefined)return undefined;return String(+raw)===raw?+raw:raw;};
        api.css=function(key,value){if(typeof key==='object')return mutate(n=>Object.assign(n.styles,key));if(arguments.length>1)return mutate(n=>{n.styles[key]=value;});return nodes[0]?.styles[key]??(key==='display'&&nodes[0]?.classes.has('seedlot_event_notes_input_div')?'none':'block');};
        api.empty=()=>mutate(n=>{n.text='';n.children=[];});
        api.append=(...children)=>mutate(n=>{for(const child of children.flat()){const added=child?.nodes||typeof child==='string'?child?.nodes||parseMarkup(child).children:[child];for(const c of added){if(!c)continue;c.parent=n;n.children.push(c);}}});
        api.appendTo=target=>{jq(target).append(api);return api;};
        api.find=selector=>jq({nodes:select(nodes,selector)});
        api.parent=selector=>jq({nodes:[...new Set(nodes.map(n=>n.parent).filter(n=>n&&(!selector||matches(n,selector))))]});
        api.each=callback=>{nodes.forEach((n,i)=>callback.call(n,i,n));return api;};
        api.addClass=classes=>mutate(n=>{for(const c of classes.split(/\s+/))n.classes.add(c);});api.removeClass=classes=>mutate(n=>{for(const c of classes.split(/\s+/))n.classes.delete(c);});api.hasClass=cls=>nodes.some(n=>n.classes.has(cls));
        for(const event of ['click','change'])api[event]=callback=>mutate(n=>{n.handlers[event]=callback;});
        api.bind=(event,callback)=>mutate(n=>{n.handlers[event]=callback;});
        api.on=(event,selector,callback)=>{if(typeof selector==='function')return mutate(n=>{n.handlers[event]=selector;});delegated.push({event,selector,callback});return api;};
        api.autocomplete=options=>mutate(n=>{n.autocomplete=options;});api.modal=value=>mutate(n=>{n.modal=value;});
        return api;
    }
    jq.ajax=options=>{const request={options,deliver(data){options.success?.(data);options.complete?.();},fail(error='Transport_'+canonical){options.error?.(error);options.complete?.();}};requests.push(request);options.beforeSend?.();return request;};
    class FrozenDate extends Date{constructor(...args){super(...(args.length?args:[2026,9,11,4,5,6]));}}

    const context=vm.createContext({window,document,jQuery:jq,URL,URLSearchParams,Date:FrozenDate,console});vm.runInContext(inline(rendered.html),context,{filename:file});
    const one=selector=>{const value=jq(selector);assert.equal(value.length,1,'Exactly one control '+selector);return value;};
    function trigger(target,event='click'){const n=typeof target==='string'?one(target).e:target;assert(n);if(n.tag==='button')assert.equal(!!n.props.disabled||Object.hasOwn(n.attrs,'disabled'),false,'Source-unit trigger uses an enabled control');const handler=n.handlers[event];if(handler)return handler.call(n,{preventDefault(){}});const d=delegated.find(item=>item.event===event&&matches(n,item.selector));assert(d,'Actual registered delegated handler exists');return d.callback.call(n,{preventDefault(){}});}
    function pick(index=1){const buttons=jq('.seedlot_event_values').first().find('.seedlot_event_value_btn');trigger(buttons[index]);}
    function sourceReply(name=literal){return {data:[{seedlot_stock_id:17,seedlot_stock_uniquename:name,contents_html:'<a href="/stock/18/view">'+escape(canonical)+'</a> (accession)',location:'Location_'+canonical,box:'Box_'+canonical}]};}
    function lookup(name=literal){one('#seedlot_event_name').val(name);trigger('#seedlot_event_name_update');const req=requests.at(-1);req.deliver(sourceReply(name));return req;}
    return {context,window,document,forest,jq,one,requests,htmlWrites,translationCalls,scrollCalls,trigger,pick,lookup,sourceReply,windowNode,textOf};
}
function query(value){return '?'+new URLSearchParams({seedlot_name:value,lang:'uk'}).toString();}
function eventPosts(h){return h.requests.filter(r=>/^\/ajax\/breeders\/seedlot\/\d+\/maintenance$/.test(r.options.url));}
function activeNodes(h){return descendants(h.forest).filter(n=>n.tag==='script'||n.tag==='img'&&!(n.classes.has('collapser_img')&&/^\/documents\/img\/collapser_(?:plus|minus)\.png$/.test(n.attrs.src||''))||Object.keys(n.attrs).some(key=>key==='onerror'||key==='data-record-injection'||key==='onclick'&&!n.classes.has('collapser')));}

test('real whole Mason serializer keeps canonical ontology and operator data inert and exact',()=>{
    const r=render({locale:'uk',catalog:true});assert.equal(r.locale,'uk');const h=harness();
    assert.deepEqual(plain(vm.runInContext('ONTOLOGY',h.context)),ontology,'Actual Mason ontology JSON carries all scientific fields exactly');
    assert.equal(h.one('#seedlot_event_operator').val(),'Operator_'+canonical);assert.deepEqual(activeNodes(h),[]);
    const ids=new Map(identities(source).map(m=>[m.context,m.source]));assert.equal(ids.size,33);assert([...ids.keys()].every(k=>k.startsWith('seedlot_record.ui.')));
    for(const locale of ['uk','es','ar']){const translated=render({locale,catalog:true});assert.equal(translated.locale,locale);assert(!translated.html.includes('<img src=x onerror='));assert(!translated.html.includes('<script data-record-injection='));const dom=parseMarkup(translated.html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,''));const anchors=descendants(dom).filter(n=>n.tag==='a'&&n.classes.has('info_section_anchor')).map(n=>n.attrs.name);assert.deepEqual(anchors,['seedlot','maintenance_events','usernametimestamp']);}
    const missing=render({locale:'uk',catalog:true,eventOntology:null});assert(missing.html.includes('TR[uk]'));assert(missing.html.includes('Seedlot Maintenance Event Ontology not loaded!'));assert(!missing.html.includes('<img src=x onerror='));assert(!missing.html.includes('function submitEvents('));
    for(const cvterms of [[],[41]]){const html=render({infoCvterms:cvterms}).html;const dom=parseMarkup(html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,''));assert.equal(select([dom],'.seedlot_event_info_cvterm_row').length,cvterms.length);}
});
test('raw typed/prefilled scientific names and own same-origin locale reach structured native lookup unchanged',()=>{
    for(const name of [literal,'literal_seedlot_name=part_+_&_%','%2F_%{names}']){
        const h=harness({query:query(name),translator:true});assert.equal(h.one('#seedlot_event_name').val(),name);const o=h.requests[0].options;
        assert.equal(o.type,'GET');assert.equal(o.url,'/ajax/breeders/seedlots');assert.deepEqual(plain(o.data),{seedlot_name:name});assert.deepEqual(plain(o.headers),{'X-SGN-Locale':'uk'});
    }
});
test('lookup/recent-event registered handlers keep scientific fields in text and preserve canonical search body',()=>{
    const h=harness({translator:true});h.lookup();
    assert.equal(h.one('#seedlot_event_contents').text(),canonical+' (accession)');assert.equal(h.one('#seedlot_event_contents').find('a').attr('href'),'/stock/18/view');
    assert.equal(h.one('#seedlot_event_location').text(),'Location_'+canonical);assert.equal(h.one('#seedlot_event_box').text(),'Box_'+canonical);
    const recent=h.requests.find(r=>r.options.url==='/ajax/breeders/seedlot/maintenance/search');assert(recent);assert.deepEqual(JSON.parse(recent.options.data),{filters:{names:[{comp:'=',value:literal}],types:[{cvterm_id:41}]}});
    recent.deliver({results:[{cvterm_name:canonical,value:'0',notes:'Notes_'+canonical,timestamp:'2026-10-11 00:00:00'}]});
    assert.equal(h.one('.seedlot_event_info_cvterm_event').text(),canonical);assert.equal(h.one('.seedlot_event_info_cvterm_value').text(),'0');assert.equal(h.one('.seedlot_event_info_cvterm_notes').text(),'Notes_'+canonical);assert.equal(h.one('.seedlot_event_info_cvterm_timestamp').text(),'2026-10-11 00:00:00');
    assert.deepEqual(activeNodes(h),[]);assert(!h.htmlWrites.some(w=>w.value.includes(canonical)),'Raw scientific values never enter an HTML sink');
});
test('only enum clicks enable pending submit; free values/notes and inherited hide-notes no-op stay unchanged',()=>{
    const h=harness();assert.equal(h.one('#seedlot_event_submit').prop('disabled'),true);assert.equal(vm.runInContext('PENDING_CHANGES',h.context),false);
    h.one('.seedlot_event_value_input').val('Free_'+canonical);h.one('#seedlot_event_notes_input_div_42').find('textarea').val('Notes_'+canonical);
    assert.equal(h.one('#seedlot_event_submit').prop('disabled'),true);assert.equal(vm.runInContext('PENDING_CHANGES',h.context),false);
    const noteButton=h.jq('.seedlot_event_notes_btn').nodes.find(n=>h.jq(n).data('cvterm')===42);h.trigger(noteButton);h.trigger(noteButton);
    assert.equal(h.one('#seedlot_event_notes_input_div_42').find('textarea').val(),'Notes_'+canonical,'Original missing-ID clear is still a no-op');
    h.pick();assert.equal(vm.runInContext('PENDING_CHANGES',h.context),true);assert.equal(h.one('#seedlot_event_submit').prop('disabled'),false);
    const e={originalEvent:{}};const message=h.windowNode.handlers.beforeunload(e);assert.equal(message,e.originalEvent.returnValue);assert(message.includes('pending changes'));
});
test('canonical enum .data and free value/notes/operator/timestamp retain exact native POST schema',()=>{
    const h=harness({translator:true});h.lookup();h.pick();h.one('.seedlot_event_value_input').val('Free_'+canonical);h.one('#seedlot_event_notes_input_div_41').find('textarea').val('Notes_'+canonical);
    h.one('#seedlot_event_operator').val('Operator_'+canonical);assert.equal(h.one('#seedlot_event_timestamp').val(),'2026-10-11 04:05:06');h.trigger('#seedlot_event_submit');
    const request=eventPosts(h).at(-1);assert(request);assert.equal(request.options.type,'POST');assert.equal(request.options.contentType,'application/json; charset=utf-8');assert.deepEqual(plain(request.options.headers),{'X-SGN-Locale':'uk'});
    assert.deepEqual(JSON.parse(request.options.data),{events:[{cvterm_id:41,value:canonical,notes:'Notes_'+canonical,operator:'Operator_'+canonical,timestamp:'2026-10-11 04:05:06'},{cvterm_id:42,value:'Free_'+canonical,operator:'Operator_'+canonical,timestamp:'2026-10-11 04:05:06'}]});
    request.deliver({events:[{},{}]});assert.equal(vm.runInContext('PENDING_CHANGES',h.context),false);assert.equal(h.one('#seedlot_event_submit').prop('disabled'),true);assert.equal(h.scrollCalls.length,1);
    assert(h.one('#seedlot_modal_body').text().includes(literal),'Raw scientific name is substituted once, including literal named-token text');assert.deepEqual(activeNodes(h),[]);
});
test('English Not Recorded exclusion remains canonical in sentinel, enum and free-input cases',()=>{
    for(const index of [0,2]){
        const h=harness({translator:true});h.lookup();h.pick(index);h.one('.seedlot_event_value_input').val('Not Recorded');h.trigger('#seedlot_event_submit');
        assert.equal(eventPosts(h).length,0);assert(h.one('#seedlot_modal_body').text().includes('One or more Events must be recorded'));assert.equal(vm.runInContext('PENDING_CHANGES',h.context),true);assert.deepEqual(activeNodes(h),[]);
    }
});
test('catalog/database/transport diagnostics remain plain modal text; failed submissions preserve pending state',()=>{
    for(const failure of ['database','unknown','transport']){
        const h=harness({translator:true});h.lookup();h.pick();h.trigger('#seedlot_event_submit');const request=eventPosts(h).at(-1);const diagnostic='Diagnostic_'+canonical+adverse;
        if(failure==='transport')request.fail(diagnostic);else request.deliver(failure==='database'?{error:diagnostic}:{});
        if(failure!=='unknown')assert(h.one('#seedlot_modal_body').text().includes(diagnostic));assert.equal(vm.runInContext('PENDING_CHANGES',h.context),true);assert.equal(h.one('#seedlot_event_submit').prop('disabled'),false);assert.deepEqual(activeNodes(h),[]);
        h.trigger('#seedlot_modal_close');assert.deepEqual(plain(vm.runInContext('MESSAGES',h.context)),[]);
    }
});
test('scanner returns the original recorder path and locale; missing helper retains English fallback',()=>{
    const h=harness();h.trigger('#seedlot_event_name_barcode');const scanner=new URL(h.window.location,'http://127.0.0.1:18335');assert.equal(scanner.pathname,'/barcode/read');assert.equal(scanner.searchParams.get('param'),'seedlot_name');assert.equal(scanner.searchParams.get('lang'),'uk');
    const returned=new URL(scanner.searchParams.get('return'),'http://127.0.0.1:18335');assert.equal(returned.pathname,'/breeders/seedlot/maintenance/record');assert.equal(returned.searchParams.get('lang'),'uk');
    h.pick();h.trigger('#seedlot_event_submit');assert(h.one('#seedlot_modal_body').text().includes('Please enter a valid Seedlot name'));
});
test('locale remains inside admitted same-origin routes and autocomplete/scanner return raw values',()=>{
    const h=harness({locale:'en',translator:true});
    for(const url of ['/ajax/breeders/seedlots','/ajax/stock/seedlot_name_autocomplete','/ajax/breeders/seedlot/maintenance/search','/ajax/breeders/seedlot/17/maintenance'])assert.deepEqual(plain(h.context.recordLocaleHeaders(url)),{'X-SGN-Locale':'en'});
    for(const url of ['https://foreign.test/ajax/breeders/seedlots','/ajax/breeders/seedlot/17/maintenance/12','/ajax/breeders/seedlot/0/maintenance','/ajax/breeders/seedlot/maintenance/upload','/ajax/unknown','http://['])assert.deepEqual(plain(h.context.recordLocaleHeaders(url)),{});
    let result;h.one('#seedlot_event_name').e.autocomplete.source({term:literal},values=>{result=values;});const request=h.requests.at(-1);assert.equal(request.options.url,'/ajax/stock/seedlot_name_autocomplete');assert.deepEqual(plain(request.options.data),{term:literal});assert.deepEqual(plain(request.options.headers),{'X-SGN-Locale':'en'});request.deliver([literal]);assert.deepEqual(result,[literal]);
    for(const tail of ['https://example.test/path?seedlot_name='+encodeURIComponent(literal),'/path?seedlot_name='+literal]){const scan=harness({query:query(tail)});assert.equal(scan.one('#seedlot_event_name').val(),literal);}
});
if(process.env.I18N_MAINTENANCE_RECORD_BEFORE_SOURCE)test('actual original whole script reproduces malformed percent query and unsafe scientific URL',()=>{
    const before=fs.readFileSync(process.env.I18N_MAINTENANCE_RECORD_BEFORE_SOURCE,'utf8');
    // Benign ontology isolates the old scientific URL failure from its JS-string serializer.
    const old=harness({text:before,eventOntology:[{name:'Category',children:[]}]});old.one('#seedlot_event_name').val(literal);old.trigger('#seedlot_event_name_update');const url=old.requests.at(-1).options.url;assert.equal(url,'/ajax/breeders/seedlots?seedlot_name='+literal);assert.notEqual(new URL(url,'http://127.0.0.1:18335').searchParams.get('seedlot_name'),literal);
    assert.throws(()=>harness({text:before,eventOntology:[{name:'Category',children:[]}],query:query('%{names}')}),error=>error.name==='URIError');
});
test('armed actual vendored jQuery/template carrier creates no active scientific/diagnostic DOM or injected requests',{
    skip:process.env.I18N_MAINTENANCE_RECORD_BROWSER!=='1'?'Explicit Root-owned exclusive browser window required':false,timeout:30000
},async()=>{
    const {chromium}=require(process.env.I18N_PLAYWRIGHT_PATH||'playwright');const browser=await chromium.launch({headless:true});const context=await browser.newContext();
    try{
        const page=await context.newPage(),errors=[],network=[];page.on('pageerror',error=>errors.push(error.message));await context.route('**/*',async route=>{network.push(route.request().url());await route.abort();});
        const rendered=render(),script=inline(rendered.html);await page.setContent(rendered.html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,''));
        for(const name of ['jquery.js','jquerymigrate.js','jqueryui.js','bootstrap_min.js'])await page.addScriptTag({path:path.join(root,'js/source/legacy',name)});
        await page.evaluate(()=>{window.recordUnitRequests=[];jQuery.ajax=options=>{recordUnitRequests.push(options);options.beforeSend?.();return {};};});await page.addScriptTag({content:script});await page.waitForFunction(()=>document.querySelectorAll('.seedlot_event_title').length===2);network.length=0;
        const injection='<img src="https://record-unit.invalid/image" onerror="window.recordUnitInjected=1"><iframe src="https://record-unit.invalid/frame"></iframe><script>window.recordUnitInjected=1</script>';
        await page.evaluate(({canonical,injection})=>{
            ONTOLOGY[0].children[0].definition='Definition '+injection;setEvents();
            const escaped=canonical.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));setSeedlotContents('<a href="/stock/18/view">'+escaped+'</a> (accession)'+injection);displayError('Catalog '+injection,'Diagnostic '+injection);
        },{canonical,injection});
        await page.waitForTimeout(50);assert.equal(await page.locator('#seedlot_event_contents a').textContent(),canonical);assert.equal(await page.locator('#seedlot_event_contents a').getAttribute('href'),'/stock/18/view');
        assert.equal(await page.locator('#seedlot_event_container img,#seedlot_event_container iframe,#seedlot_event_container script,#seedlot_event_contents img,#seedlot_event_contents iframe,#seedlot_event_contents script,#seedlot_modal_body img,#seedlot_modal_body iframe,#seedlot_modal_body script').count(),0);
        assert.equal(await page.locator('#seedlot_modal_body code').textContent(),'Diagnostic '+injection);assert.equal(await page.evaluate(()=>window.recordUnitInjected),undefined);assert.deepEqual(errors,[]);assert.deepEqual(network,[]);
    }finally{await context.close();await browser.close();}
});
