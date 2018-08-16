
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
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub genotyping_data_search : Path('/ajax/genotyping_data/search') : ActionClass('REST') { }

sub genotyping_data_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $clean_inputs = _clean_inputs($c->req->params);

    my $limit = $c->req->param('length');
    my $offset = $c->req->param('start');

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$bcs_schema,
        accession_list=>$clean_inputs->{accession_id_list},
        tissue_sample_list=>$clean_inputs->{tissue_sample_id_list},
        trial_list=>$clean_inputs->{genotyping_data_project_id_list},
        protocol_id_list=>$clean_inputs->{protocol_id_list},
        #marker_name_list=>['S80_265728', 'S80_265723']
        #marker_search_hash_list=>[{'S80_265728' => {'pos' => '265728', 'chrom' => '1'}}],
        #marker_score_search_hash_list=>[{'S80_265728' => {'GT' => '0/0', 'GQ' => '99'}}],
        limit => $limit,
        offset => $offset
    });
    my ($total_count, $data) = $genotypes_search->get_genotype_info();

    my @result;
    foreach (@$data){
        my $synonym_string = scalar(@{$_->{synonyms}})>0 ? join ',', @{$_->{synonyms}} : '';
        push @result,
          [
            "<a href=\"/breeders_toolbox/protocol/$_->{analysisMethodDbId}\">$_->{analysisMethod}</a>",
            "<a href=\"/stock/$_->{stock_id}/view\">$_->{stock_name}</a>",
            $_->{stock_type_name},
            "<a href=\"/stock/$_->{germplasmDbId}/view\">$_->{germplasmName}</a>",
            $synonym_string,
            $_->{genotypeDescription},
            $_->{resultCount},
            $_->{igd_number},
            "<a href=\"/stock/$_->{stock_id}/genotypes?genotypeprop_id=$_->{markerProfileDbId}\">Download</a>"
          ];
    }
    #print STDERR Dumper \@result;

    my $draw = $c->req->param('draw');
    if ($draw){
        $draw =~ s/\D//g; # cast to int
    }

    $c->stash->{rest} = { data => \@result, draw => $draw, recordsTotal => $total_count,  recordsFiltered => $total_count };
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
