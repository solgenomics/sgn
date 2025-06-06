// Cached allele values by marker name
// This is updated each time the selected markerset is changed
var ALLELES = {}

jQuery(document).ready(function (){
    ALLELES_BY_MARKER = {};
    MARKER_BY_ALLELE = {};

    get_select_box('genotyping_protocol','selected_protocol', {'empty':1});

    var lo = new CXGN.List();
    jQuery('#selected_marker_set1').html(lo.listSelect('selected_marker_set1', ['markers'], 'Select a list of marker alleles', 'refresh', 'hide_public_lists' ));

    var list = new CXGN.List();
    jQuery('#selected_marker_set2').html(list.listSelect('selected_marker_set2', ['markers'], 'Select a list of marker alleles', 'refresh', undefined));


    jQuery("#save_marker_set").click(function(){
        var name = $('#new_marker_set').val();
        if (!name) {
            alert("List name is required");
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

        var list_id = lo.newList(name, desc);
        lo.setListType(list_id, 'markers');

        var markersetProtocol = {};
        markersetProtocol.genotyping_protocol_name = protocol_name;
        markersetProtocol.genotyping_protocol_id = protocol_id;
        markersetProtocol.genotyping_data_type = data_type;

        var markersetProtocolString = JSON.stringify(markersetProtocol);
        lo.addToList(list_id, markersetProtocolString);

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
                    jQuery("#markerset_download_section").hide();
                } else if (markersetType == "SNP") {
                    jQuery("#markerset_snp_section").show();
                    jQuery("#markerset_dosage_section").hide();
                    jQuery("#markerset_download_section").hide();
                } else if (markersetType == "Download") {
                    jQuery("#markerset_download_section").show();
                    jQuery("#markerset_dosage_section").hide();
                    jQuery("#markerset_snp_section").hide();
                } else {
                    jQuery("#markerset_snp_section").hide();
                    jQuery("#markerset_dosage_section").hide();
                    jQuery("#markerset_download_section").hide();
                }
            },
        });
    });

    jQuery("#add_marker").click(function(){
        var markerInfo = {};
        var markerAdded = false;

        var markerSetID = $('#selected_marker_set1').val();
        if (markerSetID == '') {
            alert("List name is required");
            return;
        }

        if (markersetType == "Dosage") {
            var markerNameDosage = $('#marker_name_dosage').val();
            var dosage = $('#allele_dosage').val();

            if (markerNameDosage == '') {
                alert("Marker name is required");
                return;
            }
            if (dosage == '') {
                alert("Please indicate a dosage");
                return;
            }

            markerInfo.marker_name = markerNameDosage;
            markerInfo.allele_dosage = dosage;
            var markerInfoString = JSON.stringify(markerInfo);

            markerAdded = lo.addToList(markerSetID, markerInfoString);
        }

        if (markersetType == "SNP") {
            var multiple_tab_selected = jQuery("#markerset_snp_section_tab li.active")[0]?.id === "markerset_snp_section_multiple";

            if ( multiple_tab_selected ) {
                var markerInfos = [];
                var missingAlleles = [];
                var alleleNames = jQuery("#allele_names").val()?.split('\n');

                // Find corresponding marker for each allele
                alleleNames.forEach((alleleName) => {
                    var marker_name = MARKER_BY_ALLELE[alleleName];
                    if ( marker_name && marker_name !== "" ) {
                        markerInfo[marker_name] = alleleName;
                        markerInfos.push(
                            JSON.stringify({
                                marker_name: marker_name,
                                allele1: alleleName,
                                allele2: alleleName
                            })
                        );
                    }
                    else {
                        missingAlleles.push(alleleName);
                    }
                });

                // Display error message for alleles with no matching marker
                if ( missingAlleles.length > 0 ) {
                    alert(`The following alleles do not have a corresponding marker: ${missingAlleles.join(', ')}`);
                    return;
                }

                markerAdded = lo.addBulk(markerSetID, markerInfos);
            }

            else {
                var markerNameSNP = $('#marker_name_snp').val();
                var allele1 = $('#allele_1').val();
                var allele2 = $('#allele_2').val();

                if (markerNameSNP == '') {
                    alert("Marker name is required");
                    return;
                }
                if ((allele1 == '') || ( allele2 == '')) {
                    alert("Please indicate SNP alleles");
                    return;
                }

                markerInfo.marker_name = markerNameSNP;
                markerInfo.allele1 = allele1;
                markerInfo.allele2 = allele2;
                var markerInfoString = JSON.stringify(markerInfo);
                markerAdded = lo.addToList(markerSetID, markerInfoString);
            }
        }

        if (markersetType == "Download") {
            var markerNameArray = [];
            var markerNameDownload = $('#marker_name_download').val();

            if (markerNameDownload == '') {
                alert("Marker name is required");
                return;
            }

            var markerNames = markerNameDownload.split("\n");

            for (let i = 0; i < markerNames.length; i++) {
                markerInfo.marker_name = markerNames[i];
                markerInfoString = JSON.stringify(markerInfo);
                markerNameArray.push(markerInfoString);
            }
            markerAdded = lo.addBulk(markerSetID, markerNameArray);
        }

        if ( markerAdded ) {
            jQuery(".marker_name").val("");
            onMarkerChange();

            var html = "<strong>New Item(s) Added!</strong>&emsp;";
            var items = [];
            Object.entries(markerInfo).forEach(([key, value]) => {
                items.push(`<strong>${key}</strong>: ${value}`);
            });
            html += `<br />${items.join('&emsp;')}`;

            jQuery("#add-marker-success").html(html).css("display", "block");
        }
    });

    jQuery("#close_add_marker").click(show_table);

    jQuery("#add_parameters").click(function(){
        var markerSetName = $('#selected_marker_set2').val();
        if (!markerSetName) {
            alert("List name is required");
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

    jQuery('#selected_marker_set1').on('change', onMarkerSetChange);
    jQuery('#marker_name_snp').on('input change blur', onMarkerChange);
    jQuery('#allele_names').on('input change blur', onAlleleNamesChange);
});

function show_table() {
    var markersets_table = jQuery('#marker_sets').DataTable({
        'destroy': true,
        'ajax':{'url': '/marker_sets/available'},
        'columns': [
            {title: "List Name", "data": "markerset_name"},
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
                        {
                            title: "Item",
                            data: "item_name",
                            render: function(data) {
                                let parsed = JSON.parse(data);
                                let items = [];
                                Object.entries(parsed).forEach(([key, value]) => {
                                    items.push(`<strong>${key}</strong>: ${value}`);
                                });
                                return items.join('&emsp;');
                            }
                        },
                        {
                            title: "Remove",
                            data: "item_id",
                            render: function(data, type, row, meta) {
                                let index = meta.row;
                                let html = '';
                                if ( index > 0 ) {
                                    html = `<a href="#" onclick="removeMarkerSetListItem(${markerset_id}, ${data})">Remove</a>`;
                                }
                                return html;
                            }
                        }
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

// Handle a change in selected markerset
// - Update the marker name autocomplete
// - Update the cached allele values for every marker in markerset protocol
function onMarkerSetChange() {
    var list_id = jQuery(this).val();

    jQuery("#markerset_snp_section_tab").css("display", "none");
    ALLELES_BY_MARKER = {};
    MARKER_BY_ALLELE = {};

    if ( list_id && list_id !== '' ) {
        var lo = new CXGN.List();
        var markerset_list = lo.getList(list_id);
        var metadata = JSON.parse(markerset_list[0]);
        var protocol_id = metadata.genotyping_protocol_id;

        // Set marker name autocomplete
        jQuery("#marker_name_snp").autocomplete({
            source: `/ajax/genotyping_protocol/locus_marker_autocomplete?protocol_id=${protocol_id}`,
        });
        jQuery("#marker_name_snp").on("autocompleteclose", onMarkerChange);

        // Get all possible allele values
        jQuery.ajax({
            url: `/ajax/genotyping_protocol/get_marker_metadata/${protocol_id}`,
            success: function(resp) {
                if ( resp ) {
                    Object.keys(resp).forEach((marker) => {
                        ALLELES_BY_MARKER[marker] = resp[marker].alleles.map((x) => x.allele_name);
                        (resp[marker].alleles || []).forEach((a) => {
                            MARKER_BY_ALLELE[a.allele_name] = marker;
                        })
                    });
                }
                jQuery("#allele_names").attr("placeholder", ["Enter Allele names, one per line", ...Object.keys(MARKER_BY_ALLELE)].join('\n'));
                if ( Object.keys(ALLELES_BY_MARKER).length > 0 ) {
                    jQuery("#markerset_snp_section_tab").css("display", "block");
                }
            }
        });
    }
}

// Handle a change in marker name
// - Hide the success message
// - Update the displayed allele values
function onMarkerChange() {
    jQuery("#add-marker-success").css("display", "none");
    let html = "<option>Enter marker name first</option>";
    let disabled = true;

    var marker = jQuery('#marker_name_snp').val();
    if ( marker && marker !== "" ) {

        // Default to ATCG alleles
        var alleles = ["A", "T", "G", "C"];
        disabled = false;
        html = "";

        // Set alleles based on marker metadata
        if ( ALLELES_BY_MARKER.hasOwnProperty(marker) ) {
            alleles = ALLELES_BY_MARKER[marker]
        }

        // Build options based on available alleles
        alleles.forEach((allele) => {
            html += `<option value="${allele}">${allele}</option>`;
        });

    }

    jQuery("#allele_1").html(html).attr("disabled", disabled);
    jQuery("#allele_2").html(html).attr("disabled", disabled);
}

// Handle a change in the allele names textarea
// - Hide the success message
function onAlleleNamesChange() {
    jQuery("#add-marker-success").css("display", "none");
}

// Remove the specified list item from the list
// - Display the list details dialog again after removing
function removeMarkerSetListItem(list_id, list_item_id) {
    var confirmation = confirm("Are you sure you want remove this item from the marker set?");
    if ( confirmation ) {
        var lo = new CXGN.List();
        lo.removeItem(list_id, list_item_id);
        showMarkersetDetail(list_id);
        show_table();
    }
}