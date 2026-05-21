
=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 Name

SGN::Controller::solGS::Anova - a controller for ANOVA. For now, this implements a one-way
single trial ANOVA with a possibility for simultanously running anova for multiple traits.

=cut

package SGN::Controller::solGS::Anova;

use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;

use CXGN::Trial;
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Slurp qw /write_file read_file/;
use File::Spec::Functions;
use File::Path qw /mkpath/;
use JSON;
use List::Util qw/any uniq all/;
use List::MoreUtils qw/firstidx/;
use Scalar::Util qw /weaken reftype looks_like_number/;
use SGN::Model::Cvterm;
use Storable qw/nstore retrieve/;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub anova_check_design : Path('/anova/check/design/') Args(0) {
    my ( $self, $c ) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args( $c, $args );

    my $design = $self->get_trial_design($c);
    my $supported;
    $supported = $self->check_design_support($design) if $design;

    if ( !$design ) {
        $c->stash->{rest}{'Error'} = 'This trial has no design. ANOVA can not be applied.';
    }
    elsif ( $design && !$supported ) {
        $c->stash->{rest}{'Error'} = $design
          . ' design is not supported yet. Please report this to the database team. ';
    }
    else {
        $c->stash->{rest}{'Design'} = $design;
    }

}

sub anova_traits_list : Path('/anova/traits/list/') Args(0) {
    my ( $self, $c ) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args( $c, $args );

    my $traits = $self->anova_traits($c);
    $c->stash->{rest}{anova_traits} = $traits;

}

sub anova_phenotype_data : Path('/anova/phenotype/data/') Args(0) {
    my ( $self, $c ) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args( $c, $args );

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->controller('solGS::Trait')->get_trait_details( $c, $trait_id );

    my $pheno_file = $self->trial_phenotype_file($c);

    if ( !-s $pheno_file ) {

        $pheno_file = $self->create_anova_phenodata_file($c);

        if ( !-s $pheno_file ) {
            $c->stash->{rest}{'Error'} =
              'There is no phenotype data for this  trial.';
        }

        if ( @{ $c->error } ) {
            $c->stash->{rest}{'Error'} =
              'There was error querying for the phenotype data.';
        }
    }
    else {
        my $categorical = $self->check_categorical_dependent_variable($c);
        if ($categorical) {
            $c->stash->{rest}{'Error'} =
"The trait data is not all numeric. Some or all of the trait values are text. ";
        }
        else {
            $c->stash->{rest}{'success'} = 'Success.';
        }
    }

    my $traits_abbrs = $self->get_traits_abbrs($c);
    $c->stash->{rest}{trial_id}     = $trial_id;
    $c->stash->{rest}{traits_abbrs} = $traits_abbrs;

}

sub anova_analyis : Path('/anova/analysis/') Args(0) {
    my ( $self, $c ) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args( $c, $args );

    my $anova_result = $self->check_anova_output($c);

    $c->controller('solGS::Trait')
      ->get_trait_details( $c, $c->stash->{trait_id} );

    if ( !$anova_result ) {
        $self->run_anova($c);
    }

    $self->prepare_response($c);

}

sub anova_traits {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};

    my $traits =
      $c->controller('solGS::Search')->model($c)->trial_traits($trial_id);
    my $clean_traits = $c->controller('solGS::Utils')->remove_ontology($traits);

    return $clean_traits;

}

sub create_anova_phenodata_file {
    my ( $self, $c ) = @_;

    my $cached = $c->controller('solGS::CachedResult')
      ->check_cached_phenotype_data( $c, $c->stash->{trial_id} );

    if ( !$cached ) {
        $self->anova_query_jobs_file($c);
        my $queries = $c->stash->{anova_query_jobs_file};

        $c->stash->{dependent_jobs} = $queries;
        $c->controller('solGS::AsyncJob')->run_async($c);
    }

    return $self->trial_phenotype_file($c);

}

sub trial_phenotype_file {
    my ( $self, $c ) = @_;

    $c->controller('solGS::Files')
      ->phenotype_file_name( $c, $c->stash->{trial_id} );
    return $c->stash->{phenotype_file_name};

}

sub get_trial_design {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};

    my $trial = CXGN::Trial->new(
        {
            bcs_schema => $self->schema($c),
            trial_id   => $trial_id
        }
    );

    return $trial->get_design_type();


}

sub check_design_support {
    my ( $self, $design ) = @_;

    my $supported_designs = $self->supported_designs();

    my ($match) = grep( /$design/, @$supported_designs );

    return $match;

}

sub supported_designs {
    my $self = shift;

    my $supported_designs = [qw(Alpha, Augmented, RCBD, CRD)];

    return $supported_designs;

}

sub get_traits_abbrs {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->stash->{pop_id} = $trial_id;
    $c->controller('solGS::Trait')->get_all_traits( $c, $trial_id );
    $c->controller('solGS::Files')->all_traits_file( $c, $trial_id );

    $c->controller('solGs::Trait')->get_trait_details( $c, $trait_id );
    my $trait_abbr = $c->stash->{trait_abbr};

    my $id_abbr      = { 'trait_id' => $trait_id, 'trait_abbr' => $trait_abbr };
    my $json         = JSON->new();
    my $traits_abbrs = $json->encode($id_abbr);

    return $traits_abbrs;
}

sub check_categorical_dependent_variable {
    my ( $self, $c ) = @_;

    my $pheno_file = $self->trial_phenotype_file($c);
    my $header     = ( read_file( $pheno_file, { binmode => ':utf8' } ) )[0];
    my @headers    = split( /\t/, $header );

    $c->controller('solGS::Trait')
      ->get_trait_details( $c, $c->stash->{trait_id} );
    my $trait_abbr = $c->stash->{trait_abbr};

    my $trait_idx = firstidx { $_ eq $trait_abbr } @headers;

    # Read the trait column directly via Perl I/O (avoid shell command injection)
    my @trait_values;
    open(my $pfh, '<:utf8', $pheno_file) or return 0;
    my $skip_header = <$pfh>;  # skip header line
    while (my $line = <$pfh>) {
        chomp $line;
        my @cols = split(/\t/, $line, -1);
        my $val = $cols[$trait_idx] // '';
        push @trait_values, $val if $val ne '';
    }
    close($pfh);

    return 0 unless @trait_values;
    my $categorical = all { $_ =~ /[A-Za-z]/ } @trait_values;

    return $categorical;

}

sub check_anova_output {
    my ( $self, $c ) = @_;

    $self->anova_table_file($c);
    my $html_file = $c->stash->{anova_table_html_file};

    my $exists = -s $html_file ? 1 : 0;

    return $exists;

}

sub prepare_response {
    my ( $self, $c ) = @_;

    $self->anova_table_file($c);
    my $anova_txt_file  = $c->stash->{anova_table_txt_file};
    my $anova_html_file = $c->stash->{anova_table_html_file};

    if ( -s $anova_html_file ) {
        $self->anova_model_file($c);
        my $model_file = $c->stash->{anova_model_file};

        $self->adj_means_file($c);
        my $means_file = $c->stash->{adj_means_file};

        # Compute Points Score from raw replicate data and append
        # as a column to the adj_means file.
        my $trial_id_ps = $c->stash->{trial_id};
        my $pheno_file  = catfile(
            $c->stash->{anova_cache_dir},
            "phenotype_data_filtered_${trial_id_ps}.tsv"
        );
        my $trait_abbr = $c->stash->{trait_abbr};
        my $ps_info = $self->_append_points_score_to_adj_means(
            $means_file, $pheno_file, $trait_abbr
        );

        $self->anova_diagnostics_file($c);
        my $diagnostics_file = $c->stash->{anova_diagnostics_file};

        my $dir = 'anova';
        $anova_txt_file = $c->controller('solGS::Files')
          ->copy_to_tempfiles_subdir( $c, $anova_txt_file, $dir );
        $model_file = $c->controller('solGS::Files')
          ->copy_to_tempfiles_subdir( $c, $model_file, $dir );
        $means_file = $c->controller('solGS::Files')
          ->copy_to_tempfiles_subdir( $c, $means_file, $dir );
        $diagnostics_file = $c->controller('solGS::Files')
          ->copy_to_tempfiles_subdir( $c, $diagnostics_file, $dir );

        $c->stash->{rest}{anova_table_html_file} =
          read_file( $anova_html_file, { binmode => ':utf8' } );
        $c->stash->{rest}{anova_table_txt_file}       = $anova_txt_file;
        $c->stash->{rest}{anova_model_file}       = $model_file;
        $c->stash->{rest}{adj_means_file}         = $means_file;
        $c->stash->{rest}{anova_diagnostics_file} = $diagnostics_file;
        $c->stash->{rest}{points_score_baseline}  = $ps_info->{baseline};
        $c->stash->{rest}{points_score_count}     = $ps_info->{count};

        # Read persisted outlier count from the count file
        my $outliers = $self->_read_outlier_count_file($c);
        $c->stash->{rest}{outliers_excluded} = $outliers;

        # Check if trial has passed QC validation
        my $trial_id = $c->stash->{trial_id};
        my $schema   = $self->schema($c);
        my $validated_type = SGN::Model::Cvterm
            ->get_cvterm_row($schema, 'validated_phenotype', 'project_property');
        my $qc_validated = 0;
        if ($validated_type) {
            $qc_validated = $schema->resultset("Project::Projectprop")->count({
                project_id => $trial_id,
                type_id    => $validated_type->cvterm_id(),
            });
        }
        $c->stash->{rest}{qc_validated} = $qc_validated;
    }
    else {
        $self->anova_error_file($c);
        my $error_file = $c->stash->{anova_error_file};

        my $error = read_file( $error_file, { binmode => ':utf8' } );
        $c->stash->{rest}{Error} = $error;
    }

}

sub run_anova {
    my ( $self, $c ) = @_;

    $self->anova_query_jobs_file($c);
    $c->stash->{prerequisite_jobs} = $c->stash->{anova_query_jobs_file};

    $self->anova_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{anova_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}

sub run_anova_single_core {
    my ( $self, $c ) = @_;

    $self->anova_query_jobs($c);
    my $queries = $c->stash->{anova_query_jobs};

    $self->anova_r_jobs($c);
    my $r_jobs = $c->stash->{anova_r_jobs};

    foreach my $job (@$queries) {
        $c->controller('solGS::AsyncJob')->submit_job_cluster( $c, $job );
    }

    foreach my $job (@$r_jobs) {
        $c->controller('solGS::AsyncJob')->submit_job_cluster( $c, $job );
    }

}

sub run_anova_multi_cores {
    my ( $self, $c ) = @_;

    $self->anova_query_jobs_file($c);
    $c->stash->{prerequisite_jobs} = $c->stash->{anova_query_jobs_file};

    $self->anova_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{anova_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}

sub anova_r_jobs {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $self->anova_input_files($c);
    my $input_file = $c->stash->{anova_input_files};

    $self->anova_output_files($c);
    my $output_file = $c->stash->{anova_output_files};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{anova_temp_dir};

    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "anova-${trial_id}-${trait_id}";
    $c->stash->{r_script}     = 'R/solGS/anova.r';

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs = $c->stash->{cluster_r_job_args};

    if ( reftype $jobs ne 'ARRAY' ) {
        $jobs = [$jobs];
    }

    $c->stash->{anova_r_jobs} = $jobs;

}

sub anova_r_jobs_file {
    my ( $self, $c ) = @_;

    $self->anova_r_jobs($c);
    my $jobs = $c->stash->{anova_r_jobs};

    my $temp_dir  = $c->stash->{anova_temp_dir};
    my $jobs_file = $c->controller('solGS::Files')
      ->create_tempfile( $temp_dir, 'anova-r-jobs-file' );

    nstore $jobs, $jobs_file
      or croak "anova r jobs : $! serializing anova r jobs to $jobs_file";

    $c->stash->{anova_r_jobs_file} = $jobs_file;

}

sub anova_query_jobs {
    my ( $self, $c ) = @_;

    $self->create_anova_phenotype_data_query_jobs($c);
    my $jobs = $c->stash->{anova_pheno_query_jobs};

    if ( reftype $jobs ne 'ARRAY' ) {
        $jobs = [$jobs];
    }

    $c->stash->{anova_query_jobs} = $jobs;
}

sub anova_query_jobs_file {
    my ( $self, $c ) = @_;

    $self->anova_query_jobs($c);
    my $jobs = $c->stash->{anova_query_jobs};

    if ( $jobs->[0] ) {
        my $temp_dir  = $c->stash->{anova_temp_dir};
        my $jobs_file = $c->controller('solGS::Files')
          ->create_tempfile( $temp_dir, 'anova-query-jobs-file' );

        nstore $jobs, $jobs_file
          or croak
          "anova query jobs : $! serializing anova query jobs to $jobs_file";

        $c->stash->{anova_query_jobs_file} = $jobs_file;
    }

}

sub create_anova_phenotype_data_query_jobs {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{pop_id} || $c->stash->{trial_id};
    $c->controller('solGS::AsyncJob')
      ->get_trials_phenotype_query_jobs_args( $c, [$trial_id] );
    my $jobs = $c->stash->{trials_phenotype_query_jobs_args};

    if ( reftype $jobs ne 'ARRAY' ) {
        $jobs = [$jobs];
    }

    $c->stash->{anova_pheno_query_jobs} = $jobs;

}

sub copy_pheno_file_to_anova_dir {
    my ( $self, $c ) = @_;

    my $pheno_file  = $self->trial_phenotype_file($c);
    my $anova_cache = $c->stash->{anova_cache_dir};

    $c->stash->{phenotype_file} =
      $c->controller('solGS::Files')->copy_file( $pheno_file, $anova_cache );

}

sub anova_input_files {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    # Copy the shared phenotype file to the ANOVA cache dir, then
    # filter outliers from the copy — so other solGS tools keep the
    # original unfiltered file.
    my $shared_pheno_file = $self->trial_phenotype_file($c);
    my $anova_cache       = $c->stash->{anova_cache_dir};
    my $pheno_file        = $shared_pheno_file;

    if (-s $shared_pheno_file && $anova_cache) {
        my $filtered_name = "phenotype_data_filtered_${trial_id}.tsv";
        my $filtered_path = catfile($anova_cache, $filtered_name);

        copy($shared_pheno_file, $filtered_path)
            or croak "anova: cannot copy phenotype file: $!";

        my $excluded = $self->_filter_outliers_from_phenofile(
            $c, $filtered_path
        );

        # Persist outlier count so prepare_response can read it
        # across separate HTTP requests
        if ($excluded > 0) {
            $self->_write_outlier_count_file($c, $excluded);
        }

        $pheno_file = $filtered_path;
    }

    $self->anova_traits_file($c);
    my $traits_file = $c->stash->{anova_traits_file};

    $c->controller("solGS::Files")->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};

    my $file_list = join( "\t", $pheno_file, $traits_file, $metadata_file );

    my $tmp_dir = $c->stash->{anova_temp_dir};
    my $name    = "anova_input_files_${trial_id}_${trait_id}";
    my $tempfile =
      $c->controller('solGS::Files')->create_tempfile( $tmp_dir, $name );
    write_file( $tempfile, { binmode => ':utf8' }, $file_list );

    $c->stash->{anova_input_files} = $tempfile;

}

sub anova_traits_file {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $traits   = $c->stash->{trait_abbr};

    my $tmp_dir = $c->stash->{anova_temp_dir};
    my $name    = "anova_traits_file_${trial_id}";
    my $traits_file =
      $c->controller('solGS::Files')->create_tempfile( $tmp_dir, $name );
    write_file( $traits_file, { binmode => ':utf8' }, $traits );

    $c->stash->{anova_traits_file} = $traits_file;

}

sub anova_output_files {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $self->anova_table_file($c);
    $self->anova_model_file($c);
    $self->adj_means_file($c);
    $self->anova_diagnostics_file($c);
    $self->anova_error_file($c);

    my @files = $c->stash->{anova_table_file};

    my $file_list = join( "\t",
        $c->stash->{anova_model_file},
        $c->stash->{anova_table_html_file},
        $c->stash->{anova_table_txt_file},
        $c->stash->{adj_means_file},
        $c->stash->{anova_diagnostics_file},
        $c->stash->{anova_error_file},
    );

    my $tmp_dir = $c->stash->{anova_temp_dir};
    my $name    = "anova_output_files_${trial_id}_${trait_id}";
    my $tempfile =
      $c->controller('solGS::Files')->create_tempfile( $tmp_dir, $name );
    write_file( $tempfile, { binmode => ':utf8' }, $file_list );

    $c->stash->{anova_output_files} = $tempfile;

}

sub anova_table_file {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    my $cache_data = {
        key       => "anova_table_html_${trial_id}_${trait_id}",
        file      => "anova_table_html_${trial_id}_${trait_id}",
        ext       => 'html',
        stash_key => "anova_table_html_file"
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    $cache_data = {
        key       => "anova_table_txt_${trial_id}_${trait_id}",
        file      => "anova_table_txt_${trial_id}_${trait_id}",
         ext      => 'txt',
        stash_key => "anova_table_txt_file"
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

}

sub anova_diagnostics_file {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    my $cache_data = {
        key       => "anova_diagnosics_${trial_id}_${trait_id}",
        file      => "anova_diagnostics_${trial_id}_${trait_id}",
        ext       => '.png',
        stash_key => "anova_diagnostics_file"
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

}

sub anova_model_file {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    my $cache_data = {
        key       => "anova_model_${trial_id}_${trait_id}",
        file      => "anova_model_${trial_id}_${trait_id}",
        stash_key => "anova_model_file"
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

}

sub anova_error_file {
    my ( $self, $c ) = @_;

    $c->stash->{file_id} = $c->stash->{trial_id} . '_' . $c->stash->{trait_id};
    $c->stash->{cache_dir}     = $c->stash->{anova_cache_dir};
    $c->stash->{analysis_type} = 'anova';

    $c->controller('solGS::Files')->analysis_error_file($c);

}

sub adj_means_file {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    my $cache_data = {
        key       => "adj_means_${trial_id}_${trait_id}",
        file      => "adj_means_${trial_id}_${trait_id}",
        stash_key => "adj_means_file"
    };

    $c->controller('solGS::Files')->cache_file( $c, $cache_data );

}

# Compute a relative performance index ("Points Score") from the
# RAW replicate data.  For each accession, sort its replicates by
# yield, remove the top 1 and bottom 2, then average the rest
# (trimmed mean).  The overall mean of all trimmed means becomes
# the baseline (= 100 points).  Results are appended as a column
# to the adj_means file for display.
sub _append_points_score_to_adj_means {
    my ( $self, $means_file, $pheno_file, $trait_abbr ) = @_;

    my %result = ( baseline => 0, count => 0 );
    return \%result unless $means_file && -s $means_file;
    return \%result unless $pheno_file && -s $pheno_file;

    # Guard: if Points_Score already appended, strip it so we recompute fresh
    my $existing_header = (read_file($means_file, { binmode => ':utf8' }))[0];
    chomp $existing_header if $existing_header;
    if ($existing_header && $existing_header =~ /Points_Score/) {
        # Remove existing Points_Score column(s) and rewrite the file
        my @all_lines = read_file($means_file, { binmode => ':utf8' });
        my $hdr = shift @all_lines;
        chomp $hdr;
        my @hcols = split(/\t/, $hdr);

        # Find indices to keep (everything except Points_Score)
        my @keep;
        for my $i (0 .. $#hcols) {
            push @keep, $i unless $hcols[$i] eq 'Points_Score';
        }

        my @clean_lines;
        push @clean_lines, join("\t", @hcols[@keep]) . "\n";
        for my $dl (@all_lines) {
            chomp $dl;
            my @dc = split(/\t/, $dl);
            push @clean_lines, join("\t", @dc[@keep]) . "\n";
        }
        write_file($means_file, { binmode => ':utf8' }, @clean_lines);
    }

    # ---- Step 1: Read filtered phenotype file and collect raw values ----
    my @pheno_lines = read_file($pheno_file, { binmode => ':utf8' });
    return \%result unless @pheno_lines >= 2;

    my $pheno_header = shift @pheno_lines;
    chomp $pheno_header;
    my @pheno_headers = split(/\t/, $pheno_header);

    # Find germplasmName column and the trait column
    my ($germ_idx, $trait_idx);
    for my $i (0 .. $#pheno_headers) {
        $germ_idx  = $i if $pheno_headers[$i] eq 'germplasmName';
        # Match trait column by abbreviation (e.g., GY_TH)
        $trait_idx = $i if defined $trait_abbr && $pheno_headers[$i] eq $trait_abbr;
    }

    # If exact match not found, try partial match (trait abbr is a prefix)
    unless (defined $trait_idx) {
        for my $i (0 .. $#pheno_headers) {
            if (defined $trait_abbr && $pheno_headers[$i] =~ /^\Q$trait_abbr\E/) {
                $trait_idx = $i;
                last;
            }
        }
    }

    return \%result unless defined $germ_idx && defined $trait_idx;

    # Collect raw values per germplasm
    my %germ_values;
    for my $line (@pheno_lines) {
        chomp $line;
        my @cols = split(/\t/, $line, -1);
        my $germ = $cols[$germ_idx] // '';
        next unless $germ;
        my $val = $cols[$trait_idx] // '';
        next unless $val ne '' && $val ne 'NA' && $val =~ /^[\d.]+$/;
        push @{ $germ_values{$germ} }, $val + 0;
    }

    return \%result unless keys %germ_values >= 4;

    # ---- Step 2: Per-accession trimmed mean ----
    # For each accession: sort reps descending, then trim:
    #   5+ reps  → remove top 1 + bottom 2
    #   3-4 reps → remove top 1 + bottom 1
    #   < 3 reps → excluded (no data)
    my %trimmed_means;
    for my $germ (keys %germ_values) {
        my @vals = sort { $b <=> $a } @{ $germ_values{$germ} };
        my $n = scalar @vals;

        next if $n < 3;

        my $start = 1;                              # always skip top 1
        my $end   = ($n >= 5) ? $n - 3 : $n - 2;   # skip bottom 2 or 1

        my $sum = 0;
        my $cnt = 0;
        for my $i ($start .. $end) {
            $sum += $vals[$i];
            $cnt++;
        }
        next unless $cnt > 0;
        $trimmed_means{$germ} = $sum / $cnt;
    }

    return \%result unless keys %trimmed_means >= 3;

    # ---- Step 3: Baseline = mean of top 2/3 trimmed means (100 points) ----
    my @sorted_means = sort { $b <=> $a } values %trimmed_means;
    my $top_count = int( scalar(@sorted_means) * 2 / 3 + 0.5 );
    $top_count = 1 if $top_count < 1;

    my $total = 0;
    for my $i (0 .. $top_count - 1) {
        $total += $sorted_means[$i];
    }
    my $baseline = $total / $top_count;
    return \%result unless $baseline > 0;

    # ---- Step 4: Compute score per germplasm ----
    my %scores;
    for my $germ (keys %trimmed_means) {
        $scores{$germ} = sprintf('%.1f', ($trimmed_means{$germ} / $baseline) * 100);
    }

    # ---- Step 5: Append Points_Score column to adj_means file ----
    my @means_lines = read_file($means_file, { binmode => ':utf8' });
    return \%result unless @means_lines >= 2;

    my $header = shift @means_lines;
    chomp $header;

    my $new_header = $header . "\tPoints_Score";
    my @new_lines;
    for my $line (@means_lines) {
        chomp $line;
        my @cols = split(/\t/, $line);
        my $germ = $cols[0] // '';
        my $score = $scores{$germ} // '';
        push @new_lines, $line . "\t" . $score;
    }

    my $content = $new_header . "\n" . join("\n", @new_lines) . "\n";
    write_file($means_file, { binmode => ':utf8' }, $content);

    $result{baseline} = sprintf('%.2f', $baseline);
    $result{count}    = scalar keys %trimmed_means;

    return \%result;
}

# Replace outlier-marked phenotype values with NA in the phenotype
# data file.  This keeps the row structure intact (blocks, reps) so
# the mixed-model ANOVA handles missing data gracefully.
#
# The phenotype data file uses short/abbreviated trait column names
# (e.g. 'GY_TH') that differ from the DB full format
# ('Grain yield - t/ha|CO_322:0000731').  We match outliers by
# stock_id via the observationUnitDbId column instead of names.
sub _filter_outliers_from_phenofile {
    my ( $self, $c, $pheno_file ) = @_;

    return 0 unless $pheno_file && -s $pheno_file;

    my $trial_id = $c->stash->{trial_id};
    my $schema   = $self->schema($c);

    # Resolve the cvterm_id for the outlier property type
    my $outlier_type_id = SGN::Model::Cvterm
        ->get_cvterm_row($schema, 'phenotype_outlier', 'phenotype_property')
        ->cvterm_id();

    # Query outlier stock_ids for this trial.
    # NOTE: We do NOT filter by trait_id here because the same trait
    # can exist under different ontology cvterm_ids (e.g. CO_321 vs
    # CO_322) and outliers may be stored against a different cvterm_id
    # than what ANOVA uses. Filtering by trial only is safe because
    # each outlier row in phenotypeprop is already trait-specific.
    my $dbh = $schema->storage->dbh();
    my $sth = $dbh->prepare(qq{
        SELECT DISTINCT nes.stock_id
        FROM phenotypeprop pp
        JOIN phenotype p       ON pp.phenotype_id = p.phenotype_id
        JOIN nd_experiment_phenotype nep ON nep.phenotype_id = p.phenotype_id
        JOIN nd_experiment_stock nes     ON nes.nd_experiment_id = nep.nd_experiment_id
        JOIN nd_experiment_project nexp  ON nexp.nd_experiment_id = nep.nd_experiment_id
        WHERE pp.type_id = ?
          AND nexp.project_id = ?
    });
    $sth->execute($outlier_type_id, $trial_id);

    my %outlier_stock_ids;
    while (my ($sid) = $sth->fetchrow_array()) {
        $outlier_stock_ids{$sid} = 1;
    }

    return 0 unless keys %outlier_stock_ids;

    # Read the TSV file
    my @lines = read_file($pheno_file, { binmode => ':utf8' });
    return 0 unless @lines;

    my $header = shift @lines;
    chomp $header;
    my @headers = split(/\t/, $header);

    # Known metadata columns that are NOT trait data
    my %metadata_cols = map { $_ => 1 } qw(
        studyYear programDbId programName programDescription
        studyDbId studyName studyDescription studyDesign
        plotWidth plotLength fieldSize
        fieldTrialIsPlannedToBeGenotyped fieldTrialIsPlannedToCross
        plantingDate harvestDate locationDbId locationName
        germplasmDbId germplasmName germplasmSynonyms
        observationLevel observationUnitDbId observationUnitName
        replicate blockNumber plotNumber rowNumber colNumber
        entryType plantNumber notes
    );

    # Find observationUnitDbId, germplasmName, and trait columns
    my $obs_dbid_col_idx;
    my $germplasm_col_idx;
    my @trait_col_indices;

    for my $i (0 .. $#headers) {
        if ($headers[$i] eq 'observationUnitDbId') {
            $obs_dbid_col_idx = $i;
        }
        elsif ($headers[$i] eq 'germplasmName') {
            $germplasm_col_idx = $i;
        }
        # Trait columns are everything NOT in the metadata list
        elsif (!exists $metadata_cols{ $headers[$i] }) {
            push @trait_col_indices, $i;
        }
    }

    return 0 unless defined $obs_dbid_col_idx && @trait_col_indices;

    my $excluded_count = 0;

    for my $line (@lines) {
        chomp $line;
        my @cols = split(/\t/, $line, -1);  # preserve empty trailing fields

        my $stock_id = $cols[$obs_dbid_col_idx] // '';
        next unless exists $outlier_stock_ids{$stock_id};

        # Blank out all trait columns for this outlier plot
        for my $idx (@trait_col_indices) {
            if (defined $cols[$idx] && $cols[$idx] ne '' && $cols[$idx] ne 'NA') {
                $cols[$idx] = 'NA';
                $excluded_count++;
            }
        }

        $line = join("\t", @cols);
    }

    # --- Second pass: exclude germplasms with < 3 valid replicates ---
    # ANOVA requires at least 3 reps for reliable variance estimation.
    # Count remaining non-NA values per germplasm, then blank those
    # that fall below the threshold.
    my $min_reps = 3;
    my $low_rep_excluded = 0;

    if (defined $germplasm_col_idx && @trait_col_indices) {
        # Count non-NA trait values per germplasm (use first trait col
        # as representative — all traits are blanked together)
        my %germ_valid_count;
        my $rep_trait_idx = $trait_col_indices[0];

        for my $line (@lines) {
            my @cols = split(/\t/, $line, -1);
            my $germ = $cols[$germplasm_col_idx] // '';
            next unless $germ;
            my $val = $cols[$rep_trait_idx] // '';
            if ($val ne '' && $val ne 'NA') {
                $germ_valid_count{$germ}++;
            }
        }

        # Identify germplasms below the minimum replicate threshold
        my %low_rep_germs;
        for my $germ (keys %germ_valid_count) {
            if ($germ_valid_count{$germ} < $min_reps) {
                $low_rep_germs{$germ} = $germ_valid_count{$germ};
            }
        }
        # Also catch germplasms with zero valid reps (not in %germ_valid_count)
        # — they'll be caught by the blanking loop already having all NA.

        if (keys %low_rep_germs) {
            for my $line (@lines) {
                chomp $line;
                my @cols = split(/\t/, $line, -1);
                my $germ = $cols[$germplasm_col_idx] // '';

                next unless exists $low_rep_germs{$germ};

                for my $idx (@trait_col_indices) {
                    if (defined $cols[$idx] && $cols[$idx] ne '' && $cols[$idx] ne 'NA') {
                        $cols[$idx] = 'NA';
                        $low_rep_excluded++;
                    }
                }

                $line = join("\t", @cols);
            }
        }
    }

    $excluded_count += $low_rep_excluded;

    # Rewrite the file only if we actually excluded something
    if ($excluded_count > 0) {
        my $content = $header . "\n" . join("\n", @lines) . "\n";
        write_file($pheno_file, { binmode => ':utf8' }, $content);
    }

    return $excluded_count;
}

# Persist the outlier exclusion count to a file in the ANOVA cache
# so the response endpoint (a separate HTTP request) can read it.
sub _write_outlier_count_file {
    my ( $self, $c, $count ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};
    my $cache    = $c->stash->{anova_cache_dir};

    return unless $cache;

    my $file = catfile($cache, "outlier_count_${trial_id}_${trait_id}.txt");
    write_file($file, { binmode => ':utf8' }, $count);
}

# Read the persisted outlier count.
sub _read_outlier_count_file {
    my ( $self, $c ) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};
    my $cache    = $c->stash->{anova_cache_dir};

    return 0 unless $cache;

    my $file = catfile($cache, "outlier_count_${trial_id}_${trait_id}.txt");
    return 0 unless -s $file;

    my $count = read_file($file, { binmode => ':utf8' });
    chomp $count;
    return looks_like_number($count) ? $count : 0;
}

sub schema {
    my ( $self, $c ) = @_;

    return $c->dbic_schema("Bio::Chado::Schema");

}

sub begin : Private {
    my ( $self, $c ) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

# Save Points Score values to the database as phenotype records.
# Called via POST /anova/save_points_scores/ with trial_id + trait_id.
sub save_points_scores : Path('/anova/save_points_scores/') Args(0) {
    my ( $self, $c ) = @_;

    # Declared outside eval so the catch-block can rollback on error
    my $_txn_dbh;

    eval {

    my $args = $c->req->param('arguments');
    # Parse JSON directly — stash_json_args calls stash_protocol_id
    # which crashes on undef genotyping_protocol_id.
    my $parsed = eval { JSON::decode_json($args) } || {};
    my $trial_id = $parsed->{trial_id};
    my $trait_id = $parsed->{trait_id};

    unless ($trial_id && $trait_id) {
        $c->stash->{rest}{Error} = "Missing trial_id($trial_id) or trait_id($trait_id). Args: $args";
        return;
    }

    # Find adj_means file — dynamically scan tmp directory structure
    my $tmp_base = $c->config->{cluster_shared_tempdir} || '/home/production/tmp';
    my @search_dirs;
    if (opendir(my $top_dh, $tmp_base)) {
        for my $subdir (readdir($top_dh)) {
            next if $subdir =~ /^\./;
            my $anova_cache = "$tmp_base/$subdir/anova/cache";
            push @search_dirs, $anova_cache if -d $anova_cache;
            my $anova_dir = "$tmp_base/$subdir/anova";
            push @search_dirs, $anova_dir if -d $anova_dir && $anova_dir ne $anova_cache;
        }
        closedir($top_dh);
    }
    # Also include the flat breedbase-site/anova path if present
    my $flat_anova = "$tmp_base/breedbase-site/anova";
    push @search_dirs, $flat_anova if -d $flat_anova;

    my $prefix = "adj_means_${trial_id}_";
    my $means_file;
    my $best_mtime = 0;

    for my $dir (@search_dirs) {
        next unless -d $dir;
        opendir(my $dh, $dir) or next;
        while (my $entry = readdir($dh)) {
            next unless $entry =~ /^\Q$prefix\E\d+$/;
            my $full = "$dir/$entry";
            next unless -s $full;
            # Check for Points_Score in header
            open(my $fh, '<:utf8', $full) or next;
            my $hdr = <$fh>;
            close($fh);
            next unless $hdr && $hdr =~ /Points_Score/;
            my $mtime = (stat($full))[9] || 0;
            if ($mtime > $best_mtime) {
                $best_mtime = $mtime;
                $means_file = $full;
            }
        }
        closedir($dh);
    }

    unless ($means_file) {
        $c->stash->{rest}{Error} = "No adj_means file with Points_Score found for trial $trial_id.";
        return;
    }

    my @lines = read_file($means_file, { binmode => ':utf8' });
    my $header = shift @lines;
    chomp $header;
    my @hcols = split(/\t/, $header);

    # Find Points_Score column index
    my $ps_idx;
    for my $i (0 .. $#hcols) {
        if ($hcols[$i] eq 'Points_Score') {
            $ps_idx = $i;
            last;
        }
    }

    unless (defined $ps_idx) {
        $c->stash->{rest}{Error} = 'Points_Score column not found. Re-run ANOVA.';
        return;
    }

    # Parse germplasm => score pairs
    my %scores;
    for my $line (@lines) {
        chomp $line;
        my @cols = split(/\t/, $line);
        next unless @cols > $ps_idx;
        my $germ  = $cols[0];
        my $score = $cols[$ps_idx];
        next unless defined $score && $score =~ /^[\d.]+$/;
        $scores{$germ} = $score + 0;
    }

    unless (keys %scores) {
        $c->stash->{rest}{Error} = 'No valid scores found.';
        return;
    }

    # Resolve the Performance score cvterm_id
    my $schema = $self->schema($c);
    my $ps_cvterm = SGN::Model::Cvterm
        ->get_cvterm_row($schema, 'Performance score - points', 'cxgn_units_ontology');

    unless ($ps_cvterm) {
        $c->stash->{rest}{Error} = 'Performance score - points trait not found.';
        return;
    }

    my $ps_cvterm_id = $ps_cvterm->cvterm_id();
    my $dbh = $schema->storage->dbh();
    $_txn_dbh = $dbh;  # capture for rollback in outer catch

    # Begin transaction — all deletes + inserts must be atomic
    $dbh->begin_work;

    # Find plots for this trial with their accession names.
    # Use DISTINCT to avoid duplicates from multiple experiment links.
    my $plot_sth = $dbh->prepare(qq{
        SELECT DISTINCT plot.stock_id AS plot_id,
               acc.uniquename AS germplasm
        FROM stock plot
        JOIN stock_relationship sr ON sr.subject_id = plot.stock_id
        JOIN stock acc ON sr.object_id = acc.stock_id
        WHERE plot.stock_id IN (
            SELECT nes.stock_id
            FROM nd_experiment_stock nes
            JOIN nd_experiment_project nep ON nep.nd_experiment_id = nes.nd_experiment_id
            WHERE nep.project_id = ?
        )
        AND plot.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'plot')
        AND acc.type_id  = (SELECT cvterm_id FROM cvterm WHERE name = 'accession')
    });
    $plot_sth->execute($trial_id);

    my @plot_rows;
    while (my $row = $plot_sth->fetchrow_hashref()) {
        push @plot_rows, $row;
    }

    unless (@plot_rows) {
        $c->stash->{rest}{Error} = 'No plots found for this trial.';
        return;
    }

    # --- Cleanup: remove all prior Points Score data for this trial ---
    # Identify old nd_experiments created by prior saves (via uniquename pattern).
    my $old_exp_ids = $dbh->selectcol_arrayref(qq{
        SELECT nd_experiment_id FROM nd_experiment
        WHERE nd_experiment_id IN (
            SELECT nep2.nd_experiment_id
            FROM nd_experiment_phenotype nep2
            JOIN phenotype p ON p.phenotype_id = nep2.phenotype_id
            WHERE p.uniquename LIKE 'points_score_${trial_id}_%'
        )
    });

    if (@$old_exp_ids) {
        my $id_list = join(',', @$old_exp_ids);
        # Remove link tables first, then experiments
        $dbh->do("DELETE FROM nd_experiment_phenotype WHERE nd_experiment_id IN ($id_list)");
        $dbh->do("DELETE FROM nd_experiment_stock    WHERE nd_experiment_id IN ($id_list)");
        $dbh->do("DELETE FROM nd_experiment_project  WHERE nd_experiment_id IN ($id_list)");
        $dbh->do("DELETE FROM nd_experiment          WHERE nd_experiment_id IN ($id_list)");
    }

    # Delete orphaned phenotype records
    $dbh->do(qq{
        DELETE FROM phenotype
        WHERE uniquename LIKE 'points_score_${trial_id}_%'
    });

    # --- Determine experiment metadata from existing trial experiments ---
    my ($exp_type_id, $geo_id) = $dbh->selectrow_array(qq{
        SELECT ne.type_id, ne.nd_geolocation_id
        FROM nd_experiment ne
        JOIN nd_experiment_project nep ON nep.nd_experiment_id = ne.nd_experiment_id
        WHERE nep.project_id = ?
        LIMIT 1
    }, undef, $trial_id);

    unless ($exp_type_id && $geo_id) {
        $c->stash->{rest}{Error} = 'Cannot determine experiment type for trial.';
        return;
    }

    # --- Insert: one nd_experiment + phenotype per plot ---
    my $exp_sth = $dbh->prepare(qq{
        INSERT INTO nd_experiment (nd_geolocation_id, type_id)
        VALUES (?, ?)
        RETURNING nd_experiment_id
    });

    my $exp_proj_sth = $dbh->prepare(qq{
        INSERT INTO nd_experiment_project (nd_experiment_id, project_id)
        VALUES (?, ?)
    });

    my $exp_stock_sth = $dbh->prepare(qq{
        INSERT INTO nd_experiment_stock (nd_experiment_id, stock_id, type_id)
        VALUES (?, ?, ?)
    });

    my $pheno_sth = $dbh->prepare(qq{
        INSERT INTO phenotype (observable_id, cvalue_id, value, uniquename)
        VALUES (?, ?, ?, ?)
        RETURNING phenotype_id
    });

    my $exp_pheno_sth = $dbh->prepare(qq{
        INSERT INTO nd_experiment_phenotype (nd_experiment_id, phenotype_id)
        VALUES (?, ?)
    });

    my $saved = 0;
    for my $pr (@plot_rows) {
        my $germ  = $pr->{germplasm};
        my $score = $scores{$germ};
        next unless defined $score;

        my $plot_id = $pr->{plot_id};
        my $uniq = "points_score_${trial_id}_${plot_id}_${ps_cvterm_id}";

        # Create dedicated nd_experiment
        $exp_sth->execute($geo_id, $exp_type_id);
        my ($exp_id) = $exp_sth->fetchrow_array();

        # Link experiment to project and stock
        $exp_proj_sth->execute($exp_id, $trial_id);
        $exp_stock_sth->execute($exp_id, $plot_id, $exp_type_id);

        # Create phenotype and link to experiment
        $pheno_sth->execute($ps_cvterm_id, $ps_cvterm_id, $score, $uniq);
        my ($pheno_id) = $pheno_sth->fetchrow_array();
        $exp_pheno_sth->execute($exp_id, $pheno_id);

        $saved++;
    }

    # Commit the transaction — all records inserted successfully
    $dbh->commit;

    $c->stash->{rest}{success} = "Saved $saved Points Score values.";
    $c->stash->{rest}{saved_count} = $saved;

    };  # end eval

    if ($@) {
        my $err = $@;
        # Rollback on any error to maintain data consistency
        eval { $_txn_dbh->rollback if $_txn_dbh; };
        $c->stash->{rest}{Error} = "Perl error: $err";
    }
}

__PACKAGE__->meta->make_immutable;

1;
