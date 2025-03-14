package SGN::Controller::solGS::pcaSave;

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


sub pca_result_details :Path('/solgs/pca/result/details') Args() {
    my ($self, $c) = @_;

	my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

	my $stored = $c->controller('solGS::AnalysisSave')->check_stored_analysis($c);

	if (!$stored) {
		my $params = decode_json($args);
		my $analysis_details;

		eval {
			if ($c->stash->{analysis_type} =~ /pca/) {
				$analysis_details = $self->structure_pca_result_details($c);
			} 
		};

		if ($@) {
			print STDERR "\n$@\n";
			$c->stash->{rest}{error} = 'Something went wrong structuring pca analysis result for storage.';
		} else {
			$c->stash->{rest}{analysis_details} = $analysis_details;
		}
	}

}


sub pca_details {
	my ($self, $c) = @_;

	my $pca_type = 'prcomp';
	my $stat_ont_term = 'Principal component analysis using prcomp from base R package|SGNSTAT:0000043';
	my $protocol = "prcomp method from base R Package";
	my $log = $c->controller('solGS::AnalysisSave')->get_analysis_job_info($c);
	my $pca_page = $log->{analysis_page};
	my $pca_desc = qq | <a href="$pca_page">Go to PCA detail page</a>|;

	my $details = {
		'pca_type' => $pca_type,
		'pca_page' => $pca_page,
		'pca_desc' => $pca_desc,
		'pca_lang' => 'R',
		'stat_ont_term' => $stat_ont_term,
		'protocol' => $protocol
	};

	return $details;
}


sub get_pca_scores {
	my ($self, $c) = @_;

    $c->controller('solGS::pca')->pca_scores_file($c);
	my $scores_file = $c->stash->{pca_scores_file};
	my @cols = $c->controller('solGS::Utils')->get_data_col_headers($scores_file);
	my @pc_cols = grep(/PC/i, @cols);

	my $include_rownames = 'TRUE';
	my $scores = $c->controller('solGS::Utils')->read_file_data_cols($scores_file, \@pc_cols, $include_rownames);
	
	#remove the first array with col headers
	shift(@$scores);

	return $scores;

}

sub structure_pca_scores {
	my ($self, $c) = @_;

	my $pcs_names = $self->get_pcs_names($c);
	my $scores = $self->get_pca_scores($c);
	my $scores_ref = $c->controller('solGS::Utils')->convert_arrayref_to_hashref($scores);
	
	my %scores_hash;
	my $now = DateTime->now();
	my $timestamp = $now->ymd()."T".$now->hms();

	my $user = $c->controller('solGS::AnalysisQueue')->get_user_detail($c);
	my $user_name = $user->{user_name};

	my @accessions = keys %$scores_ref;
	
		foreach my $accession (@accessions) { 
			for (my $i=0;  $i < scalar(@$pcs_names);  $i++) {
				my $pc = $pcs_names->[$i];
		
				$scores_hash{$accession}{$pc} = 
					[$scores_ref->{$accession}->[$i], $timestamp, $user_name, "", ""];
			}
		}

	return \%scores_hash;

}

sub get_pcs_names {
	my ($self, $c) = @_;

	$c->controller('solGS::pca')->pca_scores_file($c);
	my $scores_file = $c->stash->{pca_scores_file};
	my @cols = $c->controller('solGS::Utils')->get_data_col_headers($scores_file);
	my @pc_cols = grep(/PC/i, @cols);

	my $cv_name = "SGNStatistics_ontology";
	my $schema = $self->schema($c);
	my @extended_pc_names;

	foreach my $pc (@pc_cols) {
		my ($num) = $pc =~ /(\d+)/;
		my $cvterm_name = 'Principal component '   . $num . ' (PC' . $num . ') scores';
		my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $cvterm_name, $cv_name)->cvterm_id();
		my $extended_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $cvterm_id, 'extended');
		
		push @extended_pc_names, $extended_name;
	}

	return \@extended_pc_names;

}

sub structure_pca_result_details {
	my ($self, $c) = @_;

	my $scores = $self->structure_pca_scores($c);
	my @stocks = keys %$scores;

	my $pcs_names		= $self->get_pcs_names($c);
	my $pca_details     = $self->pca_details($c);
	my $app_details		= $c->controller('solGS::AnalysisSave')->app_details();
    my $analysis_year   = $c->controller('solGS::AnalysisSave')->analysis_year($c);
    my $breeding_prog_id = $c->controller('solGS::AnalysisSave')->analysis_breeding_prog($c);
    my $log			    = $c->controller('solGS::AnalysisSave')->get_analysis_job_info($c);
	my $analysis_name   = $log->{analysis_name};
    my $data_type = $log->{data_type};
    my $data_str = $log->{data_structure};

    my $analysis_result_stock_names = '';
    my $is_analysis_result_stock_type = 0;
    my $analysis_result_values_type = 'analysis_result_values_match_accession_names',

    my $accession_names = encode_json(\@stocks);
    if ($data_type =~ /phenotype/i && $data_str =~ /dataset/) {
        my $dataset = CXGN::Dataset->new({
            people_schema => $c->dbic_schema("CXGN::People::Schema"),
            schema => $c->dbic_schema("Bio::Chado::Schema", "sgn_chado"),
            sp_dataset_id => $log->{dataset_id},
        });

        my $dataset_data = $dataset->get_dataset_data();
        if (scalar(@{$dataset_data->{categories}->{trials}}) > 1) {
            $analysis_result_stock_names = encode_json(\@stocks);
            $is_analysis_result_stock_type = 1;
            $analysis_result_values_type = 'analysis_result_new_stocks';
            $accession_names = '';
        } 
    } 

    my $details = {
        'analysis_to_save_boolean' => 'yes',
        'analysis_name' => $log->{analysis_name},
        'analysis_description' => $log->{pca_desc} || 'test pca load',
        'analysis_year' => $analysis_year,
        'analysis_breeding_program_id' => $breeding_prog_id,
        'analysis_protocol' => $pca_details->{protocol},
        'analysis_dataset_id' => $log->{dataset_id},
        'analysis_accession_names' => $accession_names,
        'analysis_trait_names' => encode_json($pcs_names),
        'analysis_precomputed_design_optional' =>'',
        'analysis_result_values' => to_json($scores),
        'analysis_result_values_type' => $analysis_result_values_type,
        'is_analysis_result_stock_type' => $is_analysis_result_stock_type,
        'analysis_result_stock_names' => $analysis_result_stock_names,
        'analysis_result_summary' => '',
        'analysis_result_trait_compose_info' =>  "",
        'analysis_statistical_ontology_term' =>  $pca_details->{stat_ont_term},
        'analysis_model_application_version' => $app_details->{version},
        'analysis_model_application_name' => $app_details->{name},
        'analysis_model_language' => $pca_details->{pca_lang},
        'analysis_model_is_public' => 'yes',
        'analysis_model_description' =>  $pca_details->{pca_desc},
        'analysis_model_name' => $log->{analysis_name},
        'analysis_model_type' => $pca_details->{pca_type},
    };

	return $details;

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
