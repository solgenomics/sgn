use strict;

package SGN::Controller::AJAX::GCPC;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use File::Spec qw | catfile|;
use File::Basename qw | basename |;
use File::Copy;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::Tools::Run;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/distinct evens/;
use CXGN::Blast::Parse;
use CXGN::Blast::SeqQuery;
use Cwd qw(cwd);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );


sub shared_phenotypes: Path('/ajax/gcpc/shared_phenotypes') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    my $traits = $ds->retrieve_traits();
    
    $c->tempfiles_subdir("gcpc_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"gcpc_files/trait_XXXXX");
    $people_schema = $c->dbic_schema("CXGN::People::Schema");
    $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;
    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes => 0);
    my $phenotype_data_ref = $ds2->retrieve_phenotypes();

    print STDERR Dumper($traits);
    $c->stash->{rest} = {
        options => $traits,
        tempfile => $tempfile."_phenotype.txt",
#        tempfile => $file_response,
    };
}

my $method_id;
sub get_method: Path('/ajax/gcpc/get_method') : {
    my $self = shift;
    my $c = shift;
    my $method_1 = $c->req->param('method_id');
    print STDERR Dumper($method_1);
    $method_id = $method_1;
    print "The vairable method_id is $method_id \n";
}


sub extract_trait_data :Path('/ajax/gcpc/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);
    my @data;
    
    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/gcpc_files", $file);
    print STDERR Dumper($temppath);

    my $F;
    if (! open($F, "<", $temppath)) {
	$c->stash->{rest} = { error => "Can't find data." };
	return;
    }
    
    $c->stash->{rest} = { data => \@data, trait => $trait};
}

sub generate_results: Path('/ajax/gcpc/generate_results') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    #my $method = $c->req->param('method_id');
    my $sin_list_id = $c->req->param('sin_list_id');
    
    print STDERR "DATASET_ID: $dataset_id\n";
    print STDERR "SELECTION INDEX ID: $sin_list_id\n";
    #print STDERR "Method: ".Dumper($method);

    my $list = CXGN::List->new( { dbh => $c->dbic_schema("Bio::Chado::Schema")->storage->dbh() , list_id => $sin_list_id });
    my $elements = $list->elements();

    print STDERR "ELEMENTS: ".Dumper($elements);

    $elements->[0] =~ s/^traits\://g;
    my @traits = split /\,/, $elements->[0];

    $elements->[1] =~ s/^numbers\://g;
    my @numbers = split /\,/, $elements->[1];

    print STDERR "TRAITS: ".join(",", @traits)."\n";
    print STDERR "NUMBERS: ".join(",", @numbers)."\n";
    
    my @si_r_traits = @traits;
    foreach my $t (@si_r_traits) {
	$t = make_R_trait_name($t);
    }

    my $si_traits = join(",", @si_r_traits);
    my $si_weights = join(",", @numbers);
    
    print STDERR "TRAITS and WEIGHTS: $si_traits $si_weights\n";
    
    $c->tempfiles_subdir("gcpc_files");
    my $gcpc_tmp_output = $c->config->{cluster_shared_tempdir}."/gcpc_files";
    mkdir $gcpc_tmp_output if ! -d $gcpc_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "gcpc_download_XXXXX",
      DIR=> $gcpc_tmp_output,
    );

    my $pheno_filepath = $tempfile . "_phenotype.txt";
    my $geno_filepath  = $tempfile . "_genotype.txt";

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    #my $temppath = $stability_tmp_output . "/" . $tempfile;
    my $temppath =  $tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes=>0);
    
    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);

    print STDERR "PHENOTYPES REF: ".Dumper($phenotype_data_ref);
    

    open(my $PF, "<", $pheno_filepath) || die "Can't open pheno file $pheno_filepath";
    open(my $CLEAN, ">", $pheno_filepath.".clean") || die "Can't open pheno_filepath clean for writing";
    
    my $header = <$PF>;
    chomp($header);

    my @fields = split /\t/, $header;

    my @file_traits = @fields[ 39 .. @fields-1 ];
    my @other_headers = @fields[ 0 .. 38 ];
    
    print STDERR "FIELDS: ".Dumper(\@file_traits);

    foreach my $t (@file_traits) {
	$t = make_R_trait_name($t);
    }

    print STDERR "FILE TRAITS: ".Dumper(\@file_traits);
    
    print $CLEAN join("\t", @other_headers, @file_traits)."\n";

    while(<$PF>) {
	print $CLEAN $_;
    }

    close($CLEAN);
    close($PF);

    # compare if all the traits in the selection index are in the file
    #
    my %file_traits_hash = ();
    foreach my $ft (@file_traits) {
	$file_traits_hash{$ft}++;
    }

    my @missing_traits;
    foreach my $si_t (@si_r_traits) {
	if (! defined($file_traits_hash{$si_t})) {
	    push @missing_traits, $si_t;
	}
    }

    if (scalar(@missing_traits) == scalar(@si_r_traits)) {
	$c->stash->{rest} = { error => "None of the traits in the selection index are present in the dataset. Please choose another selection index." };
	return ;
    }

    if (scalar(@missing_traits) < scalar(@si_r_traits)) {
	$c->stash->{rest} = { message => "Some of the traits in the selection index are not in the dataset (".join(",", @missing_traits)."). Their weights will be ignored." };
    }
    
    my $genotyping_protocols = $ds->retrieve_genotyping_protocols();

    print STDERR "Genotyping protocols: ".Dumper($genotyping_protocols);
    
    if (scalar(@$genotyping_protocols) == 0) { die "No genotyping protocols found in this dataset! Please choose another dataset!"; }
    
    my $protocol = shift @$genotyping_protocols;

    print STDERR "PROTOCOL NOW : ".Dumper($protocol);

    print STDERR "PROTOCOL ID = ".$protocol->[0]."\n";
    
    my $forbid_cache = 0;

    print STDERR "GENOFILE PATH = $geno_filepath\n";
    print STDERR "cache file path = ".$c->config->{cache_file_path}." CLUSTER SHARED TEMPDIR: ".$c->config->{cluster_shared_tempdir}."\n";

    
    my $genotype_data_fh = $ds->retrieve_genotypes( $protocol->[0], $geno_filepath, $c->config->{cache_file_path}, $c->config->{cluster_shared_tempdir}, $c->config->{backend}, $c->config->{cluster_host}, $c->config->{'web_cluster_queue'}, $c->config->{basepath}, $forbid_cache, ['GT'], [], ['name', 'chrom', 'pos', 'alt', 'ref', 'format', 'filter', 'qual', 'info' ]);

    my $cmd = CXGN::Tools::Run->new({
            backend => $c->config->{backend},
            submit_host=>$c->config->{cluster_host},
            temp_base => $c->config->{cluster_shared_tempdir} . "/gcpc_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        });

    $cmd->run_cluster(
	"Rscript ",
	$c->config->{basepath} . "/R/GCPC.R",
	$pheno_filepath.".clean",
	$geno_filepath,
	"'".$si_traits."'",
	"'".$si_weights."'",
	
	);

    while ($cmd->alive) { 
	sleep(1);
    }

#    my $figure_path = $c->config->{basepath} . "/static/documents/tempfiles/stability_files/";

    my @data;

    open(my $F, "<", $pheno_filepath.".clean.out") || die "Can't open result file $pheno_filepath".".clean.out";
    while (<$F>) {
	chomp;
	my @fields = split /\t/;
	push @data, \@fields;
    }
    
    $c->stash->{rest}->{
	data => \@data
    };
}


sub make_R_trait_name { 
    my $trait = shift;
    $trait =~ s/\s/\_/g;
    $trait =~ s/\//\_/g;
    $trait =~ tr/ /./;
    $trait =~ tr/\//./;
    $trait =~ s/\:/\_/g;
    $trait =~ s/\|/\_/g;
    $trait =~ s/\-/\_/g;
    
    return $trait;
}

1
