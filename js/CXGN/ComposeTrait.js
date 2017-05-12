
function create_multi_selects(cv_names) {
    jQuery('#compose_trait').prop('disabled', true);
    var names = cv_names.split(',');

    for(i = 0; i < names.length; i++){
        var cv_name = names[i];
        var name = cv_name.trim();

        switch (name) {
            case "time":
                jQuery("#tod_div,#toy_div,#gen_div").show();
                get_select_box('ontology_children', 'tod_select_div', { 'selectbox_id' : 'tod_select', 'selectbox_name': 'tod_select', 'multiple': 'true', 'parent_node_cvterm': 'time of day|TIME:0000001', 'rel_cvterm': 'is_a', 'rel_cv': 'relationship' });
                get_select_box('ontology_children', 'toy_select_div', { 'selectbox_id' : 'toy_select', 'selectbox_name': 'toy_select', 'multiple': 'true', 'parent_node_cvterm': 'time of year|TIME:0000005', 'rel_cvterm': 'is_a', 'rel_cv': 'relationship' });
                get_select_box('ontology_children', 'gen_select_div', { 'selectbox_id' : 'gen_select', 'selectbox_name': 'gen_select', 'multiple': 'true', 'parent_node_cvterm': 'generation|TIME:0000072', 'rel_cvterm': 'is_a', 'rel_cv': 'relationship' });
                break;
            case "tod":
                jQuery("#tod_div").show();
                get_select_box('ontology_children', 'tod_select_div', { 'selectbox_id' : 'tod_select', 'selectbox_name': 'tod_select', 'multiple': 'true', 'parent_node_cvterm': 'time of day|TIME:0000001', 'rel_cvterm': 'is_a', 'rel_cv': 'relationship' });
                break;
            case "toy":
                jQuery("#toy_div").show();
                get_select_box('ontology_children', 'toy_select_div', { 'selectbox_id' : 'toy_select', 'selectbox_name': 'toy_select', 'multiple': 'true', 'parent_node_cvterm': 'time of year|TIME:0000005', 'rel_cvterm': 'is_a', 'rel_cv': 'relationship' });
                break;
            case "gen":
                jQuery("#gen_div").show();
                get_select_box('ontology_children', 'gen_select_div', { 'selectbox_id' : 'gen_select', 'selectbox_name': 'gen_select', 'multiple': 'true', 'parent_node_cvterm': 'generation|TIME:0000072', 'rel_cvterm': 'is_a', 'rel_cv': 'relationship' });
                break;
            default:
                if (window.console) console.log("Did not recognize "+name+" category");
        }
    }
}

function display_matching_traits () {

var component_ids = get_component_ids();
// restrict to allowed combos here
//console.log("component_ids are "+component_ids);
var response = retrieve_matching_traits(component_ids);
var matching_traits = [];
if (response[0]) {matching_traits = response[0]};
var new_traits = [];
if (response[1]) { new_traits = response[1]};
//console.log("New traits are "+new_traits);
var trait_html;
var new_trait_html;

if (matching_traits.length > 0) {
  trait_html = format_options_list(matching_traits);
}
else {
  trait_html = 'No matching traits.';
}
if (new_traits.length > 0) {
  new_trait_html = format_options_list(new_traits);
}
else {
  new_trait_html = 'No new traits.';
  jQuery('#compose_trait').prop('disabled', true);
}

jQuery('#existing_traits').html(trait_html);
jQuery('#new_traits').html(new_trait_html);
if (jQuery('#new_traits').val()) {
    jQuery('#compose_trait').prop('disabled', false);
}
else {
    jQuery('#compose_trait').prop('disabled', true);
}

}

function get_component_ids () {
  var component_ids = [];
  if (jQuery("#object_select").val()) { component_ids.push(jQuery("#object_select").val()); }
  if (jQuery("#attribute_select").val()) { component_ids.push(jQuery("#attribute_select").val()); }
  if (jQuery("#method_select").val()) { component_ids.push(jQuery("#method_select").val()); }
  if (jQuery("#unit_select").val()) { component_ids.push(jQuery("#unit_select").val()); }
  if (jQuery("#trait_select").val()) { component_ids.push(jQuery("#trait_select").val()); }
  if (jQuery("#tod_select").val()) { component_ids.push(jQuery("#tod_select").val()); }
  if (jQuery("#toy_select").val()) { component_ids.push(jQuery("#toy_select").val()); }
  if (jQuery("#gen_select").val()) { component_ids.push(jQuery("#gen_select").val()); }
  return component_ids;
}

function retrieve_matching_traits (component_ids) {
  if (component_ids.length < 1) {
    return [];
  }
  var ids = {};
  ids["object_ids"] = jQuery("#object_select").val();
  ids["attribute_ids"] = jQuery("#attribute_select").val();
  ids["method_ids"] = jQuery("#method_select").val();
  ids["unit_ids"] = jQuery("#unit_select").val();
  ids["trait_ids"] = jQuery("#trait_select").val();
  ids["tod_ids"] = jQuery("#tod_select").val();
  ids["toy_ids"] = jQuery("#toy_select").val();
  ids["gen_ids"] = jQuery("#gen_select").val();

jQuery.ajax( {
  url: '/ajax/onto/get_traits_from_component_categories',
  async: false,
  data: { 'object_ids': ids["object_ids"],
          'attribute_ids': ids["attribute_ids"],
          'method_ids': ids["method_ids"],
          'unit_ids': ids["unit_ids"],
          'trait_ids': ids["trait_ids"],
          'tod_ids': ids["tod_ids"],
          'toy_ids': ids["toy_ids"],
          'gen_ids': ids["gen_ids"],
        },
  success: function(response) {
    traits = response.existing_traits || [];
    new_traits = response.new_traits || [];
    //console.log("traits="+traits+"\n newtraits="+new_traits);
  },
  error: function(request, status, err) {
    console.log("Error retrieving matches");
  }
});
  return [traits, new_traits];
}
