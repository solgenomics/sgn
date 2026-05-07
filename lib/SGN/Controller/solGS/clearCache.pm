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

    my $trials_ids = [];
    $trials_ids = [ $trial_id ] if $trial_id;

    if ($dataset_id) {
        $trials_ids = $self->get_dataset_trials($c, $dataset_id);
    }

    my $delete_dirs_result = 1; 
    for my $trial_id (@$trials_ids) {
        $delete_dirs_result = $self->delete_cache_dirs($c, $trial_id, $analysis_type);
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


sub clear_cache_trial_analysis_data {
    my ($self, $c, $trial_id, $analysis_type) = @_;


    my $delete_dirs_result = $self->delete_cache_dirs($c, $trial_id, $analysis_type);
    
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
    my ($self, $c, $trial_id, $analysis_type) = @_;

    die "Trial ID must be a positive integer"
        unless $trial_id =~ /^\d+$/;

    die "Invalid analysis type"
        unless $analysis_type =~ /^[a-zA-Z]+$/;

    my $analysis_cache_dir = catdir($c->stash->{"${analysis_type}_cache_dir"}, 'trials', $trial_id);
    my $solgs_trial_cache_dir = catdir($c->stash->{solgs_cache_dir}, 'trials', $trial_id);
    my $analysis_temp_dir = $c->stash->{"${analysis_type}_temp_dir"};
    my $analysis_tempfiles_subdir = catdir($c->tempfiles_subdir, $analysis_type, 'trials', $trial_id);

    my @dirs_to_delete = (
        $analysis_cache_dir, 
        $solgs_trial_cache_dir, 
        $analysis_temp_dir, 
        $analysis_tempfiles_subdir
    );

    remove_tree(@dirs_to_delete, {
        error => \my $err,
        safe  => 1,
    });

    if (@$err) {
        $c->log->error("Error removing a directory: " . $err->[0]->{message} . " at " . $err->[0]->{path});
        return 0;
    }
    
    return 1;

}


sub begin : Private {
    my ( $self, $c ) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}