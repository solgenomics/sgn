'use strict';
// Real whole Mason/Perl rendering of the reviewed main and info_section.
// Unrelated workflow children and user data are explicit controlled boundaries;
// no native HTTP, database, browser, authentication or layout claim is made.
const assert=require('node:assert/strict'),test=require('node:test');
const fs=require('node:fs'),path=require('node:path');
const {execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../../..');
const mainPath=path.join(root,'mason/breeders_toolbox/seedlot_maintenance/main.mas');
const infoPath=path.join(root,'mason/page/info_section.mas');
const main=fs.readFileSync(mainPath,'utf8'),info=fs.readFileSync(infoPath,'utf8');
const pageTitle=fs.readFileSync(path.join(root,'mason/page/page_title.mas'),'utf8');
const identities=[...main.matchAll(/\$c->i18n->p\(\s*'([^']+)',\s*'((?:\\.|[^'])*)'/g)].map(m=>({context:m[1],source:m[2].replace(/\\'/g,"'").replace(/\\\\/g,'\\')}));
const unique=new Map(identities.map(m=>[m.context,m]));
assert.equal(unique.size,13,'Exact thirteen source-owned server messages');
assert([...unique.keys()].every(k=>k.startsWith('seedlot_maintenance.ui.')));
const command=JSON.parse(process.env.I18N_MAINTENANCE_MAIN_PERL_COMMAND || '["perl"]');
assert(Array.isArray(command)&&command.length&&command.every(x=>typeof x==='string'&&x.length),'Trusted explicit Perl argv; no shell');
const perlProgram=[
    "use strict;use warnings;use utf8;",
    "use JSON::PP;use File::Temp qw(tempdir);use File::Path qw(make_path);",
    "use HTML::Mason::Interp;use HTML::Parser;use SGN::I18N;",
    "binmode STDIN,':raw';binmode STDOUT,':raw';",
    "my $q=JSON::PP->new->utf8->decode(do{local $/;<STDIN>});",
    "my $tmp=tempdir(CLEANUP=>1);",
    "sub save_file{my($path,$text)=@_;my $dir=$path;$dir=~s{/[^/]+$}{};make_path($dir);open my $f,'>:encoding(UTF-8)',$path or die $!;print {$f} $text;close $f;}",
    "save_file(\"$tmp/comp/breeders_toolbox/seedlot_maintenance/main.mas\",$q->{main});",
    "save_file(\"$tmp/comp/page/info_section.mas\",$q->{info});",
    "save_file(\"$tmp/comp/page/page_title.mas\",$q->{pageTitle});",
    "# Only unrelated child-rendering boundaries are inert. The reviewed components,",
    "# Mason compiler, translator and collapser implementation are real and unchanged.",
    "save_file(\"$tmp/comp/util/import_javascript.mas\",'<%args>$classes => []</%args><!-- controlled import boundary -->');",
    "save_file(\"$tmp/comp/breeders_toolbox/seedlot_maintenance/tools.mas\",'<%args>$collapsed => 1</%args><div data-unit-dependency=\"tools\"></div>');",
    "save_file(\"$tmp/comp/breeders_toolbox/seedlot_maintenance/table.mas\",'<div data-unit-dependency=\"event-table\"></div>');",
    "save_file(\"$tmp/comp/breeders_toolbox/seedlot_maintenance/upload_dialog.mas\",'<div data-unit-dependency=\"event-upload\"></div>');",
    "make_path(\"$tmp/catalog\");",
    "if($q->{catalog}){",
    " my $catalog_path=\"$tmp/catalog/$q->{locale}/sgn.json\";make_path(\"$tmp/catalog/$q->{locale}\");",
    " open my $catalog_file,\">:raw\",$catalog_path or die $!;",
    " print {$catalog_file} JSON::PP->new->canonical->utf8->encode({",
    "  schema=>1,api=>1,locale=>$q->{locale},direction=>$q->{locale} eq 'ar'?'rtl':'ltr',",
    "  sourceRevision=>'0'x64,nplurals=>1,pluralForms=>'nplurals=1; plural=0;',",
    "  pluralAst=>{type=>'NUM',val=>0},messages=>$q->{catalog}});close $catalog_file;",
    "}",
    "{",
    " package Unit::Maintenance::User;",
    " sub new{bless{role=>$_[1]},$_[0]}sub check_roles{$_[0]->{role} eq $_[1]}",
    " package Unit::Maintenance::Context;",
    " sub new{bless{translator=>$_[1],role=>$_[2]},$_[0]}",
    " sub i18n{$_[0]->{translator}}",
    " sub user{return undef if $_[0]->{role} eq 'anonymous';Unit::Maintenance::User->new($_[0]->{role})}",
    "}",
    "my $translator=SGN::I18N->new(locale=>$q->{locale},catalog_root=>\"$tmp/catalog\");",
    "my $c=Unit::Maintenance::Context->new($translator,$q->{role});",
    "my $html='';",
    "my $interp=HTML::Mason::Interp->new(comp_root=>\"$tmp/comp\",data_dir=>\"$tmp/mason-cache\",",
    " allow_globals=>['$c'],preamble=>'use utf8;',out_method=>\\$html,autohandler_name=>'__unit_no_autohandler__');",
    "$interp->set_global('$c',$c);srand(734);",
    "if(($q->{component}//'main') eq 'info'){",
    " my %args=(title=>$q->{title},contents=>'<p>Controlled caller body</p>',collapsible=>0,id=>'unchanged-unit-section');",
    " $args{anchor_title}=$q->{anchorTitle} if exists $q->{anchorTitle};",
    " $interp->exec('/page/info_section.mas',%args);",
    "}else{",
    " $interp->exec('/breeders_toolbox/seedlot_maintenance/main.mas',tool=>$q->{tool});",
    "}",
    "my(@anchors,@links,@buttons,@paragraphs,@strong,@titles,@sections,@subtitles,@scripts,@bad,@stack);",
    "my $parser=HTML::Parser->new(api_version=>3,",
    " start_h=>[sub{",
    "  my($tag,$attr)=@_;my @targets;",
    "  push @anchors,$attr->{name} if $tag eq 'a'&&($attr->{class}//'')=~/\\binfo_section_anchor\\b/;",
    "  for my $key(keys %$attr){push @bad,{tag=>$tag,attribute=>$key,value=>$attr->{$key}} if $key eq 'onerror'||$key=~/^data-maintenance-injection/;}",
    "  if($tag eq 'a'&&exists $attr->{href}){my $v={href=>$attr->{href},text=>''};push @links,$v;push @targets,$v;}",
    "  if($tag eq 'button'){my $v={id=>$attr->{id},text=>''};push @buttons,$v;push @targets,$v;}",
    "  if($tag eq 'p'){my $v={text=>''};push @paragraphs,$v;push @targets,$v;}",
    "  if($tag eq 'strong'){my $v={text=>''};push @strong,$v;push @targets,$v;}",
    "  if($tag eq 'h3'){my $v={text=>''};push @titles,$v;push @targets,$v;}",
    "  if($tag eq 'td'&&($attr->{class}//'')=~/\\binfosectiontitle\\b/){my $v={text=>''};push @sections,$v;push @targets,$v;}",
    "  if($tag eq 'td'&&($attr->{class}//'')=~/\\binfosectionsubtitle\\b/){my $v={text=>''};push @subtitles,$v;push @targets,$v;}",
    "  if($tag eq 'script'){my $v={text=>''};push @scripts,$v;push @targets,$v;}",
    "  push @stack,{tag=>$tag,targets=>\\@targets} unless $tag=~/\\A(?:br|img|input|hr|meta|link|area|base|embed|param|source|track|wbr)\\z/;",
    " },'tagname,attr'],",
    " text_h=>[sub{my $text=$_[0];for my $entry(@stack){$_->{text}.=$text for @{$entry->{targets}};}},'dtext'],",
    " end_h=>[sub{my $tag=$_[0];while(@stack){last if pop(@stack)->{tag} eq $tag;}},'tagname']);",
    "$parser->parse($html);$parser->eof;",
    "print JSON::PP->new->canonical->utf8->encode({html=>$html,locale=>$translator->locale,",
    " anchors=>\\@anchors,links=>\\@links,buttons=>\\@buttons,paragraphs=>\\@paragraphs,strong=>\\@strong,",
    " titles=>\\@titles,sections=>\\@sections,subtitles=>\\@subtitles,scripts=>\\@scripts,bad=>\\@bad});"
].join("\n");
const adverse=' <img src=x onerror="window.injected=1"> <script data-maintenance-injection="x">bad()</script> <strong>catalog markup</strong> &amp; "literal"';
const normalize=s=>String(s).replace(/\s+/g,' ').trim();
function catalog(locale,mode='normal'){
    const messages={};
    for(const m of unique.values()){
        let form='Переклад_'+locale+'_'+m.source+adverse;
        if(mode==='repeat'&&m.context.endsWith('.record_help'))form=form.replace('%{record_button}','%{record_button} and %{record_button}');
        if(mode==='repeat'&&m.context.endsWith('.view_help'))form=form.replace('%{seedlots_link}','%{seedlots_link} and %{seedlots_link}');
        if(mode==='literal_markers')form+='\uFDD0record_button\uFDD1 plain literal noncharacters';
        if(mode==='unknown'&&m.context.endsWith('.record_help'))form+=' %{unknown_slot}';
        if(mode==='unknown'&&m.context.endsWith('.view_help'))form+=' %{unknown_slot}';
        if(mode==='missing'&&m.context.endsWith('.record_help'))form=form.replace('%{upload_button}','removed required token');
        if(mode==='missing'&&m.context.endsWith('.view_help'))form=form.replace('%{download_link}','removed required token');
        messages[m.context+'\u0004'+m.source]={plural:null,forms:[form]};
    }
    return messages;
}
function render({role='curator',locale='en',mode,tool=null,mainSource=main,infoSource=info,component='main',title,anchorTitle}={}){
    const request={main:mainSource,info:infoSource,pageTitle,role,locale,tool,component};
    if(mode)request.catalog=catalog(locale,mode);
    if(title!==undefined)request.title=title;if(anchorTitle!==undefined)request.anchorTitle=anchorTitle;
    const output=execFileSync(command[0],[...command.slice(1),'-e',perlProgram],{input:JSON.stringify(request),encoding:'utf8',shell:false,maxBuffer:4*1024*1024});
    return JSON.parse(output);
}
function functional(r){
    return {anchors:r.anchors,links:r.links.filter(x=>['/breeders/seedlots','/breeders/download'].includes(x.href)).map(x=>({...x,text:normalize(x.text)})),
        buttons:r.buttons.map(x=>({...x,text:normalize(x.text)})),paragraphs:r.paragraphs.map(x=>normalize(x.text)),
        titles:r.titles.map(x=>normalize(x.text)),sections:r.sections.map(x=>normalize(x.text)),subtitles:(r.subtitles || []).map(x=>normalize(x.text)),scripts:r.scripts.map(x=>x.text)};
}
function safe(r){
    assert.deepEqual(r.bad,[],'Catalog text creates no active event/injection attribute');
    assert(!r.html.includes('<img src=x onerror='),'Authored catalogue markup is escaped');
    assert.equal(r.html.includes('<script data-maintenance-injection='),false);
    assert(r.links.filter(x=>['/breeders/seedlots','/breeders/download'].includes(x.href)).every(x=>!x.href.includes('catalog')),'Only fixed original help hrefs');
}
test('whole real Mason role/tool branches preserve English labels, IDs, anchors and handlers',()=>{
    for(const role of ['anonymous','ordinary','curator','submitter'])for(const tool of [null,'split_seedlot']){
        const r=render({role,tool});safe(r);assert.deepEqual(r.anchors,['about_seedlot_maintenance','seedlot_maintenance_tools','seedlot_maintenance_events']);
        assert.deepEqual(r.buttons.map(x=>x.id),['curator','submitter'].includes(role)?['record_events','upload_events']:[]);
        if(role==='curator'||role==='submitter')assert.deepEqual(r.buttons.map(x=>normalize(x.text)),['Record Maintenace','Upload Maintenance'],'Original toolbar typo remains separate from correct help label');
        assert.equal(r.paragraphs.length,3);assert.deepEqual(r.strong.map(x=>normalize(x.text)),['Record Maintenance','Upload Maintenance','Manage > Seedlots','Manage > Download']);
        assert(r.scripts.some(x=>x.text.includes("window.location = '/breeders/seedlot/maintenance/record'")));
        assert(r.scripts.some(x=>x.text.includes("jQuery('#upload_maintenance_event_upload_modal').modal")));
    }
});
test('real installed-language catalogue translates server text while all markup slots stay authored',()=>{
    for(const locale of ['uk','es','ar'])for(const role of ['anonymous','curator']){
        const r=render({locale,role,mode:'normal'});safe(r);assert.equal(r.locale,locale);
        assert.deepEqual(r.anchors,['about_seedlot_maintenance','seedlot_maintenance_tools','seedlot_maintenance_events'],'Translated captions never rename legacy section anchors');
        assert(r.paragraphs.every(p=>p.text.includes('Переклад_'+locale+'_')));
        assert(r.titles[0].text.includes('Переклад_'+locale+'_Seedlot Maintenance'));
        assert.equal(r.strong.length,4);assert.equal(r.links.filter(x=>['/breeders/seedlots','/breeders/download'].includes(x.href)).length,2);
        if(role==='anonymous')assert((r.subtitles || []).some(x=>x.text.includes('Переклад_'+locale+'_Login to add Seedlot maintenance events')));
        assert(r.buttons.every(b=>b.text.includes(adverse)),'Adverse labels survive exact entity decoding as text');
    }
});
test('uninstalled catalogue falls back to the complete English whole template',()=>{
    assert.deepEqual(functional(render({locale:'uk'})),functional(render({locale:'en'})));
});
test('accepted repeated known help slots render per occurrence without inventing markup',()=>{
    const r=render({locale:'uk',mode:'repeat'});safe(r);
    assert(r.paragraphs[1].text.startsWith('Переклад_uk_'));assert(r.paragraphs[2].text.startsWith('Переклад_uk_'));
    assert.equal(r.strong.length,6);assert.equal(r.links.filter(x=>x.href==='/breeders/seedlots').length,2);
    assert.equal(r.links.filter(x=>x.href==='/breeders/download').length,1);
});
test('literal noncharacters are plain translated data and cannot become help slots',()=>{
    const r=render({locale:'uk',mode:'literal_markers'});safe(r);
    // HTML::Parser replaces numeric references to Unicode noncharacters with U+FFFD.
    // Prove exact authored HTML references before that parser boundary, then prove
    // they never become additional slots or markup. No scientific data is normalized.
    const paragraphs=[...r.html.matchAll(/<p>([\s\S]*?)<\/p>/g)];
    assert.equal(paragraphs.length,3);
    assert(paragraphs.every(p=>p[1].includes('&#xFDD0;record_button&#xFDD1;')));
    assert(r.paragraphs.every(p=>p.text.includes('\uFFFDrecord_button\uFFFD')));assert.equal(r.strong.length,4);
});
test('missing required tokens fall back safely to complete original authored paragraphs',()=>{
    for(const mode of ['missing']){
        const r=render({locale:'uk',mode});safe(r);assert.equal(r.paragraphs.length,3);
        assert(normalize(r.paragraphs[1].text).startsWith('To record a new maintenance event for a particular Seedlot, use the '));
        assert(normalize(r.paragraphs[2].text).startsWith('You can view the maintenance events for a single Seedlot on the Seedlot detail page by going to the '));
        assert(!r.paragraphs[1].text.includes('%{unknown_slot}'));assert(!r.paragraphs[2].text.includes('%{unknown_slot}'));
        assert.equal(r.strong.length,4);assert.equal(r.links.filter(x=>['/breeders/seedlots','/breeders/download'].includes(x.href)).length,2);
    }
});
test('real formatter rejects an unknown named variable outside accepted catalogue scope',()=>{
    assert.throws(()=>render({locale:'uk',mode:'unknown'}),error=>error.status!==0 && /unknown_slot/.test(String(error.stderr || error.message)),
        'Actual SGN::I18N formatter rejects the invalid translation; no fake translator or product catch');
});
const beforeMain=process.env.I18N_MAINTENANCE_MAIN_BEFORE_SOURCE,beforeInfo=process.env.I18N_MAINTENANCE_INFO_BEFORE_SOURCE;
if(beforeMain||beforeInfo){
    assert(beforeMain&&beforeInfo,'Both exact original snapshots required');
    const oldMain=fs.readFileSync(beforeMain,'utf8'),oldInfo=fs.readFileSync(beforeInfo,'utf8');
    test('actual original and current complete English templates retain role/tool behavior',()=>{
        for(const role of ['anonymous','ordinary','curator','submitter'])for(const tool of [null,'split_seedlot'])
            assert.deepEqual(functional(render({role,tool})),functional(render({role,tool,mainSource:oldMain,infoSource:oldInfo})));
    });
    test('actual shared section default remains original; explicit anchor changes its name only',()=>{
        const title='<b>Caller Title</b> &amp; Existing';
        const before=render({component:'info',title,infoSource:oldInfo}),after=render({component:'info',title});
        assert.deepEqual(functional(after),functional(before));assert.equal(after.html,before.html,'Whole original shared-helper output remains byte-identical by default');
        const explicit=render({component:'info',title,anchorTitle:'Fixed Existing Anchor'});
        assert.deepEqual(explicit.anchors,['fixed_existing_anchor']);
        assert.equal(explicit.html.replace('fixed_existing_anchor',after.anchors[0]),after.html,'Explicit anchor argument changes only the anchor name');
    });
}
