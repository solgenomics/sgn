
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
use CXGN::Trial::TrialCreate;
use CXGN::Trial::Search;
use CXGN::Location::LocationLookup;
use JSON;
use JSON qw( decode_json );
use Data::Dumper;
use Digest::MD5;
use Try::Tiny;
use File::Slurp qw | read_file |;
use Spreadsheet::WriteExcel;
use Time::Piece;

use CXGN::BrAPI;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
	# Leaving default Content-Type to not break everything. If data is passed that is not parsable as json, and the
	# data type is not handled in the map below, we get a catalyst error with a 200 response which is not ideal.
	default		  => 'application/json',
	stash_key     => 'rest',
	map           => {  'application/json' => 'JSON',
						# would be nice if we could do image/* instead of explicitly listing each type
						# also should see if a single list of image types can be used for this and for _get_extension in Images.pm
						'image/_*'  => [ 'Callback', { deserialize => \&deserialize_image, serialize => \&serialize_image } ],
						'image/jpeg'  => [ 'Callback', { deserialize => \&deserialize_image, serialize => \&serialize_image } ],
						'image/png'  => [ 'Callback', { deserialize => \&deserialize_image, serialize => \&serialize_image } ],
						'image/gif'  => [ 'Callback', { deserialize => \&deserialize_image, serialize => \&serialize_image } ],
						'image/svg+xml'  => [ 'Callback', { deserialize => \&deserialize_image, serialize => \&serialize_image } ],
						'application/pdf'  => [ 'Callback', { deserialize => \&deserialize_image, serialize => \&serialize_image } ],
						'application/postscript'  => [ 'Callback', { deserialize => \&deserialize_image, serialize => \&serialize_image } ],
	},
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

# don't do anything, let catalyst handle putting body into a temp file
sub deserialize_image {
	my ( $self, $data, $c ) = @_;
	# want $c->request->data to be undefined so that parsing in brapi sub skips it
	return;
}

# have to serialize the json because using the callbacks in the config map
sub serialize_image {
	my ( $self, $data, $c ) = @_;
	my $json = JSON->new->allow_nonref;
	$json->allow_tags;
	$json->allow_blessed;
	$json->convert_blessed;
	my $json_text = $json->encode( $c->stash->{rest} );

	$c->response->content_type('application/json');
	return $json_text;
}

sub brapi : Chained('/') PathPart('brapi') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $version = shift;
	my @status;

	my $page = $c->req->param("page") || 0;
	my $page_size = $c->req->param("pageSize") || $DEFAULT_PAGE_SIZE;
	my $authorization_token = $c->req->headers->header("Authorization");
	my $bearer_token = undef;

	if (defined $authorization_token) {
		my @bearer = split(/\s/, $authorization_token);
		if (scalar @bearer == 2) {
			if ($bearer[0] eq "Bearer") {
				$bearer_token = $bearer[1];
			}
		}
	}

	my $session_token = $c->req->headers->header("access_token") || $bearer_token;

	if (defined $c->request->data){
	    my $data_type = ref $c->request->data;
	    my $current_page;
	    $current_page = $c->request->data->{"page"} if ($data_type ne 'ARRAY');
	    my $current_page_size;
	    $current_page_size = $c->request->data->{"pageSize"} if ($data_type ne 'ARRAY');
	    my $current_session_token;
	    $current_session_token = $c->request->data->{"access_token"} if ($data_type ne 'ARRAY');
	    $page = $current_page || $page || 0;
	    $page_size = $current_page_size || $page_size || $DEFAULT_PAGE_SIZE;
	    $session_token = $current_session_token|| $session_token;
	}
	my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
	my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
	my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
	my $people_schema = $c->dbic_schema("CXGN::People::Schema");
	push @status, { 'INFO' => "BrAPI base call found with page=$page, pageSize=$page_size" };

	my $brapi = CXGN::BrAPI->new({
		version => $version,
		brapi_module_inst => {
			context => $c,
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
	$c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
	$c->stash->{session_token} = $session_token;

	if (defined $c->request->data){
		# All POST requests accept for search methods require a json array body
		if ($c->request->method eq "POST" && index($c->request->env->{REQUEST_URI}, "search") == -1){
			if (ref $c->request->data ne 'ARRAY') {
				my $response = CXGN::BrAPI::JSONResponse->return_error($c->stash->{status}, 'JSON array body required', 400);
				_standard_response_construction($c, $response);
			}
			$c->stash->{clean_inputs} = _clean_inputs($c->req->params,$c->request->data);
		} elsif ($c->request->method eq "PUT") {
			if (ref $c->request->data eq 'ARRAY') {
				my $response = CXGN::BrAPI::JSONResponse->return_error($c->stash->{status}, 'JSON hash body required', 400);
				_standard_response_construction($c, $response);
			}
			$c->stash->{clean_inputs} = $c->request->data;
		} else {
			$c->stash->{clean_inputs} = $c->request->data;
		}
	}
	else {
		$c->stash->{clean_inputs} = _clean_inputs($c->req->params);
	}
}

#useful because javascript can pass 'undef' as an empty value, and also standardizes all inputs as arrayrefs
sub _clean_inputs {
	no warnings 'uninitialized';
	my $params = shift;
	my $alldata = shift;

	if($alldata){
		my %data = ref $alldata eq 'ARRAY' ? map { $_ => $_} @{$alldata} : %{$alldata};
		%$params = $params ? (%data, %$params) : %data;
	}

	foreach (keys %$params){
		my $values = $params->{$_};
		my $ret_val;
		if (ref \$values eq 'SCALAR' || ref $values eq 'ARRAY'){

			if (ref \$values eq 'SCALAR') {
				push @$ret_val, $values;
			} elsif (ref $values eq 'ARRAY'){
				$ret_val = $values;
			}

			@$ret_val = grep {$_ ne undef} @$ret_val;
			@$ret_val = grep {$_ ne ''} @$ret_val;
			$_ =~ s/\[\]$//; #ajax POST with arrays adds [] to the end of the name e.g. germplasmName[]. since all inputs are arrays now we can remove the [].
			$params->{$_} = $ret_val;
		}
		elsif (ref $values eq 'HASH') {
			$params->{$_} = $values;
		}
		else {
			die "Input $_ is not a scalar, arrayref, or a single level hash\n";
		}

	}
	return $params;
}

sub _validate_request {
	my $c = shift;
	my $data_type = shift;
	my $data = shift;
	my $required_fields = shift;
	my $required_field_prefix = shift;

	if ($required_fields) {
		# Validate each array element
		if ($data_type eq 'ARRAY') {
			foreach my $object (values %{$data}) {
				# Ignore the query params if they were passed in. Their included in the body
				if (ref($object) eq 'HASH') {
					_validate_request($c, 'HASH', $object, $required_fields);
				}
			}
		}

		# Check all of our fields
		foreach my $required_field (@{$required_fields}) {
			# Check if the required field has another level or not
			if (ref($required_field) eq 'HASH') {
				# Check the field keys and recurse
				foreach my $sub_req_field (keys %{$required_field}) {
					if ($data_type eq 'HASH') {
						if (!$data->{$sub_req_field}) {
							_missing_field_response($c, $sub_req_field, $required_field_prefix);
						} else {
							my $sub_data = $data->{$sub_req_field};
							_validate_request($c, 'HASH', $sub_data, $required_field->{$sub_req_field},
								$required_field_prefix ? sprintf("%s.%s", $required_field_prefix, $sub_req_field): $sub_req_field);
						}
					}
				}
				next;
			}

			if ($data_type eq 'HASH') {
				if (!$data->{$required_field}) {
					_missing_field_response($c, $required_field, $required_field_prefix);
				}
			}
		}
	}
}

sub _missing_field_response {
	my $c = shift;
	my $field_name = shift;
	my $prefix = shift;
	my $response = CXGN::BrAPI::JSONResponse->return_error($c->stash->{status}, $prefix ? sprintf("%s.%s required", $prefix, $field_name) : sprintf("%s required", $field_name), 400);
	_standard_response_construction($c, $response);
}

sub _authenticate_user {
    my $c = shift;
	my $force_authenticate = shift;
    my $status = $c->stash->{status};
	my $user_id;
	my $user_type;
	my $user_pref;
	my $expired;
	my $wildcard = 'any';

        print STDERR "AUTHENTICATING USER status: $status\n";    
	my %server_permission;
    my $rc = eval{
	print STDERR "SERVER PERMISSION CHECK...\n";
		my $server_permission = $c->config->{"brapi_" . $c->request->method};
		my @server_permission  = split ',', $server_permission;
		%server_permission = map { $_ => 1 } @server_permission;
	1; };

	if(!$rc && !%server_permission){
		$server_permission{$wildcard} = 1;
	}

    print STDERR "SERVER CHECK DONE...\n";
	# Check if there is a config for default brapi user. This will be overwritten if a token is passed.
	# Will still throw error if auth is required
    if ($c->config->{brapi_default_user} && $c->config->{brapi_require_login} == 0) {
	print STDERR "BRAPI DEFAULT USER CHECK...\n";
		$user_id = CXGN::People::Person->get_person_by_username($c->dbc->dbh, $c->config->{brapi_default_user});
		$user_type = $c->config->{brapi_default_user_role};
		if (! defined $user_id) {
			my $brapi_package_result = CXGN::BrAPI::JSONResponse->return_error($status, 'Default brapi user was not found');
			_standard_response_construction($c, $brapi_package_result, 500);
		}
	}

	# If our brapi config is set to authenticate or the controller calling this asks for forcing of
    # authentication or serverinfo call method request auth, we authenticate.
    my $login = CXGN::Login->new($c->dbc->dbh); 
    if ($c->config->{brapi_require_login} == 1 || $force_authenticate || !exists($server_permission{$wildcard})){
	print STDERR "REQUIRE LOGIN... logging in user\n";
	print STDERR "SESSION TOKEN: ".$c->stash->{session_token}."\n";
	if ($c->stash->{session_token}) { 
	    ($user_id, $user_type, $user_pref, $expired) = $login->query_from_cookie($c->stash->{session_token});
	    print STDERR "LOGGING IN USER: ".$user_id." : ".$user_type." : ".$expired;
	}
	else { 
	    print STDERR "GET USER ID FROM LOGIN...\n";
	    if ($c->user) {
		$user_id = $c->user->get_object->get_sp_person_id();
		($user_type) = $c->user->get_object->get_user_type();
	   
		my $cookie_string = $login->get_login_cookie();
		print STDERR "USER ID: $user_id, EXPIRED: $expired, USER TYPE: $user_type\n";
		$c->stash->{session_token} = $login->get_login_cookie();
	    }
	}
          
        if (!$user_id || $expired || !$user_type || (!exists($server_permission{$user_type}) && !exists($server_permission{$wildcard}))) {
            my $brapi_package_result = CXGN::BrAPI::JSONResponse->return_error($status, 'You must login and have permission to access this BrAPI call.');

            _standard_response_construction($c, $brapi_package_result, 401);
        }
    }

    return (1, $user_id, $user_type, $user_pref, $expired);
}

sub _standard_response_construction {
	my $c = shift;
	my $brapi_package_result = shift;
	my $return_status = shift;
	my $status = $brapi_package_result->{status};
	my $pagination = $brapi_package_result->{pagination};
	my $result = $brapi_package_result->{result};
	my $datafiles = $brapi_package_result->{datafiles};

	# some older brapi stuff uses parameter, could refactor at some point
	if (!$return_status) { $return_status = $brapi_package_result->{http_code} };

	my %metadata = (pagination=>$pagination, status=>$status, datafiles=>$datafiles);
	my %response = (metadata=>\%metadata, result=>$result);
	$c->stash->{rest} = \%response;
	$c->response->status((!$return_status) ? 200 : $return_status);
	$c->detach;
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
   "access_token": "..."
   "expires_in": "The lifetime in seconds of the access token"
 }

For Logging out
DELETE Request:

{
    "access_token" : "..." // (optional, text, `R6gKDBRxM4HLj6eGi4u5HkQjYoIBTPfvtZzUD8TUzg4`) ... The user access token. Default: current user token.
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

sub authenticate_token_GET {
    my $self = shift;
    my $c = shift;
    process_authenticate_token($self,$c);
}

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

	my %metadata = (pagination=>$pagination, status=>$status, datafiles=>$datafiles);
	my %response = (metadata=>\%metadata, access_token=>$result->{access_token}, userDisplayName=>$result->{userDisplayName}, expires_in=>$CXGN::Login::LOGIN_TIMEOUT);
	$c->stash->{rest} = \%response;
    $c->detach();
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
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Calls');
	my $brapi_package_result = $brapi_module->search(
		$clean_inputs
	);
	_standard_response_construction($c, $brapi_package_result);
}

=head2 /brapi/v2/serverinfo

 Usage: For determining which endpoints have been implemented and with which datafile types and methods
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

sub serverinfo : Chained('brapi') PathPart('serverinfo') Args(0) : ActionClass('REST') { }

sub serverinfo_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ServerInfo');
	my $brapi_package_result = $brapi_module->search($c,$clean_inputs);
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

sub commoncropnames : Chained('brapi') PathPart('commoncropnames') Args(0) : ActionClass('REST') { }

sub commoncropnames_GET {
	my $self = shift;
	my $c = shift;
	my $supported_crop = $c->config->{'supportedCrop'};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('CommonCropNames');
	my $brapi_package_result = $brapi_module->crops($supported_crop);
	_standard_response_construction($c, $brapi_package_result);
}

sub observation_levels : Chained('brapi') PathPart('observationlevels') Args(0) : ActionClass('REST') { }

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
	my ($auth, $user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $postedData = $clean_inputs;
	my @data;
	foreach my $season (values %{$postedData}) {
		push @data, {
			seasonDbId=>$season->{year},
			season=>undef,
			year=>$season->{year}
		}
	}
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(scalar(@data), scalar(@data), 1);
	my %result = (data=>\@data);
	my @data_files;
	my $status;
	_standard_response_construction($c, CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, "Season created successfully"));
}

sub seasons_GET {
    my $self = shift;
    my $c = shift;
    seasons_process($self, $c);
}

sub seasons_process {
    my $self = shift;
    my $c = shift;
    my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Studies');
    my $brapi_package_result = $brapi_module->seasons(
        $clean_inputs->{year}->[0],
    );
    _standard_response_construction($c, $brapi_package_result);
}

sub season_single : Chained('brapi') PathPart('seasons') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $id = shift;
	$c->stash->{seasonDbId} = $id;
}

sub season_fetch : Chained('season_single') PathPart('') Args(0) : ActionClass('REST') { }


sub season_fetch_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Seasons');
	my $brapi_package_result = $brapi_module->detail($c->stash->{seasonDbId});
	_standard_response_construction($c, $brapi_package_result);
}

sub season_search  : Chained('brapi') PathPart('search/seasons') Args(0) : ActionClass('REST') { }

sub season_search_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Seasons');
}

sub season_search_retrieve : Chained('brapi') PathPart('search/seasons') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Seasons');
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

sub study_types : Chained('brapi') PathPart('studytypes') Args(0) : ActionClass('REST') { }

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
    my ($auth) = _authenticate_user($c);
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

sub germplasm_search_old  : Chained('brapi') PathPart('germplasm-search') Args(0) : ActionClass('REST') { }

sub germplasm_search_old_GET {
    my $self = shift;
    my $c = shift;
    my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Germplasm');
    my $brapi_package_result = $brapi_module->search({
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

sub germplasm_search_old_POST {
    my $self = shift;
    my $c = shift;
    # my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Germplasm');
    my $brapi_package_result = $brapi_module->search({
        germplasmName => $clean_inputs->{germplasmNames},
        accessionNumber => $clean_inputs->{accessionNumbers},
        germplasmGenus => $clean_inputs->{germplasmGenus},
        germplasmSubTaxa => $clean_inputs->{germplasmSubTaxa},
        germplasmSpecies => $clean_inputs->{germplasmSpecies},
        germplasmDbId => $clean_inputs->{germplasmDbIds},
        germplasmPUI => $clean_inputs->{germplasmPUIs},
        matchMethod => $clean_inputs->{matchMethod},
    });
    _standard_response_construction($c, $brapi_package_result);
}

sub germplasm  : Chained('brapi') PathPart('germplasm') Args(0) : ActionClass('REST') { }

sub germplasm_GET {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Germplasm');
    my $brapi_package_result = $brapi_module->search($clean_inputs,$c);

    _standard_response_construction($c, $brapi_package_result);
}

sub germplasm_POST {
    my $self = shift;
    my $c = shift;
    my ($auth,$user_id) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $data = $clean_inputs;
	my @all_germplasm;
	foreach my $germplasm (values %{$data}) {
		push @all_germplasm, $germplasm;
	}
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Germplasm');
    my $brapi_package_result = $brapi_module->store(\@all_germplasm,$user_id,$c);

    _standard_response_construction($c, $brapi_package_result);
}

sub germplasm_search_save  : Chained('brapi') PathPart('search/germplasm') Args(0) : ActionClass('REST') { }

sub germplasm_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Germplasm');
}

sub germplasm_search_retrieve  : Chained('brapi') PathPart('search/germplasm') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Germplasm');
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

sub germplasm_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Germplasm');
	my $brapi_package_result = $brapi_module->germplasm_detail(
		$c->stash->{stock_id},$c
	);
	_standard_response_construction($c, $brapi_package_result);
}

sub germplasm_detail_PUT {
    my $self = shift;
    my $c = shift;
    my ($auth,$user_id) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $data = $clean_inputs;
	my @all_germplasm;
	push @all_germplasm, $data;
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Germplasm');
    my $brapi_package_result = $brapi_module->update($c->stash->{stock_id},\@all_germplasm,$user_id,$c);

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

sub germplasm_mcpd  : Chained('germplasm_single') PathPart('mcpd') Args(0) : ActionClass('REST') { }

sub germplasm_mcpd_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Germplasm');
	my $brapi_package_result = $brapi_module->germplasm_mcpd(
		$c->stash->{stock_id}
	);
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
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	my @all_trials;
	foreach my $trials (values %{$data}) {
		push @all_trials, $trials;
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Trials');
	my $brapi_package_result = $brapi_module->store(\@all_trials,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub trials_search_process {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Trials');
	my $brapi_package_result = $brapi_module->search({
		crop => $c->config->{supportedCrop},
		contactDbIds => $clean_inputs->{contactDbId},
		searchDateRangeStart  => $clean_inputs->{searchDateRangeStart},
		searchDateRangeEnd  => $clean_inputs->{searchDateRangeEnd},
		trialPUIs => $clean_inputs->{trialPUI},
		externalReferenceIDs => $clean_inputs->{externalReferenceID},
		externalReferenceIds => $clean_inputs->{externalReferenceId},
		externalReferenceSources => $clean_inputs->{externalReferenceSource},
		active  => $clean_inputs->{active},
		commonCropNames  => $clean_inputs->{commonCropName},
		programDbIds => $clean_inputs->{programDbId},
		locationDbIds => $clean_inputs->{locationDbId},
		studyDbIds  => $clean_inputs->{studyDbId},
		trialDbIds  => $clean_inputs->{trialDbId},
		trialNames  => $clean_inputs->{trialName},

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

sub trials_detail_PUT {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	$data->{trialDbId} = $c->stash->{trial_id};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Trials');
	my $brapi_package_result = $brapi_module->update($data,$user_id,$c->config->{supportedCrop});
	_standard_response_construction($c, $brapi_package_result);
}

sub trials_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Trials');
	my $brapi_package_result = $brapi_module->details(
		$c->stash->{trial_id},
		$c->config->{supportedCrop}
	);
	_standard_response_construction($c, $brapi_package_result);
}

sub trials_search_save  : Chained('brapi') PathPart('search/trials') Args(0) : ActionClass('REST') { }

sub trials_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Trials');
}

sub trials_search_retrieve : Chained('brapi') PathPart('search/trials') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Trials');
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
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Germplasm');
	my $brapi_package_result = $brapi_module->germplasm_pedigree({
		stock_id => $c->stash->{stock_id},
		notation => $clean_inputs->{notation}->[0]
	});
	_standard_response_construction($c, $brapi_package_result);
}


=head2 brapi/v1/germplasm/{id}/progeny?notation=purdy

 Usage: To retrieve progeny (direct descendant) information for a single germplasm
 Desc:
 Return JSON example:
 {
    "metadata" : {
        "pagination": {},
        "status": [],
        "datafiles": []
    },
    "result" : {
       "germplasmDbId": "382",
       "defaultDisplayName": "Pahang",
       "data" : [{
          "progenyGermplasmDbId": "403",
          "parentType": "FEMALE"
       }, {
          "progenyGermplasmDbId": "402",
          "parentType": "MALE"
       }, {
          "progenyGermplasmDbId": "405",
          "parentType": "SELF"
       }]
    }
 }
 Args:
 Side Effects:

=cut

sub germplasm_progeny : Chained('germplasm_single') PathPart('progeny') Args(0) : ActionClass('REST') { }

sub germplasm_progeny_POST {
	my $self = shift;
	my $c = shift;
}

sub germplasm_progeny_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Germplasm');
	my $brapi_package_result = $brapi_module->germplasm_progeny({
		stock_id => $c->stash->{stock_id}
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub germplasm_attributes_detail  : Chained('germplasm_single') PathPart('attributes') Args(0) : ActionClass('REST') { }

sub germplasm_attributes_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
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
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Germplasm');
	my $brapi_package_result = $brapi_module->germplasm_markerprofiles(
		$c->stash->{stock_id}
	);
	_standard_response_construction($c, $brapi_package_result);
}


#
# Germplasm Attributes
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
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GermplasmAttributes');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub attribute_single  : Chained('brapi') PathPart('attributes') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $attribute_id = shift;

	$c->stash->{attribute_id} = $attribute_id;
}

sub attribute_detail  : Chained('attribute_single') PathPart('') Args(0) : ActionClass('REST') { }

sub attribute_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GermplasmAttributes');
	my $brapi_package_result = $brapi_module->detail($c->stash->{attribute_id});
	_standard_response_construction($c, $brapi_package_result);
}

sub germplasm_attribute_categories_list  : Chained('brapi') PathPart('attributes/categories') Args(0) : ActionClass('REST') { }

sub germplasm_attribute_categories_list_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GermplasmAttributes');
	my $brapi_package_result = $brapi_module->germplasm_attributes_categories_list();
	_standard_response_construction($c, $brapi_package_result);
}

sub attributes_save : Chained('brapi') PathPart('search/attributes') Args(0) : ActionClass('REST') { }

sub attributes_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'GermplasmAttributes');
}

sub attributes_retrieve  : Chained('brapi') PathPart('search/attributes') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'GermplasmAttributes');
}


sub germplasm_attributes_values  : Chained('brapi') PathPart('attributevalues') Args(0) : ActionClass('REST') { }

sub germplasm_attributes_values_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GermplasmAttributeValues');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub germplasm_attributes_values_single  : Chained('brapi') PathPart('attributevalues') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $value_id = shift;

	$c->stash->{value_id} = $value_id;
}

sub germplasm_attributes_values_detail  : Chained('germplasm_attributes_values_single') PathPart('') Args(0) : ActionClass('REST') { }

sub germplasm_attributes_values_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	$clean_inputs->{attributeValueDbId}=[$c->stash->{value_id}];
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GermplasmAttributeValues');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub attributes_values_save : Chained('brapi') PathPart('search/attributevalues') Args(0) : ActionClass('REST') { }

sub attributes_values_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'GermplasmAttributeValues');
}

sub attributes_values_retrieve  : Chained('brapi') PathPart('search/attributevalues') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'GermplasmAttributeValues');
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
    my ($auth) = _authenticate_user($c);
    my $default_protocol = $self->bcs_schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$c->config->{default_genotyping_protocol}});
    my $default_protocol_id = $default_protocol ? $default_protocol->nd_protocol_id : 0;
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Markerprofiles');
    my $brapi_package_result = $brapi_module->markerprofiles_search({
        cache_file_path => $c->config->{cache_file_path},
        shared_cluster_dir => $c->config->{cluster_shared_tempdir},
        study_ids => $clean_inputs->{studyDbId},
        stock_ids => $clean_inputs->{germplasmDbId},
        extract_ids => $clean_inputs->{extractDbId},
        sample_ids => $clean_inputs->{sampleDbId},
        protocol_ids => $clean_inputs->{methodDbId}
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
    my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Markerprofiles');
    my $brapi_package_result = $brapi_module->markerprofiles_detail({
        cache_file_path => $c->config->{cache_file_path},
        shared_cluster_dir => $c->config->{cluster_shared_tempdir},
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
	my ($auth) = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Markerprofiles');
	my $brapi_package_result = $brapi_module->markerprofiles_methods();
	_standard_response_construction($c, $brapi_package_result);
}



=head2 brapi/v1/allelematrices-search?markerprofileDbId=100&markerprofileDbId=101

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

sub allelematrices : Chained('brapi') PathPart('allelematrices-search') Args(0) : ActionClass('REST') { }

sub allelematrices_POST {
    my $self = shift;
    my $c = shift;
    allelematrix_search_process($self, $c);
}

sub allelematrices_GET {
    my $self = shift;
    my $c = shift;
    allelematrix_search_process($self, $c);
}

sub allelematrices_new : Chained('brapi') PathPart('allelematrices') Args(0) : ActionClass('REST') { }

sub allelematrices_new_GET {
    my $self = shift;
    my $c = shift;
    allelematrix_search_process($self, $c);
}

sub allelematrices_cached : Chained('brapi') PathPart('search/allelematrices') Args(0) : ActionClass('REST') { }

sub allelematrices_cached_POST {
    my $self = shift;
    my $c = shift;
    allelematrix_search_process($self, $c);
}

sub allelematrices_cached_GET {
    my $self = shift;
    my $c = shift;
    allelematrix_search_process($self, $c);
}


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
    # my ($auth) = _authenticate_user($c);

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
        cache_file_path => $c->config->{cache_file_path},
        shared_cluster_dir => $c->config->{cluster_shared_tempdir},
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


=head2 brapi/v2/plates

=cut

sub plates : Chained('brapi') PathPart('plates') Args(0) : ActionClass('REST') { }

sub plates_GET {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Plates');
	my $brapi_package_result = $brapi_module->search($clean_inputs,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub plates_single  : Chained('brapi') PathPart('plates') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $plate_id = shift;

	$c->stash->{plate_id} = $plate_id;
}

sub plates_detail  : Chained('plates_single') PathPart('') Args(0) : ActionClass('REST') { }

sub plates_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Plates');
	my $brapi_package_result = $brapi_module->detail($c->stash->{plate_id},$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub plates_search_save : Chained('brapi') PathPart('search/plates') Args(0) : ActionClass('REST') { }

sub plates_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Plates');
}

sub plates_search_retrieve  : Chained('brapi') PathPart('search/Plates') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Plates');
}


=head2 brapi/v2/lists

=cut

sub lists : Chained('brapi') PathPart('lists') Args(0) : ActionClass('REST') { }

sub lists_GET {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c, $c->config->{brapi_lists_require_login});
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Lists');
	my $brapi_package_result;
	if($c->config->{brapi_lists_require_login}) {
		$brapi_package_result = $brapi_module->search($clean_inputs, $user_id, 1, $c->config->{main_production_site_url});
	} else {
		$brapi_package_result = $brapi_module->search($clean_inputs, undef, 0, $c->config->{main_production_site_url});
	}
	_standard_response_construction($c, $brapi_package_result);
}

sub lists_POST {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	my @all_lists;
	foreach my $list (values %{$data}) {
		push @all_lists, $list;
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Lists');
	my $brapi_package_result = $brapi_module->store(\@all_lists,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub list_single  : Chained('brapi') PathPart('lists') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $list_id = shift;

	$c->stash->{list_id} = $list_id;
}

sub list_detail  : Chained('list_single') PathPart('') Args(0) : ActionClass('REST') { }

sub list_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Lists');
	my $brapi_package_result = $brapi_module->detail($c->stash->{list_id},$user_id, $c->config->{main_production_site_url});
	_standard_response_construction($c, $brapi_package_result);
}

sub list_detail_PUT {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	$data->{listDbId} = $c->stash->{list_id};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Lists');
	my $brapi_package_result = $brapi_module->update($data,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub list_items  : Chained('list_single') PathPart('items') Args(0) : ActionClass('REST') { }

sub list_items_POST {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Lists');
	my $brapi_package_result = $brapi_module->store_items($c->stash->{list_id},$clean_inputs,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub list_data  : Chained('list_single') PathPart('data') Args(0) : ActionClass('REST') { }

sub list_data_POST {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Lists');
	my $brapi_package_result = $brapi_module->store_items($c->stash->{list_id},$clean_inputs,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}


sub list_search_save : Chained('brapi') PathPart('search/lists') Args(0) : ActionClass('REST') { }

sub list_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Lists');
}

sub list_search_retrieve  : Chained('brapi') PathPart('search/lists') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Lists');
}

=head2 brapi/v2/people

=cut

sub people : Chained('brapi') PathPart('people') Args(0) : ActionClass('REST') { }

sub people_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('People');
	my $brapi_package_result = $brapi_module->search($clean_inputs,$c);
	_standard_response_construction($c, $brapi_package_result);
}

sub people_single  : Chained('brapi') PathPart('people') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $people_id = shift;

	$c->stash->{people_id} = $people_id;
}

sub people_detail  : Chained('people_single') PathPart('') Args(0) : ActionClass('REST') { }

sub people_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('People');
	my $brapi_package_result = $brapi_module->detail($c->stash->{people_id},$c);
	_standard_response_construction($c, $brapi_package_result);
}

sub people_search_save : Chained('brapi') PathPart('search/people') Args(0) : ActionClass('REST') { }

sub people_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'People');
}

sub people_search_retrieve  : Chained('brapi') PathPart('search/people') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'People');
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
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	my @all_programs;
	foreach my $program (values %{$data}) {
		push @all_programs, $program;
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Programs');

	my $brapi_package_result = $brapi_module->store(\@all_programs, $user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub programs_list_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Programs');
	my $brapi_package_result = $brapi_module->search({
		program_names => $clean_inputs->{programName},
		programNames => $clean_inputs->{programName},
		abbreviations => $clean_inputs->{abbreviation},
		externalReferenceIDs => $clean_inputs->{externalReferenceID},
		externalReferenceSources => $clean_inputs->{externalReferenceSource},
		commonCropNames => $clean_inputs->{commonCropName},
        crop => $c->config->{supportedCrop}
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub programs_single  : Chained('brapi') PathPart('programs') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $program_id = shift;

	$c->stash->{program_id} = $program_id;
}

sub programs_detail  : Chained('programs_single') PathPart('') Args(0) : ActionClass('REST') { }

sub programs_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Programs');
	my $brapi_package_result = $brapi_module->detail(
		$c->stash->{program_id},
		$c->config->{supportedCrop}
	);
	_standard_response_construction($c, $brapi_package_result);
}

sub programs_detail_PUT {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $user_id = undef;
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	$data->{programDbId} = $c->stash->{program_id};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Programs');
	my $brapi_package_result = $brapi_module->update($data,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub programs_search_save : Chained('brapi') PathPart('search/programs') Args(0) : ActionClass('REST') { }

sub programs_search_save_POST {
    my $self = shift;
    my $c = shift; #print $self;
    save_results($self,$c,$c->stash->{clean_inputs},'Programs');
}

sub programs_search_retrieve  : Chained('brapi') PathPart('search/programs') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Programs');
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

sub studies_search  : Chained('brapi') PathPart('studies-search') Args(0) : ActionClass('REST') { }

sub studies_search_POST {
    my $self = shift;
    my $c = shift;
    # my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Studies');
    my $brapi_package_result = $brapi_module->search({
        programDbIds => $clean_inputs->{programDbIds},
        programNames => $clean_inputs->{programNames},
        studyDbIds => $clean_inputs->{studyDbIds},
        studyNames => $clean_inputs->{studyNames},
        trialDbIds => $clean_inputs->{trialDbIds},
        trialNames => $clean_inputs->{trialNames},
        studyLocationDbIds => $clean_inputs->{locationDbIds},
        studyLocationNames => $clean_inputs->{studyLocations},
        studyTypeName => $clean_inputs->{studyType},
        germplasmDbIds => $clean_inputs->{germplasmDbIds},
        germplasmNames => $clean_inputs->{germplasmNames},
        seasons => $clean_inputs->{seasonDbIds},
        observationVariableDbIds => $clean_inputs->{observationVariableDbIds},
        observationVariableNames => $clean_inputs->{observationVariableNames},
        active => $clean_inputs->{active}->[0],
        sortBy => $clean_inputs->{sortBy}->[0],
        sortOrder => $clean_inputs->{sortOrder}->[0],
    }, $c);
    _standard_response_construction($c, $brapi_package_result);
}

sub studies_search_GET {
    my $self = shift;
    my $c = shift;
    my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Studies');
    my $brapi_package_result = $brapi_module->search({
        programDbIds => $clean_inputs->{programDbId},
        programNames => $clean_inputs->{programName},
        studyDbIds => $clean_inputs->{studyDbId},
        studyNames => $clean_inputs->{studyName},
        trialDbIds => $clean_inputs->{trialDbId},
        trialNames => $clean_inputs->{trialName},
        studyLocationDbIds => $clean_inputs->{locationDbId},
        studyLocationNames => $clean_inputs->{locationName},
        seasons => $clean_inputs->{seasonDbId},
        studyTypeName => $clean_inputs->{studyType},
        germplasmDbIds => $clean_inputs->{germplasmDbId},
        germplasmNames => $clean_inputs->{germplasmName},
        observationVariableDbIds => $clean_inputs->{observationVariableDbId},
        observationVariableNames => $clean_inputs->{observationVariableName},
        active => $clean_inputs->{active}->[0],
        sortBy => $clean_inputs->{sortBy}->[0],
        sortOrder => $clean_inputs->{sortOrder}->[0],
    }, $c);
    _standard_response_construction($c, $brapi_package_result);
}

sub studies  : Chained('brapi') PathPart('studies') Args(0) : ActionClass('REST') { }

sub studies_GET {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Studies');
    my $brapi_package_result = $brapi_module->search({
        programDbIds => $clean_inputs->{programDbId},
        programNames => $clean_inputs->{programName},
        studyDbIds => $clean_inputs->{studyDbId},
        studyNames => $clean_inputs->{studyName},
        trialDbIds => $clean_inputs->{trialDbId},
        trialNames => $clean_inputs->{trialName},
        studyLocationDbIds => $clean_inputs->{locationDbId},
        studyLocationNames => $clean_inputs->{locationName},
        seasons => $clean_inputs->{seasonDbId},
        seasonDbIds => $clean_inputs->{seasonDbId},
        studyTypes => $clean_inputs->{studyType},
        germplasmDbIds => $clean_inputs->{germplasmDbId},
        germplasmNames => $clean_inputs->{germplasmName},
        observationVariableDbIds => $clean_inputs->{observationVariableDbId},
        observationVariableNames => $clean_inputs->{observationVariableName},
        crop => $c->config->{supportedCrop},
        active => $clean_inputs->{active}->[0],
        sortBy => $clean_inputs->{sortBy}->[0],
        sortOrder => $clean_inputs->{sortOrder}->[0],
        commonCropNames => $clean_inputs->{commonCropName},
    }, $c);
    _standard_response_construction($c, $brapi_package_result);
}

sub studies_POST {
    my $self = shift;
    my $c = shift;
    my ($auth, $user_id) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $data = $clean_inputs;
	_validate_request($c, 'ARRAY', $data, ['trialDbId', 'studyName', 'studyType', 'locationDbId', {'experimentalDesign' => ['PUI']}]);

    my @all_studies;
	foreach my $study (values %{$data}) {
	    push @all_studies, $study;
	}
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Studies');
    my $brapi_package_result = $brapi_module->store(\@all_studies, $user_id, $c);
    _standard_response_construction($c, $brapi_package_result);
}

sub studies_search_save  : Chained('brapi') PathPart('search/studies') Args(0) : ActionClass('REST') { }

sub studies_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Studies');
}

sub studies_search_retrieve : Chained('brapi') PathPart('search/studies') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Studies');
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
	my ($auth) = _authenticate_user($c);

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
	my ($auth) = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->studies_germplasm(
		$c->stash->{study_id}
	);
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
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->detail(
		$c->stash->{study_id},
        $c->config->{main_production_site_url},
		$c->config->{supportedCrop}
	);
	_standard_response_construction($c, $brapi_package_result);
}

sub studies_info_PUT {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	_validate_request($c, 'HASH', $data, ['trialDbId', 'studyName', 'studyType', 'locationDbId', {'experimentalDesign' => ['PUI']}]);
	$data->{studyDbId} = $c->stash->{study_id};

	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->update($data,$user_id,$c);
	_standard_response_construction($c, $brapi_package_result);
}

sub studies_observation_variables : Chained('studies_single') PathPart('observationvariables') Args(0) : ActionClass('REST') { }

sub studies_observation_variables_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub studies_observation_variables_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->studies_observation_variables(
		$c->stash->{study_id},
        $c->config->{supportedCrop}
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
    my ($auth) = _authenticate_user($c);
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

sub studies_layouts : Chained('studies_single') PathPart('layouts') Args(0) : ActionClass('REST') { }

sub studies_layouts_GET {
    my $self = shift;
    my $c = shift;
    my $clean_inputs = $c->stash->{clean_inputs};
    my ($auth) = _authenticate_user($c);
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


=head2 brapi/v1/studies/<studyDbId>/observationunits?observationVariableDbId=2

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

sub studies_observations_GET {
	my $self = shift;
	my $c = shift;
	my $clean_inputs = $c->stash->{clean_inputs};
	# my ($auth) = _authenticate_user($c);
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

sub studies_table_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);

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
		exclude_phenotype_outlier => $clean_inputs->{exclude_phenotype_outlier}->[0],
		trait_ids => $clean_inputs->{observationVariableDbId},
		trial_ids => $clean_inputs->{studyDbId},
		format => $format,
		main_production_site_url => $c->config->{main_production_site_url},
		file_path => $file_path,
		file_uri => $uri
	})
	;
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

sub studies_observations_granular_PUT {
    my $self = shift;
	my $c = shift;
    my $clean_inputs = $c->stash->{clean_inputs};
    my $observations = $clean_inputs->{observations};
    #print STDERR "Observations are ". Dumper($observations) . "\n";
	save_observation_results($self, $c, $observations, 'v1');
}

sub studies_observations_granular_GET {
	my $self = shift;
	my $c = shift;
	my $clean_inputs = $c->stash->{clean_inputs};
	my ($auth) = _authenticate_user($c);
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Studies');
	my $brapi_package_result = $brapi_module->observation_units_granular({
		study_id => $c->stash->{study_id},
		observationVariableDbIds => $clean_inputs->{observationVariableDbId},
		data_level => $clean_inputs->{observationLevel}->[0],
		search_type => $clean_inputs->{search_type}->[0],
		exclude_phenotype_outlier => $clean_inputs->{exclude_phenotype_outlier}->[0],
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
                             "observationVariableDbId": 35,
                             "season": "2005",
                             "observationValue" : "red",
                             "observationTimeStamp": null,
                             "quality": "reliability of the observation",
                             "collectionFacilityLabel":  "phenodyne",
                             "collector" : "John Doe and team"
                         },
                         {
                             "instanceNumber" : 1,
                             "observationVariableDbId": 35,
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
    # my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('ObservationUnits');
    my $brapi_package_result = $brapi_module->search($c->stash->{clean_inputs});
    _standard_response_construction($c, $brapi_package_result);
}

sub phenotypes_search_GET {
	my $self = shift;
	my $c = shift;
    my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('ObservationUnits');
    my $brapi_package_result = $brapi_module->search($c->stash->{clean_inputs});
    _standard_response_construction($c, $brapi_package_result);
}

# Observation units

sub observation_units :  Chained('brapi') PathPart('observationunits') Args(0) ActionClass('REST') { }

sub observation_units_GET {

	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationUnits');
	my $brapi_package_result = $brapi_module->search($c->stash->{clean_inputs}, $c);
	_standard_response_construction($c, $brapi_package_result);
}

sub observation_units_POST {

	my $self = shift;
	my $c = shift;
	# The observation units need an operator, so login required
	my $force_authenticate = $c->config->{brapi_observation_units_require_login};
	my ($auth,$user_id) = _authenticate_user($c, $force_authenticate);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	_validate_request($c, 'ARRAY', $data, [
		'studyDbId',
		'observationUnitName',
		{
		'observationUnitPosition' => [
			{
				'observationLevel' => ['levelName', 'levelCode'],
			}
		]
		}
	]);
	my @all_units;
	foreach my $unit (values %{$data}) {
		push @all_units, $unit;
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationUnits');
	my $brapi_package_result = $brapi_module->observationunits_store(\@all_units,$c,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub observation_units_PUT {

	my $self = shift;
	my $c = shift;
	my $force_authenticate = $c->config->{brapi_observation_units_require_login};
	my ($auth,$user_id) = _authenticate_user($c, $force_authenticate);
	my $clean_inputs = $c->stash->{clean_inputs};
	my %data = %$clean_inputs;
    my @all_units;
    foreach my $unit (keys %data) {
        my $observationUnitDbId = $unit;
        my $units = $data{$unit};
        $units->{observationUnitDbId} = $observationUnitDbId;
        push @all_units, $units;
    }
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationUnits');
	my $brapi_package_result = $brapi_module->observationunits_update(\@all_units,$c,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub observation_units_table : Chained('brapi') PathPart('observationunits/table') Args(0) : ActionClass('REST') { }

sub observation_units_table_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationTables');
	my $brapi_package_result = $brapi_module->search_observationunit_tables($c->stash->{clean_inputs});
	_standard_response_construction($c, $brapi_package_result);
}

sub observation_unit_single :  Chained('brapi') PathPart('observationunits') Args(1) ActionClass('REST') {
	my $self = shift;
	my $c = shift;
	my $observation_unit_db_id = shift;

	$c->stash->{observation_unit_db_id} = $observation_unit_db_id;
 }

sub observation_unit_single_PUT {
    my $self = shift;
    my $c = shift;
    my $observation_unit_db_id = shift;
    my $clean_inputs = $c->stash->{clean_inputs};
    my ($auth) = _authenticate_user($c);
    my $observationUnits = $clean_inputs;
    $observationUnits->{observationUnitDbId} = $observation_unit_db_id;
    my @all_observations_units;
    push @all_observations_units, $observationUnits;
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('ObservationUnits');
    my $brapi_package_result = $brapi_module->observationunits_update(\@all_observations_units, $c);

    _standard_response_construction($c, $brapi_package_result);
}

sub observation_unit_single_GET {
	my $self = shift;
	my $c = shift;
    my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('ObservationUnits');
    my $brapi_package_result = $brapi_module->detail(
    	 $c->stash->{observation_unit_db_id}, $c);
    _standard_response_construction($c, $brapi_package_result);
}

sub observation_units_search_save : Chained('brapi') PathPart('search/observationunits') Args(0) : ActionClass('REST') { }

sub observation_units_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'ObservationUnits');
}

sub observation_units_search_retrieve  : Chained('brapi') PathPart('search/observationunits') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'ObservationUnits');
}


sub phenotypes_search_table : Chained('brapi') PathPart('phenotypes-search/table') Args(0) : ActionClass('REST') { }

sub phenotypes_search_table_POST {
	my $self = shift;
	my $c = shift;
	process_phenotypes_search_table($self, $c);
}

sub phenotypes_search_table_GET {
	my $self = shift;
	my $c = shift;
	process_phenotypes_search_table($self, $c);
}

sub process_phenotypes_search_table {
	my $self = shift;
	my $c = shift;
	# my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationTables');
	my $brapi_package_result = $brapi_module->search_table($c->stash->{clean_inputs});
	_standard_response_construction($c, $brapi_package_result);
}

sub observation_tables_search_save : Chained('brapi') PathPart('search/observationtables') Args(0) : ActionClass('REST') { }

sub observation_tables_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'ObservationTables');
}

sub observation_tables_search_retrieve  : Chained('brapi') PathPart('search/observationtables') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'ObservationTables');
}

sub phenotypes_search_csv : Chained('brapi') PathPart('phenotypes-search/csv') Args(0) : ActionClass('REST') { }

sub phenotypes_search_csv_POST {
	my $self = shift;
	my $c = shift;
	process_phenotypes_search_csv($self, $c);
}

sub phenotypes_search_csv_GET {
	my $self = shift;
	my $c = shift;
	process_phenotypes_search_csv($self, $c);
}

sub process_phenotypes_search_csv {
	my $self = shift;
	my $c = shift;
	# my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $dir = $c->tempfiles_subdir('download');
	my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
	my $temp_file_name = $time_stamp . "phenotype_download_csv"."_XXXX";
	my ($file_path, $uri) = $c->tempfile( TEMPLATE => "download/$temp_file_name");

	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Phenotypes');
	my $brapi_package_result = $brapi_module->search_table_csv_or_tsv({
		trait_ids => $clean_inputs->{observationVariableDbIds},
		accession_ids => $clean_inputs->{germplasmDbIds},
		study_ids => $clean_inputs->{studyDbIds},
		location_ids => $clean_inputs->{locationDbIds},
		years => $clean_inputs->{seasonDbIds},
		data_level => $clean_inputs->{observationLevel}->[0],
		search_type => $clean_inputs->{search_type}->[0],
		exclude_phenotype_outlier => $clean_inputs->{exclude_phenotype_outlier}->[0],
        format => 'csv',
		main_production_site_url => $c->config->{main_production_site_url},
		file_path => $file_path,
		file_uri => $uri
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub phenotypes_search_tsv : Chained('brapi') PathPart('phenotypes-search/tsv') Args(0) : ActionClass('REST') { }

sub phenotypes_search_tsv_POST {
	my $self = shift;
	my $c = shift;
	process_phenotypes_search_tsv($self, $c);
}

sub phenotypes_search_tsv_GET {
	my $self = shift;
	my $c = shift;
	process_phenotypes_search_tsv($self, $c);
}

sub process_phenotypes_search_tsv {
	my $self = shift;
	my $c = shift;
	# my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $dir = $c->tempfiles_subdir('download');
	my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
	my $temp_file_name = $time_stamp . "phenotype_download_tsv"."_XXXX";
	my ($file_path, $uri) = $c->tempfile( TEMPLATE => "download/$temp_file_name");

	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Phenotypes');
	my $brapi_package_result = $brapi_module->search_table_csv_or_tsv({
		trait_ids => $clean_inputs->{observationVariableDbIds},
		accession_ids => $clean_inputs->{germplasmDbIds},
		study_ids => $clean_inputs->{studyDbIds},
		location_ids => $clean_inputs->{locationDbIds},
		years => $clean_inputs->{seasonDbIds},
		data_level => $clean_inputs->{observationLevel}->[0],
		search_type => $clean_inputs->{search_type}->[0],
		exclude_phenotype_outlier => $clean_inputs->{exclude_phenotype_outlier}->[0],
        format => 'tsv',
		main_production_site_url => $c->config->{main_production_site_url},
		file_path => $file_path,
		file_uri => $uri
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
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Traits');
	my $brapi_package_result = $brapi_module->list({
        trait_ids => $clean_inputs->{traitDbIds},
        names => $clean_inputs->{names}
    }, $c);
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
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Traits');
	my $brapi_package_result = $brapi_module->detail(
		$c->stash->{trait_id}, $c
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
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GenomeMaps');
	my $brapi_package_result = $brapi_module->list({
        config => $c->config,
        mapDbId => $clean_inputs->{mapDbId},
        commonCropName => $clean_inputs->{commonCropName},
        scientificName => $clean_inputs->{scientificName},
        type => $clean_inputs->{type},
    });

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
	my ($auth) = _authenticate_user($c);
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
	my ($auth) = _authenticate_user($c);
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
	my ($auth) = _authenticate_user($c);
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

=head2 brapi/v2/maps/map_id/linkagegroups
=cut

sub maps_marker_detail_lg : Chained('maps_single') PathPart('linkagegroups') Args(0) : ActionClass('REST') { }

sub maps_marker_detail_lg_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('GenomeMaps');
	my $brapi_package_result = $brapi_module->linkagegroups({
		map_id => $c->stash->{map_id},
		linkage_group_ids => $clean_inputs->{linkageGroupId},
		min => $clean_inputs->{min}->[0],
		max => $clean_inputs->{max}->[0],
	});
	_standard_response_construction($c, $brapi_package_result);
}

=head2 brapi/v2/markerpositions
=cut

sub maps_markerpositions : Chained('brapi') PathPart('markerpositions') Args(0) : ActionClass('REST') { }

sub maps_markerpositions_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('MarkerPositions');
	my $brapi_package_result = $brapi_module->search({
		mapDbId => $clean_inputs->{mapDbId},
		variantDbId => $clean_inputs->{variantDbId},
		linkageGroupName => $clean_inputs->{linkageGroupName},
		maxPosition => $clean_inputs->{maxPosition},
		minPosition => $clean_inputs->{minPosition},
	}, $c );
	_standard_response_construction($c, $brapi_package_result);
}

sub maps_markerpositions_save  : Chained('brapi') PathPart('search/markerpositions') Args(0) : ActionClass('REST') { }

sub maps_markerpositions_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'MarkerPositions');
}

sub maps_markerpositions_retrieve : Chained('brapi') PathPart('search/markerpositions') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'MarkerPositions');
}

=head2 brapi/<version>/locations

 Usage: To retrieve locations.
 Desc:
 Return JSON example:
 Args:
 Side Effects:

=cut

sub locations_list : Chained('brapi') PathPart('locations') Args(0) : ActionClass('REST') { }

sub locations_list_POST {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	my @all_locations;
	foreach my $location (values %{$data}) {
		push @all_locations, $location;
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Locations');
	my $brapi_package_result = $brapi_module->store(\@all_locations,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub locations_list_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Locations');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub locations_detail : Chained('brapi') PathPart('locations') Args(1) : ActionClass('REST') { }

sub locations_detail_GET {
	my $self = shift;
	my $c = shift;
	my $location_id = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Locations');
	my $brapi_package_result = $brapi_module->detail($location_id);
	_standard_response_construction($c, $brapi_package_result);
}

sub locations_detail_PUT {
	my $self = shift;
	my $c = shift;
	my $location_id = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $user_id = undef;
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	my @all_locations;
	$data->{locationDbId} = $location_id;
	push @all_locations, $data;
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Locations');
	my $brapi_package_result = $brapi_module->store(\@all_locations,$user_id);
	# Format the response to be single hash
	$brapi_package_result->{result} = $brapi_package_result->{result}->{data}[0];
	_standard_response_construction($c, $brapi_package_result);
}

sub locations_search_save  : Chained('brapi') PathPart('search/locations') Args(0) : ActionClass('REST') { }

sub locations_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Locations');
}

sub locations_search_retrieve : Chained('brapi') PathPart('search/locations') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Locations');
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
	my ($auth) = _authenticate_user($c);
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
	my ($auth) = _authenticate_user($c);

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
		name_spaces => \@namespaces,
		ontologyDbId => $clean_inputs->{ontologyDbId}
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub observationvariable_search : Chained('brapi') PathPart('variables-search') Args(0) : ActionClass('REST') { }

sub observationvariable_search_POST {
	my $self = shift;
	my $c = shift;
	_observationvariable_search_process($self, $c);
}

sub observationvariable_search_GET {
	my $self = shift;
	my $c = shift;
	_observationvariable_search_process($self, $c);
}

sub _observationvariable_search_process {
	my $self = shift;
	my $c = shift;
    # my ($auth) = _authenticate_user($c);

	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
	my $brapi_package_result = $brapi_module->search({
		observationvariable_db_ids => $clean_inputs->{observationVariableDbId},
		ontology_db_names => $clean_inputs->{ontologyXref},
		ontology_dbxref_terms => $clean_inputs->{ontologyDbId},
		method_db_ids => $clean_inputs->{methodDbId},
		scale_db_ids => $clean_inputs->{scaleDbId},
		observationvariable_names => $clean_inputs->{name},
		observationvariable_datatypes => $clean_inputs->{datatype},
		observationvariable_classes => $clean_inputs->{traitClass},
		studyDbIds => $clean_inputs->{studyDbId},
	}, $c);
	_standard_response_construction($c, $brapi_package_result);
}

sub variables_search_save  : Chained('brapi') PathPart('search/variables') Args(0) : ActionClass('REST') { }

sub variables_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'ObservationVariables');
}

sub variables_search_retrieve : Chained('brapi') PathPart('search/variables') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'ObservationVariables');
}

sub observationvariable_list : Chained('brapi') PathPart('variables') Args(0) : ActionClass('REST') { }

# Endpoint for POST variables
sub observationvariable_list_POST {
	my $self = shift;
	my $c = shift;

	my $can_post_variables = $c->config->{brapi_post_variables};
	if (not $can_post_variables){
		my $error = CXGN::BrAPI::JSONResponse->return_error([], "Not configured to post Observation Variables");
		_standard_response_construction($c, $error, 404);
	}

	my $force_authenticate = $c->config->{brapi_variables_require_login};
	my ($auth,$user_id) = _authenticate_user($c, $force_authenticate);

	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	_validate_request($c, 'ARRAY', $data, [
		'observationVariableName',
		{'scale' => ['dataType', 'scaleName']},
		{'method' => ['methodName', 'methodClass']},
		{'trait' => ['traitName', 'status']}
	]);

	my $response;
	try {
		my @all_variables;
		foreach my $variable (values %{$data}) {
			push @all_variables, $variable;
		}

		my $brapi = $self->brapi_module;
		my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
		$response = $brapi_module->store(\@all_variables, $c);
	} catch {
		if ($_->isa('CXGN::BrAPI::Exceptions::ConflictException')){
			my $error = CXGN::BrAPI::JSONResponse->return_error([], $_->message);
			_standard_response_construction($c, $error, 409);
		} else {
			warn Dumper($_);
			my $error = CXGN::BrAPI::JSONResponse->return_error([], "An unknown error has occurred.");
			_standard_response_construction($c, $error, 500);
		}
	};

	_standard_response_construction($c, $response);
}

sub observationvariable_list_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $supported_crop = $c->config->{'supportedCrop'};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
	my $brapi_package_result = $brapi_module->search({
		observationVariableDbIds => $clean_inputs->{observationVariableDbId},
		traitClasses => $clean_inputs->{traitClass},
		studyDbIds => $clean_inputs->{studyDbId},
		externalReferenceIds => $clean_inputs->{externalReferenceId},
		externalReferenceSources => $clean_inputs->{externalReferenceSource},
		supportedCrop =>$supported_crop,
	}, $c);
	_standard_response_construction($c, $brapi_package_result);
}

sub observationvariable_detail : Chained('brapi') PathPart('variables') Args(1) : ActionClass('REST') { }

sub observationvariable_detail_GET {
	my $self = shift;
	my $c = shift;
	my $trait_id = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $supported_crop = $c->config->{'supportedCrop'};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
	my $brapi_package_result = $brapi_module->detail(
		$trait_id,$c
	);
	_standard_response_construction($c, $brapi_package_result);
}

# Endpoint for PUT variables
sub observationvariable_detail_PUT {
	my $self = shift;
	my $c = shift;
	my $variableDbId = shift;
	my $force_authenticate = $c->config->{brapi_variables_require_login};
	my ($auth,$user_id) = _authenticate_user($c, $force_authenticate);

	my $can_put_variables = $c->config->{brapi_put_variables};
	if (not $can_put_variables){
		my $error = CXGN::BrAPI::JSONResponse->return_error([], "Not configured to update Observation Variables");
		_standard_response_construction($c, $error, 404);
	}

	my $response;
	try {
		my $clean_inputs = $c->stash->{clean_inputs};
		#TODO: Parse into a trait object to check bad requests
		my $data = $clean_inputs;
		$data->{observationVariableDbId} = $variableDbId;

		my $brapi = $self->brapi_module;
		my $brapi_module = $brapi->brapi_wrapper('ObservationVariables');
		$response = $brapi_module->update($data,$c);
	} catch {
		warn Dumper($_);
		if ($_->isa('CXGN::BrAPI::Exceptions::NotFoundException')){
			my $error = CXGN::BrAPI::JSONResponse->return_error([], $_->message);
			_standard_response_construction($c, $error, 404);
		} else {
			my $error = CXGN::BrAPI::JSONResponse->return_error([], "An unknown error has occurred.");
			_standard_response_construction($c, $error, 500);
		}
	};

	_standard_response_construction($c, $response);
}


sub samples_list : Chained('brapi') PathPart('samples-search') Args(0) : ActionClass('REST') { }

sub samples_list_POST {
    my $self = shift;
    my $c = shift;
    _sample_search_process($self, $c);
}

sub samples_list_GET {
    my $self = shift;
    my $c = shift;
    _sample_search_process($self, $c);
}

sub _sample_search_process {
    my $self = shift;
    my $c = shift;
    # my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Samples');
    my $brapi_package_result = $brapi_module->search({
        sampleDbId => $clean_inputs->{sampleDbId},
        sampleName => $clean_inputs->{sampleName},
        plateDbId => $clean_inputs->{plateDbId},
        plateName => $clean_inputs->{plateName},
        germplasmDbId => $clean_inputs->{germplasmDbId},
        germplasmName => $clean_inputs->{germplasmName},
        observationUnitDbId => $clean_inputs->{observationUnitDbId},
        observationUnitName => $clean_inputs->{observationUnitName},
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub samples : Chained('brapi') PathPart('samples') Args(0) : ActionClass('REST') { }

sub samples_GET {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Samples');
    my $brapi_package_result = $brapi_module->search($clean_inputs);
    _standard_response_construction($c, $brapi_package_result);
}

sub samples_list_search : Chained('brapi') PathPart('search/samples') Args(0) : ActionClass('REST') { }

sub samples_list_search_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Samples');
}

sub samples_list_search_retrieve : Chained('brapi') PathPart('search/samples') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Samples');
}


=head2 brapi/v1/samples/<sampleDbId>

Usage: To retrieve details for a specific sample
Desc:
Return JSON example:
{
    "metadata": {
        "pagination" : {
            "pageSize":0,
            "currentPage":0,
            "totalCount":0,
            "totalPages":0
        },
        "status" : [],
        "datafiles": []
    },
    "result": {
      "sampleDbId": "Unique-Plant-SampleID",
      "observationUnitDbId": "abc123",
      "germplasmDbId": "def456",
      "studyDbId": "StudyId-123",
      "plotDbId": "PlotId-123",
      "plantDbId" : "PlantID-123",
      "plateDbId": "PlateID-123",
      "plateIndex": 0,
      "takenBy": "Mr. Technician",
      "sampleTimestamp": "2016-07-27T14:43:22+0100",
      "sampleType" : "TypeOfSample",
      "tissueType" : "TypeOfTissue",
      "notes": "Cut from infected leaf",
    }
}
=cut

sub samples_single : Chained('brapi') PathPart('samples') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $sample_id = shift;

    $c->stash->{sample_id} = $sample_id;
}


sub sample_details : Chained('samples_single') PathPart('') Args(0) : ActionClass('REST') { }

sub sample_details_POST {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
}

sub sample_details_GET {
    my $self = shift;
    my $c = shift;
    my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Samples');
    my $brapi_package_result = $brapi_module->detail(
    	$c->stash->{sample_id}
    );
    _standard_response_construction($c, $brapi_package_result);
}





sub authenticate : Chained('brapi') PathPart('authenticate/oauth') Args(0) {
    my $self = shift;
    my $c = shift;

    my $host = $c->config->{main_production_site_url};
    $c->res->redirect("https://accounts.google.com/o/oauth2/auth?scope=profile&response_type=code&client_id=1068256137120-62dvk8sncnbglglrmiroms0f5d7lg111.apps.googleusercontent.com&redirect_uri=$host/oauth2callback");

    $c->stash->{rest} = { success => 1 };


}

=head2 brapi/v1/phenotypes

 Usage: To store phenotypes
 Desc:
 Request body example:
 {
  "data": [
    {
      "observationUnitDbId": "observationUnitDbId0",
      "observations": [
        {
          "collector": "collector0",
          "observationDbId": "observationDbId0",
          "observationTimeStamp": "2018-01-01T14:47:23-0600",
          "observationVariableDbId": "observationVariableDbId0",
          "observationVariableName": "observationVariableName0",
          "season": "season0",
          "value": "value0"
        },
        {
          "collector": "collector1",
          "observationDbId": "observationDbId1",
          "observationTimeStamp": "2018-01-01T14:47:23-0600",
          "observationVariableDbId": "observationVariableDbId1",
          "observationVariableName": "observationVariableName1",
          "season": "season1",
          "value": "value1"
        }
      ],
      "studyDbId": "studyDbId0"
    },
    {
      "observationUnitDbId": "observationUnitDbId1",
      "observations": [
        {
          "collector": "collector0",
          "observationDbId": "observationDbId0",
          "observationTimeStamp": "2018-01-01T14:47:23-0600",
          "observationVariableDbId": "observationVariableDbId0",
          "observationVariableName": "observationVariableName0",
          "season": "season0",
          "value": "value0"
        },
        {
          "collector": "collector1",
          "observationDbId": "observationDbId1",
          "observationTimeStamp": "2018-01-01T14:47:23-0600",
          "observationVariableDbId": "observationVariableDbId1",
          "observationVariableName": "observationVariableName1",
          "season": "season1",
          "value": "value1"
        }
      ],
      "studyDbId": "studyDbId1"
    }
  ]
}

 Response JSON example:
 {
  "metadata": {
    "datafiles": [],
    "pagination": {
      "currentPage": 0,
      "pageSize": 1000,
      "totalCount": 2,
      "totalPages": 1
    },
    "status": []
  },
  "result": {
    "data": [
      {
        "germplasmDbId": "8383",
        "germplasmName": "Pahang",
        "observationDbId": "12345",
        "observationLevel": "plot",
        "observationTimestamp": "2015-11-05T15:12:56+01:00",
        "observationUnitDbId": "11",
        "observationUnitName": "ZIPA_68_Ibadan_2014",
        "observationVariableDbId": "CO_334:0100632",
        "observationVariableName": "Yield",
        "operator": "Jane Doe",
        "studyDbId": "35",
        "uploadedBy": "dbUserId",
        "value": "5"
      }
    ]
  }
}
 Args:
 Side Effects:

=cut

sub phenotypes : Chained('brapi') PathPart('phenotypes') Args(0) : ActionClass('REST') { }

sub phenotypes_POST {
	my $self = shift;
	my $c = shift;
    my $clean_inputs = $c->stash->{clean_inputs};
    my $data = $clean_inputs->{data};
    my @all_observations;
    foreach my $observationUnit (@{$data}) {
        my $observationUnitDbId = $observationUnit->{observationUnitDbId};
        my $observations = $observationUnit->{observations};
        foreach my $observation (@{$observations}) {
            $observation->{observationUnitDbId} = $observationUnitDbId;
            push @all_observations, $observation;
        }
    }
	save_observation_results($self, $c, \@all_observations, 'v1');
}

=head2 brapi/v2/observations

 Usage: To store observations
 Desc:
 Request body example:
 {
  "observations": [
    {
      "collector": "string", //optional
      "observationDbId": "string", // if populated then update existing otherwise add new
      "observationTimeStamp": "2018-06-19T18:59:45.751Z", //optional
      "observationUnitDbId": "string", //required
      "observationVariableDbId": "string", //required
      "value": "string" //required
    }
  ]
}
 Response JSON example:
 {
  "metadata": {
    "datafiles": [],
    "pagination": {
      "currentPage": 0,
      "pageSize": 1000,
      "totalCount": 2,
      "totalPages": 1
    },
    "status": []
  },
  "result": {
    "data": [
      {
        "germplasmDbId": "8383",
        "germplasmName": "Pahang",
        "observationDbId": "12345",
        "observationLevel": "plot",
        "observationTimestamp": "2015-11-05T15:12:56+01:00",
        "observationUnitDbId": "11",
        "observationUnitName": "ZIPA_68_Ibadan_2014",
        "observationVariableDbId": "CO_334:0100632",
        "observationVariableName": "Yield",
        "operator": "Jane Doe",
        "studyDbId": "35",
        "uploadedBy": "dbUserId",
        "value": "5"
      }
    ]
  }
}
 Args:
 Side Effects:

=cut

sub observations : Chained('brapi') PathPart('observations') Args(0) : ActionClass('REST') { }

sub observations_PUT {
	my $self = shift;
	my $c = shift;
	my $version = $c->request->captures->[0];
	my $brapi_package_result;
	if ($version eq 'v2'){
		my $force_authenticate = $c->config->{brapi_observations_require_login};
		my ($auth,$user_id,$user_type) = _authenticate_user($c,$force_authenticate);
	    my $clean_inputs = $c->stash->{clean_inputs};
	    my %observations = %$clean_inputs;
	    my @all_observations;
	    foreach my $observation (keys %observations) {
	        my $observationDbId = $observation;
	        my $observations = $observations{$observation};
	        $observations->{observationDbId} = $observationDbId;
	        push @all_observations, $observations;
	    }
		my $brapi = $self->brapi_module;
		my $brapi_module = $brapi->brapi_wrapper('Observations');
		$brapi_package_result = $brapi_module->observations_store({
			observations => \@all_observations,
	        user_id => $user_id,
	        user_type => $user_type,
	        overwrite => 1,
	    },$c);
	} elsif ($version eq 'v1'){
		my $clean_inputs = $c->stash->{clean_inputs};
	    my $observations = $clean_inputs->{observations};
		save_observation_results($self, $c, $observations, 'v1');
	}

	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);

	_standard_response_construction($c, $brapi_package_result, $http_status_code);
}

sub observations_GET {
	my $self = shift; 
	my $c = shift;
    my $auth = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Observations');
    my $brapi_package_result = $brapi_module->search({
        observationLevel => $clean_inputs->{observationLevel},
        seasonDbId => $clean_inputs->{seasonDbId},
        locationDbId => $clean_inputs->{locationDbId},
        studyDbId => $clean_inputs->{studyDbId},
        germplasmDbId => $clean_inputs->{germplasmDbId},
        programDbId => $clean_inputs->{programDbId},
        observationTimeStampRangeStart => $clean_inputs->{observationTimeStampRangeStart},
        observationTimeStampRangeEnd => $clean_inputs->{observationTimeStampRangeEnd},
        observationUnitDbId => $clean_inputs->{observationUnitDbId},
        observationDbId => $clean_inputs->{observationDbId},
        observationVariableDbId => $clean_inputs->{observationVariableDbId}

    });
    _standard_response_construction($c, $brapi_package_result);
}

sub observations_POST {
	my $self = shift;
	my $c = shift;
    my $force_authenticate = $c->config->{brapi_observations_require_login};
	my ($auth,$user_id,$user_type) = _authenticate_user($c, $force_authenticate);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $data = $clean_inputs;
    my @all_observations;
    foreach my $observation (values %{$data}) {
        push @all_observations, $observation;
    }
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Observations');
	my $brapi_package_result = $brapi_module->observations_store({
		observations => \@all_observations,
        user_id => $user_id,
        user_type => $user_type,
        overwrite => 0,
    },$c);

	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);

	_standard_response_construction($c, $brapi_package_result, $http_status_code);
}

sub observations_table : Chained('brapi') PathPart('observations/table') Args(0) : ActionClass('REST') { }

sub observations_table_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ObservationTables');
	my $brapi_package_result = $brapi_module->search($c->stash->{clean_inputs});
	_standard_response_construction($c, $brapi_package_result);
}

sub observations_single :  Chained('brapi') PathPart('observations') CaptureArgs(1) {
     my $self = shift;
     my $c = shift;
     print STDERR " Capturing id\n";
     $c->stash->{observation_id} = shift;
}

sub observations_detail :  Chained('observations_single') PathPart('') Args(0) ActionClass('REST') { }

sub observations_detail_GET {
    my $self = shift;
    my $c = shift;
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Observations');
    my $brapi_package_result = $brapi_module->detail({
    	observationDbId => $c->stash->{observation_id}
    });
    _standard_response_construction($c, $brapi_package_result);
}

sub observations_detail_PUT {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id,$user_type) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $observations = $clean_inputs;
    my @all_observations;
    $observations->{observationDbId} = $c->stash->{observation_id};
    push @all_observations, $observations;

	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Observations');
	my $brapi_package_result = $brapi_module->observations_store({
		observations => \@all_observations,
        user_id => $user_id,
        user_type => $user_type,
        overwrite => 1,
    },$c);


	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);

	_standard_response_construction($c, $brapi_package_result, $http_status_code);
}

sub observation_search_save : Chained('brapi') PathPart('search/observations') Args(0) : ActionClass('REST') { }

sub observation_search_save_POST {
   my $self = shift;
   my $c = shift;
   save_results($self,$c,$c->stash->{clean_inputs},'Observations');
}

sub observation_search_retrieve  : Chained('brapi') PathPart('search/observations') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Observations');
}

sub save_observation_results {
    my $self = shift;
    my $c = shift;
    my $observations = shift;
    my $version = shift;

	# Check that the user is a user. We don't check other permissions for now.
	my $force_authenticate = $c->config->{brapi_observations_require_login};
	my ($auth_success, $user_id, $user_type, $user_pref, $expired) = _authenticate_user($c, $force_authenticate);

	my $dbh = $c->dbc->dbh;
    my $p = CXGN::People::Person->new($dbh, $user_id);
    my $username = $p->get_username;
    my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

	my $brapi_module = $brapi->brapi_wrapper('Observations');
	my $brapi_package_result = $brapi_module->observations_store({
        observations => $observations,
        user_id => $user_id,
        username => $username,
        user_type => $user_type,
        version => $version,
        archive_path => $c->config->{archive_path},
        tempfiles_subdir => $c->config->{basepath}."/".$c->config->{tempfiles_subdir},
        basepath => $c->config->{basepath},
        dbhost => $c->config->{dbhost},
        dbname => $c->config->{dbname},
        dbuser => $c->config->{dbuser},
        dbpass => $c->config->{dbpass},
        temp_file_nd_experiment_id => $temp_file_nd_experiment_id
    },$c);

	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);

	_standard_response_construction($c, $brapi_package_result, $http_status_code);
 }

=head2 brapi/v1/markers

 Usage: To retrieve markers
 Desc: BrAPI v1.3
 Args:
 Side Effects: deprecated on BrAPI v2.0

=cut

sub markers_search  : Chained('brapi') PathPart('markers') Args(0) : ActionClass('REST') { }

sub markers_search_GET {
    my $self = shift;
    my $c = shift;
    my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Markers');
	my $brapi_package_result = $brapi_module->search();
	_standard_response_construction($c, $brapi_package_result);
}

sub markers_search_save  : Chained('brapi') PathPart('search/markers') Args(0) : ActionClass('REST') { }

sub markers_search_save_POST {
    my $self = shift;
    my $c = shift; #print "--\n-" ; print Dumper($self); print "--\n-" ;
    save_results($self,$c,$c->stash->{clean_inputs},'Markers');
}

sub markers_search_retrieve : Chained('brapi') PathPart('search/markers') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Markers');
}


=head2 brapi/v2/variants

 Usage: To retrieve variants
 Desc: BrAPI v2.0
 Args:
 Side Effects:

=cut

sub variants_search  : Chained('brapi') PathPart('variants') Args(0) : ActionClass('REST') { }

sub variants_search_GET {
    my $self = shift;
    my $c = shift;
    my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Variants');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub variants_single :  Chained('brapi') PathPart('variants') CaptureArgs(1) {
     my $self = shift;
     my $c = shift;
     print STDERR " Capturing variants id\n";
     $c->stash->{variants_id} = shift;
}

sub variants_detail :  Chained('variants_single') PathPart('') Args(0) ActionClass('REST') { }

sub variants_detail_GET {
    my $self = shift;
    my $c = shift;
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Variants');
    my $brapi_package_result = $brapi_module->detail({
    	variantDbId => $c->stash->{variants_id}
    });
    _standard_response_construction($c, $brapi_package_result);
}

sub variants_calls_detail : Chained('variants_single') PathPart('calls') Args(0) : ActionClass('REST') { }

sub variants_calls_detail_POST {
	my $self = shift;
	my $c = shift;
	#my $auth = _authenticate_user($c);
}

sub variants_calls_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Variants');
	my $brapi_package_result = $brapi_module->calls({
		variantDbId => $c->stash->{variants_id},
		variantSetDbId => $c->stash->{variantSetDbId},
		unknown_string => $clean_inputs->{unknownString}->[0],
		sep_phased => $clean_inputs->{sepPhased}->[0],
		sep_unphased => $clean_inputs->{sepUnphased}->[0],
		expand_homozygotes => $clean_inputs->{expandHomozygotes}->[0],
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub variants_search_save  : Chained('brapi') PathPart('search/variants') Args(0) : ActionClass('REST') { }

sub variants_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Variants');
}

sub variants_search_retrieve : Chained('brapi') PathPart('search/variants') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Variants');
}


=head2 brapi/v1/observations-search

 Usage: To retrieve observations
 Desc:
 Request body example:
 {
    "collector": ["string","string"], //optional
    "observationDbId": ["string","string"], //optional
    "observationUnitDbId": ["string","string"], //optional
    "observationVariableDbId": ["string","string"] //optional
}
 Response JSON example:
 {
  "metadata": {
    "datafiles": [],
    "pagination": {
      "currentPage": 0,
      "pageSize": 1000,
      "totalCount": 2,
      "totalPages": 1
    },
    "status": []
  },
  "result": {
    "data": [
      {
        "germplasmDbId": "8383",
        "germplasmName": "Pahang",
        "observationDbId": "12345",
        "observationLevel": "plot",
        "observationTimestamp": "2015-11-05T15:12:56+01:00",
        "observationUnitDbId": "11",
        "observationUnitName": "ZIPA_68_Ibadan_2014",
        "observationVariableDbId": "CO_334:0100632",
        "observationVariableName": "Yield",
        "operator": "Jane Doe",
        "studyDbId": "35",
        "uploadedBy": "dbUserId",
        "value": "5"
      }
    ]
  }
}
 Args:
 Side Effects:

=cut

sub observations_search  : Chained('brapi') PathPart('observations-search') Args(0) : ActionClass('REST') { }

sub observations_search_POST {
	my $self = shift;
	my $c = shift;
	observations_search_process($self, $c);
}

sub observations_search_GET {
	my $self = shift;
	my $c = shift;
	observations_search_process($self, $c);
}

sub observations_search_process {
	my $self = shift;
	my $c = shift;
	# my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Observations');
	my $brapi_package_result = $brapi_module->search({
        collectors => $clean_inputs->{collectors},
        observationDbIds => $clean_inputs->{observationDbIds},
        observationUnitDbIds => $clean_inputs->{observationUnitDbIds},
        observationVariableDbIds => $clean_inputs->{observationVariableDbIds}
	});
	_standard_response_construction($c, $brapi_package_result);
}

=head2 brapi/<version>/events
 Usage: To retrieve events (events are treatments/management factors in the database)
 Desc:
 Request body example:
 {
}
 Response JSON example:
 {
     "@context": [
         "https://brapi.org/jsonld/context/metadata.jsonld"
     ],
     "metadata": {
         "datafiles": [
             {
                 "fileDescription": "This is an Excel data file",
                 "fileMD5Hash": "c2365e900c81a89cf74d83dab60df146",
                 "fileName": "datafile.xlsx",
                 "fileSize": 4398,
                 "fileType": "application/vnd.ms-excel",
                 "fileURL": "https://wiki.brapi.org/examples/datafile.xlsx"
             }
         ],
         "pagination": {
             "currentPage": 0,
             "pageSize": 1000,
             "totalCount": 10,
             "totalPages": 1
         },
         "status": [
             {
                 "message": "Request accepted, response successful",
                 "messageType": "INFO"
             }
         ]
     },
     "result": {
         "data": [
             {
                 "additionalInfo": {},
                 "date": [
                     "2018-10-08T18:15:11Z",
                     "2018-11-09T18:16:12Z"
                 ],
                 "eventDbId": "8566d4cb",
                 "eventDescription": "A set of plots was watered",
                 "eventParameters": [
                     {
                         "key": "http://www.example.fr/vocabulary/2018#hasContact,",
                         "value": "http://www.example.fr/id/agent/marie,",
                         "valueRdfType": "http://xmlns.com/foaf/0.1/Agent,"
                     },
                     {
                         "key": "fertilizer",
                         "value": "nitrogen",
                         "valueRdfType": null
                     }
                 ],
                 "eventType": "Watering",
                 "eventTypeDbId": "4e7d691e",
                 "observationUnitDbIds": [
                     "8439eaff",
                     "d7682e7a",
                     "305ae51c"
                 ],
                 "studyDbId": "2cc2001f"
             }
         ]
     }
 }
 Args:
 Side Effects:
=cut

sub events_search  : Chained('brapi') PathPart('events') Args(0) : ActionClass('REST') { }

sub events_search_POST {
	my $self = shift;
	my $c = shift;
	events_search_process($self, $c);
}

sub events_search_GET {
	my $self = shift;
	my $c = shift;
	events_search_process($self, $c);
}

sub events_search_process {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Events');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

=head2 brapi/<version>/images

 Usage: To retrieve observations
 Desc:
 Request body example:
 {
}
 Response JSON example:

{
  "metadata": {
    "datafiles": [
    ],
    "pagination": {
      "currentPage": 0,
      "pageSize": 1000,
      "totalCount": 10,
      "totalPages": 1
    },
    "status": [
      {
        "message": "Request accepted, response successful",
        "messageType": "INFO"
      }
    ]
  },
  "result": {
    "data": [
      {
        "additionalInfo": {},
        "copyright": "Copyright 2018 Bob Robertson",
        "description": "This is a picture of a tomato",
        "descriptiveOntologyTerms": [],
        "externalReferences": [
          {
            "referenceID": "doi:10.155454/12349537E12",
            "referenceSource": "DOI"
          }
        ],
        "imageDbId": "a55efb9c",
        "imageFileName": "image_0000231.jpg",
        "imageFileSize": 50000,
        "imageHeight": 550,
        "imageLocation": {
          "geometry": {
            "coordinates": [
              -76.506042,
              42.417373,
              123
            ],
            "type": "Point"
          },
          "type": "Feature"
        },
        "imageName": "Tomato Image 1",
        "imageTimeStamp": "2018-01-01T14:47:23-0600",
        "imageURL": "https://wiki.brapi.org/images/tomato",
        "imageWidth": 700,
        "mimeType": "image/jpeg",
        "observationDbIds": [
          "d05dd235",
          "8875177d"
        ],
        "observationUnitDbId": "b7e690b6"
      }
    ]
  }
 }

 Args:
 Side Effects:

=cut

sub images : Chained('brapi') PathPart('images') Args(0) : ActionClass('REST') { }

sub images_GET {
	my $self = shift;
	my $c = shift;
    my ($auth) = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Images');
    my $brapi_package_result = $brapi_module->search($clean_inputs, $c->config->{main_production_site_url});
    _standard_response_construction($c, $brapi_package_result);
}

sub images_POST {
    my $self = shift;
    my $c = shift;
    
    # Check user auth. This matches observations PUT observations endpoint authorization.
    # No specific roles are check, just that the user has an account.
    my $force_authenticate = $c->config->{brapi_images_require_login};
    my ($auth_success, $user_id, $user_type, $user_pref, $expired) = _authenticate_user($c, $force_authenticate);
    
    my $clean_inputs = $c->stash->{clean_inputs};
    my @all_images;
    foreach my $image (values %{$clean_inputs}) {
	push @all_images, $image;
    }
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Images');
    my $image_dir = File::Spec->catfile($c->config->{static_datasets_path}, $c->config->{image_dir});

    my $brapi_package_result = $brapi_module->image_metadata_store(\@all_images, $image_dir, $user_id, $user_type, $c->config->{main_production_site_url});
    my $status = $brapi_package_result->{status};
    my $http_status_code = _get_http_status_code($status);
    
    _standard_response_construction($c, $brapi_package_result, $http_status_code);
}

sub images_by_id :  Chained('brapi') PathPart('images') CaptureArgs(1) {
     my $self = shift;
     my $c = shift;
     print STDERR "Images_base... capturing image_id\n";
     $c->stash->{image_id} = shift;
}

sub images_single :  Chained('images_by_id') PathPart('') Args(0) ActionClass('REST') { }

sub images_single_GET {
    my $self = shift;
    my $c = shift;
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Images');
    my $brapi_package_result = $brapi_module->detail( { image_id => $c->stash->{image_id} }, $c->config->{main_production_site_url} );
    _standard_response_construction($c, $brapi_package_result);
}

# /brapi/v1/images PUT
# sub image_store :  Chained('brapi') PathPart('images') Args(0) ActionClass('REST') { }

sub images_single_PUT {
    my $self = shift;
    my $c = shift;

	# Check user auth. This matches observations PUT observations endpoint authorization.
	# No specific roles are check, just that the user has an account.
	my $force_authenticate = $c->config->{brapi_images_require_login};
	my ($auth_success, $user_id, $user_type, $user_pref, $expired) = _authenticate_user($c, $force_authenticate);

    my $clean_inputs = $c->stash->{clean_inputs};
    my $image = $clean_inputs;
    $image->{imageDbId} = $c->stash->{image_id};
    my @all_images;
    push @all_images, $image;
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Images');
    my $image_dir = File::Spec->catfile($c->config->{static_datasets_path}, $c->config->{image_dir});
    my $brapi_package_result = $brapi_module->image_metadata_store(\@all_images, $image_dir, $user_id, $user_type, $c->stash->{image_id});
	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);

    _standard_response_construction($c, $brapi_package_result, $http_status_code);

 }

 # /brapi/v1/images/<image_id>/imagecontent
sub image_content_store :  Chained('images_by_id') PathPart('imagecontent') Args(0) ActionClass('REST') { }

sub image_content_store_PUT {
    my $self = shift;
    my $c = shift;
    
    # Check user auth. This matches observations PUT observations endpoint authorization.
    # No specific roles are check, just that the user has an account.
    my $force_authenticate = $c->config->{brapi_images_require_login};
    my ($auth_success, $user_id, $user_type, $user_pref, $expired) = _authenticate_user($c, $force_authenticate);
    
    my $clean_inputs = $c->stash->{clean_inputs};
    print STDERR Dumper($clean_inputs);print Dumper $c->req->body();
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Images');
    my $image_dir = File::Spec->catfile($c->config->{static_datasets_path}, $c->config->{image_dir});

    my $brapi_package_result = $brapi_module->image_data_store($image_dir, $c->stash->{image_id}, $c->req->body(), $c->req->content_type(), $c->config->{main_production_site_url});

	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);

	_standard_response_construction($c, $brapi_package_result, $http_status_code);
 }

sub image_search_save  : Chained('brapi') PathPart('search/images') Args(0) : ActionClass('REST') { }

sub image_search_save_POST {
    my $self = shift;
    my $c = shift; #print "--\n-" ; print Dumper($self); print "--\n-" ;
    save_results($self,$c,$c->stash->{clean_inputs},'Images');
}

sub image_search_retrieve : Chained('brapi') PathPart('search/images') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Images');
}

sub _get_http_status_code {
	my $status = shift;
	my $http_status_code = 200;

	foreach(@$status) {

		if ($_->{messageType} eq "403") {
			$http_status_code = 403;
			last;
		}
		elsif ($_->{messageType} eq "401") {
			$http_status_code = 401;
			last;
		}
		elsif ($_->{messageType} eq "400") {
			$http_status_code = 400;
			last;
		}
		elsif ($_->{messageType} eq "200") {
			$http_status_code = 200;
			last;
		}
	}

	return $http_status_code;
}

=head2 brapi/v2/callsets

 Usage: To retrieve data for callsets
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
                "data": [
			      {
			        "additionalInfo": {},
			        "callSetDbId": "eb2bfd3d",
			        "callSetName": "Sample_123_DNA_Run_456",
			        "created": "2018-01-01T14:47:23-0600",
			        "sampleDbId": "5e50e11d",
			        "studyDbId": "708149c1",
			        "updated": "2018-01-01T14:47:23-0600",
			        "variantSetIds": [
			          "cfd3d60f",
			          "a4e8bfe9"
			        ]
			      }
			    ]
           }
        }
 Args:
 Side Effects:

=cut

sub callsets : Chained('brapi') PathPart('callsets') Args(0) : ActionClass('REST') { }

sub callsets_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('CallSets');
	my $brapi_package_result = $brapi_module->search({
		variantSetDbId => $clean_inputs->{variantSetDbId},
        sampleDbId => $clean_inputs->{sampleDbId},
        callSetName => $clean_inputs->{callSetName},
        # studyDbId => $clean_inputs->{studyDbId},
        germplasmDbId => $clean_inputs->{germplasmDbId},
        callSetDbId => $clean_inputs->{callSetDbId},
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub callsets_single : Chained('brapi') PathPart('callsets') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $id = shift;
	$c->stash->{callset_id} = $id;
}

sub callsets_fetch : Chained('callsets_single') PathPart('') Args(0) : ActionClass('REST') { }

sub callsets_fetch_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('CallSets');
	my $brapi_package_result = $brapi_module->detail({
		callset_id => $c->stash->{callset_id},
		unknown_string => $clean_inputs->{unknownString}->[0],
		sep_phased => $clean_inputs->{sepPhased}->[0],
		sep_unphased => $clean_inputs->{sepUnphased}->[0],
		expand_homozygotes => $clean_inputs->{expandHomozygotes}->[0],
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub callsets_call_detail : Chained('callsets_single') PathPart('calls') Args(0) : ActionClass('REST') { }

sub callsets_call_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('CallSets');
	my $brapi_package_result = $brapi_module->calls({
		callset_id => $c->stash->{callset_id},
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub callsets_call_filter_detail : Chained('callsets_single') PathPart('calls') Args(1) : ActionClass('REST') { }

sub callsets_call_filter_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('CallSets');
	my $brapi_package_result = $brapi_module->calls({
		callset_id => $c->stash->{callset_id},
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub callsets_search_save  : Chained('brapi') PathPart('search/callsets') Args(0) : ActionClass('REST') { }

sub callsets_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'CallSets');
}

sub callsets_search_retrieve : Chained('brapi') PathPart('search/callsets') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'CallSets');
}


=head2 brapi/v2/variantsets

 Usage: To retrieve data for variantsets
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
			    "data": [
			      {
			        "additionalInfo": {},
			        "analysis": [
			          {
			            "analysisDbId": "6191a6bd",
			            "analysisName": "Standard QC",
			            "created": "2018-01-01T14:47:23-0600",
			            "description": "This is a formal description of a QC methodology.",
			            "software": [
			              "https://github.com/genotyping/QC"
			            ],
			            "type": "QC",
			            "updated": "2018-01-01T14:47:23-0600"
			          }
			        ],
			        "availableFormats": [
			          {
			            "dataFormat": "VCF",
			            "fileFormat": "application/excel",
			            "fileURL": "https://brapi.org/example/VCF_1.xlsx"
			          },
			          {
			            "dataFormat": "VCF",
			            "fileFormat": "text/csv",
			            "fileURL": "https://brapi.org/example/VCF_2.csv"
			          }
			        ],
			        "callSetCount": 341,
			        "referenceSetDbId": "57eae639",
			        "studyDbId": "2fc3b034",
			        "variantCount": 250,
			        "variantSetDbId": "87a6ac1e",
			        "variantSetName": "Maize QC DataSet 002334"
			      }
			    ]
           }
        }
 Args:
 Side Effects:

=cut

sub variantsets : Chained('brapi') PathPart('variantsets') Args(0) : ActionClass('REST') { }

sub variantsets_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('VariantSets');
	my $brapi_package_result = $brapi_module->search({
        variantSetDbId => $clean_inputs->{variantSetDbId},
        variantDbId => $clean_inputs->{variantDbId},
        callSetDbId => $clean_inputs->{callSetDbId},
        studyDbId => $clean_inputs->{studyDbId},
        studyName => $clean_inputs->{studyName}
	});
	_standard_response_construction($c, $brapi_package_result);
}

### VariantSet single

sub variantsets_single : Chained('brapi') PathPart('variantsets') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $id = shift;
	$c->stash->{variantSetDbId} = $id;
}

sub variantsets_fetch : Chained('variantsets_single') PathPart('') Args(0) : ActionClass('REST') { }


sub variantsets_fetch_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('VariantSets');
	my $brapi_package_result = $brapi_module->detail({
		variantSetDbId => $c->stash->{variantSetDbId},
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub variantsets_callset_detail : Chained('variantsets_single') PathPart('callsets') Args(0) : ActionClass('REST') { }

sub variantsets_callset_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('VariantSets');
	my $brapi_package_result = $brapi_module->callsets({
		variantSetDbId => $c->stash->{variantSetDbId},
		callSetDbId => $clean_inputs->{callSetDbId},
		callSetName => $clean_inputs->{callSetName}
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub variantsets_calls_detail : Chained('variantsets_single') PathPart('calls') Args(0) : ActionClass('REST') { }

sub variantsets_calls_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('VariantSets');
	my $brapi_package_result = $brapi_module->calls({
		variantSetDbId => $c->stash->{variantSetDbId},
		unknown_string => $clean_inputs->{unknownString}->[0],
		sep_phased => $clean_inputs->{sepPhased}->[0],
		sep_unphased => $clean_inputs->{sepUnphased}->[0],
		expand_homozygotes => $clean_inputs->{expandHomozygotes}->[0],
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub variantsets_variants_detail : Chained('variantsets_single') PathPart('variants') Args(0) : ActionClass('REST') { }

sub variantsets_variants_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('VariantSets');
	my $brapi_package_result = $brapi_module->variants({
		variantSetDbId => $c->stash->{variantSetDbId},
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub variantsets_extract : Chained('brapi') PathPart('variantsets/extract') Args(0) : ActionClass('REST') { }

sub variantsets_extract_POST {
    my $self = shift;
    my $c = shift;
    # my $force_authenticate = 1;
	# my ($auth_success, $user_id, $user_type, $user_pref, $expired) = _authenticate_user($c, $force_authenticate);

    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('VariantSets');
    my $brapi_package_result = $brapi_module->extract($clean_inputs);
	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);

	_standard_response_construction($c, $brapi_package_result, $http_status_code);
}

sub variantsets_search_save  : Chained('brapi') PathPart('search/variantsets') Args(0) : ActionClass('REST') { }

sub variantsets_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'VariantSets');
}

sub variantsets_search_retrieve : Chained('brapi') PathPart('search/variantsets') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'VariantSets');
}


=head2 brapi/v2/calls

 Usage: To retrieve data for calls
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
			    "data": [
			      {
			        "additionalInfo": {},
			        "callSetDbId": "16466f55",
			        "callSetName": "Sample_123_DNA_Run_456",
			        "genotype": {
			          "values": [
			            "AA"
			          ]
			        },
			        "genotype_likelihood": [
			          1
			        ],
			        "phaseSet": "6410afc5",
			        "variantDbId": "538c8ecf",
			        "variantName": "Marker A"
			      }
			    ],
			    "expandHomozygotes": true,
			    "sepPhased": "~",
			    "sepUnphased": "|",
			    "unknownString": "-"
			  }
			}
        }
 Args:
 Side Effects:

=cut


sub calls_search_save  : Chained('brapi') PathPart('search/calls') Args(0) : ActionClass('REST') { }

sub calls_search_save_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Calls');
}

sub calls_search_retrieve : Chained('brapi') PathPart('search/calls') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Calls');
}

=head2 brapi/v2/referencesets

 Usage: To retrieve data for reference sets
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
			    "data": [
			      {
			        "additionalInfo": {},
			        "assemblyPUI": "doi://10.12345/fake/9876",
			        "description": "Description for an assembly",
			        "md5checksum": "c2365e900c81a89cf74d83dab60df146",
			        "referenceSetDbId": "7e029a84",
			        "referenceSetName": "Assembly version",
			        "sourceAccessions": [
			          "A0000002",
			          "A0009393"
			        ],
			        "sourceURI": "https://wiki.brapi.org/files/demo.fast",
			        "species": {
			          "term": "sonic hedgehog",
			          "termURI": "MGI:MGI:98297"
			        }
			      }
			    ]
			}
        }
 Args:
 Side Effects:

=cut

sub referencesets : Chained('brapi') PathPart('referencesets') Args(0) : ActionClass('REST') { }

sub referencesets_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ReferenceSets');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub referencesets_single : Chained('brapi') PathPart('referencesets') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $id = shift;
	$c->stash->{referenceSetDbId} = $id;
}

sub referencesets_fetch : Chained('referencesets_single') PathPart('') Args(0) : ActionClass('REST') { }


sub referencesets_fetch_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('ReferenceSets');
	my $brapi_package_result = $brapi_module->detail($c->stash->{referenceSetDbId});
	_standard_response_construction($c, $brapi_package_result);
}

sub referencesets_search  : Chained('brapi') PathPart('search/referencesets') Args(0) : ActionClass('REST') { }

sub referencesets_search_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'ReferenceSets');
}

sub referencesets_search_retrieve : Chained('brapi') PathPart('search/referencesets') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'ReferenceSets');
}

=head2 brapi/v2/reference

 Usage: To retrieve data for reference
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
			    "data": [
			      {
			        "additionalInfo": {},
			        "length": 50000000,
			        "md5checksum": "c2365e900c81a89cf74d83dab60df146",
			        "referenceDbId": "fc0a81d0",
			        "referenceName": "Chromosome 2",
			        "referenceSetDbId": "c1ecfef1",
			        "sourceAccessions": [
			          "GCF_000001405.26"
			        ],
			        "sourceDivergence": 0.01,
			        "sourceURI": "https://wiki.brapi.org/files/demo.fast",
			        "species": {
			          "term": "sonic hedgehog",
			          "termURI": "MGI:MGI:98297"
			        }
			      }
			    ]
			}
        }
 Args:
 Side Effects:

=cut

sub reference : Chained('brapi') PathPart('references') Args(0) : ActionClass('REST') { }

sub reference_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('References');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub reference_single : Chained('brapi') PathPart('references') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $id = shift;
	$c->stash->{referenceDbId} = $id;
}

sub reference_fetch : Chained('reference_single') PathPart('') Args(0) : ActionClass('REST') { }


sub reference_fetch_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('References');
	my $brapi_package_result = $brapi_module->detail($c->stash->{referenceDbId});
	_standard_response_construction($c, $brapi_package_result);
}

sub reference_search  : Chained('brapi') PathPart('search/references') Args(0) : ActionClass('REST') { }

sub reference_search_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'References');
}

sub reference_search_retrieve : Chained('brapi') PathPart('search/references') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Referenced');
}


=head2 brapi/v2/crossingprojects

=cut

sub crossingprojects : Chained('brapi') PathPart('crossingprojects') Args(0) : ActionClass('REST') { }

sub crossingprojects_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Crossing');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub crossingprojects_POST {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};

	my $data = $clean_inputs;
	my @all_data;
	foreach my $project (values %{$data}) {
	    push @all_data, $project;
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Crossing');
	my $brapi_package_result = $brapi_module->store_crossingproject(\@all_data,$c,$user_id);


	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);
	_standard_response_construction($c, $brapi_package_result);
}

sub crossingproject_single : Chained('brapi') PathPart('crossingprojects') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $id = shift;
	$c->stash->{crossingProjectDbId} = $id;
}

sub crossingproject_fetch : Chained('crossingproject_single') PathPart('') Args(0) : ActionClass('REST') { }


sub crossingproject_fetch_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Crossing');
	my $brapi_package_result = $brapi_module->detail($c->stash->{crossingProjectDbId});
	_standard_response_construction($c, $brapi_package_result);
}

sub crossingproject_fetch_PUT {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id,$user_type) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Crossing');
	my $brapi_package_result = $brapi_module->update_crossingproject($c->stash->{crossingProjectDbId}, $clean_inputs,$c,$user_id,$user_type);
	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);
	_standard_response_construction($c, $brapi_package_result);
}

=head2 brapi/v2/crosses

=cut

sub crosses : Chained('brapi') PathPart('crosses') Args(0) : ActionClass('REST') { }

sub crosses_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Crossing');
	my $brapi_package_result = $brapi_module->crosses($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub crosses_POST {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	my @all_crosses;
	foreach my $cross (values %{$data}) {
	    push @all_crosses, $cross;
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Crossing');
	my $brapi_package_result = $brapi_module->store_crosses(\@all_crosses,$c,$user_id);
	_standard_response_construction($c, $brapi_package_result);
}

# sub crosses_PUT {
# 	my $self = shift;
# 	my $c = shift;
# 	my ($auth) = _authenticate_user($c);
# 	my $clean_inputs = $c->stash->{clean_inputs};
# 	my $brapi = $self->brapi_module;
# 	my $brapi_module = $brapi->brapi_wrapper('Crossing');
# 	my $brapi_package_result = $brapi_module->update_crosses($clean_inputs);
# 	_standard_response_construction($c, $brapi_package_result);
# }

=head2 brapi/v2/seedlots

=cut

sub seedlots : Chained('brapi') PathPart('seedlots') Args(0) : ActionClass('REST') { }

sub seedlots_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('SeedLots');
	my $brapi_package_result = $brapi_module->search($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub seedlots_POST {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	my @all_data;
	foreach my $seedlot (values %{$data}) {
	    push @all_data, $seedlot;
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('SeedLots');
	my $brapi_package_result = $brapi_module->store_seedlots(\@all_data,$c,$user_id);

	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);

	_standard_response_construction($c, $brapi_package_result, $http_status_code);
}

sub seedlot_transactions : Chained('brapi') PathPart('seedlots/transactions') Args(0) : ActionClass('REST') { }

sub seedlot_transactions_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('SeedLots');
	my $brapi_package_result = $brapi_module->all_transactions($clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub seedlot_transactions_POST {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $data = $clean_inputs;
	my @all_data;
	foreach my $transaction (values %{$data}) {
	    push @all_data, $transaction;
	}
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('SeedLots');
	my $brapi_package_result = $brapi_module->store_seedlot_transaction(\@all_data,$c,$user_id);
	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);

	_standard_response_construction($c, $brapi_package_result);
}

sub seedlot_single : Chained('brapi') PathPart('seedlots') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $id = shift;
	$c->stash->{seedLotDbId} = $id;
}

sub seedlot_single_fetch : Chained('seedlot_single') PathPart('') Args(0) : ActionClass('REST') { }


sub seedlot_single_fetch_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('SeedLots');
	my $brapi_package_result = $brapi_module->detail($c->stash->{seedLotDbId});
	_standard_response_construction($c, $brapi_package_result);
}

sub seedlot_single_fetch_PUT {
	my $self = shift;
	my $c = shift;
	my ($auth,$user_id) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('SeedLots');
	my $brapi_package_result = $brapi_module->update_seedlot($c->stash->{seedLotDbId}, $clean_inputs,$c,$user_id);
	my $status = $brapi_package_result->{status};
	my $http_status_code = _get_http_status_code($status);
	_standard_response_construction($c, $brapi_package_result);
}

sub seedlot_single_transaction_fetch : Chained('seedlot_single') PathPart('transactions') Args(0) : ActionClass('REST') { }


sub seedlot_single_transaction_fetch_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('SeedLots');
	my $brapi_package_result = $brapi_module->transactions($c->stash->{seedLotDbId}, $clean_inputs);
	_standard_response_construction($c, $brapi_package_result);
}

sub breedingmethods : Chained('brapi') PathPart('breedingmethods') Args(0) : ActionClass('REST') { }

sub breedingmethods_GET {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('BreedingMethods');
    my $brapi_package_result = $brapi_module->search($clean_inputs);

    _standard_response_construction($c, $brapi_package_result);
}

sub nirs : Chained('brapi') PathPart('nirs') Args(0) : ActionClass('REST') { }

sub nirs_GET {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $clean_inputs = $c->stash->{clean_inputs};
    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper('Nirs');
    my $brapi_package_result = $brapi_module->search($clean_inputs);

    _standard_response_construction($c, $brapi_package_result);
}

sub nirs_single  : Chained('brapi') PathPart('nirs') CaptureArgs(1) {
	my $self = shift;
	my $c = shift;
	my $nd_protocol_id = shift;

	$c->stash->{nd_protocol_id} = $nd_protocol_id;
}

sub nirs_detail  : Chained('nirs_single') PathPart('') Args(0) : ActionClass('REST') { }

sub nirs_detail_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Nirs');
	my $brapi_package_result = $brapi_module->nirs_detail(
		$c->stash->{nd_protocol_id}
	);
	_standard_response_construction($c, $brapi_package_result);
}

sub nirs_matrix  : Chained('nirs_single') PathPart('matrix') Args(0) : ActionClass('REST') { }

sub nirs_matrix_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Nirs');
	my $brapi_package_result = $brapi_module->nirs_matrix(
		$c->stash->{nd_protocol_id},
		$clean_inputs
	);
	_standard_response_construction($c, $brapi_package_result);
}


=head2 brapi/v2/pedigree

=cut

sub pedigree : Chained('brapi') PathPart('pedigree') Args(0) : ActionClass('REST') { }

sub pedigree_GET {
	my $self = shift;
	my $c = shift;
	my ($auth) = _authenticate_user($c);
	my $clean_inputs = $c->stash->{clean_inputs};
	my $brapi = $self->brapi_module;
	my $brapi_module = $brapi->brapi_wrapper('Pedigree');
	my $brapi_package_result = $brapi_module->search({
        germplasmDbId => $clean_inputs->{germplasmDbId},
        pedigreeDepth => $clean_inputs->{pedigreeDepth},
        progenyDepth => $clean_inputs->{progenyDepth},
        includeFullTree => $clean_inputs->{includeFullTree},
        includeSiblings => $clean_inputs->{includeSiblings},
        includeParents => $clean_inputs->{includeParents},
        includeProgeny => $clean_inputs->{includeProgeny},
	});
	_standard_response_construction($c, $brapi_package_result);
}

sub pedigree_search  : Chained('brapi') PathPart('search/pedigree') Args(0) : ActionClass('REST') { }

sub pedigree_search_POST {
    my $self = shift;
    my $c = shift;
    save_results($self,$c,$c->stash->{clean_inputs},'Pedigree');
}

sub pedigree_search_retrieve : Chained('brapi') PathPart('search/pedigree') Args(1) {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    retrieve_results($self, $c, $search_id, 'Pedigree');
}



#functions
sub save_results {
    my $self = shift;
    my $c = shift;
    my $search_params = shift;
    my $search_type = shift;

	my %server_permission;
	my $rc = eval{
		my $server_permission = $c->config->{"brapi_GET"};
		my @server_permission  = split ',', $server_permission;
		%server_permission = map { $_ => 1 } @server_permission;
	1; };
	if($rc && !$server_permission{'any'}){
	    my $auth = _authenticate_user($c);
	}

    my $brapi = $self->brapi_module;
    my $brapi_module = $brapi->brapi_wrapper($search_type);

    #set default value to 100000 to get as much as possible records when page size is not a parameter
    if(!$search_params->{pageSize}) {
    	$brapi_module->{page_size} = 100000;
	}

    my $search_result = $brapi_module->search($search_params,$c);

    my $dir = $c->tempfiles_subdir('/brapi_searches');
    my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'brapi_searches/XXXXXXXXXXXXXXXX');
    my $results_module = $brapi->brapi_wrapper('Results');
    my $brapi_package_result = $results_module->save_results($tempfile, $search_result, $search_type);

    _standard_response_construction($c, $brapi_package_result, 202);
}

sub retrieve_results {
    my $self = shift;
    my $c = shift;
    my $search_id = shift;
    my $search_type = shift;
    my $auth = _authenticate_user($c);

    my $clean_inputs = $c->stash->{clean_inputs};
    my $tempfiles_subdir = $c->config->{basepath} . $c->tempfiles_subdir('brapi_searches');
    my $brapi = $self->brapi_module;
    my $search_module = $brapi->brapi_wrapper('Results');
    my $brapi_package_result = $search_module->retrieve_results($tempfiles_subdir, $search_id);
    _standard_response_construction($c, $brapi_package_result);
}

1;
