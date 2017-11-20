;
(function(g){
var ex = {};

var forms = {
     'gen-form':`<form class="ttph_gen-form form-inline">
             <span class="ttph_group-wrapper"></span>            
             <div class="ttph_add-dropdown dropdown">
                 <button id="{UNIQUEID1}" type="button" class="dropdown-toggle btn btn-success" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                     <span class="glyphicon glyphicon-plus"></span>
                     <span class="caret"></span>
                 </button>
                 <ul id="{UNIQUEID2}" class="dropdown-menu" aria-labelledby="{UNIQUEID1}">
                     <li><a href="#" class="ttph_add-ph" ph-type="statictext"><span class="glyphicon glyphicon-font"></span>&nbsp;&nbsp;Static Text</a></li>
                     <li><a href="#" class="ttph_add-ph" ph-type="textfield"><span class="glyphicon glyphicon-edit"></span>&nbsp;&nbsp;Text Field</a></li>
                 </ul>
             </div>                        
         </form>`,
     'fill-form':`<form class="ttph_fill-form form-inline"></form>`
}
var fields = {
    'textfield':`<div class="btn-group ttph_group" role="group" aria-label="...">
        <span disabled class="btn btn-default ttph_btn-static">{NAME}</span>
        <input type="text" class="form-control ttph_text" name="__statictext__">
    </div>`,
    'variable':`<span disabled class="ttph_variable-field btn btn-default ttph_btn-static"><strong>$ {NAME}</strong><input type="hidden" name="{NAME}"></span>`,
    'static':`<span class="ttph_static-field">{ESC_TEXT}<input type="hidden" name="__statictext__" value="{TEXT}"></span>`
}
var default_placeholders = {
    'statictext':`<div class="btn-group ttph_group" role="group" aria-label="...">
            <span disabled class="btn btn-default ttph_btn-static"><span class="glyphicon glyphicon-font"></span></span>
            <input type="text" class="form-control ttph_text" name="statictext" placeholder="Static Text">
            <button type="button" tabindex="-1" class="btn ttph_remove btn-danger"><span class="glyphicon glyphicon-remove"></span></button>
        </div>`,
    'textfield':`<div class="btn-group ttph_group" role="group" aria-label="...">
            <span disabled class="btn btn-default ttph_btn-static"><span class="glyphicon glyphicon-edit"></span></span>
            <input type="text" class="form-control ttph_text" name="textfield" placeholder="Field Name">
            <button type="button" tabindex="-1" class="btn ttph_remove btn-danger"><span class="glyphicon glyphicon-remove"></span></button>
        </div>`,
    '__variable':`<div class="btn-group ttph_group" role="group" aria-label="...">
            <span disabled class="btn btn-default ttph_btn-static"><span class="glyphicon glyphicon-usd"></span></span>
            <span disabled class="btn btn-default ttph_btn-static"><strong>{NAME}</strong></span>
            <input type="hidden" hidden name="variable" value="{NAME}">
            <button type="button" tabindex="-1" class="btn ttph_remove btn-danger"><span class="glyphicon glyphicon-remove"></span></button>
        </div>`,
}
var variable_li = '<li><a href="#" class="ttph_add-ph" ph-type="{NAME}"><span class="glyphicon glyphicon-usd"></span>&nbsp;&nbsp;{NAME}</a></li>';


ex.builder = function(selector,variables){
    var parent = $(selector);
    var dropdownID = genID();
    var dropdownListID = genID();
    var formHTML = forms['gen-form'].replace(/{UNIQUEID1}/g,dropdownID)
                                    .replace(/{UNIQUEID2}/g,dropdownListID);
    var form = $(formHTML).appendTo(parent);
    
    var placeholders = $.extend({}, default_placeholders);
    variables.forEach(function(v){
        placeholders[v] = (placeholders['__variable']).replace(/{NAME}/g,v);
        var opt = (variable_li).replace(/{NAME}/g,v);
        $(opt).insertAfter($("#"+dropdownListID+">li:last-of-type"));
    });
    
    $("#"+dropdownListID+' .ttph_add-ph').click(function(){
        var type = $(this).attr('ph-type');
        var wrapper = form.children(".ttph_group-wrapper");
        $(placeholders[type]).appendTo(wrapper);
        reset_ph_handlers();
        return false;
    });
    
    reset_ph_handlers();
    return {
        'form':function(){return form.get(0);},
        'getTemplate':function(){return create_format_string(form.serializeArray());}
    }
}

ex.filler = function(selector,templateString){
    var parent = $(selector);
    var formHTML = forms['fill-form']
    parent.html("");
    var form = $(formHTML).appendTo(parent);
    
    var formhtml = templateString
        .replace(/(^|})[^{}]+?({|$)/g, function(staticText){
            var html = staticText.replace(/[^{}]+/g, function(nobrackets){
                var esc_text = nobrackets.replace(/&/g,"&amp;")
                    .replace(/\ /g,"&nbsp;")
                    .replace(/</g,"&lt;")
                    .replace(/>/g,"&gt;");
                var text = nobrackets.replace(/\"/g,'\\"').replace(/\'/g,"\\'");
                return fields["static"]
                    .replace(/\n\s*/g,"")
                    .replace(/{ESC_TEXT}/g,esc_text)
                    .replace(/{TEXT}/g,text);
            });
            return html;
        })
        .replace(/\{.+?\}/g, function(placeholder){
            var ph_name = placeholder.replace(/^\{|\}$/g,'');
            if(ph_name.slice(0,9)=="__FIELD__"){
                // is a editable field
                ph_name = ph_name.slice(9)
                    .replace(/&/g,"&amp;")
                    .replace(/</g,"&lt;")
                    .replace(/>/g,"&gt;");
                if(ph_name=="") ph_name="Text";
                fieldhtml = fields["textfield"]
                    .replace(/\n\s*/g,"")
                    .replace(/{NAME}/g,ph_name);
                return fieldhtml;
            } else {
                fieldhtml = fields["variable"]
                    .replace(/\n\s*/g,"")
                    .replace(/{NAME}/g,ph_name);
                return fieldhtml;
            }
            return "";
        });
    form.html(formhtml);
    return {
        'form':function(){return form.get(0);},
        'getFilledTemplate':function(){
            result = ""
            form.serializeArray().forEach(function(field){
                if (field.name=="__statictext__") result+=field.value;
                else {
                    result+="{"+field.name+"}";
                }
            });
            return result;
        }
    }
};

ex.populateTemplate = function(tempalteString, variables){
    result = tempalteString.replace(/\{.+?\}/g, function(placeholder){
        var ph_name = placeholder.replace(/^\{|\}$/g,'');
        if(variables[ph_name]===undefined) return placeholder;
        return variables[ph_name];
    })
    return result;
};

function reset_ph_handlers() {
    $('.ttph_group-wrapper').sortable();
    $('.ttph_remove').off("click").click(function(){
        $(this).parent().remove();
    });
}

function create_format_string(data) {
    console.log(data);
    var format_string = "";
    data.forEach(function(field){
        if (field.value.indexOf("{") !== -1 || field.value.indexOf("{") !== -1){
            alert("Fields cannot contain curly brackets!")
            throw "Fields cannot contain curly brackets!";
        }
        if (field.name=="statictext"){
            format_string+=field.value;
        }
        else if (field.name=="textfield"){
            format_string+="{__FIELD__"+field.value+"}";
        }
        else if (field.name=="variable"){
            format_string+="{"+field.value+"}";
        }
    });
    return format_string
}

var genID_counter = 1;
function genID(){
     var newID = "ttph-id_"+(genID_counter++);
     if (document.getElementById(newID)!=null){
          return genID();
     }
     else{
          return newID;
     }
}

g.textTemplater = ex;
})(window);
