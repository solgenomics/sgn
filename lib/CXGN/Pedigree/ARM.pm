package CXGN::Pedigree::ARM;

=head1 NAME

CXGN::Genotype::GRM - an object to handle fetching an additive relationship matrix (ARM) from pedigrees for stocks

=head1 USAGE

my $pedigree_arm = CXGN::Pedigree::ARM->new({
    bcs_schema=>$schema,
    arm_temp_file=>$file_temp_path,
    people_schema=>$people_schema,
    accession_id_list=>\@accession_list,
    plot_id_list=>\@plot_id_list,
    cache_root=>$cache_root,
    download_format=>'matrix', #either 'matrix', 'three_column', or 'heatmap'
});
RECOMMENDED
$pedigree_arm->download_arm();

OR

my $arm = $pedigree_arm->get_arm();

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use JSON;
use CXGN::Stock::Accession;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::Search;
use CXGN::Genotype::ComputeHybridGenotype;
use R::YapRI::Base;
use R::YapRI::Data::Matrix;
use CXGN::Dataset::Cache;
use Cache::File;
use Digest::MD5 qw | md5_hex |;
use File::Slurp qw | write_file |;
use POSIX;
use File::Copy;
use CXGN::Tools::Run;
use File::Temp 'tempfile';

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
    is => 'rw',
    required => 1
);

# Uses a cached file system for getting genotype results and getting GRM
has 'cache_root' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'download_format' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'cache' => (
    isa => 'Cache::File',
    is => 'rw',
);

has 'cache_expiry' => (
    isa => 'Int',
    is => 'rw',
    default => 0, # never expires?
);

has '_cache_key' => (
    isa => 'Str',
    is => 'rw',
);

has 'arm_temp_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'accession_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'plot_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

sub get_arm {
    my $self = shift;
    my $shared_cluster_dir_config = shift;
    my $backend_config = shift;
    my $cluster_host_config = shift;
    my $web_cluster_queue_config = shift;
    my $basepath_config = shift;
    my $schema = $self->bcs_schema();
    my $people_schema = $self->people_schema();
    my $cache_root_dir = $self->cache_root();
    my $accession_list = $self->accession_id_list();
    my $plot_list = $self->plot_id_list();
    my $arm_tempfile = $self->arm_temp_file();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
    chomp($number_system_cores);
    print STDERR "NUMCORES $number_system_cores\n";

    my $tmp_output_dir = $shared_cluster_dir_config."/tmp_pedigree_download_arm";
    mkdir $tmp_output_dir if ! -d $tmp_output_dir;
    my ($arm_tempfile_out_fh, $arm_tempfile_out) = tempfile("download_arm_out_XXXXX", DIR=> $tmp_output_dir);
    my ($temp_out_file_fh, $temp_out_file) = tempfile("download_arm_tmp_XXXXX", DIR=> $tmp_output_dir);

    my @individuals_stock_ids;
    my @all_individual_accessions_stock_ids;

    if ($plot_list && scalar(@$plot_list)>0) {
        print STDERR "COMPUTING ARM FROM PARENTS FOR PLOTS\n";
        my $plot_list_string = join ',', @$plot_list;
        my $q = "SELECT plot.stock_id, accession.stock_id, female_parent.stock_id, male_parent.stock_id
            FROM stock AS plot
            JOIN stock_relationship AS plot_acc_rel ON(plot_acc_rel.subject_id=plot.stock_id AND plot_acc_rel.type_id=$plot_of_cvterm_id)
            JOIN stock AS accession ON(plot_acc_rel.object_id=accession.stock_id AND accession.type_id=$accession_cvterm_id)
            JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
            JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
            JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
            JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
            WHERE plot.type_id=$plot_cvterm_id AND plot.stock_id IN ($plot_list_string);";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute();
        my @plot_stock_ids_found = ();
        my @plot_accession_stock_ids_found = ();
        my @plot_female_stock_ids_found = ();
        my @plot_male_stock_ids_found = ();
        while (my ($plot_stock_id, $accession_stock_id, $female_parent_stock_id, $male_parent_stock_id) = $h->fetchrow_array()) {
            push @plot_stock_ids_found, $plot_stock_id;
            push @plot_accession_stock_ids_found, $accession_stock_id;
            push @plot_female_stock_ids_found, $female_parent_stock_id;
            push @plot_male_stock_ids_found, $male_parent_stock_id;
        }

        @all_individual_accessions_stock_ids = @plot_accession_stock_ids_found;

        # print STDERR Dumper \@plot_stock_ids_found;
        # print STDERR Dumper \@plot_female_stock_ids_found;
        # print STDERR Dumper \@plot_male_stock_ids_found;

        for my $i (0..scalar(@plot_stock_ids_found)-1) {
            my $female_stock_id = $plot_female_stock_ids_found[$i];
            my $male_stock_id = $plot_male_stock_ids_found[$i];
            my $plot_stock_id = $plot_stock_ids_found[$i];

            my $genotype_string = "";
            my $geno = CXGN::Genotype::ComputeHybridGenotype->new({
                parental_genotypes=>$genotypes,
                marker_objects=>\@all_marker_objects
            });
            my $progeny_genotype = $geno->get_hybrid_genotype();

            push @individuals_stock_ids, $plot_stock_id;
            my $genotype_string_scores = join "\t", @$progeny_genotype;
            $genotype_string .= $genotype_string_scores . "\n";
            write_file($grm_tempfile, {append => 1}, $genotype_string);
            undef $progeny_genotype;
        }
    }
    elsif ($accession_list && scalar(@$accession_list)>0) {
        print STDERR "COMPUTING ARM FROM PARENTS FOR ACCESSIONS\n";
        my $accession_list_string = join ',', @$accession_list;
        my $q = "SELECT accession.stock_id, female_parent.stock_id, male_parent.stock_id
            FROM stock AS accession
            JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
            JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
            JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
            JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
            WHERE accession.type_id=$accession_cvterm_id AND accession.stock_id IN ($accession_list_string);";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute();
        my @accession_stock_ids_found = ();
        my @female_stock_ids_found = ();
        my @male_stock_ids_found = ();
        while (my ($accession_stock_id, $female_parent_stock_id, $male_parent_stock_id) = $h->fetchrow_array()) {
            push @accession_stock_ids_found, $accession_stock_id;
            push @female_stock_ids_found, $female_parent_stock_id;
            push @male_stock_ids_found, $male_parent_stock_id;
        }

        # print STDERR Dumper \@accession_stock_ids_found;
        # print STDERR Dumper \@female_stock_ids_found;
        # print STDERR Dumper \@male_stock_ids_found;

        @all_individual_accessions_stock_ids = @$accession_list;

        for my $i (0..scalar(@accession_stock_ids_found)-1) {
            my $female_stock_id = $female_stock_ids_found[$i];
            my $male_stock_id = $male_stock_ids_found[$i];
            my $accession_stock_id = $accession_stock_ids_found[$i];

            my $genotype_string = "";
            my $geno = CXGN::Genotype::ComputeHybridGenotype->new({
                parental_genotypes=>$genotypes,
                marker_objects=>\@all_marker_objects
            });
            my $progeny_genotype = $geno->get_hybrid_genotype();

            push @individuals_stock_ids, $accession_stock_id;
            my $genotype_string_scores = join "\t", @$progeny_genotype;
            $genotype_string .= $genotype_string_scores . "\n";
            write_file($grm_tempfile, {append => 1}, $genotype_string);
            undef $progeny_genotype;
        }
    }

    # print STDERR Dumper \@all_marker_names;
    # print STDERR Dumper \@individuals_stock_ids;
    # print STDERR Dumper \@dosage_matrix;

    #$cmd .= 'write.table(A, file=\''.$grm_tempfile_out.'\', row.names=FALSE, col.names=FALSE, sep=\'\t\');"';
    #print STDERR Dumper $cmd;

    return ($arm_tempfile_out, \@individuals_stock_ids, \@all_individual_accessions_stock_ids);
}

sub arm_cache_key {
    my $self = shift;
    my $datatype = shift;

    #print STDERR Dumper($self->_get_dataref());
    my $json = JSON->new();
    #preserve order of hash keys to get same text
    $json = $json->canonical();
    my $sorted_accession_list = $self->accession_id_list() || [];
    my @sorted_accession_list = sort @$sorted_accession_list;
    my $accessions = $json->encode( \@sorted_accession_list );
    my $plots = $json->encode( $self->plot_id_list() || [] );
    my $key = md5_hex($accessions.$plots."_$datatype");
    return $key;
}

sub download_arm {
    my $self = shift;
    my $return_type = shift || 'filehandle';
    my $shared_cluster_dir_config = shift;
    my $backend_config = shift;
    my $cluster_host_config = shift;
    my $web_cluster_queue_config = shift;
    my $basepath_config = shift;
    my $download_format = $self->download_format();
    my $arm_tempfile = $self->arm_temp_file();

    my $key = $self->arm_cache_key("download_arm_v01".$download_format);
    $self->_cache_key($key);
    $self->cache( Cache::File->new( cache_root => $self->cache_root() ));

    my $return;
    if ($self->cache()->exists($key)) {
        if ($return_type eq 'filehandle') {
            $return = $self->cache()->handle($key);
        }
        elsif ($return_type eq 'data') {
            $return = $self->cache()->get($key);
        }
    }
    else {
        my ($arm_tempfile_out, $stock_ids, $all_accession_stock_ids) = $self->get_arm($shared_cluster_dir_config, $backend_config, $cluster_host_config, $web_cluster_queue_config, $basepath_config);

        my @grm;
        open(my $fh, "<", $arm_tempfile_out) or die "Can't open < $arm_tempfile_out: $!";
        while (my $row = <$fh>) {
            chomp($row);
            my @vals = split "\t", $row;
            push @grm, \@vals;
        }

        my $data = '';
        if ($download_format eq 'matrix') {
            my @header = ("stock_id");
            foreach (@$stock_ids) {
                push @header, "S".$_;
            }

            my $header_line = join "\t", @header;
            $data = "$header_line\n";

            my $row_num = 0;
            foreach my $s (@$stock_ids) {
                my @row = ("S".$s);
                my $col_num = 0;
                foreach my $c (@$stock_ids) {
                    push @row, $grm[$row_num]->[$col_num];
                    $col_num++;
                }
                my $line = join "\t", @row;
                $data .= "$line\n";
                $row_num++;
            }

            $self->cache()->set($key, $data);
            if ($return_type eq 'filehandle') {
                $return = $self->cache()->handle($key);
            }
            elsif ($return_type eq 'data') {
                $return = $data;
            }
        }
        elsif ($download_format eq 'three_column') {
            my %result_hash;
            my $row_num = 0;
            my %seen_stock_ids;
            # print STDERR Dumper \@grm;
            foreach my $s (@$stock_ids) {
                my $col_num = 0;
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $val = $grm[$row_num]->[$col_num];
                        if (defined $val and length $val) {
                            $result_hash{$s}->{$c} = $val;
                            $seen_stock_ids{$s}++;
                            $seen_stock_ids{$c}++;
                        }
                    }
                    $col_num++;
                }
                $row_num++;
            }

            foreach my $r (sort keys %result_hash) {
                foreach my $s (sort keys %{$result_hash{$r}}) {
                    my $val = $result_hash{$r}->{$s};
                    if (defined $val and length $val) {
                        $data .= "S$r\tS$s\t$val\n";
                    }
                }
            }

            foreach my $a (@$all_accession_stock_ids) {
                if (!exists($seen_stock_ids{$a})) {
                    $data .= "S$a\tS$a\t1\n";
                }
            }

            $self->cache()->set($key, $data);
            if ($return_type eq 'filehandle') {
                $return = $self->cache()->handle($key);
            }
            elsif ($return_type eq 'data') {
                $return = $data;
            }
        }
        elsif ($download_format eq 'three_column_stock_id_integer') {
            my %result_hash;
            my $row_num = 0;
            my %seen_stock_ids;
            foreach my $s (@$stock_ids) {
                my $col_num = 0;
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $val = $grm[$row_num]->[$col_num];
                        if (defined $val and length $val) {
                            $result_hash{$s}->{$c} = $val;
                            $seen_stock_ids{$s}++;
                            $seen_stock_ids{$c}++;
                        }
                    }
                    $col_num++;
                }
                $row_num++;
            }

            foreach my $r (sort keys %result_hash) {
                foreach my $s (sort keys %{$result_hash{$r}}) {
                    my $val = $result_hash{$r}->{$s};
                    if (defined $val and length $val) {
                        $data .= "$r\t$s\t$val\n";
                    }
                }
            }

            foreach my $a (@$all_accession_stock_ids) {
                if (!exists($seen_stock_ids{$a})) {
                    $data .= "$a\t$a\t1\n";
                }
            }

            $self->cache()->set($key, $data);
            if ($return_type eq 'filehandle') {
                $return = $self->cache()->handle($key);
            }
            elsif ($return_type eq 'data') {
                $return = $data;
            }
        }
        elsif ($download_format eq 'three_column_reciprocal') {
            my %result_hash;
            my $row_num = 0;
            my %seen_stock_ids;
            # print STDERR Dumper \@grm;
            foreach my $s (@$stock_ids) {
                my $col_num = 0;
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $val = $grm[$row_num]->[$col_num];
                        if (defined $val and length $val) {
                            $result_hash{$s}->{$c} = $val;
                            $seen_stock_ids{$s}++;
                            $seen_stock_ids{$c}++;
                        }
                    }
                    $col_num++;
                }
                $row_num++;
            }

            foreach my $r (sort keys %result_hash) {
                foreach my $s (sort keys %{$result_hash{$r}}) {
                    my $val = $result_hash{$r}->{$s};
                    if (defined $val and length $val) {
                        $data .= "S$r\tS$s\t$val\n";
                        if ($s != $r) {
                            $data .= "S$s\tS$r\t$val\n";
                        }
                    }
                }
            }

            foreach my $a (@$all_accession_stock_ids) {
                if (!exists($seen_stock_ids{$a})) {
                    $data .= "S$a\tS$a\t1\n";
                }
            }

            $self->cache()->set($key, $data);
            if ($return_type eq 'filehandle') {
                $return = $self->cache()->handle($key);
            }
            elsif ($return_type eq 'data') {
                $return = $data;
            }
        }
        elsif ($download_format eq 'three_column_reciprocal_stock_id_integer') {
            my %result_hash;
            my $row_num = 0;
            my %seen_stock_ids;
            # print STDERR Dumper \@grm;
            foreach my $s (@$stock_ids) {
                my $col_num = 0;
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $val = $grm[$row_num]->[$col_num];
                        if (defined $val and length $val) {
                            $result_hash{$s}->{$c} = $val;
                            $seen_stock_ids{$s}++;
                            $seen_stock_ids{$c}++;
                        }
                    }
                    $col_num++;
                }
                $row_num++;
            }

            foreach my $r (sort keys %result_hash) {
                foreach my $s (sort keys %{$result_hash{$r}}) {
                    my $val = $result_hash{$r}->{$s};
                    if (defined $val and length $val) {
                        $data .= "$r\t$s\t$val\n";
                        if ($s != $r) {
                            $data .= "$s\t$r\t$val\n";
                        }
                    }
                }
            }

            foreach my $a (@$all_accession_stock_ids) {
                if (!exists($seen_stock_ids{$a})) {
                    $data .= "$a\t$a\t1\n";
                }
            }

            $self->cache()->set($key, $data);
            if ($return_type eq 'filehandle') {
                $return = $self->cache()->handle($key);
            }
            elsif ($return_type eq 'data') {
                $return = $data;
            }
        }
        elsif ($download_format eq 'heatmap') {
            my %result_hash;
            my $row_num = 0;
            my %seen_stock_ids;
            foreach my $s (@$stock_ids) {
                my @row = ($s);
                my $col_num = 0;
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $val = $grm[$row_num]->[$col_num];
                        if ($val || $val == 0) {
                            $result_hash{$s}->{$c} = $val;
                            $seen_stock_ids{$s}++;
                            $seen_stock_ids{$c}++;
                        }
                    }
                    $col_num++;
                }
                $row_num++;
            }

            foreach my $r (sort keys %result_hash) {
                foreach my $s (sort keys %{$result_hash{$r}}) {
                    my $val = $result_hash{$r}->{$s};
                    $data .= "$r\t$s\t$val\n";
                }
            }

            foreach my $a (@$all_accession_stock_ids) {
                if (!exists($seen_stock_ids{$a})) {
                    $data .= "$a\t$a\t1\n";
                }
            }

            open(my $heatmap_fh, '>', $grm_tempfile) or die $!;
                print $heatmap_fh $data;
            close($heatmap_fh);

            my $grm_tempfile_out = $grm_tempfile . "_plot_out";
            my $heatmap_cmd = 'R -e "library(ggplot2); library(data.table);
            mat <- fread(\''.$grm_tempfile.'\', header=FALSE, sep=\'\t\', stringsAsFactors=FALSE);
            pdf( \''.$grm_tempfile_out.'\', width = 8.5, height = 11);
            ggplot(data = mat, aes(x=V1, y=V2, fill=V3)) + geom_tile();
            dev.off();
            "';
            print STDERR Dumper $heatmap_cmd;

            my $tmp_output_dir = $shared_cluster_dir_config."/tmp_genotype_download_grm_heatmap";
            mkdir $tmp_output_dir if ! -d $tmp_output_dir;

            # Do the GRM on the cluster
            my $plot_cmd = CXGN::Tools::Run->new(
                {
                    backend => $backend_config,
                    submit_host => $cluster_host_config,
                    temp_base => $tmp_output_dir,
                    queue => $web_cluster_queue_config,
                    do_cleanup => 0,
                    out_file => $grm_tempfile_out,
                    # don't block and wait if the cluster looks full
                    max_cluster_jobs => 1_000_000_000,
                }
            );

            $plot_cmd->run_cluster($heatmap_cmd);
            $plot_cmd->is_cluster(1);
            $plot_cmd->wait;

            if ($return_type eq 'filehandle') {
                open my $out_copy, '<', $grm_tempfile_out or die "Can't open output file: $!";

                $self->cache()->set($key, '');
                my $file_handle = $self->cache()->handle($key);
                copy($out_copy, $file_handle);

                close $out_copy;
                $return = $self->cache()->handle($key);
            }
            elsif ($return_type eq 'data') {
                die "Can only return the filehandle for GRM heatmap!\n";
            }
        }
    }
    return $return;
}

1;
