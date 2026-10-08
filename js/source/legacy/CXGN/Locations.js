/**
 *  Common JS functions used by the table and map in the Manage Locations page
 */

var table;
var mymap;

var lo = new CXGN.List();
jQuery('#locations_list').html(lo.listSelect('locations_list', [ 'locations' ], 'select', undefined, undefined));
jQuery('#locations_list').on('change', 'select', updateLocationsTable);

jQuery('#add_location_link').click( function() {
    jQuery('#add_location_dialog').modal("show");
});


function updateLocations(callback) {
    jQuery.ajax({
        url: '/ajax/location/all',
        success: function(response) {
            var locations = response?.data || [];
            locations = locations.filter(function(loc) {
                return loc.properties.Name !== '[Computation]';
            });
            if ( callback ) callback(locations);
        },
        error: function(response) {
            alert("An error occurred");
        }
    });
}

function refreshLocationTableAndMap() {
    if ( jQuery("#location_table").length ) {
        updateLocationsTable();
    }
    if ( jQuery("#location_map").length ) {
        initialize_map();
    }
}




function initialize_table() {
    createLocationsTable();
    updateLocationsTable();
}

function createLocationsTable() {
    var export_message = 'Location data from ' + window.location.href;
    table = jQuery('#location_table').DataTable({
        data: [],
        dom: 'Bfrtip',
        rowId: 'properties.Id',
        "columns": [
            { "data": "properties.Id" },
            { "data": "properties.Name" },
            { "data": "properties.Abbreviation" },
            { "data": "properties.Code",
                "render":function(data, type, full, meta){
                    return full.properties.Code + ' ' + full.properties.Country;
                }
            },
            { "data": "properties.Program" },
            { "data": "properties.Type" },
            { "data": "properties.Latitude" },
            { "data": "properties.Longitude" },
            { "data": "properties.Altitude" },
            { "data": "properties.Trials" },
            { "data": "properties.NOAAStationID",
                "render":function(data, type, full, meta) {
                    return full.properties.NOAAStationID ? "<a href='https://www.ncdc.noaa.gov/cdo-web/datasets/GHCND/stations/" + full.properties.NOAAStationID + "/detail' target=_blank>"+ full.properties.NOAAStationID + "</a>" : "";
                }
            },
            {
                "data": "properties.Id",
                "render": function(data, type, full, meta) {
                    return `[<a href="javascript:;" onclick="edit_location(${full.properties.Id})">Edit</a>] [<a href="javascript:;" onclick="delete_location(${full.properties.Id})">Delete</a>]`;
                }
            }
        ],
        buttons: [ 'colvis',
            {
                extend: 'copy',
                exportOptions: {
                    columns: ':visible'
                }
            },
            {
                extend: 'excelHtml5',
                title: document.title +'_locations',
                exportOptions: {
                    columns: ':visible'
                }
            },
            {
                extend: 'csvHtml5',
                title: document.title +'_locations',
                exportOptions: {
                    columns: ':visible'
                }
            },
            {
                extend: 'pdfHtml5',
                title: document.title +'_locations',
                exportOptions: {
                    columns: ':visible'
                },
                message: export_message
            },
            {
                extend: 'print',
                exportOptions: {
                    columns: ':visible'
                },
                message: export_message
            }
        ],
        drawCallback: function( settings ) {
            var api = this.api();
            var name_data = api.column(1, { search:'applied' } ).data();
            var names = [];
            for (var i = 0; i < name_data.length; i++) { //extract names from data object
                names.push(name_data[i]+'\n');
            }
            $('#location_names').html(names);
            addToListMenu('locations_to_list_menu', 'location_names', {
                listType: 'locations'
            });
        }
    });
}

function updateLocationsTable() {
    updateLocations((locations) => {

        // Filter locations by list items, if a list is selected
        var filtered_locations = locations;
        var list_id = jQuery("#locations_list_list_select option:selected").val();
        if ( list_id ) {
            var data = lo.getListData(list_id);
            var names = data.elements.map((x) => x[1]);
            filtered_locations = filtered_locations.filter((loc) => names.includes(loc.properties.Name));
        }

        // Update table with filtered locations
        table.clear();
        table.rows.add(filtered_locations);
        table.draw();

    });
}




function initialize_map(id = "location_map") {
    updateLocations((locationJSON) => {
        if ( mymap ) {
            mymap.off();
            mymap.remove();
        }

        var satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
            attribution: 'Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community'
        });

        var topomap = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}', {
            attribution: 'Tiles &copy; Esri &mdash; Esri, DeLorme, NAVTEQ, TomTom, Intermap, iPC, USGS, FAO, NPS, NRCAN, GeoBase, Kadaster NL, Ordnance Survey, Esri Japan, METI, Esri China (Hong Kong), and the GIS User Community'
        });

        var streetmap = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}', {
            attribution: 'Tiles &copy; Esri &mdash; Source: Esri, DeLorme, NAVTEQ, USGS, Intermap, iPC, NRCAN, Esri Japan, METI, Esri China (Hong Kong), Esri (Thailand), TomTom, 2012'
        });

        var baseMaps = {
            "Street (Default)": streetmap,
            "Topographical": topomap,
            "Satellite": satellite
        };

        var location_layer = L.geoJSON(locationJSON, {
            pointToLayer: function (feature, latlng) {
            return L.marker(latlng, style(feature));
        },
        onEachFeature: onEachFeature
        });

        var overlayMaps = {
            "Locations": location_layer
        };

        mymap = L.map( id, {
            layers: [streetmap, location_layer]
        });

        var locateUser = L.Control.extend({
            onAdd: function (map) {
                var container = L.DomUtil.create('button', 'leaflet-bar leaflet-control leaflet-control-custom glyphicon glyphicon-map-marker');

                container.style.backgroundColor = 'white';
                container.style.cursor = "pointer";
                container.title = 'Zoom to my location';
                container.style.width = '30px';
                container.style.height = '30px';

                container.onclick = function(){
                map.locate({setView: true});
                }
                return container;
            }
        });

        mymap.addControl(new locateUser({ position: 'topleft' }));

        // Set Map Bounds if provided, otherwise fit the map to the world
        if ( Object.entries(location_layer.getBounds()).length !== 0 ) {
            mymap.fitBounds(location_layer.getBounds());
        }
        else {
            mymap.fitWorld();
        }
        var layerControl = L.control.layers(baseMaps, overlayMaps, {position: 'bottomright'}).addTo(mymap);
        var scale = L.control.scale().addTo(mymap);

        var popup = L.popup();

        function onMapClick(e) {
            popup
                .setLatLng(e.latlng)
                .setContent(
                    'Add a new location here?<br><center><a href="javascript:;" onclick="add_from_map(\''+e.latlng.lat+','+e.latlng.lng+'\')">Add Location</a></center>'
                )
                .openOn(mymap);
        }

        mymap.on('click', onMapClick);

        var arcgisOnline = L.esri.Geocoding.arcgisOnlineProvider();

        var searchControl = L.esri.Geocoding.geosearch({
            providers: [
                arcgisOnline,
                L.esri.Geocoding.featureLayerProvider({
                    url: 'https://services.arcgis.com/uCXeTVveQzP4IIcx/arcgis/rest/services/gisday/FeatureServer/0/',
                    searchFields: ['Name', 'Organization'],
                    label: 'GIS Day Events',
                    bufferRadius: 5000,
                    formatSuggestion: function(feature){
                        return feature.properties.Name + ' - ' + feature.properties.Organization;
                    }
                })
            ],
            position: 'topright',
            expanded: true
        }).addTo(mymap);

        if ( jQuery("#location_table").length ) {
            var table = jQuery('#location_table').DataTable();
            table.on('draw.dt', function () {  // recreate location layer based on filtered table contents
                location_layer.clearLayers();
                var ids = {};
                table.column(0,  { search:'applied' } ).data().each(function(value, index) {
                    ids[value] = true;
                });
                layerControl.removeLayer(location_layer);
                location_layer = L.geoJson(locationJSON, {
                    filter: function(feature, layer) {
                        return ids[feature.properties.Id];
                    },
                    pointToLayer: function (feature, latlng) {
                    return L.marker(latlng, style(feature));
                },
                onEachFeature: onEachFeature
                });

                layerControl.addOverlay(location_layer, "Locations");
                location_layer.addTo(mymap);
                mymap.fitBounds(location_layer.getBounds());
            });
        }

    });
}

function style(feature) {
    //console.log("Type of marker "+feature.properties.Name+" is "+feature.properties.Type);

    var label = feature.properties.Abbreviation || feature.properties.Id;

    var townMarker = L.ExtraMarkers.icon({
        icon: 'fa-number',
        innerHTML: '<div style="color: white; position: relative; top: 50%; transform: translateY(-50%); font-size: 80%">'+label+'</div>',
        markerColor: 'purple',
        shape: 'circle',
        prefix: ''
    });

    var farmMarker = L.ExtraMarkers.icon({
        icon: 'fa-number',
        // number: feature.properties.Id,
        innerHTML: '<div style="color: white; position: relative; top: 50%; transform: translateY(-50%); font-size: 80%">'+label+'</div>',
        markerColor: 'red',
        shape: 'circle',
        prefix: ''
    });

    var fieldMarker = L.ExtraMarkers.icon({
        icon: 'fa-number',
        // number: feature.properties.Id,
        innerHTML: '<div style="color: white; position: relative; top: 50%; transform: translateY(-50%); font-size: 80%">'+label+'</div>',
        markerColor: 'orange',
        shape: 'circle',
        prefix: ''
    });

    var defaultMarker = L.ExtraMarkers.icon({
        icon: 'fa-number',
        // number: feature.properties.Id,
        innerHTML: '<div style="color: white; position: relative; top: 50%; transform: translateY(-50%); font-size: 80%">'+label+'</div>',
        markerColor: 'cyan',
        shape: 'circle',
        prefix: ''
    });

    var greenhouseMarker = L.ExtraMarkers.icon({
        icon: 'fa-number',
        // number: feature.properties.Id,
        innerHTML: '<div style="color: white; position: relative; top: 50%; transform: translateY(-50%); font-size: 80%">'+label+'</div>',
        markerColor: 'green-light',
        shape: 'penta',
        prefix: ''
    });

    var screenhouseMarker = L.ExtraMarkers.icon({
        icon: 'fa-number',
        // number: feature.properties.Id,
        innerHTML: '<div style="color: white; position: relative; top: 50%; transform: translateY(-50%); font-size: 80%">'+label+'</div>',
        markerColor: 'white',
        shape: 'penta',
        prefix: ''
    });

    var labMarker = L.ExtraMarkers.icon({
        icon: 'fa-number',
        // number: feature.properties.Id,
        innerHTML: '<div style="color: white; position: relative; top: 50%; transform: translateY(-50%); font-size: 80%">'+label+'</div>',
        markerColor: 'blue',
        shape: 'square',
        prefix: ''
    });

    var storageMarker = L.ExtraMarkers.icon({
        icon: 'fa-number',
        // number: feature.properties.Id,
        innerHTML: '<div style="color: white; position: relative; top: 50%; transform: translateY(-50%); font-size: 80%">'+label+'</div>',
        markerColor: 'purple',
        shape: 'square',
        prefix: ''
    });

    var otherMarker = L.ExtraMarkers.icon({
        icon: 'fa-number',
        // number: feature.properties.Id,
        innerHTML: '<div style="color: white; position: relative; top: 50%; transform: translateY(-50%); font-size: 80%">'+label+'</div>',
        markerColor: 'pink',
        shape: 'circle',
        prefix: ''
    });

    switch (feature.properties.Type) {
        case 'Town':   return { icon: townMarker };
        case 'Farm':   return { icon: farmMarker };
        case 'Field': return { icon: fieldMarker };
        case 'Greenhouse':   return { icon: greenhouseMarker };
        case 'Screenhouse':   return { icon: screenhouseMarker };
        case 'Lab':   return { icon: labMarker };
        case 'Storage':   return { icon: storageMarker };
        case 'Other':   return { icon: otherMarker };
        default:    return { icon: defaultMarker };
    }
}

function onEachFeature(feature, layer) {
    // var keys = ["Id","Name","Abbreviation","Country","Program","Type","Latitude","Longitude","Altitude","Trials"];
    var keys = ["Abbreviation","Program","Type","Trials"];
    var popupContent = '<table class="table table-sm"><caption style="text-align: center;"><font id="'+feature.properties.Id+'_name" size="3" color="black">'+feature.properties.Name+'</font></caption><tbody>';
    for (var i = 0; i < keys.length; i++) {
        popupContent += '<tr><th>'+keys[i]+'</th><td>'+feature.properties[keys[i]]+'</td></tr>';
    }
    var options = '[<a href="javascript:;" onclick="edit_location('+feature.properties.Id+')">Edit</a>]&nbsp[<a href="javascript:;" onclick="delete_location('+feature.properties.Id+')">Delete</a>]';
    popupContent += '<tr><th>Options</th><td>'+options+'</td></tr></tbody></table>';
    layer.bindPopup(popupContent);
    layer.on('mouseover', function (e) {
        this.openPopup();
    });
}

function add_from_map(coordinate_string) {
    //console.log("coordinate_string is"+coordinate_string);
    var latlng = coordinate_string.split(',');
    latitude = latlng[0], longitude = latlng[1];
    var coordinates = [parseFloat(latitude),parseFloat(longitude)];


    // removed because of mixed content restrictions. Can be uncommented once datascience toolkit can be accessed locally or over https

    // var dstk = $.DSTK();
    // dstk.coordinates2statistics(coordinates, function(c2s_result) {
    //
    //   dstk.coordinates2politics(coordinates, function(c2p_result) {
        //console.log("elevation result is "+JSON.stringify(c2s_result));
        //console.log("politics result is "+JSON.stringify(c2p_result));
        //console.log("elevation result is "+c2s_result[0].statistics.elevation+" and politics result is "+c2p_result[0].politics);
        // if (!c2s_result[0].statistics.elevation || !c2p_result[0].politics) {
        //     alert("Unable to add a location at these coordinates. Please make sure your new location is located on land between 60 north and south.");
        //     return;
        // }
        // var elevation = c2s_result[0].statistics.elevation.value;
        // var code= c2p_result[0].politics[0].code.toUpperCase();
        //console.log("elevation is "+elevation+" and code is "+code);


        $('#location_id').val('');
        $('#location_name').val('');
        $('#location_abbreviation').val('');
        $('#breeding_program_select').val('');
        $('#location_type').val('');
        // $('#location_country').val(code);
        // $('#location_altitude').val(elevation);
        $('#location_country').val('');
        $('#location_altitude').val('');
        $('#location_latitude').val(coordinates[0]);
        $('#location_longitude').val(coordinates[1]);
        $('#store_location_dialog').modal("show");
    //   });
    // });

}





function edit_location(id) {
    updateLocations((locations) => {
        var matches = locations.filter((e) => e.properties.Id === id);
        if ( matches.length !== 1) return alert("Could not find matching location");
        var loc_data = matches[0];

        //console.log("Data for location to edit: "+JSON.stringify(loc_data));
        //console.log("Program for location to edit is "+loc_data.properties.Program);
        $('#location_id').val(loc_data.properties.Id);
        $('#location_name').val(loc_data.properties.Name);
        $('#location_abbreviation').val(loc_data.properties.Abbreviation);
        $('#location_country').val(loc_data.properties.Code);

        $('#breeding_program_select option:selected').prop('selected', false);

        var programs = loc_data.properties.Program;
        var program_array = [];
        if (programs) { program_array = programs.split(" & ") };

        if (program_array.length > 0) {
            $("#breeding_program_select option").each(function() {
                $(this).prop('selected', program_array.includes(this.text));
            });
        } else {
            $('#breeding_program_select option:first').text('');
            $('#breeding_program_select option:first').prop('selected', true);
        }
        setTimeout(() => scrollToSelected("breeding_program_select"), 250);

        $('#location_type').val(loc_data.properties.Type);
        $('#location_latitude').val(loc_data.properties.Latitude);
        $('#location_longitude').val(loc_data.properties.Longitude);
        $('#location_altitude').val(loc_data.properties.Altitude);
        $('#location_noaa_station_id').val(loc_data.properties.NOAAStationID);
        $('#store_location_dialog').modal("show");
    });
}

function delete_location(id) {
    updateLocations((locations) => {
        var matches = locations.filter((e) => e.properties.Id === id);
        if ( matches.length !== 1) return alert("Could not find matching location");
        var loc_data = matches[0];

        var name = loc_data.properties.Name;
        var yes = confirm('Are you sure you want to delete location '+name+'? ');

        if (! yes) { return; }

        new jQuery.ajax( {
            type: 'POST',
            url: '/ajax/location/delete/'+id,
            success: function(response) {
                if (response.error) { alert(response.error); }
                else {
                    alert(response.success);
                    refreshLocationTableAndMap();
                }
            },
            error: function(response) {
                alert("An error occurred");
            }
        });
    });
}

function scrollToSelected(select_id) {
    var select = document.getElementById(select_id);
    var opts = select.getElementsByTagName('option');
    for ( var j = 0; j < opts.length; j++ ) {
        if ( opts.item(j).selected === true ) {
            select.scrollTop = j * opts.item(j).offsetHeight;
            return;
        }
    }
}