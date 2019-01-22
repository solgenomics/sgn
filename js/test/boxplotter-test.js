import * as Boxplotter from '../source/entries/boxplotter.js';

test('Boxplot', t=>{
    var boxplotter;
    document.querySelector('body').innerHTML = `<div id="bxplt"></div>`;
    t.test("initialize", t=>{
        t.plan(1);
        t.doesNotThrow(()=>{
            boxplotter = Boxplotter.init("#bxplt");
        })
    });
    // t.test("populate", t=>{
    // 
    //     t.plan(1);
    //     t.doesNotThrow(()=>{
    //         boxplotter = Boxplotter.init("#bxplt");
    //     })
    // });
});
