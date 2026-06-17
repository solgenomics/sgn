package SGN::Controller::solGS::clearCache;

use Moose;
use namespace::autoclean;

use File::Path qw /remove_tree/;
use File::Spec::Functions;
use CXGN::Dataset;
use JSON;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);


BEGIN { extends 'Catalyst::Controller::REST' }

sub cache_clear : Path('/solgs/cache/clear') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->params;
    my $analysis_type = $args->{analysis_type};
    my $data_structure = $args->{data_structure};
    my $trial_id = $args->{trial_id};
    my $dataset_id = $args->{dataset_id};

    my @trials_ids = ();
    if ($trial_id) {
        push @trials_ids, $trial_id;
    }

    if ($dataset_id) {
        @trials_ids = $self->get_dataset_trials($c, $dataset_id);
    }

    my $delete_dirs_result = 1; 
    for my $trial_id (@trials_ids) {
        my $args = {
            trial_id => $trial_id,
            analysis_types => ($analysis_type),
            delete_all_analyses_output => 1,
        };

        $delete_dirs_result = $self->delete_cache_dirs($c, $args);
    }
    

    if ($delete_dirs_result) {
        $c->stash->{rest}{'success'} = 1;
        $c->stash->{rest}{'message'} = "Cache cleared for analysis type: $analysis_type";

    } else {
        $c->stash->{rest}{'success'} = 0;
        $c->stash->{rest}{'message'} = "Failed to clear cache for analysis type: $analysis_type";
    }

}


sub clear_cache_trial_data {
    my ($self, $c, $trial_id) = @_;

    my @files_to_delete = $self->get_files_to_delete($c, $trial_id);
    my $delete_files_result = $self->delete_files(\@files_to_delete);

    return $delete_files_result;
}


sub clear_cache_trial_analyses_data {
    my ($self, $c, $trial_id, $analysis_type) = @_;

    my $args = {
        trial_id => $trial_id,
        analysis_types => ($analysis_type),
        delete_all_analyses_output => 1,
    };

    my $delete_dirs_result = $self->delete_cache_dirs($c, $args);

    return $delete_dirs_result;
}


sub get_dataset_trials {
    my ($self, $c, $dataset_id) = @_;

    my $dataset = CXGN::Dataset->new({ schema => $c->dbic_schema('Bio::Chado::Schema'), dataset_id => $dataset_id });
    my $trials_ids = $dataset->get_trials();

    return $trials_ids;
}

sub delete_files {
    my ($self, $file_paths) = @_;

    foreach my $file_path (@$file_paths) {
        print STDERR "Attempting to delete file: $file_path\n";
        if (-e $file_path) {
            unless (unlink $file_path) {
            warn "Could not delete file: $file_path. Error: $!";
            return 0;
            }
        } else {
            warn "File not found, skipping: $file_path";
        }
    }

    return 1;
}

sub get_files_to_delete {
    my ($self, $c, $trial_id, $analysis_type) = @_;

    my @files_to_delete;

    my $phenotype_file = $c->controller('solGS::Files')->phenotype_file_name($c, $trial_id);
    push @files_to_delete, $phenotype_file if $phenotype_file;

    return @files_to_delete;
}


sub delete_cache_dirs {
    my ($self, $c, $args) = @_;

    my $trial_id = $args->{trial_id};
    my @analysis_types = $args->{analysis_types};
    my $delete_all_analyses_output = $args->{delete_all_analyses_output} || 1;

    die "Trial ID must be a positive integer"
        unless $trial_id =~ /^\d+$/;


    if ($delete_all_analyses_output) {
        @analysis_types = (
            "solgs", "solqtl","anova", "correlation", 
            "cluster", "kinship", "pca", "qualityControl", 
            "heritability", "selectionIndex", "histogram", 
        );
    }

    for my $analysis_type (@analysis_types) {

        my $analysis_cache_dir = $self->analysis_cache_dir($c, $trial_id, $analysis_type);
        my $analysis_tempfiles_dir = $self->analysis_tempfiles_dir($c, $trial_id, $analysis_type);

        my @dirs_to_delete = (
            $analysis_cache_dir, 
            $analysis_tempfiles_dir
        );

        remove_tree(@dirs_to_delete, {
            error => \my $err,
            safe  => 1,
        });

        if (@$err) {
            $c->log->error("Error removing a directory: " . $err->[0]->{message} . " at " . $err->[0]->{path});
            return 0;
        }
    }
    
    return 1;

}

sub analysis_cache_dir {
    my ($self, $c, $trial_id, $analysis_type) = @_;

    my $analysis_dir = $c->stash->{"${analysis_type}_dir"};

    if (!$analysis_dir) {
        $c->controller('solGS::Files')->get_solgs_dirs($c);
        $analysis_dir = $c->stash->{"${analysis_type}_dir"};
    }

    return catdir($analysis_dir, $trial_id, 'cache');
}

sub analysis_tempfiles_dir {
    my ($self, $c, $trial_id, $analysis_type) = @_;

    my $analysis_dir = $c->stash->{"${analysis_type}_dir"};

    if (!$analysis_dir) {
        $c->controller('solGS::Files')->get_solgs_dirs($c);
        $analysis_dir = $c->stash->{"${analysis_type}_dir"};
    }

    return catdir($analysis_dir, $trial_id, 'tempfiles');
}


sub begin : Private {
    my ( $self, $c ) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}