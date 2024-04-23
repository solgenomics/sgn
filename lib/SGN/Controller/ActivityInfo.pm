
package SGN::Controller::ActivityInfo;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;
use CXGN::Stock::TrackingIdentifier;


BEGIN { extends 'Catalyst::Controller'; }

sub activity_details :Path('/activity/details') : Args(1) {
    my $self = shift;
    my $c = shift;
    my $identifier_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $tracking_identifier = CXGN::Stock::TrackingIdentifier->new(schema=>$schema, tracking_identifier_id=>$identifier_id);
    my $identifier_name = $tracking_identifier->uniquename;
    my $data_type = $tracking_identifier->data_type;
    my $material_type = $tracking_identifier->material_type;
    my $material = $tracking_identifier->get_material;
    my $material_name = $material->[1];

    my $types;
    my @type_select_options = ();
    my $activity_type_header;
    my @activity_headers = ();
    my $activity_type;

    if ($data_type eq 'trial_treatments') {
        $activity_type = 'Trial Treatments';
        $types = $c->config->{tracking_trial_treatments};
        @type_select_options = split ',',$types;

        $activity_type_header = $c->config->{tracking_trial_treatments_header};
        @activity_headers = split ',',$activity_type_header;
    } else {
        $activity_type = 'Tissue Culture';
        $types = $c->config->{tracking_tissue_culture};
        @type_select_options = split ',',$types;

        $activity_type_header = $c->config->{tracking_tissue_culture_header};
        @activity_headers = split ',',$activity_type_header;
    }

    my @options = ();
    for my $i (0 .. $#type_select_options) {
        push @options, [$type_select_options[$i], $activity_headers[$i]];
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    $c->stash->{identifier_id} = $identifier_id;
    $c->stash->{identifier_name} = $identifier_name;
    $c->stash->{type_select_options} = \@options;
    $c->stash->{activity_headers} = \@activity_headers;
    $c->stash->{material_name} = $material_name;
    $c->stash->{timestamp} = $timestamp;
    $c->stash->{activity_type} = $activity_type;

    $c->stash->{template} = '/order/activity_info_details.mas';

}


sub record_activity :Path('/activity/record') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $identifier_name = $c->req->param("identifier_name");
    my $identifier_id;
    my $data_type;
    my $material_name;

    if (!$c->user()) {
        $c->stash->{rest} = { error_string => "You must be logged in to use record page." };
        return;
    }
    if (!($c->user()->has_role('submitter') or $c->user()->has_role('curator'))) {
        $c->stash->{rest} = { error_string => "You do not have sufficient privileges to use record page." };
        return;
    }

    if ($c->user) {
        my $check_vendor_role = $c->user->check_roles('vendor');
        $c->stash->{check_vendor_role} = $check_vendor_role;
    }

    if ($identifier_name) {
        my $identifier_rs = $schema->resultset("Stock::Stock")->find({uniquename => $identifier_name});
        if (!$identifier_rs) {
            $c->stash->{message} = "The tracking identifier does not exist or has been deleted.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        } else {
            $identifier_id = $identifier_rs->stock_id();
        }
    }

    if ($identifier_id) {
        my $tracking_identifier = CXGN::Stock::TrackingIdentifier->new(schema=>$schema, tracking_identifier_id=>$identifier_id);
        $data_type = $tracking_identifier->data_type;
        my $material = $tracking_identifier->get_material;
        $material_name = $material->[1];
    }

    my $types;
    my @type_select_options = ();
    my $activity_type_header;
    my @activity_headers = ();
    my $activity_type;
    if ($data_type eq 'trial_treatments') {
        $activity_type = 'Trial Treatments';
        $types = $c->config->{tracking_trial_treatments};
        @type_select_options = split ',',$types;

        $activity_type_header = $c->config->{tracking_trial_treatments_header};
        @activity_headers = split ',',$activity_type_header;
    } elsif ($identifier_id && !$data_type){
        $activity_type = 'Tissue Culture';
        $types = $c->config->{tracking_tissue_culture};
        @type_select_options = split ',',$types;

        $activity_type_header = $c->config->{tracking_tissue_culture_header};
        @activity_headers = split ',',$activity_type_header;
    }

    my @options = ();
    for my $i (0 .. $#type_select_options) {
        push @options, [$type_select_options[$i], $activity_headers[$i]];
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    $c->stash->{identifier_id} = $identifier_id;
    $c->stash->{type_select_options} = \@options;
    $c->stash->{activity_headers} = \@activity_headers;
    $c->stash->{timestamp} = $timestamp;
    $c->stash->{activity_type} = $activity_type;
    $c->stash->{material_name} = $material_name;
    $c->stash->{template} = '/tracking_activities/record_activity.mas';

}



1;
