/*jslint browser: true, devel: true */

/**

=head1 Trial.js

Display for managing genotyping plates


=head1 AUTHOR

Mirella Flores <mrf252@cornell.edu>
Lukas Mueller <lam87@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    var plate_data = new Object();

    function genotyping_facility_login(auth_data) {
        var access_token;
        $.ajax({
            url: auth_data.host+'/brapi/v1/token',
            method: 'POST',
            async: false,
            data: {
                username: auth_data.username,
                password: auth_data.password,
            },
            success: function(response) {
                if (response.metadata.status[0].message) {
                    alert('Login failed. '+JSON.stringify(response.metadata.status[0].message));
                }
                else {
                    alert("Success!"+ JSON.stringify(response)+" which is "+response.result.access_token);
                    access_token = response.result.access_token;
                }
            },
            error: function(response) {
                alert("An error occurred trying to log into the sequencing facility server. Please try again later.");
            }
        });
        return access_token;
    }

    function get_genotyping_facility_credentials() {
        var auth_data;
        jQuery.ajax({
            url: '/ajax/breeders/genotyping_credentials',
            async: false,
            success: function(response) {
                if(response.host && response.host != 'NULL'){
                    auth_data =  {
                        host : response.host,
                        username : response.username,
                        password : response.password,
                        token : response.token
                    };
                } else {
                        return auth_data = { error : "An error occurred", };
                }
            },
            error: function(response) {
                return auth_data = { error : "An error occurred", };
            }
        });
        return auth_data;
    }

    function submit_samples(order_info) {

        var brapi_order = new Object();

        // Submit samples
        jQuery.ajax({
            url: '/ajax/breeders/createplateorder',
            method: 'POST',
            beforeSend: function(){
                jQuery("#working_modal").modal('show');
            },
            data: {
                'order_info': JSON.stringify(order_info)
            },
            success : function(response) {
                jQuery("#working_modal").modal('hide');
                if (response.error) {
                    alert(response.error);
                }
                else {
                    
                    brapi_order = response.order;
                    if (order_info.full_order) {
                        submit_order_to_facility(brapi_order,order_info.facility_id,order_info.plate_id,store_facility_order);
                    }
                    else {
                        submit_plate_to_facility(brapi_order,order_info.facility_id,order_info.plate_id,store_facility_order);
                    }
                }
            },
            error: function(response) {
                alert('An error occurred trying to submit the order.');
                jQuery("#working_modal").modal('hide');
            }
        });
    }

    function submit_order_to_facility(brapi_plate_data,facility,plate_id,store_order) {

        var auth_data = new Object();
        auth_data = get_genotyping_facility_credentials();
        var order;

        if (auth_data.error) {
            alert("Genotyping server credentials are not available. Stop.");
            return;
        }

        var access_token;
        if (auth_data.token){
            access_token = auth_data.token;
        } else {
            access_token = genotyping_facility_login(auth_data);
        }

        if (access_token) {
            auth_data.token = access_token;

            var facility_url = auth_data.host + '/brapi/v1/vendor/orders';
            // alert("Sending genotyping experiment entry to genotyping facility...");

            $.ajax( {
                url: facility_url,
                method: 'POST',
                headers: {"Authorization": 'Bearer ' + access_token, "Content-type":"application/json"},
                data: JSON.stringify(brapi_plate_data),
                success: function(response) {
                    const orderId = ((response || {}).result || {}).orderId;
                    if ( orderId ) {
                        order = response.result;
                        alert("Successfully!. Plate submitted to facility.");

                        store_order(order,parseInt(plate_id));

                        Workflow.complete('#submit_plate_btn');
                        Workflow.complete('#continue_submission_btn');
                        Workflow.focus("#plates_to_facilities_workflow", -1); //Go to success page
                        Workflow.check_complete("#plates_to_facilities_workflow");
                    }
                    else {
                        alert(response.metadata.status);
                        return;
                    }
                },
                error: function(response) {
                    alert("An error occurred trying to submit your plate to the facility.");
                    return;
                }
            });
        }
    }

    function submit_plate_to_facility(brapi_plate_data,facility,plate_id,store_submission) {

        var auth_data = new Object();
        auth_data = get_genotyping_facility_credentials();
        var submission;

        if (auth_data.error) {
            alert("Genotyping server credentials are not available. Stop.");
            return;
        }

        var access_token;
        if (auth_data.token){
            access_token = auth_data.token;
        } else {
            access_token = genotyping_facility_login(auth_data);
        }

        if (access_token) {
            // alert("Sending genotyping experiment entry to genotyping facility...");
            var url = auth_data.host +  '/brapi/v1/vendor/plates';

            $.ajax( {
                url: url,
                method: 'POST',
                headers: {"Authorization": 'Bearer ' + access_token, "Content-type":"application/json"},
                data: JSON.stringify(brapi_plate_data),
                success: function(response) {
                    const submissionId = ((response || {}).result || {}).submissionId;
                    if (submissionId) {
                        // submission =  response.result;
                        submission = (response || {}).result || {};
                        jQuery('#submission_lbl').html(submissionId);
                        alert("Successfully!. Plate submitted to facility.");
                        store_submission(submission,parseInt(plate_id));
                        Workflow.complete('#submit_plate_btn');
                        document.getElementById("facility_href").href = auth_data.host + "/order.pl"; 
                        
                    }
                    else {
                        alert(response.metadata.status);
                        return;
                    }
                },
                error: function(response) {
                    alert("An error occurred trying to submit your plate to the facility.");
                    return;
                }
            });
        }
    }

    function store_facility_order(gdf_order,plate_id) {

        // Submit samples
        jQuery.ajax({
            url: '/ajax/breeders/storeplateorder',
            method: 'POST',
            data: {
                'order': JSON.stringify(gdf_order),
                'plate_id': JSON.stringify(plate_id)
            },
            success : function(response) {
                if (response.error) {
                    alert(response.error);
                } else {
                    const orderId = response.order_id;
                    alert('Order stored successfully.');
                     $('#order_lbl').text(orderId);
                    // Workflow.focus("#plates_to_facilities_workflow", -1); //Go to success page
                    // Workflow.check_complete("#plates_to_facilities_workflow");
                }
            },
            error: function(response) {
                alert('An error occurred trying to store the order.');
                jQuery("#working_modal").modal('hide');
            }
        });
    }

    function get_facility_services_id(){
        var facility = document.getElementById('genotyping_facility').innerHTML;

        var auth_data = new Object();
        auth_data = get_genotyping_facility_credentials();

        if (auth_data.error) {
            alert("Genotyping server credentials are not available. Stop.");
            jQuery("#review_order_link").prop("disabled", true);
            return;
        }

        var access_token;
        if (auth_data.token){
            access_token = auth_data.token;
        } else {
            access_token = genotyping_facility_login(auth_data);
        }
        jQuery('#facility_url_lbl').html(auth_data.host);

        if (access_token){
            var url = auth_data.host + '/brapi/v1/vendor/specifications';

            auth_data.token = access_token;

            $.ajax({
                url: url,
                method: 'GET',
                headers: {"Authorization": 'Bearer ' + access_token },
                success: function(response) {
                    var options = response.result.services;
                    jQuery('#service_id_select').empty();
                
                    jQuery.each(options, function(i, p) {
                        jQuery('#organism_name').append(jQuery('<option></option>').val(p.organismName).html(p.organismName));
                        jQuery('#service_id_select').append(jQuery('<option></option>').val(p.serviceId).html(p.serviceName));

                        var requeriments = p.specificRequirements;
                        if (requeriments.length  > 0) {
                            requeriments.forEach(function(o) {
                                let type = document.createElement('label'); 
                                type.setAttribute("class","col-sm-3 control-label");
                                type.appendChild(document.createTextNode(o.key)); 
                                document.getElementById("required_services").appendChild(type);

                                let input = document.createElement("input");
                                input.type = "text";
                                input.name = o.key;
                                input.setAttribute("id", "req-" + o.key);
                                input.setAttribute("class", "form-control");

                                let div_input = document.createElement('div');
                                div_input.setAttribute("class", "col-sm-9");
                                div_input.appendChild(input);

                                let div = document.createElement('div');
                                div.setAttribute("class", "col-sm-12");
                                div.appendChild(type);
                                div.appendChild(div_input);
                                document.getElementById("required_services").appendChild(div);
                            });
                        }
                    });
                },
                error: function(response) {
                    // alert('An error occurred getting services for GDF.');
                    jQuery("#review_order_link").prop("disabled", true);
                }
            });
        }
    }

    function get_facility_order_status(){
        var order_id = document.getElementById('genotyping_vendor_order_id_tab').innerHTML;
        var submission_id = document.getElementById('genotyping_vendor_submission_id_tab').innerHTML;
        var facility = document.getElementById('genotyping_facility_tab').innerHTML;
        var status;

        if(order_id){
            var auth_data = new Object();
            auth_data = get_genotyping_facility_credentials();

            if (auth_data.error) {
                alert("Genotyping server credentials are not available. Stop.");
                return;
            }

            var access_token;
            if (auth_data.token){
                access_token = auth_data.token;
            } else {
                access_token = genotyping_facility_login(auth_data);
            }

            if (access_token){
                var url = auth_data.host + '/brapi/v1/vendor/orders/' + order_id + '/status';

                jQuery.ajax({
                    url: url,
                    type: 'GET',
                    headers: { 
                        "Authorization" : "Bearer " + access_token
                     },
                    success: function(response) {
                        status = response.result.status;       
                        jQuery('#genotyping_trial_status_info').html(status);
                        if ( status == 'completed'){
                            get_facility_vcf(order_id,auth_data.host,access_token);
                        }
                    },
                    error: function(response) {
                        alert("An error occurred trying to get the order status.");
                    }
                });


            }
        } else {
            if(submission_id){
                var url = auth_data.host + '/brapi/v1/vendor/orders?submissionId=' + submission_id;

                jQuery.ajax({
                    url: url,
                    type: 'GET',
                    headers: {"Authorization": 'Bearer ' + access_token },
                    success: function(response) {
                        var gdf_order = (((response || {}).result || {}).data || {})[0];
                        const orderId = (gdf_order|| {}).orderId;
                        if(orderId){
                            store_facility_order(gdf_order,parseInt(plate_id));
                        }
                        else{
                            alert("Something went wrong! Could not get order from submission.");
                        }
                    },
                    error: function(response) {
                        alert('Something went wrong!. Complete your order clicking the link.');
                    }
                });
            }
        }
        return status;
    }

    function get_facility_vcf(order_id,facility_url,access_token){

            if (facility_url){
                var url = facility_url + '/brapi/v1/vendor/orders/' + order_id + '/results';
                jQuery.ajax({
                    url: url,
                    type: 'GET',
                    headers: {"Authorization": 'Bearer ' + access_token },
                    success: function(response) {
                        var data = response.result.data;
                        var links = "";
                        data.forEach(function (item) { 
                            links += "<b>File Name:</b> " + item.fileName + "<br>" + 
                                    "<b>File url:</b> " + item.fileURL + "<br>" +
                                    "<b>md5sum:</b> " + item.md5sum + "<br><br>";
                        });
                        jQuery('#raw_data_tab').html(links);
                    },
                    error: function(response) {

                    }
                });
            }
    }

    jQuery('#continue_submission_btn').click(function () {

        var submission_id = document.getElementById('submission_lbl').innerHTML;
        var plate_id = document.getElementById('plate_id').innerHTML;
        var facility = jQuery('#genotyping_facility').html();

        // var auth_data = new Object();
        // auth_data = get_genotyping_facility_credentials();

        // if (auth_data.error) {
        //     alert("Genotyping server credentials are not available. Stop.");
        //     return;
        // }

        // var access_token;
        // if (auth_data.token){
        //     access_token = auth_data.token;
        // } else {
        //     access_token = genotyping_facility_login(auth_data);
        // }

        // if (access_token) {
        //     auth_data.token = access_token;
        // }

        if(submission_id){
            Workflow.focus("#plates_to_facilities_workflow", -1); //Go to success page
            Workflow.check_complete("#plates_to_facilities_workflow");

        //     var submission =  { "submissionId" :  submission_id }; 
        //     store_facility_order(submission,parseInt(plate_id));

            // var url = auth_data.host + '/brapi/v1/vendor/orders?submissionId=' + submission_id;

            // jQuery.ajax({
            //     url: url,
            //     type: 'GET',
            //     headers: {"Authorization": 'Bearer ' + access_token },
            //     success: function(response) {
            //         var gdf_order = (((response || {}).result || {}).data || {})[0];
            //         const orderId = (gdf_order|| {}).orderId;
            //         if(orderId){
            //             store_facility_order(gdf_order,parseInt(plate_id));
            //         }
            //         else{
            //             alert("Something went wrong! Could not get order from submission.");
            //         }
            //     },
            //     error: function(response) {
            //         alert('Something went wrong!. Complete your order clicking the link.');
            //     }
            // });
        }

    });

    jQuery('#submit_plate_btn').click(function () {
        var order_info = new Object();

        order_info.plate_id = jQuery('#plate_id').html();
        order_info.client_id = jQuery('#client_id').val();
        order_info.service_ids = jQuery('#service_id_select').val();
        order_info.facility_id = jQuery('#genotyping_facility').html();
        order_info.organism_name = jQuery('#organism_name').val();
        order_info.full_order = order_info.facility_id == 'DArT' ? false : true;
        
        if (order_info.plate_id == '' || order_info.client_id == '') {
            alert("A plate id, client facility id and service are required. Please try again.");
            return;
        }

        var requeriments = {};

        $("input[id^=req-").each(function(){
            let idd = $(this).attr('id');
            requeriments[idd.replace("req-", "")] = $(this).val();
        });

        order_info.requeriments = requeriments;

        submit_samples(order_info);

    });

    jQuery('#facility_info_link').click(function () {
        get_facility_services_id(); 
    });

    jQuery('#genotyping_trial_facility_submit_select').on('change', function() {
         
        jQuery("#submit_plate_btn").prop("disabled", this.value == 1);
    });
    jQuery('#organism_name').on('change', function() {
        var select = document.getElementById("service_id_select");
        for (var i = 0; i < select.length; i++) {
            var txt = select.options[i].text;
            var include = txt.includes(this.value);
            select.options[i].style.display = include ? 'list-item':'none';
        }
    });

    jQuery('#genotyping_facilities_section_onswitch').click( function() {
        var order_id = document.getElementById('genotyping_vendor_order_id_tab').innerHTML;
        var submission_id = document.getElementById('genotyping_vendor_submission_id_tab').innerHTML;
        if(order_id || submission_id){
            jQuery('#genotyping_facility_submitted_tab').html("yes");
            jQuery('#submit_plate_link').attr("disabled", true);
            get_facility_order_status();
        } else {
            jQuery('#genotyping_facility_submitted_tab').html("no");
            jQuery('#submit_plate_link').attr("disabled", false);
        }
        
    });

});

