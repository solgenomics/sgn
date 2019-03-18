import test from 'tape';
import nock from 'nock';
import * as Boxplotter from '../source/entries/boxplotter.js';
import data from './boxplotter.test.data.js';

test('Boxplot', t=>{
    
    document.querySelector('body').innerHTML = `<div id="bxplt"></div>`;
    
    var boxplotter;
    
    t.test("initialize", t=>{
        t.plan(1);
        t.doesNotThrow(()=>{
            boxplotter = Boxplotter.init("#bxplt");
        })
    });
    
    t.test("populate", t=>{
        t.plan(2);
        
        var scope = nock(document.location.origin);
        scope.get('/ajax/tools/boxplotter/get_constraints').query({dataset: 7})
            .reply(200, data.constraints);
        scope.post('/brapi/v1/phenotypes-search')
            .reply(200, data.phenotypes);
            
        setTimeout(() => {
            t.ok(scope.isDone(),"expected calls made");
        }, 200)
            
        t.doesNotThrow(()=>{
            boxplotter.loadDatasetObsUnits(7,"plot");
        },"loadDatasetObsUnits works");
    });
});
