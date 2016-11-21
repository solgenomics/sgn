
package CXGN::Dataset;

use Moose;
use Moose::Util::TypeConstraints;
use JSON::Any;
use CXGN::BreederSearch;
use CXGN::People::Schema;


has 'people_schema' => (isa => 'CXGN::People::Schema',  is => 'rw', required => 1 );

has 'schema' =>       ( isa => "Bio::Chado::Schema", is => 'rw', required => 1 );

has 'sp_dataset_id' => ( isa => 'Int', 
			 is => 'rw',
			 predicate => 'has_sp_dataset_id',
    );

has 'data' => ( isa => 'Str', is => 'rw');

has 'description' => ( isa => 'Str', is => 'rw');

has 'accessions' =>  ( isa => 'ArrayRef', 
		       is => 'rw',
		       predicate => 'has_accessions',
    );

has 'plots' =>       ( isa => 'ArrayRef', 
		       is => 'rw',
		       predicate => 'has_plots',
    );

has 'trials' =>      ( isa => 'ArrayRef', 
		       is => 'rw',
		       predicate => 'has_trials',
    );

has 'traits' =>      ( isa => 'ArrayRef', 
		       is => 'rw',
		       predicate => 'has_traits',
    );

has 'years' =>       ( isa => 'ArrayRef', 
		       is => 'rw',
		       predicate => 'has_years',
    );

has 'breeding_programs' => ( isa => 'ArrayRef', 
			     is => 'rw',
			     predicate => 'has_breeding_programs',
    );

has 'is_live' =>     ( isa => 'Bool', 
		       is => 'rw',
		       default => 0,
    );

has 'data_level' =>  ( isa => 'String',
		       is => 'rw',
		       isa => enum([qw[ plots plants ]]),
		       default => 'plots',
    );

has 'breeder_search' => (isa => 'CXGN::BreederSearch', is => 'rw');

sub BUILD { 
    my $self = shift;
    
    if ($self->sp_dataset_id()) { 
	my $row = $self->schema()->resultset("SpDataset")->find({ sp_dataset_id => $self->sp_dataset_id() });
	
	my $dataset = JSON::Any->decode($row->dataset());
	
	$self->data($dataset);
	$self->name($dataset->{name});
	$self->description($dataset->{description});
	$self->accessions($dataset->{accessions});
	$self->plots($dataset->{plots});
	$self->trials($dataset->{trials});
	$self->traits($dataset->{traits});
	$self->years($dataset->{years});
	$self->breeding_programs($dataset->{breeding_programs});
	$self->is_live($dataset->{is_live});
    }
    
    my $bs = CXGN::BreederSearch->new(dbh => $self->schema->storage->dbh());
    $self->breeder_search($bs);

}

sub datasets_by_person { 
    my $class = shift;
    my $sgn_schema = shift;
    my $sp_person_id = shift;

    my $rs = $sgn_schema->resultset("SpDataset")->search( { sp_person_id => $sp_person_id });

    my @datasets;
    while (my $row = $rs->next()) { 
	push @datasets, $row->sp_dataset_id(), $row->name();
    }

    return \@datasets;
}    

sub store { 
    my $self = shift;
 
    my $json = JSON::Any->encode($self->_get_dataref());
   
    my $data = { name => $self->name(), 
		 description => $self->description(),
		 dataset => $json,
	};
    if ($self->sp_dataset_id()) { 
	my $row = $self->schema()->resultset("SpDataset")->create($data);
	$self->sp_dataset_id($row->sp_dataset_id());
    }
    else { 
	my $row = $self->schema()->resultset("SpDataset")->find( sp_dataset_id => $self->sp_dataset_id());
	$row->name($self->name());
	$row->description($self->description());
	$row->dataset($json);
	$row->update();
    }
}
    
sub _get_dataref { 
    my $self = shift;
 
    my $dataref = 
	[ 
	  $self->accessions(), 
	  $self->plots(), 
	  $self->trials(), 
	  $self->traits(), 
	  $self->years(), 
	  $self->breeding_programs() 
	];

    return $dataref;
}

sub retrieve_genotypes { 
    my $self = shift;

    my $criteria = $self->_get_criteria();
    push @$criteria, "genotypes";
    $self->breeder_search()->metadata_query($criteria, $self->get_dataref());
						
}

sub retrieve_phenotypes { 
    my $self = shift;
    my $phenotypes_search = CXGN::Phenotypes::Search->new({
        bcs_schema => $self->schema(),
        trait_list => $self->traits(),
        trial_list => $self->trials(),
        accession_list => $self->accessions(),
        data_level => $self->datalevel(),
    });

}

sub retrieve_accessions { 
    my $self = shift;
    if ($self->has_accessions()) { 
	return $self->accessions();
    }
    else {
	my $criteria = $self->_get_criteria();
	push @$criteria, "accessions";
	$self->breeder_search()->metadata_query($criteria, $self->get_dataref());
						
    }
}

sub retrieve_plots { 

}

sub retrieve_trials { 
    my $self = shift;
    if ($self->has_trials()) { 
	return $self->trials();
    }
    else {
	my $criteria = $self->_get_criteria();
	push @$criteria, "trials";
	$self->breeder_search()->metadata_query($criteria, $self->_get_dataref());						
    }
}


sub retrieve_traits { 

}

sub retrieve_years { 


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
