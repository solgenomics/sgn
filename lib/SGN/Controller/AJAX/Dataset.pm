
package SGN::Controller::AJAX::Dataset;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use File::Temp qw| tempfile tempdir |;
use Data::Dumper;
use JSON::Any;
use CXGN::Dataset;
use Text::CSV ("csv");
use strict;
use warnings;

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

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $people_schema =  $c->dbic_schema("CXGN::People::Schema", undef, $user_id);
    if (CXGN::Dataset->exists_dataset_name($people_schema, $dataset_name)) {
	$c->stash->{rest} = { error => "The dataset with name $dataset_name already exists. Please choose another name." };
	return;
    }

    my $dataset = CXGN::Dataset->new( {
	schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id),
	people_schema => $people_schema,
				      });

    $dataset->sp_person_id($user_id);
    $dataset->name($dataset_name);
    $dataset->description($dataset_description);

    foreach my $type (qw | trials accessions years locations plots traits breeding_programs genotyping_protocols genotyping_projects trial_types trial_designs category_order |) {
	#print STDERR "Storing data: $type\n";

	my $json = $c->req->param($type);
	if ($json) {
	    my $obj = JSON::Any->jsonToObj($json);
	    $dataset->$type($obj);
	}
    }

    $dataset->store();

    $c->stash->{rest} = { message => "Stored Dataset Successfully!" };
}

sub store_outliers_in_dataset :Path('/ajax/dataset/store_outliers') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $string_outliers = $c->req->param('outliers');
    my $string_outlier_cutoffs = $c->req->param('outlier_cutoffs');

    my @outliers = split(',',$string_outliers);
    my @outlier_cutoffs = split(',', $string_outlier_cutoffs);
    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    sp_dataset_id => $dataset_id,
        outliers => \@outliers,
        outlier_cutoffs => \@outlier_cutoffs
	});


    $dataset->store();
    $c->stash->{rest} = { success => 1 };
    
}

sub retrieve_outliers_from_dataset :Path('/ajax/dataset/retrieve_outliers') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $dataset = CXGN::Dataset->new(
        {
            schema => $c->dbic_schema("Bio::Chado::Schema"),
            people_schema => $c->dbic_schema("CXGN::People::Schema"),
            sp_dataset_id => $dataset_id,
        });

    my $outliers = $dataset->outliers();

    $c->stash->{rest} = { outliers => $outliers };
}

sub get_rosners_test_outliers :Path('/ajax/dataset/rosner_test') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $dataset_trait = $c->req->param('dataset_trait');

    print STDERR "dataset_trait: $dataset_trait";
    my $dataset = CXGN::Dataset->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id => $dataset_id,
        include_phenotype_primary_key => 1,
    });
    #
    my $phenotypes_data_ref = $dataset->retrieve_phenotypes();
    my @columns = @{$phenotypes_data_ref->[0]};
    # print STDERR "columns: ", join(", ", @columns);

    my ($trait_index) = grep { @columns[$_] eq $dataset_trait } (0 ..  scalar @columns -1);
    my ($trait_id_index) = grep { @columns[$_] eq "${dataset_trait}_phenotype_id" } (0 ..  scalar @columns -1);

    $c->tempfiles_subdir("rosners_files");
    my ($trait_file_path, $temp_file) = $c->tempfile(TEMPLATE=>"rosners_files/trait_XXXXX", SUFFIX => '.csv');
    my ($stat_file_path, $stat_file) = $c->tempfile(TEMPLATE=>"rosners_files/stat_XXXXX", SUFFIX => '.csv');

    my $csv = Text::CSV->new ({ binary => 1});

    open my $fh, ">:encoding(utf8)", $trait_file_path or die "$trait_file_path: $!";
    foreach my $row (@$phenotypes_data_ref) {
        $csv->say ($fh, [$row->[$trait_index], $row->[$trait_id_index]]);
    }
    close $fh;

    # run cluster with R
    my $cmd = CXGN::Tools::Run->new({
        backend => $c->config->{backend},
        submit_host=>$c->config->{cluster_host},
        temp_base => $c->config->{cluster_shared_tempdir} . "/rosners_files",
        queue => $c->config->{'web_cluster_queue'},
        do_cleanup => 0,
        # don't block and wait if the cluster looks full
        max_cluster_jobs => 1_000_000_000,
    });

    $cmd->run_cluster(
        "Rscript ",
        $c->config->{basepath} . "/R/dataset/rosner_test.R",
        $trait_file_path,
        $stat_file_path
    );
    $cmd->alive;
    $cmd->is_cluster(1);
    $cmd->wait;

    # print STDERR Dumper $stat_file_path;
    my $aoa = csv (in => $stat_file_path);   # as array of hash

    $c->stash->{rest} = {
        message            => "Rosners TEST Successfully!",
        dataset_id         => $dataset_id,
        dataset_trait      => $dataset_trait,
        data               => \@columns,
        index              => $trait_index,
        phenotype_id_index => $trait_id_index,
        file               => $aoa,
    };
}

sub retrieve_datasets_by_user :Path('/ajax/dataset/by_user') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user = $c->user();
    if (!$user) {
	$c->stash->{rest} = { error => "No logged in user to display dataset information for." };
	return;
    }

    my $sp_person_id = $c->user() ? $c->user()->get_object->get_sp_person_id() : undef;
    my $datasets = CXGN::Dataset->get_datasets_by_user(
	$c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id),
	$sp_person_id
	);

    $c->stash->{rest} = $datasets;
}

sub get_datasets_by_user_html :Path('/ajax/dataset/by_user_html') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user = $c->user();
    if (!$user) {
        $c->stash->{rest} = { error => "No logged in user to display dataset information for." };
        return;
    }

    my $sp_person_id = $c->user() ? $c->user()->get_object->get_sp_person_id() : undef;

    my $datasets = CXGN::Dataset->get_datasets_by_user(
        $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id),
        $sp_person_id
        );

    my @result;
    foreach (@$datasets) {
        my @res;
        push @res, ("<a href=\"/dataset/$_->[0]\">$_->[1]</a>", $_->[2]);
        push @result , \@res;
    }
    $c->stash->{rest} = { data => \@result };
}

sub get_datasets_public :Path('/ajax/dataset/get_public') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $datasets = CXGN::Dataset->get_datasets_public(
        $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id)
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
	    schema => $c->dbic_schema("Bio::Chado::Schema", undef, $logged_in_user),
            people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $logged_in_user),
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

sub set_datasets_private :Path('/ajax/dataset/set_private') Args(1) {
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
            schema => $c->dbic_schema("Bio::Chado::Schema", undef, $logged_in_user),
            people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $logged_in_user),
            sp_dataset_id=> $dataset_id,
        });
    print STDERR "Dataset owner: ".$dataset->sp_person_id.", logged in: $logged_in_user\n";
    if ($dataset->sp_person_id() != $logged_in_user) {
        $c->stash->{rest} = { error => "Only the owner can change a dataset" };
        return;
    }
    print STDERR "set private dataset_id $dataset_id\n";
    my $error = $dataset->set_dataset_private();

    if ($error) {
        $c->stash->{rest} = { error => $error };
    } else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub update_description :Path('/ajax/dataset/update_description') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $dataset_description = $c->req->param("description");

    my $user = $c->user();
    if (!$user) {
        $c->stash->{rest} = { error => "No logged in user error." };
        return;
    }

    my $logged_in_user = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new(
        {
            schema => $c->dbic_schema("Bio::Chado::Schema", undef, $logged_in_user),
            people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $logged_in_user),
            sp_dataset_id=> $dataset_id,
        });
    $dataset->description($dataset_description);
    print STDERR "Dataset owner: ".$dataset->sp_person_id.", logged in: $logged_in_user\n";
    if ($dataset->sp_person_id() != $logged_in_user) {
        $c->stash->{rest} = { error => "Only the owner can change a dataset" };
        return;
    }
    my $error = $dataset->update_description($dataset_description);

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

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id),
	    people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id),
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
	    schema => $c->dbic_schema("Bio::Chado::Schema", undef, $logged_in_user),
	    people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $logged_in_user),
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

1
