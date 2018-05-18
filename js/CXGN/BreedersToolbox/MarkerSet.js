
jQuery(document).ready(function (){

    var lo = new CXGN.List();

    get_select_box('genotyping_protocol','selected_protocol');

    $('#selected_marker_set').html(lo.listSelect('selected_marker_set', ['markers']));

    $("#save_marker_set").click(function(){
        var markerSetName = $('#new_marker_set').val();
        if (!markerSetName) {
            alert("Marker set name is required");
            return;
        }

        var list_id = lo.newList(markerSetName);
        lo.setListType(list_id, 'markers')
        alert("Added new marker set");
        return list_id
    });

    $("#add_marker").click(function(){
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
});
