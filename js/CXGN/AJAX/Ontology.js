
/**
* @class Ontology
* Function used for printing ontology annotations
* and helper functions for populating the menus of the associate_ontology tool
* @author Naama Menda <nm249@cornell.edu>
*
*/

JSAN.use('jquery');
JSAN.use('jqueryui');
JSAN.use('popup');


var Ontology = {
    submitCvtermForm: function(cvterm_add_uri, ontology_url) {
        var onto_html = this.displayOntologies( "ontology" , ontology_url);
        //make an AJAX request with the form params
        var object_id = jQuery('#object_id').val();
        var relationship = jQuery('#relationship_select').val();
        var evidence_code = jQuery('#evidence_code_select').val();
        var evidence_description = jQuery('#evidence_description_select').val();
        var evidence_with = jQuery('#evidence_with_select').val();
        var reference = jQuery('#reference_select').val();
        jQuery.ajax({
                type: 'POST',
                    dataType: "json",
                    url: cvterm_add_uri ,
                    data: 'term_name='+jQuery('#term_name').val()+'&object_id='+object_id+'&relationship='+relationship+'&evidence_code='+evidence_code+'&evidence_description='+evidence_description+'&evidence_with='+evidence_with+'&reference='+reference ,
                    success: function(response) {
                    var error = response.error;
                    if (error) { alert(error) ; }
                }
            } );
        jQuery("#ontology").html( this.displayOntologies( "ontology" , ontology_url) );
    },

    displayOntologies: function(div_id, url) {
        //alternate show the annotation and the detailed evidence
        jQuery(function() {
                jQuery("#ontology_show_details").show()
                jQuery("#ontology_show_details input").click(function() {
                        if( this.checked ) {
                            jQuery("#ontology .evidence").show();
                            jQuery(this).addClass('active');
                        } else {
                            jQuery("#ontology .evidence").hide();
                            jQuery(this).removeClass('active');
                        }
                    });
            });
        jQuery.ajax( { url: url , dataType: "json",
                    success: function(response) {
                    var json = response;
                    jQuery("#"+div_id).html(response.html);
                    if ( response.error ) { alert(x.error) ; }
                    if (response.html ) {
                        jQuery("#ontology_show_details input").first()[0].disabled = false;
                        jQuery("#ontology .evidence").hide();
                    } else { jQuery('#ontology_show_details').hide(); }
                }
            });
    },

    updateAutocomplete: function(autocomplete_url, relationship_uri, rel_div) {
        // setting some default values
        if (!autocomplete_url) autocomplete_url = '/ajax/cvterm/autocomplete';
        if (!relationship_uri)  relationship_uri = '/ajax/cvterm/relationships' ;
        if (!rel_div) rel_div = 'relationship_select' ;
        var term = jQuery("#term_name").val();
        var db_name = jQuery("#db_name").val();
        if (term.length > 2 && db_name.length > 0 ) {
            jQuery(function() {
                    jQuery("#term_name").autocomplete({
                            source: autocomplete_url + "?db_name="+db_name,
                                //wait: 2,
                                change: Ontology.populateEvidence(rel_div, relationship_uri)
                                });
                });
        }
    },
    ////
    //Make an ajax request for finding the available objects for ontology evidence
    //(relationships, evidence codes, evidence description
    populateEvidence: function(div_id, uri, dummy_option) {
        jQuery.ajax({ url: uri , method:"POST" ,
                      success: function(response) {
                    var error = response.error;
                    if (error) { alert(error) ; }
                    var select = jQuery('#'+div_id);
                    ////
                    var arraykeys=[];
                    for(var k in response) {arraykeys.push(k); }
                    arraykeys.sort();
                    var outputarray=[];
                    for(var i=0; i<arraykeys.length; i++) {
                        outputarray[arraykeys[i]]=response[arraykeys[i]];
                    }
                    ////
                    var options = '';
                    if (!dummy_option) dummy_option = '--Please select one--';
                    options += '<option value="">' + dummy_option + '</option>';
                    for ( var j in outputarray) {
                        if ( !(isNaN(outputarray[j])) ) {
                            options += '<option value="' + outputarray[j] + '">' + j + '</option>';
                        }
                    }
                    jQuery("#"+div_id).html(options);
                }
            });
    },
    getEvidenceWith: function() {
    },
    getReference: function() {
    },

}
