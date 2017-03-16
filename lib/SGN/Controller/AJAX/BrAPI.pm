
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
use CXGN::Trial::TrialCreate;
use CXGN::Trial::Search;
use CXGN::Location::LocationLookup;
use JSON qw( decode_json );
use Data::Dumper;
use Try::Tiny;
use CXGN::Phenotypes::SearchFactory;
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

my $DEFAULT_PAGE_SIZE=20;

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
    push @status, { 'info' => "BrAPI base call found with page=$page, pageSize=$page_size" };

    my $brapi = CXGN::BrAPI->new({
        version => $version,
		brapi_module_inst => {
			bcs_schema => $bcs_schema,
			metadata_schema => $metadata_schema,
			phenome_schema => $phenome_schema,
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
    $c->stash->{current_page} = $page;
    $c->stash->{page_size} = $page_size;

	$c->stash->{clean_inputs} = _clean_inputs($c->req->params);
}

#useful because javascript can pass 'undef' as an empty value
sub _clean_inputs {
	no warnings 'uninitialized';
	my $params = shift;
	#print STDERR Dumper $params;
	foreach (keys %$params){
		my @values = $params->{$_};
		@values = grep {$_ ne undef} @values;
		$params->{$_} = \@values;
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
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status=>$status};
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
		programDbIds => $clean_inputs->{programDbIds},
		programNames => $clean_inputs->{programNames},
		studyDbIds => $clean_inputs->{studyDbIds},
		studyNames => $clean_inputs->{studyNames},
		studyLocationDbIds => $clean_inputs->{studyLocationDbIds},
		studyLocationNames => $clean_inputs->{studyLocationNames},
		studyTypeName => $clean_inputs->{studyTypeName},
		germplasmDbIds => $clean_inputs->{germplasmDbIds},
		germplasmNames => $clean_inputs->{germplasmNames},
		observationVariableDbIds => $clean_inputs->{observationVariableDbIds},
		observationVariableNames => $clean_inputs->{observationVariableNames},
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
		locationDbIds => $clean_inputs->{locationDbIds},
		programDbIds => $clean_inputs->{programDbIds},
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
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status=>$status};
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
    my $status = $c->stash->{status};

    my $metadata = $c->req->params("metadata");
    my $result = $c->req->params("result");
    my %metadata_hash = %$metadata;
    my %result_hash = %$result;

    print STDERR Dumper($metadata);
    print STDERR Dumper($result);

    my $pagintation = $metadata_hash{"pagination"};

    $c->stash->{rest} = {status=>$status};
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
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status=>$status};
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
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status=>$status};
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
	my $default_protocol_id = $self->bcs_schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$c->config->{default_genotyping_protocol}})->nd_protocol_id();
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
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status=>$status};
}

sub genotype_fetch_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my $unknown_string = $c->req->param('unknownString') || '';
    my $expand_homozygotes = $c->req->param('expandHomozygotes') || '';
    my $sep_phased = $c->req->param('sepPhased') || '|';
    my $sep_unphased = $c->req->param('sepUnphased') || '/';
    my @data;
    my %result;

    my $total_count = 0;
    my $rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->find(
        {'genotypeprops.genotypeprop_id' => $c->stash->{markerprofile_id} },
        {join=> [{'nd_experiment_genotypes' => {'genotype' => 'genotypeprops'} }, {'nd_experiment_protocols' => 'nd_protocol' }, {'nd_experiment_stocks' => 'stock'} ],
         select=> ['genotypeprops.value', 'nd_protocol.name', 'stock.stock_id', 'stock.uniquename'],
         as=> ['value', 'protocol_name', 'stock_id', 'uniquename'],
        }
    );

    if ($rs) {
        my $genotype_json = $rs->get_column('value');
        my $genotype = JSON::Any->decode($genotype_json);
        $total_count = scalar keys %$genotype;

        foreach my $m (sort genosort keys %$genotype) {
            push @data, { $m=>$self->convert_dosage_to_genotype($genotype->{$m}) };
        }

        my $start = $c->stash->{page_size}*$c->stash->{current_page};
        my $end = $c->stash->{page_size}*($c->stash->{current_page}+1)-1;
        my @data_window = splice @data, $start, $end;

        %result = (
            germplasmDbId=>$rs->get_column('stock_id'),
            uniqueDisplayName=>$rs->get_column('uniquename'),
            extractDbId=>'',
            markerprofileDbId=>$c->stash->{markerprofile_id},
            analysisMethod=>$rs->get_column('protocol_name'),
            #encoding=>"AA,BB,AB",
            data => \@data_window
        );
    }

    my @datafiles;
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>\@datafiles);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


sub markerprofiles_methods : Chained('brapi') PathPart('markerprofiles/methods') Args(0) {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

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

    if ($a_chr && $b_chr) {
      if ($a_chr == $b_chr) {
          return $a_pos <=> $b_pos;
      }
      return $a_chr <=> $b_chr;
    } else {
      return -1;
    }
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
    my $status = $c->stash->{status};
    my $message = '';
    my @profile_ids = $c->req->param('markerprofileDbId');
    my @marker_ids = $c->req->param('markerDbId');
    my $unknown_string = $c->req->param('unknownString') || '';
    my $sep_phased = $c->req->param('sepPhased') || '|';
    my $sep_unphased = $c->req->param('sepUnphased') || '/';
    my $data_format = $c->req->param('format') || 'json';
    my %metadata;
    my $data_file_path;
    my %result;
    #print STDERR Dumper \@profile_ids;
    #my @profile_ids = split ",", $markerprofile_ids;

    if ($data_format ne 'json' && $data_format ne 'tsv' && $data_format ne 'csv') {
        $message .= 'Unsupported Format Given. Supported values are: json, tsv, csv';
        $status->{'message'} = $message;
        $c->stash->{rest} = {
            metadata => { pagination=>{}, status => [$status], datafiles=>[$data_file_path] },
            result => \%result,
        };
        $c->detach;
    }

    my $rs = $self->bcs_schema()->resultset("Genetic::Genotypeprop")->search( { genotypeprop_id => { -in => \@profile_ids }});

    my @scores;
    my $total_pages;
    my $total_count;
    my @ordered_refmarkers;
    my $markers;
    if ($rs->count() > 0) {
        while (my $profile = $rs->next()) {
            my $profile_json = $profile->value();
            my $refmarkers = JSON::Any->decode($profile_json);
            #print STDERR Dumper($refmarkers);
            push @ordered_refmarkers, sort genosort keys(%$refmarkers);
        }
        #print Dumper(\@ordered_refmarkers);
        my %unique_markers;
        foreach (@ordered_refmarkers) {
            $unique_markers{$_} = 1;
        }

        my $json = JSON->new();
        $rs = $self->bcs_schema()->resultset("Genetic::Genotypeprop")->search( { genotypeprop_id => { -in => \@profile_ids }});
        while (my $profile = $rs->next()) {
            my $markers_json = $profile->value();
            $markers = $json->decode($markers_json);
            my $genotypeprop_id = $profile->genotypeprop_id();
            foreach my $m (sort keys %unique_markers) {
                push @scores, [$m, $genotypeprop_id, $self->convert_dosage_to_genotype($markers->{$m})];
            }
        }
    }

    #print STDERR Dumper \@scores;

    my $file_path;
    my @scores_seen;
    if (!$data_format || $data_format eq 'json' ){

        for (my $n = $c->stash->{page_size}*$c->stash->{current_page}; $n< ($c->stash->{page_size}*($c->stash->{current_page}+1)-1); $n++) {
            push @scores_seen, $scores[$n];
        }

    } elsif ($data_format eq 'tsv' || $data_format eq 'csv') {

        my @header_row;
        push @header_row, 'markerprofileDbIds';
        foreach (@profile_ids){
            push @header_row, $_;
        }

        my %markers;
        foreach (@scores){
            $markers{$_->[0]}->{$_->[1]} = $_->[2];
        }
        #print STDERR Dumper \%markers;

        my $delim;
        if ($data_format eq 'tsv') {
            $delim = "\t";
        } elsif ($data_format eq 'csv') {
            $delim = ",";
        }
        my $dir = $c->tempfiles_subdir('download');
        my ($file_path, $uri) = $c->tempfile( TEMPLATE => 'download/allelematrix_'.$data_format.'_'.'XXXXX');
        #$file_path = $c->config->{main_production_sitae_url}.":".$c->config->{basepath}."/".$tempfile.".$data_format";
        open(my $fh, ">", $file_path);
            print STDERR $file_path."\n";
            print $fh join("$delim", @header_row),"\n";
            #print $fh "markerprofileDbIds\t", join($delim, @lines), "\n";
            foreach (keys %markers) {
                print $fh $_.$delim;
                my $count = 1;
                foreach my $profile_id (@profile_ids) {
                    print $fh $markers{$_}->{$profile_id};
                    if ($count < scalar(@profile_ids)){
                        print $fh $delim;
                    }
                    #print $fh .join("$delim", @{$_}),"\n";
                    $count++;
                }
                print $fh "\n";
            }

        close $fh;
        $data_file_path = $c->config->{main_production_site_url}.$uri;
        #$c->res->content_type('Application/'.$data_format);
        #$c->res->header('Content-Disposition', qq[attachment; filename="$data_file_path"]);
        #my $output = read_file($data_file_path);
        #$c->res->body($output);
    }

    $total_count = scalar(@scores);

    $c->stash->{rest} = {
        metadata => { pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status => [$status], datafiles=>[$data_file_path] },
        result => {data => \@scores_seen},
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

sub programs_list : Chained('brapi') PathPart('programs') Args(0) : ActionClass('REST') { }

sub programs_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status=>$status};
}

sub programs_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my $program_name = $c->req->param('programName');
    my $abbreviation = $c->req->param('abbreviation');
    my %result;
    my @data;

    my $ps = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $programs = $ps -> get_breeding_programs();
    my $total_count = scalar(@$programs);

    my $start = $c->stash->{page_size}*$c->stash->{current_page};
    my $end = $c->stash->{page_size}*($c->stash->{current_page}+1)-1;
    for( my $i = $start; $i <= $end; $i++ ) {
        if (@$programs[$i]) {
            if ($program_name) {
                if ($program_name eq @$programs[$i]->[1]) {
                    push @data, {
                        programDbId=>@$programs[$i]->[0],
                        name=>@$programs[$i]->[1],
                        abbreviation=>@$programs[$i]->[1],
                        objective=>@$programs[$i]->[2],
                        leadPerson=>''
                    };
                }
            } else {
                push @data, {
                    programDbId=>@$programs[$i]->[0],
                    name=>@$programs[$i]->[1],
                    abbreviation=>@$programs[$i]->[1],
                    objective=>@$programs[$i]->[2],
                    leadPerson=>''
                };
            }
        }
    }

    %result = (data=>\@data);
    my @datafiles;
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>\@datafiles);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}



sub studies_instances  : Chained('studies_single') PathPart('instances') Args(0) : ActionClass('REST') { }

sub studies_instances_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status=>$status};
}

sub studies_instances_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my %result;
    my $status = $c->stash->{status};
    my $total_count = 0;

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status]);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


sub studies_info  : Chained('studies_single') PathPart('') Args(0) : ActionClass('REST') { }

sub studies_info_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub studies_info_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my %result;
    my $status = $c->stash->{status};
    my $message = '';
    my $total_count = 0;
    my $study_id = $c->stash->{study_id};
    my $t = $c->stash->{study};
    if ($t) {
        $total_count = 1;
        my $folder = CXGN::Trial::Folder->new( { folder_id => $study_id, bcs_schema => $self->bcs_schema } );
        if ($folder->folder_type eq 'trial') {

            my @years = ($t->get_year());
            my %additional_info = (
                studyPUI=>'',
            );
            my $project_type = '';
            if ($t->get_project_type()) {
               $project_type = $t->get_project_type()->[1];
            }
            my $location_id = '';
            my $location_name = '';
            if ($t->get_location()) {
               $location_id = $t->get_location()->[0];
               $location_name = $t->get_location()->[1];
            }
            my $planting_date = '';
            if ($t->get_planting_date()) {
                $planting_date = $t->get_planting_date();
                my $t = Time::Piece->strptime($planting_date, "%Y-%B-%d");
                $planting_date = $t->strftime("%Y-%m-%d");
            }
            my $harvest_date = '';
            if ($t->get_harvest_date()) {
                $harvest_date = $t->get_harvest_date();
                my $t = Time::Piece->strptime($harvest_date, "%Y-%B-%d");
                $harvest_date = $t->strftime("%Y-%m-%d");
            }
            %result = (
                studyDbId=>$t->get_trial_id(),
                name=>$t->get_name(),
                trialDbId=>$folder->project_parent->project_id(),
                trialName=>$folder->project_parent->name(),
                studyType=>$project_type,
                seasons=>\@years,
                locationDbId=>$location_id,
                locationName=>$location_name,
                programDbId=>$folder->breeding_program->project_id(),
                programName=>$folder->breeding_program->name(),
                startDate => $planting_date,
                endDate => $harvest_date,
                additionalInfo=>\%additional_info,
                active=>'',
                observationVariables=>"/brapi/v1/studies/$study_id/observationVariables",
                germplasm=>"/brapi/v1/studies/$study_id/germplasm",
                observationUnits=>"/brapi/v1/studies/$study_id/observationUnits",
                layout=>"/brapi/v1/studies/$study_id/layout",
                location=>"/brapi/v1/locations/$location_id",
            );
        }
    } else {
        $message .= "StudyDbId not found.";
    }
    $status->{'message'} = $message;
    my @datafiles;
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>\@datafiles);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
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
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub studies_observation_variables_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my %result;
    my $total_count = 0;

    my $t = CXGN::Trial->new( { schema => $self->bcs_schema, trial_id => $c->stash->{study_id} });
    my @data;

    %result = (data=>\@data);
    my @datafiles;
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>\@datafiles);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}



sub studies_layout : Chained('studies_single') PathPart('layout') Args(0) : ActionClass('REST') { }

sub studies_layout_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub studies_layout_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my %result;
    my $total_count = 0;

    my $tl = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $c->stash->{study_id} });
    my $design = $tl->get_design();

    my $plot_data = [];
    my $formatted_plot = {};
    my %optional_info;
    my $check_id;
    my $type;

    foreach my $plot_number (keys %$design) {
	$check_id = $design->{$plot_number}->{is_a_control} ? 1 : 0;
	if ($check_id == 1) {
	    $type = 'Check';
	} else {
	    $type = 'Test';
	}
	$formatted_plot = {
	    studyDbId => $c->stash->{study_id},
	    observationUnitDbId => $design->{$plot_number}->{plot_id},
	    observationUnitName => $design->{$plot_number}->{plot_name},
        observationLevel => 'plot',
	    replicate => $design->{$plot_number}->{replicate} ? $design->{$plot_number}->{replicate} : '',
        blockNumber => $design->{$plot_number}->{block_number} ? $design->{$plot_number}->{block_number} : '',
        X => $design->{$plot_number}->{row_number} ? $design->{$plot_number}->{row_number} : '',
        Y => $design->{$plot_number}->{col_number} ? $design->{$plot_number}->{col_number} : '',
        entryType => $type,
        germplasmName => $design->{$plot_number}->{accession_name},
	    germplasmDbId => $design->{$plot_number}->{accession_id},
	    optionalInfo => \%optional_info
	};
	push @$plot_data, $formatted_plot;
	$total_count += 1;
    }
    %result = (data=>$plot_data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status]);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
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

sub studies_observations : Chained('studies_single') PathPart('observations') Args(0) : ActionClass('REST') { }

sub studies_observations_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub studies_observations_GET {
    my $self = shift;
    my $c = shift;
    my @trait_ids_array = $c->req->param('observationVariableDbId');
    my $data_level = $c->req->param('observationLevel') || 'plot';
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my %result;
    #my @trait_ids_array;
    #if(ref($trait_ids) eq 'ARRAY') {
    #    @trait_ids_array = @{$trait_ids};
    #} elsif(ref($trait_ids) eq 'SCALAR') {
    #    @trait_ids_array = ($trait_ids);
    #}
    #print STDERR Dumper $trait_ids;
    #print STDERR Dumper \@trait_ids_array;
    my $t = $c->stash->{study};
    my $phenotype_data;
    if ($data_level eq 'all') {
        $phenotype_data = $t->get_stock_phenotypes_for_traits(\@trait_ids_array, 'all', ['plot_of','plant_of'], 'accession', 'subject');
    } elsif ($data_level eq 'plot') {
        $phenotype_data = $t->get_stock_phenotypes_for_traits(\@trait_ids_array, 'plot', ['plot_of'], 'accession', 'subject');
    } elsif ($data_level eq 'plant') {
        $phenotype_data = $t->get_stock_phenotypes_for_traits(\@trait_ids_array, 'plant', ['plant_of'], 'accession', 'subject');
    }

    #print STDERR Dumper $phenotype_data;

    my @data;
    my $total_count = scalar(@$phenotype_data);
    my $start = $c->stash->{page_size}*$c->stash->{current_page};
    my $end = $c->stash->{page_size}*($c->stash->{current_page}+1)-1;
    for( my $i = $start; $i <= $end; $i++ ) {
        if (@$phenotype_data[$i]) {
            my $pheno_uniquename = @$phenotype_data[$i]->[5];
            my ($part1 , $part2) = split( /date: /, $pheno_uniquename);
            my ($timestamp , $operator) = split( /\ \ operator = /, $part2);

            my %data_hash = (
                studyDbId => $c->stash->{study_id},
                observationDbId=>@$phenotype_data[$i]->[4],
                observationVariableDbId => @$phenotype_data[$i]->[2],
                observationVariableName => @$phenotype_data[$i]->[3],
                observationUnitDbId => @$phenotype_data[$i]->[0],
                observationUnitName => @$phenotype_data[$i]->[1],
                observationLevel => @$phenotype_data[$i]->[10],
                observationTimestamp => $timestamp,
                uploadedBy => @$phenotype_data[$i]->[6],
                operator => $operator,
                germplasmDbId => @$phenotype_data[$i]->[8],
                germplasmName => @$phenotype_data[$i]->[9],
                value => @$phenotype_data[$i]->[7]
            );
            push @data, \%data_hash;
        }
    }

    %result = (data=>\@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>[]);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
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
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub studies_table_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my $data_level = $c->req->param('observationLevel') || 'plot';
    my $format = $c->req->param('format') || 'json';
    my %result;
    my $search_type = $c->req->param("search_type") || 'complete';
    my $include_timestamp = $c->req->param("timestamp") || 0;
    my $trial_id = $c->stash->{study_id};

    my $factory_type;
    if ($search_type eq 'complete'){
        $factory_type = 'Native';
    }
    if ($search_type eq 'fast'){
        $factory_type = 'MaterializedView';
    }
    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        $factory_type,    #can be either 'MaterializedView', or 'Native'
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$data_level,
            trial_list=>[$trial_id],
            include_timestamp=>$include_timestamp,
        }
    );
    my @data = $phenotypes_search->get_extended_phenotype_info_matrix();

    #print STDERR Dumper \@data;

    if ($format eq 'json') {
        my $total_count = scalar(@data)-1;
        my @header_names = split /\t/, $data[0];
        #print STDERR Dumper \@header_names;
        my @trait_names = @header_names[15 .. $#header_names];
        #print STDERR Dumper \@trait_names;
        my @header_ids;
        foreach my $t (@trait_names) {
            push @header_ids, SGN::Model::Cvterm->get_cvterm_row_from_trait_name($self->bcs_schema, $t)->cvterm_id();
        }

        my $start = $c->stash->{page_size}*$c->stash->{current_page};
        my $end = $c->stash->{page_size}*($c->stash->{current_page}+1)-1;
        my @data_window;
        for (my $line = $start; $line < $end; $line++) {
            if ($data[$line]) {
                my @columns = split /\t/, $data[$line], -1;

                push @data_window, \@columns;
            }
        }

        #print STDERR Dumper \@data_window;

        %result = (
            studyDbId => $c->stash->{study_id},
            headerRow => ['studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber'],
            observationVariableDbIds => \@header_ids,
            observationVariableNames => \@trait_names,
            data=>\@data_window
        );
        my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>[]);
        my %response = (metadata=>\%metadata, result=>\%result);
        $c->stash->{rest} = \%response;

    } else {
        # if xls or csv, create tempfile name and place to save it
        my $what = "phenotype_download";
        my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
        my $dir = $c->tempfiles_subdir('download');
        my $temp_file_name = $time_stamp . "$what" . "XXXX";
        my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
        my $tempfile = $c->config->{basepath}."/".$rel_file;

        if ($format eq "csv") {

            #build csv with column names
            open(CSV, ">", $tempfile) || die "Can't open file $tempfile\n";
                my @header = split /\t/, $data[0];
                my $num_col = scalar(@header);
                for (my $line =0; $line< @data; $line++) {
                    my @columns = split /\t/, $data[$line];
                    my $step = 1;
                    for(my $i=0; $i<$num_col; $i++) {
                        if ($columns[$i]) {
                            print CSV "\"$columns[$i]\"";
                        } else {
                            print CSV "\"\"";
                        }
                        if ($step < $num_col) {
                            print CSV ",";
                        }
                        $step++;
                    }
                    print CSV "\n";
                }
            close CSV;

        } elsif ($format = 'xls') {
            my $ss = Spreadsheet::WriteExcel->new($tempfile);
            my $ws = $ss->add_worksheet();

            for (my $line =0; $line< @data; $line++) {
                my @columns = split /\t/, $data[$line];
                for(my $col = 0; $col<@columns; $col++) {
                    $ws->write($line, $col, $columns[$col]);
                }
            }
            #$ws->write(0, 0, "$program_name, $location ($year)");
            $ss ->close();
        }

        #Using tempfile and new filename,send file to client
        my $file_name = $time_stamp . "$what" . ".$format";
        $c->res->content_type('Application/'.$format);
        $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
        my $output = read_file($tempfile);
        $c->res->body($output);
    }
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
    my $status = $c->stash->{status};
    my @data;
    my $stock_ids = $c->req->param('germplasmDbIds');
    my $trait_ids = $c->req->param('observationVariableDbIds');
    my $trial_ids = $c->req->param('studyDbIds');
    my $location_ids = $c->req->param('locationDbIds');
    my $year_ids = $c->req->param('seasonDbIds');
    my $data_level = $c->req->param('observationLevel') || 'plot';
    my $search_type = $c->req->param("search_type") || 'complete';
    my @stocks_array = split /,/, $stock_ids;
    my @traits_array = split /,/, $trait_ids;
    my @trials_array = split /,/, $trial_ids;
    my @locations_array = split /,/, $location_ids;
    my @years_array = split /,/, $year_ids;
    my $offset = $c->stash->{current_page}*$c->stash->{page_size};

    my $factory_type;
    if ($search_type eq 'complete'){
        $factory_type = 'Native';
    }
    if ($search_type eq 'fast'){
        $factory_type = 'MaterializedView';
    }
    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        $factory_type,    #can be either 'MaterializedView', or 'Native'
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$data_level,
            stock_list=>\@stocks_array,
            trial_list=>\@trials_array,
            location_list=>\@locations_array,
            trait_list=>\@traits_array,
            year_list=>\@years_array,
            include_timestamp=>1,
            limit=>$c->stash->{page_size},
            offset=>$offset
        }
    );
    my $search_result = $phenotypes_search->search();
    #print STDERR Dumper $search_result;
    my $total_count = 0;
    if (scalar(@$search_result)>0){
        $total_count = $search_result->[0]->[21];
    }
    foreach my $result (@$search_result){
            my %data_entry = (
                observationDbId=>$result->[20],
                observationUnitDbId=>$result->[15],
                observationUnitName=>$result->[6],
                studyDbId=>$result->[12],
                studyName=>$result->[1],
                studyLocationDbId=>$result->[13],
                studyLocation=>$result->[3],
                programName=>'',
                observationLevel=>$result->[19],
                germplasmDbId=>$result->[14],
                germplasmName=>$result->[2],
                observationVariableName=>$result->[4]."|".$result->[7],
                observationVariableDbId=>$result->[11],
                season=>$result->[0],
                value=>$result->[5],
                observationTimeStamp=>$result->[16],
                collector=>'',
                uploadedBy=>'',
                additionalInfo=>{
                    'block'=>$result->[9],
                    'replicate'=>$result->[8],
                    'plotNumber'=>$result->[10],
                    'germplasmSynonyms'=>$result->[17],
                    'design'=>$result->[18],
                }
            );
            push @data, \%data_entry;
        #}
    }

    my %result = (data => \@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>[]);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}

sub traits_list : Chained('brapi') PathPart('traits') Args(0) : ActionClass('REST') { }

sub traits_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub traits_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    #my $db_rs = $self->bcs_schema()->resultset("General::Db")->search( { name => $c->config->{trait_ontology_db_name} } );
    #if ($db_rs->count ==0) { return undef; }
    #my $db_id = $db_rs->first()->db_id();

    #my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, cvtermprop.value, dbxref.accession FROM cvterm LEFT JOIN cvtermprop using(cvterm_id) JOIN dbxref USING(dbxref_id) WHERE dbxref.db_id=?";
    #my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
    #$h->execute($db_id);

    my @trait_ids;
    my $q = "SELECT trait_id FROM traitsxtrials ORDER BY trait_id;";
    my $p = $self->bcs_schema()->storage->dbh()->prepare($q);
    $p->execute();
    while (my ($cvterm_id) = $p->fetchrow_array()) {
        push @trait_ids, $cvterm_id;
    }

    my @data;
    foreach my $cvterm_id (@trait_ids){
        my $q2 = "SELECT cvterm.definition, cvtermprop.value, dbxref.accession, db.name, cvterm.name FROM cvterm LEFT JOIN cvtermprop using(cvterm_id) JOIN dbxref USING(dbxref_id) JOIN db using(db_id) WHERE cvterm.cvterm_id=?";
        my $h = $self->bcs_schema()->storage->dbh()->prepare($q2);
        $h->execute($cvterm_id);

        while (my ($description, $scale, $accession, $db, $name) = $h->fetchrow_array()) {
            my @observation_vars = ();
            push @observation_vars, $name.'|'.$db.":".$accession;
            push @data, {
                traitDbId => $cvterm_id,
                traitId => $db.':'.$accession,
                name => $name,
                description => $description,
                observationVariables => \@observation_vars,
                defaultValue => '',
                #scale =>$scale
            };
        }
    }

    my $total_count = $p->rows;
    my %result = (data => \@data);
    my @datafiles;
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>\@datafiles);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;

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
    my $cvterm_id = $c->stash->{trait_id};
    my $status = $c->stash->{status};
    my %result;

    my $q = "SELECT cvterm.definition, cvtermprop.value, dbxref.accession, db.name, cvterm.name FROM cvterm LEFT JOIN cvtermprop using(cvterm_id) JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) WHERE cvterm.cvterm_id=?";
    my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
    $h->execute($cvterm_id);
    my $total_count = 0;
    while (my ($description, $scale, $accession, $db, $name) = $h->fetchrow_array()) {
        $total_count++;
        my @observation_vars = ();
        push @observation_vars, $name.'|'.$db.':'.$accession;
        %result = (
            traitDbId => $cvterm_id,
            traitId => $db.':'.$accession,
            name => $name,
            description => $description,
            observationVariables => \@observation_vars,
            defaultValue => '',
            scale =>$scale
        );
    }

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>[]);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
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
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub maps_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { } );

    my @data;
    while (my $row = $rs->next()) {
        my %map_info;
        print STDERR "Retrieving map info for ".$row->name()." ID:".$row->nd_protocol_id()."\n";
        #$self->bcs_schema->storage->debug(1);
        my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { 'genotypeprops.type_id' => $snp_genotyping_cvterm_id, 'me.nd_protocol_id' => $row->nd_protocol_id() } )->search_related('nd_experiment_protocols')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops', {}, {select=>['genotype.description', 'genotypeprops.value'], as=>['description', 'value'], rows=>1, order_by=>{ -asc => 'genotypeprops.genotypeprop_id' }} );

        my $lg_row = $lg_rs->first();

        if (!$lg_row) {
            die "This was never supposed to happen :-(";
        }

        my $scores = JSON::Any->decode($lg_row->get_column('value'));
        my %chrs;

        my $marker_count =0;
        foreach my $m (sort genosort (keys %$scores)) {
            my ($chr, $pos) = split "_", $m;
            #print STDERR "CHR: $chr. POS: $pos\n";
            $chrs{$chr} = $pos;
            $marker_count++;
        }
        my $lg_count = scalar(keys(%chrs));

        %map_info = (
            mapDbId =>  $row->nd_protocol_id(),
            name => $row->name(),
            species => $lg_row->get_column('description'),
            type => "physical",
            unit => "bp",
            markerCount => $marker_count,
            publishedDate => undef,
            comments => "",
            linkageGroupCount => $lg_count,
        );

        push @data, \%map_info;
    }

    my $total_count = scalar(@data);
    my $start = $c->stash->{page_size}*$c->stash->{current_page};
    my $end = $c->stash->{page_size}*($c->stash->{current_page}+1)-1;
    my @data_window = splice @data, $start, $end;

    my %result = (data => \@data_window);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>[]);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
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
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub maps_details_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my $params = $c->req->params();
    my $total_count = 0;

    my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'snp genotyping', 'genotype_property')->cvterm_id();

    # maps are just marker lists associated with specific protocols
    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->find( { nd_protocol_id => $c->stash->{map_id} } );
    my %map_info;
    my @data;

    print STDERR "Retrieving map info for ".$rs->name()."\n";
    #$self->bcs_schema->storage->debug(1);
    my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProtocol")->search( { 'genotypeprops.type_id' => $snp_genotyping_cvterm_id, 'me.nd_protocol_id' => $rs->nd_protocol_id() })->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops', {}, {rows=>1, order_by=>{ -asc => 'genotypeprops.genotypeprop_id' }} );

    if (!$lg_rs) {
        die "This was never supposed to happen :-(";
    }

    my %chrs;
    my %markers;
    my @ordered_refmarkers;
    while (my $profile = $lg_rs->next()) {
        my $profile_json = $profile->value();
        my $refmarkers = JSON::Any->decode($profile_json);
        #print STDERR Dumper($refmarkers);
        push @ordered_refmarkers, sort genosort keys(%$refmarkers);

    }

    foreach my $m (@ordered_refmarkers) {

        my ($chr, $pos) = split "_", $m;
        #print STDERR "CHR: $chr. POS: $pos\n";

        $markers{$chr}->{$m} = 1;
        if ($pos) {
            if ($chrs{$chr}) {
                if ($pos > $chrs{$chr}) {
                    $chrs{$chr} = $pos;
                }
            } else {
                $chrs{$chr} = $pos;
            }
        }

    }

    foreach my $ci (sort (keys %chrs)) {
        my $num_markers = scalar keys %{ $markers{$ci} };
        my %linkage_groups_data = (
            linkageGroupId => $ci,
            numberMarkers => $num_markers,
            maxPosition => $chrs{$ci}
        );
        push @data, \%linkage_groups_data;
    }

    $total_count = scalar(@data);
    my $start = $c->stash->{page_size}*$c->stash->{current_page};
    my $end = $c->stash->{page_size}*($c->stash->{current_page}+1)-1;
    my @data_window = splice @data, $start, $end;

    %map_info = (
        mapDbId =>  $rs->nd_protocol_id(),
        name => $rs->name(),
        type => "physical",
        unit => "bp",
        linkageGroups => \@data_window,
    );

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>[]);
    my %response = (metadata=>\%metadata, result=>\%map_info);
    $c->stash->{rest} = \%response;
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
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub maps_marker_detail_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my $params = $c->req->params();

    my %linkage_groups;
    if ($params->{linkageGroupIdList}) {
        my $linkage_groups_list = $params->{linkageGroupIdList};
        my @linkage_groups_array = split /,/, $linkage_groups_list;
        %linkage_groups = map { $_ => 1 } @linkage_groups_array;
    }

    my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->find( { nd_protocol_id => $c->stash->{map_id} } );

    my @markers;
    print STDERR "Retrieving map info for ".$rs->name()."\n";
      #$self->bcs_schema->storage->debug(1);
    my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { 'genotypeprops.type_id' => $snp_genotyping_cvterm_id, 'me.nd_protocol_id' => $rs->nd_protocol_id()})->search_related('nd_experiment_protocols')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops', {}, {rows=>1, order_by=>{ -asc => 'genotypeprops.genotypeprop_id' }} );

    if (!$lg_rs) {
        die "This was never supposed to happen :-(";
    }

    my @ordered_refmarkers;
    while (my $profile = $lg_rs->next()) {
      my $profile_json = $profile->value();
      my $refmarkers = JSON::Any->decode($profile_json);
      #print STDERR Dumper($refmarkers);
      push @ordered_refmarkers, sort genosort keys(%$refmarkers);
    }

  	my %chrs;

    	foreach my $m (@ordered_refmarkers) {
    	    my ($chr, $pos) = split "_", $m;
    	    #print STDERR "CHR: $chr. POS: $pos\n";
           $chrs{$chr} = $pos;
            #   "markerDbId": 1,
            #   "markerName": "marker1",
            #   "location": "1000",
            #   "linkageGroup": "1A"

            if (%linkage_groups) {
                if (exists $linkage_groups{$chr} ) {
                    if ($params->{min} && $params->{max}) {
                        if ($pos >= $params->{min} && $pos <= $params->{max}) {
                            push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
                        }
                    } elsif ($params->{min}) {
                        if ($pos >= $params->{min}) {
                            push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
                        }
                    } elsif ($params->{max}) {
                        if ($pos <= $params->{max}) {
                            push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
                        }
                    } else {
                        push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
                    }
                }
            } else {
                push @markers, { markerDbId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
            }

        }

    my $total_count = scalar(@markers);
    my $page_size = $c->stash->{page_size};
    if ($page_size == $DEFAULT_PAGE_SIZE) {
        $page_size = 100000;
    }
    my $start = $page_size*$c->stash->{current_page};
    my $end = $page_size*($c->stash->{current_page}+1)-1;
    my @data_window = splice @markers, $start, $end;

    my %result = (data => \@data_window);
    my %metadata = (pagination=>pagination_response($total_count, $page_size, $c->stash->{current_page}), status=>[$status], datafiles=>[]);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


sub locations_list : Chained('brapi') PathPart('locations') Args(0) : ActionClass('REST') { }

sub locations_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};

    $c->stash->{rest} = {status => $status};
}

sub locations_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @data;
    my @attributes;

    my $locations = CXGN::Trial::get_all_locations($self->bcs_schema);

    my $total_count = scalar(@$locations);
    my $start = $c->stash->{page_size}*$c->stash->{current_page};
    my $end = $c->stash->{page_size}*($c->stash->{current_page}+1)-1;
    for( my $i = $start; $i <= $end; $i++ ) {
        if (@$locations[$i]) {
            push @data, {
                locationDbId => @$locations[$i]->[0],
                locationType=>'',
                name=> @$locations[$i]->[1],
                abbreviation=>'',
                countryCode=> @$locations[$i]->[6],
                countryName=> @$locations[$i]->[5],
                latitude=>@$locations[$i]->[2],
                longitude=>@$locations[$i]->[3],
                altitude=>@$locations[$i]->[4],
                additionalInfo=> @$locations[$i]->[7]
            };
        }
    }

    my %result = (data=>\@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>[$status], datafiles=>[]);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}



sub authenticate : Chained('brapi') PathPart('authenticate/oauth') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->res->redirect("https://accounts.google.com/o/oauth2/auth?scope=profile&response_type=code&client_id=1068256137120-62dvk8sncnbglglrmiroms0f5d7lg111.apps.googleusercontent.com&redirect_uri=https://cassavabase.org/oauth2callback");

    $c->stash->{rest} = { success => 1 };


}


1;
