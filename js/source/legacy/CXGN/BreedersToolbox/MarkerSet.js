
jQuery(document).ready(function (){

    get_select_box('genotyping_protocol','selected_protocol', {'empty':1});

    var lo = new CXGN.List();
    jQuery('#selected_marker_set1').html(lo.listSelect('selected_marker_set1', ['markers'], 'Select a markerset', 'refresh', 'hide_public_lists' ));

    var list = new CXGN.List();
    jQuery('#selected_marker_set2').html(list.listSelect('selected_marker_set2', ['markers'], 'Select a markerset', 'refresh', undefined));


    jQuery("#save_marker_set").click(function(){
        var name = $('#new_marker_set').val();
        if (!name) {
            alert("Markerset name is required");
            return;
        }

        var protocol_id = $('#selected_protocol').val();
        if (!protocol_id) {
            alert("Genotyping protocol is required");
            return;
        }

        var data_type = $('#genotyping_data_type').val();
        if (!data_type) {
            alert("Genotyping data type is required");
            return;
        }

        var protocol_name = $('#selected_protocol').find(":selected").text();
        var desc = $('#marker_set_desc').val();

        if (!desc) {
            alert("Please provide description");
            return;
        }

        var list_id = lo.newList(name, desc);
        lo.setListType(list_id, 'markers');

        var markersetProtocol = {};
        markersetProtocol.genotyping_protocol_name = protocol_name;
        markersetProtocol.genotyping_protocol_id = protocol_id;
        markersetProtocol.genotyping_data_type = data_type;

        var markersetProtocolString = JSON.stringify(markersetProtocol);

        var protocolAdded = lo.addToList(list_id, markersetProtocolString);
        if (protocolAdded){
            alert ("Added new markerset: " + name + " for genotyping protocol: " + protocol_name + " ," + "data type: " + data_type);
        }
        location.reload();
        return list_id;

    });

    var markersetType;
    jQuery(document).on("change", "#selected_marker_set1", function() {

        var markersetID = jQuery('#selected_marker_set1').val();

        jQuery.ajax({
            url: '/markerset/type',
            data: {'markerset_id': markersetID},
            success: function(response) {
                markersetType = response.type;
                if (markersetType == "Dosage") {
                    jQuery("#markerset_dosage_section").show();
                    jQuery("#markerset_snp_section").hide();
                } else if (markersetType == "SNP") {
                    jQuery("#markerset_snp_section").show();
                    jQuery("#markerset_dosage_section").hide();
                } else {
                    jQuery("#markerset_dosage_section").hide();
                    jQuery("#markerset_snp_section").hide();
                }
            },
        });
    });

    jQuery("#add_marker").click(function(){
        var markerSetID = $('#selected_marker_set1').val();
        if (!markerSetID) {
            alert("Markerset name is required");
            return;
        }

        var markerName = $('#marker_name').val();
        if (!markerName) {
            alert("Marker name is required");
            return;
        }

        var dosage = $('#allele_dosage').val();
        var allele1 = $('#allele_1').val();
        var allele2 = $('#allele_2').val();

        if ((markersetType == "Dosage") && (dosage == '')) {
            alert("Please indicate a dosage");
            return;
        }

        if ((markersetType == 'SNP') && ((allele1 == '') || ( allele2 == ''))) {
            alert("Please indicate SNP alleles");
            return;
        }

        var markerDosage = {};

        markerDosage.marker_name = markerName;

        if (dosage){
            markerDosage.allele_dosage = dosage;
        }

        if (allele1){
            markerDosage.allele1 = allele1;
        }

        if (allele2){
            markerDosage.allele2 = allele2;
        }

        var markerDosageString = JSON.stringify(markerDosage);

        var markerAdded = lo.addToList(markerSetID, markerDosageString);
        if (markerAdded){
            alert("Added "+markerDosageString);
        }

        location.reload();
        return markerSetName;

    });

    jQuery("#add_parameters").click(function(){
        var markerSetName = $('#selected_marker_set2').val();
        if (!markerSetName) {
            alert("Markerset name is required");
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
        'destroy': true,
        'ajax':{'url': '/marker_sets/available'},
        'columns': [
            {title: "Markerset Name", "data": "markerset_name"},
            {title: "Number of Markers", "data": "number_of_markers"},
            {title: "Description", "data": "description"},
            {title: "", "data": "null", "render": function (data, type, row) {return "<a onclick = 'showMarkersetDetail("+row.markerset_id+")'>Detail</a>" ;}},
            {title: "", "data": "null", "render": function (data, type, row) {return "<a onclick = 'removeMarkerSet("+row.markerset_id+")'>Delete</a>" ;}},
        ],
    });
}

function removeMarkerSet (markerset_id){
    if (confirm("Are you sure you want to delete this markerset? This cannot be undone")){
        jQuery.ajax({
            url: '/markerset/delete',
            data: {'markerset_id': markerset_id},
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                if (response.success == 1) {
                    alert("The markerset has been deleted.");
                    location.reload();
                }
                if (response.error) {
                    alert(response.error);
                }
            },
            error: function(response){
                jQuery('#working_modal').modal('hide');
                alert('An error occurred deleting markerset');
            }
        });
    }
}


function showMarkersetDetail (markerset_id){
    jQuery.ajax({
        url: '/markerset/items',
        data: {'markerset_id': markerset_id},
        beforeSend: function(){
            jQuery('#working_modal').modal('show');
        },
        success: function(response) {
            jQuery('#working_modal').modal('hide');
            if (response.success == 1) {
                jQuery('#markerset_detail_dialog').modal('show');
                var markerset_detail_table = jQuery('#markerset_detail_table').DataTable({
                    'destroy': true,
                    'data': response.data,
                    'columns': [
                        {title: "Item", "data": "item_name"},
                    ],
                });
            } else {
                alert(response.error);
            }
        },
        error: function(response){
            jQuery('#working_modal').modal('hide');
            alert('An error occurred getting markerset detail');
        }
    });
}
