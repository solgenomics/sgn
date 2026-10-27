// Optional locale assets never block the native crossing workflow.
var crossI18n = (window.SGN && window.SGN.i18n) || {
    p: function (context, source, variables) {
        return source.replace(/%\{([A-Za-z0-9_]+)\}/g, function (match, name) {
            return variables && Object.prototype.hasOwnProperty.call(variables, name) ? String(variables[name]) : match;
        });
    },
    np: function (context, one, many, count, variables) {
        return this.p(context, count === 1 ? one : many, variables);
    }
};
// Presentation language belongs only to these reviewed same-origin crossing actions.
function crossLocaleTag() {
    var root = typeof document !== 'undefined' && document.documentElement;
    var runtime = window.SGN && window.SGN.i18n;
    var requested = root && typeof root.getAttribute === 'function' && root.getAttribute('data-sgn-locale');
    var tag = requested || (runtime && runtime.requestedLocale) || (root && root.lang) || (runtime && runtime.locale) || 'en';
    return typeof tag === 'string' && /^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{2,8})*$/.test(tag) ? tag : 'en';
}
function crossLocaleTarget(url) {
    try {
        var target = new URL(url, window.location.href);
        if (target.origin !== window.location.origin) return null;
        var admitted = /^\/ajax\/cross\/(?:add_cross|add_crossingtrial|upload_crosses_file|delete|(?:membership|accession_plot_plant_parents|properties|transactions|additional_info|tissue_culture_summary)\/[0-9]+)$/.test(target.pathname)
            || /^\/cross\/(?:ajax\/relationships|progeny\/add|property\/(?:check|save))\/[0-9]+$/.test(target.pathname)
            || /^\/ajax\/pedigrees\/(?:upload_verify|upload_store|get_full|get_relationships)$/.test(target.pathname);
        return admitted ? target : null;
    } catch (error) {
        return null;
    }
}
function crossLocaleHeaders(url) {
    return crossLocaleTarget(url) ? {'X-SGN-Locale': crossLocaleTag()} : {};
}
function crossLocaleUploadURL(url) {
    var target = crossLocaleTarget(url);
    if (!target || !/^\/ajax\/(?:cross\/upload_crosses_file|pedigrees\/upload_verify)$/.test(target.pathname)) return url;
    // Native iframe forms cannot emit custom HTTP headers. Keep their payload intact.
    target.searchParams.set('lang', crossLocaleTag());
    return target.pathname + target.search + target.hash;
}

function crossHTML(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (character) {
        return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[character];
    });
}

/*jslint browser: true, devel: true */

/**

=head1 UploadPedigrees.js

Dialogs for uploading pedigrees


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>, based on code by
Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {


    $('#upload_pedigrees_link').click(function () {
        open_upload_pedigrees_dialog();
    });

    $("#upload_pedigrees_dialog_submit").click( function () {
        $('#upload_pedigrees_dialog').modal("hide");
        upload_pedigrees_file();
    });

    $("#pedigrees_upload_spreadsheet_format_info").click( function () {
        $('#upload_pedigrees_dialog').modal("hide");
        $("#pedigrees_upload_spreadsheet_info_dialog" ).modal("show");
    });

    var pedigree_data;
    $('#upload_pedigrees_form').iframePostForm({
        json: false,
        post: function () {
            var uploadedPedigreesFile = $("#pedigrees_uploaded_file").val();
            $('#working_modal').modal("show");
            if (uploadedPedigreesFile === '') {
                $('#working_modal').modal("hide");
                alert(crossI18n.p("cross.ui.no_file_selected", "No file selected"));
            }
        },
        complete: function (r) {
//	    alert("RETRIEVED: "+r);
    	    var clean_r = r.replace('<pre>', '');
	    clean_r = clean_r.replace('</pre>', '');
//	    alert("NOW: "+clean_r);
	    console.log(clean_r);
	    var response = JSON.parse(clean_r);
            $('#working_modal').modal("hide");

            var html;
            pedigree_data = response.pedigree_data;
            if (response.error) {
                html = "<h3>" + crossHTML(crossI18n.p("cross.ui.the_following_issues_were_identified", "The Following Issues Were Identified")) + "</h3><p class=\"bg-warning\">"+response.error+'</p>';
                $("#upload_pedigrees_validate_display tbody").html(html);
                $("#upload_pedigrees_validate_display").modal('show');
            } else if (response.error_string) {
                html = "<h3>" + crossHTML(crossI18n.p("cross.ui.the_following_issues_were_identified", "The Following Issues Were Identified")) + "</h3><p class=\"bg-warning\">"+response.error_string+'</p>';
                $("#upload_pedigrees_error_display tbody").html(html);
                $("#upload_pedigrees_error_display").modal('show');
            } else {
                html = "<h3>" + crossHTML(crossI18n.p("cross.ui.there_were_no_issues_identified", "There Were No Issues Identified")) + "</h3>";
                $("#upload_pedigrees_validate_display tbody").html(html);
                $("#upload_pedigrees_validate_display").modal('show');
            }
        }
    });

    function upload_pedigrees_file() {
        var uploadFile = $("#pedigrees_uploaded_file").val();
        $('#upload_pedigrees_form').attr("action", crossLocaleUploadURL("/ajax/pedigrees/upload_verify"));
        if (uploadFile === '') {
            alert(crossI18n.p("cross.ui.please_select_a_file", "Please select a file"));
            return;
        }
        $("#upload_pedigrees_form").submit();
    }

    function open_upload_pedigrees_dialog() {
        $('#upload_pedigrees_dialog').modal("show");
    }

    jQuery('#upload_pedigrees_store').click(function(){
        jQuery.ajax( {
            url: '/ajax/pedigrees/upload_store',
            headers: crossLocaleHeaders('/ajax/pedigrees/upload_store'),
	    type: 'POST',
            data: {
                'pedigree_data':pedigree_data,
                'overwrite_pedigrees':jQuery('#pedigree_upload_overwrite_pedigrees').is(":checked")
            },
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert(crossI18n.p("cross.ui.an_error_occured_no_pedigrees_were_saved_try_fixing_your_file_", "An Error Occured: No pedigrees were saved! Try Fixing Your File For The Issues Identified In the Validation. %{detail}", {detail: response.error}));
                }
                else {
                    jQuery('#pedigrees_upload_success_dialog_message').modal('show');
                }
            },
            error: function(response) {
                jQuery('#working_modal').modal('hide');
                alert(crossI18n.p("cross.ui.an_error_occurred_storing_the_pedigrees_none_were_uploaded", "An error occurred storing the pedigrees. None were uploaded."));
            }
        });
    });

});
