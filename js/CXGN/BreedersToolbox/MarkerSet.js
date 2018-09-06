
jQuery(document).ready(function (){

    get_select_box('genotyping_protocol','selected_protocol1', {'id':'genotyping_protocol_select1', 'name':'genotyping_protocol_select1', 'multiple':0});
    get_select_box('genotyping_protocol','selected_protocol2', {'id':'genotyping_protocol_select2', 'name':'genotyping_protocol_select2', 'multiple':0});

    var lo = new CXGN.List();
    jQuery('#selected_marker_set1').html(lo.listSelect('selected_marker_set1', ['markers'], 'Select a marker set', 'refresh'));

    var list = new CXGN.List();
    jQuery('#selected_marker_set2').html(list.listSelect('selected_marker_set2', ['markers'], 'Select a marker set', 'refresh'));


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
        var markerSetName = $('#selected_marker_set1').val();
        if (!markerSetName) {
            alert("Marker set name is required");
            return;
        }

        var protocol = $('#selected_protocol1').val();
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
            {title: "Marker Set Name", "data": "markerset_name"},
            {title: "Number of Markers", "data": "number_of_markers"},
            {title: "Description", "data": "description"},
        ]
    });
}
