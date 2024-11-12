/**
 * Sets genotyping protocol for solGS and related analysis
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.genotypingProtocol = {
  setGenotypingProtocol: function (divPlace, protocol) {
    var msg = "You are using genotyping protocol: <b>" + protocol.name + "</b>.";

    if (divPlace) {
      divPlace = divPlace + " ";
    }

    jQuery(divPlace + "#genotyping_protocol #genotyping_protocol_message").val(
      protocol.protocol_id
    );
    jQuery(divPlace + "#genotyping_protocol #genotyping_protocol_message").html(
      msg
    );
    jQuery(divPlace + "#genotyping_protocol #genotyping_protocol_id").val(
      protocol.protocol_id
    );

  },

  getAllProtocols: function () {
    var protocolsQuery = jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: "/get/genotyping/protocols/",
    });

    return protocolsQuery;
  },

  createGenoProtocolsOpts: function (allProtocols) {
    var genoProtocols;

    for (var i = 0; i < allProtocols.length; i++) {
      genoProtocols +=
        '<option value="' +
        allProtocols[i].protocol_id +
        '">' +
        allProtocols[i].name +
        "</option>";
    }

    return genoProtocols;
  },

  populateMenu: function (allProtocols) {
    var menu = this.createGenoProtocolsOpts(allProtocols);
    jQuery("#genotyping_protocol #genotyping_protocols_list_select").append(
      menu
    );
  },

  formatId: function (divPlace) {
    divPlace = divPlace ? "#" + divPlace : "";
    return divPlace;
  },

  getGenotypingProtocolId: function (divPlace) {
    divPlace = solGS.genotypingProtocol.formatId(divPlace);
    var protocolId = jQuery(
      divPlace + " #genotyping_protocol #genotyping_protocol_id"
    ).val();
    if (!protocolId) {
      protocolId = jQuery("#genotyping_protocol_id").val();
    }

    return protocolId;
  },

  getSelPopGenotypingProtocolId: function () {
    return jQuery("#selection_pop_genotyping_protocol_id").val();
  },

  displayGenotypeMissingMsg: function () {
    // jQuery("#genotyping_protocol").hide();
    jQuery("#genotyping_protocols_message").hide();
    jQuery("#genotype_missing_message").show();
  },
};

jQuery(document).ready(function () {
  jQuery("#genotyping_protocols_message").show();
  jQuery("#genotyping_protocols_progress .multi-spinner-container").show();

  solGS.genotypingProtocol
    .getAllProtocols()
    .done(function (res) {
      var protocolId;
      if (res) {
        var divPlaces = [""];
        if (document.URL.match(/breeders/)) {
          divPlaces = ["#pca_div", "#cluster_div", "#kinship_div"];
        }

        for (i = 0; i < divPlaces.length; i++) {
          solGS.genotypingProtocol.setGenotypingProtocol(
            divPlaces[i],
            res.default_protocol
          );
        }

        solGS.genotypingProtocol.populateMenu(res.all_protocols);
        protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();

        jQuery("#genotyping_protocol").show();
        jQuery("#genotyping_protocols_message").hide();
        jQuery(
          "#genotyping_protocols_progress .multi-spinner-container"
        ).hide();
      } else {
        var message = "<p class='px-4'>No genotyping protocols found.</p>";

        jQuery("#genotyping_protocols_message").html(message).show();
        jQuery(
          "#genotyping_protocols_progress .multi-spinner-container"
        ).hide();
      }

      if (!protocolId) {
        solGS.genotypingProtocol.displayGenotypeMissingMsg();
      }
    })
    .fail(function (res) {
      var message = "<p class='px-4'>No genotyping protocols found.</p>";

      jQuery("#genotyping_protocols_message").html(message).show();
      jQuery("#genotyping_protocols_progress .multi-spinner-container").hide();

      if (document.URL.match(/solgs/)) {
        // solGS.blockSearchInterface();
      }

      solGS.genotypingProtocol.displayGenotypeMissingMsg();
    });
});

jQuery(document).ready(function () {
  jQuery("#genotyping_protocol #genotyping_protocols_change").click(
    function () {
      var divPlace = jQuery(this).parent().parent().parent().attr("id");
      divPlace = solGS.genotypingProtocol.formatId(divPlace);

      jQuery(
        divPlace + " #genotyping_protocol #genotyping_protocols_list_div"
      ).show();
      jQuery(
        divPlace + " #genotyping_protocol #genotyping_protocols_change"
      ).hide();
    }
  );
});

jQuery(document).ready(function () {
  jQuery("<option>", { value: "", selected: true }).prependTo(
    "#genotyping_protocol #genotyping_protocols_list_select"
  );

  jQuery("#genotyping_protocol #genotyping_protocols_list_select").change(
    function () {
      var selectedProtocolId = jQuery(this).find("option:selected").val();
      var selectedProtocolName = jQuery(this).find("option:selected").text();

      var selectedProtocol = {
        protocol_id: selectedProtocolId,
        name: selectedProtocolName,
      };

      var divPlace = jQuery(this).parent().parent().parent().attr("id");

      divPlace = solGS.genotypingProtocol.formatId(divPlace);
      solGS.genotypingProtocol.setGenotypingProtocol(divPlace, selectedProtocol);

      jQuery(
        divPlace + " #genotyping_protocol #genotyping_protocols_list_div"
      ).hide();
      jQuery(
        divPlace +
          " #genotyping_protocol #genotyping_protocols_list_select option:selected"
      ).prop("selected", false);
      jQuery(
        divPlace + " #genotyping_protocol #genotyping_protocols_change"
      ).show();

      if (selectedProtocolId) {
        jQuery("#genotype_missing_message").hide();
      }
    }
  );
});
