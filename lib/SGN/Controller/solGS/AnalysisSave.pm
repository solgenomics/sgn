package SGN::Controller::solGS::AnalysisSave;

use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use DateTime;
use Data::Dumper;
use File::Find::Rule;
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use JSON;
use Scalar::Util 'reftype';
use Storable qw/ nstore retrieve /;
use Try::Tiny;
use URI;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
    );


sub check_analysis_result :Path('/solgs/check/stored/analysis/') Args() {
    my ($self, $c) = @_;

    $self->check_stored_analysis($c);

}


sub result_details :Path('/solgs/analysis/result/details') Args() {
    my ($self, $c) = @_;

	my $stored = $self->check_stored_analysis($c);

	if (!$stored)
	{
		my $params = $c->req->params;
		my $analysis_details;

		eval
		{
			$analysis_details = $self->structure_gebvs_result_details($c, $params);
		};

		if ($@)
		{
			print STDERR "\n$@\n";
			$c->stash->{rest}{error} = 'Something went wrong structuring the analysis result';
		}
		else
		{

		$c->stash->{rest}{analysis_details} = $analysis_details;
		}
	}

}


sub structure_gebvs_result_details {
	my ($self, $c, $params) = @_;

	my $gebvs = $self->structure_gebvs_values($c, $params);
	my @accessions = keys %$gebvs;

	my $trait_names		= $self->analysis_traits($c);
	my $model_details = $self->model_details($c);
	my $app_details		= $self->app_details();
	my $log					 = $self->analysis_log($c);

    my $details = {
		'analysis_to_save_boolean' => 'yes',
		'analysis_name' => $log->{analysis_name},
		'analysis_description' => $log->{training_pop_desc},
		'analysis_year' => $self->analysis_year($c),
		'analysis_breeding_program_id' => $self->analysis_breeding_prog($c),
		'analysis_protocol' => $model_details->{protocol},
		'analysis_dataset_id' => '',
		'analysis_accession_names' => encode_json(\@accessions),
		'analysis_trait_names' =>encode_json($trait_names),
		'analysis_precomputed_design_optional' =>'',
		'analysis_result_values' => to_json($gebvs),
		'analysis_result_values_type' => 'analysis_result_values_match_accession_names',
		'analysis_result_summary' => '',
		'analysis_result_trait_compose_info' =>  "",
		'analysis_statistical_ontology_term' =>  $model_details->{stat_ont_term},
		'analysis_model_application_version' => $app_details->{version},
		'analysis_model_application_name' => $app_details->{name},
		'analysis_model_language' => $model_details->{model_lang},
		'analysis_model_is_public' => 'yes',
		'analysis_model_description' =>  $model_details->{model_desc},
		'analysis_model_name' => $log->{analysis_name},
		'analysis_model_type' => $model_details->{model_type},
	};

	return $details;

}


sub app_details {
	my $self = shift;

	my $ver = qx / git describe --tags --abbrev=0 /;

	my $details = {
		'name' => 'solGS',
		'version' => $ver
	};

	return $details;

}


sub analysis_traits {
	my ($self, $c) = @_;

	my $log = $self->analysis_log($c);
	my $trait_ids = $log->{trait_id};
	my @trait_names;

	foreach my $tr_id (@$trait_ids)
	{
		my $extended_name = $self->extended_trait_name($c, $tr_id);
		push @trait_names, $extended_name;
	}

	return \@trait_names;

}


sub analysis_breeding_prog {
	my ($self, $c) = @_;

	my $log = $self->analysis_log($c);

	my $trial_id = $log->{training_pop_id}[0];
	if ($log->{data_set_type} =~ /combined/)
	{
		my $trials_ids = $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $trial_id);
		$trial_id = $trials_ids->[0];
	}

	if ($trial_id =~ /list/)
	{
		$trial_id = $c->controller('solGS::List')->get_trial_id_plots_list($c, $trial_id);
	}

	my $program_id;
	if ($trial_id =~ /^\d+$/)
	{
		$program_id = $c->model('solGS::solGS')->trial_breeding_program_id($trial_id);
	}

	return $program_id;

}


sub model_details {
	my ($self, $c) = @_;

	my $model_type = 'gblup_model_rrblup';
	my $stat_ont_term = 'GEBVs using GBLUP from rrblup R package|SGNSTAT:0000038';
	my $protocol = "GBLUP model from RRBLUP R Package";
	my $log = $self->analysis_log($c);
	my $model_page = $log->{analysis_page};
	my $model_desc= qq | <a href="$model_page">Go to model detail page</a>|;
	#my $model_desc = 'test desc';

	my $details = {
		'model_type' => $model_type,
		'model_page' => $model_page,
		'model_desc' => $model_desc,
		'model_lang' => 'R',
		'stat_ont_term' => $stat_ont_term,
		'protocol' => $protocol
	};

	return $details;
}


sub analysis_year {
	my ($self, $c) = @_;

	my $log = $self->analysis_log($c);
	my $time = $log->{analysis_time};

	my $time= (split(/\s+/, $time))[0];
	my $year = (split(/\//, $time))[2];

	return $year;

}


sub check_stored_analysis {
	my ($self, $c) = @_;

	my $log = $self->analysis_log($c);
	my $analysis_name = $log->{analysis_name};

	if ($analysis_name)
	{
		my $schema = $self->schema($c);
        my $analysis= $schema->resultset("Project::Project")->find({ name => $analysis_name });

	    if ($analysis)
		{
			my $analysis_id = $analysis->project_id;
            $c->stash->{rest} = {
				analysis_id =>  $analysis_id,
				error => "This model GEBVs are already in the database."
			};

			return 1;
		}
	}

	return;
}


sub extended_trait_name {
	my ($self, $c, $trait_id) = @_;

	my $schema = $self->schema($c);
	# foreach my $tr_id (@$trait_ids) {
		#$c->controller('solGS::solGS')->get_trait_details($c, $tr_id);
		my $extended_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $trait_id, 'extended');
		# push @trait_names, $extended_name;
	# }

	return $extended_name;

}


sub gebvs_values {
	my ($self, $c, $params) = @_;

	my $training_pop_id = $params->{training_pop_id};
	my $selection_pop_id = $params->{selection_pop_id};
	my $trait_id = $params->{trait_id};
	my $protocol_id = $params->{genotyping_protocol_id};

	$c->stash->{genotyping_protocol_id} = $protocol_id;

	my $ref = $c->req->referer;
	my $path = $c->req->path;
	my $gebvs_file;
	if ($ref =~ /solgs\/trait\/|solgs\/model\/combined\/trials\//)
	{
			$gebvs_file = $c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $training_pop_id, $trait_id);
	}
	elsif ($ref =~ /solgs\/selection\/|solgs\/combined\/model\/\d+|\w+_\d+\/selection\//)
	{
		$gebvs_file = $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
	}

	my $gebvs = $c->controller('solGS::Utils')->read_file_data($gebvs_file);

	return $gebvs;

}


sub structure_gebvs_values {
	my ($self, $c, $params) = @_;

	my $trait_name = $self->extended_trait_name($c, $params->{trait_id});

	my $gebvs = $self->gebvs_values($c, $params);
	my $gebvs_ref = $c->controller('solGS::Utils')->convert_arrayref_to_hashref($gebvs);

	my %gebvs_hash;
	my $now = DateTime->now();
	my $timestamp = $now->ymd()."T".$now->hms();

	my $user = $c->controller('solGS::AnalysisQueue')->get_user_detail($c);
	my $user_name = $user->{user_name};

	my @accessions = keys %$gebvs_ref;

	foreach my $accession (@accessions)
	{
		$gebvs_hash{$accession} = {
			$trait_name => [$gebvs_ref->{$accession}, $timestamp, $user_name, "", ""]
		};
	}

	return \%gebvs_hash;

}


sub analysis_log {
	my ($self, $c) = @_;

	my $files = $self->all_users_analyses_logs($c);
	my $ref = $c->req->referer;
	my $base = $c->req->base;
	$ref =~ s/$base//;

	my @log;
	foreach my $log_file (@$files)
	{
		my @logs = read_file($log_file, {binmode => ':utf8'});
		my ($log) = grep{ $_ =~ /$ref/} @logs;

		@log = split(/\t/, $log);
	}

	if (@log)
	{
		return decode_json($log[5]);
	}
	else
	{
		return;
	}

}


sub all_users_analyses_logs {
	my ($self, $c) = @_;

	my $dir = $c->stash->{analysis_log_dir};
	my $rule = File::Find::Rule->new;
	$rule->file;
	$rule->nonempty;
	$rule->name('analysis_log');

	my @files = $rule->in($dir);

	return \@files;

}


sub schema {
	my ($self, $c) = @_;

	return  $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}




__PACKAGE__->meta->make_immutable;


####
1;
####
