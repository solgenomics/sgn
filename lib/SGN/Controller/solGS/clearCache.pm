package SGN::Controller::solGS::clearCache;

use Moose;
use namespace::autoclean;

use File::Path qw /remove_tree/;
use File::Spec::Functions;
use CXGN::Dataset;
use JSON;
#use Data::Dumper;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);


BEGIN { extends 'Catalyst::Controller::REST' }

our @ANALYSIS_TYPES = (
    "solgs", "solqtl","anova", "correlation", 
    "cluster", "kinship", "pca", "qualityControl", 
    "heritability", "selectionIndex", "histogram", 
);

sub solgs_cache_clear : Path('/solgs/cache/clear') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->params;
    
    my $cache_cleared = $self->clear_cached_analyses_result($c, $args);

    if ($cache_cleared) {
        $c->stash->{rest}{'success'} = 1;
        $c->stash->{rest}{'message'} = "Cache cleared for analysis type.";

    } else {
        $c->stash->{rest}{'success'} = 0;
        $c->stash->{rest}{'message'} = "Failed to clear cache for analysis type.";
    }

}

sub clear_cached_analyses_result {
    my ($self, $c, $args) = @_;

    if ($args->{dataset_id}) {
        if (ref($args->{trials}) ne 'ARRAY') {    
            $args->{trials} = $self->get_dataset_trials($c, $args->{dataset_id});
        }
    }

    my $cache_dirs = {
        data_dir_ids  => $self->_get_data_dir_ids($args),
        analysis_type_dirs => $self->_get_analysis_type_dirs($args),
    };

    my $delete_dirs_result = $self->delete_cache_dirs($c, $cache_dirs);

    return $delete_dirs_result;
}


sub get_dataset_trials {
    my ($self, $c, $dataset_id) = @_;

    $dataset_id =~ s/dataset_//; 

    my $user_id = $c->user() ? $c->user()->get_object()->get_sp_person_id() : undef;
    my $dataset = CXGN::Dataset->new({ 
        schema => $c->dbic_schema('Bio::Chado::Schema'),  
        people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $user_id),
        sp_dataset_id => $dataset_id 
    });

    if ($dataset) {
        my $trials = $dataset->retrieve_trials();
        my @trial_ids = ();
    
        foreach my $trial (@$trials){
            push @trial_ids, $trial->[0];
        }
    
        return \@trial_ids;
    } else {
        return;
    }
}

sub delete_cache_dirs {
    my ($self, $c, $cache_dirs) = @_;

    my @data_id_dirs = @{$cache_dirs->{data_dir_ids}};
    my @analysis_types = @{$cache_dirs->{analysis_type_dirs}};
    
    for my $analysis_type (@analysis_types) {

        for my $data_id (@data_id_dirs) {
            print STDERR "\nDeleting cache directories for trial_id/dataset_id: $data_id, analysis_type: $analysis_type\n";
            my $analysis_cache_dir = $self->analysis_cache_dir($c, $data_id, $analysis_type);
            my $analysis_tempfiles_dir = $self->analysis_tempfiles_dir($c, $data_id, $analysis_type);

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
    }
    
    return 1;

}


sub _get_analysis_type_dirs {
    my ($self, $args) = @_;

    my @analysis_types;

    if ($args->{analysis_types} || $args->{analysis_type}) {
        if (ref($args->{analysis_types}) eq 'ARRAY') {
            @analysis_types = @{$args->{analysis_types}};
        } else {
            @analysis_types = $args->{analysis_types} || $args->{analysis_type};
        }

        return \@analysis_types;
    } else {
        return \@ANALYSIS_TYPES;
    } 

}

sub _get_data_dir_ids {
    my ($self, $args) = @_;
    my $trials = $args->{trials};
    my @data_dir_ids = ();
    
    if (ref($trials) eq 'ARRAY') {  
        push @data_dir_ids, @$trials;
    } else {
        push @data_dir_ids, $trials;
    }

    if ($args->{dataset_id}) {
        my $dataset_id = $args->{dataset_id};
        if ($dataset_id !~ /dataset_/) {
            $dataset_id = 'dataset_' . $dataset_id;
        }

        push @data_dir_ids, $dataset_id;
    }

    if ($args->{trial_id}) {
        push @data_dir_ids, $args->{trial_id};
    }

    @data_dir_ids = grep {$_ ne ''} @data_dir_ids;
    
    return \@data_dir_ids;

}

sub analysis_cache_dir {
    my ($self, $c, $data_id, $analysis_type) = @_;

    my $analysis_dir = $c->stash->{"${analysis_type}_dir"};

    if (!$analysis_dir) {
        $c->controller('solGS::Files')->get_solgs_dirs($c);
        $analysis_dir = $c->stash->{"${analysis_type}_dir"};
    }

    return catdir($analysis_dir, $data_id, 'cache');
}

sub analysis_tempfiles_dir {
    my ($self, $c, $data_id, $analysis_type) = @_;

    my $analysis_dir = $c->stash->{"${analysis_type}_dir"};

    if (!$analysis_dir) {
        $c->controller('solGS::Files')->get_solgs_dirs($c);
        $analysis_dir = $c->stash->{"${analysis_type}_dir"};
    }

    return catdir($analysis_dir, $data_id, 'tempfiles');
}


sub begin : Private {
    my ( $self, $c ) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}