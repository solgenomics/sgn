
package SGN::Controller::AJAX::BrAPI;

use Moose;
use JSON::Any;
use Data::Dumper;

use POSIX;
use CXGN::BreedersToolbox::Projects;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Stock;
use CXGN::Login;
use CXGN::BreederSearch;
use Data::Dumper qw(Dumper);
use CXGN::GenotypeProtocol;
use List::MoreUtils qw(uniq);
use CXGN::Trial::TrialCreate;
use CXGN::Trial::Search;
use CXGN::Location::LocationLookup;
use JSON qw( decode_json );
use Data::Dumper;
use Try::Tiny;
use File::Slurp qw | read_file |;
use Spreadsheet::WriteExcel;
use Time::Piece;

use CXGN::BrAPI;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
	default   => 'application/json',
	stash_key => 'rest',
	map       => { 'application/json' => 'JSON' },
);

has 'brapi_module' => (
	isa => 'CXGN::BrAPI',
	is => 'rw',
);

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
);

my $DEFAULT_PAGE_SIZE=10;

sub brapi : Chained('/') PathPart('brapi') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $version = shift;
	my @status;

	my $page = $c->req->param("page") || 0;
	my $page_size = $c->req->param("pageSize") || $DEFAULT_PAGE_SIZE;
	my $session_token = $c->req->param("session_token");
	my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
	my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
	my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
	my $people_schema = $c->dbic_schema("CXGN::People::Schema");
	push @status, { 'info' => "BrAPI base call found with page=$page, pageSize=$page_size" };

	my $brapi = CXGN::BrAPI->new({
		version => $version,
		brapi_module_inst => {
			bcs_schema => $bcs_schema,
			metadata_schema => $metadata_schema,
			phenome_schema => $phenome_schema,
			people_schema => $people_schema,
			page_size => $page_size,
			page => $page,
			status => \@status
		}
	});
	$self->brapi_module($brapi);
	$self->bcs_schema($bcs_schema);

	$c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
	$c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
	$c->stash->{session_token} = $session_token;

	$c->stash->{clean_inputs} = _clean_inputs($c->req->params);
}

#useful because javascript can pass 'undef' as an empty value, and also standardizes all inputs as arrayrefs
sub _clean_inputs {
	no warnings 'uninitialized';
	my $params = shift;
	foreach (keys %$params){
		my $values = $params->{$_};
		my $ret_val;
		if (ref \$values eq 'SCALAR'){
			push @$ret_val, $values;
		} elsif (ref $values eq 'ARRAY'){
			$ret_val = $values;
		} else {
			die "Input is not a scalar or an arrayref\n";
		}
		@$ret_val = grep {$_ ne undef} @$ret_val;
		@$ret_val = grep {$_ ne ''} @$ret_val;
        $_ =~ s/\[\]$//; #ajax POST with arrays adds [] to the end of the name e.g. germplasmName[]. since all inputs are arrays now we can remove the [].
		$params->{$_} = $ret_val;
	}
	return $params;
}

sub _authenticate_user {
	my $c = shift;
	my $status = $c->stash->{status};

	my ($person_id, $user_type, $user_pref, $expired) = CXGN::Login->new($c->dbc->dbh)->query_from_cookie($c->stash->{session_token});
	#print STDERR $person_id." : ".$user_type." : ".$expired;

	if (!$person_id || $expired || $user_type ne 'curator') {
		$status->{'message'} = 'You must login and have permission to access this BrAPI call.';
		my %metadata = (status=>$status);
		$c->stash->{rest} = \%metadata;
		$c->detach;
	}

	return 1;
}

sub _standard_response_construction {
	my $c = shift;
	my $brapi_package_result = shift;
	my $status = $brapi_package_result->{status};
	my $pagination = $brapi_package_result->{pagination};
	my $result = $brapi_package_result->{result};
	my $datafiles = $brapi_package_result->{datafiles};

	my %metadata = (pagination=>$pagination, status=>$status, datafiles=>$datafiles);
	my %response = (metadata=>\%metadata, result=>$result);
	$c->stash->{rest} = \%response;
}

=head2 /brapi/v1/token

 Usage: For logging a user in and loggin a user out through the API
 Desc:

For Logging In
POST Request:
{
 "grant_type" : "password", //(optional, text, `password`) ... The grant type, only allowed value is password, but can be ignored
 "username" : "user38", // (required, text, `thepoweruser`) ... The username
 "password" : "secretpw", // (optional, text, `mylittlesecret`) ... The password
 "client_id" : "blabla" // (optional, text, `blabla`) ... The client id, currently ignored.
}

POST Response:
 {
   "metadata": {
     "pagination": {},
     "status": {},
     "datafiles": []
   },
   "userDisplayName": "John Smith",
   "access_token": "R6gKDBRxM4HLj6eGi4u5HkQjYoIBTPfvtZzUD8TUzg4",
   "expires_in": "The lifetime in seconds of the access token"
 }

For Logging out
DELETE Request:

{
    "access_token" : "R6gKDBRxM4HLj6eGi4u5HkQjYoIBTPfvtZzUD8TUzg4" // (optional, text, `R6gKDBRxM4HLj6eGi4u5HkQjYoIBTPfvtZzUD8TUzg4`) ... The user access token. Default: current user token.
}

DELETE Response:
{
    "metadata": {
            "pagination" : {},
            "status" : { "message" : "User has been logged out successfully."},
            "datafiles": []
        }
    "result" : {}
}

=cut

sub authenticate_token : Chained('brapi') PathPart('token') Args(0) : ActionClass('REST') { }

sub authenticate_token_DELETE {
	my $self = shift;
	my $c = shift;
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Authentication');
	my $brapi_package_result = $brapi_module->logout();
	_standard_response_construction($c, $brapi_package_result);
}

#sub authenticate_token_GET {
#    my $self = shift;
#    my $c = shift;
#    process_authenticate_token($self,$c);
#}

sub authenticate_token_POST {
	my $self = shift;
	my $c = shift;
	process_authenticate_token($self,$c);
}

sub process_authenticate_token {
	my $self = shift;
	my $c = shift;
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Authentication');
	my $brapi_package_result = $brapi_module->login(
		$clean_inputs->{grant_type}->[0],
		$clean_inputs->{password}->[0],
		$clean_inputs->{username}->[0],
		$clean_inputs->{client_id}->[0],
	);
	my $status = $brapi_package_result->{status};
	my $pagination = $brapi_package_result->{pagination};
	my $result = $brapi_package_result->{result};
	my $datafiles = $brapi_package_result->{datafiles};

	my $first_name = $result->{first_name};
	my $last_name = $result->{last_name};
	my $cookie = $result->{cookie};
	my %metadata = (pagination=>$pagination, status=>$status, datafiles=>$datafiles);
	my %response = (metadata=>\%metadata, access_token=>$cookie, userDisplayName=>"$first_name $last_name", expires_in=>$CXGN::Login::LOGIN_TIMEOUT);
	$c->stash->{rest} = \%response;
}

=head2 /brapi/v1/calls

 Usage: For determining which calls have been implemented and with which datafile types and methods
 Desc:

 GET Request:

 GET Response:
{
  "metadata": {
    "pagination": {
      "pageSize": 3,
      "currentPage": 0,
      "totalCount": 3,
      "totalPages": 1
    },
    "status": {},
    "datafiles": []
  },
  "result": {
    "data": [
      {
        "call": "allelematrix",
        "datatypes": [
          "json",
          "tsv"
        ],
        "methods": [
          "GET",
          "POST"
        ]
      },
      {
        "call": "germplasm/id/mcpd",
        "datatypes": [
          "json"
        ],
        "methods": [
          "GET"
        ]
      },
      {
        "call": "doesntexistyet",
        "datatypes": [
          "png",
          "jpg"
        ],
        "methods": [
          "GET"
        ]
      }
    ]
  }
}

=cut

sub calls : Chained('brapi') PathPart('calls') Args(0) : ActionClass('REST') { }

sub calls_GET {
	my $self = shift;
	my $c = shift;
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Calls');
	my $brapi_package_result = $brapi_module->calls(
		$clean_inputs->{datatype}->[0],
	);
	_standard_response_construction($c, $brapi_package_result);
}

sub crops : Chained('brapi') PathPart('crops') Args(0) : ActionClass('REST') { }

sub crops_GET {
	my $self = shift;
	my $c = shift;
	my $supported_crop = $c->config->{'supportedCrop'};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Crops');
	my $brapi_package_result = $brapi_module->crops($supported_crop);
	_standard_response_construction($c, $brapi_package_result);
}

sub observation_levels : Chained('brapi') PathPart('observationLevels') Args(0) : ActionClass('REST') { }

sub observation_levels_GET {
	my $self = shift;
	my $c = shift;
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
	my $brapi_package_result = $brapi_module->observation_levels();
	_standard_response_construction($c, $brapi_package_result);
}

sub seasons : Chained('brapi') PathPart('seasons') Args(0) : ActionClass('REST') { }

sub seasons_POST {
	my $self = shift;
	my $c = shift;
	seasons_process($self, $c);
}

sub seasons_GET {
	my $self = shift;
	my $c = shift;
	seasons_process($self, $c);
}

sub seasons_process {
	my $self = shift;
	my $c = shift;
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->seasons();
	_standard_response_construction($c, $brapi_package_result);
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

sub study_types : Chained('brapi') PathPart('studyTypes') Args(0) : ActionClass('REST') { }

sub study_types_POST {
	my $self = shift;
	my $c = shift;
	study_types_process($self, $c);
}

sub study_types_GET {
	my $self = shift;
	my $c = shift;
	study_types_process($self, $c);
}

sub study_types_process {
	my $self = shift;
	my $c = shift;
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->study_types();
	_standard_response_construction($c, $brapi_package_result);
}




=head2 /brapi/v1/germplasm-search?germplasmName=&germplasmGenus=&germplasmSubTaxa=&germplasmDbId&germplasmPUI=http://data.inra.fr/accession/234Col342&germplasmSpecies=Triticum&panel=diversitypanel1&collection=none&pageSize=pageSize&page=page

 Usage: For searching a germplasm by name. Allows for exact and wildcard match methods. http://docs.brapi.apiary.io/#germplasm
 Desc:

 POST Request:

{
    "germplasmPUI" : "http://...", // (optional, text, `http://data.inra.fr/accession/234Col342`) ... The name or synonym of external genebank accession identifier
    "germplasmDbId" : 986, // (optional, text, `986`) ... The name or synonym of external genebank accession identifier
    "germplasmSpecies" : "tomato", // (optional, text, `aestivum`) ... The name or synonym of genus or species ( merge with below ?)
    "germplasmGenus" : "Solanum lycopersicum", //(optional, text, `Triticum, Hordeum`) ... The name or synonym of genus or species
    "germplasmName" : "XYZ1", // (optional, text, `Triticum, Hordeum`) ... The name or synonym of the accession
    "accessionNumber" : "ITC1234" // optional
    "pageSize" : 100, // (optional, integer, `1000`) ... The size of the pages to be returned. Default is `1000`.
    "page":  1 (optional, integer, `10`) ... Which result page is requested
}


POST Response:
{
    "metadata": {
        "status": {},
        "datafiles": [],
        "pagination": {
        "pageSize": 10,
        "currentPage": 1,
        "totalCount": 2,
        "totalPages": 1
        }
    },
    "result": {
        "data":[
            {
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
        ]
    }
}

=cut

sub germplasm_list  : Chained('brapi') PathPart('germplasm-search') Args(0) : ActionClass('REST') { }

sub germplasm_list_GET {
	my $self = shift;
	my $c = shift;
	germplasm_search_process($self, $c);
}

sub germplasm_list_POST {
	my $self = shift;
	my $c = shift;
	germplasm_search_process($self, $c);
}

sub germplasm_search_process {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Germplasm');
	my $brapi_package_result = $brapi_module->germplasm_search({
		germplasmName => $clean_inputs->{germplasmName},
		accessionNumber => $clean_inputs->{accessionNumber},
		germplasmGenus => $clean_inputs->{germplasmGenus},
		germplasmSubTaxa => $clean_inputs->{germplasmSubTaxa},
		germplasmSpecies => $clean_inputs->{germplasmSpecies},
		germplasmDbId => $clean_inputs->{germplasmDbId},
		germplasmPUI => $clean_inputs->{germplasmPUI},
		matchMethod => $clean_inputs->{matchMethod},
	});
	_standard_response_construction($c, $brapi_package_result);
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

sub germplasm_single  : Chained('brapi') PathPart('germplasm') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $stock_id = shift;

	$c->stash->{stock_id} = $stock_id;
}


sub germplasm_detail  : Chained('germplasm_single') PathPart('') Args(0) : ActionClass('REST') { }

sub germplasm_detail_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub germplasm_detail_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Germplasm');
	my $brapi_package_result = $brapi_module->germplasm_detail(
		$c->stash->{stock_id}
	);
	_standard_response_construction($c, $brapi_package_result);
}

=head2 brapi/v1/germplasm/{id}/MCPD

MCPD CALL NO LONGER IN BRAPI SPEC

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

#sub germplasm_mcpd  : Chained('germplasm_single') PathPart('MCPD') Args(0) : ActionClass('REST') { }

#sub germplasm_mcpd_POST {
#    my $self = shift;
#    my $c = shift;
#    my $auth = _authenticate_user($c);
#    my $status = $c->stash->{status};

#    $c->stash->{rest} = {status=>$status};
#}

#sub germplasm_mcpd_GET {
#    my $self = shift;
#    my $c = shift;
#    #my $auth = _authenticate_user($c);
#    my $schema = $self->bcs_schema();
#    my %result;
#    my $status = $c->stash->{status};

#    my $synonym_id = $schema->resultset("Cv::Cvterm")->find( { name => "synonym" })->cvterm_id();
#    my $organism = CXGN::Chado::Organism->new( $schema, $c->stash->{stock}->get_organism_id() );

#    %result = (germplasmDbId=>$c->stash->{stock_id}, defaultDisplayName=>$c->stash->{stock}->get_uniquename(), accessionNumber=>$c->stash->{stock}->get_uniquename(), germplasmName=>$c->stash->{stock}->get_name(), germplasmPUI=>$c->stash->{stock}->get_uniquename(), pedigree=>germplasm_pedigree_string($schema, $c->stash->{stock_id}), germplasmSeedSource=>'', synonyms=>germplasm_synonyms($schema, $c->stash->{stock_id}, $synonym_id), commonCropName=>$organism->get_common_name(), instituteCode=>'', instituteName=>'', biologicalStatusOfAccessionCode=>'', countryOfOriginCode=>'', typeOfGermplasmStorageCode=>'', genus=>$organism->get_genus(), species=>$organism->get_species(), speciesAuthority=>'', subtaxa=>$organism->get_taxon(), subtaxaAuthority=>'', donors=>'', acquisitionDate=>'');

#    my %pagination;
#    my %metadata = (pagination=>\%pagination, status=>$status);
#    my %response = (metadata=>\%metadata, result=>\%result);
#    $c->stash->{rest} = \%response;
#}


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

sub studies_search  : Chained('brapi') PathPart('studies-search') Args(0) : ActionClass('REST') { }

#sub studies_list_POST {
#    my $self = shift;
#    my $c = shift;
#    my $auth = _authenticate_user($c);
#    my $status = $c->stash->{status};
#    my $message = '';

#    my $study_name = $c->req->param('studyName');
#    my $location_id = $c->req->param('locationDbId');
#    my $years = $c->req->param('studyYears');
#    my $program_id = $c->req->param('programDbId');
#    my $optional_info = $c->req->param('optionalInfo');
#
#    my $description;
#    my $study_type;
#    if ($optional_info) {
#        my $opt_info_hash = decode_json($optional_info);
#        $description = $opt_info_hash->{"studyObjective"};
#        $study_type = $opt_info_hash->{"studyType"};
#    }

#    my $program_obj = CXGN::BreedersToolbox::Projects->new({schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') });
#    my $programs = $program_obj->get_breeding_programs();
#    my $program_check;
#    my $program_name;
#    foreach (@$programs) {
#        if ($_->[0] == $program_id) {
#            $program_check = 1;
#            $program_name = $_->[1];
#        }
#    }
#    if (!$program_check) {
#        $message .= "Program not found with programDbId = ".$program_id;
#        $status->{'message'} = $message;
#        $c->stash->{rest} = {status => $status };
#        $c->detach();
#    }

#    my $locations = $program_obj->get_all_locations();
#    my $location_check;
#    my $location_name;
#    foreach (@$locations) {
#        if ($_->[0] == $location_id) {
#            $location_check = 1;
#            $location_name = $_->[1];
#        }
#    }
#    if (!$location_check) {
#        $message .= "Location not found with locationDbId = ".$location_id;
#        $status->{'message'} = $message;
#        $c->stash->{rest} = {status => $status };
#        $c->detach();
#    }

#    my $trial_design;
#    my $trial_create = CXGN::Trial::TrialCreate->new({
#        dbh => $c->dbc->dbh,
#        chado_schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'),
#        metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
#        phenome_schema => $c->dbic_schema("CXGN::Phenome::Schema"),
#        user_name => $c->user()->get_object()->get_username(), #not implemented
#        program => $program_name,
#        trial_year => $years,
#        trial_description => $description,
#        design_type => $study_type,
#        trial_location => $location_name,
#        trial_name => $study_name,
#        design => $trial_design,
#    });

#    if ($trial_create->trial_name_already_exists()) {
#        $message .= "Trial name \"".$trial_create->get_trial_name()."\" already exists.";
#        $status->{'message'} = $message;
#        $c->stash->{rest} = {status => $status };
#        $c->detach();
#    }

#    try {
#        $trial_create->save_trial();
#    } catch {
#        $message .= "Error saving trial in the database $_";
#        $status->{'message'} = $message;
#        $c->stash->{rest} = {status => $status };
#        $c->detach();
#    };

#    $message .= "Study saved successfully.";
#    $status->{'message'} = $message;
#    $c->stash->{rest} = {status => $status };
#}

sub studies_search_POST {
	my $self = shift;
	my $c = shift;
	studies_search_process($self, $c);
}

sub studies_search_GET {
	my $self = shift;
	my $c = shift;
	studies_search_process($self, $c);
}

sub studies_search_process {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->studies_search({
		programDbIds => $clean_inputs->{programDbId},
		programNames => $clean_inputs->{programName},
		studyDbIds => $clean_inputs->{studyDbId},
		studyNames => $clean_inputs->{studyName},
		studyLocationDbIds => $clean_inputs->{locationDbId},
		studyLocationNames => $clean_inputs->{locationName},
		studyTypeName => $clean_inputs->{studyType},
		germplasmDbIds => $clean_inputs->{germplasmDbId},
		germplasmNames => $clean_inputs->{germplasmName},
		observationVariableDbIds => $clean_inputs->{observationVariableDbId},
		observationVariableNames => $clean_inputs->{observationVariableName},
	});
	_standard_response_construction($c, $brapi_package_result);
}

#BrAPI Trials are modeled as Folders
sub trials_list  : Chained('brapi') PathPart('trials') Args(0) : ActionClass('REST') { }

sub trials_list_GET {
	my $self = shift;
	my $c = shift;
	trials_search_process($self, $c);
}

sub trials_list_POST {
	my $self = shift;
	my $c = shift;
	trials_search_process($self, $c);
}

sub trials_search_process {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Trials');
	my $brapi_package_result = $brapi_module->trials_search({
		locationDbIds => $clean_inputs->{locationDbId},
		programDbIds => $clean_inputs->{programDbId},
	});
	_standard_response_construction($c, $brapi_package_result);
}


sub trials_single  : Chained('brapi') PathPart('trials') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $folder_id = shift;

	$c->stash->{trial_id} = $folder_id;
}


sub trials_detail  : Chained('trials_single') PathPart('') Args(0) : ActionClass('REST') { }

sub trials_detail_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub trials_detail_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Trials');
	my $brapi_package_result = $brapi_module->trial_details(
		$c->stash->{trial_id}
	);
	_standard_response_construction($c, $brapi_package_result);
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

sub studies_single  : Chained('brapi') PathPart('studies') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $study_id = shift;

	$c->stash->{study_id} = $study_id;
}


sub studies_germplasm : Chained('studies_single') PathPart('germplasm') Args(0) : ActionClass('REST') { }

sub studies_germplasm_POST {
	my $self = shift;
	my $c = shift;
	my $auth = _authenticate_user($c);

	my $metadata = $c->req->params("metadata");
	my $result = $c->req->params("result");
	my %metadata_hash = %$metadata;
	my %result_hash = %$result;

	#print STDERR Dumper($metadata);
	#print STDERR Dumper($result);

	my $pagintation = $metadata_hash{"pagination"};
}

sub studies_germplasm_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->studies_germplasm(
		$c->stash->{study_id}
	);
	_standard_response_construction($c, $brapi_package_result);
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

sub germplasm_pedigree : Chained('germplasm_single') PathPart('pedigree') Args(0) : ActionClass('REST') { }

sub germplasm_pedigree_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub germplasm_pedigree_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Germplasm');
	my $brapi_package_result = $brapi_module->germplasm_pedigree({
		stock_id => $c->stash->{stock_id},
		notation => $clean_inputs->{notation}->[0]
	});
	_standard_response_construction($c, $brapi_package_result);
}




sub germplasm_attributes_detail  : Chained('germplasm_single') PathPart('attributes') Args(0) : ActionClass('REST') { }

sub germplasm_attributes_detail_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GermplasmAttributes');
	my $brapi_package_result = $brapi_module->germplasm_attributes_germplasm_detail({
		stock_id => $c->stash->{stock_id},
		attribute_dbids => $clean_inputs->{attributeDbId}
	});
	_standard_response_construction($c, $brapi_package_result);
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

sub germplasm_markerprofile : Chained('germplasm_single') PathPart('markerprofiles') Args(0) : ActionClass('REST') { }

sub germplasm_markerprofile_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub germplasm_markerprofile_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Germplasm');
	my $brapi_package_result = $brapi_module->germplasm_markerprofiles(
		$c->stash->{stock_id}
	);
	_standard_response_construction($c, $brapi_package_result);
}


#
# Need to implement Germplasm Attributes
#

sub germplasm_attributes_list  : Chained('brapi') PathPart('attributes') Args(0) : ActionClass('REST') { }

sub germplasm_attributes_list_GET {
	my $self = shift;
	my $c = shift;
	germplasm_attributes_process($self, $c);
}

sub germplasm_attributes_process {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GermplasmAttributes');
	my $brapi_package_result = $brapi_module->germplasm_attributes_list({
		attribute_category_dbids => $clean_inputs->{attributeCategoryDbId}
	});
	_standard_response_construction($c, $brapi_package_result);
}


sub germplasm_attribute_categories_list  : Chained('brapi') PathPart('attributes/categories') Args(0) : ActionClass('REST') { }

sub germplasm_attribute_categories_list_GET {
	my $self = shift;
	my $c = shift;
	germplasm_attributes_categories_process($self, $c);
}

sub germplasm_attributes_categories_process {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GermplasmAttributes');
	my $brapi_package_result = $brapi_module->germplasm_attributes_categories_list();
	_standard_response_construction($c, $brapi_package_result);
}



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

sub markerprofile_search_process {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $default_protocol = $self->bcs_schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$c->config->{default_genotyping_protocol}});
	my $default_protocol_id = $default_protocol ? $default_protocol->nd_protocol_id : 0;
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Markerprofiles');
	my $brapi_package_result = $brapi_module->markerprofiles_search({
		study_ids => $clean_inputs->{studyDbId},
		stock_ids => $clean_inputs->{germplasmDbId},
		extract_ids => $clean_inputs->{extractDbId},
		sample_ids => $clean_inputs->{sampleDbId},
		protocol_id => $clean_inputs->{methodDbId}->[0] ? $clean_inputs->{methodDbId}->[0] : $default_protocol_id
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub markerprofiles_list : Chained('brapi') PathPart('markerprofiles') Args(0) : ActionClass('REST') { }

sub markerprofiles_list_POST {
	my $self = shift;
	my $c = shift;
	markerprofile_search_process($self, $c);
}

sub markerprofiles_list_GET {
	my $self = shift;
	my $c = shift;
	markerprofile_search_process($self, $c);
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

sub markerprofiles_single : Chained('brapi') PathPart('markerprofiles') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $id = shift;
	$c->stash->{markerprofile_id} = $id; # this is genotypeprop_id
}

sub genotype_fetch : Chained('markerprofiles_single') PathPart('') Args(0) : ActionClass('REST') { }

sub genotype_fetch_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub genotype_fetch_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Markerprofiles');
	my $brapi_package_result = $brapi_module->markerprofiles_detail({
		markerprofile_id => $c->stash->{markerprofile_id},
		unknown_string => $clean_inputs->{unknownString}->[0],
		sep_phased => $clean_inputs->{sepPhased}->[0],
		sep_unphased => $clean_inputs->{sepUnphased}->[0],
		expand_homozygotes => $clean_inputs->{expandHomozygotes}->[0],
	});
	_standard_response_construction($c, $brapi_package_result);
}


sub markerprofiles_methods : Chained('brapi') PathPart('markerprofiles/methods') Args(0) {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Markerprofiles');
	my $brapi_package_result = $brapi_module->markerprofiles_methods();
	_standard_response_construction($c, $brapi_package_result);
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
                    { "markerDbId1":["AB","AA","AA"] },
                    { "markerDbId2":["AA","AB","AA"] },
                    { "markerDbId3":["AB","AB","BB"] }
                ]
            }
        }
 Args:
 Side Effects:

=cut

sub allelematrix : Chained('brapi') PathPart('allelematrix-search') Args(0) : ActionClass('REST') { }

sub allelematrix_POST {
	my $self = shift;
	my $c = shift;
	allelematrix_search_process($self, $c);
}

sub allelematrix_GET {
	my $self = shift;
	my $c = shift;
	allelematrix_search_process($self, $c);
}

sub allelematrix_search_process {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);

	my $clean_inputs = $c->stash->{clean_inputs};
	my $format = $clean_inputs->{format}->[0];
	my $file_path;
	my $uri;
	if ($format eq 'tsv' || $format eq 'csv' || $format eq 'xls'){
		my $dir = $c->tempfiles_subdir('download');
		($file_path, $uri) = $c->tempfile( TEMPLATE => 'download/allelematrix_'.$format.'_'.'XXXXX');
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Markerprofiles');
	my $brapi_package_result = $brapi_module->markerprofiles_allelematrix({
		markerprofile_ids => $clean_inputs->{markerprofileDbId},
		marker_ids => $clean_inputs->{markerDbId},
		unknown_string => $clean_inputs->{unknownString}->[0],
		sep_phased => $clean_inputs->{sepPhased}->[0],
		sep_unphased => $clean_inputs->{sepUnphased}->[0],
		expand_homozygotes => $clean_inputs->{expandHomozygotes}->[0],
		format => $format,
		main_production_site_url => $c->config->{main_production_site_url},
		file_path => $file_path,
		file_uri => $uri
	});
	_standard_response_construction($c, $brapi_package_result);
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

sub programs_list : Chained('brapi') PathPart('programs') Args(0) : ActionClass('REST') { }

sub programs_list_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub programs_list_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Programs');
	my $brapi_package_result = $brapi_module->programs_list({
		program_names => $clean_inputs->{programName},
		abbreviations => $clean_inputs->{abbreviation},
	});
	_standard_response_construction($c, $brapi_package_result);
}




sub studies_info  : Chained('studies_single') PathPart('') Args(0) : ActionClass('REST') { }

sub studies_info_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub studies_info_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->studies_detail(
		$c->stash->{study_id}
	);
	_standard_response_construction($c, $brapi_package_result);
}


#sub studies_details  : Chained('studies_single') PathPart('details') Args(0) : ActionClass('REST') { }

#sub studies_details_POST {
#    my $self = shift;
#    my $c = shift;
#    my $auth = _authenticate_user($c);
#    my $status = $c->stash->{status};
#
#    $c->stash->{rest} = {status => $status};
#}

#sub studies_details_GET {
#    my $self = shift;
#    my $c = shift;
#    #my $auth = _authenticate_user($c);
#    my $status = $c->stash->{status};
#    my %result;
#    my $total_count = 0;

#    my $schema = $self->bcs_schema();
#    my $t = $c->stash->{study};
#    my $tl = CXGN::Trial::TrialLayout->new( { schema => $schema, trial_id => $c->stash->{study_id} });

#    if ($t) {
#	$total_count = 1;
#	my ($accessions, $controls) = $tl->_get_trial_accession_names_and_control_names();
#	my @germplasm_data;
#    foreach (@$accessions) {
#        push @germplasm_data, { germplasmDbId=>$_->{stock_id}, germplasmName=>$_->{accession_name}, germplasmPUI=>$_->{accession_name} };
#    }
#    foreach (@$controls) {
#        push @germplasm_data, { germplasmDbId=>$_->{stock_id}, germplasmName=>$_->{accession_name}, germplasmPUI=>$_->{accession_name} };
#    }

#    my $ps = CXGN::BreedersToolbox::Projects->new( { schema => $self->bcs_schema });
#    my $programs = $ps->get_breeding_program_with_trial($c->stash->{study_id});

#	%result = (
#	    studyDbId => $c->stash->{study_id},
#	    studyId => $t->get_name(),
#	    studyPUI => "",
#	    studyName => $t->get_name(),
#	    studyObjective => $t->get_description(),
#	    studyType => $t->get_project_type() ? $t->get_project_type()->[1] : "trial",
#	    studyLocation => $t->get_location() ? $t->get_location()->[1] : undef,
#	    studyProject => $t->get_breeding_program(),
#	    dataSet => "",
#	    studyPlatform => "",
#	    startDate => $t->get_planting_date(),
#	    endDate => $t->get_harvest_date(),
#        programDbId=>@$programs[0]->[0],
#        programName=>@$programs[0]->[1],
#	    designType => $tl->get_design_type(),
#	    keyContact => "",
#	    contacts => "",
#	    meteoStationCode => "",
#	    meteoStationNetwork => "",
#	    studyHistory => "",
#	    studyComments => "",
#	    attributes => "",
#	    seasons => "",
#	    observationVariables => "",
#	    germplasm => \@germplasm_data,
#	);
#    }

#    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>$status);
#    my %response = (metadata=>\%metadata, result=>\%result);
#    $c->stash->{rest} = \%response;
#}

sub studies_observation_variables : Chained('studies_single') PathPart('observationVariables') Args(0) : ActionClass('REST') { }

sub studies_observation_variables_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub studies_observation_variables_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->studies_observation_variables(
		$c->stash->{study_id}
	);
	_standard_response_construction($c, $brapi_package_result);
}



sub studies_layout : Chained('studies_single') PathPart('layout') Args(0) : ActionClass('REST') { }

sub studies_layout_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub studies_layout_GET {
    my $self = shift;
    my $c = shift;
    my $clean_inputs = $c->stash->{clean_inputs};
    #my $auth = _authenticate_user($c);
    my $format = $clean_inputs->{format}->[0] || 'json';
    my $file_path;
    my $uri;
    if ($format eq 'tsv' || $format eq 'csv' || $format eq 'xls'){
        my $dir = $c->tempfiles_subdir('download');
        my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
        my $temp_file_name = $time_stamp . "phenotype_download_$format"."_XXXX";
        ($file_path, $uri) = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    }

	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
    my $brapi_package_result = $brapi_module->studies_layout({
        study_id => $c->stash->{study_id},
        format => $format,
        main_production_site_url => $c->config->{main_production_site_url},
        file_path => $file_path,
        file_uri => $uri
    });
    _standard_response_construction($c, $brapi_package_result);
}


=head2 brapi/v1/studies/<studyDbId>/observationUnits?observationVariableDbId=2

 Usage: To retrieve phenotypic values on a the plot level for an entire trial
 Desc:
 Return JSON example:
        {
            "metadata" : "status": [],
                "pagination": {
                    "pageSize": 1,
                    "currentPage": 1,
                    "totalCount": 1,
                    "totalPages": 1
                },
            "result" : {
                "data" : [
                    {
                        "studyDbId": 1,
                        "plotDbId": 11,
                        "observationVariableDbId" : 393939,
                        "observationVariableName" : "Yield",
                        "plotName": "ZIPA_68_Ibadan_2014",
                        "timestamp" : "2015-11-05 15:12",
                        "uploadedBy" : {dbUserId},
                        "operator" : "Jane Doe",
                        "germplasmName": 143,
                        "value" : 5,
                    }
                ]
            }
        }
 Args:
 Side Effects:

=cut

sub studies_observations : Chained('studies_single') PathPart('observationunits') Args(0) : ActionClass('REST') { }

sub studies_observations_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub studies_observations_GET {
	my $self = shift;
	my $c = shift;
	my $clean_inputs = $c->stash->{clean_inputs};
	#my $auth = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->observation_units({
		study_id => $c->stash->{study_id},
		observationVariableDbIds => $clean_inputs->{observationVariableDbId},
		data_level => $clean_inputs->{observationLevel}->[0]
	});
	_standard_response_construction($c, $brapi_package_result);
}


=head2 brapi/v1/studies/<studyDbId>/table

 Usage: To retrieve phenotypic values for a study, in a manner representative of a table, with headers and data separated
 Desc:
 Return JSON example:
{
    "metadata": {
        "status": [],
        "pagination": {
            "pageSize": 1,
            "currentPage": 1,
            "totalCount": 1,
            "totalPages": 1
        },
    }
    "result" : {
        "studyDbId": 1,
        "observationVariableDbId": [ '', '', '', '', '', '', '', '', 44444, 55555, 66666...],
        "observationVariableName": [ "plotDbId", "plotName", "block", "rep", "germplasmID", "germplasmName", "operator", "timestamp", "Yield", "Color", "Dry Matter"...],

        "data" :
        [
          [1, "plot1", 1, 1, "CIP1", 41, "user1", "2015-11-05 15:12", 10, "yellow", 9, ...],
          [2, "plot2", 1, 1, "CIP2", 42, "user1", "2015-11-05 20:12", 3, "red", 4, ...]
        ]
    }
}
 Args:
 Side Effects:

=cut

sub studies_table : Chained('studies_single') PathPart('table') Args(0) : ActionClass('REST') { }

sub studies_table_POST {
	my $self = shift;
	my $c = shift;
	my $trait_id = shift;
	#my $auth = _authenticate_user($c);
}

sub studies_table_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);

	my $clean_inputs = $c->stash->{clean_inputs};
	my $format = $clean_inputs->{format}->[0];
	my $file_path;
	my $uri;
	if ($format eq 'tsv' || $format eq 'csv' || $format eq 'xls'){
		my $dir = $c->tempfiles_subdir('download');
		my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
		my $temp_file_name = $time_stamp . "phenotype_download_$format"."_XXXX";
		($file_path, $uri) = $c->tempfile( TEMPLATE => "download/$temp_file_name");
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->studies_table({
		study_id => $c->stash->{study_id},
		data_level => $clean_inputs->{observationLevel}->[0],
		search_type => $clean_inputs->{search_type}->[0],
		trait_ids => $clean_inputs->{observationVariableDbId},
		trial_ids => $clean_inputs->{studyDbId},
		format => $format,
		main_production_site_url => $c->config->{main_production_site_url},
		file_path => $file_path,
		file_uri => $uri
	});
	_standard_response_construction($c, $brapi_package_result);
}


=head2 brapi/v1/studies/<studyDbId>/observations?observationVariableDbId=2

 Usage: To retrieve phenotypic values on a the plot level for an entire trial
 Desc:
 Return JSON example:
        {
            "metadata" : "status": [],
                "pagination": {
                    "pageSize": 1,
                    "currentPage": 1,
                    "totalCount": 1,
                    "totalPages": 1
                },
            "result" : {
                "data" : [
                    {
                        "studyDbId": 1,
                        "plotDbId": 11,
                        "observationVariableDbId" : 393939,
                        "observationVariableName" : "Yield",
                        "plotName": "ZIPA_68_Ibadan_2014",
                        "timestamp" : "2015-11-05 15:12",
                        "uploadedBy" : {dbUserId},
                        "operator" : "Jane Doe",
                        "germplasmName": 143,
                        "value" : 5,
                    }
                ]
            }
        }
 Args:
 Side Effects:

=cut

sub studies_observations_granular : Chained('studies_single') PathPart('observations') Args(0) : ActionClass('REST') { }

sub studies_observations_granular_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub studies_observations_granular_GET {
	my $self = shift;
	my $c = shift;
	my $clean_inputs = $c->stash->{clean_inputs};
	#my $auth = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->observation_units_granular({
		study_id => $c->stash->{study_id},
		observationVariableDbIds => $clean_inputs->{observationVariableDbId},
		data_level => $clean_inputs->{observationLevel}->[0],
		search_type => $clean_inputs->{search_type}->[0],
	});
	_standard_response_construction($c, $brapi_package_result);
}

=head2 brapi/v1/phenotypes?observationUnitLevel=plot&studyDbId=876&studyPUI=&studyLocation=&studySet=&studyProject=&treatmentFactor=lowInput&germplasmGenus=&germplasmSubTaxa=&germplasmDbId&germplasmPUI=http://data.inra.fr/accession/234Col342&germplasmSpecies=Triticum&panel=diversitypanel1&collection=none&observationVariables=CO_321:000034,CO_321:000025&location=bergheim&season=2005,2006&pageSize={pageSize}&page={page}

 Usage: To retrieve a phenotype dataset
 Desc:d
 Return JSON example:
        {
             "metadata": {
                 "pagination": {
                     "pageSize": 10,
                     "currentPage": 1,
                     "totalCount": 10,
                     "totalPages": 1
                 },
                 "status": []
             },

             "result" : {
                 "observationUnitDbId": 20,
                 "observationUnitPUI": "http://phenome-fppn.fr/maugio/bloc/12/2345",
                 "studyId": "RIGW1",
                 "studyDbId": 25,
                 "studyLocation": "Bergheim",
                 "studyPUI": "http://phenome-fppn.fr/phenoarch/2014/1",
                 "studyProject": "Inovine",
                 "studySet": ["National Network", "Frost suceptibility network"],
                 "studyPlatform": "Phenome",
                 "observationUnitLevelTypes" : [ "plant","plot", "bloc"],
                 "observationUnitLevelLabels": [ "1","26123", "1"],
                 "germplasmPUI": "http://inra.fr/vassal/41207Col0001E",
                 "germplasmDbId": 3425,
                 "germplasmName": "charger",
                 "treatments":
                 [
                     {
                         "factor" : "water regimen" ,
                         "modality":"water deficit"
                     }
                 ],
                 "attributes":
                 [
                     {"att1" :"value"},
                 {"numPot" :"23"}
                 ],
                 "X" : "",
                 "Y" : "",
                 "XLabel" : "",
                 "YLabel" : "",
                 "data": [
                         {
                             "instanceNumber" : 1,
                             "observationVariableId": "CO_321:0000045",
                             //"observationVariableDbId": 35,
                             "season": "2005",
                             "observationValue" : "red",
                             "observationTimeStamp": null,
                             "quality": "reliability of the observation",
                             "collectionFacilityLabel":  "phenodyne",
                             "collector" : "John Doe and team"
                         },
                         {
                             "instanceNumber" : 1,
                             "observationVariableId": "http://www.cropontology.org/rdf/CO_321:0000025",
                             //"observationVariableDbId": 35,
                             "season": null,
                             "observationValue" :  32,
                             "observationTimeStamp": "2006-07-03::10:00",
                             "quality": "8",
                             "collectionFacilityLabel": null,
                             "collector" : "userURIOrName"
                         }
                     ]
                 }
             ]
         }
 Args:
 Side Effects:

=cut

sub phenotypes_search : Chained('brapi') PathPart('phenotypes-search') Args(0) : ActionClass('REST') { }

sub phenotypes_search_POST {
	my $self = shift;
	my $c = shift;
	process_phenotypes_search($self, $c);
}

sub phenotypes_search_GET {
	my $self = shift;
	my $c = shift;
	process_phenotypes_search($self, $c);
}

sub process_phenotypes_search {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Phenotypes');
	my $brapi_package_result = $brapi_module->search({
		trait_ids => $clean_inputs->{observationVariableDbIds},
		accession_ids => $clean_inputs->{germplasmDbIds},
		study_ids => $clean_inputs->{studyDbIds},
		location_ids => $clean_inputs->{locationDbIds},
		years => $clean_inputs->{seasonDbIds},
		data_level => $clean_inputs->{observationLevel}->[0],
		search_type => $clean_inputs->{search_type}->[0],
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub traits_list : Chained('brapi') PathPart('traits') Args(0) : ActionClass('REST') { }

sub traits_list_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub traits_list_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Traits');
	my $brapi_package_result = $brapi_module->list({
        trait_ids => $clean_inputs->{traitDbIds},
        names => $clean_inputs->{names}
    });
	_standard_response_construction($c, $brapi_package_result);
}


sub traits_single  : Chained('brapi') PathPart('traits') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $trait_id = shift;

	$c->stash->{trait_id} = $trait_id;
}


sub trait_detail  : Chained('traits_single') PathPart('') Args(0) : ActionClass('REST') { }

sub trait_detail_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Traits');
	my $brapi_package_result = $brapi_module->detail(
		$c->stash->{trait_id}
	);
	_standard_response_construction($c, $brapi_package_result);
}


=head2 brapi/v1/maps?species=speciesId

 Usage: To retrieve a list of all maps available in the database.
 Desc:
 Return JSON example:
        {
            "metadata" : {
                "pagination" : {
                    "pageSize": 30,
                    "currentPage": 2,
                    "totalCount": 40,
                    "totalPages": 2
                }
                "status" : []
            },
            "result": {
                "data" : [
                    {
                        "mapId": 1,
                        "name": "Some Map",
                        "species": "Some species",
                        "type": "Genetic",
                        "unit": "cM",
                        "publishedDate": "2008-04-16",
                        "markerCount": 1000,
                        "linkageGroupCount": 7,
                        "comments": "This map contains ..."
                    },
                    {
                        "mapId": 2,
                        "name": "Some Other map",
                        "species": "Some Species",
                        "type": "Genetic",
                        "unit": "cM",
                        "publishedDate": "2009-01-12",
                        "markerCount": 1501,
                        "linkageGroupCount": 7,
                        "comments": "this is blah blah"
                    }
                ]
            }
        }
 Args:
 Side Effects:

=cut

sub maps_list : Chained('brapi') PathPart('maps') Args(0) : ActionClass('REST') { }

sub maps_list_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub maps_list_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GenomeMaps');
	my $brapi_package_result = $brapi_module->list();
	_standard_response_construction($c, $brapi_package_result);
}



=head2 brapi/v1/maps/<map_id>

 Usage: To retrieve details for a specific map_id
 Desc:
 Return JSON example:
        {
            "metadata" : {
                "pagination" : {
                    "pageSize": 30,
                    "currentPage": 2,
                    "totalCount": 40,
                    "totalPages": 2
                }
                "status" : []
            },
            "result": {
                "mapId": "id",
                "name": "Some map",
                "type": "Genetic",
                "unit": "cM",
                "linkageGroups": [
                    {
                        "linkageGroupId": 1,
                        "numberMarkers": 100000,
                        "maxPosition": 10000000
                    },
                    {
                        "linkageGroupId": 2,
                        "numberMarkers": 1247,
                        "maxPostion": 12347889
                    }
                ]
            }
        }
 Args:
 Side Effects:

=cut

sub maps_single : Chained('brapi') PathPart('maps') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $map_id = shift;

	$c->stash->{map_id} = $map_id;
}


sub maps_details : Chained('maps_single') PathPart('') Args(0) : ActionClass('REST') { }

sub maps_details_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub maps_details_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GenomeMaps');
	my $brapi_package_result = $brapi_module->detail(
		$c->stash->{map_id}
	);
	_standard_response_construction($c, $brapi_package_result);
}


=head2 brapi/v1/maps/<map_id>/position?linkageGroupIdList=1,2,3

 Usage: To retrieve marker position data for a species map_id. Can provide a list of linkage groups (e.g. chromosomes) to narrow result set.
 Desc:
 Return JSON example:
        {
            "metadata" : {
                "pagination" : { "pageSize": 30, "currentPage": 2, "totalCount": 40, "totalPages":2 },
                "status: []
            },
            "result": {
                "data" : [
                    {
                        "markerDbId": 1,
                        "markerName": "marker1",
                        "location": "1000",
                        "linkageGroup": "1A"
                    }, {
                        "markerDbId": 2,
                        "markerName": "marker2",
                        "location": "1001",
                        "linkageGroup": "1A"
                    }
                ]
            }
        }
 Args:
 Side Effects:

=cut

sub maps_marker_detail : Chained('maps_single') PathPart('positions') Args(0) : ActionClass('REST') { }

sub maps_marker_detail_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub maps_marker_detail_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GenomeMaps');
	my $brapi_package_result = $brapi_module->positions({
		map_id => $c->stash->{map_id},
		linkage_group_ids => $clean_inputs->{linkageGroupId},
		min => $clean_inputs->{min}->[0],
		max => $clean_inputs->{max}->[0],
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub maps_marker_linkagegroup_detail : Chained('maps_single') PathPart('positions') Args(1) : ActionClass('REST') { }

sub maps_marker_linkagegroup_detail_GET {
	my $self = shift;
	my $c = shift;
	my $linkage_group_id = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GenomeMaps');
	my $brapi_package_result = $brapi_module->positions({
		map_id => $c->stash->{map_id},
		linkage_group_ids => [$linkage_group_id],
		min => $clean_inputs->{min}->[0],
		max => $clean_inputs->{max}->[0],
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub locations_list : Chained('brapi') PathPart('locations') Args(0) : ActionClass('REST') { }

sub locations_list_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub locations_list_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Locations');
	my $brapi_package_result = $brapi_module->locations_list();
	_standard_response_construction($c, $brapi_package_result);
}

sub observationvariable_data_type_list : Chained('brapi') PathPart('variables/datatypes') Args(0) : ActionClass('REST') { }

sub observationvariable_data_type_list_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub observationvariable_data_type_list_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
	my $brapi_package_result = $brapi_module->observation_variable_data_types();
	_standard_response_construction($c, $brapi_package_result);
}

sub observationvariable_ontologies : Chained('brapi') PathPart('ontologies') Args(0) : ActionClass('REST') { }

sub observationvariable_ontologies_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub observationvariable_ontologies_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);

	#Using code pattern found in SGN::Controller::Ontology->onto_browser
	my $onto_root_namespaces = $c->config->{onto_root_namespaces};
	my @namespaces = split ", ", $onto_root_namespaces;
	foreach my $n (@namespaces) {
		$n =~ s/\s*(\w+)\s*\(.*\)/$1/g;
	}
	#print STDERR Dumper \@namespaces;

	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
	my $brapi_package_result = $brapi_module->observation_variable_ontologies({
		name_spaces => \@namespaces
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub observationvariable_search : Chained('brapi') PathPart('variables-search') Args(0) : ActionClass('REST') { }

sub observationvariable_search_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	_observationvariable_search_process($self, $c);
}

sub observationvariable_search_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	_observationvariable_search_process($self, $c);
}

sub _observationvariable_search_process {
	my $self = shift;
	my $c = shift;

	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
	my $brapi_package_result = $brapi_module->observation_variable_search({
		observationvariable_db_ids => $clean_inputs->{observationVariableDbId},
		ontology_db_names => $clean_inputs->{ontologyXref},
		ontology_dbxref_terms => $clean_inputs->{ontologyDbId},
		method_db_ids => $clean_inputs->{methodDbId},
		scale_db_ids => $clean_inputs->{scaleDbId},
		observationvariable_names => $clean_inputs->{name},
		observationvariable_datatypes => $clean_inputs->{datatype},
		observationvariable_classes => $clean_inputs->{traitClass},
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub observationvariable_list : Chained('brapi') PathPart('variables') Args(0) : ActionClass('REST') { }

sub observationvariable_list_GET {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
	my $brapi_package_result = $brapi_module->observation_variable_search();
	_standard_response_construction($c, $brapi_package_result);
}

sub observationvariable_detail : Chained('brapi') PathPart('variables') Args(1) : ActionClass('REST') { }

sub observationvariable_detail_GET {
	my $self = shift;
	my $c = shift;
	my $trait_id = shift;
	#my $auth = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
	my $brapi_package_result = $brapi_module->observation_variable_detail(
		$trait_id
	);
	_standard_response_construction($c, $brapi_package_result);
}

sub authenticate : Chained('brapi') PathPart('authenticate/oauth') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->res->redirect("https://accounts.google.com/o/oauth2/auth?scope=profile&response_type=code&client_id=1068256137120-62dvk8sncnbglglrmiroms0f5d7lg111.apps.googleusercontent.com&redirect_uri=https://cassavabase.org/oauth2callback");

    $c->stash->{rest} = { success => 1 };


}


1;
