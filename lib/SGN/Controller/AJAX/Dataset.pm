
package SGN::Controller::AJAX::Dataset;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::Dataset;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );

sub store_dataset :Path('/ajax/dataset/save') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user;
    if (!$c->user()) {
	$c->stash->{rest} = { error => "Login required to perform requested action." };
	return;
    }

    my %data;

    my $dataset_name = $c->req->param("name");
    my $dataset_description = $c->req->param("description");

    my $people_schema =  $c->dbic_schema("CXGN::People::Schema");
    if (CXGN::Dataset->exists_dataset_name($people_schema, $dataset_name)) {
	$c->stash->{rest} = { error => "The dataset with name $dataset_name already exists. Please chose another name." };
	return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new( {
	schema => $c->dbic_schema("Bio::Chado::Schema"),
	people_schema => $people_schema,
				      });

    $dataset->sp_person_id($user_id);
    $dataset->name($dataset_name);
    $dataset->description($dataset_description);

    foreach my $type (qw | trials accessions years locations plots traits breeding_programs genotyping_protocols trial_types trial_designs category_order |) {
#	print STDERR "Storing data: $type. $data{$type}\n";

	my $json = $c->req->param($type);
	if ($json) {
	    my $obj = JSON::Any->jsonToObj($json);
	    $dataset->$type($obj);
	}
    }

    $dataset->store();

    $c->stash->{rest} = { message => "Stored Dataset Successfully!" };
}

sub get_datasets_by_user :Path('/ajax/dataset/by_user') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user = $c->user();
    if (!$user) {
	$c->stash->{rest} = { error => "No logged in user to display dataset information for." };
	return;
    }

    my $datasets = CXGN::Dataset->get_datasets_by_user(
	$c->dbic_schema("CXGN::People::Schema"),
	$user->get_object()->get_sp_person_id()
	);

    $c->stash->{rest} = $datasets;
}

sub get_datasets_public :Path('/ajax/dataset/get_public') {
    my $self = shift;
    my $c = shift;

    my $datasets = CXGN::Dataset->get_datasets_public(
        $c->dbic_schema("CXGN::People::Schema")
        );

    $c->stash->{rest} = $datasets;
}

sub set_datasets_public :Path('/ajax/dataset/set_public') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $user = $c->user();
    if (!$user) {
        $c->stash->{rest} = { error => "No logged in user error." };
        return;
    }

    my $logged_in_user = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new(
        {
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
            people_schema => $c->dbic_schema("CXGN::People::Schema"),
            sp_dataset_id=> $dataset_id,
        });
    print STDERR "Dataset owner: ".$dataset->sp_person_id.", logged in: $logged_in_user\n";
    if ($dataset->sp_person_id() != $logged_in_user) {
        $c->stash->{rest} = { error => "Only the owner can change a dataset" };
        return;
    }
    print STDERR "set public dataset_id $dataset_id\n";
    my $error = $dataset->set_dataset_public();

    if ($error) {
        $c->stash->{rest} = { error => $error };
    } else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub get_dataset :Path('/ajax/dataset/get') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    sp_dataset_id=> $dataset_id,
	});

    my $dataset_data = $dataset->get_dataset_data();

    $c->stash->{rest} = { dataset => $dataset_data };
}


sub retrieve_dataset_dimension :Path('/ajax/dataset/retrieve') Args(2) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $dimension = shift;
    my $include_phenotype_primary_key = $c->req->param('include_phenotype_primary_key');

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    sp_dataset_id=> $dataset_id,
        include_phenotype_primary_key => $include_phenotype_primary_key,
	});


    my $dimension_data;
    my $function_name = 'retrieve_'.$dimension;
    if ($dataset->can($function_name)) {
	
	$dimension_data = $dataset->$function_name();
    }
    else {
	$c->stash->{rest} = { error => "The specified dimension '$dimension' does not exist" };
	return;
    }

    $c->stash->{rest} = { dataset_id => $dataset_id,
			  $dimension => $dimension_data,
    };
}

sub delete_dataset :Path('/ajax/dataset/delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    if (!$c->user()) {
	$c->stash->{rest} = { error => "Deleting datasets requires login" };
	return;
    }

    my $logged_in_user = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    sp_dataset_id=> $dataset_id,
	});

#    print STDERR "Dataset owner: ".$dataset->sp_person_id.", logged in: $logged_in_user\n";
    if ($dataset->sp_person_id() != $logged_in_user) {
	$c->stash->{rest} = { error => "Only the owner can delete a dataset" };
	return;
    }

    my $error = $dataset->delete();

    if ($error) {
	$c->stash->{rest} = { error => $error };
    }
    else {
	$c->stash->{rest} = { success => 1 };
    }
}

1;
