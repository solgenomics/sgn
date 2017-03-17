
package SGN::Controller::AJAX::Dataset;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::Dataset;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );

sub store_dataset :Path('/ajax/dataset/save') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $user;
    if (!$c->user()) { 
	$c->stash->{rest} = { error => "Login required to perform requested action." };
	return;
    }
    else { 
	if (! ($c->user->check_roles('submitter') || $c->user->check_roles('curator'))) { 
	    $c->stash->{rest} = { error => "Insufficient privileges to perform requested action." };
	    return;
	}
    }
	    

    my %data;

    my $dataset_name = $c->req->param("name");
    
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
    
    foreach my $type (qw | trials accessions years locations plots traits breeding_programs genotyping_protocols trial_types trial_designs |) { 
	print STDERR "Storing data: $type. $data{$type}\n";
	
	my $json = $c->req->param($type);
	if ($json) { 
	    my $obj = JSON::Any->jsonToObj($json);
	    $dataset->$type($obj);
	}
    }

    $dataset->store();

    $c->stash->{rest} = { message => "Peace on earth!" };

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

sub get_dataset :Path('/ajax/dataset/get') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    
    my $dataset = CXGN::Dataset->new( 
	{ 
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    dataset_id=> $dataset_id,
	});
	    
    my $dataset_definition = $dataset->get_dataset_definition();
    
    $c->stash->{rest} = { dataset => $dataset_definition };
}


1;
