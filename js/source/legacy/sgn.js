/**
 * English fallbacks for SGN.t and SGN.tn.
 *
 * This file is loaded on every page. When interface translation is enabled,
 * /i18n/runtime.js is loaded first and defines the translating versions; these
 * fallbacks are then not installed. With translation off they return the
 * English text, so code can always call SGN.t and SGN.tn.
 */
(function (root) {
    var api = root.SGN = root.SGN || {};

    function format(text, variables) {
        variables = variables || {};
        if (typeof variables !== 'object' || Array.isArray(variables)) {
            throw new Error('Named variables must be an object');
        }
        return text.replace(/%\{([A-Za-z_][A-Za-z0-9_]*)\}/g, function (_, name) {
            var value = variables[name];
            if (!Object.prototype.hasOwnProperty.call(variables, name) || value == null ||
                typeof value === 'object' || typeof value === 'function') {
                throw new Error('Missing or invalid named variable: ' + name);
            }
            return String(value);
        });
    }

    /**
     * Translate one message.
     * @param {string} context Message key, for example "navigation.manage.menu".
     * @param {string} text Exact English text, used when there is no translation.
     * @param {Object} [variables] Values for %{name} placeholders.
     * @returns {string} Plain text; insert it with textContent or jQuery .text().
     */
    if (!api.t) api.t = function (context, text, variables) {
        if (api.i18n) return api.i18n.p(context, text, variables);
        if (typeof context !== 'string' || typeof text !== 'string') {
            throw new Error('Translation context and text must be strings');
        }
        return format(text, variables);
    };

    /**
     * Translate a message that depends on a count.
     * @param {string} context Message key.
     * @param {string} one English singular text.
     * @param {string} many English plural text.
     * @param {number} count Non-negative integer that selects the form.
     * @param {Object} [variables] Values for %{name} placeholders.
     * @returns {string} Plain text.
     */
    if (!api.tn) api.tn = function (context, one, many, count, variables) {
        if (api.i18n) return api.i18n.np(context, one, many, count, variables);
        if (!Number.isSafeInteger(count) || count < 0) {
            throw new Error('Plural count must be a nonnegative safe integer');
        }
        if (typeof context !== 'string' || typeof one !== 'string' || typeof many !== 'string') {
            throw new Error('Translation context and texts must be strings');
        }
        return format(count === 1 ? one : many, variables);
    };
})(typeof globalThis !== 'undefined' ? globalThis : this);

// stub out some problematic things
var docroot = '/';

// Toggles the layer visibility on 
function showLayer(layerName) { 
  document.getElementById(layerName).style.visibility="visible"; 
}

// Toggles the layer visibility off 
function hideLayer(layerName) { 
  document.getElementById(layerName).style.visibility = "hidden";
}

////////////////////////////////////
// cookie helper
////////////////////////////////////

function getCookie(name) {
    var dc = document.cookie;
    var prefix = name + "=";
    var begin = dc.indexOf("; " + prefix);
    if (begin == -1) {
        begin = dc.indexOf(prefix);
        if (begin != 0) return null;
    } else {
        begin += 2;
    }
    var end = document.cookie.indexOf(";", begin);
    if (end == -1) {
        end = dc.length;
    }
    return unescape(dc.substring(begin + prefix.length, end));
}

////////////////////////////////////////////////////////////
//   clone cart
////////////////////////////////////////////////////////////
function count_clones()
{
    var n_clones=0;
    var p;
    var cookies;
    cookies=document.cookie;
    var count_el = document.getElementById('clone_cart_count');
    if(getCookie('CloneCart')!="") 
    {
        n_clones = 1;//first clone in cookie does not begin with a comma (fencepost problem)
        p+=1;
        while((p=cookies.indexOf(",",p))!=-1) 
        {
            p++;
            n_clones++;
        }

        count_el.innerHTML = n_clones;
    }
    else
    {
        count_el.innerHTML = 'No';
    }
}

function check_clonecart() 
{
    //if we are on the order routing page, hide cart
    if(document.URL.indexOf("route-order.pl")!=-1) 
    {
        hideLayer('clone_shoppingcart');
        return;
    }
    //if there is something in the cart, show cart
    if(getCookie('CloneCart')!="" && getCookie('CloneCart')!=null) 
    {
        showLayer('clone_shoppingcart');
        return;
    } 
    //otherwise, hide cart
    hideLayer('clone_shoppingcart');
    return;
}


JSAN.use('jquery');
jQuery( check_clonecart ); // check the clone cart on document load
jQuery( count_clones );
