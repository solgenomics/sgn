
jQuery(document).ready(function (){

    var lo = new CXGN.List();

    get_select_box('genotyping_protocol','selected_protocol');

    jQuery('#selected_marker_set').html(lo.listSelect('selected_marker_set', ['markers']));

    jQuery("#save_marker_set").click(function(){
        var name = $('#new_marker_set').val();
        if (!name) {
            alert("Marker set name is required");
            return;
        }

        var desc = $('#marker_set_desc').val();

        var list_id = lo.newList(name, desc);
        lo.setListType(list_id, 'markers')
        alert("Added new marker set");
        return list_id
    });

    jQuery("#add_marker").click(function(){
        var markerSetName = $('#selected_marker_set').val();
        if (!markerSetName) {
            alert("Marker set name is required");
            return;
        }

        var protocol = $('#selected_protocol').val();
        if (!protocol) {
            alert("Genotyping protocol is required");
            return;
        }

        var markerName = $('#marker_name').val();
        if (!markerName) {
            alert("Marker name is required");
            return;
        }

        var dosage = $('#allele_dosage').val();
        if (!dosage) {
            alert("Allele dosage is required");
            return;
        }

        var markerDosage = {};
        markerDosage[protocol] = {};
        markerDosage[protocol][markerName] = dosage;

        var markerDosageString = JSON.stringify(markerDosage);

        var markerAdded = lo.addToList(markerSetName, markerDosageString);
        alert("Added"+markerDosageString);
        return markerSetName;

    });

    show_table();
});

function show_table() {
    var markersets_table = jQuery('#marker_sets').DataTable({
        'ajax':{'url': '/marker_sets/available'},
        'columns': [
            {title: "Marker Set Name"},
            {title: "Number of Markers"},
            {title: "Description"},
        ]
    });
}
