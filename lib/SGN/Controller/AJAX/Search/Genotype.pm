
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
use CXGN::Stock::TissueSample::Search;
use utf8;
use File::Slurp qw | read_file |;
use File::Temp 'tempfile';
use File::Copy;
use File::Spec::Functions;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use DateTime;
use SGN::Model::Cvterm;

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
        genotyping_plate_list=>$clean_inputs->{genotyping_plate_list},
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

        my %identifier_hash = ();
        while (my $gt_line = <$fh>) {
            my $g = decode_json $gt_line;
            my $synonym_string = scalar(@{$g->{synonyms}})>0 ? join ',', @{$g->{synonyms}} : '';
            my $stock_id = $g->{stock_id};
            my $source_id = $g->{germplasmDbId};
            $identifier_hash{$stock_id}{sources}{$source_id}{germplasmDbId}= $g->{germplasmDbId};
            $identifier_hash{$stock_id}{sources}{$source_id}{germplasmName}= $g->{germplasmName};
            $identifier_hash{$stock_id}{stock_id} = $stock_id;
            $identifier_hash{$stock_id}{stock_name} = $g->{stock_name};
            $identifier_hash{$stock_id}{protocol_id} = $g->{analysisMethodDbId};
            $identifier_hash{$stock_id}{protocol_name} = $g->{analysisMethod};
            $identifier_hash{$stock_id}{stock_type_name} = $g->{stock_type_name};
            $identifier_hash{$stock_id}{synonym_string} = $synonym_string;
            $identifier_hash{$stock_id}{description} = $g->{genotypeDescription};
            $identifier_hash{$stock_id}{result_count} = $g->{resultCount};
            $identifier_hash{$stock_id}{igd_number} = $g->{igd_number};
            $identifier_hash{$stock_id}{genotype_id} = $g->{markerProfileDbId};
        }

        my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'accession', 'stock_type')->cvterm_id();
        my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'tissue_sample', 'stock_type')->cvterm_id();
        my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'plot', 'stock_type')->cvterm_id();
        my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'plant', 'stock_type')->cvterm_id();

        foreach my $stock_id (sort keys %identifier_hash) {
            if ($counter >= $start_index && $counter < $end_index) {
                my %source_info = ();
                my @all_sources = ();
                my $source_link;
                my $sources = $identifier_hash{$stock_id}{sources};
                %source_info = %$sources;
                my @ids = keys %source_info;
                my $number_of_sources = scalar @ids;

                if ($number_of_sources == 1) {
                    $source_link =  qq{<a href="/stock/$ids[0]/view\">$source_info{$ids[0]}{germplasmName}</a>}
                } else {
                    foreach my $source_id (sort @ids) {
                        my $name = $source_info{$source_id}{germplasmName};
                        my $stock_type_id = $bcs_schema->resultset("Stock::Stock")->find({stock_id => $source_id})->type_id();
                        my $link;
                        if ($stock_type_id == $accession_cvterm_id) {
                            $link = 'accession'.":". qq{<a href="/stock/$source_id/view\">$name</a>};
                        } elsif ($stock_type_id == $plot_cvterm_id) {
                            $link = 'plot'.":". qq{<a href="/stock/$source_id/view\">$name</a>};
                        } elsif ($stock_type_id == $plant_cvterm_id) {
                            $link = 'plant'.":". qq{<a href="/stock/$source_id/view\">$name</a>};
                        } elsif ($stock_type_id == $tissue_sample_cvterm_id) {
                            $link = 'tissue sample'.":". qq{<a href="/stock/$source_id/view\">$name</a>};
                        }
                        push @all_sources, $link;
                    }
                    $source_link = join("<br>", @all_sources);
                }
                push @result, [
                    "<a href=\"/breeders_toolbox/protocol/$identifier_hash{$stock_id}{protocol_id}\">$identifier_hash{$stock_id}{protocol_name}</a>",
                    "<a href=\"/stock/$stock_id/view\">$identifier_hash{$stock_id}{stock_name}</a>",
                    $identifier_hash{$stock_id}{stock_type_name},
                    $source_link,
                    $identifier_hash{$stock_id}{synonym_string},
                    $identifier_hash{$stock_id}{description},
                    $identifier_hash{$stock_id}{result_count},
                    $identifier_hash{$stock_id}{igd_number},
                    "<a href=\"/stock/$stock_id/genotypes?genotype_id=$identifier_hash{$stock_id}{genotype_id}\">Download</a>"
                ]
            }
            $counter++;
        }
    }

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
    my $project_id = $clean_inputs->{genotype_project_list};

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$bcs_schema,
        people_schema=>$people_schema,
        protocol_id_list=>$protocol_id,
        genotype_data_project_list=>$project_id
    });
    my $result = $genotypes_search->get_pcr_genotype_info();
    print STDERR "PCR RESULTS =".Dumper($result)."\n";
    my $protocol_marker_names = $result->{'marker_names'};
    my $ssr_genotype_data = $result->{'ssr_genotype_data'};

    my $protocol_marker_names_ref = decode_json $protocol_marker_names;
    my @marker_name_arrays = sort @$protocol_marker_names_ref;

    my @ssr_genotype_data_array = @$ssr_genotype_data;
    my @results;
    foreach my $genotype_data (@ssr_genotype_data_array) {
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
    my $ssr_genotype_data = $result->{'ssr_genotype_data'};

    my $protocol_marker_names_ref = decode_json $protocol_marker_names;
    my @marker_name_arrays = @$protocol_marker_names_ref;
    my $number_of_markers = scalar @marker_name_arrays;

    my @ssr_genotype_data_array = @$ssr_genotype_data;
    my @results;
    foreach my $genotype_info (@ssr_genotype_data_array) {
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
    my $ssr_protocol_id_list = $clean_inputs->{ssr_protocol_id};
    my $ssr_project_id_list = $clean_inputs->{ssr_project_id};
    print STDERR "SSR PROTOCOL ID =".Dumper($ssr_protocol_id_list)."\n";
    print STDERR "SSR PROJECT ID =".Dumper($ssr_project_id_list)."\n";

    my $downloaded_protocol_id;
    my $downloaded_project_id;
    if ($ssr_protocol_id_list && scalar($ssr_protocol_id_list)>0) {
        $downloaded_protocol_id = $ssr_protocol_id_list->[0];
    } elsif ($ssr_project_id_list && scalar($ssr_project_id_list)>0) {
        $downloaded_project_id = $ssr_project_id_list->[0];
    }

    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name;
    if (defined $downloaded_protocol_id) {
        $temp_file_name = "protocol".$downloaded_protocol_id . "_" . "ssr_genotype_data" . "XXXX";
    } elsif (defined $downloaded_project_id) {
        $temp_file_name = "project".$downloaded_project_id . "_" . "ssr_genotype_data" . "XXXX";
    }

    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".csv";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

#    print STDERR "TEMPFILE : $tempfile\n";

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
    my $archived_file_name = catfile($user_id, $subdirectory_name,$timestamp."_".'ssr_genotype_data'.".csv");
    my $archive_path = $c->config->{archive_path};
    my $file_destination =  catfile($archive_path, $archived_file_name);
    my $dbh = $c->dbc->dbh();

    my $genotypes = CXGN::Genotype::DownloadFactory->instantiate(
        'SSR',
        {
            bcs_schema=>$schema,
            people_schema=>$people_schema,
            protocol_id_list=>$ssr_protocol_id_list,
            genotype_data_project_list=>$ssr_project_id_list,
            filename => $tempfile,
        }
    );
    my $file_handle = $genotypes->download();
#    print STDERR "FILE HANDLE =".Dumper($file_handle)."\n";

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
#    print STDERR "FILE ID =".Dumper($file_id)."\n";
#    print STDERR "FILE DESTINATION =".Dumper($file_destination)."\n";

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
