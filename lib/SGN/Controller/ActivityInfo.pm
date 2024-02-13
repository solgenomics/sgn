
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
    my @type_select_options = split ',',$types;

    my $activity_type_header = $c->config->{tracking_activities_header};
    my @activity_headers = split ',',$activity_type_header;

    my $identifier_name = $schema->resultset("Stock::Stock")->find({stock_id => $identifier_id})->uniquename();
    my $material_of_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id();
    my $material_info = $schema->resultset("Stock::StockRelationship")->find( { object_id => $identifier_id, type_id => $material_of_cvterm_id} );
    my $material_id = $material_info->subject_id();
    my $material_rs = $schema->resultset("Stock::Stock")->find( { stock_id => $material_id });
    my $material_name = $material_rs->uniquename();

    $c->stash->{identifier_id} = $identifier_id;
    $c->stash->{identifier_name} = $identifier_name;
    $c->stash->{type_select_options} = \@type_select_options;
    $c->stash->{activity_headers} = \@activity_headers;
    $c->stash->{material_name} = $material_name;

    $c->stash->{template} = '/order/activity_info_details.mas';

}


sub record_activity :Path('/activity/record') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $identifier_name = $c->req->param("identifier_name");
#    print STDERR "IDENTIFIER NAME =".Dumper($identifier_name)."\n";

    if (! $c->user()) {
	    $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user) {
        my $check_vendor_role = $c->user->check_roles('vendor');
        $c->stash->{check_vendor_role} = $check_vendor_role;
    }

    my $types = $c->config->{tracking_activities};
    my @type_select_options = split ',',$types;

    my $activity_type_header = $c->config->{tracking_activities_header};
    my @activity_headers = split ',',$activity_type_header;

    my $identifier_id;
    if ($identifier_name) {
        $identifier_id = $schema->resultset("Stock::Stock")->find({uniquename => $identifier_name})->stock_id();
    }
    print STDERR "IDENTIFIER ID =".Dumper($identifier_id)."\n";



    $c->stash->{identifier_id} = $identifier_id;
    $c->stash->{activity_headers} = \@activity_headers;
    $c->stash->{type_select_options} = \@type_select_options;
    $c->stash->{template} = '/tracking_activities/record_activity.mas';

}



1;
