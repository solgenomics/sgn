
jQuery(document).ready(function (){

    var lo = new CXGN.List();

    $('#selected_marker_set').html(lo.listSelect('selected_marker_set', ['markers']));

    $("#save_marker_set").click(function(){
        var markerSetName = $('#new_marker_set').val();
        if (!markerSetName) {
            alert("Marker set name is required");
            return;
        }

        var list_id = lo.newList(markerSetName);
        lo.setListType(list_id, 'markers')
        alert("Added new marker set");
        return list_id
    });
});
