
package CXGN::Dataset::File;

use Moose;
use File::Slurp qw | write_file |;
use JSON::Any;
use Data::Dumper;
use CXGN::Genotype::Search;

extends 'CXGN::Dataset';

has 'file_name' => ( isa => 'Str',
		     is => 'rw',
		     default => '/tmp/dataset_file',
    );

has 'quotes' => ( isa => 'Bool',
		  is => 'rw',
		  default => 1,
    );

sub retrieve_genotypes_vcf {
    my $self = shift;
    my $protocol_id = shift;
    my $file = shift; # || $self->file_name()."_genotype.txt";
    my $cache_root_dir = shift;
    my $cluster_shared_tempdir_config = shift;
    my $backend_config = shift;
    my $cluster_host_config = shift;
    my $web_cluster_queue_config = shift;
    my $basepath_config	= shift;
    my $forbid_cache = shift;
    my $genotypeprop_hash_select = shift || ['DS'];
    my $protocolprop_top_key_select = shift || [];
    my $protocolprop_marker_hash_select = shift || [];
    my $return_only_first_genotypeprop_for_stock = shift || 1;
    
    my $accessions_list_ref = $self->retrieve_accessions();
    
    my @accession_ids;
    foreach my $ai (@$accessions_list_ref) {
	push @accession_ids, $ai->[0];
    }
    
    my @protocol_ids;
    
    if ($protocol_id) {
	push @protocol_ids, $protocol_id;
    }
    else { 
	my $genotyping_protocol_ref = $self->retrieve_genotyping_protocols();
	
	foreach my $p (@$genotyping_protocol_ref) {
	    push @protocol_ids, $p->[0];
	}
    }
    
    if (! @protocol_ids)  {
	die "No protocol provided or no protocol associated with dataset\n";
    }
    
    print STDERR "PROTOCOL IDS: ".Dumper(\@protocol_ids);
    
    my @accessions_list = @$accessions_list_ref;
    my $genotypes_search = CXGN::Genotype::Search->new(
	bcs_schema => $self->schema(),
	people_schema => $self->people_schema(),
	cache_root=>$cache_root_dir,
	accession_list => \@accession_ids,
	trial_list => $self->trials(),
	protocol_id_list => \@protocol_ids,
	genotypeprop_hash_select=>$genotypeprop_hash_select, #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
	protocolprop_top_key_select=>$protocolprop_top_key_select, #THESE ARE THE KEYS AT THE TOP LEVEL OF THE PROTOCOLPROP OBJECT
	protocolprop_marker_hash_select=>$protocolprop_marker_hash_select, #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
	return_only_first_genotypeprop_for_stock=>$return_only_first_genotypeprop_for_stock, #FOR MEMORY REASONS TO LIMIT DATA
	forbid_cache=>$forbid_cache
	);
    my @required_config = (
	$cluster_shared_tempdir_config,
	$backend_config,
	$cluster_host_config,
	$web_cluster_queue_config,
	$basepath_config
	);
    
    my $filehandle = $genotypes_search->get_cached_file_VCF(@required_config);
    print STDERR "Checking if a file was requested...\n";
    
    if ($file) {
	print STDERR "Generating the file $file ...\n";
	open(my $F, ">", $file) || die "Can't open file $file";
	while(<$filehandle>) {
	    print $F $_;
	}
	print STDERR "Done.\n";
	close($F);
    }
    
    return $filehandle
}


override('retrieve_genotypes',
	 sub {
	     my $self = shift;
	     my $protocol_id = shift;
	     my $file = shift || $self->file_name()."_genotype.txt";
	     my $cache_root_dir = shift;
	     my $cluster_shared_tempdir_config = shift;
	     my $backend_config = shift;
	     my $cluster_host_config = shift;
	     my $web_cluster_queue_config = shift;
	     my $basepath_config	= shift;
	     my $forbid_cache = shift;
	     

	     my $genotypeprop_hash_select = shift || ['DS'];
	     my $protocolprop_top_key_select = shift || [];
	     my $protocolprop_marker_hash_select = shift || [];
	     my $return_only_first_genotypeprop_for_stock = shift || 1;
	     
	     my $accessions_list_ref = $self->retrieve_accessions();
	     my @accession_ids;
	     foreach (@$accessions_list_ref) {
		 push @accession_ids, $_->[0];
	     }
	     
	     my $genotyping_protocol_ref = $self->retrieve_genotyping_protocols();
	     my @protocols;
	     foreach my $p (@$genotyping_protocol_ref) {
		 push @protocols, $p->[0];		 
	     }

	     print STDERR "PROTOCOLS IN RETRIEVE_GENOTYPES: ".join(", ",@protocols)."\n";
    	     my @accessions_list = @$accessions_list_ref;
	     my $genotypes_search = CXGN::Genotype::Search->new(
		 bcs_schema => $self->schema(),
		 people_schema => $self->people_schema(),
		 cache_root=>$cache_root_dir,
		 accession_list => \@accession_ids,
		 trial_list => $self->trials(),
		 protocol_id_list => \@protocols,
		 genotypeprop_hash_select=>$genotypeprop_hash_select, #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
		 protocolprop_top_key_select=>$protocolprop_top_key_select, #THESE ARE THE KEYS AT THE TOP LEVEL OF THE PROTOCOLPROP OBJECT
		 protocolprop_marker_hash_select=>$protocolprop_marker_hash_select, #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
		 return_only_first_genotypeprop_for_stock=>$return_only_first_genotypeprop_for_stock, #FOR MEMORY REASONS TO LIMIT DATA
		 forbid_cache=>$forbid_cache
		 );

	     print STDERR "DONE WITH GENO SEARCH!\n";
	     
	     my @required_config = (
		 $cluster_shared_tempdir_config,
		 $backend_config,
		 $cluster_host_config,
		 $web_cluster_queue_config,
		 $basepath_config
		 );

	     my $fh = $genotypes_search->get_cached_file_dosage_matrix(@required_config);

	     print STDERR "DONE GETTING DOSAGE MATRIX\n";


	     if ($file) {
		 print STDERR "Generating the file $file ...\n";
		 open(my $F, ">", $file) || die "Can't open file $file";
		 while(<$fh>) {
		     print $F $_;
		 }
		 print STDERR "Done.\n";
		 close($F);
	     }

	     return $fh;

	 });



override('retrieve_phenotypes',
	 sub {
	     my $self = shift;
	     my $file = shift || $self->file_name()."_phenotype.txt";
	     my $phenotypes = $self->SUPER::retrieve_phenotypes();
	     my $phenotype_string = "";
	     my $s;
	     foreach my $line (@$phenotypes) {
		 if ($self->quotes()) {
		     no warnings; # turn off warnings, otherwise there are a lot of undefined warnings.
		     $s = join("\t", map { "\"$_\"" } @$line);
		 }
		 else {
		     no warnings;
		     $s = join("\t", @$line);
		 }
		 # $s = "";
	         # my $num_col = scalar(@{$line});
		 # for (my $j = 0; $j < $num_col; $j++) {
                 #     if (@$line[$j]) {
		 #         if ($s eq "") {
	         #            $s .= "\"@$line[$j]\"";
		 #         } else {
		 #            $s .= "\t\"@$line[$j]\"";
		 # 	 }
                 #     } else {
                 #         $s .= "\t";
                 #     }
                 # }		
		 
		 $s =~ s/\n//g;
		 $s =~ s/\r//g;
		 $phenotype_string .= $s."\n";
	     }
	     write_file($file, $phenotype_string);
	     return $phenotypes;
	 });

override('retrieve_accessions',
	 sub {
	     my $self = shift;
	     my $file = shift || $self->file_name()."_accessions.txt";
	     my $accessions = $self->SUPER::retrieve_accessions();
	     my $accession_json = JSON::Any->encode($accessions);
	     write_file($file, $accession_json);
	     return $accessions;
	 });

override('retrieve_plots',
	 sub {
	     my $self = shift;
	     my $file = shift || $self->file_name()."_plots.txt";
	     my $plots = $self->SUPER::retrieve_plots();
	     my $plot_json = JSON::Any->encode($plots);
	     write_file($file, $plot_json);
	     return $plots;
	 });

override('retrieve_trials',
	 sub {
	     my $self = shift;
	     my $file = shift || $self->file_name()."_trials.txt";
	     my $trials = $self->SUPER::retrieve_trials();
	     my $trial_json = JSON::Any->encode($trials);
	     write_file($file, $trial_json);
	     return $trials;
	 });

override('retrieve_traits',
	 sub {
	     my $self = shift;
	     my $file = shift || $self->file_name()."_traits.txt";
	     my $traits = $self->SUPER::retrieve_traits();
	     my $trait_json = JSON::Any->encode($traits);
	     write_file($file, $trait_json);
	     return $traits;
	 });

override('retrieve_years',
	 sub {
	     my $self = shift;
	     my $file = shift || $self->file_name()."_years.txt";
	     my $years = $self->SUPER::retrieve_years();
	     my $year_json = JSON::Any->encode($years);
	     write_file($file, $year_json);
	     return $years;
	 });

1;
