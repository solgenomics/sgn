
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
use CXGN::BreederSearch;
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

my $DEFAULT_PAGE_SIZE=20;


sub brapi : Chained('/') PathPart('brapi') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $version = shift;
    my @status;

    $self->bcs_schema( $c->dbic_schema("Bio::Chado::Schema") );
    $c->stash->{api_version} = $version;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->stash->{status} = \@status;
    $c->stash->{session_token} = $c->req->param("session_token");
    $c->stash->{current_page} = $c->req->param("page") || 1;
    $c->stash->{page_size} = $c->req->param("pageSize") || $DEFAULT_PAGE_SIZE;

}

sub _authenticate_user {
    my $c = shift;
    my $status = $c->stash->{status};
    my @status = @$status;

    my ($person_id, $user_type, $user_pref, $expired) = CXGN::Login->new($c->dbc->dbh)->query_from_cookie($c->stash->{session_token});
    #print STDERR $person_id." : ".$user_type." : ".$expired;

    if (!$person_id || $expired || $user_type ne 'curator') {
        push(@status, 'You must login and have permission to access BrAPI calls.');
        my %metadata = (status=>\@status);
        $c->stash->{rest} = \%metadata;
        $c->detach;
    }

    return 1;
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

    my $status = $c->stash->{status};
    my @status = @$status;
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

sub germplasm_list  : Chained('brapi') PathPart('germplasm') Args(0) : ActionClass('REST') { }

sub germplasm_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);

    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub germplasm_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $params = $c->req->params();

    my $status = $c->stash->{status};
    my @status = @$status;

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
	    push @data, { germplasmDbId=>$stock->get_column('stock_id'), defaultDisplayName=>$stock->get_column('name'), germplasmName=>$stock->get_column('uniquename'), accessionNumber=>'', germplasmPUI=>$stock->get_column('uniquename'), pedigree=>germplasm_pedigree_string($self->bcs_schema(), $stock->get_column('stock_id')), seedSource=>'', synonyms=>germplasm_synonyms($self->bcs_schema(), $stock->get_column('stock_id'), $synonym_id) };
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

sub germplasm_single  : Chained('brapi') PathPart('germplasm') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;

    $c->stash->{stock_id} = $stock_id;
    $c->stash->{stock} = CXGN::Chado::Stock->new($self->bcs_schema(), $stock_id);
}


sub germplasm_detail  : Chained('germplasm_single') PathPart('') Args(0) : ActionClass('REST') { }

sub germplasm_detail_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status=>\@status};
}

sub germplasm_detail_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $rs = $c->stash->{stock};
    my $schema = $self->bcs_schema();
    my $status = $c->stash->{status};
    my @status = @$status;

    my $total_count = 0;
    if ($c->stash->{stock}) {
	$total_count = 1;
    }

    my %result;
    my $synonym_id = $schema->resultset("Cv::Cvterm")->find( { name => "synonym" })->cvterm_id();

    %result = (germplasmDbId=>$c->stash->{stock_id}, defaultDisplayName=>$c->stash->{stock}->get_name(), germplasmName=>$c->stash->{stock}->get_uniquename(), accessionNumber=>$c->stash->{stock}->get_uniquename(), germplasmPUI=>$c->stash->{stock}->get_uniquename(), pedigree=>germplasm_pedigree_string($self->bcs_schema(), $c->stash->{stock_id}), seedSource=>'', synonyms=>germplasm_synonyms($schema, $c->stash->{stock_id}, $synonym_id));

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
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

sub germplasm_mcpd  : Chained('germplasm_single') PathPart('MCPD') Args(0) : ActionClass('REST') { }

sub germplasm_mcpd_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status=>\@status};
}

sub germplasm_mcpd_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $schema = $self->bcs_schema();
    my %result;
    my $status = $c->stash->{status};
    my @status = @$status;

    my $synonym_id = $schema->resultset("Cv::Cvterm")->find( { name => "synonym" })->cvterm_id();
    my $organism = CXGN::Chado::Organism->new( $schema, $c->stash->{stock}->get_organism_id() );

    %result = (germplasmDbId=>$c->stash->{stock_id}, defaultDisplayName=>$c->stash->{stock}->get_uniquename(), accessionNumber=>$c->stash->{stock}->get_uniquename(), germplasmName=>$c->stash->{stock}->get_name(), germplasmPUI=>$c->stash->{stock}->get_uniquename(), pedigree=>germplasm_pedigree_string($schema, $c->stash->{stock_id}), germplasmSeedSource=>'', synonyms=>germplasm_synonyms($schema, $c->stash->{stock_id}, $synonym_id), commonCropName=>$organism->get_common_name(), instituteCode=>'', instituteName=>'', biologicalStatusOfAccessionCode=>'', countryOfOriginCode=>'', typeOfGermplasmStorageCode=>'', genus=>$organism->get_genus(), species=>$organism->get_species(), speciesAuthority=>'', subtaxa=>$organism->get_taxon(), subtaxaAuthority=>'', donors=>'', acquisitionDate=>'');

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

sub studies_list  : Chained('brapi') PathPart('studies') Args(0) : ActionClass('REST') { }

sub studies_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub studies_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $program_id = $c->req->param("programId");
    my $status = $c->stash->{status};
    my @status = @$status;

    my @data;
    my %result;
    my $rs;
    if (!$program_id) {
	$rs = $self->bcs_schema->resultset('Project::Project')->search(
	    {'type.name' => 'breeding_program_trial_relationship' },
	    {join=> {'project_relationship_subject_projects' => 'type'},
	     '+select'=> ['me.project_id'],
	     '+as'=> ['study_id' ],
	     order_by=>{ -asc=>'me.project_id' }
	    }
	);
    }elsif ($program_id) {
	$rs = $self->bcs_schema->resultset('Project::Project')->search(
	    {'type.name' => 'breeding_program_trial_relationship', 'project_relationship_subject_projects.object_project_id' => $program_id },
	    {join=> {'project_relationship_subject_projects' => 'type'},
	     '+select'=> ['me.project_id'],
	     '+as'=> ['study_id' ],
	     order_by=>{ -asc=>'me.project_id' }
	    }
	);
    }

    my $total_count = 0;
    if ($rs) {
	$total_count = $rs->count();
	my $rs_slice = $rs->slice($c->stash->{page_size}*($c->stash->{current_page}-1), $c->stash->{page_size}*$c->stash->{current_page}-1);
	while (my $s = $rs_slice->next()) {
	   my $t = CXGN::Trial->new( { trial_id => $s->get_column('study_id'), bcs_schema => $self->bcs_schema } );

	   my @years = ($t->get_year());
	   my %optional_info = (studyPUI=>'', startDate => $t->get_planting_date(), endDate => $t->get_harvest_date());
	   my $project_type = '';
	   if ($t->get_project_type()) {
	       $project_type = $t->get_project_type()->[1];
	   }
	   my $location = '';
	   if ($t->get_location()) {
	       $location = $t->get_location()->[0];
	   }
	   push @data, {studyDbId=>$t->get_trial_id(), name=>$t->get_name(), studyType=>$project_type, years=>\@years, locationDbId=>$location, optionalInfo=>\%optional_info};
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

sub studies_single  : Chained('brapi') PathPart('studies') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $study_id = shift;

    $c->stash->{study_id} = $study_id;
    my $t = CXGN::Trial->new( { trial_id => $study_id, bcs_schema => $self->bcs_schema } );
    $c->stash->{study} = $t;
    $c->stash->{studyName} = $t->get_name();
}


sub studies_germplasm : Chained('studies_single') PathPart('germplasm') Args(0) : ActionClass('REST') { }

sub studies_germplasm_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    my $metadata = $c->req->params("metadata");
    my $result = $c->req->params("result");
    my %metadata_hash = %$metadata;
    my %result_hash = %$result;

    print STDERR Dumper($metadata);
    print STDERR Dumper($result);

    my $pagintation = $metadata_hash{"pagination"};
    push(@status, $metadata_hash{"status"});

    $c->stash->{rest} = {status=>\@status};
}

sub studies_germplasm_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my %result;
    my $status = $c->stash->{status};
    my @status = @$status;
    my $total_count = 0;

    my $synonym_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => "synonym" })->cvterm_id();
    my $tl = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $c->stash->{study_id} });
    my ($accessions, $controls) = $tl->_get_trial_accession_names_and_control_names();
    my @germplasm_data;

    if ($accessions) {
        push (@$accessions, @$controls);
        $total_count = scalar(@$accessions);
        my $start = $c->stash->{page_size}*($c->stash->{current_page}-1);
        my $end = $c->stash->{page_size}*$c->stash->{current_page}-1;
        for( my $i = $start; $i <= $end; $i++ ) {
            if (@$accessions[$i]) {
                push @germplasm_data, { germplasmDbId=>@$accessions[$i]->{stock_id}, germplasmName=>@$accessions[$i]->{accession_name}, studyEntryNumberId=>'', defaultDisplayName=>@$accessions[$i]->{accession_name}, accessionNumber=>@$accessions[$i]->{accession_name}, germplasmPUI=>@$accessions[$i]->{accession_name}, pedigree=>germplasm_pedigree_string($self->bcs_schema, @$accessions[$i]->{stock_id}), seedSource=>'', synonyms=>germplasm_synonyms($self->bcs_schema, @$accessions[$i]->{stock_id}, $synonym_id)};
            }
        }
    }

	%result = (studyDbId=>$c->stash->{study_id}, studyName=>$c->stash->{studyName}, data =>\@germplasm_data);

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

sub germplasm_pedigree : Chained('germplasm_single') PathPart('pedigree') Args(0) : ActionClass('REST') { }

sub germplasm_pedigree_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status=>\@status};
}

sub germplasm_pedigree_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $schema = $self->bcs_schema();
    my %result;
    my $status = $c->stash->{status};
    my @status = @$status;
    my $total_count = 0;

    if ($c->req->param('notation')) {
	push @status, 'notation not implemented';
	if ($c->req->param('notation') ne 'purdy') {
	    push @status, {code=>'ERR-1', message=>'Unsupported notation code.'};
	}
    }

    my $s = $c->stash->{stock};
    if ($s) {
	$total_count = 1;
    }

    my @direct_parents = $s->get_direct_parents();

    %result = (germplasmDbId=>$c->stash->{stock_id}, pedigree=>germplasm_pedigree_string($schema, $c->stash->{stock_id}), parent1Id=>$direct_parents[0][0], parent2Id=>$direct_parents[1][0]);

    my %pagination;
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
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

sub germplasm_markerprofile : Chained('germplasm_single') PathPart('markerprofiles') Args(0) : ActionClass('REST') { }

sub germplasm_markerprofile_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status=>\@status};
}

sub germplasm_markerprofile_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $schema = $self->bcs_schema();
    my %result;
    my $status = $c->stash->{status};
    my @status = @$status;
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

sub markerprofiles_list : Chained('brapi') PathPart('markerprofiles') Args(0) : ActionClass('REST') { }

sub markerprofiles_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status=>\@status};
}

sub markerprofiles_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $germplasm = $c->req->param("germplasm");
    my $extract = $c->req->param("extract");
    my $method = $c->req->param("method");
    my $status = $c->stash->{status};
    my @status = @$status;
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
    my @status = @$status;

    $c->stash->{rest} = {status=>\@status};
}

sub genotype_fetch_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;
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
    	foreach my $row ($rs->first()) {

    	    my $genotype_json = $row->get_column('value');
    	    my $genotype = JSON::Any->decode($genotype_json);
            $total_count = scalar keys %$genotype;

    	    foreach my $m (sort genosort keys %$genotype) {
                push @data, { $m=>$self->convert_dosage_to_genotype($genotype->{$m}) };
    	    }

            my $start = $c->stash->{page_size}*($c->stash->{current_page}-1);
            my $end = $c->stash->{page_size}*$c->stash->{current_page};
            my @data_window = splice @data, $start, $end;

    	    %result = (germplasmDbId=>$row->get_column('stock_id'), extractDbId=>'', markerprofileDbId=>$c->stash->{markerprofile_id}, analysisMethod=>$row->get_column('protocol_name'), encoding=>"AA,BB,AB", data => \@data_window);
    	}
    }

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


sub markerprofiles_methods : Chained('brapi') PathPart('markerprofiles/methods') Args(0) {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

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
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

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

sub programs_list : Chained('brapi') PathPart('programs') Args(0) : ActionClass('REST') { }

sub programs_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status=>\@status};
}

sub programs_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;
    my %result;
    my @data;

    my $ps = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $programs = $ps -> get_breeding_programs();
    my $total_count = scalar(@$programs);

    my $start = $c->stash->{page_size}*($c->stash->{current_page}-1);
    my $end = $c->stash->{page_size}*$c->stash->{current_page}-1;
    for( my $i = $start; $i <= $end; $i++ ) {
        if (@$programs[$i]) {
            push @data, {programDbId=>@$programs[$i]->[0], name=>@$programs[$i]->[1], objective=>@$programs[$i]->[2], leadPerson=>''};
        }
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

sub studies_types_list  : Chained('brapi') PathPart('studyTypes') Args(0) : ActionClass('REST') { }

sub studies_types_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status=>\@status};
}

sub studies_types_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my %result;
    my @data;
    my $status = $c->stash->{status};
    my @status = @$status;

    my @cvterm_ids = CXGN::Trial::get_all_project_types($self->bcs_schema);
    my $cvterm;
    foreach (@cvterm_ids) {
	$cvterm = CXGN::Chado::Cvterm->new($c->dbc->dbh, $_->[0]);
	push @data, {name=>$_->[1], description=>$cvterm->get_definition },
    }

    my $total_count = scalar(@cvterm_ids);
    %result = (data => \@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


sub studies_instances  : Chained('studies_single') PathPart('instances') Args(0) : ActionClass('REST') { }

sub studies_instances_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status=>\@status};
}

sub studies_instances_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my %result;
    my $status = $c->stash->{status};
    my @status = @$status;
    my $total_count = 0;

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


sub studies_info  : Chained('studies_single') PathPart('') Args(0) : ActionClass('REST') { }

sub studies_info_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub studies_info_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my %result;
    my $status = $c->stash->{status};
    my @status = @$status;
    my $total_count = 0;

    my $t = $c->stash->{study};
    if ($t) {
    	$total_count = 1;
    	my @years = ($t->get_year());
    	my %optional_info = (studyPUI=>'', startDate=>'', endDate=>'');
    	my $project_type = '';
    	if ($t->get_project_type()) {
    	    $project_type = $t->get_project_type()->[1];
    	}
    	my $location = '';
    	if ($t->get_location()) {
    	    $location = $t->get_location()->[0];
    	}
    	my $ps = CXGN::BreedersToolbox::Projects->new( { schema => $self->bcs_schema });
    	my $programs = $ps->get_breeding_program_with_trial($c->stash->{study_id});

    	%result = (studyDbId=>$t->get_trial_id(), studyName=>$t->get_name(), studyType=>$project_type, years=>\@years, locationDbId=>$location, programDbId=>@$programs[0]->[0], programName=>@$programs[0]->[1], optionalInfo=>\%optional_info);
    } else {
	   push @status, "Study ID not found.";
    }

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


sub studies_details  : Chained('studies_single') PathPart('details') Args(0) : ActionClass('REST') { }

sub studies_details_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub studies_details_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;
    my %result;
    my $total_count = 0;

    my $schema = $self->bcs_schema();
    my $t = $c->stash->{study};
    my $tl = CXGN::Trial::TrialLayout->new( { schema => $schema, trial_id => $c->stash->{study_id} });

    if ($t) {
	$total_count = 1;
	my ($accessions, $controls) = $tl->_get_trial_accession_names_and_control_names();
	my @germplasm_data;
    foreach (@$accessions) {
        push @germplasm_data, { germplasmDbId=>$_->{stock_id}, germplasmName=>$_->{accession_name}, germplasmPUI=>$_->{accession_name} };
    }
    foreach (@$controls) {
        push @germplasm_data, { germplasmDbId=>$_->{stock_id}, germplasmName=>$_->{accession_name}, germplasmPUI=>$_->{accession_name} };
    }

    my $ps = CXGN::BreedersToolbox::Projects->new( { schema => $self->bcs_schema });
    my $programs = $ps->get_breeding_program_with_trial($c->stash->{study_id});

	%result = (
	    studyDbId => $c->stash->{study_id},
	    studyId => $t->get_name(),
	    studyPUI => "",
	    studyName => $t->get_name(),
	    studyObjective => $t->get_description(),
	    studyType => $t->get_project_type() ? $t->get_project_type()->[1] : "trial",
	    studyLocation => $t->get_location() ? $t->get_location()->[1] : undef,
	    studyProject => $t->get_breeding_program(),
	    dataSet => "",
	    studyPlatform => "",
	    startDate => $t->get_planting_date(),
	    endDate => $t->get_harvest_date(),
        programDbId=>@$programs[0]->[0], 
        programName=>@$programs[0]->[1],
	    designType => $tl->get_design_type(),
	    keyContact => "",
	    contacts => "",
	    meteoStationCode => "",
	    meteoStationNetwork => "",
	    studyHistory => "",
	    studyComments => "",
	    attributes => "",
	    seasons => "",
	    observationVariables => "",
	    germplasm => \@germplasm_data,
	);
    }

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


sub studies_layout : Chained('studies_single') PathPart('layout') Args(0) : ActionClass('REST') { }

sub studies_layout_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub studies_layout_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;
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
	%optional_info = (germplasmName => $design->{$plot_number}->{accession_name}, blockNumber => $design->{$plot_number}->{block_number} ? $design->{$plot_number}->{block_number} : undef, rowNumber => $design->{$plot_number}->{row_number} ? $design->{$plot_number}->{row_number} : undef, columnNumber => $design->{$plot_number}->{col_number} ? $design->{$plot_number}->{col_number} : undef, type => $type);
	$formatted_plot = {
	    studyDbId => $c->stash->{study_id},
	    plotDbId => $design->{$plot_number}->{plot_id},
	    plotName => $design->{$plot_number}->{plot_name},
	    replicate => $design->{$plot_number}->{replicate} ? 1 : 0,
	    germplasmDbId => $design->{$plot_number}->{accession_id},
	    optionalInfo => \%optional_info
	};
	push @$plot_data, $formatted_plot;
	$total_count += 1;
    }
    %result = (data=>$plot_data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


=head2 brapi/v1/studies/<studyDbId>/observationVariable/<observationVariableDbId>

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

sub studies_plot_phenotypes : Chained('studies_single') PathPart('observationVariable') Args(1) : ActionClass('REST') { }

sub studies_plot_phenotypes_POST {
    my $self = shift;
    my $c = shift;
    my $trait_id = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub studies_plot_phenotypes_GET {
    my $self = shift;
    my $c = shift;
    my $trait_id = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;
    my %result;

    my $t = $c->stash->{study};
    my $phenotype_data = $t->get_plot_phenotypes_for_trait($trait_id);

    my $trait =$self->bcs_schema->resultset('Cv::Cvterm')->find({ cvterm_id => $trait_id });

    #print STDERR Dumper $phenotype_data;
    
    my @data;
    my $total_count = scalar(@$phenotype_data);
    my $start = $c->stash->{page_size}*($c->stash->{current_page}-1);
    my $end = $c->stash->{page_size}*$c->stash->{current_page}-1;
    for( my $i = $start; $i <= $end; $i++ ) {
        if (@$phenotype_data[$i]) {
            my $pheno_uniquename = @$phenotype_data[$i]->[2];
            my ($part1 , $part2) = split( /date: /, $pheno_uniquename);
            my ($timestamp , $operator) = split( /\ \ operator = /, $part2);

            my $plot_id = @$phenotype_data[$i]->[0];
            my $stock_plot_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'plot_of', 'stock_relationship')->cvterm_id();
            my $germplasm =$self->bcs_schema->resultset('Stock::StockRelationship')->find({ 'me.subject_id' => $plot_id, 'me.type_id' =>$stock_plot_relationship_type_id }, {join => 'object', '+select'=> ['object.stock_id', 'object.uniquename'], '+as'=> ['germplasm_id', 'germplasm_name'] } );

            my %data_hash = (studyDbId => $c->stash->{study_id}, plotDbId => $plot_id, observationVariableDbId => $trait_id, observationVariableName => $trait->name(), plotName => @$phenotype_data[$i]->[1], timestamp => $timestamp, uploadedBy => @$phenotype_data[$i]->[3], operator => $operator, germplasmDbId => $germplasm->get_column('germplasm_id'), germplasmName => $germplasm->get_column('germplasm_name'), value => @$phenotype_data[$i]->[4] );
            push @data, \%data_hash;
        }
    }

    %result = (data=>\@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
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
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub studies_table_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;
    my %result;

    my $bs = CXGN::BreederSearch->new( { dbh => $self->bcs_schema->storage->dbh() });
    my $trial_id = $c->stash->{study_id};
    my $trial_sql = "\'$trial_id\'";
    my @data = $bs->get_extended_phenotype_info_matrix(undef,$trial_sql, undef);

    #print STDERR Dumper \@data;

    my $total_count = scalar(@data)-1;
    my @header_ids;
    my @header_names = split /\t/, $data[0];

    my $start = $c->stash->{page_size}*($c->stash->{current_page}-1)+1;
    my $end = $c->stash->{page_size}*$c->stash->{current_page}+1;
    my @data_window;
    for (my $line = $start; $line < $end; $line++) { 
        if ($data[$line]) {
            my @columns = split /\t/, $data[$line];
            
            push @data_window, \@columns;
        }
    }
    
    
    %result = (studyDbId => $c->stash->{study_id}, observationVariableDbId => \@header_ids, observationVariableName => \@header_names, data=>\@data_window);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
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

sub phenotypes_dataset : Chained('brapi') PathPart('phenotypes') Args(0) : ActionClass('REST') { }

sub phenotypes_dataset_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub phenotypes_dataset_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my $params = $c->req->params();
    my @status = @$status;

    my $study_id = $params->{studyDbId};
    my $t = CXGN::Trial->new( { trial_id => $study_id, bcs_schema => $self->bcs_schema } );
    my $traits_assayed = $t->get_traits_assayed();
    print STDERR Dumper $traits_assayed;

    my $count_limit = $c->stash->{page_size};
    foreach (@$traits_assayed) {
      if ($_->[2] < $count_limit) {


      }
      $count_limit = $count_limit - $_->[2];
    }


    my @data;

    my $total_count = '0';
    my %result = (
      observationUnitDbId =>
      data => \@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;

}


sub traits_list : Chained('brapi') PathPart('traits') Args(0) : ActionClass('REST') { }

sub traits_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub traits_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

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

sub traits_single  : Chained('brapi') PathPart('traits') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $cvterm_id = shift;
    my $status = $c->stash->{status};
    my @status = @$status;
    my %result;

    my $q = "SELECT cvterm_id, name FROM materialized_traits where cvterm_id=?;";
    my $p = $self->bcs_schema()->storage->dbh()->prepare($q);
    $p->execute($cvterm_id);

    while (my ($cvterm_id, $name) = $p->fetchrow_array()) {
	my $q2 = "SELECT cvterm.definition, cvtermprop.value, dbxref.accession FROM cvterm LEFT JOIN cvtermprop using(cvterm_id) JOIN dbxref USING(dbxref_id) WHERE cvterm.cvterm_id=?";
	my $h = $self->bcs_schema()->storage->dbh()->prepare($q2);
	$h->execute($cvterm_id);

	while (my ($description, $scale, $accession) = $h->fetchrow_array()) {
	    my @observation_vars = ();
	    push (@observation_vars, ($name, $accession));
	    %result = ( traitDbId => $cvterm_id, traitId => $name, name => $name, description => $description, observationVariables => \@observation_vars, defaultValue => '', scale =>$scale );
	}
    }

    my $total_count = $p->rows;
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
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
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub maps_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;


    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { } );

    my @data;
    my %map_info;
    while (my $row = $rs->next()) {
    	print STDERR "Retrieving map info for ".$row->name()." ID:".$row->nd_protocol_id()."\n";
        #$self->bcs_schema->storage->debug(1);
    	my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { 'me.nd_protocol_id' => $row->nd_protocol_id() } )->search_related('nd_experiment_protocols')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops', {}, {select=>['genotype.description', 'genotypeprops.value'], as=>['description', 'value'], rows=>1} );

    	my $lg_row = $lg_rs->first();

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
    	    #print STDERR "CHR: $chr. POS: $pos\n";
    	    $chrs{$chr} = $pos;
    	    $marker_count++;
    	    $lg_count = scalar(keys(%chrs));
    	}

    	%map_info = (
    	    mapId =>  $row->nd_protocol_id(),
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
    my $start = $c->stash->{page_size}*($c->stash->{current_page}-1);
    my $end = $c->stash->{page_size}*$c->stash->{current_page};
    my @data_window = splice @data, $start, $end;

    my %result = (data => \@data_window);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
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
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub maps_details_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;
    my $params = $c->req->params();
    my $total_count = 0;

    # maps are just marker lists associated with specific protocols
    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { nd_protocol_id => $c->stash->{map_id} } );
    my %map_info;
    my @data;
    while (my $row = $rs->next()) {
    	print STDERR "Retrieving map info for ".$row->name()."\n";
        #$self->bcs_schema->storage->debug(1);
    	my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProtocol")->search( { 'me.nd_protocol_id' => $row->nd_protocol_id() })->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops', {}, {rows=>1} );

    	my $lg_row = $lg_rs->first();

    	if (!$lg_row) {
    	    die "This was never supposed to happen :-(";
    	}

    	my $scores;
    	if ($lg_row) {
    	    $scores = JSON::Any->decode($lg_row->value());
    	}

    	my %chrs;
        my %chrs_marker_count;
    	foreach my $m (sort genosort (keys %$scores)) {
    	    my ($chr, $pos) = split "_", $m;
    	    #print STDERR "CHR: $chr. POS: $pos\n";
    	    $chrs{$chr} = $pos;
            if ($chrs_marker_count{$chr}) {
                ++$chrs_marker_count{$chr};
            } else {
                $chrs_marker_count{$chr} = 1;
            }
    	}

        foreach my $ci (sort (keys %chrs)) {
            my %linkage_groups_data = (linkageGroupId => $ci, numberMarkers => $chrs_marker_count{$ci}, maxPosition => $chrs{$ci} );
            push @data, \%linkage_groups_data;
        }

        $total_count = scalar(@data);
        my $start = $c->stash->{page_size}*($c->stash->{current_page}-1);
        my $end = $c->stash->{page_size}*$c->stash->{current_page};
        my @data_window = splice @data, $start, $end;

    	%map_info = (
    	    mapId =>  $row->nd_protocol_id(),
    	    name => $row->name(),
    	    type => "physical",
    	    unit => "bp",
    	    linkageGroups => \@data_window,
    	    );
    }

    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
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
                        "markerId": 1,
                        "markerName": "marker1",
                        "location": "1000",
                        "linkageGroup": "1A"
                    }, {
                        "markerId": 2,
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
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub maps_marker_detail_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;
    my $params = $c->req->params();

    my %linkage_groups;
    if ($params->{linkageGroupIdList}) {
        my $linkage_groups_list = $params->{linkageGroupIdList};
        my @linkage_groups_array = split /,/, $linkage_groups_list;
        %linkage_groups = map { $_ => 1 } @linkage_groups_array;
    }

    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { nd_protocol_id => $c->stash->{map_id} } );

    my @markers;
    while (my $row = $rs->next()) {
    	print STDERR "Retrieving map info for ".$row->name()."\n";
        #$self->bcs_schema->storage->debug(1);
    	my $lg_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search( { 'me.nd_protocol_id' => $row->nd_protocol_id()  } )->search_related('nd_experiment_protocols')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops', {}, {rows=>1} );

    	my $lg_row = $lg_rs->first();

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
    	    #print STDERR "CHR: $chr. POS: $pos\n";
    	    $chrs{$chr} = $pos;
            #   "markerId": 1,
            #   "markerName": "marker1",
            #   "location": "1000",
            #   "linkageGroup": "1A"

            if (%linkage_groups) {
                if (exists $linkage_groups{$chr} ) {
                    if ($params->{min} && $params->{max}) {
                        if ($pos >= $params->{min} && $pos <= $params->{max}) {
                            push @markers, { markerId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
                        }
                    } elsif ($params->{min}) {
                        if ($pos >= $params->{min}) {
                            push @markers, { markerId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
                        }
                    } elsif ($params->{max}) {
                        if ($pos <= $params->{max}) {
                            push @markers, { markerId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
                        }
                    } else {
                        push @markers, { markerId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
                    }
                }
            } else {
                push @markers, { markerId => $m, markerName => $m, location => $pos, linkageGroup => $chr };
            }
    	}
    }

    my $total_count = scalar(@markers);
    my $start = $c->stash->{page_size}*($c->stash->{current_page}-1);
    my $end = $c->stash->{page_size}*$c->stash->{current_page};
    my @data_window = splice @markers, $start, $end;

    my %result = (data => \@data_window);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
    my %response = (metadata=>\%metadata, result=>\%result);
    $c->stash->{rest} = \%response;
}


sub locations_list : Chained('brapi') PathPart('locations') Args(0) : ActionClass('REST') { }

sub locations_list_POST {
    my $self = shift;
    my $c = shift;
    my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;

    $c->stash->{rest} = {status => \@status};
}

sub locations_list_GET {
    my $self = shift;
    my $c = shift;
    #my $auth = _authenticate_user($c);
    my $status = $c->stash->{status};
    my @status = @$status;
    my @data;
    my @attributes;

    my $locations = CXGN::Trial::get_all_locations($self->bcs_schema);

    my $total_count = scalar(@$locations);
    my $start = $c->stash->{page_size}*($c->stash->{current_page}-1);
    my $end = $c->stash->{page_size}*$c->stash->{current_page}-1;
    for( my $i = $start; $i <= $end; $i++ ) {
        if (@$locations[$i]) {
            push @data, {locationDbId => @$locations[$i]->[0], name=> @$locations[$i]->[1], countryCode=> @$locations[$i]->[6], countryName=> @$locations[$i]->[5], latitude=>@$locations[$i]->[2], longitude=>@$locations[$i]->[3], altitude=>@$locations[$i]->[4], attributes=> @$locations[$i]->[7]};
        }
    }

    my %result = (data=>\@data);
    my %metadata = (pagination=>pagination_response($total_count, $c->stash->{page_size}, $c->stash->{current_page}), status=>\@status);
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
