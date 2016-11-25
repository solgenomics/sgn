
package CXGN::Dataset;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use JSON::Any;
use CXGN::BreederSearch;
use CXGN::People::Schema;
use CXGN::Phenotypes::Search;
use CXGN::Genotype::Search;

has 'people_schema' => (isa => 'CXGN::People::Schema',  is => 'rw', required => 1 );

has 'schema' =>       ( isa => "Bio::Chado::Schema", is => 'rw', required => 1 );

has 'sp_dataset_id' => ( isa => 'Int', 
			 is => 'rw',
			 predicate => 'has_sp_dataset_id',
    );

has 'data' =>        ( isa => 'HashRef', 
		       is => 'rw'
    );

has 'name' =>        ( isa => 'Maybe[Str]',
		       is => 'rw',
    );

has 'description' => ( isa => 'Maybe[Str]', 
		       is => 'rw'
    );

has 'accessions' =>  ( isa => 'Maybe[ArrayRef]', 
		       is => 'rw',
		       predicate => 'has_accessions',
    );

has 'plots' =>       ( isa => 'Maybe[ArrayRef]', 
		       is => 'rw',
		       predicate => 'has_plots',
    );

has 'trials' =>      ( isa => 'Maybe[ArrayRef]', 
		       is => 'rw',
		       predicate => 'has_trials',
    );

has 'traits' =>      ( isa => 'Maybe[ArrayRef]', 
		       is => 'rw',
		       predicate => 'has_traits',
    );

has 'years' =>       ( isa => 'Maybe[ArrayRef]', 
		       is => 'rw',
		       predicate => 'has_years',
    );

has 'breeding_programs' => ( isa => 'Maybe[ArrayRef]', 
			     is => 'rw',
			     predicate => 'has_breeding_programs',
    );

has 'is_live' =>     ( isa => 'Bool', 
		       is => 'rw',
		       default => 0,
    );

has 'data_level' =>  ( isa => 'String',
		       is => 'rw',
		       isa => enum([qw[ plot plant ]]),
		       default => 'plot',
    );

has 'breeder_search' => (isa => 'CXGN::BreederSearch', is => 'rw');


sub BUILD { 
    my $self = shift;
    
    print STDERR "Processing dataset_id ".$self->sp_dataset_id()."\n";
    if ($self->has_sp_dataset_id()) { 
	my $row = $self->people_schema()->resultset("SpDataset")->find({ sp_dataset_id => $self->sp_dataset_id() });
	
	my $dataset = JSON::Any->decode($row->dataset());
	$self->data($dataset);
	$self->name($row->name());
	$self->description($row->description());
	$self->accessions($dataset->{accessions});
	$self->plots($dataset->{plots});
	$self->trials($dataset->{trials});
	$self->traits($dataset->{traits});
	$self->years($dataset->{years});
	$self->breeding_programs($dataset->{breeding_programs});
	$self->is_live($dataset->{is_live});
    }
    else { print STDERR "Creating empty dataset object\n"; }
    my $bs = CXGN::BreederSearch->new(dbh => $self->schema->storage->dbh());
    $self->breeder_search($bs);

}

sub datasets_by_person { 
    my $class = shift;
    my $people_schema = shift;
    my $sp_person_id = shift;

    my $rs = $people_schema->resultset("SpDataset")->search( { sp_person_id => $sp_person_id });

    my @datasets;
    while (my $row = $rs->next()) { 
	push @datasets, $row->sp_dataset_id(), $row->name();
    }

    return \@datasets;
}    

sub store { 
    my $self = shift;

    my $dataref;
    $dataref->{accessions} = $self->accessions() if $self->has_accessions();
    $dataref->{plots} = $self->plots() if $self->has_plots();
    $dataref->{trials} = $self->trials() if $self->has_trials();
    $dataref->{traits} = $self->traits() if $self->has_traits();
    $dataref->{years} = $self->years() if $self->has_years();
    $dataref->{breeding_programs} = $self->breeding_programs() if $self->has_breeding_programs();
    
    my $json = JSON::Any->encode($dataref);
   
    my $data = { name => $self->name(), 
		 description => $self->description(),
		 dataset => $json,
	};

    print STDERR "dataset_id = ".$self->sp_dataset_id()."\n";
    if (!$self->has_sp_dataset_id()) { 
	print STDERR "Creating new dataset row... ".$self->sp_dataset_id()."\n";
	my $row = $self->people_schema()->resultset("SpDataset")->create($data);
	$self->sp_dataset_id($row->sp_dataset_id());
	return $row->sp_dataset_id();
    }
    else { 
	print STDERR "Updating dataset row ".$self->sp_dataset_id()."\n";
	my $row = $self->people_schema()->resultset("SpDataset")->find( { sp_dataset_id => $self->sp_dataset_id() });
	if ($row) { 
	    $row->name($self->name());
	    $row->description($self->description());
	    $row->dataset($json);
	    $row->update();
	    return $row->sp_dataset_id();
	}
	else { 
	    print STDERR "Weird... has ".$self->sp_dataset_id()." but no data in db\n";
	}
    }
}

sub _get_dataref { 
    my $self = shift;
     my $dataref;
    
    $dataref->{accessions} = join(",", @{$self->accessions()}) if $self->has_accessions();
    $dataref->{plots} = join(",", @{$self->plots()}) if $self->has_plots();
    $dataref->{trials} = join(",", @{$self->trials()}) if $self->has_trials();
    $dataref->{traits} = join(",", @{$self->traits()}) if $self->has_traits();
    $dataref->{years} = join(",", @{$self->years()}) if $self->has_years();
    $dataref->{breeding_programs} = join(",", @{$self->breeding_programs()}) if $self->has_breeding_programs();
    return $dataref;
}
    
sub _get_source_dataref { 
    my $self = shift;
    my $source_type = shift;

    my $dataref;
    
    $dataref->{$source_type} = $self->_get_dataref();
    
    return $dataref;
}

sub retrieve_genotypes { 
    my $self = shift;
    my $protocol_id = shift;

    my $genotypes_search = CXGN::Genotype::Search->new(
	bcs_schema => $self->schema(),
	accession_list => $self->accessions(),
	trial_list => $self->trials(),
	protocol_id => $protocol_id
	); 
    my $resultset = $genotypes_search->get_genotype_info(); 
    my $genotypes = $resultset->{genotypes};	
}

sub retrieve_phenotypes { 
    my $self = shift;
    my $phenotypes_search = CXGN::Phenotypes::Search->new({
        bcs_schema => $self->schema(),
        trait_list => $self->traits(),
        trial_list => $self->trials(),
        accession_list => $self->accessions(),
        data_level => $self->data_level(),
    });

    my @data =
	$phenotypes_search->get_extended_phenotype_info_matrix();

    return \@data;

}

sub retrieve_accessions { 
    my $self = shift;
    my $accessions;
    if ($self->has_accessions()) { 
	return $self->accessions();
    }
    else {
	my $criteria = $self->_get_criteria();
	push @$criteria, "accessions";
	$accessions = $self->breeder_search()->metadata_query(undef, $criteria, $self->_get_source_dataref("accessions"));						
    }
    return $accessions->{results};
}

sub retrieve_plots { 
    my $self = shift;
    my $plots;
    if ($self->has_plots()) { 
	return $self->plots();
    }
    else {
	my $criteria = $self->_get_criteria();
	push @$criteria, "plots";
	$plots = $self->breeder_search()->metadata_query(undef, $criteria, $self->_get_source_dataref("plots"));						
    }
    return $plots->{results};
}

sub retrieve_trials { 
    my $self = shift;
    my $trials;
    if ($self->has_trials()) { 
	return $self->trials();
    }
    else {
	my $criteria = $self->_get_criteria();
	push @$criteria, "trials";
	$trials = $self->breeder_search()->metadata_query(undef, $criteria, $self->_get_source_dataref("trials"));						
    }
    print STDERR "TRIALS: ".Dumper($trials);
    return $trials->{results};
}


sub retrieve_traits { 
    my $self = shift;
    my $traits;
    if ($self->has_traits()) { 
	return $self->traits();
    }
    else {
	my $criteria = $self->_get_criteria();
	push @$criteria, "traits";
	$traits = $self->breeder_search()->metadata_query(undef, $criteria, $self->_get_source_dataref("traits"));						
    }
    return $traits->{results};

}

sub retrieve_years { 
    my $self = shift;
    my @years;
    if ($self->has_years()) { 
	return $self->years();
    }
    else {
	my $criteria = $self->_get_criteria();
	push @$criteria, "years";
	my $year_data = $self->breeder_search()->metadata_query(undef, $criteria, $self->_get_source_dataref("years"));
	my $year_list = $year_data->{result};

	foreach my $y (@$year_list) { 
	    push @years, $y->[0];
	}
    }
    return \@years;
}

sub _get_criteria { 
    my $self = shift;
    my @criteria;

    if ($self->has_accessions()) { 
	push @criteria, "accessions";
    }
    if ($self->has_plots()) { 
	push @criteria, "plots";
    }
    if ($self->has_trials()) { 
	push @criteria, "trials";
    }
    if ($self->has_traits()) { 
	push @criteria, "traits";
    }
    if ($self->has_years()) { 
	push @criteria, "years";
    }

    return \@criteria;

}


1;
