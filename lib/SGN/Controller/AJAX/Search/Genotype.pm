
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

use utf8;
use File::Slurp qw | read_file |;
use File::Temp 'tempfile';
use File::Copy;
use File::Spec::Functions;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use DateTime;

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
        genotype_data_project_list=>$clean_inputs->{genotyping_data_project_id_list},
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
#                 print STDERR "PROTOCOL GENOTYPING DATA =".Dumper($g)."\n";
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
                    "<a href=\"/stock/$g->{stock_id}/genotypes?genotype_id=$g->{markerProfileDbId}\">Download</a>"
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


sub pcr_genotyping_data_search : Path('/ajax/pcr_genotyping_data/search') : ActionClass('REST') { }

sub pcr_genotyping_data_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $clean_inputs = _clean_inputs($c->req->params);
    my $protocol_id = $clean_inputs->{protocol_id_list};

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$bcs_schema,
        people_schema=>$people_schema,
        protocol_id_list=>$protocol_id,
    });
    my $result = $genotypes_search->get_pcr_genotype_info();
#    print STDERR "PCR RESULTS =".Dumper($result)."\n";
    my $protocol_marker_names = $result->{'marker_names'};
    my $protocol_genotype_data = $result->{'protocol_genotype_data'};

    my $protocol_marker_names_ref = decode_json $protocol_marker_names;
    my @marker_name_arrays = sort @$protocol_marker_names_ref;

    my @protocol_genotype_data_array = @$protocol_genotype_data;
    my @results;
    foreach my $genotype_data (@protocol_genotype_data_array) {
        my @each_genotype = ();
        my $stock_id = $genotype_data->[0];
        my $stock_name = $genotype_data->[1];
        my $stock_type = $genotype_data->[2];
        my $ploidy_level = $genotype_data->[3];
        push @each_genotype, qq{<a href="/stock/$stock_id/view">$stock_name</a>};
        push @each_genotype, ($stock_type, $ploidy_level);

        my $marker_genotype_json = $genotype_data->[6];
        my $marker_genotype_ref = decode_json $marker_genotype_json;
        my %marker_genotype_hash = %$marker_genotype_ref;
        foreach my $marker (@marker_name_arrays) {
            my @positive_bands = ();
            my $product_sizes_ref = $marker_genotype_hash{$marker};
            if (!$product_sizes_ref) {
                push @each_genotype, 'NA';
            } else {
                my %product_sizes_hash = %$product_sizes_ref;
                foreach my $product_size (keys %product_sizes_hash) {
                    my $pcr_result = $product_sizes_hash{$product_size};
                    if ($pcr_result eq '1') {
                        push @positive_bands, $product_size;
                    } elsif ($pcr_result eq '?') {
                        push @positive_bands, $pcr_result;
                    }
                }
                if (scalar @positive_bands == 0) {
                    push @positive_bands, '-';
                }
                my $pcr_result = join(",", sort @positive_bands);
                push @each_genotype, $pcr_result ;
            }
        }
        push @results, [@each_genotype];
    }
#    print STDERR "RESULTS =".Dumper(\@results)."\n";
    $c->stash->{rest} = { data => \@results};
}


sub pcr_genotyping_data_summary_search : Path('/ajax/pcr_genotyping_data_summary/search') : ActionClass('REST') { }

sub pcr_genotyping_data_summary_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $clean_inputs = _clean_inputs($c->req->params);
    my $protocol_id = $clean_inputs->{protocol_id_list};

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$bcs_schema,
        people_schema=>$people_schema,
        protocol_id_list=>$protocol_id,
    });
    my $result = $genotypes_search->get_pcr_genotype_info();
#    print STDERR "PCR RESULTS =".Dumper($result)."\n";
    my $protocol_marker_names = $result->{'marker_names'};
    my $protocol_genotype_data = $result->{'protocol_genotype_data'};

    my $protocol_marker_names_ref = decode_json $protocol_marker_names;
    my @marker_name_arrays = @$protocol_marker_names_ref;
    my $number_of_markers = scalar @marker_name_arrays;

    my @protocol_genotype_data_array = @$protocol_genotype_data;
    my @results;
    foreach my $genotype_info (@protocol_genotype_data_array) {
        push @results, {
            stock_id => $genotype_info->[0],
            stock_name => $genotype_info->[1],
            stock_type => $genotype_info->[2],
            genotype_description => $genotype_info->[3],
            genotype_id => $genotype_info->[4],
            number_of_markers => $number_of_markers,
        };
    }
#    print STDERR "RESULTS =".Dumper(\@results)."\n";
    $c->stash->{rest} = { data => \@results};
}


sub pcr_genotyping_data_download : Path('/ajax/pcr_genotyping_data/download') : ActionClass('REST') { }

sub pcr_genotyping_data_download_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $clean_inputs = _clean_inputs($c->req->params);
    my $ssr_protocol_id = $clean_inputs->{ssr_protocol_id};
    my $downloaded_protocol_id = $ssr_protocol_id->[0];
    print STDERR "PROTOCOL ID = $downloaded_protocol_id\n";

    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = $downloaded_protocol_id . "_" . "genotype_data" . "XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".csv";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    print STDERR "TEMPFILE : $tempfile\n";

    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to download genotype data" };
        return;
    }
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory_name = "ssr_download";
    my $archived_file_name = catfile($user_id, $subdirectory_name,$timestamp."_".'genotype_data'.".csv");
    my $archive_path = $c->config->{archive_path};
    my $file_destination =  catfile($archive_path, $archived_file_name);
    my $dbh = $c->dbc->dbh();

    my $genotypes = CXGN::Genotype::DownloadFactory->instantiate(
        'SSR',
        {
            bcs_schema=>$schema,
            people_schema=>$people_schema,
            protocol_id_list=>$ssr_protocol_id,
            filename => $tempfile,
        }
    );
    my $file_handle = $genotypes->download();
    print STDERR "FILE HANDLE =".Dumper($file_handle)."\n";

    open(my $F, "<", $tempfile) || die "Can't open file ".$self->tempfile();
    binmode $F;
    my $md5 = Digest::MD5->new();
    $md5->addfile($F);
    close($F);

    if (!-d $archive_path) {
        mkdir $archive_path;
    }

    if (! -d catfile($archive_path, $user_id)) {
        mkdir (catfile($archive_path, $user_id));
    }

    if (! -d catfile($archive_path, $user_id,$subdirectory_name)) {
        mkdir (catfile($archive_path, $user_id, $subdirectory_name));
    }

    my $md_row = $metadata_schema->resultset("MdMetadata")->create({
        create_person_id => $user_id,
    });
    $md_row->insert();

    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($file_destination),
        dirname => dirname($file_destination),
        filetype => 'ssr_genotype_data_csv',
        md5checksum => $md5->hexdigest(),
        metadata_id => $md_row->metadata_id(),
    });
    $file_row->insert();

    my $file_id = $file_row->file_id();
    print STDERR "FILE ID =".Dumper($file_id)."\n";
    print STDERR "FILE DESTINATION =".Dumper($file_destination)."\n";

    move($tempfile,$file_destination);
    unlink $tempfile;

    my $result = $file_row->file_id;

#    print STDERR "FILE =".Dumper($file_destination)."\n";
#    print STDERR "FILE ID =".Dumper($file_id)."\n";

    $c->stash->{rest} = {
        success => 1,
        result => $result,
        file => $file_destination,
        file_id => $file_id,
    };

}




1;
