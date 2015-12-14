
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
use Data::Dumper;

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
    
    my $person_id=CXGN::Login->new($c->dbc->dbh)->has_session();
    if (!$person_id) {
	$c->res->redirect("/solpeople/login.pl");
    }

    $c->stash->{current_page} = $c->req->param("page") || 1;
    $c->stash->{page_size} = $c->req->param("pageSize") || $DEFAULT_PAGE_SIZE;

    $self->bcs_schema( $c->dbic_schema("Bio::Chado::Schema") );
    $c->stash->{api_version} = $version;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );

}

=head2 /brapi/v1/token?grant_type=password&username=USERNAME&password=PASSWORD&client_id=CLIENT_ID

 Usage: For logging a user in through the API http://docs.brapi.apiary.io/#authentication
 Desc:
 Return JSON example:
{
    "metadata": {
        "pagination" : {},
        "status" : []
        },
    "session_token": "R6gKDBRxM4HLj6eGi4u5HkQjYoIBTPfvtZzUD8TUzg4"
} 
 Args:
 Side Effects:

=cut

sub authenticate_token : Chained('brapi') PathPart('token') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $login_controller = CXGN::Login->new($c->dbc->dbh);
    my $params = $c->req->params();

    my @status;
    my $cookie = '';

    if ( $login_controller->login_allowed() ) {
	if ($params->{grant_type} eq 'password' || !$params->{grant_type}) {
	    my $login_info = $login_controller->login_user( $params->{username}, $params->{password} );
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
		push(@status, 'Login Successfull');
		$cookie = $login_info->{cookie_string};
	    }
	} else {
	    push(@status, 'Grant Type Not Supported. Valid grant type: password');
	}
    } else {
	push(@status, 'Login Not Allowed');
    }
    my %pagination = ();
    my %metadata = (pagination=>\%pagination, status=>\@status);
    my %result = (metadata=>\%metadata, session_token=>$cookie);
    
    $c->stash->{rest} = \%result;
}

sub pagination_response {
    my $data_count = shift;
    my $page_size = shift;
    my $page = shift;
    my $total_pages_decimal = $data_count/$page_size;
    my $total_pages = ($total_pages_decimal == int $total_pages_decimal) ? $total_pages_decimal : int($total_pages_decimal + 1);
    my %pagination = (pageSize=>$page_size, currentPage=>$page, totalCount=>$data_count, totalPages=>$total_pages);
    return \%pagination;
}


=head2 brapi/v1/germplasm?name=*Mo?re%&matchMethod=wildcard&include=&pageSize=1000&page=10

 Usage: For searching a germplasm by name. Allows for exact and wildcard match methods. http://docs.brapi.apiary.io/#germplasm
 Desc:
 Return JSON example:
{    
    "metadata": {
        "pagination": {
            "pageSize": 1000,
            "currentPage": 10,
            "totalCount": 27338,
            "totalPages": 28
        },
        "status": []
    },
    "result" : { 
        "data": [
            { 
                "germplasmDbId": "382",
                "defaultDisplayName": "Pahang",
                "germplasmName": "Pahang",
                "accessionNumber": "ITC0609",
                "germplasmPUI": "http://www.crop-diversity.org/mgis/accession/01BEL084609",
                "pedigree": "TOBA97/SW90.1057",
                "seedSource": "",
                "synonyms": ["01BEL084609"],
            },
            {
                "germplasmDbId": "394",
                "defaultDisplayName": "Pahang",
                "germplasmName": "Pahang",
                "accessionNumber": "ITC0727",
                "germplasmPUI": "http://www.crop-diversity.org/mgis/accession/01BEL084727",
                "pedigree": "TOBA97/SW90.1057",
                "seedSource": "",
                "synonyms": [ "01BEL084727"],
            }
        ]
    }
}    
 Args:
 Side Effects:

=cut

sub germplasm_synonyms {
    my $schema = shift;
    my $stock_id = shift;
    my $synonym_id = shift;
    my @synonyms;
    my $rsp = $schema->resultset("Stock::Stockprop")->search({type_id => $synonym_id, stock_id=>$stock_id });
    while (my $stockprop = $rsp->next()) { 
	push( @synonyms, $stockprop->value() );
    }
    return \@synonyms;
}

sub germplasm_pedigree_string {
    my $schema = shift;
    my $stock_id = shift;
    my $s = CXGN::Chado::Stock->new($schema, $stock_id);
    my $pedigree_root = $s->get_parents('1');
    my $pedigree_string = $pedigree_root->get_pedigree_string('1');
    return $pedigree_string;
}

sub germplasm_search : Chained('brapi') PathPart('germplasm') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $params = $c->req->params();
    
    my @status;
    if ($params->{include}) {
	push (@status, 'include not implemented');
    }
    my $rs;
    my $total_count = 0;
    my %result;
    my $type_id = $self->bcs_schema()->resultset("Cv::Cvterm")->find( { name => "accession" })->cvterm_id();

    if (!$params->{name}) {
	$rs = $self->bcs_schema()->resultset("Stock::Stock")->search( {type_id=>$type_id}, { '+select'=> ['stock_id', 'name', 'uniquename'], '+as'=> ['stock_id', 'name', 'uniquename'], order_by=>{ -asc=>'stock_id' } } );
    } else {
	if (!$params->{matchMethod} || $params->{matchMethod} eq "exact") { 
	    $rs = $self->bcs_schema()->resultset("Stock::Stock")->search( {type_id=>$type_id, uniquename=>$params->{name} }, { '+select'=> ['stock_id', 'name', 'uniquename'], '+as'=> ['stock_id', 'name', 'uniquename'], order_by=>{ -asc=>'stock_id' } } );
	}
	elsif ($params->{matchMethod} eq "wildcard") { 
	    $params->{name} =~ tr/*?/%_/;
	    $rs = $self->bcs_schema()->resultset("Stock::Stock")->search( {type_id=>$type_id, uniquename=>{ ilike => $params->{name} } }, { '+select'=> ['stock_id', 'name', 'uniquename'], '+as'=> ['stock_id', 'name', 'uniquename'],  order_by=>{ -asc=>'stock_id' } } );
	}
	else { 
	    push(@status, "matchMethod '$params->{matchMethod}' not recognized. Allowed matchMethods: wildcard, exact. Wildcard allows % or * for multiple characters and ? for single characters.");
	} 
    }
    if ($rs) {
	my @data;
	$total_count = $rs->count();
	my $rs_slice = $rs->slice($c->stash->{page_size}*($c->stash->{current_page}-1), $c->stash->{page_size}*$c->stash->{current_page}-1);
	my $synonym_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => "synonym" })->cvterm_id();
	while (my $stock = $rs_slice->next()) { 
	    push @data, { germplasmDbId=>$stock->get_column('stock_id'), defaultDisplayName=>$stock->get_column('name'), germplasmName=>$stock->get_column('uniquename'), accessionNumber=>'', germplasmPUI=>'', pedigree=>germplasm_pedigree_string($self->bcs_schema(), $stock->get_column('stock_id')), seedSource=>'', synonyms=>germplasm_synonyms($self->bcs_schema(), $stock->get_column('stock_id'), $synonym_id) };
	}
	%result = (data => \@data);
    }

    my %metadata = (pagination=> pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}

=head2 brapi/v1/germplasm/{id}

 Usage: To retrieve details for a single germplasm
 Desc:
 Return JSON example:
{
    "metadata": {
        "status": [],
        "pagination": {}
    },
    "result": {
        "germplasmDbId": "01BEL084609",
        "defaultDisplayName": "Pahang",
        "germplasmName": "Pahang",
        "accessionNumber": "ITC0609",
        "germplasmPUI": "http://www.crop-diversity.org/mgis/accession/01BEL084609",
        "pedigree": "TOBA97/SW90.1057",
        "seedSource": "Female GID:4/Male GID:4",
        "synonyms": ["Pahanga","Pahange"],
    }
}
 Args:
 Side Effects:

=cut

sub germplasm : Chained('brapi') PathPart('germplasm') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;

    $c->stash->{stock_id} = $stock_id;
    $c->stash->{stock} = CXGN::Chado::Stock->new($self->bcs_schema(), $stock_id);
}

sub germplasm_detail : Chained('germplasm') PathPart('') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $rs = $c->stash->{stock};
    my $schema = $self->bcs_schema();

    my %result;
    my $synonym_id = $schema->resultset("Cv::Cvterm")->find( { name => "synonym" })->cvterm_id();

    %result = (germplasmDbId=>$c->stash->{stock_id}, defaultDisplayName=>$c->stash->{stock}->get_uniquename(), germplasmName=>$c->stash->{stock}->get_name(), accessionNumber=>'', germplasmPUI=>'', pedigree=>germplasm_pedigree_string($self->bcs_schema(), $c->stash->{stock_id}), seedSource=>'', synonyms=>germplasm_synonyms($schema, $c->stash->{stock_id}, $synonym_id));

    my @status;
    my %pagination;
    my %metadata = (pagination=>\%pagination, status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}

=head2 brapi/v1/germplasm/{id}/MCPD

 Usage: To retrieve multi crop passport descriptor for a single germplasm
 Desc:
 Return JSON example:
{
    "metadata": {
        "status": [],
        "pagination": {}
    },
    "result": {
                "germplasmDbId": "01BEL084609",
                "defaultDisplayName": "Pahang",
                "accessionNumber": "ITC0609",
                "germplasmName": "Pahang",
                "germplasmPUI": "http://www.crop-diversity.org/mgis/accession/01BEL084609",
                "pedigree": "TOBA97/SW90.1057",
                "germplasmSeedSource": "Female GID:4/Male GID:4",
                "synonyms": [ ],
                "commonCropName": "banana",
                "instituteCode": "01BEL084",
                "instituteName": "ITC",
                "biologicalStatusOfAccessionCode": 412,
                "countryOfOriginCode": "UNK",
                "typeOfGermplasmStorageCode": 10,
                "genus": "Musa",
                "species": "acuminata",
                "speciesAuthority": "",
                "subtaxa": "sp malaccensis var pahang",
                "subtaxaAuthority": "",
                "donors": 
                [
                    {
                        "donorAccessionNumber": "",
                        "donorInstituteCode": "",
                        "germplasmPUI": ""
                    }
                ],
                "acquisitionDate": "19470131"
}
 Args:
 Side Effects:

=cut

sub germplasm_mcpd : Chained('germplasm') PathPart('MCPD') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $schema = $self->bcs_schema();
    my %result;
    my @status;

    my $synonym_id = $schema->resultset("Cv::Cvterm")->find( { name => "synonym" })->cvterm_id();
    my $organism = CXGN::Chado::Organism->new( $schema, $c->stash->{stock}->get_organism_id() );

    %result = (germplasmDbId=>$c->stash->{stock_id}, defaultDisplayName=>$c->stash->{stock}->get_uniquename(), accessionNumber=>'', germplasmName=>$c->stash->{stock}->get_name(), germplasmPUI=>'', pedigree=>germplasm_pedigree_string($schema, $c->stash->{stock_id}), germplasmSeedSource=>'', synonyms=>germplasm_synonyms($schema, $c->stash->{stock_id}, $synonym_id), commonCropName=>$organism->get_common_name(), instituteCode=>'', instituteName=>'', biologicalStatusOfAccessionCode=>'', countryOfOriginCode=>'', typeOfGermplasmStorageCode=>'', genus=>$organism->get_genus(), species=>$organism->get_species(), speciesAuthority=>'', subtaxa=>$organism->get_taxon(), subtaxaAuthority=>'', donors=>'', acquisitionDate=>'');
    
    my %pagination;
    my %metadata = (pagination=>\%pagination, status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


=head2 brapi/v1/studies?programId=programId

 Usage: To retrieve studies
 Desc:
 Return JSON example:
        {
            "metadata": {
                "pagination": {
                    "pageSize": 2,
                    "currentPage": 1,
                    "totalCount": 100,
                    "totalPages": 50
                },
            "status" : []
            },
            "result": {
                "data": [ 
                    {
                        "studyDbId": 35,
                        "name": "Earlygenerationtesting",
                        "studyType": "Trial",
                        "years": ["2005", "2008"],
                        "locationDbId": 23,
                        "programDbId": 27,
                        "optionalInfo" : {
                            "studyPUI" : "PUI string",
                            "studyType": "Trial",
                            "startDate": "2015-06-01",
                            "endDate"  : "2015-12-31",
                        }
                    }
                    ,
                    {
                        "studyDbId": 345,
                        "name": "Earlygenerationtesting",
                        "seasons": ["2005", "2008"],
                        "locationDbId": 33,
                        "programDbId": 58,
                        "optionalInfo" : {
                            "studyPUI" : "PUI string",
                            "studyType": "Trial",
                            "startDate": "2015-06-01",
                            "endDate"  : "2015-12-31",
                        }
                    }
                ]
            }
        }        
 Args:
 Side Effects:

=cut


sub study_list : Chained('brapi') PathPart('studies') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $program = $c->req->param("programId");
    my @status;
    my @data;
    my %result;

    my $ps = CXGN::BreedersToolbox::Projects->new( { schema => $self->bcs_schema });
    my $programs = $ps -> get_breeding_programs();

    if ($program) { 
	my $program_info;
	foreach my $bp (@$programs) { 
	    if (uc($bp->[1]) eq uc($program)) { 
		$program_info = $bp;
	    }
	}
	if (!$program_info) { 
	    push @status, "ProgramId $program does not exist. Ignoring program parameter"; 
	}
	else { 
	    $programs = $program_info;
	}
    }
    
    my $total_count = 0;

    foreach my $bp (@$programs) { 
	my $trial_data = {};
	my @trials = $ps->get_trials_by_breeding_program($bp->[0]);
	my @trial_ids = map { $_->[0] } @trials;
	#print STDERR Dumper(\@trial_ids);
	print STDERR scalar(@trial_ids)."number ";
	foreach my $trial_id (@trial_ids) { 

	    if ($trial_id) {

		my $t = CXGN::Trial->new( { trial_id => $trial_id->[0], bcs_schema => $self->bcs_schema } );
	    
		my $layout = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $bp->[0] } );

		
		my @years = ($t->get_year());

		my %optional_info = (studyPUI=>'', startDate=>'', endDate=>'');
		push @data, {studyDbId=>$t->get_trial_id(), name=>$t->get_name(), studyType=>$t->get_project_type()->[1], years=>\@years, locationDbId=>$t->get_location()->[0], optionalInfo=>\%optional_info};
	    }
	}
    }

    %result = (data=>\@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


=head2 brapi/v1/studies/{studyId}/germplasm?pageSize=20&page=1 

 Usage: To retrieve all germplasm used in a study
 Desc: 
 Return JSON example:
{
    "metadata": {
        "status": [],
        "pagination": {
            "pageSize": 1000,
            "currentPage": 1,
            "totalCount": 1,
            "totalPages": 1
        }
    },
    "result": {
        "studyDbId": 123,
        "studyName": "myBestTrial",
        "data": [
            { 
                "germplasmDbId": "382",
                "trialEntryNumberId": "1",
                "defaultDisplayName": "Pahang",
                "germplasmName": "Pahang",
                "accessionNumber": "ITC0609",
                "germplasmPUI": "http://www.crop-diversity.org/mgis/accession/01BEL084609",
                "pedigree": "TOBA97/SW90.1057",
                "seedSource": "",
                "synonyms": ["01BEL084609"],
            },
            {
                "germplasmDbId": "394",
                "trialEntryNumberId": "2",
                "defaultDisplayName": "Pahang",
                "germplasmName": "Pahang",
                "accessionNumber": "ITC0727",
                "germplasmPUI": "http://www.crop-diversity.org/mgis/accession/01BEL084727",
                "pedigree": "TOBA97/SW90.1057",
                "seedSource": "",
                "synonyms": [ "01BEL084727"],
            }
        ]
    }
}
 Args: 
 Side Effects: 

=cut

sub studies : Chained('brapi') PathPart('studies') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $study_id = shift;

    $c->stash->{study_id} = $study_id;
    my $t = CXGN::Trial->new( { trial_id => $study_id, bcs_schema => $self->bcs_schema } );
    $c->stash->{study} = $t;
    $c->stash->{studyName} = $t->get_name();
}

sub studies_germplasm : Chained('studies') PathPart('germplasm') Args(0) { 
    my $self = shift;
    my $c = shift;
    my %result;
    my @status;
    my $total_count = 0;

    my $t = CXGN::Trial->new( { trial_id => $c->stash->{study_id}, bcs_schema => $self->bcs_schema } );
    my $rs = $t->_brapi_get_trial_accessions();

    if ($rs) {
	$total_count = $rs->count();
	my $rs_slice = $rs->slice($c->stash->{page_size}*($c->stash->{current_page}-1), $c->stash->{page_size}*$c->stash->{current_page}-1);
	my @data;
	my $synonym_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => "synonym" })->cvterm_id();
	while (my $s = $rs_slice->next()) { 
	    push @data, { germplasmDbId=>$s->get_column('stock_id'), studyEntryNumberId=>$s->get_column('study_entry_id'), defaultDisplayName=>$s->get_column('name'), germplasmName=>$s->get_column('uniquename'), accessionNumber=>'', germplasmPUI=>'', pedigree=>germplasm_pedigree_string($self->bcs_schema, $s->get_column('stock_id')), seedSource=>'', synonyms=>germplasm_synonyms($self->bcs_schema, $s->get_column('stock_id'), $synonym_id) };
	}
	%result = (studyDbId=>$c->stash->{study_id}, studyName=>$c->stash->{studyName}, data =>\@data);
    }

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


=head2 brapi/v1/germplasm/{id}/pedigree?notation=purdy

 Usage: To retrieve pedigree information for a single germplasm
 Desc:
 Return JSON example:
{
    "metadata": {
        "status": [],
        "pagination": {}
    },
    "result": {
        "germplasmDbId": "382",
        "pedigree": "TOBA97/SW90.1057",
        "parent1Id": "23",
        "parent2Id": "55"
    }
}
 Args:
 Side Effects:

=cut

sub germplasm_pedigree : Chained('germplasm') PathPart('pedigree') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $schema = $self->bcs_schema();
    my %result;
    my @status;

    if ($c->req->param('notation')) {
	push @status, 'notation not implemented';
	if ($c->req->param('notation') ne 'purdy') {
	    push @status, {code=>'ERR-1', message=>'Unsupported notation code.'};
	}
    }
    
    my $s = CXGN::Chado::Stock->new($schema, $c->stash->{stock_id});
    my @direct_parents = $s->get_direct_parents();

    %result = (germplasmDbId=>$c->stash->{stock_id}, pedigree=>germplasm_pedigree_string($schema, $c->stash->{stock_id}), parent1Id=>$direct_parents[0][0], parent2Id=>$direct_parents[1][0]);
    
    my %pagination;
    my %metadata = (pagination=>\%pagination, status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}

=head2 brapi/v1/germplasm/{id}/markerprofiles

 Usage: To retrieve markerprofile ids for a single germplasm
 Desc:
 Return JSON example:
{
    "metadata": {
        "status": [],
        "pagination": {}
    },
    "result": {
        "germplasmDbId": "382",
        "markerProfiles": [
	    "123",
	    "456"
	]
    }
}
 Args:
 Side Effects:

=cut

sub germplasm_markerprofile : Chained('germplasm') PathPart('markerprofiles') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $schema = $self->bcs_schema();
    my %result;
    my @status;
    my @marker_profiles;

    my $rs = $self->bcs_schema()->resultset("Stock::StockGenotype")->search( {stock_id=>$c->stash->{stock_id} } );
    my $mp;
    while (my $gt = $rs->next()) {
	$mp = $self->bcs_schema()->resultset("Genetic::Genotypeprop")->search( {genotype_id=>$gt->genotype_id} );
	while (my $gp = $mp->next()) {
	    push @marker_profiles, $gp->genotypeprop_id;
	}
    }
    %result = (germplasmDbId=>$c->stash->{stock_id}, markerProfiles=>\@marker_profiles);
    
    my %pagination;
    my %metadata = (pagination=>\%pagination, status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}

#
# Need to implement Germplasm Attributes
#


=head2 brapi/v1/markerprofiles?germplasm=germplasmDbId&extract=extractDbId&method=methodDbId

 Usage: To retrieve markerprofile ids for a single germplasm
 Desc:
 Return JSON example:
        {
            "metadata" : {
                "pagination": {
                    "pageSize": 10,
                    "currentPage": 1,
                    "totalCount": 10,
                    "totalPages": 1
                },
                "status": []
            },
            "result" : {
                "data" : [
                    {   
                        "markerProfileDbId": "993",
                        "germplasmDbId" : 2374,
                        "extractDbId" : 3939,
                        "analysisMethod": "GoldenGate",
                        "resultCount": 1470
                    },
                    {
                        "markerProfileDbId": "994",
                        "germplasmDbId" : 2374,
                        "extractDbId" : 3939,
                        "analysisMethod": "GBS",
                        "resultCount": 1470
                    }
                ]
            }
        }
 Args:
 Side Effects:

=cut


sub markerprofiles_search : Chained('brapi') PathPart('markerprofiles') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $germplasm = $c->req->param("germplasm");
    my $extract = $c->req->param("extract");
    my $method = $c->req->param("method");
    my @status;
    my @data;
    my %result;
    
    my $rs; 
    if ($germplasm && $method) {
	$rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search(
	    {'stock.stock_id'=>$germplasm, 'nd_protocol.nd_protocol_id'=>$method},
	    {join=> [{'nd_experiment_genotypes' => {'genotype' => 'genotypeprops'} }, {'nd_experiment_protocols' => 'nd_protocol' }, {'nd_experiment_stocks' => 'stock'} ],
	     '+select'=> ['genotypeprops.genotypeprop_id', 'genotypeprops.value', 'nd_protocol.name', 'stock.stock_id'], 
	     '+as'=> ['genotypeprop_id', 'value', 'protocol_name', 'stock_id'],
	     order_by=>{ -asc=>'genotypeprops.genotypeprop_id' }
	    }
	);
    }
    if ($germplasm && !$method) {
	$rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search(
	    {'stock.stock_id'=>$germplasm},
	    {join=> [{'nd_experiment_genotypes' => {'genotype' => 'genotypeprops'} }, {'nd_experiment_protocols' => 'nd_protocol' }, {'nd_experiment_stocks' => 'stock'} ],
	     '+select'=> ['genotypeprops.genotypeprop_id', 'genotypeprops.value', 'nd_protocol.name', 'stock.stock_id'], 
	     '+as'=> ['genotypeprop_id', 'value', 'protocol_name', 'stock_id'],
	     order_by=>{ -asc=>'genotypeprops.genotypeprop_id' }
	    }
	);
    }
    if (!$germplasm && $method) {
	$rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search(
	    {'nd_protocol.nd_protocol_id'=>$method},
	    {join=> [{'nd_experiment_genotypes' => {'genotype' => 'genotypeprops'} }, {'nd_experiment_protocols' => 'nd_protocol' }, {'nd_experiment_stocks' => 'stock'} ],
	     '+select'=> ['genotypeprops.genotypeprop_id', 'genotypeprops.value', 'nd_protocol.name', 'stock.stock_id'], 
	     '+as'=> ['genotypeprop_id', 'value', 'protocol_name', 'stock_id'],
	     order_by=>{ -asc=>'genotypeprops.genotypeprop_id' }
	    }
	);
    }
    if (!$germplasm && !$method) {
	$rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search(
	    {},
	    {join=> [{'nd_experiment_genotypes' => {'genotype' => 'genotypeprops'} }, {'nd_experiment_protocols' => 'nd_protocol' }, {'nd_experiment_stocks' => 'stock'} ],
	     '+select'=> ['genotypeprops.genotypeprop_id', 'genotypeprops.value', 'nd_protocol.name', 'stock.stock_id'], 
	     '+as'=> ['genotypeprop_id', 'value', 'protocol_name', 'stock_id'],
	     order_by=>{ -asc=>'genotypeprops.genotypeprop_id' }
	    }
	);
    }
    
    if ($extract) {
	push @status, 'Extract not supported';
    }

    my $total_count = 0;

    if ($rs) {
	$total_count = $rs->count();
	my $rs_slice = $rs->slice($c->stash->{page_size}*($c->stash->{current_page}-1), $c->stash->{page_size}*$c->stash->{current_page}-1);
        my @runs;
	foreach my $row ($rs_slice->all()) { 
	    my $genotype_json = $row->get_column('value');
	    my $genotype = JSON::Any->decode($genotype_json);
	
	    push @data, {markerProfileDbId => $row->get_column('genotypeprop_id'), germplasmDbId => $row->get_column('stock_id'), extractDbId => "", analysisMethod => $row->get_column('protocol_name'), resultCount => scalar(keys(%$genotype)) };
	}
    }

    %result = (data => \@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


=head2 brapi/v1/markerprofiles/markerprofilesDbId

 Usage: To retrieve data for a single markerprofile
 Desc:
 Return JSON example:
        {
            "metadata" : {
                "pagination": {
                    "pageSize": 10,
                    "currentPage": 1,
                    "totalCount": 10,
                    "totalPages": 1
                },
                "status": []
            },
        
            "result": {
                "germplasmDbId": 993,
                "extractDbId" : 38383, 
                "markerprofileDbId": 37484,
                "analysisMethod": "GBS-Pst1",
                "encoding": "AA,BB,AB",
                "data" : [ { "marker1": "AA" }, { "marker2":"AB" }, ... ]
           }
        }
 Args:
 Side Effects:

=cut

sub markerprofiles : Chained('brapi') PathPart('markerprofiles') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $id = shift;
    $c->stash->{markerprofile_id} = $id; # this is genotypeprop_id
}


sub genotype_fetch : Chained('markerprofiles') PathPart('') Args(0){ 
    my $self = shift;
    my $c = shift;
    my @status;
    my @data;
    my %result;

    my $total_count = 0; 
    my $rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search(
	{'genotypeprops.genotypeprop_id' => $c->stash->{markerprofile_id} },
	{join=> [{'nd_experiment_genotypes' => {'genotype' => 'genotypeprops'} }, {'nd_experiment_protocols' => 'nd_protocol' }, {'nd_experiment_stocks' => 'stock'} ],
	 '+select'=> ['genotypeprops.value', 'nd_protocol.name', 'stock.stock_id'], 
	 '+as'=> ['value', 'protocol_name', 'stock_id'],
	 order_by=>{ -asc=>'genotypeprops.genotypeprop_id' }
	}
    );

    if ($rs) {
	$total_count = $rs->count();
	foreach my $row ($rs->all()) { 
	    
	    my $genotype_json = $row->get_column('value');
	    my $genotype = JSON::Any->decode($genotype_json);
	    foreach my $m (sort genosort keys %$genotype) { 
		push @data, { $m=>$self->convert_dosage_to_genotype($genotype->{$m}) };
	    }

	    %result = (germplasmDbId=>$row->get_column('stock_id'), extractDbId=>'', markerprofileDbId=>$c->stash->{markerprofile_id}, analysisMethod=>$row->get_column('protocol_name'), encoding=>"AA,BB,AB", data => \@data);
	}
    }

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
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


=head2 brapi/v1/allelematrix?markerprofileDbId=100&markerprofileDbId=101

 Usage: Gives a matrix data structure for a given list of markerprofileDbIds
 Desc:
 Return JSON example:
         {
            "metadata": {   
                "status": [],
                "pagination": {
                    "pageSize": 100,
                    "currentPage": 1,
                    "totalCount": 1,
                    "totalPages": 1
                }
            },
            "result" : {
                "makerprofileDbIds": ["markerprofileId1","markerprofileId2","markerprofileId3"],
                "data" : [ 
                    { "markerId1":["AB","AA","AA"] },
                    { "markerId2":["AA","AB","AA"] },
                    { "markerId3":["AB","AB","BB"] }
                ]
            }
        }
 Args:
 Side Effects:

=cut

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


=head2 brapi/v1/programs

 Usage: To retrieve a list of programs being worked on
 Desc:
 Return JSON example:
        {
            "metadata" : {
                "pagination": {
                    "pageSize": 10,
                    "currentPage": 1,
                    "totalCount": 10,
                    "totalPages": 1
                },
                "status": []
            },
            "result" : {
                "data" : [
                    {
                        "programDbid": "123",
                        "name": "Wheat Resistance Program",
                        "objective" : "Disease resistance",
                        "leadPerson" : "Dr. Henry Beachell"
                    },
                    {
                        "programDbId": "456",
                        "name": "Wheat Improvement Program",
                        "objective" : "Yield improvement",
                        "leadPerson" : "Dr. Norman Borlaug"
                    }
                ]
            }
        }
 Args:
 Side Effects:

=cut

sub programs_list : Chained('brapi') PathPart('programs') Args(0) { 
    my $self = shift;
    my $c = shift;
    my @status;
    my %result;
    my @data;

    my $ps = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $programs = $ps -> get_breeding_programs();
    my $total_count = scalar(@$programs);

    foreach my $bp (@$programs) {
	push @data, {programDbId=>$bp->[0], name=>$bp->[1], objective=>$bp->[2], leadPerson=>''};
    }

    %result = (data=>\@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


=head2 brapi/v1/studyTypes

 Usage: To retrieve a list of programs being worked onthe various study types
 Desc:
 Return JSON example:
        {
             "metadata" : {
                "pagination": {
                    "pageSize": 10,
                    "currentPage": 1,
                    "totalCount": 10,
                    "totalPages": 1
                },
                "status": []
            },
            "result" : {
                "data" : [
                    {
                        "name": "Nursery",
                        "description": "Description for Nursery study type"
                    },
                    {
                        "name": "Trial",
                        "description": "Description for Nursery study type"
                    }
                ]
            }
        }
 Args:
 Side Effects:

=cut

sub studies_types : Chained('brapi') PathPart('studyTypes') Args(0) { 
    my $self = shift;
    my $c = shift;
    my %result;
    my @status;
    my $total_count = 0;

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}

sub studies_instances : Chained('studies') PathPart('instances') Args(0) { 
    my $self = shift;
    my $c = shift;
    my %result;
    my @status;
    my $total_count = 0;

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}

sub studies_info : Chained('studies') PathPart('') Args(0) { 
    my $self = shift;
    my $c = shift;
    my %result;
    my @status;
    my $total_count = 0;

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}

sub studies_details : Chained('studies') PathPart('details') Args(0) { 
    my $self = shift;
    my $c = shift;
    my %result;
    my @status;
    my $total_count = 0;

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
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
    # 	replication: "15d23e60851bfbf98c5d7d33465d4e6b2704de261",
    # 	checkId: "0",
    # 	lineId: "143",
    # 	lineRecordName: "ZIPA_68"
    #      }, ...
    #    ]

}

sub traits :  Chained('brapi') PathPart('traits') Args(0) {
    my $self = shift;
    my $c = shift;
    my @status;

    #my $db_rs = $self->bcs_schema()->resultset("General::Db")->search( { name => $c->config->{trait_ontology_db_name} } );
    #if ($db_rs->count ==0) { return undef; }
    #my $db_id = $db_rs->first()->db_id();
    
    #my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, cvtermprop.value, dbxref.accession FROM cvterm LEFT JOIN cvtermprop using(cvterm_id) JOIN dbxref USING(dbxref_id) WHERE dbxref.db_id=?";
    #my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
    #$h->execute($db_id);

    my $q = "SELECT cvterm_id, name FROM materialized_traits;";
    my $p = $self->bcs_schema()->storage->dbh()->prepare($q);
    $p->execute();

    my @data;
    while (my ($cvterm_id, $name) = $p->fetchrow_array()) { 
	my $q2 = "SELECT cvterm.definition, cvtermprop.value, dbxref.accession FROM cvterm LEFT JOIN cvtermprop using(cvterm_id) JOIN dbxref USING(dbxref_id) WHERE cvterm.cvterm_id=?";
	my $h = $self->bcs_schema()->storage->dbh()->prepare($q2);
	$h->execute($cvterm_id);
    
	while (my ($description, $scale, $accession) = $h->fetchrow_array()) { 
	    my @observation_vars = ();
	    push (@observation_vars, ($name, $accession)); 
	    push @data, { traitDbId => $cvterm_id, traitId => $name, name => $name, description => $description, observationVariables => \@observation_vars, defaultValue => '', scale =>$scale };
	}
    }

    my $total_count = $p->rows;
    my %result = (data => \@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;

}

#sub specific_traits_list : Chained('traits') PathPart('') Args(1) { 
#    my $self = shift;
#    my $c = shift;

#    $c->res->body("IT WORKS");

#}

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
