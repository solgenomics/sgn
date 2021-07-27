package CXGN::Genotype::GWAS;

=head1 NAME

CXGN::Genotype::GWAS - an object to handle GWAS

=head1 USAGE

my $geno = CXGN::Genotype::GWAS->new({
    bcs_schema=>$schema,
    grm_temp_file=>$file_temp_path,
    gwas_temp_file=>$file_temp_path_gwas,
    pheno_temp_file=>$file_temp_path_pheno,
    people_schema=>$people_schema,
    download_format=>$download_format, #either 'results_tsv' or 'manhattan_qq_plots'
    accession_id_list=>\@accession_list,
    trait_id_list=>\@trait_id_list,
    traits_are_repeated_measurements=>$traits_are_repeated_measurements,
    protocol_id=>$protocol_id,
    get_grm_for_parental_accessions=>1,
    cache_root=>$cache_root,
    minor_allele_frequency=>0.01,
    marker_filter=>0.6,
    individuals_filter=>0.8
});
$geno->download_gwas();

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
use CXGN::Phenotypes::SearchFactory;
use CXGN::Page;
use R::YapRI::Base;
use R::YapRI::Data::Matrix;
use CXGN::Dataset::Cache;
use Cache::File;
use Digest::MD5 qw | md5_hex |;
use File::Slurp qw | write_file |;
use File::Temp 'tempfile';
use File::Copy;
use POSIX;

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

has 'grm_temp_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'gwas_temp_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'pheno_temp_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'protocol_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1
);

has 'download_format' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'minor_allele_frequency' => (
    isa => 'Num',
    is => 'rw',
    default => sub{0.05}
);

has 'marker_filter' => (
    isa => 'Num',
    is => 'rw',
    default => sub{0.60}
);

has 'individuals_filter' => (
    isa => 'Num',
    is => 'rw',
    default => sub{0.80}
);

has 'accession_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'trait_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'traits_are_repeated_measurements' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
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

sub get_gwas {
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
    my $trait_list = $self->trait_id_list();
    my $protocol_id = $self->protocol_id();
    my $get_grm_for_parental_accessions = $self->get_grm_for_parental_accessions();
    my $grm_tempfile = $self->grm_temp_file();
    my $gwas_tempfile = $self->gwas_temp_file();
    my $pheno_tempfile = $self->pheno_temp_file();
    my $download_format = $self->download_format();
    my $traits_are_repeated_measurements = $self->traits_are_repeated_measurements();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
    chomp($number_system_cores);
    print STDERR "NUMCORES $number_system_cores\n";

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>'plot',
            trait_list=>$trait_list,
            accession_list=>$accession_list,
            exclude_phenotype_outlier=>0,
            include_timestamp=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    my %unique_trait_ids;
    my %unique_observation_units;
    my %phenotype_data_hash;
    my %filtered_accession_ids;
    foreach my $d (@$data) {
        $unique_observation_units{$d->{observationunit_stock_id}} = $d;
        foreach my $o (@{$d->{observations}}) {
            my $trait_id_use;
            if ($traits_are_repeated_measurements) {
                $trait_id_use = '0001';
            }
            else {
                $trait_id_use = $o->{trait_id};
            }
            $unique_trait_ids{$trait_id_use}++;
            if ($o->{value} || $o->{value} == 0) {
                $phenotype_data_hash{$d->{observationunit_stock_id}}->{$trait_id_use} = $o->{value};
                $filtered_accession_ids{$d->{germplasm_stock_id}}++;
            }
        }
    }
    my @unique_stock_ids_sorted = sort keys %unique_observation_units;
    my @unique_trait_ids_sorted = sort keys %unique_trait_ids;
    my @unique_accession_ids_sorted = sort keys %filtered_accession_ids;
    $accession_list = \@unique_accession_ids_sorted;

    my $trait_string_sql = join ',', @unique_trait_ids_sorted;
    open(my $F_pheno, ">", $pheno_tempfile) || die "Can't open file ".$pheno_tempfile;
        print $F_pheno 'gid,field_trial_id,replicate,'.$trait_string_sql."\n";
        foreach my $stock_id (@unique_stock_ids_sorted) {
            my $d = $unique_observation_units{$stock_id};
            print $F_pheno $d->{germplasm_stock_id}.','.$d->{trial_id}.','.$d->{obsunit_rep};
            foreach my $t (@unique_trait_ids_sorted) {
                my $pheno_val = $phenotype_data_hash{$stock_id}->{$t} || '';
                print $F_pheno ','.$pheno_val;
            }
            print $F_pheno "\n";
        }
    close($F_pheno);

    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id
    });
    my $markers = $protocol->markers;
    my @all_marker_objects = values %$markers;
    if (scalar(@all_marker_objects) > 10000) {
	my $page = CXGN::Page->new();
	$page->message_page('GWAS Error', 'Please choose less than 10,000 markers');
        print STDERR "Error: for GWAS please choose less than 10,000 markers";
    }

    no warnings 'uninitialized';
    @all_marker_objects = sort { $a->{chrom} cmp $b->{chrom} || $a->{pos} <=> $b->{pos} || $a->{name} cmp $b->{name} } @all_marker_objects;

    my @individuals_stock_ids;
    my @all_individual_accessions_stock_ids;
    my $counter = 0;

    # In this case a list of accessions is given, so get a GRM between these accessions
    if ($accession_list && scalar(@$accession_list)>0 && !$get_grm_for_parental_accessions){
        @all_individual_accessions_stock_ids = @$accession_list;
        if (scalar(@all_individual_accessions_stock_ids) > 100) {
	    my $page = CXGN::Page->new();
            $page->message_page('GWAS Error', 'Please choose less than 100 accessions');
            print STDERR "Error: for GWAS please choose less than 100 accessions";
        }
        foreach (@$accession_list) {
            my $dataset = CXGN::Dataset::Cache->new({
                people_schema=>$people_schema,
                schema=>$schema,
                cache_root=>$cache_root_dir,
                accessions=>[$_]
            });
            my $genotypes = $dataset->retrieve_genotypes($protocol_id, ['DS'], ['markers'], ['name','chrom','pos'], 1, [], undef, undef, []);

            if (scalar(@$genotypes)>0) {

                # For old genotyping protocols without nd_protocolprop info...
                if (scalar(@all_marker_objects) == 0) {
                    my $position_placeholder = 1;
                    foreach my $o (sort genosort keys %{$genotypes->[0]->{selected_genotype_hash}}) {
                        push @all_marker_objects, {name => $o, chrom => '1', pos => $position_placeholder};
                        $position_placeholder++;
                    }
                }

                foreach my $p (0..scalar(@$genotypes)-1) {
                    my $geno = $genotypes->[$p];

                    my $genotype_string = "";
                    if ($counter == 0) {
                        $genotype_string .= "ID\t";
                        foreach my $m (@all_marker_objects) {
                            $genotype_string .= $m->{name} . "\t";
                        }
                        $genotype_string .= "\n";
                        $genotype_string .= "CHROM\t";
                        foreach my $m (@all_marker_objects) {
                            $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{chrom} . " \t";
                        }
                        $genotype_string .= "\n";
                        $genotype_string .= "POS\t";
                        foreach my $m (@all_marker_objects) {
                            $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{pos} . " \t";
                        }
                        $genotype_string .= "\n";
                    }
                    my $genotype_id = $geno->{stock_id};
                    my $genotype_data_string = "";
                    foreach my $m (@all_marker_objects) {
                        $genotype_data_string .= $geno->{selected_genotype_hash}->{$m->{name}}->{'DS'}."\t";
                    }
                    $genotype_string .= $genotype_id."\t".$genotype_data_string."\n";

                    push @individuals_stock_ids, $genotype_id;
                    write_file($grm_tempfile, {append => 1}, $genotype_string);
                    undef $genotypes->[$p];
                    $counter++;
                }
                undef $genotypes;
            }
        }
    }
    # IN this case of a hybrid evaluation where the parents of the accessions planted in a plot are genotyped
    elsif ($get_grm_for_parental_accessions && $accession_list && scalar(@$accession_list)>0) {
        print STDERR "COMPUTING GENOTYPE FROM PARENTS FOR ACCESSIONS\n";
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

        @all_individual_accessions_stock_ids = @accession_stock_ids_found;

        for my $i (0..scalar(@accession_stock_ids_found)-1) {
            my $female_stock_id = $female_stock_ids_found[$i];
            my $male_stock_id = $male_stock_ids_found[$i];
            my $accession_stock_id = $accession_stock_ids_found[$i];

            my $dataset = CXGN::Dataset::Cache->new({
                people_schema=>$people_schema,
                schema=>$schema,
                cache_root=>$cache_root_dir,
                accessions=>[$female_stock_id, $male_stock_id]
            });
            my $genotypes = $dataset->retrieve_genotypes($protocol_id, ['DS'], ['markers'], ['name', 'chrom', 'pos'], 1, [], undef, undef, []);

            if (scalar(@$genotypes) > 0) {
                # For old genotyping protocols without nd_protocolprop info...
                if (scalar(@all_marker_objects) == 0) {
                    foreach my $o (sort genosort keys %{$genotypes->[0]->{selected_genotype_hash}}) {
                        push @all_marker_objects, {name => $o};
                    }
                }

                my $geno = $genotypes->[0];

                my $genotype_string = "";
                if ($counter == 0) {
                    $genotype_string .= "ID\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $m->{name} . "\t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "CHROM\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{chrom} . " \t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "POS\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{pos} . " \t";
                    }
                    $genotype_string .= "\n";
                }
                my $geno_hybrid = CXGN::Genotype::ComputeHybridGenotype->new({
                    parental_genotypes=>$genotypes,
                    marker_objects=>\@all_marker_objects
                });
                my $progeny_genotype = $geno_hybrid->get_hybrid_genotype();

                push @individuals_stock_ids, $accession_stock_id;
                my $genotype_string_scores = join "\t", @$progeny_genotype;
                $genotype_string .= $accession_stock_id."\t".$genotype_string_scores."\n";
                write_file($grm_tempfile, {append => 1}, $genotype_string);
                undef $progeny_genotype;
                $counter++;
            }
        }
    }

    my $transpose_tempfile = $grm_tempfile . "_transpose";

    my $tmp_output_dir = $shared_cluster_dir_config."/tmp_genotype_download_gwas";
    mkdir $tmp_output_dir if ! -d $tmp_output_dir;

    my $transpose_cmd = CXGN::Tools::Run->new(
        {
            backend => $backend_config,
            submit_host => $cluster_host_config,
            temp_base => $tmp_output_dir,
            queue => $web_cluster_queue_config,
            do_cleanup => 0,
            out_file => $transpose_tempfile,
#            out_file => $transpose_tempfile,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );

    # Do the transposition job on the cluster
    $transpose_cmd->run_cluster(
            "perl ",
            $basepath_config."/bin/transpose_matrix.pl",
            $grm_tempfile,
    );
    $transpose_cmd->is_cluster(1);
    $transpose_cmd->wait;

    # print STDERR Dumper \@all_marker_names;
    # print STDERR Dumper \@individuals_stock_ids;
    # print STDERR Dumper \@dosage_matrix;

    my $maf = $self->minor_allele_frequency();
    my $marker_filter = $self->marker_filter();
    my $individuals_filter = $self->individuals_filter();

    my $cmd = 'R -e "library(genoDataFilter); library(rrBLUP); library(data.table); library(scales);
    pheno <- fread(\''.$pheno_tempfile.'\', header=TRUE, sep=\',\');
    pheno\$field_trial_id <- as.factor(pheno\$field_trial_id);
    pheno\$replicate <- as.factor(pheno\$replicate);
    geno_mat_marker_first <- fread(\''.$transpose_tempfile.'\', header=TRUE, sep=\'\t\') #has sample names as column names, first 3 columns are marker info;
    geno_mat_sample_first <- data.frame(fread(\''.$grm_tempfile.'\', header=FALSE, sep=\'\t\', skip=3)) #has sample names in first column, no defined column names;
    sample_names <- geno_mat_sample_first\$V1; #no defined column names but they are markers
    geno_mat_sample_first <- geno_mat_sample_first[,-1]; #remove first column so that row names are sample names and all other columns are markers
    geno_mat_sample_first <- as.data.frame(rescale(as.matrix(geno_mat_sample_first), to = c(-1,1) ) ); #rrBLUP expected -1 to 1
    colnames(geno_mat_sample_first) <- geno_mat_marker_first\$ID; #has sample names as row names, column names are marker names
    row.names(geno_mat_sample_first) <- sample_names;
    mat_clean_sample_first <- filterGenoData(gData=geno_mat_sample_first, maf='.$maf.', markerFilter='.$marker_filter.', indFilter='.$individuals_filter.');
    if (\'rn\' %in% colnames(mat_clean_sample_first)) { row.names(mat_clean_sample_first) <- mat_clean_sample_first\$rn; mat_clean_sample_first <- mat_clean_sample_first[,-1]; }
    remaining_samples <- row.names(mat_clean_sample_first);
    remaining_markers <- colnames(mat_clean_sample_first);
    imputation <- A.mat(mat_clean_sample_first, impute.method=\'EM\', n.core='.$number_system_cores.', return.imputed=TRUE);
    K.mat <- imputation\$A;
    geno_imputed <- imputation\$imputed;
    geno_gwas <- cbind(geno_mat_marker_first[geno_mat_marker_first\$ID %in% remaining_markers, c(1:3)], t(geno_imputed));
    gwas_results <- GWAS(pheno[pheno\$gid %in% remaining_samples, ], geno_gwas, fixed=c(\'field_trial_id\',\'replicate\'), K=K.mat, plot=F, min.MAF='.$maf.'); #columns are ID,CHROM,POS,TraitIDs and values in TraitIDs column are -log10 p values'."\n";
    if ($download_format eq 'manhattan_qq_plots') {
	$cmd .= 'pdf( \''.$gwas_tempfile.'\', width = 11, height = 8.5 );
        for (i in 4:length(gwas_results)) { alpha_bonferroni=-log10(0.05/length(gwas_results[,i])); chromosome_ids <- as.factor(gwas_results\$CHROM); marker_indicator <- match(unique(gwas_results\$CHROM), gwas_results\$CHROM); N <- length(gwas_results[,1]); plot(seq(1:N), gwas_results[,i], col=chromosome_ids, ylab=\'-log10(pvalue)\', main=paste(\'Manhattan Plot \',colnames(gwas_results)[i]), xaxt=\'n\', xlab=\'Position\', ylim=c(0,14)); axis(1,at=marker_indicator,labels=gwas_results\$CHROM[marker_indicator], cex.axis=0.8, las=2); abline(h=alpha_bonferroni,col=\'red\',lwd=2); expected.logvalues <- sort( -log10( c(1:N) * (1/N) ) ); observed.logvalues <- sort(gwas_results[,i]); plot(expected.logvalues, observed.logvalues, main=paste(\'QQ Plot \',colnames(gwas_results)[i]), xlab=\'Expected -log p-values \', ylab=\'Observed -log p-values\', col.main=\'black\', col=\'coral1\', pch=20); abline(0,1,lwd=3,col=\'black\'); }
        dev.off();
        "';
    }
    elsif ($download_format eq 'results_tsv') {
        $cmd .= 'write.table(gwas_results, file=\''.$gwas_tempfile.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
        "';
    }
    print STDERR Dumper $cmd;

    # Do the GWAS on the cluster
    my $gwas_cmd = CXGN::Tools::Run->new(
        {
            backend => $backend_config,
            submit_host => $cluster_host_config,
            temp_base => $tmp_output_dir,
            queue => $web_cluster_queue_config,
            do_cleanup => 0,
            out_file => $gwas_tempfile,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );

    # Do the transposition job on the cluster
    $gwas_cmd->run_cluster($cmd);
    $gwas_cmd->is_cluster(1);
    $gwas_cmd->wait;
    my $status;

    return ($gwas_tempfile, $status);
}

sub grm_cache_key {
    my $self = shift;
    my $datatype = shift;

    #print STDERR Dumper($self->_get_dataref());
    my $json = JSON->new();
    #preserve order of hash keys to get same text
    $json = $json->canonical();
    my $accessions = $json->encode( $self->accession_id_list() || [] );
    my $traits = $json->encode( $self->trait_id_list() || [] );
    my $protocol = $self->protocol_id() || '';
    my $genotypeprophash = $json->encode( $self->genotypeprop_hash_select() || [] );
    my $protocolprophash = $json->encode( $self->protocolprop_top_key_select() || [] );
    my $protocolpropmarkerhash = $json->encode( $self->protocolprop_marker_hash_select() || [] );
    my $maf = $self->minor_allele_frequency();
    my $marker_filter = $self->marker_filter();
    my $download_format = $self->download_format();
    my $individuals_filter = $self->individuals_filter();
    my $key = md5_hex($accessions.$traits.$protocol.$genotypeprophash.$protocolprophash.$protocolpropmarkerhash.$self->get_grm_for_parental_accessions().$self->return_only_first_genotypeprop_for_stock()."_MAF$maf"."_mfilter$marker_filter"."_ifilter$individuals_filter"."repeated".$self->traits_are_repeated_measurements()."format$download_format"."_$datatype");
    return $key;
}

sub download_gwas {
    my $self = shift;
    my $shared_cluster_dir_config = shift;
    my $backend_config = shift;
    my $cluster_host_config = shift;
    my $web_cluster_queue_config = shift;
    my $basepath_config = shift;

    my $key = $self->grm_cache_key("download_gwas_v01");
    $self->_cache_key($key);
    $self->cache( Cache::File->new( cache_root => $self->cache_root() ));

    my $return;
    if ($self->cache()->exists($key)) {
        $return = $self->cache()->handle($key);
    }
    else {
        my ($gwas_tempfile, $status) = $self->get_gwas($shared_cluster_dir_config, $backend_config, $cluster_host_config, $web_cluster_queue_config, $basepath_config);

        open my $out_copy, '<', $gwas_tempfile or die "Can't open output file: $!";

        $self->cache()->set($key, '');
        my $file_handle = $self->cache()->handle($key);
        copy($out_copy, $file_handle);

        close $out_copy;
        $return = $self->cache()->handle($key);
    }
    return $return;
}

sub genosort {
    my ($a_chr, $a_pos, $b_chr, $b_pos);
    if ($a =~ m/S(\d+)\_(.*)/) {
        $a_chr = $1;
        $a_pos = $2;
    }
    if ($b =~ m/S(\d+)\_(.*)/) {
        $b_chr = $1;
        $b_pos = $2;
    }

    if ($a_chr && $b_chr) {
        if ($a_chr == $b_chr) {
            return $a_pos <=> $b_pos;
        }
        return $a_chr <=> $b_chr;
    } else {
        return -1;
    }
}

1;
