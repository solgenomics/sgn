
package SGN::Controller::AJAX::Order;

use Moose;
use CXGN::Stock::Order;
use CXGN::Stock::OrderBatch;
use Data::Dumper;
use JSON;
use DateTime;
use CXGN::People::Person;
use CXGN::Contact;
use CXGN::Trial::Download;
use CXGN::TrackingActivity::AddTrackingIdentifier;
use CXGN::Stock::OrderTrackingIdentifier;
use CXGN::TrackingActivity::AddActivityProject;
use CXGN::Location::LocationLookup;

use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;

use LWP::UserAgent;
use LWP::Simple;
use HTML::Entities;
use URI::Encode qw(uri_encode uri_decode);
use Tie::UrlEncoder; our(%urlencode);


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub submit_order : Path('/ajax/order/submit') : ActionClass('REST'){ }

sub submit_order_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $people_schema = $c->dbic_schema('CXGN::People::Schema', undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $dbh = $c->dbc->dbh();
    my $list_id = $c->req->param('list_id');
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $request_date = $time->ymd();
    my $order_properties = $c->config->{order_properties};
    my @properties = split ',',$order_properties;

    if (!$c->user()) {
        print STDERR "User not logged in... not adding a catalog item.\n";
        $c->stash->{rest} = {error_string => "You must be logged in to add a catalog item." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $user_role = $c->user->get_object->get_user_type();

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $people_schema = $c->dbic_schema('CXGN::People::Schema', undef, $user_id);

    my $list = CXGN::List->new( { dbh=>$dbh, list_id=>$list_id });
    my $items = $list->elements();

    my $catalog_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_catalog_json', 'stock_property')->cvterm_id();
    my %group_by_contact_id;
    my @all_new_rows;
    my @all_items = @$items;
    foreach my $ordered_item (@all_items) {
        my $order_details_ref = decode_json ($ordered_item);
        my %order_details = %{$order_details_ref};
        my $item_name = $order_details{'Item Name'};
        my %each_item_details;
        foreach my $field (@properties) {
            $each_item_details{$field} = $order_details{$field};
        }

        my $item_rs = $schema->resultset("Stock::Stock")->find( { uniquename => $item_name });
        my $item_id = $item_rs->stock_id();
        my $item_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $item_id, type_id => $catalog_cvterm_id});
        my $item_info_string = $item_info_rs->value();
        my $item_info_hash = decode_json $item_info_string;
        my $contact_person_id = $item_info_hash->{'contact_person_id'};
        my $item_type = $item_info_hash->{'item_type'};
        my $item_source = $item_info_hash->{'material_source'};
        my $breeding_program_id = $item_info_hash->{'breeding_program'};
        $group_by_contact_id{$contact_person_id}{'item_list'}{$item_name}{'item_type'} = $item_type;
        $group_by_contact_id{$contact_person_id}{'item_list'}{$item_name}{'material_source'} = $item_source;
        $group_by_contact_id{$contact_person_id}{'item_list'}{$item_name} = \%each_item_details;
        $group_by_contact_id{$contact_person_id}{'breeding_program'} = $breeding_program_id;
    }

    my $tracking_activity = $c->config->{tracking_order_activity};

    my @item_list;
    my @contact_email_list;
    foreach my $contact_id (keys %group_by_contact_id) {
        my @history = ();
        my $history_info = {};
        my $item_ref = $group_by_contact_id{$contact_id}{'item_list'};
        my %item_hashes = %{$item_ref};
        my @names = keys %item_hashes;

        my @item_list = map { { $_ => $item_hashes{$_} } } sort keys %item_hashes;

        my $new_order = CXGN::Stock::Order->new( { bcs_schema => $schema, people_schema => $people_schema, dbh => $dbh});
        $new_order->order_from_id($user_id);
        $new_order->order_to_id($contact_id);
        $new_order->order_status("submitted");
        $new_order->create_date($timestamp);
        my $order_id = $new_order->store();
        if (!$order_id){
            $c->stash->{rest} = {error_string => "Error saving your order",};
            return;
        }

        $history_info ->{'submitted'} = $timestamp;
        push @history, $history_info;

        my $order_prop = CXGN::Stock::OrderBatch->new({ bcs_schema => $schema, people_schema => $people_schema});
        $order_prop->clone_list(\@item_list);
        $order_prop->parent_id($order_id);
        $order_prop->history(\@history);
    	my $order_prop_id = $order_prop->store_people_schema_prop();
#        print STDERR "ORDER PROP ID =".($order_prop_id)."\n";

        if (!$order_prop_id){
            $c->stash->{rest} = {error_string => "Error saving your order",};
            return;
        }

        my @tracking_identifiers = ();
        my @identifier_stock_ids = ();
        my @tracking_ids = ();
        my $activity_project_id;
        if ($tracking_activity) {
            my $n = 0;
            foreach my $name (sort @names) {
                $n++;
                push @tracking_identifiers, ["order".$order_id.":".$name."_"."T".(sprintf "%04d", $n), $name];
            }

            my $activity_project_name = $user_name."_"."order_progress";
            my $activity_project_rs = $schema->resultset('Project::Project')->find({name=>$activity_project_name});
            if ($activity_project_rs) {
                $activity_project_id = $activity_project_rs->project_id();
            } else {
                my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema =>$schema);
                $geolocation_lookup->set_location_name('[Computation]');
                if(!$geolocation_lookup->get_geolocation()){
                    $c->stash->{rest}={error => "Location not found"};
                    return;
                }

                my $breeding_program_id = $group_by_contact_id{$contact_id}{'breeding_program'};

                my $add_activity_project = CXGN::TrackingActivity::AddActivityProject->new({
                    bcs_schema => $schema,
                    dbh => $dbh,
                    breeding_program_id => $breeding_program_id,
                    year => '2024',
                    project_description => 'Tracking order progress',
                    activity_project_name => $activity_project_name,
                    activity_type => 'tissue_culture',
                    nd_geolocation_id => $geolocation_lookup->get_geolocation()->nd_geolocation_id(),
                    owner_id => $contact_id,
                    project_vendor => $contact_id
                });

                my $return = $add_activity_project->save_activity_project();
                if ($return->{error}) {
                    my $error = $return->{error};
                    $c->stash->{rest} = {error_string => $error};
                    return;
                } else {
                    $activity_project_id = $return->{project_id};
                }
            }

            foreach my $identifier_info (@tracking_identifiers) {
                my $tracking_identifier = $identifier_info->[0];
                my $material = $identifier_info->[1];
                my $tracking_obj = CXGN::TrackingActivity::AddTrackingIdentifier->new({
                    schema => $schema,
                    phenome_schema => $phenome_schema,
                    tracking_identifier => $tracking_identifier,
                    material => $material,
                    project_id => $activity_project_id,
                    user_id => $contact_id
                 });
                my $return = $tracking_obj->store();
                if (!$return) {
                    $c->stash->{rest} = {error_string => "Error generating tracking identifier"};
                    return;
                } elsif ($return->{error}) {
                    my $error = $return->{error};
                    $c->stash->{rest} = {error_string => $error};
                    return;
                } else {
                    my $tracking_stock_id = $return->{tracking_id};
                    push @identifier_stock_ids, $tracking_stock_id;
                }
            }

            my $order_tracking_identifier_prop = CXGN::Stock::OrderTrackingIdentifier->new({ bcs_schema => $schema, people_schema => $people_schema});
            $order_tracking_identifier_prop->tracking_identifiers(\@identifier_stock_ids);
            $order_tracking_identifier_prop->parent_id($order_id);
        	my $prop_id = $order_tracking_identifier_prop->store_sp_orderprop();

            if (!$prop_id){
                $c->stash->{rest} = {error_string => "Error saving your tracking identifiers",};
                return;
            }
        }

        my $contact_person = CXGN::People::Person -> new($dbh, $contact_id);
        my $contact_email = $contact_person->get_contact_email();
        push @contact_email_list, $contact_email;

    }

    my $host = $c->config->{main_production_site_url};
    my $project_name = $c->config->{project_name};
    my $subject="Ordering Notification from $project_name";
    my $body=<<END_HEREDOC;

You have an order submitted to $project_name ($host/order/stocks/view).
Please do *NOT* reply to this message.

Thank you,
$project_name Team

END_HEREDOC

    foreach my $each_email (@contact_email_list) {
        CXGN::Contact::send_email($subject,$body,$each_email);
    }

    $c->stash->{rest}->{success} .= 'Your order has been submitted successfully and the vendor has been notified.';

}


sub get_user_current_orders :Path('/ajax/order/current') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh;
    my $order_properties = $c->config->{order_properties};
    my @properties = split ',',$order_properties;
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your current orders!'};
        $c->detach();
    }

    if ($c->user){
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $people_schema = $c->dbic_schema('CXGN::People::Schema', undef, $user_id);

    my $orders = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, order_from_id => $user_id});
    my $all_orders_ref = $orders->get_orders_from_person_id();

    my @current_orders;
    my @all_orders = @$all_orders_ref;
    foreach my $order (@all_orders) {
        if (($order->{'order_status'}) ne 'completed') {
            my $clone_list = $order->{'clone_list'};
            my $item_name;
            my @all_item_details = ();
            my $all_details_string;
            my $empty_string = '';
            foreach my $each_item (@$clone_list) {
                my @request_details = ();
                $item_name = (keys %$each_item)[0];
                push @request_details, "<b>"."Item Name"."<b>". ":"."".$item_name;
                foreach my $field (@properties) {
                    my $each_detail = $each_item->{$item_name}->{$field};
                    my $detail_string = $field. ":"."".$each_detail;
                    push @request_details, $detail_string;
                }
                push @request_details, $empty_string;
                my $details_string = join("<br>", @request_details);
                push @all_item_details, $details_string;
            }
            $all_details_string = join("<br>", @all_item_details);
            push @current_orders, [qq{<a href="/order/details/view/$order->{'order_id'}">$order->{'order_id'}</a>}, $order->{'create_date'}, $all_details_string, $order->{'order_status'}, $order->{'order_to_name'}, $order->{'comments'}]
        }
    }

    $c->stash->{rest} = {data => \@current_orders};
}

sub get_user_completed_orders :Path('/ajax/order/completed') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh;
    my $order_properties = $c->config->{order_properties};
    my @properties = split ',',$order_properties;
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your completed orders!'};
        $c->detach();
    }

    if ($c->user){
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $people_schema = $c->dbic_schema('CXGN::People::Schema', undef, $user_id);
    my $orders = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, order_from_id => $user_id});
    my $all_orders_ref = $orders->get_orders_from_person_id();
    my @completed_orders;
    my @all_orders = @$all_orders_ref;

    foreach my $order (@all_orders) {
        if (($order->{'order_status'}) eq 'completed') {
            my $clone_list = $order->{'clone_list'};
            my $item_name;
            my @all_item_details = ();
            my $empty_string = '';
            my $all_details_string;
            foreach my $each_item (@$clone_list) {
                my @request_details = ();
                $item_name = (keys %$each_item)[0];
                push @request_details, "<b>"."Item Name"."<b>". ":"."".$item_name;
                foreach my $field (@properties) {
                    my $each_detail = $each_item->{$item_name}->{$field};
                    my $detail_string = $field. ":"."".$each_detail;
                    push @request_details, $detail_string;
                }
                push @request_details, $empty_string;
                my $details_string = join("<br>", @request_details);
                push @all_item_details, $details_string;
            }
            $all_details_string = join("<br>", @all_item_details);

            push @completed_orders, [qq{<a href="/order/details/view/$order->{'order_id'}">$order->{'order_id'}</a>}, $order->{'create_date'}, $all_details_string, $order->{'order_status'}, $order->{'completion_date'}, $order->{'order_to_name'}, $order->{'comments'}]
        }
    }

    $c->stash->{rest} = {data => \@completed_orders};

}


sub get_vendor_current_orders :Path('/ajax/order/vendor_current_orders') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh;
    my $order_properties = $c->config->{order_properties};
    my @properties = split ',',$order_properties;
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your orders!'};
        $c->detach();
    }

    if ($c->user){
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $people_schema = $c->dbic_schema('CXGN::People::Schema', undef, $user_id);
    my $orders = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, order_to_id => $user_id});
    my $vendor_orders_ref = $orders->get_orders_to_person_id();

    my @vendor_current_orders;
    my @all_vendor_orders = @$vendor_orders_ref;
    foreach my $vendor_order (@all_vendor_orders) {
        if (($vendor_order->{'order_status'}) ne 'completed') {
            my $clone_list = $vendor_order->{'clone_list'};
            my $item_name;
            my @all_item_details = ();
            my $all_details_string;
            my $empty_string = '';
            foreach my $each_item (@$clone_list) {
                my @request_details = ();
                $item_name = (keys %$each_item)[0];
                push @request_details, "<b>"."Item Name"."<b>". ":"."".$item_name;
                foreach my $field (@properties) {
                    my $each_detail = $each_item->{$item_name}->{$field};
                    my $detail_string = $field. ":"."".$each_detail;
                    push @request_details, $detail_string;
                }
                push @request_details, $empty_string;
                my $details_string = join("<br>", @request_details);

                push @all_item_details, $details_string;
            }
            $all_details_string = join("<br>", @all_item_details);

            $vendor_order->{'order_details'} = $all_details_string;
            push @vendor_current_orders, $vendor_order
        }
    }

    $c->stash->{rest} = {data => \@vendor_current_orders};

}


sub get_vendor_completed_orders :Path('/ajax/order/vendor_completed_orders') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh;
    my $order_properties = $c->config->{order_properties};
    my @properties = split ',',$order_properties;
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your orders!'};
        $c->detach();
    }

    if ($c->user) {
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $people_schema = $c->dbic_schema('CXGN::People::Schema', undef, $user_id);
    my $orders = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, order_to_id => $user_id});
    my $vendor_orders_ref = $orders->get_orders_to_person_id();

    my @vendor_completed_orders;
    my @all_vendor_orders = @$vendor_orders_ref;
    foreach my $vendor_order (@all_vendor_orders) {
        if (($vendor_order->{'order_status'}) eq 'completed') {
            my $clone_list = $vendor_order->{'clone_list'};
            my $item_name;
            my @all_item_details = ();
            my $empty_string = '';
            my $all_details_string;
            foreach my $each_item (@$clone_list) {
                my @request_details = ();
                $item_name = (keys %$each_item)[0];
                push @request_details, "<b>"."Item Name"."<b>". ":"."".$item_name;
                foreach my $field (@properties) {
                    my $each_detail = $each_item->{$item_name}->{$field};
                    my $detail_string = $field. ":"."".$each_detail;
                    push @request_details, $detail_string;
                }
                push @request_details, $empty_string;
                my $details_string = join("<br>", @request_details);
                push @all_item_details, $details_string;
            }
            $all_details_string = join("<br>", @all_item_details);
            $vendor_order->{'order_details'} = $all_details_string;

            push @vendor_completed_orders, $vendor_order
        }
    }

    $c->stash->{rest} = {data => \@vendor_completed_orders};

}

sub update_order : Path('/ajax/order/update') : ActionClass('REST'){ }

sub update_order_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh;
    my $order_id = $c->req->param('order_id');
    my $new_status = $c->req->param('new_status');
    my $contact_person_comments = $c->req->param('contact_person_comments');
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to update the orders!'};
        $c->detach();
    }

    if ($c->user) {
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $people_schema = $c->dbic_schema('CXGN::People::Schema', undef, $user_id);
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);

    if ($new_status eq 're-opened') {
        my $re_open_by_person= CXGN::People::Person->new($dbh, $user_id);
        my $re_open_name = $re_open_by_person->get_first_name()." ".$re_open_by_person->get_last_name();
        $new_status = 're-opened by'." ".$re_open_name;

        my $order_obj = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, sp_order_id => $order_id});
        my $order_result = $order_obj->get_order_details();
        my $vendor_id = $order_result->[7];
        if ($user_id != $vendor_id) {
            my $contact_person = CXGN::People::Person -> new($dbh, $vendor_id);
            my $contact_email = $contact_person->get_contact_email();

            my $host = $c->config->{main_production_site_url};
            my $project_name = $c->config->{project_name};
            my $subject="Ordering Notification from $project_name";
            my $body=<<END_HEREDOC;

You have a re-opened order submitted to $project_name ($host/order/stocks/view).
Please do *NOT* reply to this message.

Thank you,
$project_name Team

END_HEREDOC

            CXGN::Contact::send_email($subject,$body,$contact_email);
        }
    }

    my $order_obj;
    if ($new_status eq 'completed') {
        $order_obj = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, sp_order_id => $order_id, order_to_id => $user_id, order_status => $new_status, completion_date => $timestamp, comments => $contact_person_comments});
    } else {
        $order_obj = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, sp_order_id => $order_id, order_to_id => $user_id, order_status => $new_status, comments => $contact_person_comments});
    }

    my $updated_order = $order_obj->store();
#    print STDERR "UPDATED ORDER ID =".Dumper($updated_order)."\n";
    if (!$updated_order){
        $c->stash->{rest} = {error_string => "Error updating the order",};
        return;
    }

    my $orderprop_rs = $people_schema->resultset('SpOrderprop')->find( { sp_order_id => $order_id } );
    my $orderprop_id = $orderprop_rs->sp_orderprop_id();
    my $details_json = $orderprop_rs->value();
    print STDERR "ORDER PROP ID =".Dumper($orderprop_id)."\n";
    my $detail_hash = JSON::Any->jsonToObj($details_json);

    my $order_history_ref = $detail_hash->{'history'};
    my @order_history = @$order_history_ref;
    my $new_status_record = {};
    $new_status_record->{$new_status}{'Date'} = $timestamp;
    $new_status_record->{$new_status}{'Comments'} = $contact_person_comments;
    push @order_history, $new_status_record;
    $detail_hash->{'history'} = \@order_history;

    my $order_prop = CXGN::Stock::OrderBatch->new({ bcs_schema => $schema, people_schema => $people_schema, sp_order_id => $order_id, prop_id => $orderprop_id});
    $order_prop->history(\@order_history);
    my $updated_orderprop = $order_prop->store_people_schema_prop();

    if (!$updated_orderprop){
        $c->stash->{rest} = {error_string => "Error updating the order",};
        return;
    }

    $c->stash->{rest} = {success => "1",};

}


sub single_step_submission : Path('/ajax/order/single_step_submission') : ActionClass('REST'){ }

sub single_step_submission_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh();
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $request_date = $time->ymd();
    my $item_name = $c->req->param('item_name');
    my $order_details = decode_json ($c->req->param('order_details'));
    my %details;

    $details{$item_name} = $order_details;
    if (!$c->user()) {
        print STDERR "User not logged in... not adding a catalog item.\n";
        $c->stash->{rest} = {error_string => "You must be logged in to add a catalog item." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $user_role = $c->user->get_object->get_user_type();

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $people_schema = $c->dbic_schema('CXGN::People::Schema', undef, $user_id);

    my $catalog_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_catalog_json', 'stock_property')->cvterm_id();
    my $item_rs = $schema->resultset("Stock::Stock")->find( { uniquename => $item_name });
    my $item_id = $item_rs->stock_id();
    my $item_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $item_id, type_id => $catalog_cvterm_id});
    my $item_info_string = $item_info_rs->value();
    my $item_info_hash = decode_json $item_info_string;
    my $contact_person_id = $item_info_hash->{'contact_person_id'};
    my $item_type = $item_info_hash->{'item_type'};
    $details{$item_name}{'item_type'} = $item_type;
    push my @item_list, \%details;
    print STDERR "REQUEST DETAILS =".Dumper(\%details)."\n";
    my @history = ();
    my $history_info = {};

    my $new_order = CXGN::Stock::Order->new( { bcs_schema => $schema, people_schema => $people_schema, dbh => $dbh});
    $new_order->order_from_id($user_id);
    $new_order->order_to_id($contact_person_id);
    $new_order->order_status("submitted");
    $new_order->create_date($timestamp);
    my $order_id = $new_order->store();
#        print STDERR "ORDER ID =".($order_id)."\n";
    if (!$order_id){
        $c->stash->{rest} = {error_string => "Error saving your order",};
        return;
    }

    $history_info ->{'submitted'} = $timestamp;
    push @history, $history_info;


    my $order_prop = CXGN::Stock::OrderBatch->new({ bcs_schema => $schema, people_schema => $people_schema});
    $order_prop->clone_list(\@item_list);
    $order_prop->parent_id($order_id);
    $order_prop->history(\@history);
    my $order_prop_id = $order_prop->store_sp_orderprop();
#        print STDERR "ORDER PROP ID =".($order_prop_id)."\n";

    if (!$order_prop_id){
        $c->stash->{rest} = {error_string => "Error saving your order",};
        return;
    }

    my $contact_person = CXGN::People::Person -> new($dbh, $contact_person_id);
    my $contact_email = $contact_person->get_contact_email();

    my $host = $c->config->{main_production_site_url};
    my $project_name = $c->config->{project_name};
    my $subject="Ordering Notification from $project_name";
    my $body=<<END_HEREDOC;

You have an order submitted to $project_name ($host/order/stocks/view).
Please do *NOT* reply to this message.

Thank you,
$project_name Team

END_HEREDOC

    CXGN::Contact::send_email($subject,$body,$contact_email);

    $c->stash->{rest}->{success} .= 'Your request has been submitted successfully and the vendor has been notified.';

}


sub get_order_tracking_ids :Path('/ajax/order/order_tracking_ids') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;
    my $order_number = $c->req->param('order_id');
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your orders!'};
        $c->detach();
    }

    if ($c->user) {
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $order_obj = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, sp_order_id => $order_number});
    my $tracking_info = $order_obj->get_tracking_info();

    $c->stash->{rest} = {tracking_info => $tracking_info};

}


sub download_order_item_file : Path('/ajax/order/download_order_item_file') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;

    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }
    my $user_id = $user->get_object()->get_sp_person_id();

    my $order_id = $c->req->param('order_id');
#    print STDERR "ORDER ID =".Dumper($order_id)."\n";
    my $file_format = "xls";

    my $time = DateTime->now();
    my $timestamp = $time->ymd();
    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = "order_items". "XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".$file_format";
    my $tempfile = $c->config->{basepath}."/".$rel_file;
#    print STDERR "TEMPFILE : $tempfile\n";

    my $download;
    if (!defined $order_id || $order_id eq '') {
        $download = CXGN::Trial::Download->new({
            bcs_schema => $schema,
            people_schema => $people_schema,
            dbh => $dbh,
            filename => $tempfile,
            format => 'OrderItemFileXLS',
            user_id => $user_id,
        });
    } else {
        $download = CXGN::Trial::Download->new({
            bcs_schema => $schema,
            people_schema => $people_schema,
            dbh => $dbh,
            filename => $tempfile,
            format => 'OrderItemFileXLS',
            user_id => $user_id,
            trial_id => $order_id
        });
    }

    my $error = $download->download();

    my $file_name = "order_items" . "_" . "$timestamp" . ".$file_format";
    $c->res->content_type('Application/'.$file_format);
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

    my $output = read_file($tempfile);

    $c->res->body($output);


}


sub get_active_order_tracking_ids :Path('/ajax/order/active_order_tracking_ids') Args(0) {

    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;
    my $order_properties = $c->config->{order_properties};
    my @properties = split ',',$order_properties;
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your orders!'};
        $c->detach();
    }

    if ($c->user){
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $orders = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, order_to_id => $user_id, bcs_schema => $schema});
    my $active_item_tracking_ids = $orders->get_active_item_tracking_info();
#    print STDERR "ACTIVE TRACKING IDS =".Dumper($active_item_tracking_ids)."\n";

    $c->stash->{rest} = {tracking_info => $active_item_tracking_ids};

}


sub get_order_progress :Path('/ajax/order/progress') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;
    my $tracking_activities = $c->config->{tracking_tissue_culture_info};
    my @activity_types = split ',',$tracking_activities;

    my $order_properties = $c->config->{order_properties};
    my @properties = split ',',$order_properties;

    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your orders!'};
        $c->detach();
    }

    if ($c->user){
        $user_id = $c->user()->get_object()->get_sp_person_id();
        my $check_vendor_role = $c->user->check_roles('vendor');
    }

    my $orders = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, bcs_schema => $schema, order_to_id => $user_id});
    my $order_activities = $orders->get_orders_to_person_id_progress();
    my @order_progress;
    foreach my $activity_info (@$order_activities) {
        my @row = ();
        my @request_details = ();
        my $empty_string;
        my $order_id = $activity_info->[0];
        my $identifier_name = $activity_info->[1];
        my $identifier_id = $activity_info->[2];
        my $material_name = $activity_info->[3];
        my $material_id = $activity_info->[4];
        my $material_type = $activity_info->[5];
        my $order_info = $activity_info->[7];

        foreach my $field (@properties) {
            my $each_detail = $order_info->{$field};
            my $detail_string = $field. ":"."".$each_detail;
            push @request_details, $detail_string;
        }
        push @request_details, $empty_string;
        my $details_string = join("<br>", @request_details);

        push @row, qq{<a href="/order/details/view/$order_id">$order_id</a>};
        push @row, $details_string;
        push @row, qq{<a href="/activity/details/$identifier_id">$identifier_name</a>};
        push @row, qq{<a href="/stock/$material_id/view">$material_name</a>};
        my $progress = $activity_info->[6];
        my $input;

        if ($progress) {
            my %progress_hash = %{$progress};
            foreach my $type (@activity_types){
                if ($progress_hash{$type}) {
                    my $details = {};
                    my %details_hash = ();
                    $details = $progress_hash{$type};
                    %details_hash = %{$details};
                    my $input = 0;
                    foreach my $key (keys %details_hash) {
                        $input += $details_hash{$key}{'input'};
                    }
                    push @row, $input
                } else {
                    push @row, $input;
                }
            }
        } else {
            foreach my $type (@activity_types) {
                push @row, $input;
            }
        }

        push @order_progress,[@row];
    }

    print STDERR "ORDER PROGRESS =".Dumper(\@order_progress)."\n";

    $c->stash->{rest} = {data => \@order_progress};

}



1;
