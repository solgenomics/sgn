

/**

autocomplete related js logic for solgs

Isaak Y Tecle 
iyt2@cornell.edu
*/


//trait search autocomplete
jQuery(document).ready( function() {
        jQuery("#search_trait_entry").autocomplete({
                source: "/solgs/ajax/trait/search",
                minLength: 3,
       });
    });


//population search autocomplete
jQuery(document).ready( function() {
        jQuery("#population_search_entry").autocomplete({
                source: "/solgs/ajax/population/search",
                minLength: 3,
       });
    });
    

