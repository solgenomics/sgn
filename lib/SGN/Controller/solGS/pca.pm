package SGN::Controller::solGS::pca;

use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use JSON;
use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;

use CXGN::List;

BEGIN { extends 'Catalyst::Controller' }

sub pca_analysis : Path('/pca/analysis/') Args() {
    my ( $self, $c, $id ) = @_;

    if ( $id && !$c->user ) {
        $c->controller('solGS::Utils')->require_login($c);
    }

    $c->stash->{template} = '/solgs/tools/pca/analysis.mas';

}

sub run_pca_analysis : Path('/run/pca/analysis') Args() {
    my ( $self, $c ) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args( $c, $args );

    $c->stash->{data_type} = 'genotype' if !$c->stash->{data_type};

    my $file_id = $c->controller('solGS::Files')->create_file_id($c);
    $c->stash->{file_id} = $file_id;


    my $list_id = $c->stash->{list_id};
    if ($list_id) {
        $c->controller('solGS::List')
          ->create_list_population_metadata_file( $c, $file_id );
        $c->controller('solGS::List')->stash_list_metadata( $c, $list_id );
    }

    my $combo_pops_id = $c->stash->{combo_pops_id};
    if ($combo_pops_id) {
        $c->controller('solGS::combinedTrials')
          ->get_combined_pops_list( $c, $combo_pops_id );
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
    }

    my $cached =
      $c->controller('solGS::CachedResult')->check_pca_output( $c, $file_id );
    if ( !$cached->{scores_file} ) {
        $self->run_pca($c);
    }

    $self->prepare_pca_output_response($c);
    my $ret = $c->stash->{pca_output_response};

    $ret = to_json($ret);
    $c->res->content_type('application/json');
    $c->res->body($ret);

}

sub download_pca_scores : Path('/download/pca/scores/population') Args(1) {
    my ( $self, $c, $file_id ) = @_;

    $c->stash->{file_id} = $file_id;
    $self->pca_scores_file($c);
    my $file     = $c->stash->{pca_scores_file};
    my $pca_data = $c->controller('solGS::Utils')
      ->structure_downloadable_data( $file, 'Individuals' );

    $c->res->content_type("text/plain");
    $c->res->body( join "", map { $_->[0] } @$pca_data );
}

sub download_pca_loadings : Path('/download/pca/loadings/population') Args(1) {
    my ( $self, $c, $file_id ) = @_;

    $c->stash->{file_id} = $file_id;
    $self->pca_loadings_file($c);
    my $file     = $c->stash->{pca_loadings_file};
    my $pca_data = $c->controller('solGS::Utils')
      ->structure_downloadable_data( $file, 'Variables' );

    $c->res->content_type("text/plain");
    $c->res->body( join "", map { $_->[0] } @$pca_data );

}

sub download_pca_variances : Path('/download/pca/variances/population') Args(1)
{
    my ( $self, $c, $file_id ) = @_;

    $c->stash->{file_id} = $file_id;
    $self->pca_variances_file($c);
    my $file = $c->stash->{pca_variances_file};

    my $pca_data = $c->controller('solGS::Utils')
      ->structure_downloadable_data( $file, 'PCs' );

    $c->res->content_type("text/plain");
    $c->res->body( join "", map { $_->[0] } @$pca_data );

}

sub prepare_pca_output_response {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};
    my $res->{status} = undef;

    if ($file_id) {
        $self->pca_scores_file($c);
        my $scores_file = $c->stash->{pca_scores_file};

        if ( -s $scores_file ) {
            my $scores =
              $c->controller('solGS::Utils')->read_file_data($scores_file);

            $self->pca_variances_file($c);
            my $variances_file = $c->stash->{pca_variances_file};
            my $variances =
              $c->controller('solGS::Utils')->read_file_data($variances_file);

            $self->prep_pca_download_files($c);
            my $scree_plot_file = $c->stash->{download_scree_plot};
            my $scree_data_file = $c->stash->{download_scree_data};
            my $loadings_file   = $c->stash->{download_loadings};
            my $variances_file  = $c->stash->{download_variances};
            my $scores_file     = $c->stash->{download_scores};
            my $report_file    = $c->stash->{download_report_file};

            my $output_link = '/pca/analysis/' . $file_id;
            my $trials_names;

            my $tr_pop_id  = $c->stash->{training_pop_id};
            my $sel_pop_id = $c->stash->{selection_pop_id};
            if ( $tr_pop_id && $sel_pop_id ) {
                $trials_names = {
                    $tr_pop_id  => 'Training population',
                    $sel_pop_id => 'Selection population'
                };
            }
            else {
                $c->controller('solGS::combinedTrials')
                  ->process_trials_list_details($c);
                $trials_names = $c->stash->{trials_names};
            }

        
            my $analysis_name = $c->controller('solGS::AnalysisSave')->check_logged_analysis_name($c);

            if ($scores) {
                $res = {
                    "scores"          =>  $scores,
                    "variances"       => $variances,
                    "scores_file"     => $scores_file,
                    "variances_file"  => $variances_file,
                    "loadings_file"   => $loadings_file,
                    "scree_data_file" => $scree_data_file,
                    "scree_plot_file" => $scree_plot_file,
                    "report_file"     => $report_file,
                    "status"          => 'success',
                    "cached"          => 1,
                    "pca_pop_id"      => $c->stash->{pca_pop_id},
                    "file_id"         => $file_id,
                    "list_id"         => $c->stash->{list_id},
                    "trials_names"    => $trials_names,
                    "output_link"     => $output_link,
                    "data_type"       => $c->stash->{data_type},
                    "analysis_name"   => $analysis_name   
                };
        
            }

            $c->stash->{pca_output_response} = $res;
        }
        else {
            $res->{status} = $self->error_message($c);
            $c->stash->{formatted_pca_output} = $res;
        }
    }
    else {
        die "Required file id argument missing.";
    }

}

sub error_message {
    my ( $self, $c ) = @_;

    $self->pca_scores_file($c);
    my $pca_scores_file = $c->stash->{pca_scores_file};

    $self->pca_input_files($c);
    my $files = $c->stash->{pca_input_files};

    my $error_message;

    my @data_exists;
    my @data_files = split( /\s/, read_file( $files, { binmode => ':utf8' } ) );

    foreach my $file (@data_files) {
        push @data_exists, 1 if -s $file;
    }

    if ( !@data_exists ) {
        my $data_type = $c->stash->{data_type};
        $error_message = "There is no $data_type for this dataset.";
    }
    elsif ( @data_exists && !-s $pca_scores_file ) {
        $error_message = 'The PCA R Script failed.';
    }

    return $error_message;
}

sub format_pca_scores {
    my ( $self, $c ) = @_;

    my $file = $c->stash->{pca_scores_file};
    my $data = $c->controller('solGS::Utils')->read_file_data($file);

    $c->stash->{pca_scores} = $data;

}

sub pca_query_jobs {
    my ( $self, $c ) = @_;

    my $data_type   = $c->stash->{data_type};
    my $pca_pop_id  = $c->stash->{pca_pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $jobs = [];

    if ( $data_type =~ /phenotype/i ) {
        $jobs = $c->controller('solGS::AsyncJob')
          ->create_phenotype_data_query_jobs( $c, $pca_pop_id );
    }
    elsif ( $data_type =~ /genotype/i ) {
        $jobs = $c->controller('solGS::AsyncJob')
          ->create_genotype_data_query_jobs( $c, $pca_pop_id, $protocol_id );
    }

    if ( reftype $jobs ne 'ARRAY' ) {
        $jobs = [$jobs];
    }

    $c->stash->{pca_query_jobs} = $jobs;
}

sub pca_scores_file {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};
    $c->stash->{cache_dir} = $c->stash->{pca_cache_dir};

    my $cache_data = {
        key       => "pca_scores_${file_id}",
        file      => "pca_scores_${file_id}",
        stash_key => 'pca_scores_file'
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

}

sub pca_scree_data_file {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};
    $c->stash->{cache_dir} = $c->stash->{pca_cache_dir};

    my $cache_data = {
        key       => "pca_scree_data_${file_id}",
        file      => "pca_scree_data_${file_id}",
        stash_key => 'pca_scree_data_file'
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

}

sub pca_scree_plot_file {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};
    $c->stash->{cache_dir} = $c->stash->{pca_cache_dir};

    my $cache_data = {
        key       => "pca_scree_plot_${file_id}",
        file      => "pca_scree_plot_${file_id}",
        ext       => 'png',
        stash_key => 'pca_scree_plot_file'
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

}

sub pca_variances_file {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};
    $c->stash->{cache_dir} = $c->stash->{pca_cache_dir};

    my $cache_data = {
        key       => "pca_variances_${file_id}",
        file      => "pca_variances_${file_id}",
        stash_key => 'pca_variances_file'
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

}

sub pca_loadings_file {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};
    $c->stash->{cache_dir} = $c->stash->{pca_cache_dir};

    my $cache_data = {
        key       => "pca_loadings_${file_id}",
        file      => "pca_loadings_${file_id}",
        stash_key => 'pca_loadings_file'
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

}

sub pca_output_files {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};

    $self->pca_scores_file($c);
    $self->pca_loadings_file($c);
    $self->pca_variances_file($c);
    $self->pca_scree_data_file($c);
    $self->pca_scree_plot_file($c);
    $self->combined_pca_trials_data_file($c);
    $c->controller('solGS::Files')->analysis_report_file($c);

    my $file_list = join( "\t",
        $c->stash->{pca_scores_file},     $c->stash->{pca_loadings_file},
        $c->stash->{pca_scree_data_file}, $c->stash->{pca_scree_plot_file},
        $c->stash->{pca_variances_file},  $c->stash->{combined_pca_data_file},
        $c->{stash}->{"pca_analysis_report_file"}
    );

    my $tmp_dir = $c->stash->{pca_temp_dir};
    my $name    = "pca_output_files_${file_id}";
    my $tempfile =
      $c->controller('solGS::Files')->create_tempfile( $tmp_dir, $name );
    write_file( $tempfile, { binmode => ':utf8' }, $file_list );

    $c->stash->{pca_output_files} = $tempfile;

}

sub combined_pca_trials_data_file {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};
    my $tmp_dir = $c->stash->{pca_temp_dir};
    my $name    = "combined_pca_data_file_${file_id}";
    my $tempfile =
      $c->controller('solGS::Files')->create_tempfile( $tmp_dir, $name );

    $c->stash->{combined_pca_data_file} = $tempfile;

}

sub pca_data_input_files {
    my ( $self, $c ) = @_;

    my $pop_id      = $c->stash->{pca_pop_id};
    my $data_type   = $c->stash->{data_type};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $input_file;
    if ( $data_type =~ /genotype/i ) {
        $c->controller('solGS::Files')
          ->genotype_file_name( $c, $pop_id, $protocol_id );
        $input_file = $c->stash->{genotype_file_name};
    }
    elsif ( $data_type =~ /phenotype/i ) {
        $c->controller('solGS::Files')->phenotype_file_name( $c, $pop_id );
        $input_file = $c->stash->{phenotype_file_name};
    }

    return $input_file;
}

sub pca_input_files {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};
    my $tmp_dir = $c->stash->{pca_temp_dir};

    my $name = "pca_input_files_${file_id}";
    my $tempfile =
      $c->controller('solGS::Files')->create_tempfile( $tmp_dir, $name );

    my $files;
    my $data_type = $c->stash->{data_type};
    if ( $data_type =~ /genotype/i ) {
        $self->pca_geno_input_files($c);
        $files = $c->stash->{pca_geno_input_files};
    }
    elsif ( $data_type =~ /phenotype/i ) {
        $self->pca_pheno_input_files($c);
        $files = $c->stash->{pca_pheno_input_files};
    }

    write_file( $tempfile, { binmode => ':utf8' }, $files );
    $c->stash->{pca_input_files} = $tempfile;

}

sub pca_geno_input_files {
    my ( $self, $c ) = @_;

    my $data_type = $c->stash->{data_type};
    my $files;

    if ( $data_type =~ /genotype/i ) {
        if ( $c->req->referer =~
            /solgs\/selection\/|solgs\/combined\/model\/\d+\/selection\// )
        {
            $self->training_selection_geno_files($c);
        }

        $files =
          $c->stash->{genotype_files_list} || $c->stash->{genotype_file_name};
    }

    $files = join( "\t", @$files ) if reftype($files) eq 'ARRAY';
    $c->stash->{pca_geno_input_files} = $files;
}

sub training_selection_geno_files {
    my ( $self, $c ) = @_;

    my $tr_pop_id  = $c->stash->{training_pop_id};
    $tr_pop_id =~ s/-\d+//;
    my $sel_pop_id = $c->stash->{selection_pop_id};

    my @files;
    foreach my $id ( ( $tr_pop_id, $sel_pop_id ) ) {
        $c->controller('solGS::Files')->genotype_file_name( $c, $id );
        push @files, $c->stash->{genotype_file_name};
    }

    my $files = join( "\t", @files );
    $c->stash->{genotype_files_list} = $files;
}

sub pca_pheno_input_files {
    my ( $self, $c ) = @_;

    my $data_type = $c->stash->{data_type};
    my $files;

    if ( $data_type =~ /phenotype/i ) {
        $files = $c->stash->{phenotype_files_list}
          || $c->stash->{phenotype_file_name};

        $files = join( "\t", @$files ) if reftype($files) eq 'ARRAY';

        $c->controller('solGS::Files')->phenotype_metadata_file($c);
        my $metadata_file = $c->stash->{phenotype_metadata_file};

        $files .= "\t" . $metadata_file;
    }

    $c->stash->{pca_pheno_input_files} = $files;

}

sub run_pca {
    my ( $self, $c ) = @_;

    $self->pca_query_jobs_file($c);
    $c->stash->{prerequisite_jobs} = $c->stash->{pca_query_jobs_file};

    $self->pca_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{pca_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}

sub run_pca_single_core {
    my ( $self, $c ) = @_;

    $self->pca_query_jobs($c);
    my $queries = $c->stash->{pca_query_jobs};

    $self->pca_r_jobs($c);
    my $r_jobs = $c->stash->{pca_r_jobs};

    foreach my $job (@$queries) {
        $c->controller('solGS::AsyncJob')->submit_job_cluster( $c, $job );
    }

    foreach my $job (@$r_jobs) {
        $c->controller('solGS::AsyncJob')->submit_job_cluster( $c, $job );
    }

}

sub run_pca_multi_cores {
    my ( $self, $c ) = @_;

    $self->pca_query_jobs_file($c);
    $c->stash->{prerequisite_jobs} = $c->stash->{pca_query_jobs_file};

    $self->pca_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{pca_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}

sub pca_r_jobs {
    my ( $self, $c ) = @_;

    my $file_id = $c->stash->{file_id};

    $self->pca_output_files($c);
    my $output_file = $c->stash->{pca_output_files};

    $self->pca_input_files($c);
    my $input_file = $c->stash->{pca_input_files};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{pca_temp_dir};

    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "pca-${file_id}";
    $c->stash->{r_script}     = 'R/solGS/pca.r';

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs = $c->stash->{cluster_r_job_args};

    if ( reftype $jobs ne 'ARRAY' ) {
        $jobs = [$jobs];
    }

    $c->stash->{pca_r_jobs} = $jobs;

}

sub pca_r_jobs_file {
    my ( $self, $c ) = @_;

    $self->pca_r_jobs($c);
    my $jobs = $c->stash->{pca_r_jobs};

    my $temp_dir  = $c->stash->{pca_temp_dir};
    my $jobs_file = $c->controller('solGS::Files')
      ->create_tempfile( $temp_dir, 'pca-r-jobs-file' );

    nstore $jobs, $jobs_file
      or croak "pca r jobs : $! serializing pca r jobs to $jobs_file";

    $c->stash->{pca_r_jobs_file} = $jobs_file;

}

sub pca_query_jobs_file {
    my ( $self, $c ) = @_;

    $self->pca_query_jobs($c);
    my $jobs = $c->stash->{pca_query_jobs};

    my $temp_dir  = $c->stash->{pca_temp_dir};
    my $jobs_file = $c->controller('solGS::Files')
      ->create_tempfile( $temp_dir, 'pca-query-jobs-file' );

    nstore $jobs, $jobs_file
      or croak "pca query jobs : $! serializing pca query jobs to $jobs_file";

    $c->stash->{pca_query_jobs_file} = $jobs_file;

}

sub prep_pca_download_files {
    my ( $self, $c ) = @_;

    my $analysis_type = $c->stash->{analysis_type};
    $self->pca_scores_file($c);
    $self->pca_loadings_file($c);
    $self->pca_variances_file($c);
    $self->pca_scree_data_file($c);
    $self->pca_scree_plot_file($c);
    $c->controller('solGS::Files')->analysis_report_file($c);
    my $scores_file     = $c->stash->{pca_scores_file};
    my $loadings_file   = $c->stash->{pca_loadings_file};
    my $scree_data_file = $c->stash->{pca_scree_data_file};
    my $scree_plot_file = $c->stash->{pca_scree_plot_file};
    my $variances_file  = $c->stash->{pca_variances_file};
    my $analysis_report_file = $c->stash->{pca_analysis_report_file};

    $scores_file = $c->controller('solGS::Files')
      ->copy_to_tempfiles_subdir( $c, $scores_file, 'pca' );
    $loadings_file = $c->controller('solGS::Files')
      ->copy_to_tempfiles_subdir( $c, $loadings_file, 'pca' );
    $scree_data_file = $c->controller('solGS::Files')
      ->copy_to_tempfiles_subdir( $c, $scree_data_file, 'pca' );
    $scree_plot_file = $c->controller('solGS::Files')
      ->copy_to_tempfiles_subdir( $c, $scree_plot_file, 'pca' );
    $variances_file = $c->controller('solGS::Files')
      ->copy_to_tempfiles_subdir( $c, $variances_file, 'pca' );
    $analysis_report_file = $c->controller('solGS::Files')
      ->copy_to_tempfiles_subdir( $c, $analysis_report_file, 'pca' );

    $c->stash->{download_scores}     = $scores_file;
    $c->stash->{download_loadings}   = $loadings_file;
    $c->stash->{download_scree_data} = $scree_data_file;
    $c->stash->{download_scree_plot} = $scree_plot_file;
    $c->stash->{download_variances}  = $variances_file;
    $c->stash->{download_report_file}= $analysis_report_file;

}

sub begin : Private {
    my ( $self, $c ) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

__PACKAGE__->meta->make_immutable;

####
1;
####
