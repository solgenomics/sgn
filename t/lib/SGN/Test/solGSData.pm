=head1 NAME

SGN::Test::solGSData - load lists, datasets into fixture db and delete at the end of a test

=head1 SYNOPSIS


my $solgs_data = SGN::Test::solGSData->new();

To load lists and datasets to fixture db...
my $accessions_list =  $solgs_data->load_accessions_list();
my $accessions_list_name = $accessions_list->{list_name};
my $accessions_list_id = $accessions_list->{list_id};

my $plots_list =  $solgs_data->load_plots_list();
my $plots_list_name = $plots_list->{list_name};
my $plots_list_id = $plots_list->{list_id};

my $trials_list =  $solgs_data->load_trials_list();
my $trials_list_name = $trials_list->{list_name};
my $trials_list_id = $trials_list->{list_id};

my $trials_dt = $solgs_data->load_trials_dataset();
my $trials_dt_name = $trials_dt->{dataset_name};
my $trials_dt_id = $trials_dt->{dataset_id};

my $accessions_dt = $solgs_data->load_accessions_dataset();
my $accessions_dt_name = $accessions_dt->{dataset_name};
my $accessions_dt_id = $accessions_dt->{dataset_id};


my $plots_dt = $solgs_data->load_plots_dataset();
my $plots_dt_name = $plots_dt->{dataset_name};
my $plots_dt_id = $plots_dt->{dataset_id};

To delete lists and datasets from the fixture db..

foreach my $list_id ($trials_list_id, $accessions_list_id, $plots_list_id) {
    $solgs_data->delete_list($list_id);
}

foreach my $dataset_id ($trials_dt_id, $accessions_dt_id, $plots_dt_id) {
    $solgs_data->delete_dataset($dataset_id);
}


=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=cut

package SGN::Test::solGSData;


use Moose;

use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::List;
use CXGN::Dataset;
use File::Spec;

has 'user_id' => (isa => 'Int',
    is => 'rw',
    required => 1,
    default => 40
);

has 'fixture'=>(isa => 'Ref',
is => 'rw');


has 'trials_ids' => (isa => 'ArrayRef',
    is => 'rw',
    default => sub { [139, 141] }
);

has 'accessions_source_trial' => (isa => 'Int',
    is => 'rw',
    default => 141
);

has 'plots_source_trial' => (isa => 'Int',
    is => 'rw',
    default => 139
);

has 'accessions_list_name' => (isa => 'Str',
    is => 'rw',
    default =>'accessions list'
);

has 'accessions_list_subset' => (isa => 'Int',
    is => 'rw',
);

has 'plots_list_name' => (isa => 'Str',
    is => 'rw',
    default =>'plots list'
);

has 'plots_list_subset' => (isa => 'Int',
    is => 'rw',
);

has 'trials_list_name' => (isa => 'Str',
    is => 'rw',
    default =>'trials list'
);

has 'accessions_dataset_name' => (isa => 'Str',
    is => 'rw',
    default =>'accessions dataset'
);

has 'plots_dataset_name' => (isa => 'Str',
    is => 'rw',
    default =>'plots dataset'
);

has 'trials_dataset_name' => (isa => 'Str',
    is => 'rw',
    default =>'trials dataset'
);

has 'genotyping_protocol_id' => (isa => 'Int',
    is => 'rw',
    default => 1
);


sub load_plots_list {
    my $self = shift;
    my $trial_id = shift;

    my $list_id = $self->create_plots_list();
    my $plots = $self->get_plots_names($trial_id);

    return  $self->load_list_elems($list_id, $plots, 'plots');

}

sub get_list_details {
    my $self = shift;
    my $type = shift;
    my $list_type_name= $type. '_list_name';
    my $name = $self->$list_type_name;
    my $owner = $self->user_id;
print STDERR "\n get_list_details: name: $name -- owner: $owner\n";
    my $q = "SELECT list_id, name
                    FROM sgn_people.list
                    WHERE name = ?
                        AND owner = ?";

    my $h = $self->get_dbh->prepare($q);
    $h->execute($name, $owner);
    my ($list_id, $list_name) = $h->fetchrow_array();
print STDERR "\n get_list_details: list_name: $list_name -- list_id: $list_id\n";
    return { list_id => $list_id,
        list_name => $list_name
    };

}


sub get_dataset_details {
    my $self = shift;
    my $type = shift;
    my $dataset_type_name= $type. '_dataset_name';
    my $name = $self->$dataset_type_name;
    my $owner = $self->user_id;

print STDERR "\n get_dataset_details name: $name -- owner: $owner\n";
    my $q = "SELECT sp_dataset_id, name
                    FROM sgn_people.sp_dataset
                    WHERE name = ?
                        AND sp_person_id = ? ";

    my $h = $self->get_dbh->prepare($q);
    $h->execute($name, $owner);
    my ($dataset_id, $dataset_name) = $h->fetchrow_array();
print STDERR "\n get_list_details: dataset_name: $dataset_name -- dataset_id: $dataset_id\n";
    return { dataset_id => $dataset_id,
        dataset_name => $dataset_name
    };

}

sub create_list {
    my $self = shift;
    my $name = shift;
    my $desc = shift;

    my $user_id = $self->user_id();
    my $dbh = $self->get_dbh;

    my $list_id = CXGN::List::create_list($dbh, $name, $desc, $user_id );

    return $list_id;

}

sub create_plots_list {
    my $self = shift;

    my $name = $self->plots_list_name;
    my $desc = 'solgs plots list';

    my $list_id = $self->create_list($name, $desc);

    return $list_id;

}

sub create_trials_list {
    my $self = shift;

    my $name =$self->trials_list_name;
    my $desc = 'solgs nacrri list';

    my $list_id = $self->create_list($name, $desc);

    return $list_id;

}

sub create_accessions_list {
    my $self = shift;

    my $name = $self->accessions_list_name;
    my $desc = 'solgs clones list';

    my $list_id = $self->create_list($name, $desc);

    return $list_id;

}

sub load_accessions_list {
    my $self = shift;
    my $trial_id = shift;

    my $list_id = $self->create_accessions_list;
    my $accs = $self->get_accessions_names;

    return $self->load_list_elems($list_id, $accs, 'accessions');

}

sub load_trials_list {
    my $self = shift;

    my $list_id = $self->create_trials_list();
    my $trials = $self->trials_list();

    return $self->load_list_elems($list_id, $trials, 'trials');

}

sub load_list_elems {
    my $self = shift;
    my $list_id = shift;
    my $elems = shift;
    my $type = shift;

    my $list = $self->get_list_obj($list_id);

    $list->type($type);

    print STDERR "\nadding $type...: @$elems\n";
    my $res = $list->add_bulk($elems);

    return { list_id => $list_id,
        list_name => $list->name
    };

}

sub get_list_obj {
    my $self = shift;
    my $list_id = shift;

    my $dbh = $self->get_dbh();
    my $list = CXGN::List->new({dbh => $dbh, list_id => $list_id});

    return $list;

}

sub delete_list {
    my $self = shift;
    my $list_id = shift;

    print STDERR "\nDELETING list $list_id\n";
    CXGN::List::delete_list($self->get_dbh, $list_id);

}


sub delete_dataset {
    my ($self, $dataset_id) = @_;

    my $dataset = $self->get_dataset_obj();
    $dataset->sp_dataset_id($dataset_id);
    print STDERR "\nDELETING dataset $dataset_id\n";
    my $res = $dataset->delete();

}

sub load_trials_dataset {
    my $self = shift;

    my $dt_name = $self->trials_dataset_name;
    my $dataset = $self->create_dataset($dt_name);
    $dataset->trials($self->trials_ids);
    $dataset->store();

    return {'dataset_name' => $dataset->name,
        'dataset_id' =>$dataset->sp_dataset_id
    };
}

sub load_accessions_dataset {
    my $self = shift;

   my $trial_id = $self->accessions_source_trial;

    my $dt_name = $self->accessions_dataset_name;
    my $dataset = $self->create_dataset($dt_name);
    $dataset->trials([$trial_id]);

    my $accessions_ids = $self->get_accessions_ids;
    print STDERR "\nload_accessions_dataset: @$accessions_ids\n";

    $dataset->accessions($accessions_ids);
    $dataset->is_live(1);
    my $dataset_id = $dataset->store();

    my $sp_dt_id = $dataset->sp_dataset_id();
    print STDERR "\nstored dataset: $dataset_id -- sp_dataset_id: $sp_dt_id\n";

    return {'dataset_name' => $dataset->name,
        'dataset_id' =>$dataset->sp_dataset_id
    };
}

sub load_plots_dataset {
    my $self = shift;

    my $trial_id =  $self->plots_source_trial;

    my $dt_name = $self->plots_dataset_name;
    my $dataset = $self->create_dataset($dt_name);
    $dataset->trials([$trial_id]);

    my $plots_ids = $self->get_plots_ids;
    $dataset->plots($plots_ids);
    $dataset->is_live(1);
    $dataset->store();

    return {'dataset_name' => $dataset->name,
        'dataset_id' =>$dataset->sp_dataset_id
    };
}

sub get_dataset_obj {
    my $self = shift;
    # my $sp_dataset_id = shift;

    my $dataset = CXGN::Dataset->new({
	       schema => $self->bcs_schema,
	       people_schema => $self->people_schema,
	});

    return $dataset;

}

sub create_dataset {
    my $self = shift;
    my $dataset_name = shift;

    my $protocol_id = $self->genotyping_protocol_id;
    my $dataset = $self->get_dataset_obj();

    $dataset->sp_person_id($self->user_id);

    $dataset->name($dataset_name);
    $dataset->genotyping_protocols([$protocol_id]);

    return $dataset;

}

sub get_dbh {
    my $self = shift;

    my $fixture = $self->get_fixture_obj();
    return  $fixture->dbh;

}

sub get_fixture_obj {
    my $self = shift;

    return $self->fixture;
    # return SGN::Test::Fixture->new();
}

sub people_schema {
    my $self = shift;

    my $fixture = $self->get_fixture_obj();
    return  $fixture->people_schema;

}

sub bcs_schema {
    my $self = shift;

    my $fixture = $self->get_fixture_obj();
    return  $fixture->bcs_schema;

}

sub trials_list {
    my $self = shift;

    my @trials;
    my $trials_ids = $self->trials_ids;

    foreach my $trial_id (@$trials_ids) {
        my $trial =  $self->get_trial_obj($trial_id);
        push @trials, $trial->name;
    }

    return \@trials;

}

sub accessions_list {
    my $self = shift;

    my $trial_id = $self->accessions_source_trial;

print STDERR "\naccessions_list: getting accessions from trial $trial_id\n";
    my $trial =  $self->get_trial_obj($trial_id);
    my $accessions = $trial->get_accessions();

    my $subset = $self->accessions_list_subset;

    if ($subset) {
        my @accs_subset = @$accessions[0..$subset-1];
        $accessions = \@accs_subset;
        print STDERR "\n subsetting $subset accessions  from trial: $trial_id\n";
    }

    return $accessions;

}

sub plots_list {
    my $self = shift;

    my $trial_id = $self->plots_source_trial;

    my $trial = $self->get_trial_obj($trial_id);
    my $plots =  $trial->get_plots();

    my $subset = $self->plots_list_subset;
    if ($subset) {
        my @plots_subset = @$plots[0..$subset-1];
        $plots = \@plots_subset;

        print STDERR "\n subsetting $subset plots from trial $trial_id\n";
    }

    return $plots;

}

sub get_trial_obj {
    my ($self, $trial_id) = @_;

    my $trial = CXGN::Trial->new({'bcs_schema' => $self->bcs_schema,
        'trial_id' => $trial_id}
        );

    return $trial;

}

sub get_plots_ids {
    my $self = shift;

    my $plots = $self->plots_list;

    my @plots_ids;
    foreach my $pl (@$plots){
        push @plots_ids, $pl->[0];
    }

    return \@plots_ids;

}

sub get_plots_names {
    my $self = shift;

    my $plots = $self->plots_list;

    my @plots_names;
    foreach my $pl (@$plots){
        push @plots_names, $pl->[1];
    }

    return \@plots_names;

}

sub get_accessions_ids {
    my $self = shift;

    my $accessions = $self->accessions_list;

    my @accessions_ids;
    foreach my $acc (@$accessions){
        push @accessions_ids, $acc->{stock_id};
    }

    return \@accessions_ids;

}

sub get_accessions_names {
    my $self = shift;

    my $accessions = $self->accessions_list;

    my @accessions_names;
    foreach my $acc (@$accessions){
        push @accessions_names, $acc->{accession_name};
    }

    return \@accessions_names;

}

sub site_cluster_shared_dir { 
    my $self = shift;

    my $tmp = $self->fixture->get_conf('cluster_shared_tempdir');
    my $host = $self->fixture->get_conf('main_production_site_url');

    $host    =~ s/(http?)|(:\d+)|\/|://g;
    $host    =~ s/(www\.)//;
    $host    = File::Spec->catdir($tmp, $host);
   
    return $host;

}
###
1;
###
