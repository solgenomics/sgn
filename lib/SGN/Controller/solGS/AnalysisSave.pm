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
use SGN::Model::Cvterm;
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

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $analysis_id = $self->check_stored_analysis($c);
    $c->stash->{rest} {analysis_id} = $analysis_id;

    if ($analysis_id) {
        $c->stash->{rest}{error} = "The results of this analysis are already in the database.";
    } 
        
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

    my $log = $self->get_analysis_job_info($c);
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

    my $log = $self->get_analysis_job_info($c);

    my $trial_id;
    if (ref $log->{training_pop_id} eq 'ARRAY') {
         $trial_id = $log->{training_pop_id}[0];
    } else {
         $trial_id = $log->{training_pop_id};
    }
    
    if ($log->{data_set_type} =~ /combined/) {
        my $trials_ids = $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $trial_id);
        $trial_id = $trials_ids->[0];
    }

    if ($trial_id =~ /list/) {
        $trial_id = $c->controller('solGS::List')->get_trial_id_plots_list($c, $trial_id);
    }

    my $program_id;
    if ($trial_id =~ /^\d+$/) {
        $program_id = $c->controller('solGS::Search')->model($c)->trial_breeding_program_id($trial_id);
    }

    if (!$program_id) {
        my $data_type = $log->{data_type};
        my $data_str = $log->{data_structure};
        
        if ($data_str =~ /dataset/) {
            $c->stash->{dataset_id} = $log->{dataset_id};
            $program_id = $c->controller('solGS::Dataset')->get_dataset_breeding_program($c);

        } elsif ($data_str =~ /list/) {
            $c->stash->{list_id} = $log->{list_id};
            $program_id = $c->controller('solGS::List')->get_list_breeding_program($c);
        }
    }
    
    return $program_id;

}

sub analysis_year {
    my ($self, $c) = @_;

    my $log = $self->get_analysis_job_info($c);
    my $time = $log->{analysis_time};

    $time= (split(/\s+/, $time))[0];
    my $year = (split(/\//, $time))[2];

    return $year;

} 

sub get_analysis_result_specific_analysis_name {
    my ($self, $c) = @_;

    my $log = $self->get_analysis_job_info($c);
    my $analysis_name = $log->{analysis_name};
    my $analysis_result_save_type = $c->stash->{analysis_result_save_type};
    $analysis_name .= " -- $analysis_result_save_type" if $analysis_result_save_type;

    return $analysis_name;
}

sub check_stored_analysis {
    my ($self, $c) = @_;

    my $analysis_name = $self->get_analysis_result_specific_analysis_name($c);
    my $analysis_id;

    if ($analysis_name) {
        my $schema = $self->schema($c);
        my $analysis = $schema->resultset("Project::Project")->find({ name => $analysis_name });
        
        if ($analysis) {
            $analysis_id = $analysis->project_id;
        } 
    }
    
    return $analysis_id;

}

sub check_logged_analysis_name {
    my ($self, $c) = @_;

    my $log = $self->get_analysis_job_info($c);

    return $log->{analysis_name};

}

sub extended_trait_name {
    my ($self, $c, $trait_id) = @_;

    return SGN::Model::Cvterm::get_trait_from_cvterm_id($self->schema($c), $trait_id, 'extended');

}

sub get_analysis_job_info {
    my ($self, $c) = @_;

    my $files = $self->all_users_analyses_logs($c);
    my $analysis_page = $c->stash->{analysis_page};
    my $analysis_name = $c->stash->{analysis_name};
    
    my @log;
    my @analysis_logs;
    foreach my $log_file (@$files) {
        my @logs = read_file($log_file, {binmode => ':utf8'});
        @analysis_logs = grep{ $_ =~ /$analysis_page\s+/} @logs;

        last if @analysis_logs;
    }

    if (@analysis_logs) {
        my @analysis_times;
        foreach my $analysis_log (@analysis_logs){
            my @analysis_log_cols = split(/\t/, $analysis_log);
            push @analysis_times, $analysis_log_cols[4];
        }

        my ($oldest, $latest) = (sort @analysis_times)[0, -1];
        
        my ($latest_analysis_log) = grep{ $_ =~ $latest } @analysis_logs;
        my @latest_analysis_log_cols = split(/\t/, $latest_analysis_log);
        my $analysis_info = decode_json($latest_analysis_log_cols[5]);

        return $analysis_info;
    } else {
        return;
    }

}

sub all_users_analyses_logs {
    my ($self, $c) = @_;

    my $dir = $c->stash->{analysis_log_dir};
    my @files = File::Find::Rule->file()
                            ->name( 'analysis_log*' )
                            ->in( $dir );
    
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
