
package SGN::Controller::ActivityInfo;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;


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

    my $types = $c->config->{tracking_activities};
    my @activity_types = split ',',$types;

    my $activity_type_header = $c->config->{tracking_activities_header};
    my @activity_headers = split ',',$activity_type_header;

    my $identifier_name = $schema->resultset("Stock::Stock")->find({stock_id => $identifier_id})->uniquename();
    my $tracking_data_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_metadata_json', 'stock_property')->cvterm_id();
    my $activity_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $identifier_id, type_id => $tracking_data_json_cvterm_id});
    my @type_select_options = ();
    if ($activity_info_rs) {
        my $activity_json = $activity_info_rs->value();
        my $activity_hash = JSON::Any->jsonToObj($activity_json);
        my @recorded_activities = keys %$activity_hash;
        foreach my $type (@activity_types){
            if ($type ~~ @recorded_activities) {
                next;
            } else {
                push @type_select_options, $type;
            }
        }
    } else {
        @type_select_options = @activity_types;
    }

    $c->stash->{identifier_id} = $identifier_id;
    $c->stash->{identifier_name} = $identifier_name;
    $c->stash->{type_select_options} = \@type_select_options;
    $c->stash->{activity_headers} = \@activity_headers;

    $c->stash->{template} = '/order/activity_info_details.mas';

}


sub record_activity :Path('/activity/record') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $identifier_name = $c->req->param("identifier_name");
    print STDERR "IDENTIFIER NAME =".Dumper($identifier_name)."\n";

    if (! $c->user()) {
	    $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user) {
        my $check_vendor_role = $c->user->check_roles('vendor');
        $c->stash->{check_vendor_role} = $check_vendor_role;
    }


    $c->stash->{template} = '/tracking_activities/record_activity.mas';

}



1;
