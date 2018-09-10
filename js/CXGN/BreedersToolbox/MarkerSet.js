
jQuery(document).ready(function (){

    get_select_box('genotyping_protocol','selected_protocol', {'empty':1});

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

        var protocol_id = $('#selected_protocol').val();
        if (!protocol_id) {
            alert("Genotyping protocol is required");
            return;
        }

        var protocol_name = $('#selected_protocol').find(":selected").text();
        var desc = $('#marker_set_desc').val();

        var list_id = lo.newList(name, desc);
        lo.setListType(list_id, 'markers');

        var markersetProtocol = {};
        markersetProtocol.genotyping_protocol_name = protocol_name;
        markersetProtocol.genotyping_protocol_id = protocol_id;
        var markersetProtocolString = JSON.stringify(markersetProtocol);

        var protocolAdded = lo.addToList(list_id, markersetProtocolString);
        if (protocolAdded){
            alert ("Added new marker set: " + name + " for genotyping protocol: " + protocol_name);
        }
        location.reload();
        return list_id;

    });

    jQuery("#add_marker").click(function(){
        var markerSetName = $('#selected_marker_set1').val();
        if (!markerSetName) {
            alert("Marker set name is required");
            return;
        }

        var markerName = $('#marker_name').val();
        if (!markerName) {
            alert("Marker name is required");
            return;
        }

        var dosage = $('#allele_dosage').val();

        var markerDosage = {};

        markerDosage.marker_name = markerName;

        if (dosage){
            markerDosage.allele_dosage = dosage;
        }

        var markerDosageString = JSON.stringify(markerDosage);

        var markerAdded = lo.addToList(markerSetName, markerDosageString);
        if (markerAdded){
            alert("Added "+markerDosageString);
        }
        location.reload()
        return markerSetName;

    });

    jQuery("#add_parameters").click(function(){
        var markerSetName = $('#selected_marker_set2').val();
        if (!markerSetName) {
            alert("Marker set name is required");
            return;
        }

        var chromosomeNumber = $('#chromosome_number').val();
        var startPosition  = $('#start_position').val();
        var endPosition = $('#end_position').val();
        var markerName = $('#marker_name2').val();
        var snpAllele = $('#snp_allele').val();
        var quality = $('#quality').val();
        var filterStatus = $('#filter_status').val();

        var vcfParameters = {};

        if (chromosomeNumber) {
            vcfParameters.chromosome = chromosomeNumber
        }

        if (startPosition) {
            vcfParameters.start_position = startPosition
        }

        if (endPosition) {
            vcfParameters.end_position = endPosition
        }

        if (markerName) {
            vcfParameters.marker_name = markerName
        }

        if (snpAllele) {
            vcfParameters.snp_allele = snpAllele
        }

        if (quality) {
            vcfParameters.quality_score = quality
        }

        if (filterStatus) {
            vcfParameters.filter_status = filterStatus
        }

        var parametersString = JSON.stringify(vcfParameters);

        var markerAdded = list.addToList(markerSetName, parametersString);
        if (markerAdded) {
            alert("Added "+parametersString);
        }
        location.reload();
        return markerSetName;

    });

    show_table();
});

function show_table() {
    var markersets_table = jQuery('#marker_sets').DataTable({
        'ajax':{'url': '/marker_sets/available'},
        'columns': [
            {title: "Marker Set Name", "data": "markerset_name"},
            {title: "Number of Items", "data": "number_of_markers"},
            {title: "Description", "data": "description"},
        ]
    });
}
