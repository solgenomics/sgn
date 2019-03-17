import test from 'tape';
import {Wizard} from "../source/modules/wizard-search.js";

test('Wizard', t=>{
    document.querySelector('body').innerHTML = Wizard.basicTemplate;
    
    var wizard;
    const col_num = 4;
    
    t.test("initialize", t=>{
        t.plan(1);
        t.doesNotThrow(()=>{
            wizard = new Wizard(document.querySelector('body .wizard-main'),col_num);
        });
    });
    
    t.test("layout as expected", t=>{
        t.plan(1);
        t.equals(
            document.querySelectorAll('body .wizard-columns .wizard-column').length,
            col_num
        );
    });
});
