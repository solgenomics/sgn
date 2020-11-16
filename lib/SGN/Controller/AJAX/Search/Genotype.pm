
=head1 NAME

SGN::Controller::AJAX::Search::Genotype - a REST controller class to provide search over markerprofiles

=head1 DESCRIPTION


=head1 AUTHOR

=cut

package SGN::Controller::AJAX::Search::Genotype;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Login;
use CXGN::Genotype::Search;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

sub genotyping_data_search : Path('/ajax/genotyping_data/search') : ActionClass('REST') { }

sub genotyping_data_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $clean_inputs = _clean_inputs($c->req->params);

    my $limit = $c->req->param('length');
    my $offset = $c->req->param('start');

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$bcs_schema,
        people_schema=>$people_schema,
        cache_root=>$c->config->{cache_file_path},
        accession_list=>$clean_inputs->{accession_id_list},
        tissue_sample_list=>$clean_inputs->{tissue_sample_id_list},
        trial_list=>$clean_inputs->{genotyping_data_project_id_list},
        protocol_id_list=>$clean_inputs->{protocol_id_list},
        #marker_name_list=>['S80_265728', 'S80_265723']
        #marker_search_hash_list=>[{'S80_265728' => {'pos' => '265728', 'chrom' => '1'}}],
        #marker_score_search_hash_list=>[{'S80_265728' => {'GT' => '0/0', 'GQ' => '99'}}],
        genotypeprop_hash_select=>['DS'],
        protocolprop_marker_hash_select=>[],
        protocolprop_top_key_select=>[],
        forbid_cache=>$clean_inputs->{forbid_cache}->[0]
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c->config->{cluster_shared_tempdir}, 1); #only gets metadata and not all genotype data!
    my @result;
    my $counter = 0;

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;
    if ($header_line) {
        my $marker_objects = decode_json $header_line;

        my $start_index = $offset;
        my $end_index = $offset + $limit;
        # print STDERR Dumper [$start_index, $end_index];

        while (my $gt_line = <$fh>) {
            if ($counter >= $start_index && $counter < $end_index) {
                my $g = decode_json $gt_line;
                # print STDERR Dumper $g;
                my $synonym_string = scalar(@{$g->{synonyms}})>0 ? join ',', @{$g->{synonyms}} : '';
                push @result, [
                    "<a href=\"/breeders_toolbox/protocol/$g->{analysisMethodDbId}\">$g->{analysisMethod}</a>",
                    "<a href=\"/stock/$g->{stock_id}/view\">$g->{stock_name}</a>",
                    $g->{stock_type_name},
                    "<a href=\"/stock/$g->{germplasmDbId}/view\">$g->{germplasmName}</a>",
                    $synonym_string,
                    $g->{genotypeDescription},
                    $g->{resultCount},
                    $g->{igd_number},
                    "<a href=\"/stock/$g->{stock_id}/genotypes?genotypeprop_id=$g->{markerProfileDbId}\">Download</a>"
                ];
            }
            $counter++;
        }
    }
    #print STDERR Dumper \@result;

    my $draw = $c->req->param('draw');
    if ($draw){
        $draw =~ s/\D//g; # cast to int
    }

    $c->stash->{rest} = { data => \@result, draw => $draw, recordsTotal => $counter,  recordsFiltered => $counter };
}

sub _clean_inputs {
	no warnings 'uninitialized';
	my $params = shift;
	foreach (keys %$params){
		my $values = $params->{$_};
		my $ret_val;
		if (ref \$values eq 'SCALAR'){
			push @$ret_val, $values;
		} elsif (ref $values eq 'ARRAY'){
			$ret_val = $values;
		} else {
			die "Input is not a scalar or an arrayref\n";
		}
		@$ret_val = grep {$_ ne undef} @$ret_val;
		@$ret_val = grep {$_ ne ''} @$ret_val;
        $_ =~ s/\[\]$//; #ajax POST with arrays adds [] to the end of the name e.g. germplasmName[]. since all inputs are arrays now we can remove the [].
		$params->{$_} = $ret_val;
	}
	return $params;
}

1;
