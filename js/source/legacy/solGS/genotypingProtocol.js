/**
 * Sets genotyping protocol for solGS and related analysis
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */
 JSAN.use("jquery.blockUI");

var solGS = solGS || function solGS() {};

solGS.genotypingProtocol = {
  setGenotypingProtocol: function (divPlace, arg) {
    var protocolName;

    if (arg.genotyping_protocol_name != 'undefined') {
      protocolName = arg.genotyping_protocol_name;
    } else if (arg.selection_pop_genotyping_protocol_name) {
      protocolName = arg.selection_pop_genotyping_protocol_name;
    }

    console.log(`arg.genotyping_protocol_name: ${arg.genotyping_protocol_name}`)
    console.log(`arg.sel_pop_genotyping_protocol_name: ${arg.selection_pop_genotyping_protocol_name}`)
    var msg = "You are using genotyping protocol: <b>" + protocolName + "</b>.";
    divPlace = this.formatDivId(divPlace);
    jQuery(divPlace + " #genotyping_protocol #genotyping_protocol_message").val(arg.selection_pop_genotyping_protocol_id);
    jQuery(divPlace + " #genotyping_protocol #genotyping_protocol_message").html(msg);

    var trainingPages = "solgs/trait/" +
    "|solgs/model/combined/trials/" +
    "|solgs/models/combined/trials/" +
    "|solgs/traits/all/population/";

    var docUrl = document.URL;
      if (document.URL.match(trainingPages)) {
        jQuery(divPlace + " #genotyping_protocol #selection_pop_genotyping_protocol_id").val(
          arg.selection_pop_genotyping_protocol_id
        );
      } else {
        jQuery(divPlace + " #genotyping_protocol #genotyping_protocol_id").val(arg.genotyping_protocol_id);
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
        }


        for (i = 0; i < divPlaces.length; i++) {
          if (sessionGenoProtocol) {
            solGS.genotypingProtocol.setGenotypingProtocol(divPlaces[i], sessionGenoProtocol);
          } else {

            var sessionData = {
              genotyping_protocol_id: res.default_protocol.protocol_id,
              genotyping_protocol_name: res.default_protocol.name,
              divPlace: divPlaces[i]
            };

            solGS.genotypingProtocol.setGenotypingProtocol(divPlaces[i], sessionData);
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

    sessionStorage.setItem("genotyping_protocol_id", sessionData.genotyping_protocol_id);
    sessionStorage.setItem("genotyping_protocol_name", sessionData.genotyping_protocol_name);

    if (sessionData.selection_pop_genotyping_protocol_id) {
    sessionStorage.setItem("selection_pop_genotyping_protocol_id", sessionData.selection_pop_genotyping_protocol_id);
    sessionStorage.setItem("selection_pop_genotyping_protocol_name", sessionData.selection_pop_genotyping_protocol_name);
    sessionStorage.setItem("selection_pop_genotyping_protocol_div", sessionData.divPlace);
    }
  },

  getSessionGenoProtocol: function () {
    var protocolId = sessionStorage.getItem("genotyping_protocol_id");
    var protocolName = sessionStorage.getItem("genotyping_protocol_name");
    var selPopProtocolId = sessionStorage.getItem("selection_pop_genotyping_protocol_id");
    var selPopProtocolName = sessionStorage.getItem("selection_pop_genotyping_protocol_name");
    var divPlace = sessionStorage.getItem("selection_pop_genotyping_protocol_div");
	
    var sessionData;
    if (selPopProtocolId) {
      sessionData = {
        genotyping_protocol_id: protocolId,
        genotyping_protocol_name: protocolName,
        selection_pop_genotyping_protocol_id: selPopProtocolId,
        selection_pop_genotyping_protocol_name: selPopProtocolName,
        divPlace: divPlace,
      };


    } else if (protocolId) {
      sessionData = {
        genotyping_protocol_id: protocolId,
        genotyping_protocol_name: protocolName,
        divPlace: divPlace,
      };

    }

    return sessionData;
  },

  formatDivId: function (divPlace) {
    if (divPlace && !divPlace.match(/#/)) {
      divPlace = "#" + divPlace;
    } else {
      divPlace = "";
    }

    return divPlace;
  },

  getGenotypingProtocolId: function (divPlace) {

    var protocolId;
    if (divPlace) {
     divPlace = solGS.genotypingProtocol.formatId(divPlace);
		  protocolId = jQuery(divPlace + ' #genotyping_protocol #genotyping_protocol_id').val();
    }
	
    if (!protocolId) {
     protocolId = jQuery('#genotyping_protocol_id').val() || sessionStorage.getItem("genotyping_protocol_id");
    }

		return protocolId;
	},

  getGenotypingProtocolName: function () {
    return  jQuery("#genotyping_protocol_name").val();
  
  },


  getPredictionGenotypingProtocols: function () {
    var protocolId = this.getGenotypingProtocolId();
    var selPopProtocolId = jQuery("#selection_pop_genotyping_protocol_id").val();
    var sessionSelPopProtocolId = sessionStorage.getItem("selection_pop_genotyping_protocol_id");

    if (!selPopProtocolId) {
      selPopProtocolId = sessionSelPopProtocolId;
    }

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
    
    var protocolId;
    var protocolName;
    var selPopProtocolId;
    var selPopProtocolName;


    var trainingPages = "solgs/trait/" +
    "|solgs/model/combined/trials/" +
    "|solgs/models/combined/trials/" +
    "|solgs/traits/all/population/";

      if (document.URL.match(trainingPages)) {
      
        selPopProtocolId = selectedId;
        selPopProtocolName = selectedName;
        protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();
        protocolName = solGS.genotypingProtocol.getGenotypingProtocolName();    
      } else {
        protocolId = selectedId;
        protocolName = selectedName;      
      }


    var divPlace = jQuery(this).parent().parent().parent().attr("id");
    divPlace = solGS.genotypingProtocol.formatDivId(divPlace);

    var selectedGenoProtocol = {
      genotyping_protocol_id: protocolId,
      genotyping_protocol_name: protocolName,
      selection_pop_genotyping_protocol_id: selPopProtocolId,
      selection_pop_genotyping_protocol_name: selPopProtocolName,
      divPlace: divPlace,
    };

    if (document.URL.match(/solgs/)) {
      jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
      jQuery.blockUI({ message: "Please wait...setting genotyping protocol" });
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
