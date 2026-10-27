'use strict';
// Offline DOM/transport source unit, armed only during an exclusive window.
// The wire fixtures come from the actual installed Catalyst serializer unit.
const assert=require('node:assert/strict');
const test=require('node:test');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const root=path.resolve(__dirname,'../../..');
const sourcePath=path.join(root,'mason/breeders_toolbox/upload_seedlots_dialogs.mas');
const source=fs.readFileSync(sourcePath,'utf8');
const libraries=['js/source/legacy/jquery.js','js/source/legacy/jquerymigrate.js','js/source/legacy/jqueryui.js','js/source/legacy/bootstrap_min.js','js/source/legacy/jquery/iframe-post-form.js'];
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');

test('actual serializer wire crosses actual iframe plugin and upload callback without JSON or scientific-value corruption',{
    skip:process.env.I18N_SEEDLOT_IFRAME_JSON_BROWSER!=='1'?'Explicit exclusive browser window and actual serializer evidence are required':false,
    timeout:30000
},async()=>{
    const evidence=path.resolve(process.env.I18N_SEEDLOT_IFRAME_JSON_EVIDENCE||'');
    assert(evidence!==root&&!evidence.startsWith(root+path.sep));
    const proof=JSON.parse(fs.readFileSync(path.join(evidence,'serializer-source-proof.json'),'utf8'));
    assert.equal(proof.status,'PASS');assert.equal(proof.nativeSGNWorkflowQualified,false);
    assert.equal(proof.controllerSHA,hash(fs.readFileSync(path.join(root,'lib/SGN/Controller/AJAX/Seedlot.pm'))),'Actual Perl unit loaded the frozen candidate controller');
    for(const [file,sha] of Object.entries(proof.files))assert.equal(hash(fs.readFileSync(path.join(evidence,file))),sha,'Use exact actual serializer bytes');
    const expected=JSON.parse(fs.readFileSync(path.join(evidence,'expected-payload.json'),'utf8'));
    const plainError=fs.readFileSync(path.join(evidence,'plain-error.txt'),'utf8');
    const before=fs.readFileSync(path.join(evidence,'wire-before.json'),'utf8');
    const after=fs.readFileSync(path.join(evidence,'wire-after.json'),'utf8');
    assert.deepEqual(JSON.parse(before),expected,'Original wire is valid JSON before its HTML document is parsed');
    assert.deepEqual(JSON.parse(after),expected,'Corrected wire restores the exact original reply');
    const scripts=[...source.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)];assert.equal(scripts.length,1);
    const body=scripts[0][1].replace(/<%\s*\$default_seedlot_material_type\s*%>/g,'');
    assert(!body.includes('<%'),'Only the existing optional material-type Mason value is bound');
    const {chromium}=require(process.env.I18N_PLAYWRIGHT_PATH||'playwright');
    const browser=await chromium.launch({headless:true});
    const results=[];
    try {
        for(const [phase,wire] of [['before',before],['after',after]]) {
            const context=await browser.newContext(),errors=[],network=[],replies=[];
            await context.route('**/*',async route=>{network.push(route.request().url());await route.abort();});
            try {
                const page=await context.newPage();
                let onError,onReply;
                const errorEvent=new Promise(resolve=>{onError=resolve;});
                const replyEvent=new Promise(resolve=>{onReply=resolve;});
                page.on('pageerror',error=>{errors.push(error.message);onError(error.message);});
                page.on('dialog',async dialog=>{await dialog.dismiss();});
                page.on('console',async msg=>{
                    if(msg.type()!=='log'||!msg.args().length)return;
                    const value=await msg.args()[0].jsonValue().catch(()=>null);
                    if(value&&typeof value==='object'&&value.error_string){replies.push(value);onReply(value);}
                });
                await page.setContent('<form id="upload_seedlot_form" method="POST"><input id="seedlot_uploaded_file" name="seedlot_uploaded_file" type="file"><input id="seedlot_harvested_uploaded_file" type="file"><input id="upload_seedlot_location"></form><div id="working_modal" class="modal"></div><div id="upload_seedlots_missing_accessions_or_crosses_div"></div><div id="upload_seedlots_no_error_messages_accessions_html"></div><div id="upload_seedlots_error_display" style="display:none"><table><tbody></tbody></table></div><div id="upload_seedlots_error_display_second_try" style="display:none"><table><tbody></tbody></table></div>');
                for(const file of libraries)await page.addScriptTag({path:path.join(root,file)});
                await page.evaluate(()=>{
                    window.sourceWorkflowObservations=[];
                    window.Workflow={skip:(...args)=>sourceWorkflowObservations.push(['skip',...args]),focus:(...args)=>sourceWorkflowObservations.push(['focus',...args]),check_complete:()=>{throw new Error('Unexpected successful upload completion');}};
                    window.get_select_box=()=>{throw new Error('Unrelated source selector request');};
                    window.addToListMenu=()=>{throw new Error('Unexpected missing-stock List branch');};
                });
                await page.addScriptTag({content:body});
                await page.waitForFunction(()=>document.getElementById('iframe-post-form')?.contentDocument?.readyState==='complete');
                // Complete the real initial blank-document load before arming
                // the plugin's real submit listener for the controlled response.
                await page.evaluate(()=>new Promise(resolve=>setTimeout(resolve,0)));
                const nativeFile=Buffer.from('seedlot_name,accession_name,operator_name,box_name,amount,weight_gram,description,quality,"é_ж_试_خطأ_<br>_<strong>_&amp;_%{columns}"\n','utf8');
                await page.locator('#seedlot_uploaded_file').setInputFiles({name:'owned-invalid.csv',mimeType:'text/csv',buffer:nativeFile});
                const selected=await page.locator('#seedlot_uploaded_file').evaluate(async input=>Array.from(new Uint8Array(await input.files[0].arrayBuffer())));
                assert.deepEqual(Buffer.from(selected),nativeFile,'Actual file input retains the canonical/literal source bytes');
                await page.evaluate(wire=>{
                    // Actual plugin submit handler registers actual .load via
                    // actual jQuery Migrate. No submit/response handler is replaced.
                    jQuery('#upload_seedlot_form').triggerHandler('submit');
                    document.getElementById('iframe-post-form').srcdoc=wire;
                },wire);
                if(phase==='before') {
                    const error=await errorEvent;
                    assert.match(error,/JSON|Expected|Unexpected|position/i,'Original HTML document corrupts otherwise valid JSON before the upload callback');
                    assert.equal(replies.length,0,'Original complete callback is never reached');
                } else {
                    const reply=await replyEvent;
                    assert.deepEqual(reply,expected,'Actual plugin supplies the exact original reply to the actual upload callback');
                    await page.waitForFunction(()=>document.querySelector('#upload_seedlots_error_display_second_try').style.display!=='none');
                    const observed=await page.evaluate(()=>({
                        first:document.querySelector('#upload_seedlots_error_display tbody').textContent,
                        second:document.querySelector('#upload_seedlots_error_display_second_try tbody').textContent,
                        active:document.querySelectorAll('#upload_seedlots_error_display img,#upload_seedlots_error_display script,#upload_seedlots_error_display strong,#upload_seedlots_error_display_second_try img,#upload_seedlots_error_display_second_try script,#upload_seedlots_error_display_second_try strong').length,
                        breaks:document.querySelectorAll('#upload_seedlots_error_display_second_try tbody br').length,
                        injected:window.sgnSeedlotInjected||0,
                        frameInjected:document.getElementById('iframe-post-form').contentWindow.sgnSeedlotInjected||0,
                        workflow:sourceWorkflowObservations
                    }));
                    assert.equal(observed.first,plainError);assert.equal(observed.second,plainError);
                    assert.equal(observed.active,0);assert.equal(observed.injected,0);assert.equal(observed.frameInjected,0);assert.equal(observed.breaks,1);
                    assert(observed.workflow.some(row=>row[0]==='focus'&&row[1]==='#upload_seedlot_main_workflow'&&row[2]===5),'Actual rejected-file branch remains active');
                    assert.deepEqual(errors,[],'Corrected source introduces no page error');
                    assert.equal(replies.length,1);
                    results.push({phase,status:'PASS',exactReply:true,exactVisibleError:true,sourceCallbackCompleted:true,observed});
                }
                assert.deepEqual(network,[],'Controlled offline transport issues no HTTP request');
                if(phase==='before')results.push({phase,status:'EXPECTED_FAILURE_REPRODUCED',errors,sourceCallbackCompleted:false});
            } finally {await context.close();}
        }
        const result={schema:1,status:'PASS',scope:'Offline actual serializer/DOM/iframe-plugin/upload-callback source unit with controlled transport',nativeSGNWorkflowQualified:false,sourceSHA:hash(fs.readFileSync(sourcePath)),librarySHAs:Object.fromEntries(libraries.map(file=>[file,hash(fs.readFileSync(path.join(root,file)))])),serializerProofSHA:hash(fs.readFileSync(path.join(evidence,'serializer-source-proof.json'))),results};
        fs.writeFileSync(path.join(evidence,'iframe-dom-source-proof.json'),JSON.stringify(result,null,2)+'\n');
    } finally {await browser.close();}
});
