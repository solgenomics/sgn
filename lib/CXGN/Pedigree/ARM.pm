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
use CXGN::Job;
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

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
    chomp($number_system_cores);
    print STDERR "NUMCORES $number_system_cores\n";

    my @individuals_stock_ids;
    my @all_individual_accessions_stock_ids;
    my %parent_hash;
    my %seen_female_parents;
    my %seen_male_parents;

    if ($plot_list && scalar(@$plot_list)>0) {
        print STDERR "COMPUTING ARM FROM PARENTS FOR PLOTS\n";
        my $plot_list_string = join ',', @$plot_list;
        my $q = "SELECT plot.stock_id, accession.stock_id, female_parent.stock_id, male_parent.stock_id
            FROM stock AS plot
            JOIN stock_relationship AS plot_acc_rel ON(plot_acc_rel.subject_id=plot.stock_id AND plot_acc_rel.type_id=$plot_of_cvterm_id)
            JOIN stock AS accession ON(plot_acc_rel.object_id=accession.stock_id AND accession.type_id=$accession_cvterm_id)
            LEFT JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
            LEFT JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
            LEFT JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
            LEFT JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
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
        @individuals_stock_ids = @plot_stock_ids_found;

        # print STDERR Dumper \@plot_stock_ids_found;
        # print STDERR Dumper \@plot_female_stock_ids_found;
        # print STDERR Dumper \@plot_male_stock_ids_found;

        for my $i (0..scalar(@plot_stock_ids_found)-1) {
            my $female_stock_id = $plot_female_stock_ids_found[$i];
            my $male_stock_id = $plot_male_stock_ids_found[$i];
            my $plot_stock_id = $plot_stock_ids_found[$i];

            my $val = {};
            if ($female_stock_id) {
                $seen_female_parents{$female_stock_id}++;
                $val->{female_stock_id} = $female_stock_id;
            }
            if ($male_stock_id) {
                $seen_male_parents{$male_stock_id}++;
                $val->{male_stock_id} = $male_stock_id;
            }
            $parent_hash{$plot_stock_id} = $val;
        }
    }
    elsif ($accession_list && scalar(@$accession_list)>0) {
        print STDERR "COMPUTING ARM FROM PARENTS FOR ACCESSIONS\n";
        my $accession_list_string = join ',', @$accession_list;
        my $q = "SELECT accession.stock_id, female_parent.stock_id, male_parent.stock_id
            FROM stock AS accession
            LEFT JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
            LEFT JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
            LEFT JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
            LEFT JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
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
        @individuals_stock_ids = @$accession_list;

        for my $i (0..scalar(@accession_stock_ids_found)-1) {
            my $female_stock_id = $female_stock_ids_found[$i];
            my $male_stock_id = $male_stock_ids_found[$i];
            my $accession_stock_id = $accession_stock_ids_found[$i];

            my $val = {};
            if ($female_stock_id) {
                $seen_female_parents{$female_stock_id}++;
                $val->{female_stock_id} = $female_stock_id;
            }
            if ($male_stock_id) {
                $seen_male_parents{$male_stock_id}++;
                $val->{male_stock_id} = $male_stock_id;
            }
            $parent_hash{$accession_stock_id} = $val;
        }
    }

    my @female_stock_ids = keys %seen_female_parents;
    my @male_stock_ids = keys %seen_male_parents;

    return (\%parent_hash, \@individuals_stock_ids, \@all_individual_accessions_stock_ids, \@female_stock_ids, \@male_stock_ids);
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
    my $job_record_config = shift;
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
        my ($parent_hash, $stock_ids, $all_accession_stock_ids, $female_stock_ids, $male_stock_ids) = $self->get_arm($shared_cluster_dir_config, $backend_config, $cluster_host_config, $web_cluster_queue_config, $basepath_config);

        my @grm;

        my $data = '';
        if ($download_format eq 'matrix') {
            my @header = ("stock_id");
            foreach (@$stock_ids) {
                push @header, "S".$_;
            }

            my $header_line = join "\t", @header;
            $data = "$header_line\n";

            foreach my $s (@$stock_ids) {
                my @row = ("S".$s);
                foreach my $c (@$stock_ids) {
                    my $s1_female_parent = $parent_hash->{$s}->{female_stock_id};
                    my $s1_male_parent = $parent_hash->{$s}->{male_stock_id};
                    my $s2_female_parent = $parent_hash->{$c}->{female_stock_id};
                    my $s2_male_parent = $parent_hash->{$c}->{male_stock_id};
                    my $rel = 0;
                    if ($s1_female_parent == $s2_female_parent) {
                        $rel += 1;
                    }
                    if ($s1_male_parent == $s2_male_parent) {
                        $rel += 1;
                    }
                    push @row, $rel/2;
                }
                my $line = join "\t", @row;
                $data .= "$line\n";
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
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $s1_female_parent = $parent_hash->{$s}->{female_stock_id};
                        my $s1_male_parent = $parent_hash->{$s}->{male_stock_id};
                        my $s2_female_parent = $parent_hash->{$c}->{female_stock_id};
                        my $s2_male_parent = $parent_hash->{$c}->{male_stock_id};
                        my $rel = 0;
                        if ($s1_female_parent == $s2_female_parent) {
                            $rel += 1;
                        }
                        if ($s1_male_parent == $s2_male_parent) {
                            $rel += 1;
                        }
                        $result_hash{$s}->{$c} = $rel/2;
                        $seen_stock_ids{$s}++;
                        $seen_stock_ids{$c}++;
                    }
                }
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
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $s1_female_parent = $parent_hash->{$s}->{female_stock_id};
                        my $s1_male_parent = $parent_hash->{$s}->{male_stock_id};
                        my $s2_female_parent = $parent_hash->{$c}->{female_stock_id};
                        my $s2_male_parent = $parent_hash->{$c}->{male_stock_id};
                        my $rel = 0;
                        if ($s1_female_parent == $s2_female_parent) {
                            $rel += 1;
                        }
                        if ($s1_male_parent == $s2_male_parent) {
                            $rel += 1;
                        }
                        $result_hash{$s}->{$c} = $rel/2;
                        $seen_stock_ids{$s}++;
                        $seen_stock_ids{$c}++;
                    }
                }
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
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $s1_female_parent = $parent_hash->{$s}->{female_stock_id};
                        my $s1_male_parent = $parent_hash->{$s}->{male_stock_id};
                        my $s2_female_parent = $parent_hash->{$c}->{female_stock_id};
                        my $s2_male_parent = $parent_hash->{$c}->{male_stock_id};
                        my $rel = 0;
                        if ($s1_female_parent == $s2_female_parent) {
                            $rel += 1;
                        }
                        if ($s1_male_parent == $s2_male_parent) {
                            $rel += 1;
                        }
                        $result_hash{$s}->{$c} = $rel/2;
                        $seen_stock_ids{$s}++;
                        $seen_stock_ids{$c}++;
                    }
                }
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
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $s1_female_parent = $parent_hash->{$s}->{female_stock_id};
                        my $s1_male_parent = $parent_hash->{$s}->{male_stock_id};
                        my $s2_female_parent = $parent_hash->{$c}->{female_stock_id};
                        my $s2_male_parent = $parent_hash->{$c}->{male_stock_id};
                        my $rel = 0;
                        if ($s1_female_parent == $s2_female_parent) {
                            $rel += 1;
                        }
                        if ($s1_male_parent == $s2_male_parent) {
                            $rel += 1;
                        }
                        $result_hash{$s}->{$c} = $rel/2;
                        $seen_stock_ids{$s}++;
                        $seen_stock_ids{$c}++;
                    }
                }
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
                foreach my $c (@$stock_ids) {
                    if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                        my $s1_female_parent = $parent_hash->{$s}->{female_stock_id};
                        my $s1_male_parent = $parent_hash->{$s}->{male_stock_id};
                        my $s2_female_parent = $parent_hash->{$c}->{female_stock_id};
                        my $s2_male_parent = $parent_hash->{$c}->{male_stock_id};
                        my $rel = 0;
                        if ($s1_female_parent == $s2_female_parent) {
                            $rel += 1;
                        }
                        if ($s1_male_parent == $s2_male_parent) {
                            $rel += 1;
                        }
                        $result_hash{$s}->{$c} = $rel/2;
                        $seen_stock_ids{$s}++;
                        $seen_stock_ids{$c}++;
                    }
                }
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

            open(my $heatmap_fh, '>', $arm_tempfile) or die $!;
                print $heatmap_fh $data;
            close($heatmap_fh);

            my $arm_tempfile_out = $arm_tempfile . "_plot_out";
            my $heatmap_cmd = 'R -e "library(ggplot2); library(data.table);
            mat <- fread(\''.$arm_tempfile.'\', header=FALSE, sep=\'\t\', stringsAsFactors=FALSE);
            pdf( \''.$arm_tempfile_out.'\', width = 8.5, height = 11);
            ggplot(data = mat, aes(x=V1, y=V2, fill=V3)) + geom_tile();
            dev.off();
            "';
            print STDERR Dumper $heatmap_cmd;

            my $tmp_output_dir = $shared_cluster_dir_config."/tmp_download_arm_heatmap";
            mkdir $tmp_output_dir if ! -d $tmp_output_dir;

            my $cxgn_tools_run_config =  {
                backend => $backend_config,
                submit_host => $cluster_host_config,
                temp_base => $tmp_output_dir,
                queue => $web_cluster_queue_config,
                do_cleanup => 0,
                out_file => $arm_tempfile_out,
                # don't block and wait if the cluster looks full
                max_cluster_jobs => 1_000_000_000,
            };

            my $download = CXGN::Job->new({
                schema => $self->bcs_schema,
                people_schema => $self->people_schema,
                sp_person_id => $job_record_config->{calling_user_id},
                job_type => 'download',
                name => 'ARM Download',
                cmd => $heatmap_cmd,
                finish_logfile => $job_record_config->{job_finish_log},
                cxgn_tools_run_config => $cxgn_tools_run_config
            });

            $download->submit();
            # Do the GRM on the cluster (currently not called anywhere)
            # my $plot_cmd = CXGN::Tools::Run->new(
            #    $cxgn_tools_run_config
            # );
            # $download_record->update_status("submitted");
            # $plot_cmd->run_cluster($heatmap_cmd.$download_record->generate_finish_timestamp_cmd());
            
            # $plot_cmd->is_cluster(1);
            # $plot_cmd->wait;

            while($download->alive()){
                sleep(1);
            }

            my $finished = $download->read_finish_timestamp();
            if (!$finished) {
                $download->update_status("failed");
            } else {
                $download->update_status("finished");
            }

            if ($return_type eq 'filehandle') {
                open my $out_copy, '<', $arm_tempfile_out or die "Can't open output file: $!";

                $self->cache()->set($key, '');
                my $file_handle = $self->cache()->handle($key);
                copy($out_copy, $file_handle);

                close $out_copy;
                $return = $self->cache()->handle($key);
            }
            elsif ($return_type eq 'data') {
                die "Can only return the filehandle for ARM heatmap!\n";
            }
        }
    }
    return $return;
}

1;
