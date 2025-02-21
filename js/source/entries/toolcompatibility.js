

const abbreviations = {
    'pca' : 'Population Structure',
    'cluster' : 'Clustering',
    'kinship' : 'Kinship & Inbreeding',
    'corr' : 'Correlation',
    'SolGWAS' : 'GWAS',
    'Heritability' : 'Heritability',
    'Stability' : 'Stability'
}

function substituteCompatibilities(abbreviation) {
    jQuery('[id^="compatibility_glyph"]').each(function(index, element){

        var selector_id = element.id;
        var dataset_id = selector_id.split("_")[2];
        var compatibility_message;
        
        $.ajax({
            url: '/ajax/dataset/retrieve/' + dataset_id + '/tool_compatibility'
        }).then(function(response){
            if (response.error) {
                compatibility_message = 'error';
            } else {
                var tool_compatibility = JSON.parse(response.tool_compatibility);
                if (tool_compatibility == "(not calculated)") {
                    compatibility_message = "(not calculated)";
                } else {
                    if (tool_compatibility[abbreviations[abbreviation]]['compatible'] == 0) {
                    compatibility_message = '<b><span class="glyphicon glyphicon-remove" style="color:red"></span></b>'
                    } else {
                        if ('warn' in tool_compatibility[abbreviations[abbreviation]]) {
                            compatibility_message = '<b><span class="glyphicon glyphicon-warning-sign" style="color:orange;font-size:14px" title="' + tool_compatibility[abbreviations[abbreviation]]['warn'] + '"></span></b>';
                        } else {
                            compatibility_message = '<b><span class="glyphicon glyphicon-ok" style="color:green"></span></b>';
                        }
                    }
                }
            }
            jQuery(`#compatibility_glyph_${dataset_id}`).html(compatibility_message);
        }).catch(function(error) {
            console.log(error.error);
            jQuery(`#compatibility_glyph_${dataset_id}`).text('(not calculated)');
        });
    });
}

jQuery(document).ready(function() {

    jQuery('[id$=_pops_table]').each(function(index,element){
        var table_id = element.id;
        var analysis_abbr = table_id.split("_")[0];
        var table = jQuery(`#${table_id}`);

        substituteCompatibilities(analysis_abbr);

        table.on('draw.dt', function() {
            substituteCompatibilities(analysis_abbr);
        });
    });
});
