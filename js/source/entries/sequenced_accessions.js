
import '../legacy/jquery.js';
import '../legacy/jquery/dataTables.js';
import '../legacy/CXGN/Login.js';

export function init(main_div, stock_id, stockprop_id) {

    if (!(main_div instanceof HTMLElement)) {
        main_div = document.getElementById(
            main_div.startsWith("#") ? main_div.slice(1) : main_div
        );
    }

    jQuery(document).ready(function () {
        var stock_param = "";
        if (stock_id !== undefined && stock_id !== null) {
            stock_param = "/" + stock_id;
            jQuery('#sequenced_stocks_table').DataTable({
                "ajax": '/ajax/genomes/sequenced_stocks' + stock_param
            });
        }
        else {
            jQuery('#sequenced_stocks_table').DataTable({
                "ajax": '/ajax/genomes/sequenced_stocks'
            });
        }
    });

    jQuery('#sequencing_info_form').submit(function (event) {

        event.preventDefault();

        var formdata = jQuery("#sequencing_info_form").serialize();
        //alert(formdata);
        jQuery.ajax({
            url: '/ajax/genomes/store_sequencing_info?' + formdata,
            success: function (r) {
                if (r.error) { alert(r.error + r); }
                else {
                    alert("The entry has been saved. Thank you!");
                    jQuery('#edit_sequencing_info_dialog').modal('toggle');
                    clear_dialog_entries();
                    jQuery('#sequenced_stocks_table').DataTable().ajax.reload();
                }
            },
            error: function (r, e) {
                alert("An error occurred. (" + r.responseText + ")");
                var err = eval("(" + r.responseText + ")");
            }
        });
    });

    jQuery('#dismiss_sequencing_info_dialog').click(function () {
        jQuery('#edit_sequencing_info_dialog').modal('toggle');
        clear_dialog_entries();
    });
}


function clear_dialog_entries() {
    jQuery('#organization').val(undefined);
    jQuery('#website').val(undefined);
    jQuery('#genbank_accession').val(undefined);
    jQuery('#funded_by').val(undefined);
    jQuery('#funder_project_id').val(undefined);
    jQuery('#contact_email').val(undefined);
    jQuery('#sequencing_year').val(undefined);
    jQuery('#publication').val(undefined);
    jQuery('#jbrowse_link').val(undefined);
    jQuery('#blast_db_id').val(undefined);
    jQuery('#ftp_link').val(undefined);
    jQuery('#ncbi_link').val(undefined);
    jQuery('#stockprop_id').val(undefined);
    jQuery('#website').val(undefined);
}

export function delete_sequencing_info(stockprop_id) {
    var answer = confirm("Are you sure you want to delete this entry? (stockprop_id= " + stockprop_id + "). This action cannot be undone.");
    if (answer) {
        jQuery.ajax({
            url: '/ajax/genomes/sequencing_info/delete/' + stockprop_id,
            success: function (r) {
                if (r.error) { alert(r.error); }
                else {
                    alert("The entry has been deleted.");
                    jQuery('#sequenced_stocks_table').DataTable().ajax.reload();
                }
            },
            error: function (r) {
                alert("An error occurred. The entry was not deleted.");
            }
        });
    }
}

export function edit_sequencing_info(stockprop_id) {
    //alert(stockprop_id);
    jQuery.ajax({
        url: '/ajax/genomes/sequencing_info/' + stockprop_id,
        success: function (r) {
            if (r.error) { alert(r.error); }
            else {
                //alert(JSON.stringify(r));
                jQuery('#organization').val(r.data.organization);
                jQuery('#website').val(r.data.website);
                jQuery('#genbank_accession').val(r.data.genbank_accession);
                jQuery('#funded_by').val(r.data.funded_by);
                jQuery('#funder_project_id').val(r.data.funder_project_id);
                jQuery('#contact_email').val(r.data.contact_email);
                jQuery('#sequencing_year').val(r.data.sequencing_year);
                jQuery('#publication').val(r.data.publication);
                jQuery('#jbrowse_link').val(r.data.jbrowse_link);
                jQuery('#blast_db_id').val(r.data.blast_db_id);
                jQuery('#ftp_link').val(r.data.ftp_link);
                jQuery('#ncbi_link').val(r.data.ncbi_link);
                jQuery('#stockprop_id').val(r.data.stockprop_id);
                jQuery('#sequencing_status_stock_id').val(r.data.stock_id);
                jQuery('#website').val(r.data.website);
                jQuery('#edit_sequencing_info_dialog').modal("show");
            }
        },
        error: function (r) { alert("an error occurred"); }
    });



}
