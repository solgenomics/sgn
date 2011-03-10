
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
        submitCvtermForm: function(cvterm_add_uri , object_id) {
        //make an AJAX request with the form params
        var cvterm = jQuery("#term_name").val();
        jQuery.ajax({ url: cvterm_add_uri , method:"POST", data: 'object_id='+ object_id +'&term_name='+$('term_name') ,
                    success: function(response) {
                    var error = response.error;
                    if (error) { alert(error) ; }
                    this.displayOntologies( "ontology" );
                }
            } );
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
        if (!relationship_uri)  relationship_uri = '/cvterm/ajax/relationships' ;
        if (!rel_div) rel_div = 'relationship_select' ;
        jQuery(function() {
                jQuery("#term_name").autocomplete({
                        source: autocomplete_url + "?db_name="+jQuery("#db_name").val(),
                        wait: 2,
                        change: Ontology.populateEvidence(rel_div, relationship_uri)
                    });
            });
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
                    var options = '';
                    if (!dummy_option) dummy_option = '--Please select one--';
                    options += '<option value="">' + dummy_option + '</option>';
                    for ( var id in response) {
                        options += '<option value="' + id + '">' + response[id]+ '</option>';
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
