
package SGN::Controller::AJAX::TrackingActivity;

use Moose;
use CXGN::Stock::Order;
use CXGN::Stock::OrderBatch;
use Data::Dumper;
use JSON;
use DateTime;
use CXGN::People::Person;
use CXGN::Contact;
use CXGN::Trial::Download;
use CXGN::Stock::TrackingActivity::TrackingIdentifier;
use CXGN::Stock::TrackingActivity::ActivityInfo;
use SGN::Model::Cvterm;

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


sub activity_info_save : Path('/ajax/tracking_activity/save') : ActionClass('REST'){ }

sub activity_info_save_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to add properties." };
        return;
    }
    if (!($c->user()->has_role('submitter') or $c->user()->has_role('curator'))) {
        $c->stash->{rest} = { error => "You do not have sufficient privileges to record activity info." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    print STDERR "USER ID =".Dumper($user_id)."\n";

    my $tracking_identifier = $c->req->param("tracking_identifier");
    my $selected_type = $c->req->param("selected_type");
    my $input = $c->req->param("input");
    my $record_timestamp = $c->req->param("record_timestamp");
    my $tracking_activities = $c->config->{tracking_activities};
    my @types = split ',',$tracking_activities;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $check_tracking_identifier = $schema->resultset("Stock::Stock")->find({uniquename => $tracking_identifier});

    my $add_activity_info = CXGN::Stock::TrackingActivity::ActivityInfo->new({
        schema => $schema,
        tracking_identifier => $tracking_identifier,
        selected_type => $selected_type,
        input => $input,
        timestamp => $record_timestamp,
        operator_id => $user_id,
    });
    $add_activity_info->add_info();
    print STDERR "ADD INFO =".Dumper ($add_activity_info->add_info())."\n";

    if (!$add_activity_info->add_info()){
        $c->stash->{rest} = {error_string => "Error saving info",};
        return;
    }

    $c->stash->{rest} = { success => 1};

}


sub get_activity_details :Path('/ajax/tracking_activity/details') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $identifier_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my @details;
    my $tracking_activities = $c->config->{tracking_activities};
    my @activity_types = split ',',$tracking_activities;

    my $tracking_data_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_metadata_json', 'stock_property')->cvterm_id();
    my $activity_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $identifier_id, type_id => $tracking_data_json_cvterm_id});
    if ($activity_info_rs) {
        my $activity_json = $activity_info_rs->value();
        my $info = JSON::Any->jsonToObj($activity_json);
        my %info_hash = %{$info};
        foreach my $type (@activity_types){
            my $empty_string;
            my @each_type_details = ();
            my $each_timestamp_string;
            my $each_type_string;
            if ($info_hash{$type}) {
                my @each_type_details = ();
                my $details = {};
                my %details_hash = ();
                $details = $info_hash{$type};
                %details_hash = %{$details};
                print STDERR "DETAILS HASH =".Dumper(\%details_hash);
                foreach my $timestamp (keys %details_hash) {
                    my @each_timestamp_details = ();
                    push @each_timestamp_details, "timestamp".":"."".$timestamp;
                    my $operator_id = $details_hash{$timestamp}{'operator_id'};
                    push @each_timestamp_details, "operator".":"."".$operator_id;
                    my $input = $details_hash{$timestamp}{'input'};
                    push @each_timestamp_details, "count".":"."".$input;
                    push @each_timestamp_details, $empty_string;

                    $each_timestamp_string = join("<br>", @each_timestamp_details);
                    push @each_type_details, $each_timestamp_string;
                }

                $each_type_string = join("<br>", @each_type_details);
                print STDERR "EACH TYPE STRING =".Dumper($each_type_string)."\n";
                push @details, $each_type_string;
            } else {
                my $empty_string;
                push @details, $empty_string;
            }
        }
    }

    my @all_details;
    push @all_details, [@details];

    print STDERR "ALL DETAILS =".Dumper(\@all_details)."\n";

    $c->stash->{rest} = { data => \@all_details };

}


1;
