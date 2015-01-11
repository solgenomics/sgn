
package SGN::Controller::AJAX::BrAPI;

use Moose;
use JSON::Any;
use Data::Dumper;
use CXGN::BreedersToolbox::Projects;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    #default => 'text/javascript', # for jsonp
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    #map  => { 'text/javascript' => 'JSONP', 'text/html' => 'JSONP' },
   );

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
		      is => 'rw',
    );

sub brapi : Chained('/') PathPart('brapi') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $version = shift;
    $self->bcs_schema( $c->dbic_schema("Bio::Chado::Schema") );
    $c->stash->{api_version} = $version;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    
}

sub genotype : Chained('brapi') PathPart('genotype') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $id = shift;
    $c->stash->{genotype_id} = $id;
}

sub germplasm : Chained('brapi') PathPart('germplasm') CaptureArgs(0) { 
    my $self = shift;
    my $c = shift;
    
}

sub germplasm_find : Chained('germplasm') PathPart('find') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params();

    if (! $params->{q}) { 
	$c->stash->{rest} = { error => "No query provided" };
	return;
    }

    my $rs;

    if (! $params->{matchMethod} || $params->{matchMethod} eq "exact") { 
	$rs = $self->bcs_schema()
	->resultset("Stock::Stock")
	->search( { uniquename => { ilike => $params->{q} } });
    }
    elsif ($params->{matchMethod} eq "wildcard") { 
	$c->stash->{rest} = { error => "matchMethod 'wildcard' not yet implemented" };
	return;
    }
    else { 
	$c->stash->{rest} = { error => "matchMethod '$params->{matchMethod}' not recognized" };
	return;
    }

    my @results;

    foreach my $stock ($rs->all()) { 
	push @results, { queryName => $params->{q},
			 uniqueName => $stock->uniquename(),
			 germplasmId => $stock->stock_id(),
	};
    }

    $c->stash->{rest} = \@results;
}



sub genotype_count : Chained('genotype') PathPart('count') Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR "PROCESSING genotype/count...\n";

    my $rs = $self->genotype_rs($c);

    my @runs;
    foreach my $row ($rs->all()) { 
	my $genotype_json = $row->value();
	my $genotype = JSON::Any->decode($genotype_json);
	
	push @runs, { 
	    runId => $row->genotypeprop_id(),
	    analysisMethod => "null",
	    resultCount => scalar(keys(%$genotype)),
	};
    }
    my $response = {
	id => $c->stash->{genotype_id},
	markerCounts => \@runs
    };
    
    $c->stash->{rest} = $response;	
}

sub genotype_fetch : Chained('genotype') PathPart('') Args(0){ 
    my $self = shift;
    my $c = shift;

    my $rs = $self->genotype_rs($c);

    my $params = $c->req->params();

    my @runs = ();
    my $count = 0;
    foreach my $row ($rs->all()) { 
	my $genotype_json = $row->value();
	my $genotype = JSON::Any->decode($genotype_json);
	my %encoded_genotype = ();
	foreach my $m (sort keys %$genotype) { 
	    $count++;

	    if ($params->{page} && $params->{pageSize}) { 
		if ($count <= $params->{page} * $params->{pageSize} ||
		    $count > $params->{page} * $params->{pageSize} + $params->{pageSize}) { 
		    next;
		}
	    }
	    
	    if ($genotype->{$m} == 1) { 
		$encoded_genotype{$m} = "AA";
	    }
	    elsif ($genotype->{$m} == 0) { 
		$encoded_genotype{$m} = "BB";
	    }
	    elsif ($genotype->{$m} == 2) { 
		$encoded_genotype{$m} = "AB";
	    }
	    else { 
		$encoded_genotype{$m} = "NA";
	    }
	}
	push @runs, { data => \%encoded_genotype, runId => $row->genotypeprop_id() };
	
    }
    $c->stash->{rest} =  {
	germplasmId => $c->stash->{genotype_id},
	genotypes => \@runs,
    };

    if ($params->{page} && $params->{pageSize}) { 
	$c->stash->{rest}->{page} = $params->{page};
	$c->stash->{rest}->{pageSize} = $params->{pageSize};
    }
}

sub genotype_rs { 
    my $self = shift;
    my $c = shift;

    my $rs = $self->bcs_schema()->resultset("Stock::Stock")->search( { 'me.stock_id' => $c->stash->{genotype_id} })->search_related('nd_experiment_stocks')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops');

    return $rs;
}


sub study : Chained('brapi') PathPart('study') CaptureArgs(0) {
    my $self = shift;
    my $c = shift;


}

sub study_list : Chained('study') PathPart('list') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $program = $c->req->param("program");

    my $ps = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $programs = $ps -> get_breeding_programs();
    my $message;

    if ($program) { 
	my $program_info;
	foreach my $bp (@$programs) { 
	    if (uc($bp->[1]) eq uc($program)) { 
		$program_info = $bp;
	    }
	}
	if (!$program_info) { 
	    $message = "Program $program does not exist. Ignoring program parameter"; 
	}
	else { 
	    $programs = $program_info;
	}
    }
    
    my @response;
    foreach my $bp (@$programs) { 
	my $trial_data = {};
	my @trials = $ps->get_trials_by_breeding_program($bp->[0]);
	my @trial_ids = map { $_->[0] } @trials;
	print STDERR Dumper(\@trial_ids);
	foreach my $trial_id (@trial_ids) { 
	    print STDERR "TRIAL ID $trial_id\n";
	    my $t = CXGN::Trial->new( { trial_id => $trial_id->[0], bcs_schema => $c->dbic_schema("Bio::Chado::Schema") } );
	    
	    my $layout = CXGN::Trial::TrialLayout->new( { schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $bp->[0] });
	    
	    $trial_data->{studyId} = $t->get_trial_id();
	    $trial_data->{studyType} = $t->get_project_type()->[1];
	    $trial_data->{name} = $t->get_name();
	    $trial_data->{programName} = $t->get_breeding_program();
	    $trial_data->{keyContact} = "";
	    $trial_data->{locationName} = $t->get_location()->[1];
	    $trial_data->{designType} = $layout->get_design_type();
	    
	    push @response, $trial_data;
	}
    }

    $c->stash->{rest} =  \@response;

    # studyId: "1",
    # studyType: "NURSERY",
    # name: "Nursery XYZ",
    # objective: "Generate more seeds",
    # programName: "TCAP",
    # startDate: "2014-08-01",
    # keyContact: "Mr. Plant Breeder A",
    # locationName: "Ibadan",
    # designType: "RCBD"
}

sub study_detail : Chained('study') PathPart('detail') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $t = CXGN::Trial->new( {bcs_schema => $schema, trial_id => $trial_id });

    if (!$t) { 
	$c->stash->{rest} = { error => "The trial with id $trial_id does not exist" };
	return;
    }
    my $tl = CXGN::Trial::TrialLayout->new( { schema => $schema, trial_id=>$trial_id });

    my $design = $tl->get_design();
    
    my $plot_data = [];
    my $formatted_plot = {};
    
    # print STDERR Dumper($design);

    foreach my $plot_number (keys %$design) { 
	$formatted_plot = { 
	    plotId => $design->{$plot_number}->{plot_name},
	    blockId => $design->{$plot_number}->{block_number} ? $design->{$plot_number}->{block_number} : undef,
	    rowId => $design->{$plot_number}->{row_number} ? $design->{$plot_number}->{row_number} : undef,
	    columnId => $design->{$plot_number}->{col_number},
	    replication => $design->{$plot_number}->{replicate} ? 1 : 0,
	    checkId => $design->{$plot_number}->{is_a_control} ? 1 : 0,
	    lineId => $design->{$plot_number}->{stock_id},
	    lineRecord_Name => $design->{$plot_number}->{accession_name},
	};

	push @$plot_data, $formatted_plot;
	# plotId: "11",
	# blockId: "1",
	# rowId: "20",
	# columnId: "22",
	# replication: "1",
	# checkId: "0",
	# lineId: "143",
	# lineRecordName: "ZIPA_68"
	
    }
    
    my $data = { studyId => $t->get_trial_id(),
		 studyType => $t->get_project_type() ? $t->get_project_type()->[1] : "trial",
		 objective => "",
		 startDate => "",
		 keyContact => "",
		 locationName => $t->get_location() ? $t->get_location()->[1] : undef,
		 designType => $tl->get_design_type(),
		 designDetails => $plot_data,
    };

    $c->stash->{rest} = $data;

    # studyId: "1",
    #  studyType: "trial",
    #  name: "Fieldbook A",
    #  objective: "Generate seeds",
    #  startDate: "2014-08-01",
    #  keyContact: "Mr. Plant Breeder",
    #  locationName: "Ibadan",
    #  designType: "RCBD",
    #  designDetails: [ 
    #      { 
    # 	plotId: "11",
    # 	blockId: "1",
    # 	rowId: "20",
    # 	columnId: "22",
    # 	replication: "1",
    # 	checkId: "0",
    # 	lineId: "143",
    # 	lineRecordName: "ZIPA_68"
    #      }, ...
    #    ]

}

sub traits :  Chained('brapi') PathPart('traits') CaptureArgs(0) {
    my $self = shift;
    my $c = shift;
    



}

sub traits_list : Chained('traits') PathPart('list') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $db_rs = $self->bcs_schema()->resultset("General::Db")->search( { name => $c->config->{trait_ontology_db_name} } );
    if ($db_rs->count ==0) { return undef; }
    my $db_id = $db_rs->first()->db_id();
    
    my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, cvtermprop.value, dbxref.accession FROM cvterm LEFT JOIN cvtermprop using(cvterm_id) JOIN dbxref USING(dbxref_id) WHERE dbxref.db_id=?";
    my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
    $h->execute($db_id);

    my $traits = [];
    while (my ($cvterm_id, $name, $description, $scale, $accession) = $h->fetchrow_array()) { 
	push @$traits, { uid => $cvterm_id, name => $name, method => $description, unit => "", scale => $scale, accession => $accession };
    }

    $c->stash->{rest} = { traits => $traits };
}

sub specific_traits_list : Chained('traits') PathPart('') Args(1) { 
    my $self = shift;
    my $c = shift;

    $c->res->body("IT WORKS");

}

1;
