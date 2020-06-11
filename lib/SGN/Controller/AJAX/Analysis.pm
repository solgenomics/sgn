package SGN::Controller::AJAX::Analysis;

use Moose;

use File::Slurp;
use Data::Dumper;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Trial::TrialDesign;
use CXGN::AnalysisModel::SaveModel;
use URI::FromHash 'uri';
use JSON;
use CXGN::BreederSearch;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );



sub ajax_analysis : Chained('/') PathPart('ajax/analysis') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $analysis_id = shift;

    $c->stash->{analysis_id} = $analysis_id;
}

sub store_analysis_json : Path('/ajax/analysis/store/json') ActionClass("REST") Args(0) {}

sub store_analysis_json_POST {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    print STDERR Dumper $c->req->params();
    my $analysis_to_save_boolean = $c->req->param("analysis_to_save_boolean");
    my $analysis_model_to_save_boolean = $c->req->param("model_to_save_boolean");
    my $analysis_name = $c->req->param("analysis_name");
    my $analysis_description = $c->req->param("analysis_description");
    my $analysis_year = $c->req->param("analysis_year");
    my $analysis_breeding_program_id = $c->req->param("analysis_breeding_program_id");
    my $analysis_protocol = $c->req->param("analysis_protocol");
    my $analysis_dataset_id = $c->req->param("analysis_dataset_id");
    my $analysis_accession_names = $c->req->param("analysis_accession_names") ? decode_json $c->req->param("analysis_accession_names") : [];
    my $analysis_trait_names = $c->req->param("analysis_trait_names") ? decode_json $c->req->param("analysis_trait_names") : [];
    my $analysis_precomputed_design_optional = $c->req->param("analysis_precomputed_design_optional") ? decode_json $c->req->param("analysis_precomputed_design_optional") : undef;
    my $analysis_result_values = $c->req->param("analysis_result_values") ? decode_json $c->req->param("analysis_result_values") : {};
    my $analysis_result_values_type = $c->req->param("analysis_result_values_type");
    my $analysis_model_parameters = $c->req->param("analysis_model_parameters") ? decode_json $c->req->param("analysis_model_parameters") : {};
    my $analysis_model_name = $c->req->param("analysis_model_name");
    my $analysis_model_description = $c->req->param("analysis_model_description");
    my $analysis_model_is_public = $c->req->param("analysis_model_is_public");
    my $analysis_model_language = $c->req->param("analysis_model_language");
    my $analysis_model_type = $c->req->param("analysis_model_type");
    my $analysis_model_experiment_type = $c->req->param("analysis_model_experiment_type");
    my $analysis_model_properties = $c->req->param("analysis_model_properties") ? decode_json $c->req->param("analysis_model_properties") : {};
    my $analysis_model_application_name = $c->req->param("analysis_model_application_name");
    my $analysis_model_application_version = $c->req->param("analysis_model_application_version");
    my $analysis_model_file = $c->req->param("analysis_model_file");
    my $analysis_model_file_type = $c->req->param("analysis_model_file_type");
    my $analysis_model_training_data_file = $c->req->param("analysis_model_training_data_file");
    my $analysis_model_training_data_file_type = $c->req->param("analysis_model_training_data_file_type");
    my $analysis_model_auxiliary_files = $c->req->param("analysis_model_auxiliary_files") ? decode_json $c->req->param("analysis_model_auxiliary_files") : [];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $check_name = $schema->resultset("Project::Project")->find({ name => $analysis_name });
    if ($check_name) {
        $c->stash->{rest} = {error => "An analysis with name $analysis_name already exists in the database. Please choose another name."};
        return;
    }

    $self->store_data($c,
        $analysis_to_save_boolean, $analysis_model_to_save_boolean,
        $analysis_name, $analysis_description, $analysis_year, $analysis_breeding_program_id, $analysis_protocol, $analysis_dataset_id, $analysis_accession_names, $analysis_trait_names, $analysis_precomputed_design_optional, $analysis_model_parameters, $analysis_result_values, $analysis_result_values_type,
        $analysis_model_name, $analysis_model_description, $analysis_model_is_public, $analysis_model_language, $analysis_model_type, $analysis_model_experiment_type, $analysis_model_properties, $analysis_model_application_name, $analysis_model_application_version, $analysis_model_file, $analysis_model_file_type, $analysis_model_training_data_file, $analysis_model_training_data_file_type, $analysis_model_auxiliary_files,
        $user_id, $user_name, $user_role
    );
}

#PLEASE ONLY USE JSON FUNCTION ABOVE
#
# sub store_analysis_file : Path('/ajax/analysis/store/file') ActionClass("REST") Args(0) {}
# 
# sub store_analysis_file_POST {
#     my $self = shift;
#     my $c = shift;
#     my $schema = $c->dbic_schema("Bio::Chado::Schema");
# 
#     my $file = $c->req->param("file");
#     my $dir = $c->req->param("dir"); # the dir under tempfiles/
# 
#     my $params = $c->req->params();
#     my $analysis_name = $c->req->param("analysis_name");
#     my $analysis_type = $c->req->param("analysis_type");
#     my $dataset_id = $c->req->param("dataset_id");
#     my $description = $c->req->param("description");
#     my $breeding_program = $c->req->param("breeding_program");
#     my ($user_id, $user_name, $user_role) = _check_user_login($c);
# 
#     my $check_name = $schema->resultset("Project::Project")->find({ name => $analysis_name });
#     if ($check_name) {
#         $c->stash->{rest} = {error => "An analysis with name $analysis_name already exists in the database. Please choose another name."};
#         return;
#     }
# 
#     if (! defined($breeding_program)) {  
# 	my @roles = $c->user->get_object()->get_roles();
# 	print STDERR "ROLES = ".join(", ", @roles)."\n";
# 	# get breeding program, which are roles that are not user,submitter, sequencer or curator
# 
# 	foreach my $r (@roles) {
# 	    if ($r !~ m/curator|user|submitter|sequencer/) {
# 		$breeding_program = $r;
# 	    }
# 	}
#     }
#     print STDERR "Using breeding program $breeding_program\n";
# 
#     if (! $breeding_program) {
# 	$c->stash->{rest} = { error => "You do not have a breeding program associated with your account, which is required to store an analysis!" };
# 	return;
#     }
# 
#     print STDERR "Storing analysis file: $dir / $file...\n";
#     print STDERR <<INFO;
#     Analysis name: $analysis_name
#     Analysis type: $analysis_type
#     Description:   $description
# INFO
# 
#     print STDERR "Retrieving cvterms...\n";
#     my $analysis_type_row = SGN::Model::Cvterm->get_cvterm_row($schema, $params->{analysis_type}, 'experiment_type');
#     if (! $analysis_type_row) {
# 	my $error = "Provided analysis type ($params->{analysis_type}) does not exist in the database. Exiting.";
# 	print STDERR $error."\n";
# 	$c->stash->{rest} = { error =>  $error };
# 	return;
#     }
# 
#     my @plots;
#     my @stocks;
#     my %value_hash;
# 
#     my $analysis_type_id = $analysis_type_row->cvterm_id();    
# 
#     my $fullpath = $c->tempfiles_base()."/".$dir."/".$file;
# 
#     print STDERR "Reading analysis file path $fullpath...\n";
# 
#     my @lines = read_file($fullpath);
# 
#     my $header = shift(@lines);
#     chomp($header);
# 
#     my ($accession, @traits) = split /\t/, $header;
# 
#     my %good_terms = ();
# 
#     # remove illegal trait columns
#     #
#     my @good_traits;
#     foreach my $t (@traits) {
# 	my ($human_readable, $accession) = split /\|/, $t; #/
# 
# 	print "Checking term $t ($human_readable, $accession)...\n";
# 	my $term = CXGN::Cvterm->new( { schema => $schema, accession => $accession });
# 
# 	if ($term->cvterm_id()) {
# 	    $good_terms{$t} = 1;
# 	    push @good_traits, $t;
# 	}
# 	else {
# 	    $good_terms{$t} = 0; 
# 	}
#     }
# 
#     foreach my $line (@lines) {
# 	my ($acc, @values) = split /\t/, $line;
# 	$acc =~ s/\"//g;
# 	#print STDERR "Reading data for $acc with value ".join(",", @values)."...\n";
# 	my $plot_name = $analysis_name."_".$acc;
# 	push @plots, $plot_name;
# 	push @stocks, $acc;
# 	for(my $i=0; $i<@traits; $i++) {
# 	    if ($good_terms{$traits[$i]}) {  # only save good terms
# 		#print STDERR "Building hash with trait $traits[$i] and value $values[$i]...\n";
# 		if ($values[$i] eq 'NA') { $values[$i] = undef; }
# 		push @{$value_hash{$plot_name}->{$traits[$i]}}, $values[$i];
# 	    }
# 	}
#     }
# 
#     print STDERR "Storing data...\n";
#     return $self->store_data($c, $params->{analysis_name}, $params->{analysis_description}, $params->{dataset_id}, $params->{analysis_protocol}, \%value_hash, \@stocks, \@plots, \@good_traits, $user_id, $user_name, $user_role);
# }


sub store_data {
    my $self = shift;
    my ($c, $analysis_to_save_boolean, $analysis_model_to_save_boolean, $analysis_name, $analysis_description, $analysis_year, $analysis_breeding_program_id, $analysis_protocol, $analysis_dataset_id, $analysis_accession_names, $analysis_trait_names, $analysis_precomputed_design_optional, $analysis_model_parameters, $analysis_result_values, $analysis_result_values_type, $analysis_model_name, $analysis_model_description, $analysis_model_is_public, $analysis_model_language, $analysis_model_type, $analysis_model_experiment_type, $analysis_model_properties, $analysis_model_application_name, $analysis_model_application_version, $analysis_model_file, $analysis_model_file_type, $analysis_model_training_data_file, $analysis_model_training_data_file_type, $analysis_model_auxiliary_files, $user_id, $user_name, $user_role) = @_;
    
    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    my $analysis_model_protocol_id;
    if ($analysis_model_to_save_boolean eq 'yes') {
        my $model_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, $analysis_model_type, 'protocol_type')->cvterm_id();
        my $model_experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, $analysis_model_experiment_type, 'experiment_type')->cvterm_id();

        my $mo = CXGN::AnalysisModel::SaveModel->new({
            bcs_schema=>$bcs_schema,
            metadata_schema=>$metadata_schema,
            phenome_schema=>$phenome_schema,
            archive_path=>$c->config->{archive_path},
            model_name=>$analysis_model_name,
            model_description=>$analysis_model_description,
            model_language=>$analysis_model_language,
            model_type_cvterm_id=>$model_type_cvterm_id,
            model_experiment_type_cvterm_id=>$model_experiment_type_cvterm_id,
            model_properties=>$analysis_model_properties,
            application_name=>$analysis_model_application_name,
            application_version=>$analysis_model_application_version,
            dataset_id=>$analysis_dataset_id,
            is_public=>$analysis_model_is_public,
            archived_model_file_type=>$analysis_model_file_type,
            model_file=>$analysis_model_file,
            archived_training_data_file_type=>$analysis_model_training_data_file_type,
            archived_training_data_file=>$analysis_model_training_data_file,
            archived_auxiliary_files=>$analysis_model_auxiliary_files,
            user_id=>$user_id,
            user_role=>$user_role
        });
        $analysis_model_protocol_id = $mo->save_model();
    }

    my $saved_analysis_id;
    if ($analysis_to_save_boolean eq 'yes') {
        #Project BUILD inserts project entry
        my $a = CXGN::Analysis->new({
            bcs_schema => $bcs_schema,
            people_schema => $people_schema,
            name => $analysis_name,
        });
        $saved_analysis_id = $a->get_trial_id();

        if ($analysis_dataset_id !~ /^\d+$/) {
            print STDERR "Dataset ID $analysis_dataset_id not accetable.\n";
            $analysis_dataset_id = undef;
        }

        if ($analysis_dataset_id) {
            $a->metadata()->dataset_id($analysis_dataset_id);
        }

        my $year_type_id = $bcs_schema->resultset('Cv::Cvterm')->find({ name => 'project year' })->cvterm_id;
        my $year_rs = $bcs_schema->resultset('Project::Projectprop')->create({
            type_id => $year_type_id,
            value => $analysis_year,
            project_id => $saved_analysis_id
        });

        $a->year($analysis_year);
        $a->breeding_program_id($analysis_breeding_program_id);
        $a->accession_names($analysis_accession_names);
        $a->description($analysis_description);
        $a->user_id($user_id);

        $a->metadata()->traits($analysis_trait_names);
        $a->metadata()->analysis_protocol($analysis_protocol);
        $a->metadata()->model_type($analysis_model_type);
        $a->metadata()->model_language($analysis_model_language);
        $a->metadata()->application_version($analysis_model_application_version);
        $a->metadata()->application_name($analysis_model_application_name);
        $a->metadata()->model_parameters($analysis_model_parameters);

        $a->analysis_model_protocol_id($analysis_model_protocol_id);

        my ($verified_warning, $verified_error);
        print STDERR "Storing the analysis...\n";
        eval {
            ($verified_warning, $verified_error) = $a->create_and_store_analysis_design($analysis_precomputed_design_optional);
        };

        my @errors;
        my @warnings;
        if ($@) {
            push @errors, $@;
        }
        elsif ($verified_warning) {
            push @warnings, $verified_warning;
        }
        elsif ($verified_error) {
            push @errors, $verified_error;
        }

        if (@errors) {
            print STDERR "SORRY! Errors: ".join("\n", @errors);
            $c->stash->{rest} = { error => join "; ", @errors };
            return;
        }

        print STDERR "Store analysis values...\n";
        #print STDERR "value hash: ".Dumper($values);
        print STDERR "traits: ".join(",",@$analysis_trait_names);

        my $analysis_result_values_save;
        if ($analysis_result_values_type eq 'analysis_result_values_match_precomputed_design') {
            $analysis_result_values_save = $analysis_result_values;
        }
        elsif ($analysis_result_values_type eq 'analysis_result_values_match_accession_names') {
            my %analysis_result_values_fix_plot_names;
            my $design = $a->design();
            foreach (values %$design) {
                $analysis_result_values_fix_plot_names{$_->{stock_name}} = $_->{plot_name};
            }
            while (my ($accession_name, $trait_pheno) = each %$analysis_result_values) {
                $analysis_result_values_save->{$analysis_result_values_fix_plot_names{$accession_name}} = $trait_pheno;
            }
        }
        my @analysis_instance_names = keys %$analysis_result_values_save;
        # print STDERR Dumper $analysis_result_values_save;

        my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
        my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');
        eval {
            $a->store_analysis_values(
                $metadata_schema,
                $phenome_schema,
                $analysis_result_values_save,
                \@analysis_instance_names,
                $analysis_trait_names,
                $user_name,
                $c->config->{basepath},
                $c->config->{dbhost},
                $c->config->{dbname},
                $c->config->{dbuser},
                $c->config->{dbpass},
                $temp_file_nd_experiment_id,
            );
        };

        if ($@) {
            print STDERR "An error occurred storing analysis values ($@).\n";
            $c->stash->{rest} = { error => "An error occurred storing the values ($@).\n" };
            return;
        }

        my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});
    }
    $c->stash->{rest} = { success => 1, analysis_id => $saved_analysis_id, model_id => $analysis_model_protocol_id };
}

sub list_analyses_by_user_table :Path('/ajax/analyses/by_user') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $user_id;
    if ($c->user()) {
        $user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }
    my @analyses = CXGN::Analysis->retrieve_analyses_by_user($schema, $people_schema, $user_id);

    my @table;
    foreach my $a (@analyses) {
        push @table, [
            '<a href="/analyses/'.$a->get_trial_id().'">'.$a->name()."</a>",
            $a->description(),
            $a->metadata->model_type(),
            $a->metadata->analysis_protocol(),
            $a->metadata->application_name().":".$a->metadata->application_version(),
            $a->metadata->model_language()
        ];
    }

    #print STDERR Dumper(\@table);
    $c->stash->{rest} = { data => \@table };
}


=head1 retrieve_analysis_data()

Chained from ajax_analysis
URL = /ajax/analysis/<analysis_id>/retrieve
returns data for the analysis_id in the following json structure:
{ 
    analysis_name
    analysis_description
    analysis_result_type
    dataset
    analysis_protocol
    accession_names
    data
}

=cut

sub retrieve_analysis_data :Chained("ajax_analysis") PathPart('retrieve') :Args(0)  {
    my $self = shift;
    my $c = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    
    my $a = CXGN::Analysis->new( { bcs_schema => $bcs_schema, people_schema => $people_schema, trial_id => $c->stash->{analysis_id} } );

    my $dataset_id = "";
    my $dataset_name = "";
    my $dataset_description = "";

    if ($a->metadata()->dataset_id()) {
        my $ds = CXGN::Dataset->new({ schema => $bcs_schema, people_schema => $people_schema, sp_dataset_id => $a->metadata()->dataset_id() });
        $dataset_id = $ds->sp_dataset_id();
        $dataset_name = $ds->name();
        $dataset_description = $ds->description();
    }

    my $matrix = $a->get_phenotype_matrix();
    # print STDERR "Matrix: ".Dumper($matrix);
    my $dataref = [];

    # format table body with links but exclude header
    my $header = shift @$matrix;
    $header = [ @$header[18, 39..scalar(@$header)-1 ]];

    foreach my $row (@$matrix) {
        my ($stock_id, $stock_name, @values) =  @$row[17,18,39..scalar(@$row)-1];
        print STDERR "NEW ROW: $stock_id, $stock_name, ".join(",", @values)."\n";
        push @$dataref, [
            "<a href=\"/stock/$stock_id/view\">$stock_name</a>",
            @values
        ];
    }

    unshift @$dataref, $header;

    # print STDERR "TRAITS : ".Dumper($a->traits());

    my $resultref = {
        analysis_name => $a->name(),
        analysis_description => $a->description(),
        dataset => {
            dataset_id => $dataset_id,
            dataset_name => $dataset_name,
            dataset_description => $dataset_description,
        },
        #accession_ids => $a ->accession_ids(),
        analysis_protocol => $a->metadata()->analysis_protocol(),
        create_timestamp => $a->metadata()->create_timestamp(),
        model_language => $a->metadata()->model_language(),
        model_type => $a->metadata()->model_type(),
        application_name => $a->metadata()->application_name(),
        application_version => $a->metadata()->application_version(),
        accession_names => $a->accession_names(),
        traits => $a->traits(),
        data => $dataref,
    };

    $c->stash->{rest} = $resultref;
}

sub _check_user_login {
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    return ($user_id, $user_name, $user_role);
}

1;
