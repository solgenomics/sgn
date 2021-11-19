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
    
    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/gcpc_files/".$file);
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

    $elements->[0] =~ s/^traits\://;
    my @traits = split /\,/, $elements->[0];

    print STDERR join(",", @traits);

    my @new_traits = @traits;

    foreach my $t (@new_traits) {
	$t = make_R_trait_name($t);
    }

    print STDERR "NEW TRAITS ".Dumper(\@new_traits);
    
    my $trait_id;
    
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

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes => 0);

    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);

    open(my $PF, "<", $pheno_filepath) || die "Can't open pheno file $pheno_filepath";
    open(my $CLEAN, ">", $pheno_filepath.".clean") || die "Can't open pheno_filepath clean for writing";
    
    my $header = <$PF>;
    chomp($header);

    my @fields = split /\t/, $header;

    my @file_traits = @fields[ 39 .. @fields-1 ];
    my @other_headers = @fields[ 0 .. 38 ];
    
    print STDERR "FIELDS: ".Dumper(\@file_traits);

    foreach my $t (@file_traits) {
	make_R_trait_name($t);
    }

    print $CLEAN join("\t", @other_header, @file_traits);

    while(<$PF>) {
	print $CLEAN, $_;
    }

    close($CLEAN);
    close($PF);
    
    my $traits;
    my $weights;
    
    my $newtrait = $traits;

    my $genotype_data_ref = $ds->retrieve_genotypes($geno_filepath);

    open(my $F, "<", $geno_filepath) || die "Can't open file $geno_filepath\n";
    open(my $G, ">", $geno_filepath.".hmp") || die "Can't open ".$geno_filepath.".hmp for writing\n";
    
    my $AMMIFile = $tempfile . "_" . "AMMIFile.png";
    my $figure1file = $tempfile . "_" . "figure1.png";
    my $figure2file = $tempfile . "_" . "figure2.png";

    $trait_id =~ tr/ /./;
    $trait_id =~ tr/\//./;

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
	$c->config->{basepath} . "/R/GCPC_Yambase.R",
	$pheno_filepath.".clean",
	$geno_filepath,
	"'".$traits."'",
	$weights,
	
	);

    while ($cmd->alive) { 
	sleep(1);
    }

    my $error;

    if (! -e $AMMIFile) { 
	$error = "The analysis could not be completed. The factors may not have sufficient numbers of levels to complete the analysis. Please choose other parameters."
    }

    my $figure_path = $c->config->{basepath} . "/static/documents/tempfiles/stability_files/";

    copy($AMMIFile, $figure_path);
    copy($figure1file, $figure_path);
    copy($figure2file, $figure_path);

    my $AMMIFilebasename = basename($AMMIFile);
    my $AMMIFile_response = "/documents/tempfiles/stability_files/" . $AMMIFilebasename;
    
    my $figure1basename = basename($figure1file);
    my $figure1_response = "/documents/tempfiles/stability_files/" . $figure1basename;
    
    my $figure2basename = basename($figure2file);
    my $figure2_response = "/documents/tempfiles/stability_files/" . $figure2basename;
        
    $c->stash->{rest} = {
        AMMITable => $AMMIFile_response,
        figure1 => $figure1_response,
        figure2 => $figure2_response,
        dummy_response => $dataset_id
        # dummy_response2 => $trait_id,
    };
}

sub make_R_trait_name {
    my $trait = shift;
    $trait =~ s/\s/\_/g;
    $trait =~ s/\//\_/g;
    $trait =~ tr/ /./;
    $trait =~ tr/\//./;
    return $trait;
}

1

