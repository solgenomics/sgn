/* 
A library with methods for adding populations select menu and 
getting selected population id. 
*/

var solGS = solGS || function solGS () {};

solGS.selectMenu = {

    divPrefix: function(div) {

    if (!div.match(/pops/)) {
        div = `${div}_pops`;
    }

    console.log(`selectMenu div ${div}`)
    return div;

    },

    divListId: function(div) {
        div = this.divPrefix(div)
        return `#${div}_list`;
    },

    divListSelectId: function(div) {
        return this.divListId(div) + '_select';
    },

    populateMenu: function(div, listTypes, dsTypes) {
        div = this.divPrefix(div);
        
        var list = new CXGN.List();
        var listMenu = list.listSelect(div, listTypes);
        var dMenu = solGS.dataset.getDatasetPops(dsTypes);

        if (listMenu.match(/option/) != null) {
            var divListId = this.divListId(div);
            var divListSelectId = this.divListSelectId(div);

            jQuery( divListId).append(listMenu);
            jQuery(divListSelectId).append(dMenu);

            jQuery("<option>", {
            value: '',
            selected: true
            }).prependTo(divListSelectId);

        } else {
            jQuery(divListId).append("<select><option>no lists found - Log in</option></select>");
        }
    },

    getSelectedPop: function(div) {
        
        var divId = this.divListSelectId(div);

        var selectedId = jQuery(divId).find("option:selected").val();
        selectedId = parseInt(selectedId);
        var selectedName = jQuery(divId).find("option:selected").text();
        var dataStr = jQuery(divId).find("option:selected").attr('name');

        if (!dataStr) {
            dataStr = 'list';
        }
        
        return {'selected_id': selectedId,
        'selected_name': selectedName,
        'data_str': dataStr
    };

    },


}
		
