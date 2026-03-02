package SGN::Controller::Propagation;

use Moose;
use URI::FromHash 'uri';
use SGN::Model::Cvterm;
use CXGN::People::Person;
use Data::Dumper;
use CXGN::Propagation::Propagation;
use JSON;

BEGIN { extends 'Catalyst::Controller'; }


sub propagation_group_page : Path('/propagation_group') Args(1) {
    my $self = shift;
    my $c = shift;
    my $id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $c->dbc->dbh;
    my $user_role;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user() && $c->user()->check_roles("curator")) {
        $user_role = "curator";
    }

    my $propagation_group_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_group', 'stock_type')->cvterm_id();

    my $propagation_group = $schema->resultset("Stock::Stock")->find( { stock_id => $id, type_id => $propagation_group_type_id } );

    my $propagation_group_id;
    my $propagation_group_name;
	if (!$propagation_group) {
    	$c->stash->{template} = '/generic_message.mas';
    	$c->stash->{message} = 'The requested propagation group ID does not exist.';
    	return;
    } else {
        $propagation_group_id = $propagation_group->stock_id();
        $propagation_group_name = $propagation_group->uniquename();
    }
    my $propagation_obj = CXGN::Propagation::Propagation->new({schema=>$schema, dbh=>$dbh, propagation_group_stock_id=>$propagation_group_id});
    my $info = $propagation_obj->get_propagation_group_info();
    print STDERR "INFO 2 =".Dumper($info)."\n";

    my $description = $info->[0]->[2];
    my $material_type = $info->[0]->[3];
    my $metadata = $info->[0]->[4];
    my $metadata_hash = decode_json $metadata;
    my $purpose = $metadata_hash->{purpose};
    my $date = $metadata_hash->{'date'};
    my $operator_name = $metadata_hash->{'operator'};
    my $sub_location = $metadata_hash->{'sub_location'};
    my $material_source_type = $metadata_hash->{'material_source_type'};

    my $accession_stock_id = $info->[0]->[5];
    my $accession_name = $info->[0]->[6];
    my $source_stock_id = $info->[0]->[7];
    my $source_name = $info->[0]->[8];
    my $project_id = $info->[0]->[9];
    my $project_name = $info->[0]->[10];
    my $accession_link = qq{<a href="/stock/$accession_stock_id/view">$accession_name</a>};
    my $source_link = qq{<a href="/stock/$source_stock_id/view">$source_name</a>};
    my $project_link = qq{<a href="/breeders/trial/$project_id">$project_name</a>};

    $c->stash->{propagation_group_id} = $propagation_group_id;
    $c->stash->{propagation_group_name} = $propagation_group_name;
    $c->stash->{purpose} = $purpose;    
    $c->stash->{description} = $description;
    $c->stash->{accession_stock_id} = $accession_stock_id;
    $c->stash->{accession_link} = $accession_link;
    $c->stash->{source_link} = $source_link;
    $c->stash->{material_type} = $material_type;
    $c->stash->{material_source_type} = $material_source_type;
    $c->stash->{date} = $date;
    $c->stash->{operator_name} = $operator_name;
    $c->stash->{sub_location} = $sub_location;
    $c->stash->{project_link} = $project_link;

    $c->stash->{template} = '/propagation/propagation_group.mas';

}


1;
