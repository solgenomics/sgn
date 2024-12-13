package SGN::Controller::solGS::gebvsSave;

use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use DateTime;
use Data::Dumper;
use File::Find::Rule;
use File::Path qw / mkpath  /;

use JSON;
use Try::Tiny;
use URI;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
    );


sub gebvs_result_details :Path('/solgs/gebvs/result/details') Args() {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $stored = $c->controller('solGS::AnalysisSave')->check_stored_analysis($c);

    if (!$stored) {
        my $params = decode_json($args);
        my $analysis_details;

        eval {	
            $analysis_details = $self->structure_gebvs_result_details($c, $params);
        };

        if ($@) {
            print STDERR "\n$@\n";
            $c->stash->{rest}{error} = 'Something went wrong structuring the analysis result';
        } else {
            $c->stash->{rest}{analysis_details} = $analysis_details;
        }
    }

}

sub structure_gebvs_result_details {
    my ($self, $c, $params) = @_;

    my $gebvs = $self->structure_gebvs_values($c, $params);
    my @accessions = keys %$gebvs;

    my $trait_names		= $c->controller('solGS::AnalysisSave')->analysis_traits($c);
    my $model_details   = $self->model_details($c);
    my $app_details		= $c->controller('solGS::AnalysisSave')->app_details();
    my $log			    = $c->controller('solGS::AnalysisSave')->get_analysis_job_info($c);
    my $breeding_prog_id = $c->controller('solGS::AnalysisSave')->analysis_breeding_prog($c);
    my $analysis_year = $c->controller('solGS::AnalysisSave')->analysis_year($c);

    my $details = {
        'analysis_to_save_boolean' => 'yes',
        'analysis_name' => $log->{analysis_name},
        'analysis_description' => $log->{training_pop_desc},
        'analysis_year' => $analysis_year,
        'analysis_breeding_program_id' => $breeding_prog_id,
        'analysis_protocol' => $model_details->{protocol},
        'analysis_dataset_id' => $log->{dataset_id},
        'analysis_accession_names' => encode_json(\@accessions),
        'analysis_trait_names' => encode_json($trait_names),
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

sub model_details {
    my ($self, $c) = @_;

    my $model_type = 'gblup_model_rrblup';
    my $stat_ont_term = 'GEBVs using GBLUP from rrblup R package|SGNSTAT:0000038';
    my $protocol = "GBLUP model from RRBLUP R Package";
    my $log = $c->controller('solGS::AnalysisSave')->get_analysis_job_info($c);
    my $model_page = $log->{analysis_page};
    my $model_desc= qq | <a href="$model_page">Go to model detail page</a>|;

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

sub gebvs_values {
    my ($self, $c, $params) = @_;

    my $training_pop_id = $params->{training_pop_id};
    my $selection_pop_id = $params->{selection_pop_id};
    my $trait_id = $params->{trait_id};
    my $protocol_id = $params->{genotyping_protocol_id};

    $c->stash->{genotyping_protocol_id} = $protocol_id;

    my $analysis_page = $params->{analysis_page}; 
    $analysis_page = $c->controller('solGS::Path')->page_type($c, $analysis_page);

    my $gebvs_file;
    if ($analysis_page =~ /training_model/) {
        $gebvs_file = $c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $training_pop_id, $trait_id);
    }
    elsif ($analysis_page =~ /selection_prediction/) {
        $gebvs_file = $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
    }

    my $gebvs = $c->controller('solGS::Utils')->read_file_data($gebvs_file);

    return $gebvs;

}

sub structure_gebvs_values {
    my ($self, $c, $params) = @_;

    my $trait_name = $c->controller('solGS::AnalysisSave')->extended_trait_name($c, $params->{trait_id});

    my $gebvs = $self->gebvs_values($c, $params);
    my $gebvs_ref = $c->controller('solGS::Utils')->convert_arrayref_to_hashref($gebvs);

    my %gebvs_hash;
    my $now = DateTime->now();
    my $timestamp = $now->ymd()."T".$now->hms();

    my $user = $c->controller('solGS::AnalysisQueue')->get_user_detail($c);
    my $user_name = $user->{user_name};

    my @accessions = keys %$gebvs_ref;

    foreach my $accession (@accessions) {
        $gebvs_hash{$accession} = {
            $trait_name => [$gebvs_ref->{$accession}->[0], $timestamp, $user_name, "", ""]
        };
    }

    return \%gebvs_hash;

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
