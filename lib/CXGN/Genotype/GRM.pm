package CXGN::Genotype::GRM;

=head1 NAME

CXGN::Genotype::GRM - an object to handle fetching a GRM for stocks

=head1 USAGE

my $geno = CXGN::Genotype::GRM->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    accession_id_list=>\@accession_list,
    plot_id_list=>\@plot_id_list,
    protocol_id=>$protocol_id,
    get_grm_for_parental_accessions=>1,
    cache_root=>$cache_root
});
my $grm = $geno->get_grm();

OR

$geno->download_grm($filename);

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
use R::YapRI::Base;
use R::YapRI::Data::Matrix;
use CXGN::Dataset::Cache;
use Cache::File;
use Digest::MD5 qw | md5_hex |;

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

has 'protocol_id' => (
    isa => 'Int',
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

# If the accessions in the plots you are interested have not been genotyped (as in hybrids), can get this boolean to 1 and give a list of plot_id_list and you will get back a GRM built from the parent accessions for those plots (for the plots whose parents were genotyped)
has 'get_grm_for_parental_accessions' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
);

has 'genotypeprop_hash_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['DS']} #THESE ARE THE GENERIC AND EXPECTED VCF ATRRIBUTES. For dosage matrix we only need DS
);

has 'protocolprop_top_key_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['markers']} #THESE ARE ALL POSSIBLE TOP LEVEL KEYS IN PROTOCOLPROP BASED ON VCF LOADING. For dosage matrix we only need markers
);

has 'protocolprop_marker_hash_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['name']} #THESE ARE ALL POSSIBLE PROTOCOLPROP MARKER HASH KEYS BASED ON VCF LOADING. For dosage matrix we only need name
);

has 'return_only_first_genotypeprop_for_stock' => (
    isa => 'Bool',
    is => 'ro',
    default => 1
);

sub get_grm {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $people_schema = $self->people_schema();
    my $cache_root_dir = $self->cache_root();
    my $accession_list = $self->accession_id_list();
    my $plot_list = $self->plot_id_list();
    my $protocol_id = $self->protocol_id();
    my $get_grm_for_parental_accessions = $self->get_grm_for_parental_accessions();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my @individuals_stock_ids;
    my @all_marker_names;
    my @dosage_matrix;

    # In this case a list of accessions is given, so get a GRM between these accessions
    if ($accession_list && scalar(@$accession_list)>0){
        my %unique_marker_names = ();
        foreach (@$accession_list) {
            my $dataset = CXGN::Dataset::Cache->new({
                people_schema=>$people_schema,
                schema=>$schema,
                cache_root=>$cache_root_dir,
                accessions=>[$_]
            });
            my $genotypes = $dataset->retrieve_genotypes($protocol_id, ['DS'], ['markers'], ['name'], 1);

            if (scalar(@$genotypes)>0) {
                my $p1_markers = $genotypes->[0]->{selected_protocol_hash}->{markers};
                my @all_marker_objects = values %$p1_markers;
                
                foreach my $m (@all_marker_objects) {
                    my $name = $m->{name};
                    $unique_marker_names{$name}++;
                }
                @all_marker_names = keys %unique_marker_names;
                undef @all_marker_objects;

                foreach my $p (0..scalar(@$genotypes)-1) {
                    my @row;
                    foreach my $m (@all_marker_names) {
                        push @row, $genotypes->[$p]->{selected_genotype_hash}->{$m}->{DS};
                    }
                    push @dosage_matrix, @row;
                    push @individuals_stock_ids, $genotypes->[$p]->{stock_id};
                    undef $genotypes->[$p];
                }
                undef $genotypes;
            }
        }
        @all_marker_names = keys %unique_marker_names;
    }
    # IN this case of a hybrid evaluation where the parents of the accessions planted in a plot are genotyped
    elsif ($get_grm_for_parental_accessions && scalar(@$plot_list)>0) {
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

        # print STDERR Dumper \@plot_stock_ids_found;
        # print STDERR Dumper \@plot_female_stock_ids_found;
        # print STDERR Dumper \@plot_male_stock_ids_found;

        my @progeny_genotypes = ();
        my @all_marker_objects = ();
        my %unique_marker_names = ();
        for my $i (0..scalar(@plot_stock_ids_found)-1) {
            my $female_stock_id = $plot_female_stock_ids_found[$i];
            my $male_stock_id = $plot_male_stock_ids_found[$i];
            my $plot_stock_id = $plot_stock_ids_found[$i];

            my $dataset = CXGN::Dataset::Cache->new({
                people_schema=>$people_schema,
                schema=>$schema,
                cache_root=>$cache_root_dir,
                accessions=>[$female_stock_id, $male_stock_id]
            });
            my $genotypes = $dataset->retrieve_genotypes($protocol_id, ['DS'], ['markers'], ['name'], 1);

            my %progeny_genotype;
            # If both parents are genotyped, calculate progeny genotype as a average of parent dosage
            if ($genotypes->[0] && $genotypes->[1]) {
                my $parent1_genotype = $genotypes->[0]->{selected_genotype_hash};
                my $parent1_markers = $genotypes->[0]->{selected_protocol_hash}->{markers};
                my $parent2_genotype = $genotypes->[1]->{selected_genotype_hash};
                foreach my $marker (keys %$parent1_genotype) {
                    $progeny_genotype{$marker} = ($parent1_genotype->{$marker}->{DS} + $parent2_genotype->{$marker}->{DS}) / 2;
                }
                push @all_marker_objects, values %$parent1_markers;
            }
            # elsif ($genotypes->[0]) {
            #     my $parent1_genotype = $genotypes->[0]->{selected_genotype_hash};
            #     foreach my $marker (keys %$parent1_genotype) {
            #         $progeny_genotype{$marker} = $parent1_genotype->{$marker}->{DS};
            #     }
            # }
            if (scalar(keys %progeny_genotype)>0) {
                push @individuals_stock_ids, $plot_stock_id;
                push @progeny_genotypes, \%progeny_genotype;
            }
        }

        foreach my $m (@all_marker_objects) {
            my $name = $m->{name};
            $unique_marker_names{$name}++;
        }
        @all_marker_names = keys %unique_marker_names;
        undef %unique_marker_names;
        undef @all_marker_objects;

        foreach my $p (0..scalar(@individuals_stock_ids)-1) {
            my @row;
            foreach my $m (@all_marker_names) {
                push @row, $progeny_genotypes[$p]->{$m};
            }
            push @dosage_matrix, @row;
            undef $progeny_genotypes[$p];
        }
        undef @progeny_genotypes;
    }

    # print STDERR Dumper \@all_marker_names;
    # print STDERR Dumper \@individuals_stock_ids;
    # print STDERR Dumper \@dosage_matrix;

    my $grm_n = scalar(@individuals_stock_ids);
    my $rmatrix = R::YapRI::Data::Matrix->new({
        name => 'geno_matrix1',
        coln => scalar(@all_marker_names),
        rown => $grm_n,
        colnames => \@all_marker_names,
        data => \@dosage_matrix
    });

    my $rbase = R::YapRI::Base->new();
    my $r_block = $rbase->create_block('r_block');
    $rmatrix->send_rbase($rbase, 'r_block');
    # $r_block->add_command('geno_data = data.frame(geno_matrix1)');
    $r_block->add_command('geno_matrix1 <- scale(geno_matrix1, scale = FALSE)');
    $r_block->add_command('alfreq <- attributes(geno_matrix1)[["scaled:center"]]/2');
    $r_block->add_command('grm <- tcrossprod(geno_matrix1)/((2*crossprod(alfreq, 1-alfreq))[[1]])');
    $r_block->run_block();
    my $result_matrix = R::YapRI::Data::Matrix->read_rbase($rbase,'r_block','grm');
    undef @dosage_matrix;

    my @grm;
    my $count = 0;
    for my $i (1..$grm_n) {
        my @row;
        for my $j (1..$grm_n) {
            push @row, $result_matrix->{data}->[$count];
            $count++;
        }
        push @grm, \@row;
    }
    undef $result_matrix;
    return (\@grm, \@all_marker_names, \@individuals_stock_ids);
}

sub grm_cache_key {
    my $self = shift;
    my $datatype = shift;

    #print STDERR Dumper($self->_get_dataref());
    my $json = JSON->new();
    #preserve order of hash keys to get same text
    $json = $json->canonical();
    my $accessions = $json->encode( $self->accession_id_list() || [] );
    my $plots = $json->encode( $self->plot_id_list() || [] );
    my $protocol = $self->protocol_id() || '';
    my $genotypeprophash = $json->encode( $self->genotypeprop_hash_select() || [] );
    my $protocolprophash = $json->encode( $self->protocolprop_top_key_select() || [] );
    my $protocolpropmarkerhash = $json->encode( $self->protocolprop_marker_hash_select() || [] );
    my $key = md5_hex($accessions.$plots.$protocol.$genotypeprophash.$protocolprophash.$protocolpropmarkerhash.$self->get_grm_for_parental_accessions().$self->return_only_first_genotypeprop_for_stock()."_$datatype");
    return $key;
}

sub download_grm {
    my $self = shift;
    my $return_type = shift || 'filehandle';

    my $key = $self->grm_cache_key("download_grm");
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
        my ($result_matrix, $marker_names, $stock_ids) = $self->get_grm();

        my @header = ("stock_id");
        push @header, @$stock_ids;

        my $header_line = join "\t", @header;
        my $data = "$header_line\n";

        my $row_num = 0;
        foreach my $s (@$stock_ids) {
            my @row = ($s);
            my $col_num = 0;
            foreach my $c (@$stock_ids) {
                push @row, $result_matrix->[$row_num]->[$col_num];
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
    return $return;
}

1;
