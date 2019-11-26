package CXGN::Genotype::Download::VCF;

=head1 NAME

CXGN::Genotype::Download::VCF - an object to handle downloading genotypes in VCF format

=head1 USAGE

SHOULD BE USED VIA CXGN::Genotype::DownloadFactory

PLEASE BE AWARE THAT THE DEFAULT OPTIONS FOR genotypeprop_hash_select, protocolprop_top_key_select, protocolprop_marker_hash_select ARE PRONE TO EXCEEDING THE MEMORY LIMITS OF VM. CHECK THE MOOSE ATTRIBUTES BELOW TO SEE THE DEFAULTS, AND ADJUST YOUR MOOSE INSTANTIATION ACCORDINGLY

my $genotypes_search = CXGN::Genotype::Download::VCF->new({
    bcs_schema=>$schema,
    filename=>$filename,
    accession_list=>$accession_list,
    tissue_sample_list=>$tissue_sample_list,
    trial_list=>$trial_list,
    protocol_id_list=>$protocol_id_list,
    markerprofile_id_list=>$markerprofile_id_list,
    genotype_data_project_list=>$genotype_data_project_list,
    chromosome_list=>\@chromosome_numbers,
    start_position=>$start_position,
    end_position=>$end_position,
    marker_name_list=>['S80_265728', 'S80_265723'],
    genotypeprop_hash_select=>['DS', 'GT', 'DP'], #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
    limit=>$limit,
    offset=>$offset
});
my ($total_count, $genotypes) = $genotypes_search->get_genotype_info();

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;
use Text::CSV;
use CXGN::Genotype::Search;
use CXGN::Stock::StockLookup;
use CXGN::Tools::Run;
use DateTime;
use File::Slurp qw | write_file |;
use File::Temp qw | tempfile |;
use File::Copy;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'filename' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'protocol_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'markerprofile_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'tissue_sample_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'genotype_data_project_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'chromosome_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'start_position' => (
    isa => 'Int|Undef',
    is => 'ro',
);

has 'end_position' => (
    isa => 'Int|Undef',
    is => 'ro',
);

has 'marker_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'ro',
);

has 'genotypeprop_hash_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['GT', 'AD', 'DP', 'GQ', 'DS', 'PL', 'NT']} #THESE ARE THE GENERIC AND EXPECTED VCF ATRRIBUTES
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw',
);

sub download {
    my $self = shift;
    my $c = shift;
    my $schema = $self->bcs_schema;
    my $filename = $self->filename;
    my $trial_list = $self->trial_list;
    my $genotype_data_project_list = $self->genotype_data_project_list;
    my $protocol_id_list = $self->protocol_id_list;
    my $markerprofile_id_list = $self->markerprofile_id_list;
    my $accession_list = $self->accession_list;
    my $tissue_sample_list = $self->tissue_sample_list;
    my $marker_name_list = $self->marker_name_list;
    my $genotypeprop_hash_select = $self->genotypeprop_hash_select;
    my $limit = $self->limit;
    my $offset = $self->offset;
    my $chromosome_list = $self->chromosome_list;
    my $start_position = $self->start_position;
    my $end_position = $self->end_position;

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$schema,
        accession_list=>$accession_list,
        tissue_sample_list=>$tissue_sample_list,
        trial_list=>$trial_list,
        protocol_id_list=>$protocol_id_list,
        markerprofile_id_list=>$markerprofile_id_list,
        genotype_data_project_list=>$genotype_data_project_list,
        marker_name_list=>$marker_name_list,
        genotypeprop_hash_select=>$genotypeprop_hash_select,
        chromosome_list=>$chromosome_list,
        start_position=>$start_position,
        end_position=>$end_position,
        return_only_first_genotypeprop_for_stock=>1,
        limit=>$limit,
        offset=>$offset
    });

# Set the temp dir and temp output file
    my $tmp_output_dir = $c->config->{cluster_shared_tempdir}."/tmp_wizard_genotype_download";
    mkdir $tmp_output_dir if ! -d $tmp_output_dir;
    my ($tmp_fh, $tempfile) = tempfile(
      "wizard_download_XXXXX",
      DIR=> $tmp_output_dir,
    );
    my $tmp_genotype_filepath = $tempfile . "_genotype.txt";

    $genotypes_search->init_genotype_iterator();
    my $counter = 0;
    while(my $geno = $genotypes_search->get_next_genotype_info) {
        my $genotype_string = "";
        my $genotype_example = $geno;
        if($counter == 0) {
            $genotype_string .= "#CHROM\t";
            foreach my $key (sort keys %{$genotype_example->{selected_genotype_hash}}) {
                $genotype_string .= " \t";
            }
            $genotype_string .= "\n";
            $genotype_string .= "POS\t";
            foreach my $key (sort keys %{$genotype_example->{selected_genotype_hash}}) {
                $genotype_string .= " \t";
            }
            $genotype_string .= "\n";
            $genotype_string .= "ID\t";
            foreach my $key (sort keys %{$genotype_example->{selected_genotype_hash}}) {
                $genotype_string .= $key."\t";
            }
            $genotype_string .= "\n";
            $genotype_string .= "REF";
            foreach my $key (sort keys %{$genotype_example->{selected_genotype_hash}}) {
                $genotype_string .= "\t";
            }
            $genotype_string .= "\n";
            $genotype_string .= "ALT";
            foreach my $key (sort keys %{$genotype_example->{selected_genotype_hash}}) {
                $genotype_string .= "\t";
            }
            $genotype_string .= "\n";
            $genotype_string .= "QUAL";
            foreach my $key (sort keys %{$genotype_example->{selected_genotype_hash}}) {
                $genotype_string .= "\t";
            }
            $genotype_string .= "\n";
            $genotype_string .= "FILTER";
            foreach my $key (sort keys %{$genotype_example->{selected_genotype_hash}}) {
                $genotype_string .= "\t";
            }
            $genotype_string .= "\n";
            $genotype_string .= "FORMAT\t";
            foreach my $key (sort keys %{$genotype_example->{selected_genotype_hash}}) {
                $genotype_string .= "DS\t";
            }
            $genotype_string .= "\n";
        }
        my $genotype_id = $geno->{germplasmDbId};
        my $genotype_data_string = "";
        foreach my $key (sort keys %{$geno->{selected_genotype_hash}}) {
            my $dsvalue = $geno->{selected_genotype_hash}->{$key}->{DS};
#            my $gtvalue = $geno->{selected_genotype_hash}->{$key}->{GT};
#            my $value = $geno->{selected_genotype_hash}->{$key}->{DS};
#            my $current_genotype = $dsvalue . ":" . $gtvalue;
            my $current_genotype = $dsvalue;
            $genotype_data_string .= $current_genotype."\t";
        }
        my $s = join "\t", $genotype_id;
        $genotype_string .= $s."\t".$genotype_data_string."\n";
#		    }
        write_file($tempfile, {append => 1}, $genotype_string);
        $counter++;
    }

    my $transpose_tempfile = $tempfile . "_transpose";

    my $cmd = CXGN::Tools::Run->new(
        {
            backend => $c->config->{backend},
            submit_host => $c->config->{cluster_host},
            temp_base => $c->config->{cluster_shared_tempdir} . "/tmp_wizard_genotype_download",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            out_file => $transpose_tempfile,
#            out_file => $transpose_tempfile,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );

# Do the transposition job on the cluster
    $cmd->run_cluster(
            "perl ",
            $c->config->{basepath} . "/../gbs/transpose_matrix.pl",
            $tempfile,
    );
    $cmd->is_cluster(1);
    $cmd->wait;


    copy($transpose_tempfile, $filename);


    # my %unique_protocols;
    # my %unique_stocks;
    # my %unique_germplasm;
    # foreach (@$genotypes) {
    #     $unique_protocols{$_->{analysisMethodDbId}}++;
    #     my $sample_name;
    #     if ($_->{stock_type_name} eq 'tissue_sample') {
    #         $sample_name = $_->{stock_name}."|||".$_->{germplasmName};
    #     }
    #     elsif ($_->{stock_type_name} eq 'accession') {
    #         $sample_name = $_->{stock_name};
    #     }
    #     $unique_stocks{$sample_name} = $_->{selected_genotype_hash};
    #     $unique_germplasm{$_->{germplasmDbId}}++;
    # }
    # my @protocol_ids = keys %unique_protocols;
    # my @sorted_stock_names = sort keys %unique_stocks;
    # my $time = DateTime->now();
    # my $timestamp = $time->ymd()."_".$time->hms();
    #
    # my @all_protocol_info_lines = ("##INFO=<ID=VCFDownload, Description='VCFv4.2 FILE GENERATED BY BREEDBASE AT ".$timestamp."'>");
    # my @all_marker_objects;
    # foreach (@protocol_ids) {
    #     my $protocol = CXGN::Genotype::Protocol->new({
    #         bcs_schema => $schema,
    #         nd_protocol_id => $_,
    #         chromosome_list=>$chromosome_list,
    #         start_position=>$start_position,
    #         end_position=>$end_position
    #     });
    #     my $markers = $protocol->markers;
    #     push @all_protocol_info_lines, @{$protocol->header_information_lines};
    #     push @all_marker_objects, values %$markers;
    # }
    #
    # # OLD GENOTYPING PROTCOLS DID NOT HAVE ND_PROTOCOLPROP INFO...
    # if (scalar(@all_marker_objects) == 0) {
    #     my @representative_markerprofiles = values %unique_stocks;
    #     my $represenative_markerprofile = $representative_markerprofiles[0];
    #     foreach my $o (keys %$represenative_markerprofile) {
    #         push @all_marker_objects, {name => $o};
    #     }
    # }
    #
    # my $stocklookup = CXGN::Stock::StockLookup->new({ schema => $schema});
    # my @accession_ids = keys %unique_germplasm;
    # my $synonym_hash = $stocklookup->get_stock_synonyms('stock_id', 'accession', \@accession_ids);
    # my $synonym_string = "## Synonyms of accessions: ";
    # while( my( $uniquename, $synonym_list ) = each %{$synonym_hash}){
    #     if(scalar(@{$synonym_list})>0){
    #         if(not length($synonym_string)<1){
    #             $synonym_string.=" ";
    #         }
    #         $synonym_string.=$uniquename."=(";
    #         $synonym_string.= (join ", ", @{$synonym_list}).")";
    #     }
    # }
    # push @all_protocol_info_lines, $synonym_string;
    #
    # #VCF should be sorted by chromosome and position
    # no warnings 'uninitialized';
    # @all_marker_objects = sort { $a->{chrom} <=> $b->{chrom} || $a->{pos} <=> $b->{pos} || $a->{name} cmp $b->{name} } @all_marker_objects;
    #
    # my $tsv = Text::CSV->new({ sep_char => "\t", eol => $/ });
    # my @header = ("#CHROM", "POS", "ID", "REF", "ALT", "QUAL", "FILTER", "INFO", "FORMAT");
    # push @header, @sorted_stock_names;
    #
    # my $F;
    # open($F, ">:encoding(utf8)", $filename) || die "Can't open file $filename\n";
    #
    #     foreach (@all_protocol_info_lines) {
    #         $tsv->print($F, [$_]);
    #     }
    #
    #     $tsv->print($F, \@header);
    #
    #     foreach my $m (@all_marker_objects) {
    #         my $name = $m->{name};
    #         my $format = $m->{format};
    #         my @format;
    #         if (!$format) {
    #             my $first_g = $unique_stocks{$sorted_stock_names[0]}->{$name};
    #             foreach my $k (sort keys %$first_g) {
    #                 if (defined($first_g->{$k})) {
    #                     push @format, $k;
    #                 }
    #             }
    #         } else {
    #             @format = split ':', $format;
    #         }
    #         if (scalar(@format) > 1) { #ONLY ADD NT FOR NOT OLD GENOTYPING PROTOCOLS
    #             my %format_check = map {$_ => 1} @format;
    #             if (!exists($format_check{'NT'})) {
    #                 push @format, 'NT';
    #             }
    #             if (!exists($format_check{'DS'})) {
    #                 push @format, 'DS';
    #             }
    #         }
    #         $format = join ':', @format;
    #         my @row = ($m->{chrom}, $m->{pos}, $name, $m->{ref}, $m->{alt}, $m->{qual}, $m->{filter}, $m->{info}, $format);
    #         foreach my $s (@sorted_stock_names) {
    #             my $g = $unique_stocks{$s}->{$name};
    #             my @geno;
    #             foreach my $fr (@format) {
    #                 push @geno, $g->{$fr};
    #             }
    #             my $geno_string = join ':', @geno;
    #             push @row, $geno_string;
    #         }
    #         $tsv->print($F, \@row);
    #     }
    #
    # close($F);
}

1;
