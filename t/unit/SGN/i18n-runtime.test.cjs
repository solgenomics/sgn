'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const I18N = require('../../../static/js/sgn-i18n.js');
const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'i18n-fixtures.json'),'utf8'));
const clone = x => JSON.parse(JSON.stringify(x));
const create = locale => new I18N({locale,dir:locale==='ar'?'rtl':'ltr',domain:'sgn',catalogs:fixture.catalogs[locale]?[fixture.catalogs[locale]]:[]});

test('context, English fallback, named values and independent request objects',()=> {
 const uk=create('uk'), en=create('en'), ar=create('ar');
 assert.equal(uk.p('controls.save','Save'),'Зберегти');
 assert.equal(uk.p('seedlots.save','Save'),'Зберегти партію');
 assert.equal(uk.p('','Save'),'Зберегти без контексту');
 assert.equal(uk.p('data','Wheat'),'Wheat');
 for(let i=0;i<5;i++) {
  assert.equal(en.p('controls.save','Save'),'Save');
  assert.equal(uk.p('controls.save','Save'),'Зберегти');
  assert.equal(ar.np('trials.count','%{count} trial found','%{count} trials found',3,{count:3}),'ar[3] 3');
 }
 const name='</script><img src=x onerror=alert(1)>';
 assert.equal(uk.p('trial.named','Created trial %{name}.',{name}),'Створено дослід '+name+'.');
 assert.throws(()=>uk.p('trial.named','Created trial %{name}.',{}),/named variable/);
});

test('GNU plurals and regional catalogs retain different zero rules',()=>{
 const uk=create('uk'), ar=create('ar');
 const suffix={0:'дослідів',1:'дослід',2:'досліди',5:'дослідів',11:'дослідів',21:'дослід',22:'досліди',25:'дослідів',101:'дослід'};
 for(const [n,s] of Object.entries(suffix)) assert.equal(uk.np('trials.count','%{count} trial found','%{count} trials found',Number(n),{count:n}),`Знайдено ${n} ${s}`);
 for(const [n,i] of [[0,0],[1,1],[2,2],[3,3],[11,4],[100,5],[102,5]]) assert.equal(ar.np('trials.count','%{count} trial found','%{count} trials found',n,{count:n}),`ar[${i}] ${n}`);
 assert.equal(create('pt-BR').np('trials.count','%{count} trial found','%{count} trials found',0,{count:0}),'pt-BR[0] 0');
 assert.equal(create('pt-PT').np('trials.count','%{count} trial found','%{count} trials found',0,{count:0}),'pt-PT[1] 0');
 assert.equal(uk.np('missing','%{count} trial','%{count} trials',21,{count:21}),'21 trials');
 assert.equal(uk.np('trials.count','%{count} trial found','%{count} records found',1,{count:1}),'1 trial found');
 for(const n of [-1,1.2,NaN,undefined,9007199254740992]) assert.throws(()=>uk.np('ctx','one','many',n),/count/);
});

test('catalog cloning, order independent AST comparison and validation',()=> {
 const catalog=clone(fixture.catalogs.uk);
 const runtime=new I18N({locale:'uk',dir:'ltr',domain:'sgn',catalogs:[catalog]});
 catalog.messages['controls.save\x04Save'].forms[0]='changed';
 assert.equal(runtime.p('controls.save','Save'),'Зберегти');
 const reordered=JSON.parse(JSON.stringify(fixture.catalogs.uk,(k,v)=>v&&typeof v==='object'&&!Array.isArray(v)?Object.fromEntries(Object.keys(v).sort().map(key=>[key,v[key]])):v));
 assert.equal(new I18N({locale:'uk',dir:'ltr',domain:'sgn',catalogs:[reordered]}).p('controls.save','Save'),'Зберегти');
 const bad=clone(fixture.catalogs.uk);bad.pluralAst={type:'EVAL',code:'evil()'};
 assert.throws(()=>new I18N({locale:'uk',dir:'ltr',domain:'sgn',catalogs:[bad]}),/AST/);
 assert.throws(()=>I18N.parsePlural('nplurals=2; plural=evil(n);'),/Parse|parse|Lexical|Invalid|Unsupported/);
 assert.throws(()=>I18N.parsePlural('nplurals=2; plural=(n + 1);'),/Parse|parse|Lexical|Invalid|Unsupported/);
 assert.throws(()=>I18N.parsePlural('nplurals=2; plural=(n % 0);'),/zero/);
 assert.throws(()=>I18N.parsePlural('nplurals=2; plural=5;'),/outside/);
});

test('browser runtime and standard Jed plural parser work with eval disabled',()=>{
 const sandbox={console};
 sandbox.eval=()=>{throw new Error('eval forbidden')};
 sandbox.Function=()=>{throw new Error('Function forbidden')};
 vm.createContext(sandbox, {codeGeneration:{strings:false,wasm:false}});
 vm.runInContext(fs.readFileSync(path.resolve(__dirname,'../../../static/js/sgn-i18n.js'),'utf8'),sandbox);
 assert.equal(sandbox.SGN.i18n.p('ctx','English'),'English');
 sandbox.payload={locale:'uk',dir:'ltr',domain:'sgn',catalogs:[clone(fixture.catalogs.uk)]};
 assert.equal(vm.runInContext('new SGN.I18N(payload).np("trials.count", "%{count} trial found", "%{count} trials found", 22, {count:22})',sandbox),'Знайдено 22 досліди');
});


test('GNU logical expressions and single-pass named parameters',()=>{
 const en=create('en');
 assert.equal(en.p('literal','Keep {braces} and %{name}.',{name:'value'}),'Keep {braces} and value.');
 assert.equal(en.p('literal','Value: %{name}',{name:'%{other}'}),'Value: %{other}');
 for(const formula of ['nplurals=2; plural=(n || 0);','nplurals=2; plural=(n && 5);']) {
  const parsed=I18N.parsePlural(formula);
  assert.equal(I18N.evaluatePlural(parsed.ast,0),0);
  assert.equal(I18N.evaluatePlural(parsed.ast,3),1);
  const cat=clone(fixture.catalogs['pt-PT']);cat.pluralForms=parsed.normalized;cat.pluralAst=parsed.ast;
  assert.equal(new I18N({locale:'pt-PT',dir:'ltr',domain:'sgn',catalogs:[cat]}).np('trials.count','%{count} trial found','%{count} trials found',3,{count:3}),'pt-PT[1] 3');
 }
});


test('native names are optional display data with consistent Unicode limits', () => {
    assert.equal(new I18N().languageName, 'English');
    const payload={locale:'uk',dir:'ltr',domain:'sgn',languageName:'Українська',catalogs:[clone(fixture.catalogs.uk)]};
    assert.equal(new I18N(payload).languageName,'Українська');
    assert.equal(new I18N({...payload,languageName:'𞤊'.repeat(200)}).languageName,'𞤊'.repeat(200));
    for (const languageName of ['', ' ', 'x'.repeat(201), 'bad\nname', 'bad\x85name', {}, true]) {
        assert.throws(()=>new I18N({...payload,languageName}),/native language name/);
    }
    assert.throws(()=>new I18N({...payload,catalogs:[{...clone(fixture.catalogs.uk),languageName:[]}]}),/native language name/);
});

test('requested regional tag remains separate from effective language', () => {
    const payload={locale:'uk',requestedLocale:'uk-UA',dir:'ltr',domain:'sgn',catalogs:[clone(fixture.catalogs.uk)]};
    const translator=new I18N(payload);
    assert.equal(translator.locale,'uk');
    assert.equal(translator.requestedLocale,'uk-UA');
    assert.equal(translator.p('controls.save','Save'),'Зберегти');
    assert.throws(()=>new I18N({...payload,requestedLocale:'../uk'}),/requested locale/);
});
