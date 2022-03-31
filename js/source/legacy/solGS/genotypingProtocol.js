/**
 * Sets genotyping protocol for solGS and related analysis
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.genotypingProtocol = {
  setGenotypingProtocol: function (divPlace, arg) {
    var msg = "You are using genotyping protocol: <b>" + arg.name + "</b>.";

    if (divPlace) {
      divPlace = divPlace + " ";
    }

    jQuery(divPlace + "#genotyping_protocol #genotyping_protocol_message").val(arg.protocol_id);
    jQuery(divPlace + "#genotyping_protocol #genotyping_protocol_message").html(msg);

    var page = document.URL;
    var host = window.location.protocol + "//" + window.location.host;
    page = page.replace(host, "");
    var popType = [
      "solgs/trait/",
      "solgs/traits/all/",
      "solgs/combined/model/",
      "solgs/models/combined/trials/",
    ];

    if (popType.filter((item) => item.match(/page/))) {
      console.log("setting selection pop genotype pop...");
      jQuery(divPlace + "#genotyping_protocol #selection_pop_genotyping_protocol_id").val(
        arg.protocol_id
      );
    } else {
      jQuery(divPlace + "#genotyping_protocol #genotyping_protocol_id").val(arg.protocol_id);
    }
  },

  getAllProtocols: function () {
    jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: "/get/genotyping/protocols/",
      success: function (res) {
        var divPlaces = [""];
        if (document.URL.match(/breeders/)) {
          divPlaces = ["#pca_div", "#cluster_div", "#kinship_div"];
        }

        for (i = 0; i < divPlaces.length; i++) {
          solGS.genotypingProtocol.setGenotypingProtocol(divPlaces[i], res.default_protocol);
        }

        solGS.genotypingProtocol.populateMenu(res.all_protocols);
      },
    });
  },

  createGenoProtocolsOpts: function (allProtocols) {
    var genoProtocols;

    for (var i = 0; i < allProtocols.length; i++) {
      genoProtocols +=
        '<option value="' + allProtocols[i].protocol_id + '">' + allProtocols[i].name + "</option>";
    }

    return genoProtocols;
  },

  populateMenu: function (allProtocols) {
    var menu = this.createGenoProtocolsOpts(allProtocols);
    jQuery("#genotyping_protocol #genotyping_protocols_list_select").append(menu);
  },

  formatId: function (divPlace) {
    divPlace = divPlace ? "#" + divPlace : "";
    return divPlace;
  },
};

jQuery(document).ready(function () {
  solGS.genotypingProtocol.getAllProtocols();
});

jQuery(document).ready(function () {
  jQuery("#genotyping_protocol #genotyping_protocols_change").click(function () {
    var divPlace = jQuery(this).parent().parent().parent().attr("id");
    divPlace = solGS.genotypingProtocol.formatId(divPlace);

    jQuery(divPlace + " #genotyping_protocol #genotyping_protocols_list_div").show();
    jQuery(divPlace + " #genotyping_protocol #genotyping_protocols_change").hide();
  });
});

jQuery(document).ready(function () {
  jQuery("<option>", { value: "", selected: true }).prependTo(
    "#genotyping_protocol #genotyping_protocols_list_select"
  );

  jQuery("#genotyping_protocol #genotyping_protocols_list_select").change(function () {
    var selectedId = jQuery(this).find("option:selected").val();
    var selectedName = jQuery(this).find("option:selected").text();

    var selected = {
      protocol_id: selectedId,
      name: selectedName,
    };

    var divPlace = jQuery(this).parent().parent().parent().attr("id");
    divPlace = solGS.genotypingProtocol.formatId(divPlace);
    solGS.genotypingProtocol.setGenotypingProtocol(divPlace, selected);

    jQuery(divPlace + " #genotyping_protocol #genotyping_protocols_list_div").hide();
    jQuery(
      divPlace + " #genotyping_protocol #genotyping_protocols_list_select option:selected"
    ).prop("selected", false);
    jQuery(divPlace + " #genotyping_protocol #genotyping_protocols_change").show();
  });
});
