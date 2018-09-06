
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

    jQuery("#add_parameters").click(function(){
        var markerSetName = $('#selected_marker_set2').val();
        if (!markerSetName) {
            alert("Marker set name is required");
            return;
        }

        var protocol = $('#selected_protocol2').val();
        if (!protocol) {
            alert("Genotyping protocol is required");
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

        if (protocol) {
            vcfParameters.genotyping_protocol = protocol
        }

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
        alert("Added"+parametersString);
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
