/**
 * Sets genotyping protocol for solGS and related analysis
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.genotypingProtocol = {
  setGenotypingProtocol: function (divPlace, arg) {
    var protocolName = arg.name || arg.protocol_name;
    var msg = "You are using genotyping protocol: <b>" + protocolName + "</b>.";
    divPlace = this.formatDivId(divPlace);

    jQuery(divPlace + " #genotyping_protocol #genotyping_protocol_message").val(arg.protocol_id);
    jQuery(divPlace + " #genotyping_protocol #genotyping_protocol_message").html(msg);

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
      jQuery(divPlace + " #genotyping_protocol #selection_pop_genotyping_protocol_id").val(
        arg.protocol_id
      );
    } else {
      jQuery(divPlace + " #genotyping_protocol #genotyping_protocol_id").val(arg.protocol_id);
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

        var sessionGenoProtocol;
        if (document.URL.match(/solgs\//)) {
          sessionGenoProtocol = solGS.genotypingProtocol.getSessionGenoProtocol();
          console.log("sessionGenProtocol " + sessionGenoProtocol);
        }

        for (i = 0; i < divPlaces.length; i++) {
          if (sessionGenoProtocol) {
            solGS.genotypingProtocol.setGenotypingProtocol(divPlaces[i], sessionGenoProtocol);
          } else {
            solGS.genotypingProtocol.setGenotypingProtocol(divPlaces[i], res.default_protocol);
          }
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

  setSessionGenoProtocol: function (sessionData) {
    sessionStorage.setItem("selection_pop_genotyping_protocol_id", sessionData.protocol_id);
    sessionStorage.setItem("selection_pop_genotyping_protocol_name", sessionData.protocol_name);
    sessionStorage.setItem("selection_pop_genotyping_protocol_div", sessionData.divPlace);
  },

  getSessionGenoProtocol: function () {
    var selPopProtocolId = sessionStorage.getItem("selection_pop_genotyping_protocol_id");
    var selPopProtocolName = sessionStorage.getItem("selection_pop_genotyping_protocol_name");
    var divPlace = sessionStorage.getItem("selection_pop_genotyping_protocol_div");

    console.log(
      "session storage protocol id " +
        selPopProtocolId +
        " name " +
        selPopProtocolName +
        " div " +
        divPlace
    );
    if (selPopProtocolId) {
      var sessionData = {
        protocol_id: selPopProtocolId,
        protocol_name: selPopProtocolName,
        divPlace: divPlace,
      };

      return sessionData;
    } else {
      return null;
    }
  },

  formatDivId: function (divPlace) {
    if (divPlace && !divPlace.match(/#/)) {
      divPlace = "#" + divPlace;
    } else {
      divPlace = "";
    }

    return divPlace;
  },

  getPredictionGenotypingProtocols: function () {
    var protocolId = jQuery("#genotyping_protocol_id").val();
    var selPopProtocolId = jQuery("#selection_pop_genotyping_protocol_id").val();

    if (!selPopProtocolId) {
      selPopProtocolId = protocolId;
    }

    return {
      genotyping_protocol_id: protocolId,
      selection_pop_genotyping_protocol_id: selPopProtocolId,
    };
  },
};

jQuery(document).ready(function () {
  solGS.genotypingProtocol.getAllProtocols();
});

jQuery(document).ready(function () {
  jQuery("#genotyping_protocol #genotyping_protocols_change").click(function () {
    var divPlace = jQuery(this).parent().parent().parent().attr("id");
    divPlace = solGS.genotypingProtocol.formatDivId(divPlace);

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

    var divPlace = jQuery(this).parent().parent().parent().attr("id");
    divPlace = solGS.genotypingProtocol.formatDivId(divPlace);

    var selectedGenoProtocol = {
      protocol_id: selectedId,
      protocol_name: selectedName,
      divPlace: divPlace,
    };

    if (document.URL.match(/solgs/)) {
      solGS.genotypingProtocol.setSessionGenoProtocol(selectedGenoProtocol);
      location.reload();
    } else {
      solGS.genotypingProtocol.setGenotypingProtocol(divPlace, selectedGenoProtocol);

      jQuery(divPlace + " #genotyping_protocol #genotyping_protocols_list_div").hide();
      jQuery(
        divPlace + " #genotyping_protocol #genotyping_protocols_list_select option:selected"
      ).prop("selected", false);
      jQuery(divPlace + " #genotyping_protocol #genotyping_protocols_change").show();
    }
  });
});
