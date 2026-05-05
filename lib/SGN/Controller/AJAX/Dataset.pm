
package SGN::Controller::AJAX::Dataset;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use File::Temp qw| tempfile tempdir |;
use Data::Dumper;
use JSON::Any;
use CXGN::Dataset;
use CXGN::Job;
use CXGN::DB::Connection;
use CXGN::Page::UserPrefs;
use Text::CSV ("csv");
use LWP::UserAgent;
use JSON qw| decode_json encode_json |;
use Time::HiRes qw| time |;
use strict;
use warnings;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );

sub store_dataset :Path('/ajax/dataset/save') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user;
    if (!$c->user()) {
	$c->stash->{rest} = { error => "Login required to perform requested action." };
	return;
    }

    my %data;

    my $dataset_name = $c->req->param("name");
    my $dataset_description = $c->req->param("description");

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $people_schema =  $c->dbic_schema("CXGN::People::Schema", undef, $user_id);
    if (CXGN::Dataset->exists_dataset_name($people_schema, $dataset_name)) {
	$c->stash->{rest} = { error => "The dataset with name $dataset_name already exists. Please choose another name." };
	return;
    }

    my $dataset = CXGN::Dataset->new( {
	schema => $c->dbic_schema("Bio::Chado::Schema", undef, $user_id),
	people_schema => $people_schema,
				      });

    $dataset->sp_person_id($user_id);
    $dataset->name($dataset_name);
    $dataset->description($dataset_description);

    foreach my $type (qw | trials accessions years locations plots traits breeding_programs genotyping_protocols genotyping_projects trial_types trial_designs category_order |) {
	#print STDERR "Storing data: $type\n";

        my $json = $c->req->param($type);
        if ($json) {
            my $obj = JSON::Any->jsonToObj($json);
            $dataset->$type($obj);
        }
    }

    my $new_id = $dataset->store();



    $c->stash->{rest} = { message => "Stored Dataset Successfully!", id => $new_id };
}

sub store_outliers_in_dataset :Path('/ajax/dataset/store_outliers') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $string_outliers = $c->req->param('outliers');
    my $string_outlier_cutoffs = $c->req->param('outlier_cutoffs');

    my @outliers = split(',',$string_outliers);
    my @outlier_cutoffs = split(',', $string_outlier_cutoffs);
    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    sp_dataset_id => $dataset_id,
        outliers => \@outliers,
        outlier_cutoffs => \@outlier_cutoffs
	});


    $dataset->store();
    $c->stash->{rest} = { success => 1 };
    
}

sub retrieve_outliers_from_dataset :Path('/ajax/dataset/retrieve_outliers') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $dataset = CXGN::Dataset->new(
        {
            schema => $c->dbic_schema("Bio::Chado::Schema"),
            people_schema => $c->dbic_schema("CXGN::People::Schema"),
            sp_dataset_id => $dataset_id,
        });

    my $outliers = $dataset->outliers();

    $c->stash->{rest} = { outliers => $outliers };
}

sub get_rosners_test_outliers :Path('/ajax/dataset/rosner_test') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $dataset_trait = $c->req->param('dataset_trait');

    print STDERR "dataset_trait: $dataset_trait";
    my $dataset = CXGN::Dataset->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id => $dataset_id,
        include_phenotype_primary_key => 1,
    });
    #
    my $phenotypes_data_ref = $dataset->retrieve_phenotypes();
    my @columns = @{$phenotypes_data_ref->[0]};
    # print STDERR "columns: ", join(", ", @columns);

    my ($trait_index) = grep { $columns[$_] eq $dataset_trait } (0 ..  scalar @columns -1);
    my ($trait_id_index) = grep { $columns[$_] eq "${dataset_trait}_phenotype_id" } (0 ..  scalar @columns -1);

    $c->tempfiles_subdir("rosners_files");
    my ($trait_file_path, $temp_file) = $c->tempfile(TEMPLATE=>"rosners_files/trait_XXXXX", SUFFIX => '.csv');
    my ($stat_file_path, $stat_file) = $c->tempfile(TEMPLATE=>"rosners_files/stat_XXXXX", SUFFIX => '.csv');

    my $csv = Text::CSV->new ({ binary => 1});

    open my $fh, ">:encoding(utf8)", $trait_file_path or die "$trait_file_path: $!";
    foreach my $row (@$phenotypes_data_ref) {
        $csv->say ($fh, [$row->[$trait_index], $row->[$trait_id_index]]);
    }
    close $fh;

    my $user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $cxgn_tools_run_config = {
        backend => $c->config->{backend},
        submit_host=>$c->config->{cluster_host},
        temp_base => $c->config->{cluster_shared_tempdir} . "/rosners_files",
        queue => $c->config->{'web_cluster_queue'},
        do_cleanup => 0,
        # don't block and wait if the cluster looks full
        max_cluster_jobs => 1_000_000_000,
    };
    my $cmd_str = join(" ", (
        "Rscript ",
        $c->config->{basepath} . "/R/dataset/rosner_test.R",
        $trait_file_path,
        $stat_file_path
    ));

    my $job = CXGN::Job->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_person_id => $user,
        name => $dataset->name()." Rosner's test outliers",
        results_page => "/dataset/$dataset_id",
        job_type => 'phenotypic_analysis',
        cmd => $cmd_str,
        cxgn_tools_run_config => $cxgn_tools_run_config,
        finish_logfile => $c->config->{job_finish_log}
    });

    $job->submit();

    while($job->alive()) {
        sleep(1);
    }
    # run cluster with R
    # my $cmd = CXGN::Tools::Run->new($cxgn_tools_run_config);

    # $job_record->update_status("submitted");
    # $cmd->run_cluster(
    #     "Rscript ",
    #     $c->config->{basepath} . "/R/dataset/rosner_test.R",
    #     $trait_file_path,
    #     $stat_file_path,
    #     $job_record->generate_finish_timestamp_cmd()
    # );
    # $cmd->alive;
    # $cmd->is_cluster(1);
    # $cmd->wait;

    # $job_record->update_status("finished");

    # print STDERR Dumper $stat_file_path;
    my $aoa = csv (in => $stat_file_path);   # as array of hash

    $c->stash->{rest} = {
        message            => "Rosners TEST Successfully!",
        dataset_id         => $dataset_id,
        dataset_trait      => $dataset_trait,
        data               => \@columns,
        index              => $trait_index,
        phenotype_id_index => $trait_id_index,
        file               => $aoa,
    };
}

sub retrieve_datasets_by_user :Path('/ajax/dataset/by_user') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user = $c->user();
    if (!$user) {
	$c->stash->{rest} = { error => "No logged in user to display dataset information for." };
	return;
    }

    my $sp_person_id = $c->user() ? $c->user()->get_object->get_sp_person_id() : undef;
    my $datasets = CXGN::Dataset->get_datasets_by_user(
	$c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id),
	$sp_person_id
	);

    $c->stash->{rest} = $datasets;
}

sub get_datasets_by_user_html :Path('/ajax/dataset/by_user_html') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user = $c->user();
    if (!$user) {
        $c->stash->{rest} = { error => "No logged in user to display dataset information for." };
        return;
    }

    my $sp_person_id = $c->user() ? $c->user()->get_object->get_sp_person_id() : undef;

    my $datasets = CXGN::Dataset->get_datasets_by_user(
        $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id),
        $sp_person_id
        );

    my @result;
    foreach (@$datasets) {
        my @res;
        push @res, ("<a href=\"/dataset/$_->[0]\">$_->[1]</a>", $_->[2]);
        push @result , \@res;
    }
    $c->stash->{rest} = { data => \@result };
}

sub get_datasets_public :Path('/ajax/dataset/get_public') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $datasets = CXGN::Dataset->get_datasets_public(
        $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id)
        );

    $c->stash->{rest} = $datasets;
}

sub set_datasets_public :Path('/ajax/dataset/set_public') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $user = $c->user();
    if (!$user) {
        $c->stash->{rest} = { error => "No logged in user error." };
        return;
    }

    my $logged_in_user = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new(
        {
	    schema => $c->dbic_schema("Bio::Chado::Schema", undef, $logged_in_user),
            people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $logged_in_user),
            sp_dataset_id=> $dataset_id,
        });
    print STDERR "Dataset owner: ".$dataset->sp_person_id.", logged in: $logged_in_user\n";
    if ($dataset->sp_person_id() != $logged_in_user) {
        $c->stash->{rest} = { error => "Only the owner can change a dataset" };
        return;
    }
    print STDERR "set public dataset_id $dataset_id\n";
    my $error = $dataset->set_dataset_public();

    if ($error) {
        $c->stash->{rest} = { error => $error };
    } else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub set_datasets_private :Path('/ajax/dataset/set_private') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $user = $c->user();
    if (!$user) {
        $c->stash->{rest} = { error => "No logged in user error." };
        return;
    }

    my $logged_in_user = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new(
        {
            schema => $c->dbic_schema("Bio::Chado::Schema", undef, $logged_in_user),
            people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $logged_in_user),
            sp_dataset_id=> $dataset_id,
        });
    print STDERR "Dataset owner: ".$dataset->sp_person_id.", logged in: $logged_in_user\n";
    if ($dataset->sp_person_id() != $logged_in_user) {
        $c->stash->{rest} = { error => "Only the owner can change a dataset" };
        return;
    }
    print STDERR "set private dataset_id $dataset_id\n";
    my $error = $dataset->set_dataset_private();

    if ($error) {
        $c->stash->{rest} = { error => $error };
    } else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub update_description :Path('/ajax/dataset/update_description') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $dataset_description = $c->req->param("description");

    my $user = $c->user();
    if (!$user) {
        $c->stash->{rest} = { error => "No logged in user error." };
        return;
    }

    my $logged_in_user = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new(
        {
            schema => $c->dbic_schema("Bio::Chado::Schema", undef, $logged_in_user),
            people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $logged_in_user),
            sp_dataset_id=> $dataset_id,
        });
    $dataset->description($dataset_description);
    print STDERR "Dataset owner: ".$dataset->sp_person_id.", logged in: $logged_in_user\n";
    if ($dataset->sp_person_id() != $logged_in_user) {
        $c->stash->{rest} = { error => "Only the owner can change a dataset" };
        return;
    }
    my $error = $dataset->update_description($dataset_description);

    if ($error) {
        $c->stash->{rest} = { error => $error };
    } else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub get_dataset :Path('/ajax/dataset/get') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id),
	    people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id),
	    sp_dataset_id=> $dataset_id,
	});

    my $dataset_data = $dataset->get_dataset_data();

    $c->stash->{rest} = { dataset => $dataset_data };
}

sub get_child_analyses :Path('/ajax/dataset/get_child_analyses') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id),
	    people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id),
	    sp_dataset_id=> $dataset_id,
	});

    my $analysis_list;
    eval {
        $analysis_list = $dataset->get_child_analyses();
    };

    if ($@){
        $c->stash->{rest} = {error => "Error retrieving analyses using this dataset. $@"};
    }

    if ($analysis_list eq "") {
        $analysis_list = "(none)";
    }

    print STDERR "Got the following list of accessions using this dataset: $analysis_list \n";

    $c->stash->{rest} = { analysis_html_list => $analysis_list };
}


sub retrieve_dataset_dimension :Path('/ajax/dataset/retrieve') Args(2) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $dimension = shift;
    my $include_phenotype_primary_key = $c->req->param('include_phenotype_primary_key');
    
    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    sp_dataset_id=> $dataset_id,
        include_phenotype_primary_key => $include_phenotype_primary_key,
	});

    my $dimension_data;
    my $function_name = 'retrieve_'.$dimension;
    if ($dataset->can($function_name)) {

	$dimension_data = $dataset->$function_name();
    }
    else {
	$c->stash->{rest} = { error => "The specified dimension '$dimension' does not exist" };
	return;
    }

    $c->stash->{rest} = { dataset_id => $dataset_id,
			  $dimension => $dimension_data,
    };
}

sub calc_tool_compatibility :Path('/ajax/dataset/calc_tool_compatibility') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $include_phenotype_primary_key = $c->req->param('include_phenotype_primary_key');

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    sp_dataset_id=> $dataset_id,
        include_phenotype_primary_key => $include_phenotype_primary_key
	});

    my $genotyping_protocol = $c->config->{default_genotyping_protocol} =~ s/ /_/gr; 
    my $dbhost = $c->config->{dbhost};
    my $dbuser = $c->config->{dbuser};
    my $dbname = $c->config->{dbname};
    my $dbpass = $c->config->{dbpass};
    
    my $cmd = "mx-run CXGN::Dataset::ToolCompatibility".
                " --dataset_id $dataset_id".
                " --genotyping_protocol $genotyping_protocol".
                " --dbhost $dbhost".
                " --dbname $dbname".
                " --user $dbuser".
                " --password $dbpass";

    my $user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    eval {
        my $job = CXGN::Job->new({
            schema => $c->dbic_schema("Bio::Chado::Schema"),
            people_schema => $c->dbic_schema("CXGN::People::Schema"),
            sp_person_id => $user,
            name => $dataset->name()." tool compatibility check",
            results_page => "/dataset/$dataset_id",
            job_type => 'tool_compatibility',
            cmd => $cmd,
            finish_logfile => $c->config->{job_finish_log}
        });

        $job->submit();
    };

    if ($@){
        $c->stash->{rest} = {
            error => "Error calculating tool compatibility:\n$@"
        };
    } else {
         $c->stash->{rest} = {
            message => "Tool compatibility submitted. Check job logs for progress.\n",
            success => 1
         };
    }
}

sub delete_dataset :Path('/ajax/dataset/delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    if (!$c->user()) {
	$c->stash->{rest} = { error => "Deleting datasets requires login" };
	return;
    }

    my $logged_in_user = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema", undef, $logged_in_user),
	    people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $logged_in_user),
	    sp_dataset_id=> $dataset_id,
	});

#    print STDERR "Dataset owner: ".$dataset->sp_person_id.", logged in: $logged_in_user\n";
    if ($dataset->sp_person_id() != $logged_in_user) {
	$c->stash->{rest} = { error => "Only the owner can delete a dataset" };
	return;
    }

    my $error = $dataset->delete();

    if ($error) {
	$c->stash->{rest} = { error => $error };
    }
    else {
	$c->stash->{rest} = { success => 1 };
    }
}

#
# Get the external services that are configured on this instance for publishing datasets
#
sub publish_dataset_services : Path('/ajax/dataset/publish/services') Args(0) {
    my $self = shift;
    my $c = shift;

    my $config = $c->get_conf('dataset_archive_clients') || {};
    my %rtn;
    foreach my $k (keys %$config) {
        $rtn{$k} = {
            key => $k,
            type => $config->{$k}->{type},
            display_name => $config->{$k}->{display_name},
            web_url => $config->{$k}->{web_url},
            user_path => $config->{$k}->{user_path}
        };
    }

    $c->stash->{rest} = \%rtn;
    return;
}

#
# Store the user's connection info for the specified service
# This is called after the user has gone through the OAuth flow and has received an auth code
# This will request an access token using the auth code and use the token to get the account profile info
# The token and profile info are stored in the User Prefs (dataset_publish_${service} key)
#
sub publish_dataset_connection : Path('/ajax/dataset/publish/connection') : ActionClass('REST') { }
sub publish_dataset_connection_POST {
    my $self = shift;
    my $c = shift;
    my $code = $c->req->body_params->{code};
    my $service = $c->req->body_params->{service};
    my $ua = LWP::UserAgent->new();

    my $config = $c->get_conf('dataset_archive_clients') || {};
    if ( ! exists $config->{$service} ) {
        $c->stash->{rest} = { error => 'The selected service does not exist in the server configuration' };
        return;
    }
    my $selected = $config->{$service};

    # Get access token
    my $resp = $ua->post(
        $selected->{api_url} . '/token',
        {
            client_id => $selected->{client_id},
            client_secret => $selected->{client_secret},
            grant_type => "authorization_code",
            code => $code,
        }
    );
    my $token = decode_json($resp->content || {});

    # Add token expiration to token data
    my $now = time * 1000;
    my $expiration = $now + $token->{expires_in};
    $token->{expiration} = $expiration;

    # Get user info with token
    $resp = $ua->get(
        $selected->{api_url} . '/account',
        "Authorization" => "Bearer " . $token->{access_token},
    );
    my $profile = decode_json($resp->content || {});

    # Store token and profile in User Prefs
    my $prefs = CXGN::Page::UserPrefs->new(CXGN::DB::Connection->new());
    my $stored = {
        token => $token,
        profile => $profile
    };
    $prefs->set_pref("dataset_publish_$service", encode_json($stored));
    $prefs->save();

    # Return basic token and profile info
    $c->stash->{rest} = {
        token => {
            expiration => $token->{expiration}
        },
        profile => {
            first_name => $profile->{first_name},
            last_name => $profile->{last_name},
            email => $profile->{email},
            id => $profile->{id},
            user_id => $profile->{user_id}
        }
    };
    return;
}

#
# Get and check the validity of the stored connection info for the specified service
# This checks to make sure the token has not expired and returns basic profile info if it is still valid
#
sub publish_dataset_connection_GET : Path('/ajax/dataset/publish/connection') Args(1) {
    my $self = shift;
    my $c = shift;
    my $service = shift;

    my $prefs = CXGN::Page::UserPrefs->new(CXGN::DB::Connection->new());
    my $stored = decode_json( $prefs->get_pref("dataset_publish_$service") || '{}' );
    my $rtn = {};

    if ( exists $stored->{token}->{access_token} && exists $stored->{token}->{expiration} ) {
        my $now = time * 1000;
        my $cutoff = $now - 3600000;    # make sure token is good for at least another hour
        if ( $cutoff <= $stored->{token}->{expiration} ) {
            $rtn = {
                token => {
                    expiration => $stored->{token}->{expiration}
                },
                profile => {
                    first_name => $stored->{profile}->{first_name},
                    last_name => $stored->{profile}->{last_name},
                    email => $stored->{profile}->{email},
                    id => $stored->{profile}->{id},
                    user_id => $stored->{profile}->{user_id}
                }
            }
        }
    }

    $c->stash->{rest} = $rtn;
    return;
}

#
# Remove the stored connection preferences for the specified service
#
sub publish_dataset_connection_DELETE : Path('/ajax/dataset/publish/connection/remove') Args(1) {
    my $self = shift;
    my $c = shift;
    my $service = shift;

    my $prefs = CXGN::Page::UserPrefs->new(CXGN::DB::Connection->new());
    $prefs->set_pref("dataset_publish_$service", undef);
    $prefs->save();

    $c->stash->{rest} = { success => 1 };
    return;
}

#
# Get account articles for the user on the specified service
#
sub publish_dataset_articles : Path('/ajax/dataset/publish/articles') Args(1) {
    my $self = shift;
    my $c = shift;
    my $service = shift;
    my $ua = LWP::UserAgent->new();

    my $prefs = CXGN::Page::UserPrefs->new(CXGN::DB::Connection->new());
    my $stored = decode_json( $prefs->get_pref("dataset_publish_$service") || '{}' );
    my $token = $stored->{token}->{access_token};

    my $config = $c->get_conf('dataset_archive_clients') || {};
    if ( ! exists $config->{$service} ) {
        $c->stash->{rest} => { error => 'The selected service does not exist in the server configuration' };
        return;
    }
    my $selected = $config->{$service};

    my $resp = $ua->get(
        $selected->{api_url} . '/account/articles',
        "Authorization" => "Bearer " . $token
    );
    my $articles = decode_json($resp->content || []);
    $c->stash->{rest} = { articles => $articles };
    return;
}

#
# Get details of specific article from user's account on external service
#
sub publish_dataset_articles_details : Path('/ajax/dataset/publish/articles') Args(2) {
    my $self = shift;
    my $c = shift;
    my $service = shift;
    my $article = shift;
    my $ua = LWP::UserAgent->new();

    my $prefs = CXGN::Page::UserPrefs->new(CXGN::DB::Connection->new());
    my $stored = decode_json( $prefs->get_pref("dataset_publish_$service") || '{}' );
    my $token = $stored->{token}->{access_token};

    my $config = $c->get_conf('dataset_archive_clients') || {};
    if ( ! exists $config->{$service} ) {
        $c->stash->{rest} => { error => 'The selected service does not exist in the server configuration' };
        return;
    }
    my $selected = $config->{$service};

    # Get specific article
    my $resp = $ua->get(
        $selected->{api_url} . '/account/articles/' . $article,
        "Authorization" => "Bearer " . $token
    );
    my $article = decode_json($resp->content || {});
    $c->stash->{rest} = { article => $article };
    return;
}

#
# Create a new article on the external service
#
sub publish_dataset_articles_new : Path('/ajax/dataset/publish/articles/new') : ActionClass('REST') { }
sub publish_dataset_articles_new_POST {
    my $self = shift;
    my $c = shift;
    my $service = $c->req->body_params->{service};
    my $title = $c->req->body_params->{title};
    my $description = $c->req->body_params->{description};
    my $authors = $c->req->body_params->{authors};
    my $ua = LWP::UserAgent->new();

    my $prefs = CXGN::Page::UserPrefs->new(CXGN::DB::Connection->new());
    my $stored = decode_json( $prefs->get_pref("dataset_publish_$service") || '{}' );
    my $token = $stored->{token}->{access_token};

    my $config = $c->get_conf('dataset_archive_clients') || {};
    if ( ! exists $config->{$service} ) {
        $c->stash->{rest} => { error => 'The selected service does not exist in the server configuration' };
        return;
    }
    my $selected = $config->{$service};

    # Create Article
    # TODO
}

#
# Generate the archived files for the dataset
#
sub publish_dataset_generate : Path('/ajax/dataset/publish/generate') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $dataset_archive_path = $c->config->{dataset_archive_path};
    my @editable_stock_props = split ',', $c->config->{editable_stock_props};

    my $dataset = CXGN::Dataset->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id => $dataset_id
    });

    if (!$c->user()) {
        $c->stash->{rest} = { error => "Login required to perform requested action." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    if ($dataset->sp_person_id() != $user_id ) {
        $c->stash->{rest} = { error => "Only the owner can publish a dataset" };
        return;
    }

    my $resp = $dataset->generate_archive_files($dataset_archive_path, \@editable_stock_props);
    if ( defined $resp->{error} ) {
        print STDERR "GENERATE ARCHIVE FILES ERROR = " . Dumper $resp->{error};
        $c->stash->{rest} = { error => "Could not generate archive files [" . $resp->{error} . "]" };
        return;
    }

    if ( defined $resp->{directory} ) {
        $dataset->add_published($user_id, $resp->{directory}, $resp->{files});
    }
    else {
        $c->stash->{rest} = { error => "Could not generate archive files" };
        return;
    }

    $c->stash->{rest} = { success => 1 };
    return;
}

#
# Submit the arcived files to the specified article on the external service
#
sub publish_dataset_submit : Path('/ajax/dataset/publish/submit') : ActionClass('REST') { }
sub publish_dataset_submit_POST {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->body_params->{dataset_id};
    my $key = $c->req->body_params->{key};
    my $file = $c->req->body_params->{file};
    my $token = $c->req->body_params->{token};

    # TODO: Upload files to FigShare
    print STDERR "\n\n\n\n===> SUBMIT FILE: $dataset_id | $key | $file\n";
    print STDERR "TOKEN: $token\n";
    sleep 5;

    $c->stash->{rest} = { success => 1 };
}

#
# Get the published issues of the dataset
#
sub publish_dataset_issues : Path('/ajax/dataset/publish/issues') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $dataset = CXGN::Dataset->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id => $dataset_id
    });

    $c->stash->{rest} = { published => $dataset->published() };
    return;
}

#
# Remove a specific set of archived files for the dataset
#
sub publish_dataset_remove : Path('/ajax/dataset/publish/issues/remove') Args(2) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $key = shift;
    my $dataset_archive_path = $c->config->{dataset_archive_path};

    my $dataset = CXGN::Dataset->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id => $dataset_id
    });

    if (!$c->user()) {
        $c->stash->{rest} = { error => "Login required to perform requested action." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    if ($dataset->sp_person_id() != $user_id ) {
        $c->stash->{rest} = { error => "Only the owner can remove published metadata" };
        return;
    }

    my $resp = $dataset->remove_published($key, $dataset_archive_path);

    $c->stash->{rest} = $resp;
    return;
}

#
# Download a specific archived file, specified by the publish key and file name
#
sub publish_dataset_file : Path('/ajax/dataset/publish/file') Args(3) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $key = shift;
    my $file = shift;

    my $dataset = CXGN::Dataset->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id => $dataset_id
    });

    my $published = $dataset->published();

    if ( exists $published->{$key} ) {
        my $dir = $published->{$key}->{directory};
        my $path = "$dir/$file";

        if ( -f "$path" ) {
            $c->res->content_type('text/plain');
            $c->res->header('Content-Disposition', qq[attachment; filename="$file"]);

            my $output = "";
            open(my $F, "< :raw", $path) || return { error => 'Cannot open file to read contents' };
            while (<$F>) {
                $output .= $_;
            }
            close($F);

            $c->res->body($output);
        }
        else {
            $c->stash->{rest} = { error => 'The specified file does not exist' };
            return;
        }
    }
    else {
        $c->stash->{rest} = { error => 'The specified published metadata does not exist' };
        return;
    }
}

1
