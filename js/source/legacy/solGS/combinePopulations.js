/**
* saves selected training population ids to cookie
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use("Prototype");
JSAN.use("jquery.blockUI");


var getCookieName =  function (trId) {

    return 'trait_' + trId + '_populations';

};

var getPopIds =  function() {

    jQuery("input:checkbox[name='project']").change(function() {

        var cookieArrayData = [];

        var trId = getTraitId();
        var cookieName = getCookieName(trId);
        var existingPopIds = jQuery.cookie(cookieName);
        var eP = [];
         if (existingPopIds) {
                  eP  = existingPopIds.split(",");
                }
        if (eP.length <= 1) {
            jQuery("#select_done input").val('Select');
        }

        if (jQuery(this).attr('checked')) {
            var popId = jQuery(this).val();

            if (eP.length == 0) {

                jQuery("#select_done input").val('Select');


                cookieArrayData.push(popId);
                jQuery.cookie(cookieName, cookieArrayData, {path: '/'});
            } else {
                var cookieData = jQuery.cookie(cookieName);

                if (cookieData) {
                    cookieArrayData = cookieData.split(",");
                }

                var indexPopId = jQuery.inArray(popId, cookieArrayData);
                if (indexPopId == -1) {

                    cookieArrayData.push(popId);
                    cookieArrayData =  cookieArrayData.unique();

                   if (cookieArrayData.length === 1) {
                       jQuery("#select_done input").val('Select');
                   } else if (cookieArrayData.length > 1 )  {
                        jQuery("#select_done input").val('Combine');
                    }

                    jQuery.cookie(cookieName, cookieArrayData, {path: '/'});
                }
            }
        }
        else  {
            var popId = jQuery(this).val();

            var cookieData =  jQuery.cookie(cookieName);
            cookieArrayData = cookieData.split(",");

            var indexPopId = jQuery.inArray(popId, cookieArrayData);

            if(indexPopId != -1) {
                cookieArrayData.splice(indexPopId, 1);
            }

            cookieArrayData = cookieArrayData.unique();
            cookieArrayData = cookieArrayData.sort();
            jQuery.cookie(cookieName, cookieArrayData, {path: '/'});

        }
    });
};


var selectedPops = function () {

    var trId            = getTraitId();
    var cookieName      = getCookieName(trId);
    var cookieData      = jQuery.cookie(cookieName);
    var cookieArrayData = [];

    if (cookieData) {
        cookieArrayData = cookieData.split(",");
        cookieArrayData = cookieArrayData.unique();
    }

    if (cookieArrayData.length == 1) {
        var redirectUrl =  '/solgs/trait/' + trId + '/population/' + cookieData;

        jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait..'});

        jQuery.ajax({
            type: 'POST',
            dataType: "json",
            url: redirectUrl,
            data: 'source=ajaxredirect',
            success: function(res) {
                var suc = res.status;
                if (suc == 'success') {
                    jQuery.cookie(cookieName, null, {expires: -1, path: '/'});
                    window.location.href = redirectUrl;
                }
            }

        });
    }

    else if( cookieArrayData.length > 1 ) {

        var action = "/solgs/search/result/populations/" + trId;
        var selectedPops = trId + "=" + cookieArrayData + '&' + 'combine=confirm';
        jQuery.ajax({
            type: 'POST',
            dataType: "json",
            url: action,
            data: selectedPops,
            success: function(res){
                var suc = res.status;
                if (suc == 'success') {
                    var confirmPops = res.populations;
                    var url = '/solgs/combine/trials/trait/confirm/' + trId;
                    var form = jQuery('<form action="' + url + '" method="POST">' +
                                      '<input type="hidden" name="confirm_populations" value="' + confirmPops + '" />' +
                                      '</form>'
                                     );
                    jQuery('body').append(form);
                    jQuery(form).submit();
                }
            }
        });
    }
    else {
        alert('No populations were selected.' +
              'Please make your selections.'
             );

    }
};


var confirmSelections =  function() {
    var trId = getTraitId();
    var selections = [];

    jQuery("input:checkbox[name='project']:checked").each( function() {
            selections.push(jQuery(this).val());
        });

    var action = "/solgs/combine/trials/trait/" + trId + '/gp/' + protocolId;
    var selectedPops = trId + "=" + selections + '&' + 'combine=combine';

    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    jQuery.blockUI({message: 'Please wait..'});

    jQuery.ajax({
            type: 'POST',
                dataType: "json",
                url: action,
                data: selectedPops,
                success: function(res) {
                var suc = res.status;

                if (suc) {
                    //alert('combined pops');
                    var comboPopsId = res.combo_pops_id;
                    var newUrl = '/solgs/model/combined/trials/' + comboPopsId + '/trait/' + trId + '/gp/' + protocolId;

                    var form = jQuery('<form action="' + newUrl + '" method="POST">' +
                                      '<input type="hidden" name="combined_populations" value="' +
                                       selections + '" />' + '</form>');

                    jQuery('body').append(form);
                    jQuery(form).submit();

                    jQuery.unblockUI();

                } else {

                    if(res.not_matching_pops ){
                        alert('populations ' + res.not_matching_pops +
                              ' were genotyped using different marker sets. ' +
                              'Please make new selections to combine.' );
                        window.location.href =  '/solgs/search/result/populations/' + trId;
                    }

                    if (res.redirect_url) {
                        window.location.href = res.redirect_url;
                    }
                }
            }
        });

    var trId = getTraitId();
    var cookieName = getCookieName(trId);
    jQuery.cookie(cookieName, null, {expires: -1, path: '/'});

};


Array.prototype.unique = function() {
    var a = [];
    var l = this.length;
    for(var i=0; i<l; i++) {
      for(var j=i+1; j<l; j++) {
        // If this[i] is found later in the array
        if (this[i] === this[j])
          j = ++i;
      }
      a.push(this[i]);
    }
    return a;
  };


var getTraitId = function () {
   var id = jQuery("input[name='trait_id']").val();

   return id;
};
