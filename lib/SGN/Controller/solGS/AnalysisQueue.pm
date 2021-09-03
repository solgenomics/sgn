package SGN::Controller::solGS::AnalysisQueue;

use Moose;
use namespace::autoclean;
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use JSON;
use CXGN::Tools::Run;
use Try::Tiny;
use Storable qw/ nstore retrieve /;
use Carp qw/ carp confess croak /;
use Scalar::Util 'reftype';
use URI;

BEGIN { extends 'Catalyst::Controller' }


sub check_user_login :Path('/solgs/check/user/login') Args(0) {
	my ($self, $c) = @_;

	my $user = $c->user();
	my $ret->{loggedin} = 0;

	if ($user)
	{
		my $contact = $self->get_user_detail($c);

		$ret->{contact} = $contact;
		$ret->{loggedin} = 1;
	}

	$ret = to_json($ret);

	$c->res->content_type('application/json');
	$c->res->body($ret);

}


sub save_analysis_profile :Path('/solgs/save/analysis/profile') Args(0) {
	my ($self, $c) = @_;

	my $analysis_profile = $c->req->params;
	$c->stash->{analysis_profile} = $analysis_profile;

	my $analysis_page = $analysis_profile->{analysis_page};
	$c->stash->{analysis_page} = $analysis_page;

	my $ret->{result} = 0;

	$self->save_profile($c);
	my $error_saving = $c->stash->{error};

	if (!$error_saving)
	{
		$ret->{result} = 1;
	}

	$ret = to_json($ret);

	$c->res->content_type('application/json');
	$c->res->body($ret);

}


sub run_saved_analysis :Path('/solgs/run/saved/analysis/') Args(0) {
	my ($self, $c) = @_;

	my $analysis_profile = $c->req->params;
	$c->stash->{analysis_profile} = $analysis_profile;

	$self->parse_arguments($c);
	$self->structure_output_details($c);
	$self->run_analysis($c);

	my $ret->{result} = $c->stash->{status};
	$ret->{arguments} = $analysis_profile->{arguments};

	$ret = to_json($ret);

	$c->res->content_type('application/json');
	$c->res->body($ret);

}


sub check_analysis_name :Path('/solgs/check/analysis/name') Args() {
	my ($self, $c) = @_;

	my $new_name = $c->req->param('name');

	my $match = $self->check_analyses_names($c, $new_name);

	my $ret->{analysis_exists} = $match;
	$ret = to_json($ret);

	$c->res->content_type('application/json');
	$c->res->body($ret);

}


sub submission_feedback :Path('/solgs/submission/feedback/') Args() {
	my ($self, $c) = @_;

    my $job = $c->req->param('job');
    # $c->controller('solGS::Utils')->stash_json_args($c, $args);

	my $job_type = $self->get_confirm_msg($c, $job);
	my $user_id = $c->user()->get_object()->get_sp_person_id();
	my $referer = $c->req->referer;

	my $msg = "<p>$job_type</p>"
	. "<p>You will receive an email when it is completed. "
	. "You can also check the status of the job on "
	. "<a href=\"/solpeople/profile/$user_id\">your profile page</a>"
	. "<p><a href=\"$referer\">[ Go back ]</a></p>";

	$c->controller('solGS::Utils')->generic_message($c, $msg);

}


sub display_analysis_status :Path('/solgs/display/analysis/status') Args(0) {
	my ($self, $c) = @_;

	my $panel_data = $self->get_user_solgs_analyses($c);

	my $ret->{data} = $panel_data;
    my $json = JSON->new();
	$ret = $json->encode($ret);

	$c->res->content_type('application/json');
	$c->res->body($ret);

}


sub check_analyses_names {
	my ($self, $c, $new_name) = @_;

	my $logged_names = $self->check_log_analyses_names($c);

	my $log_match;
	if ($logged_names)
	{
		$log_match = grep { $_ =~ /$new_name/i } @$logged_names;
	}

	my $db_match;

	if ($new_name)
	{
		my $schema = $c->dbic_schema("Bio::Chado::Schema");
		$db_match = $schema->resultset("Project::Project")->find({ name => $new_name });
	}

	my $match = $log_match || $db_match ? 1 : 0;

	return $match;

}


sub check_log_analyses_names {
	my ($self, $c) = @_;

	my $log_file = $self->analysis_log_file($c);
	my $names = qx(cut -f 2 $log_file);

	if ($names)
	{
		my @names = split(/\n/, $names);

		shift(@names);
		return \@names;
	}
	else
	{
		return 0;
	}
}


sub save_profile {
	my ($self, $c) = @_;

	$self->analysis_log_file($c);
	my $log_file = $c->stash->{analysis_log_file};

	$self->add_log_headers($c);

	$self->format_log_entry($c);
	my $log_entry = $c->stash->{formatted_log_entry};

	write_file($log_file, {binmode => ':utf8', append => 1}, $log_entry);

}


sub add_log_headers {
	my ($self, $c) = @_;

	$self->analysis_log_file($c);
	my $log_file = $c->stash->{analysis_log_file};

	my $headers = read_file($log_file, {binmode => ':utf8'});

	unless ($headers)
	{
		$headers = 'User_name' .
		"\t" . 'Analysis_name' .
		"\t" . "Analysis_page" .
		"\t" . "Status" .
		"\t" . "Submitted on" .
		"\t" . "Arguments" .
		"\n";

		write_file($log_file, {binmode => ':utf8'}, $headers);
	}

}


sub index_log_file_headers {
	my ($self, $c) = @_;

	no warnings 'uninitialized';

	$self->analysis_log_file($c);
	my $log_file = $c->stash->{analysis_log_file};

	my @headers = split(/\t/, (read_file($log_file, {binmode => ':utf8'}))[0]);

	my $header_index = {};
	my $cnt = 0;

	foreach my $header (@headers)
	{
		$header_index->{$header} = $cnt;
		$cnt++;
	}

	$c->stash->{header_index} = $header_index;

}


sub create_itemized_prediction_log_entries {
	my ($self, $c, $analysis_log) = @_;

    $analysis_log = $self->log_analysis_time($analysis_log);

    my $json = JSON->new;
	my $args = $json->decode($analysis_log->{arguments});

	my $trait_ids = $args->{training_traits_ids};

    my $analysis_type = $args->{analysis_type};

    my $url_args = {
        'training_pop_id' => $args->{training_pop_id}->[0],
        'selection_pop_id' => $args->{selection_pop_id}->[0],
        'genotyping_protocol_id' => $args->{genotyping_protocol_id},
        'data_set_type' => $args->{data_set_type},
    };

    my $entries;
	foreach my $trait_id (@$trait_ids)
	{
		$c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
		my $trait_abbr = $c->stash->{trait_abbr};
        $url_args->{trait_id} = $trait_id;

		my $analysis_page;
        if ($analysis_type =~ /selection prediction/)
        {
           $analysis_page = $c->controller('solGS::Path')->selection_page_url($url_args);
        }
        else
        {
            $analysis_page = $c->controller('solGS::Path')->model_page_url($url_args);
            $analysis_type = 'single model';
        }

		my $analysis_name = $analysis_log->{analysis_name} . ' -- ' . $trait_abbr;

		$args->{analysis_page} = $analysis_page;
		$args->{analysis_name} = $analysis_name;
		$args->{trait_id} = [$trait_id];
		$args->{training_traits_ids} = [$trait_id];
		$args->{analysis_type} = $analysis_type;

		$entries .= join("\t", (
					$analysis_log->{user_name},
					$analysis_name,
					$analysis_page,
					'Submitted',
					$args->{analysis_time},
					$json->encode($args),)
		);

		$entries .= "\n";

	}

	return $entries;

}


sub log_analysis_time {
	my ($self, $analysis_log ) = @_;

	my $analysis_time = POSIX::strftime("%m/%d/%Y %H:%M", localtime);

	my $json = JSON->new;
	my $args = $json->decode($analysis_log->{arguments});

	$args->{analysis_time} = $analysis_time;
	$analysis_log->{arguments} = $json->encode($args);

	return $analysis_log;

}


sub format_log_entry {
    my ($self, $c) = @_;

    my $profile = $c->stash->{analysis_profile};
	$profile= $self->log_analysis_time($profile);
    my $args = $profile->{arguments};

	my $json = JSON->new;
	my $time = $json->decode($args)->{analysis_time};

   my $traits_args = $json->decode($args);
   my $traits_ids = $traits_args->{training_traits_ids} || $traits_args->{trait_id};
   my @traits_ids = ref($traits_ids) eq 'ARRAY' ? @$traits_ids : ($traits_ids);

   my $analysis_page;
   my $analysis_type = $traits_args->{analysis_type};

    if (@traits_ids > 1 && $analysis_type =~ /selection/)
    {
        $analysis_page = $traits_args->{referer};
    }
    else
    {
        $analysis_page = $traits_args->{analysis_page};
    }

    my $entry   = join("\t", (
    		$profile->{user_name},
    		$profile->{analysis_name},
    		$analysis_page,
    		'Submitted',
    		$time,
    		$args)
    );

    $entry .= "\n";

    if (@traits_ids > 1 && $analysis_type =~ /model|selection/ )
    {
    	my $traits_entries = $self->create_itemized_prediction_log_entries($c, $profile);
    	$entry .= $traits_entries;
    }

    $c->stash->{formatted_log_entry} = $entry;

}


sub analysis_report_job_args {
	my ($self, $c, $status_check_duration) = @_;

	my $analysis_details = $c->stash->{bg_job_output_details};

	my $temp_dir = $c->stash->{analysis_tempfiles_dir} || $c->stash->{solgs_tempfiles_dir} ;

	my $temp_file_template = "analysis-status";
	my $cluster_files = $c->controller('solGS::AsyncJob')->create_cluster_accessible_tmp_files($c, $temp_file_template);
	my $out_file      = $cluster_files->{out_file_temp};
	my $err_file      = $cluster_files->{err_file_temp};
	my $in_file       = $cluster_files->{in_file_temp};

	 my $config_args = {
		 'temp_dir' => $temp_dir,
		 'out_file' => $out_file,
		 'err_file' => $err_file,
		 'cluster_host' => 'localhost'
	 };

	my $report_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, 'analysis-report-args');
	nstore $analysis_details, $report_file
	or croak "analysis_report_job_args: $! serializing output_details to $report_file";

	my $job_config = $c->controller('solGS::AsyncJob')->create_cluster_config($c, $config_args);

	$status_check_duration =  ' --status_check_duration ' . $status_check_duration if $status_check_duration;

	my $cmd = 'mx-run solGS::AnalysisReport'
	. ' --output_details_file ' . $report_file
	. $status_check_duration;


	my $job_args = {
		'cmd' => $cmd,
		'config' => $job_config,
		'background_job'=> $c->stash->{background_job},
		'temp_dir' => $temp_dir,
	};

	$c->stash->{analysis_report_job_args} = $job_args;

}


sub get_analysis_report_job_args_file {
	my ($self, $c, $status_check_duration) = @_;

	$self->analysis_report_job_args($c, $status_check_duration);
	my $analysis_job_args = $c->stash->{analysis_report_job_args};

	my $temp_dir = $c->stash->{solgs_tempfiles_dir};

	my $report_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, 'analysis-report-job-args');
	nstore $analysis_job_args, $report_file
	or croak "get_analysis_report_job_args_file: $! serializing output_details to $report_file";

	$c->stash->{analysis_report_job_args_file} = $report_file;

}


sub email_analysis_report {
	my ($self, $c) = @_;

	$self->analysis_report_job_args($c);
	my $job_args = $c->stash->{analysis_report_job_args};

	my $job = $c->controller('solGS::AsyncJob')->submit_job_cluster($c, $job_args);

}

sub parse_arguments {
  my ($self, $c) = @_;

  my $analysis_data =  $c->stash->{analysis_profile};
  my $arguments     = $analysis_data->{arguments};
  my $data_set_type = $analysis_data->{data_set_type};

  if ($arguments)
  {
      $c->controller('solGS::Utils')->stash_json_args($c, $arguments);
  }

}


sub structure_output_details {
	my ($self, $c) = @_;

	my $analysis_data =  $c->stash->{analysis_profile};
	my $analysis_page = $analysis_data->{analysis_page};

	my $referer = $c->req->referer;
    my $base = $c->controller('solGS::Path')->clean_base_name($c);
	my $output_details = {};

	my $match_pages = 'solgs\/traits\/all\/population\/'
		. '|solgs\/trait\/'
		. '|solgs\/model\/combined\/trials\/'
		. '|solgs\/models\/combined\/trials\/';

	if ($analysis_page =~ m/$match_pages/)
	{
		$output_details = $self->structure_training_modeling_output($c);
	}
	elsif ( $analysis_page =~ m/solgs\/population\// )
	{
		$output_details = $self->structure_training_single_pop_data_output($c);
	}
	elsif ($analysis_page =~ m/solgs\/populations\/combined\//)
	{
		$output_details = $self->structure_training_combined_pops_data_output($c);
	}
	elsif ( $analysis_page =~ m/solgs\/selection\/(\d+|\w+_\d+)\/model\/|solgs\/combined\/model\/\d+\/selection\// )
	{
		$output_details = $self->structure_selection_prediction_output($c);
	}
	elsif ( $analysis_page =~ m/kinship\/analysis/ )
	{
		$output_details = $self->structure_kinship_analysis_output($c);
	}
    elsif ( $analysis_page =~ m/pca\/analysis/ )
	{
		$output_details = $self->structure_pca_analysis_output($c);
	}
    elsif ( $analysis_page =~ m/cluster\/analysis/ )
	{
		$output_details = $self->structure_cluster_analysis_output($c);
	}

	$self->analysis_log_file($c);
	my $log_file = $c->stash->{analysis_log_file};

	my $mail_list = $self->mailing_list($c);

	$output_details->{analysis_profile}  = $analysis_data;
	$output_details->{contact_page}      = $base . 'contact/form';
	$output_details->{data_set_type}     = $c->stash->{data_set_type};
	$output_details->{analysis_log_file} = $log_file;
	$output_details->{host}              = qq | $base |;
	$output_details->{referer}           = qq | $referer |;
	$output_details->{mailing_list} = $mail_list;

	$c->stash->{bg_job_output_details} = $output_details;

}

sub mailing_list {
    my ($self, $c) = @_;

    my $mail_list = $c->config->{cluster_job_email};

    if (!$mail_list)
    {
        $mail_list = 'cluster-jobs@solgenomics.net';
    }

    return $mail_list;
}

sub structure_kinship_analysis_output {
	my ($self, $c) = @_;

	my $analysis_data =  $c->stash->{analysis_profile};
	my $analysis_page = $analysis_data->{analysis_page};

	my $protocol_id   = $c->stash->{genotyping_protocol_id};

	$c->controller('solGS::Kinship')->stash_data_str_kinship_pop_id($c);
	my $pop_id = $c->stash->{kinship_pop_id};

    my $base = $c->controller('solGS::Path')->clean_base_name($c);

	my $kinship_page = $base . $analysis_page;
	$analysis_data->{analysis_page} = $kinship_page;

	my %output_details = ();

	my $trait_id = $c->stash->{trait_id};

	$c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
	my $geno_file  = $c->stash->{genotype_file_name};

	my $coef_files = $c->controller('solGS::Kinship')->get_kinship_coef_files($c, $pop_id, $protocol_id, $trait_id);
	my $matrix_file = $coef_files->{matrix_file_adj};

	$output_details{'kinship_' . $pop_id} = {
		'output_page'    => $kinship_page,
		'kinship_pop_id' => $pop_id,
		'genotype_file'  => $geno_file,
		'matrix_file'    => $matrix_file,
	};

   return \%output_details;
}


sub structure_pca_analysis_output {
	my ($self, $c) = @_;

	my $analysis_data =  $c->stash->{analysis_profile};
	my $analysis_page = $analysis_data->{analysis_page};

	my $pop_id = $c->stash->{pca_pop_id};

    my $base = $c->controller('solGS::Path')->clean_base_name($c);

	my $pca_page = $base . $analysis_page;
	$analysis_data->{analysis_page} = $pca_page;

	my %output_details = ();
	# $c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
     my $geno_file = $c->stash->{genotype_file_name};

    $c->stash->{file_id} = $c->controller('solGS::Files')->create_file_id($c);
    $c->controller('solGS::pca')->pca_scores_file($c);
	my $scores_file = $c->stash->{pca_scores_file};

	$output_details{'pca_' . $pop_id} = {
		'output_page'    => $pca_page,
		'pca_pop_id' => $pop_id,
		'genotype_file'  => $geno_file,
		'scores_file'    => $scores_file,
	};

   return \%output_details;

}


sub structure_cluster_analysis_output {
	my ($self, $c) = @_;

	my $analysis_data =  $c->stash->{analysis_profile};
	my $analysis_page = $analysis_data->{analysis_page};

	my $pop_id = $c->stash->{cluster_pop_id};

    my $base = $c->controller('solGS::Path')->clean_base_name($c);
	my $cluster_page = $base . $analysis_page;
	$analysis_data->{analysis_page} = $cluster_page;

	my %output_details = ();
	# $c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
    # my $geno_file = $c->stash->{genotype_file_name};
    my $input_file;
    $c->stash->{file_id} = $c->controller('solGS::Files')->create_file_id($c);
    $c->controller('solGS::Cluster')->kcluster_result_file($c);
	my $result_file = $c->stash->{'k-means_result_file'};

	$output_details{'cluster_' . $pop_id} = {
		'output_page'    => $cluster_page,
		'cluster_pop_id' => $pop_id,
		'input_file'  => $input_file,
		'result_file'    => $result_file,
	};

   return \%output_details;

}


sub structure_training_modeling_output {
    my ($self, $c) = @_;

    my $analysis_data =  $c->stash->{analysis_profile};
    my $analysis_page = $analysis_data->{analysis_page};

    my $pop_id        = $c->stash->{pop_id};
    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $protocol_id   = $c->stash->{genotyping_protocol_id};

    my @traits_ids = @{$c->stash->{training_traits_ids}} if $c->stash->{training_traits_ids};
    my $referer = $c->req->referer;

    my $base = $c->controller('solGS::Path')->clean_base_name($c);
	my $url_args = {
		'training_pop_id' => $pop_id,
		'genotyping_protocol_id' => $protocol_id,
	};

    my %output_details = ();

    foreach my $trait_id (@traits_ids)
    {
		$url_args->{trait_id} = $trait_id;

		$c->stash->{cache_dir} = $c->stash->{solgs_cache_dir};

		$c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
		$c->controller('solGS::Files')->rrblup_training_gebvs_file($c);

		my $trait_abbr = $c->stash->{trait_abbr};
		my $trait_page;


		if ( $referer =~ m/solgs\/population\// )
		{
			$url_args->{data_set_type} = 'single population';

	        my $model_page = $c->controller('solGS::Path')->model_page_url($url_args);
		    $trait_page = $base . $model_page;

		    if ($analysis_page =~ m/solgs\/traits\/all\/population\//)
		    {
				my $traits_selection_id = $c->controller('solGS::Gebvs')->create_traits_selection_id(\@traits_ids);
				$analysis_data->{analysis_page} = $base . "solgs/traits/all/population/" . $pop_id
				    . '/traits/' . $traits_selection_id
				    . '/gp/' . $protocol_id;

				$c->controller('solGS::Gebvs')->catalogue_traits_selection($c, \@traits_ids);
		    }
		}

		if ( $referer =~ m/solgs\/search\/trials\/trait\// && $analysis_page =~ m/solgs\/trait\// )
		{
			$url_args->{data_set_type} = 'single population';

	        my $model_page = $c->controller('solGS::Path')->model_page_url($url_args);
		    $trait_page = $base . $model_page;
		}

		if ( $referer =~ m/solgs\/populations\/combined\// )
		{
			$url_args->{data_set_type} = 'combined populations';

	        my $model_page = $c->controller('solGS::Path')->model_page_url($url_args);
		    $trait_page = $base . $model_page;

		    if ($analysis_page =~ m/solgs\/models\/combined\/trials\//)
		    {
				my $traits_selection_id = $c->controller('solGS::Gebvs')->create_traits_selection_id(\@traits_ids);
				$analysis_data->{analysis_page} = $base . "solgs/models/combined/trials/"
				    . $combo_pops_id
				    . '/traits/' . $traits_selection_id
				    . '/gp/' . $protocol_id;

				$c->controller('solGS::Gebvs')->catalogue_traits_selection($c, \@traits_ids);
		    }
		}

		if ( $analysis_page =~ m/solgs\/model\/combined\/trials\// )
		{
			$url_args->{data_set_type} = 'combined populations';

	        my $model_page = $c->controller('solGS::Path')->model_page_url($url_args);

		    $trait_page = $base . $model_page;

		    $c->stash->{combo_pops_id} = $combo_pops_id;
		    $c->controller('solGS::combinedTrials')->cache_combined_pops_data($c);
		}

		$output_details{'trait_id_' . $trait_abbr} = {
		    'trait_id'       => $trait_id,
		    'trait_name'     => $c->stash->{trait_name},
		    'trait_page'     => $trait_page,
		    'gebv_file'      => $c->stash->{rrblup_training_gebvs_file},
		    'pop_id'         => $pop_id,
		    'phenotype_file' => $c->stash->{trait_combined_pheno_file},
		    'genotype_file'  => $c->stash->{trait_combined_geno_file},
		    'data_set_type'  => $c->stash->{data_set_type},
		};
    }

	return \%output_details;
}


sub structure_training_single_pop_data_output {
	my ($self, $c) = @_;

	my $pop_id        = $c->stash->{pop_id};
	my $protocol_id   = $c->stash->{genotyping_protocol_id};

    my $base = $c->controller('solGS::Path')->clean_base_name($c);
	my $args = {
		 'training_pop_id' => $pop_id,
		 'genotyping_protocol_id' => $protocol_id,
		 'data_set_type' => 'single population'
	};

	my $training_pop_page = $c->controller('solGS::Path')->training_page_url($args);
    my $population_page = $base . $training_pop_page;

	my $data_set_type   = $c->stash->{data_set_type};
	my $pheno_file;
	my $geno_file;
	my $pop_name;

	my %output_details = ();

	if ($pop_id =~ /list/)
	{
		my $files   = $c->controller('solGS::List')->create_list_pop_data_files($c);
		$pheno_file = $files->{pheno_file};
		$geno_file  = $files->{geno_file};

		$c->controller('solGS::List')->create_list_population_metadata_file($c, $pop_id);
		$c->controller('solGS::List')->list_population_summary($c);
		$pop_name = $c->stash->{project_name};
	}
	elsif ($pop_id =~ /dataset/)
	{
		my $files   = $c->controller('solGS::Dataset')->create_dataset_pop_data_files($c,);
		$pheno_file = $files->{pheno_file};
		$geno_file  = $files->{geno_file};

		$c->controller('solGS::Dataset')->create_dataset_population_metadata_file($c);
		$c->controller('solGS::Dataset')->dataset_population_summary($c);
		$pop_name = $c->stash->{project_name};
	}
	else
	{
		$c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
		$c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
		$pheno_file = $c->stash->{phenotype_file_name};
		$geno_file  = $c->stash->{genotype_file_name};

		$c->controller('solGS::Search')->get_project_details($c, $pop_id);
		$pop_name = $c->stash->{project_name};
	}

	$output_details{'population_id_' . $pop_id} = {
		'population_page' => $population_page,
		'population_id'   => $pop_id,
		'population_name' => $pop_name,
		'phenotype_file'  => $pheno_file,
		'genotype_file'   => $geno_file,
		'data_set_type'   => $data_set_type,
	};

   return \%output_details;
}


sub structure_training_combined_pops_data_output {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $base = $c->controller('solGS::Path')->clean_base_name($c);
	my $args = {
		 'training_pop_id' => $combo_pops_id,
		 'genotyping_protocol_id' => $protocol_id,
		 'data_set_type' => 'combined populations'
	 };

	my $training_pop_page = $c->controller('solGS::Path')->training_page_url($args);

    my $combined_pops_page = $base . $training_pop_page;
    my @combined_pops_ids = @{$c->stash->{combo_pops_list}};

    $c->controller('solGS::combinedTrials')->multi_pops_pheno_files($c, \@combined_pops_ids);
    $c->controller('solGS::combinedTrials')->multi_pops_geno_files($c, \@combined_pops_ids, $protocol_id);

    my $multi_ph_files = $c->stash->{multi_pops_pheno_files};
    my @pheno_files = split(/\t/, $multi_ph_files);
    my $multi_gen_files = $c->stash->{multi_pops_geno_files};
    my @geno_files = split(/\t/, $multi_gen_files);
    my $match_status = $c->stash->{pops_with_no_genotype_match};

    my %output_details = ();
    foreach my $pop_id (@combined_pops_ids)
    {
		$c->controller('solGS::Search')->get_project_details($c, $pop_id);
		my $population_name = $c->stash->{project_name};

		$args = {
		 	'training_pop_id' => $pop_id,
		 	'genotyping_protocol_id' => $protocol_id,
		 	'data_set_type' => 'single population'
		};

		my $training_pop_page = $c->controller('solGS::Path')->training_page_url($args);

		my $population_page = $base . $training_pop_page;

	    $c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
		my $pheno_file  = $c->stash->{phenotype_file_name};

		$c->controller('solGS::Files')->phenotype_file_name($c, $pop_id, $protocol_id);
		my $geno_file  = $c->stash->{genotype_file_name};

		$output_details{'population_id_' . $pop_id} = {
		    'population_page'   => $population_page,
		    'population_id'     => $pop_id,
		    'population_name'   => $population_name,
		    'combo_pops_id'     => $combo_pops_id,
		    'phenotype_file'    => $pheno_file,
		    'genotype_file'     => $geno_file,
		    'data_set_type'     => $c->stash->{data_set_type},
		};
    }

    $output_details{no_match}           = $match_status;
    $output_details{combined_pops_page} = $combined_pops_page;

     return \%output_details;
}


sub structure_selection_prediction_output {
    my ($self, $c) = @_;

    my @traits_ids = @{$c->stash->{training_traits_ids}} if $c->stash->{training_traits_ids};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $referer = $c->req->referer;
    my $base = $c->controller('solGS::Path')->clean_base_name($c);
    my $data_set_type = $c->stash->{data_set_type};
    my %output_details = ();

    foreach my $trait_id (@traits_ids)
    {
		$c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
		my $trait_id = $c->stash->{trait_id};
		my $trait_abbr = $c->stash->{trait_abbr};
		my $trait_name = $c->stash->{trait_name};

		my $tr_pop_id   = $c->stash->{training_pop_id};
		my $sel_pop_id = $c->stash->{selection_pop_id};

		my $tr_pop_page;
		my $model_page;
		my $sel_pop_page;
		my $tr_pop_name;
		my $sel_pop_name;

		my $url_args = {
		  'training_pop_id' => $tr_pop_id,
		  'selection_pop_id' => $sel_pop_id,
		  'trait_id' => $trait_id,
		  'genotyping_protocol_id' => $protocol_id,
		  'data_set_type' => $data_set_type,
		};

		if ($data_set_type =~ /combined populations/)
		{
	   	 	$tr_pop_page = $c->controller('solGS::Path')->training_page_url($url_args);

		    $tr_pop_page    = $base . $tr_pop_page;
		    $tr_pop_name    = 'Training population ' . $tr_pop_id;
			$sel_pop_page =  $c->controller('solGS::Path')->selection_page_url($url_args);
		    $sel_pop_page = $base . $sel_pop_page;

	       	$model_page = $c->controller('solGS::Path')->model_page_url($url_args);
		    $model_page   = $base . $model_page;
		}
		else
		{
	   	 	my $training_pop_page = $c->controller('solGS::Path')->training_page_url($url_args);

		    $tr_pop_page    = $base . $training_pop_page;
		    if ($tr_pop_id =~ /list/)
		    {
				$c->stash->{list_id} = $tr_pop_id =~ s/\w+_//r;
				$c->controller('solGS::List')->list_population_summary($c);
				$tr_pop_name   = $c->stash->{project_name};
		    }
		    elsif ($tr_pop_id =~ /dataset/)
		    {
				$c->stash->{dataset_id} = $tr_pop_id =~ s/\w+_//r;
				$c->controller('solGS::Dataset')->dataset_population_summary($c);
				$tr_pop_name   = $c->stash->{project_name};
		    }
		    else
		    {
				$c->controller('solGS::Search')->get_project_details($c, $tr_pop_id);
				$tr_pop_name   = $c->stash->{project_name};
		    }

			$sel_pop_page =  $c->controller('solGS::Path')->selection_page_url($url_args);
		    $sel_pop_page = $base . $sel_pop_page;

	        $model_page = $c->controller('solGS::Path')->model_page_url($url_args);
		    $model_page = $base .  $model_page;
		}

		if ($sel_pop_id =~ /list/)
		{
		    $c->stash->{list_id} = $sel_pop_id =~ s/\w+_//r;
		    $c->controller('solGS::List')->list_population_summary($c, $sel_pop_id);
		    $c->controller('solGS::List')->create_list_population_metadata_file($c, $sel_pop_id);

		    $sel_pop_name = $c->stash->{selection_pop_name};
		}
		elsif ($sel_pop_id =~ /dataset/)
		{
		    $c->stash->{dataset_id} = $sel_pop_id =~ s/\w+_//r;
		    $c->controller('solGS::Dataset')->create_dataset_population_metadata_file($c);
		    $c->controller('solGS::Dataset')->dataset_population_summary($c);
		    $sel_pop_name = $c->stash->{selection_pop_name};
		}
		else
		{
		    $c->controller('solGS::Search')->get_project_details($c, $sel_pop_id);
		    $sel_pop_name = $c->stash->{project_name};
		}

		$c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $tr_pop_id, $sel_pop_id, $trait_id);
		my $gebv_file = $c->stash->{rrblup_selection_gebvs_file};

		$c->controller('solGS::Files')->genotype_file_name($c, $sel_pop_id, $protocol_id);
		my $selection_geno_file = $c->stash->{genotype_file_name};

		$output_details{'trait_id_' . $trait_id} = {
		    'training_pop_page'   => $tr_pop_page,
		    'training_pop_id'     => $tr_pop_id,
		    'training_pop_name'   => $tr_pop_name,
		    'selection_pop_name' => $sel_pop_name,
		    'selection_pop_page' => $sel_pop_page,
		    'trait_name'          => $trait_name,
		    'trait_id'            => $trait_id,
		    'model_page'          => $model_page,
		    'gebv_file'           => $gebv_file,
		    'selection_geno_file' => $selection_geno_file,
		    'data_set_type'       => $data_set_type
		};

    }

    return \%output_details;

}


sub run_analysis {
    my ($self, $c) = @_;

    $c->stash->{background_job} = 1;

    my $analysis_profile = $c->stash->{analysis_profile};
    my $analysis_page    = $analysis_profile->{analysis_page};
    $c->stash->{analysis_page} = $analysis_page;

    my $base = $c->controller('solGS::Path')->clean_base_name($c);
    $analysis_page       =~ s/$base//;
    my $referer          = $c->req->referer;

    my @selected_traits = @{$c->stash->{training_traits_ids}} if $c->stash->{training_traits_ids};

    eval
    {
		my $modeling_pages = 'solgs\/traits\/all\/population\/'
		    . '|solgs\/models\/combined\/trials\/'
		    . '|solgs\/trait\/'
		    . '|solgs\/model\/combined\/trials\/';

		my $selection_pages = '/solgs\/selection\/(\d+|\w+_\d+)\/model\/'
			. '|solgs\/combined\/model\/(\d+|\w+_\d+)\/selection\/';

		my $training_pages = '/solgs\/population\/'
			. '|solgs\/populations\/combined\/';

		if ($analysis_page =~  $training_pages)
		{
		    $self->create_training_data($c);
		}
		elsif ($analysis_page =~ /$modeling_pages/)
		{
		    $self->predict_training_traits($c);
		}
		elsif ($analysis_page =~ /$selection_pages/)
		{
		    $self->predict_selection_traits($c);
		}
		elsif ($analysis_page =~ /kinship\/analysis/)
		{
		    $self->run_kinship_analysis($c);
		}
        elsif ($analysis_page =~ /pca\/analysis/)
		{
		    $self->run_pca_analysis($c);
		}
        elsif ($analysis_page =~ /cluster\/analysis/)
        {
          $self->run_cluster_analysis($c);
        }
		else
		{
		    $c->stash->{status} = 'Error: Unknown job';
		    print STDERR "\n Uknown job.\n";
		}
    };

    my @error = $@;

    if ($error[0])
    {
		$c->stash->{status} = "run_analysis failed. Please try re-running the analysis and wait for it to finish. $error[0]";
    }
    else
    {
		$c->stash->{status} = 'Submitted';
        $self->update_analysis_progress($c);
    }



}


sub create_training_data {
	my ($self, $c) = @_;

    my $analysis_page = $c->stash->{analysis_page};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    # if ($analysis_page =~ /solgs\/population\//)
    # {
	my $pop_id = $c->stash->{model_id};

	if ($analysis_page =~ /solgs\/population\//)
	{
		my $pop_id = $c->stash->{model_id};

		if ($pop_id =~ /list/)
		{
			$c->controller('solGS::List')->submit_list_training_data_query($c);
			$c->controller('solGS::List')->create_list_population_metadata_file($c, $pop_id);
		}
		elsif ($pop_id =~ /dataset/)
		{
			 $c->controller('solGS::Dataset')->submit_dataset_training_data_query($c);
			 $c->controller('solGS::Dataset')->create_dataset_population_metadata_file($c);
		}
		else
		{
			$c->controller('solGS::AsyncJob')->submit_cluster_training_pop_data_query($c, [$pop_id], $protocol_id);
		}
	}
	elsif ($analysis_page =~ /solgs\/populations\/combined\//)
	{
			my $trials = $c->stash->{combo_pops_list};
			$c->controller('solGS::AsyncJob')->submit_cluster_training_pop_data_query($c, $trials, $protocol_id);
	}
	# }
}


sub predict_training_traits {
	my ($self, $c) = @_;

	my $analysis_page = $c->stash->{analysis_page};
	my $selected_traits = $c->stash->{training_traits_ids};

	$c->stash->{training_traits_ids} = [$c->stash->{trait_id}] if !$c->stash->{training_traits_ids};

	if ($analysis_page =~ /solgs\/traits\/all\/population\/|solgs\/trait\//)
	{
		$c->controller('solGS::solGS')->build_multiple_traits_models($c);
	}
	elsif ($analysis_page =~  /solgs\/models\/combined\/trials\/|solgs\/model\/combined\/trials\// )
	{
		if ($c->stash->{data_set_type} =~ /combined populations/)
		{
			$c->controller('solGS::combinedTrials')->combine_data_build_multiple_traits_models($c);
		}
	}

}


sub predict_selection_traits {
	my ($self, $c) = @_;

	$c->stash->{prerequisite_type} = 'selection_pop_download_data';
	my $training_pop_id   = $c->stash->{training_pop_id};
	my $selection_pop_id  = $c->stash->{selection_pop_id};

	if ($selection_pop_id =~ /list/)
	{
		$c->stash->{list_id} = $selection_pop_id =~ s/\w+_//r;
		$c->controller('solGS::List')->get_genotypes_list_details($c);
		$c->controller('solGS::List')->create_list_population_metadata_file($c, $selection_pop_id);
	}
	elsif ($selection_pop_id =~ /dataset/)
	{
		$c->stash->{dataset_id} = $selection_pop_id =~ s/\w+_//r;
		$c->controller('solGS::Dataset')->create_dataset_population_metadata_file($c);
	}

	my $referer = $c->req->referer;
	if ($referer =~ /solgs\/trait\/|solgs\/traits\/all\/population\//)
	{
		$c->controller('solGS::solGS')->predict_selection_pop_multi_traits($c);
	}
	elsif ($referer =~ /\/combined\//)
	{
		$c->stash->{data_set_type} = 'combined populations';
		$c->controller('solGS::combinedTrials')->predict_selection_pop_combined_pops_model($c);
	}

}


sub run_kinship_analysis {
	my ($self, $c) = @_;

	my $analysis_page = $c->stash->{analysis_page};

	if ($analysis_page = ~/kinship\/analysis/)
	{
		$c->controller('solGS::Kinship')->run_kinship($c);
	}

}


sub run_pca_analysis {
	my ($self, $c) = @_;

	my $analysis_page = $c->stash->{analysis_page};

	if ($analysis_page = ~/pca\/analysis/)
	{
		$c->controller('solGS::pca')->run_pca($c);
	}

}


sub run_cluster_analysis {
	my ($self, $c) = @_;

	my $analysis_page = $c->stash->{analysis_page};

	if ($analysis_page = ~/cluster\/analysis/)
	{
		$c->controller('solGS::Cluster')->run_cluster($c);
	}

}

sub update_analysis_progress {
	my ($self, $c) = @_;

	my $analysis_data =  $c->stash->{analysis_profile};
	my $analysis_name= $analysis_data->{analysis_name};
	my $status = $c->stash->{status};

	$self->analysis_log_file($c);
	my $log_file = $c->stash->{analysis_log_file};

	my @contents = read_file($log_file, {binmode => ':utf8'});

	map{ $contents[$_] =~ m/\t$analysis_name\t/
		 ? $contents[$_] =~ s/error|submitted/$status/ig
		 : $contents[$_] } 0..$#contents;

	write_file($log_file, {binmode => ':utf8'}, @contents);

}


sub get_user_detail {
	my ($self, $c) = @_;

	my $user = $c->user();

	my $contact;
	if ($user)
	{
		my $private_email = $user->get_private_email();
		my $public_email  = $user->get_contact_email();

		my $email = $public_email
			? $public_email
			: $private_email;

		my $salutation = $user->get_salutation();
		my $first_name = $user->get_first_name();
		my $last_name  = $user->get_last_name();
		my $user_role  = $user->get_object->get_user_type();
		my $user_id    = $user->get_object()->get_sp_person_id();
		my $user_name  = $user->id();

		$contact = {
			'first_name' => $first_name,
			'email'=> $email,
			'user_role' => $user_role,
			'user_id' => $user_id,
			'user_name' => $user_name,
		};

	}

	return $contact;

}


sub analysis_log_file {
	my ($self, $c) = @_;

	$self->create_analysis_log_dir($c);
	my $log_dir = $c->stash->{analysis_log_dir};

	$c->stash->{cache_dir} = $log_dir;

	my $cache_data = {
	key       => 'analysis_log',
	file      => 'analysis_log',
	stash_key => 'analysis_log_file'
	};

	$c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub get_confirm_msg {
	my ($self, $c, $job) = @_;

    $job =~ s/[_|-]/ /g;
    $job = lc($job);

    my $msg = "Your $job job is submitted.";
	return $msg;

}


sub get_user_solgs_analyses {
	my ($self, $c) = @_;

	$self->analysis_log_file($c);
	my $log_file = $c->stash->{analysis_log_file};

	my $ret = {};
	my @panel_data;

    no warnings 'uninitialized';

	if ($log_file)
	{
		my @user_analyses = grep{$_ !~ /User_name\s+/i }
							read_file($log_file, {binmode => ':utf8'});

		$self->index_log_file_headers($c);
		my $header_index = $c->stash->{header_index};

        my $json = JSON->new();
		foreach my $row (@user_analyses)
		{
			my @analysis = split(/\t/, $row);

            my $arguments = $analysis[5];
            $arguments = $json->decode($arguments);
            my $analysis_type = $arguments->{analysis_type};
			my $analysis_name   = $analysis[$header_index->{'Analysis_name'}];
			my $result_page     = $analysis[$header_index->{'Analysis_page'}];
			my $analysis_status = $analysis[$header_index->{'Status'}];
			my $submitted_on    = $analysis[$header_index->{'Submitted on'}];

			if ($analysis_status =~ /Failed/i)
			{
				$result_page = 'N/A';
			}
			elsif ($analysis_status =~ /Submitted/i)
			{
				$result_page = 'In progress...'
			}
			else
			{
				$result_page = qq |<a href=$result_page>[ View ]</a>|;
			}

            my $row = [$analysis_name, $analysis_type, $submitted_on, $analysis_status, $result_page];
			push @panel_data, $row;
		}
	}

	return \@panel_data;
}


sub create_analysis_log_dir {
	my ($self, $c) = @_;

	my $user_id = $c->user->id;

	$c->controller('solGS::Files')->get_solgs_dirs($c);

	my $log_dir = $c->stash->{analysis_log_dir};

	$log_dir = catdir($log_dir, $user_id);
	mkpath ($log_dir, 0, 0755);

	$c->stash->{analysis_log_dir} = $log_dir;

}


sub begin : Private {
	my ($self, $c) = @_;

	$c->controller('solGS::Files')->get_solgs_dirs($c);

}




__PACKAGE__->meta->make_immutable;


####
1;
####
