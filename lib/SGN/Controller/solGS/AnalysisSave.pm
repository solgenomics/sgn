package SGN::Controller::solGS::AnalysisSave;

use Moose;
use namespace::autoclean;

use DateTime;
use Data::Dumper;
use File::Find::Rule;
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use JSON;

use Try::Tiny;
use Storable qw/ nstore retrieve /;
use Carp qw/ carp confess croak /;
use Scalar::Util 'reftype';
use URI;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
    );


sub check_analysis_result :Path('/solgs/check/analysis/result') Args() {
    my ($self, $c) = @_;

    #my $

}


sub result_id :Path('/solgs/result/id') Args() {
    my ($self, $c) = @_;



}

sub result_details :Path('/solgs/analysis/result/details') Args() {
    my ($self, $c) = @_;

	my $stored = $self->check_stored_analysis($c);


	if (!$stored)
	{
		my $params = $c->req->params;
		$c->stash->{rest}{analysis_details} = $self->structure_gebvs_result_details($c, $params);
	}

}

sub structure_gebvs_result_details {
	my ($self, $c, $params) = @_;

	my $gebvs = $self->structure_gebvs_values($c, $params);
	my @accessions = keys %$gebvs;

	my $log = $self->analysis_log($c);
	my $trial_id = $log->{training_pop_id}[0];
	my $program_id = $c->model('solGS::solGS')->trial_breeding_program_id($trial_id);

	my $trait_ids = $log->{trait_id};
	my @trait_names;

	foreach my $tr_id (@$trait_ids)
	{
		my $extended_name = $self->extended_trait_name($c, $tr_id);
		push @trait_names, $extended_name;
	}

	#my $user = $c->controller('solGS::AnalysisQueue')->get_user_detail($c);
	my $model_type = 'mixed_model_lmer';#'GEBVs using GBLUP from rrblup R package';
	my $ont_term = 'GEBVs using GBLUP from rrblup R package|SGNSTAT:0000038';

	my $model_page = $log->{analysis_page};
	$model_page = qq | <a href="$model_page">Go to model detail page</a>|;
	my $model_desc = 'test desc';

    my $details = {
		'analysis_to_save_boolean' => 'yes',
		'analysis_name' => $log->{analysis_name},
		'analysis_description' => $log->{training_pop_desc},
		'analysis_year' => 2021,
		'analysis_breeding_program_id' => $program_id,
		'analysis_protocol' => 'GBLUP',
		'analysis_dataset_id' => '',
		'analysis_accession_names' => encode_json(\@accessions),
		'analysis_trait_names' =>encode_json(\@trait_names),
		'analysis_precomputed_design_optional' =>'',
		'analysis_result_values' => to_json($gebvs),
		'analysis_result_values_type' => 'analysis_result_values_match_accession_names',
		'analysis_result_summary' => '',
		'analysis_model_type' => $model_type,
		'analysis_result_trait_compose_info' =>  "",
		'analysis_statistical_ontology_term' => $ont_term,
		'analysis_model_application_version' => 'sgn-292',
		'analysis_model_application_name' => 'solGS',
		'analysis_model_language' => 'R',
		'analysis_model_is_public' => 'yes',
		'analysis_model_description' => $model_page,
		'analysis_model_name' => $log->{analysis_name},
	};

	return $details;

}

sub check_stored_analysis {
	my ($self, $c) = @_;

	my $log = $self->analysis_log($c);
	my $analysis_name = $log->{analysis_name};

	if ($analysis_name)
	{
		my $schema = $self->schema();
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

	my $schema = $self->schema();
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
	my $gebvs_file;
	if ($ref =~ /solgs\/trait\//)
	{
		$gebvs_file = $c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $training_pop_id, $trait_id);
	}
	elsif ($ref =~ /solgs\/selection\//)
	{
		$gebvs_file = $c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
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

	return decode_json($log[5]);

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
