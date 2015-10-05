
package SGN::Controller::AJAX::BrAPI;

use Moose;
use JSON::Any;
use Data::Dumper;

use POSIX;
use CXGN::BreedersToolbox::Projects;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Chado::Stock;
use CXGN::Login;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
		      is => 'rw',
    );

my $DEFAULT_PAGE_SIZE=500;


sub brapi : Chained('/') PathPart('brapi') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $version = shift;

    $c->stash->{current_page} = $c->req->param("page") || 1;
    $c->stash->{page_size} = $c->req->param("pageSize");

    $self->bcs_schema( $c->dbic_schema("Bio::Chado::Schema") );
    $c->stash->{api_version} = $version;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );

}

sub authenticate_token : Chained('brapi') PathPart('token') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $dbh = $c->dbc->dbh;
    my $login_controller = CXGN::Login->new($dbh);
    
    my $grant_type = $c->req->param("grant_type");
    my $username = $c->req->param("username");
    my $password = $c->req->param("password");
    my $client_id = $c->req->param("client_id");

    my @status;
    my $cookie = '';

    if ( $login_controller->login_allowed() ) {
	if ($grant_type eq 'password') {
	    my $login_info = $login_controller->login_user( $username, $password );
	    if ($login_info->{account_disabled}) {
		push(@status, 'Account Disabled');
	    }
	    if ($login_info->{incorrect_password}) {
		push(@status, 'Incorrect Password');
	    }
	    if ($login_info->{duplicate_cookie_string}) {
		push(@status, 'Duplicate Cookie String');
	    }
	    if ($login_info->{logins_disabled}) {
		push(@status, 'Logins Disabled');
	    }
	    if ($login_info->{person_id}) {
		$cookie = $login_info->{cookie_string};
		push(@status, 'OK');
	    }
	} else {
	    push(@status, 'Grant Type Not Supported');
	}
    } else {
	push(@status, 'Login Not Allowed');
    }
    
    my %result = (status=>\@status, session_token=>$cookie);
    
    $c->stash->{rest} = \%result;
}

sub germplasm_all : Chained('brapi') PathPart('germplasm') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $type_id = $self->bcs_schema()->resultset("Cv::Cvterm")->find( { name => "accession" })->cvterm_id();
    my $rs = $self->bcs_schema()->resultset("Stock::Stock")->search( { type_id => $type_id });

    my @result;
    
    while (my $stock = $rs->next()) { 
	# to do: needs to be expanded according to api...
	push @result, { germplasmId => $stock->stock_id(), germplasmName => $stock->uniquename() };
    }
    
    $c->stash->{rest} = \@result;
}

=head2 brapi/v1/germplasm/{id}

 Usage:
 Desc:
 Return JSON example:
    {
"germplasmId": 382, "germplasmName": "MOREX", "synonyms": [ "M25", "CIHO15773" ], "taxonId": 3,
"breedingProgramId": 18
}
 Args:
 Side Effects:
 Example:

=cut

sub germplasm : Chained('brapi') PathPart('germplasm') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;    
    my $stock_id = shift;

    $c->stash->{stock_id} = $stock_id;
    my $g = CXGN::Chado::Stock->new($self->bcs_schema(), $stock_id);
    $c->stash->{stock} = $g;
}

sub germplasm_detail : Chained('germplasm') PathPart('') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    # need to implement get_synonyms... ####my @synonyms = $c->stash->{stock}->get_synonyms();
    my $stock_data = { 
	germplasmId => $c->stash->{stock}->get_stock_id(),
	germplasmName => $c->stash->{stock}->get_uniquename(),
	#synonyms => \@synonyms,
    };

    $c->stash->{rest} = $stock_data;
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

sub markerprofiles_all : Chained('brapi') PathPart('markerprofiles') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $method = $c->req->param("methodId");
    
    my $rs = $self->bcs_schema()->resultset("Genetic::Genotypeprop")->search( {} );
    my @genotypes;
    while (my $gt = $rs->next()) { 
	push @genotypes, { markerprofileId => $gt->genotypeprop_id };
    }
    $c->stash->{rest} = \@genotypes;
}

sub markerprofiles : Chained('brapi') PathPart('markerprofiles') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $id = shift;
    $c->stash->{markerprofile_id} = $id; # this is genotypeprop_id
}

sub markerprofile_count : Chained('markerprofiles') PathPart('count') Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR "PROCESSING genotype/count...\n";

    my $rs = $self->markerprofile_rs($c);

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
	id => $c->stash->{markerprofile_id},
	markerCounts => \@runs
    };
    
    $c->stash->{rest} = $response;	
}

sub genotype_fetch : Chained('markerprofiles') PathPart('') Args(0){ 
    my $self = shift;
    my $c = shift;

    print STDERR "Markerprofile_fetch\n";
    my $rs = $self->markerprofile_rs($c);

    my $params = $c->req->params();

    my @runs = ();
    my $count = 0;
    foreach my $row ($rs->all()) { 
	my $genotype_json = $row->value();
	my $genotype = JSON::Any->decode($genotype_json);
	my %encoded_genotype = ();
	foreach my $m (sort genosort keys %$genotype) { 
	    $count++;

	    if ($params->{page} && $params->{pageSize}) { 
		if ($count <= $params->{page} * $params->{pageSize} ||
		    $count > $params->{page} * $params->{pageSize} + $params->{pageSize}) { 
		    next;
		}
	    }

	    $encoded_genotype{$m} = $self->convert_dosage_to_genotype($genotype->{$m});
	}
	push @runs, { data => \%encoded_genotype, runId => $row->genotypeprop_id() };
    }
    my $total_pages;
    my $total_count;
    $c->stash->{rest} =  {

	pagination => { 
	    page => $c->stash->{current_page},
	    pageSize => $c->stash->{page_size} || $DEFAULT_PAGE_SIZE,
	    totalPages => $total_pages, 
	    totalCount => $total_count 
	},
	germplasmId => $c->stash->{markerprofile_id},
	genotypes => \@runs,
    };

}

sub markerprofiles_methods : Chained('brapi') PathPart('markerprofiles/methods') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { } );
    my @response;
    while (my $row = $rs->next()) { 
	push @response, [ $row->nd_protocol_id(), $row->name() ];
    }
    $c->stash->{rest} = \@response;

}


sub genosort { 
    my ($a_chr, $a_pos, $b_chr, $b_pos);
    if ($a =~ m/S(\d+)\_(.*)/) { 
	$a_chr = $1;
	$a_pos = $2;
    }
    if ($b =~ m/S(\d+)\_(.*)/) { 
	$b_chr = $1;
	$b_pos = $2;
    }
    
    if ($a_chr == $b_chr) { 
	return $a_pos <=> $b_pos;
    }
    return $a_chr <=> $b_chr;
}
    

sub convert_dosage_to_genotype { 
    my $self = shift;
    my $dosage = shift;

    my $genotype;
    if ($dosage eq "NA") { 
	return "NA";
    }
    if ($dosage == 1) { 
	return "AA";
    }
    elsif ($dosage == 0) { 
	return "BB";
    }
    elsif ($dosage == 2) { 
	return "AB";
    }
    else { 
	return "NA";
    }
}


sub markerprofile_rs { 
    my $self = shift;
    my $c = shift;

#    my $rs = $self->bcs_schema()->resultset("Stock::Stock")->search( { 'me.stock_id' => $c->stash->{genotype_id} })->search_related('nd_experiment_stocks')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops');
    
    my $rs = $self->bcs_schema()->resultset("Genetic::Genotypeprop")->search( { genotypeprop_id => $c->stash->{markerprofile_id} });
    
    return $rs;
}

sub allelematrix : Chained('brapi') PathPart('allelematrix') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $markerprofile_ids = $c->req->param("markerprofileIds");

    my @profile_ids = split ",", $markerprofile_ids;

    my $rs = $self->bcs_schema()->resultset("Genetic::Genotypeprop")->search( { genotypeprop_id => { -in => \@profile_ids }});
    
    my %scores;
    my $total_pages;
    my $total_count;
    my @marker_score_lines;
    my @ordered_refmarkers;

    if ($rs->count() > 0) { 
	my $profile_json = $rs->first()->value();
	my $refmarkers = JSON::Any->decode($profile_json);

	print STDERR Dumper($refmarkers);
	
	@ordered_refmarkers = sort genosort keys(%$refmarkers);

	print Dumper(\@ordered_refmarkers);

	$total_count = scalar(@ordered_refmarkers);
	
	if ($c->stash->{page_size}) { 
	    $total_pages = ceil($total_count / $c->stash->{page_size});
	}
	else { 
	    $total_pages = 1;
	    $c->stash->{page_size} = $total_count;
	}

	while (my $profile = $rs->next()) { 
	    foreach my $m (@ordered_refmarkers) { 
		my $markers_json = $profile->value();
		my $markers = JSON::Any->decode($markers_json);

		$scores{$profile->genotypeprop_id()}->{$m} = 
		    $self->convert_dosage_to_genotype($markers->{$m});
	    }   
	}
    }
    my @lines;
    foreach my $line (keys %scores) { 
	push @lines, $line;
    }

    my %markers_by_line;

    for (my $n = $c->stash->{page_size} * ($c->stash->{current_page}-1); $n< ($c->stash->{page_size} * ($c->stash->{current_page})); $n++) {

	my $m = $ordered_refmarkers[$n];
	foreach my $line (keys %scores) { 
	    push @{$markers_by_line{$m}}, $scores{$line}->{$m};
	    push @marker_score_lines, { $m => \@{$markers_by_line{$m}} };
	}
    }
    
    $c->stash->{rest} = { 
	metadata => { 
	    pagination => { 
		pageSize => $c->stash->{page_size},
		currentPage => $c->stash->{current_page},
		totalPages => $total_pages, 
		totalCount => $total_count 
	    },
		    status => [],
	},
		    markerprofileIds => \@lines,
		    scores => \@marker_score_lines,
    };
    
}


sub studies : Chained('brapi') PathPart('studies') CaptureArgs(0) {
    my $self = shift;
    my $c = shift;


}

sub study_list : Chained('studies') PathPart('list') Args(0) { 
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
	    
	    my $layout = CXGN::Trial::TrialLayout->new( 
		{ 
		    schema => $c->dbic_schema("Bio::Chado::Schema"), 
		    trial_id => $bp->[0] 
		});

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


    $c->stash->{rest} = \@response;

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


sub study_detail : Chained('studies') PathPart('detail') Args(1) { 

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

sub maps : Chained('brapi') PathPart('maps') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $map_id = shift;

    $c->stash->{map_id} = $map_id;
}

sub maps_detail : Chained('maps') PathPart('') Args(0) { 
    my $self = shift;
    my $c = shift;

    # maps are just marker lists associated with specific protocols
    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { } );
    my %map_info;
    while (my $row = $rs->next()) { 
	print STDERR "Retrieving map info for ".$row->name()."\n";
	my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProtocol")->search( { nd_protocol_id => $row->nd_protocol_id() })->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops');
	
	my $lg_row = $lg_rs->first();

	print STDERR "LG RS COUNT = ".$lg_rs->count()."\n";

	if (!$lg_row) { 
	    die "This was never supposed to happen :-(";
	}

	my $scores;
	if ($lg_row) { 
	    $scores = JSON::Any->decode($lg_row->value());
	}
	my %chrs;

	foreach my $m (sort genosort (keys %$scores)) { 
	    my ($chr, $pos) = split "_", $m;
	    print STDERR "CHR: $chr. POS: $pos\n";
	    $chrs{$chr} = $pos;
	}

	%map_info = (
	    mapId =>  $row->nd_protocol_id(), 
	    name => $row->name(), 
	    type => "physical", 
	    unit => "bp",
	    linkageGroupCount => scalar(keys %chrs),
	    publishedDate => undef,
	    comments => "",
	    );
    }
    $c->stash->{rest} = \%map_info;
    

}

sub maps_summary : Chained('brapi') PathPart('maps') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { } );

    my %map_info;
    while (my $row = $rs->next()) { 
	print STDERR "Retrieving map info for ".$row->name()."\n";
	my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { })->search_related('nd_experiment_protocols')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops');
	
	my $lg_row = $lg_rs->first();

	print STDERR "LG RS COUNT = ".$lg_rs->count()."\n";

	if (!$lg_row) { 
	    die "This was never supposed to happen :-(";
	}

	my $scores;
	if ($lg_row) { 
	    $scores = JSON::Any->decode($lg_row->value());
	}
	my %chrs;

	my $marker_count =0;
	my $lg_count = 0;
	foreach my $m (sort genosort (keys %$scores)) { 
	    my ($chr, $pos) = split "_", $m;
	    print STDERR "CHR: $chr. POS: $pos\n";
	    $chrs{$chr} = $pos;
	    $marker_count++;
	    $lg_count = scalar(keys(%chrs));
	}

	%map_info = (
	    mapId =>  $row->nd_protocol_id(), 
	    name => $row->name(), 
	    type => "physical", 
	    unit => "bp",
	    linkageGroupCount => $marker_count,
	    publishedDate => undef,
	    comments => "",
	    linkageGroups => $lg_count,
	    );
    }
    $c->stash->{rest} = \%map_info;

    
}


sub maps_marker_detail : Chained('maps') PathPart('positions') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { nd_protocol_id => $c->stash->{map_id} } );

    my @markers;
    while (my $row = $rs->next()) { 
	print STDERR "Retrieving map info for ".$row->name()."\n";
	my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { 'me.nd_protocol_id' => $c->stash->{map_id}  })->search_related('nd_experiment_protocols')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops');
	
	my $lg_row = $lg_rs->first();
	
	print STDERR "LG RS COUNT = ".$lg_rs->count()."\n";
	
	if (!$lg_row) { 
	    die "This was never supposed to happen :-(";
	}
	
	my $scores;
	if ($lg_row) { 
	    $scores = JSON::Any->decode($lg_row->value());
	}
	my %chrs;

	foreach my $m (sort genosort (keys %$scores)) { 
	    my ($chr, $pos) = split "_", $m;
	    print STDERR "CHR: $chr. POS: $pos\n";
	    $chrs{$chr} = $pos;
	# "markerId": 1,
	#"markerName": "marker1",
        #        "location": "1000",
        #        "linkageGroup": "1A"
	    push @markers, { markerId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
	}
    }
    $c->stash->{rest} = { markers => \@markers };	
}

sub authenticate : Chained('brapi') PathPart('authenticate/oauth') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    $c->res->redirect("https://accounts.google.com/o/oauth2/auth?scope=profile&response_type=code&client_id=1068256137120-62dvk8sncnbglglrmiroms0f5d7lg111.apps.googleusercontent.com&redirect_uri=https://cassavabase.org/oauth2callback");

    $c->stash->{rest} = { success => 1 };


}


1;
