[1mdiff --git a/lib/SGN/Controller/AJAX/TrialMetadata.pm b/lib/SGN/Controller/AJAX/TrialMetadata.pm[m
[1mindex a92119d20..2f1fe9bfb 100644[m
[1m--- a/lib/SGN/Controller/AJAX/TrialMetadata.pm[m
[1m+++ b/lib/SGN/Controller/AJAX/TrialMetadata.pm[m
[36m@@ -1124,35 +1124,16 @@[m [msub trial_plot_gps_upload : Chained('trial') PathPart('upload_plot_gps') Args(0)[m
     $c->stash->{rest} = { success => 1 };[m
 }[m
 [m
[31m-sub trial_change_plot_accessions_upload : Chained('trial') PathPart('change_plot_accessions_using_file') Args(0) {[m
[32m+[m[32msub trial_change_plot_accessions_upload : Chained('trial') PathPart('change_plot_accessions_using_file') Args(1) {[m
     my $self = shift;[m
     my $c = shift;[m
[32m+[m[32m    my $override = shift;[m
     my $trial_id = $c->stash->{trial_id};[m
     my $schema = $c->dbic_schema('Bio::Chado::Schema');[m
[31m-    my $user_id;[m
[31m-    my $user_name;[m
[31m-    my $user_role;[m
[31m-    my $session_id = $c->req->param("sgn_session_id");[m
 [m
[31m-    if ($session_id){[m
[31m-        my $dbh = $c->dbc->dbh;[m
[31m-        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);[m
[31m-        if (!$user_info[0]){[m
[31m-            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};[m
[31m-            $c->detach();[m
[31m-        }[m
[31m-        $user_id = $user_info[0];[m
[31m-        $user_role = $user_info[1];[m
[31m-        my $p = CXGN::People::Person->new($dbh, $user_id);[m
[31m-        $user_name = $p->get_username;[m
[31m-    } else{[m
[31m-        if (!$c->user){[m
[31m-            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};[m
[31m-            $c->detach();[m
[31m-        }[m
[31m-        $user_id = $c->user()->get_object()->get_sp_person_id();[m
[31m-        $user_name = $c->user()->get_object()->get_username();[m
[31m-        $user_role = $c->user->get_object->get_user_type();[m
[32m+[m[32m    if (!$c->user){[m
[32m+[m[32m        $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};[m
[32m+[m[32m        return;[m
     }[m
 [m
     my $schema = $c->dbic_schema("Bio::Chado::Schema");[m
[36m@@ -1171,8 +1152,8 @@[m [msub trial_change_plot_accessions_upload : Chained('trial') PathPart('change_plot[m
         archive_path => $c->config->{archive_path},[m
         archive_filename => $upload_original_name,[m
         timestamp => $timestamp,[m
[31m-        user_id => $user_id,[m
[31m-        user_role => $user_role[m
[32m+[m[32m        user_id => $c->user->get_object->get_sp_person_id(),[m
[32m+[m[32m        user_role => ($c->user->get_roles)[0][m
     });[m
     my $archived_filename_with_path = $uploader->archive();[m
     my $md5 = $uploader->get_md5($archived_filename_with_path);[m
[36m@@ -1212,10 +1193,15 @@[m [msub trial_change_plot_accessions_upload : Chained('trial') PathPart('change_plot[m
     });[m
 [m
     my $return_error = $replace_accession_fieldmap->update_fieldmap_precheck();[m
[31m-     if ($return_error) {[m
[31m-       $c->stash->{rest} = { error => $return_error };[m
[31m-       return;[m
[31m-     }[m
[32m+[m[32m    if ($c->user()->check_roles("curator") and $return_error) {[m
[32m+[m[32m        if ($override eq "check") {[m
[32m+[m[32m            $c->stash->{rest} = { warning => "curator warning" };[m
[32m+[m[32m            return;[m
[32m+[m[32m        }[m
[32m+[m[32m    } elsif ($return_error){[m
[32m+[m[32m        $c->stash->{rest} = { error => $return_error };[m
[32m+[m[32m        return;[m
[32m+[m[32m    }[m
 [m
     my $upload_change_plot_accessions_txn = sub {[m
         my @stock_names;[m
[36m@@ -1757,6 +1743,7 @@[m [msub replace_trial_stock : Chained('trial') PathPart('replace_stock') Args(0) {[m
     old_accession_id => $old_stock_id,[m
     new_accession => $new_stock,[m
     trial_stock_type => $trial_stock_type,[m
[32m+[m
   });[m
 [m
   my $return_error = $replace_stock_fieldmap->update_fieldmap_precheck();[m
[36m@@ -1782,7 +1769,13 @@[m [msub replace_plot_accession : Chained('trial') PathPart('replace_plot_accessions'[m
   my $new_accession = $c->req->param('new_accession');[m
   my $old_plot_id = $c->req->param('old_plot_id');[m
   my $old_plot_name = $c->req->param('old_plot_name');[m
[32m+[m[32m  my $override = $c->req->param('override');[m
   my $trial_id = $c->stash->{trial_id};[m
[32m+[m[41m  [m
[32m+[m[32m  if (!$c->user){[m
[32m+[m[32m        $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};[m
[32m+[m[32m        return;[m
[32m+[m[32m    }[m
 [m
   if ($self->privileges_denied($c)) {[m
     $c->stash->{rest} = { error => "You have insufficient access privileges to edit this map." };[m
[36m@@ -1795,8 +1788,8 @@[m [msub replace_plot_accession : Chained('trial') PathPart('replace_plot_accessions'[m
   }[m
 [m
   my $replace_plot_accession_fieldmap = CXGN::Trial::FieldMap->new({[m
[31m-    bcs_schema => $schema,[m
     trial_id => $trial_id,[m
[32m+[m[32m    bcs_schema => $schema,[m
     new_accession => $new_accession,[m
     old_accession => $old_accession,[m
     old_plot_id => $old_plot_id,[m
[36m@@ -1804,11 +1797,16 @@[m [msub replace_plot_accession : Chained('trial') PathPart('replace_plot_accessions'[m
 [m
   });[m
 [m
[31m-  my $return_error = $replace_plot_accession_fieldmap->update_fieldmap_precheck();[m
[31m-     if ($return_error) {[m
[31m-       $c->stash->{rest} = { error => $return_error };[m
[31m-       return;[m
[31m-     }[m
[32m+[m[32m    my $return_error = $replace_plot_accession_fieldmap->update_fieldmap_precheck();[m
[32m+[m[32m    if ($c->user()->check_roles("curator") and $return_error) {[m
[32m+[m[32m        if ($override eq "check") {[m
[32m+[m[32m            $c->stash->{rest} = { warning => "curator warning" };[m
[32m+[m[32m            return;[m
[32m+[m[32m        }[m
[32m+[m[32m    } elsif ($return_error) {[m
[32m+[m[32m        $c->stash->{rest} = { error => $return_error};[m
[32m+[m[32m        return;[m
[32m+[m[32m    }[m
 [m
   print "Calling Replace Function...............\n";[m
   my $replace_return_error = $replace_plot_accession_fieldmap->replace_plot_accession_fieldMap();[m
[36m@@ -1871,7 +1869,7 @@[m [msub replace_well_accession : Chained('trial') PathPart('replace_well_accessions'[m
 [m
 sub substitute_stock : Chained('trial') PathPart('substitute_stock') Args(0) {[m
   my $self = shift;[m
[31m-	my $c = shift;[m
[32m+[m[32m  my $c = shift;[m
   my $schema = $c->dbic_schema('Bio::Chado::Schema');[m
   my $trial_id = $c->stash->{trial_id};[m
   my $plot_1_info = $c->req->param('plot_1_info');[m
[1mdiff --git a/mason/breeders_toolbox/trial/change_plot_accessions_dialogs.mas b/mason/breeders_toolbox/trial/change_plot_accessions_dialogs.mas[m
[1mindex 37733d70f..9855b64a8 100644[m
[1m--- a/mason/breeders_toolbox/trial/change_plot_accessions_dialogs.mas[m
[1m+++ b/mason/breeders_toolbox/trial/change_plot_accessions_dialogs.mas[m
[36m@@ -58,7 +58,37 @@[m [m$trial_id[m
     </div>[m
 </div>[m
 [m
[31m-<div class="modal  fade" id="trial_design_replace_accessions_dialog_message" name="trial_design_replace_accessions_dialog_message" tabindex="-1" role="dialog" aria-labelledby="HmDialog">[m
[32m+[m[32m<div class="modal fade" id="td_replace_accession_curator_warning_message" name="td_replace_accession_curator_warning_message" tabindex="-1" role="dialog" aria-labelledby="td_curator_warning">[m
[32m+[m[32m    <div class="modal-dialog" role="document">[m
[32m+[m[32m        <div class="modal-content">[m
[32m+[m[32m            <div class="modal-header" style="text-align: center">[m
[32m+[m[32m                <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>[m
[32m+[m[32m                <h4 class="modal-title" id="tDDialog"><b>Warning!</b></h4>[m
[32m+[m[32m            </div>[m
[32m+[m[32m            <div class="modal-body">[m
[32m+[m[32m                <div class="container-fluid">[m[41m  [m
[32m+[m
[32m+[m[32m                    <big>[m
[32m+[m[32m                        <span>&#9888;</span>[m[41m [m
[32m+[m[32m                        <p3>[m
[32m+[m[32m                            One or more traits have been assayed for this trial; <br>[m
[32m+[m[32m                            It is not recommended to change accessions at this point. Are you sure?[m
[32m+[m[32m                        </p3>[m
[32m+[m[32m                    </big>[m
[32m+[m
[32m+[m[32m                </div>[m
[32m+[m[32m            </div>[m
[32m+[m[32m            <div class="modal-footer">[m
[32m+[m[32m                <button id="td_override_accession_warning" type="button" class="btn btn-primary" >Yes</button>[m
[32m+[m[32m                <button id="close_tdfieldmap_dialog" type="button" class="btn btn-default" data-dismiss="modal">No</button>[m
[32m+[m
[32m+[m[32m            </div>[m
[32m+[m[32m        </div>[m
[32m+[m[32m    </div>[m
[32m+[m[32m</div>[m
[32m+[m
[32m+[m
[32m+[m[32m<div class="modal  fade" id="trial_design_replace_accessions_dialog_message" name="trial_design_replace_accessions_dialog_message" tabindex="-1" role="dialog" aria-labelledby="tDDialog">[m
     <div class="modal-dialog " role="document">[m
         <div class="modal-content">[m
             <div class="modal-header" style="text-align: center">[m
[36m@@ -73,7 +103,7 @@[m [m$trial_id[m
                 </div>[m
             </div>[m
             <div class="modal-footer">[m
[31m-                <button id="close_tdfieldma_dialog" type="button" class="btn btn-default" data-dismiss="modal">Close</button>[m
[32m+[m[32m                <button id="close_tdfieldmap_dialog" type="button" class="btn btn-default" data-dismiss="modal">Close</button>[m
 [m
             </div>[m
         </div>[m
[36m@@ -90,7 +120,7 @@[m [mjQuery(document).ready(function () {[m
 [m
     jQuery('#trial_design_change_accessions_submit').click( function() {[m
         var uploadFile = jQuery("#trial_design_change_accessions_file").val();[m
[31m-        jQuery('#trial_design_change_accessions_form').attr("action", "/ajax/breeders/trial/<% $trial_id %>/change_plot_accessions_using_file");[m
[32m+[m[32m        jQuery('#trial_design_change_accessions_form').attr("action", "/ajax/breeders/trial/<% $trial_id %>/change_plot_accessions_using_file/check");[m
         if (uploadFile === '') {[m
             alert("Please select a file");[m
             return;[m
[36m@@ -98,6 +128,11 @@[m [mjQuery(document).ready(function () {[m
         jQuery("#trial_design_change_accessions_form").submit();[m
     });[m
 [m
[32m+[m[32m    jQuery('#td_override_accession_warning').click( function() {[m
[32m+[m[32m        jQuery('#trial_design_change_accessions_form').attr("action", "/ajax/breeders/trial/<% $trial_id %>/change_plot_accessions_using_file/override");[m
[32m+[m[32m        jQuery("#trial_design_change_accessions_form").submit();[m
[32m+[m[32m    });[m
[32m+[m
     jQuery('#trial_design_change_accessions_form').iframePostForm({[m
         json: true,[m
         post: function () {[m
[36m@@ -106,15 +141,21 @@[m [mjQuery(document).ready(function () {[m
         complete: function (response) {[m
             jQuery('#working_modal').modal("hide");[m
             console.log(response);[m
[31m-            if (response.error) {[m
[32m+[m[32m            if (response.warning) {[m
[32m+[m[32m                jQuery('#trial_design_change_accessions_dialog').modal("hide");[m
[32m+[m[32m                jQuery('#td_replace_accession_curator_warning_message').modal("show");[m
[32m+[m[32m            } else if (response.error) {[m
                 alert(response.error);[m
             }[m
             else {[m
[31m-		jQuery('#trial_design_change_accessions_dialog').modal("hide");[m
[32m+[m	[32m            jQuery('#trial_design_change_accessions_dialog').modal("hide");[m
[32m+[m[32m                jQuery('#td_replace_accession_curator_warning_message').modal("hide");[m
                 jQuery('#trial_design_replace_accessions_dialog_message').modal("show");[m
             }[m
         },[m
         error: function(response) {[m
[32m+[m[32m            jQuery('#trial_design_change_accessions_dialog').modal("hide");[m
[32m+[m[32m            jQuery('#td_replace_accession_curator_warning_message').modal("hide");[m
             jQuery('#working_modal').modal("hide");[m
             alert("An error occurred changing plot accessions");[m
         }[m
[1mdiff --git a/mason/breeders_toolbox/trial/phenotype_heatmap.mas b/mason/breeders_toolbox/trial/phenotype_heatmap.mas[m
[1mindex bd91cd530..a0f18d35b 100644[m
[1m--- a/mason/breeders_toolbox/trial/phenotype_heatmap.mas[m
[1m+++ b/mason/breeders_toolbox/trial/phenotype_heatmap.mas[m
[36m@@ -361,6 +361,36 @@[m [m$data_level => 'plot'[m
     </div>[m
 </div>[m
 [m
[32m+[m[32m<div class="modal fade" id="hm_replace_accession_curator_warning_message" name="hm_replace_accession_curator_warning_message" tabindex="-1" role="dialog" aria-labelledby="td_curator_warning">[m
[32m+[m[32m    <div class="modal-dialog" role="document">[m
[32m+[m[32m        <div class="modal-content">[m
[32m+[m[32m            <div class="modal-header" style="text-align: center">[m
[32m+[m[32m                <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>[m
[32m+[m[32m                <h4 class="modal-title" id="tDDialog"><b>Warning!</b></h4>[m
[32m+[m[32m            </div>[m
[32m+[m[32m            <div class="modal-body">[m
[32m+[m[32m                <div class="container-fluid">[m
[32m+[m
[32m+[m[32m                    <big>[m
[32m+[m[32m                        <span>&#9888;</span>[m[41m [m
[32m+[m[32m                        <p3>[m
[32m+[m[32m                            One or more traits have been assayed for this trial; <br>[m
[32m+[m[32m                            It is not recommended to change accessions at this point. Are you sure?[m
[32m+[m[32m                        </p3>[m
[32m+[m[32m                    </big>[m
[32m+[m
[32m+[m
[32m+[m[32m                </div>[m
[32m+[m[32m            </div>[m
[32m+[m[32m            <div class="modal-footer">[m
[32m+[m[32m                <button id="fm_override_accession_warning" type="button" class="btn btn-primary">Yes</button>[m
[32m+[m[32m                <button id="close_tdfieldmap_dialog" type="button" class="btn btn-default" data-dismiss="modal">No</button>[m
[32m+[m
[32m+[m[32m            </div>[m
[32m+[m[32m        </div>[m
[32m+[m[32m    </div>[m
[32m+[m[32m</div>[m
[32m+[m
 <%perl>[m
 my $dbh = $stockref->{dbh};[m
 my $image_ids =  $stockref->{image_ids} || [] ;[m
[36m@@ -1324,14 +1354,18 @@[m [mjQuery(document).ready( function() {[m
 [m
     jQuery("#hm_replace_plot_accession_form").submit( function() {[m
       event.preventDefault();[m
[31m-      hm_replace_plotAccession_fieldMap();[m
[32m+[m[32m      hm_replace_plotAccession_fieldMap('check');[m
     });[m
 [m
     jQuery('#hm_replace_plot_accession_submit').click( function() {[m
[31m-      hm_replace_plotAccession_fieldMap();[m
[32m+[m[32m      hm_replace_plotAccession_fieldMap('check');[m
[32m+[m[32m    });[m
[32m+[m
[32m+[m[32m    jQuery('#fm_override_accession_warning').click( function() {[m
[32m+[m[32m      hm_replace_plotAccession_fieldMap('override');[m
     });[m
 [m
[31m-    function hm_replace_plotAccession_fieldMap() {[m
[32m+[m[32m    function hm_replace_plotAccession_fieldMap(override) {[m
       jQuery('#hm_replace_plot_accessions_dialog').modal("hide");[m
       jQuery('#working_modal').modal("show");[m
 [m
[36m@@ -1349,15 +1383,19 @@[m [mjQuery(document).ready( function() {[m
                 'old_accession': old_accession,[m
                 'old_plot_id': old_plot_id,[m
                 'old_plot_name': old_plot_name,[m
[32m+[m[32m                'override': override,[m
         },[m
 [m
         success: function (response) {[m
           jQuery('#working_modal').modal("hide");[m
[31m-[m
[31m-          if (response.error) {[m
[32m+[m[32m          if (response.warning) {[m
[32m+[m[32m            jQuery('#working_modal').modal("hide");[m
[32m+[m[32m            jQuery('#hm_replace_accession_curator_warning_message').modal("show");[m
[32m+[m[32m          } else if (response.error) {[m
             alert("Error Replacing Plot Accession: "+response.error);[m
           }[m
           else {[m
[32m+[m[32m            jQuery('#hm_replace_accession_curator_warning_message').modal("hide");[m
             jQuery('#hm_replace_accessions_dialog_message').modal("show");[m
           }[m
         },[m
