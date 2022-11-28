use strict;

package SGN::Controller::AJAX::SpatialModel;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use File::Spec qw | catfile|;
use File::Basename qw | basename |;
use File::Copy;
use List::Util qw | any |;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::Tools::Run;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/distinct evens/;
use CXGN::Blast::Parse;
use CXGN::Blast::SeqQuery;
use SGN::Model::Cvterm;
use Cwd qw(cwd);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );


sub shared_phenotypes: Path('/ajax/spatial_model/shared_phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    my $traits = $ds->retrieve_traits();

    $c->tempfiles_subdir("spatial_model_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"spatial_model_files/trait_XXXXX");
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



sub extract_trait_data :Path('/ajax/spatial_model/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);
    my @data;

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/spatial_model_files", $file);
    print STDERR Dumper($temppath);

    my $F;
    if (! open($F, "<", $temppath)) {
	$c->stash->{rest} = { error => "Can't find data." };
	return;
    }

    $c->stash->{rest} = { data => \@data, trait => $trait};
}

sub generate_results: Path('/ajax/spatial_model/generate_results') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    print STDERR "TRIAL_ID: $trial_id\n";

    $c->tempfiles_subdir("spatial_model_files");
    my $spatial_model_tmp_output = $c->config->{cluster_shared_tempdir}."/spatial_model_files";
    mkdir $spatial_model_tmp_output if ! -d $spatial_model_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "spatial_model_download_XXXXX",
      DIR=> $spatial_model_tmp_output,
    );

    my $pheno_filepath = $tempfile . "_phenotype.txt";


    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");


    my $temppath =  $tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema,  file_name => $temppath, quotes=>0);
    $ds -> trials([$trial_id]);
    $ds -> retrieve_phenotypes($pheno_filepath);
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

    my $si_traits = join(",", @file_traits);

    print STDERR "FILE TRAITS: ".Dumper(\@file_traits);

    my @new_header = (@other_headers, @file_traits);
    print $CLEAN join("\t", @new_header)."\n";

    my $last_index = scalar(@new_header)-1;

    while(<$PF>) {
	print $CLEAN $_;
    }

    close($PF);
    close($CLEAN);

    my $cmd = CXGN::Tools::Run->new({
	backend => $c->config->{backend},
	submit_host=>$c->config->{cluster_host},
	temp_base => $c->config->{cluster_shared_tempdir} . "/spatial_model_files",
	queue => $c->config->{'web_cluster_queue'},
	do_cleanup => 0,
	# don't block and wait if the cluster looks full
	max_cluster_jobs => 1_000_000_000,
    });

    $cmd->run_cluster(
	"Rscript ",
	$c->config->{basepath} . "/R/spatial_modeling.R",
	$pheno_filepath.".clean",
	"'".$si_traits."'",

	);

    while ($cmd->alive) {
	sleep(1);
    }

    my @data;

    open(my $F, "<", $pheno_filepath.".clean.out") || die "Can't open result file $pheno_filepath".".clean.out";
    my $header = <$F>;
    while (<$F>) {
	chomp;
	my @fields = split /\,/;
	foreach my $f (@fields) { $f =~ s/\"//g; }
	push @data, \@fields;
    }

    print STDERR "FORMATTED DATA: ".Dumper(\@data);

    my $basename = basename($pheno_filepath.".clean.out");

    copy($pheno_filepath.".clean.out", $c->config->{basepath}."/static/documents/tempfiles/spatial_model_files/".$basename);

    my $download_url = '/documents/tempfiles/spatial_model_files/'.$basename;
    my $download_link = "<a href=\"$download_url\">Download Results</a>";

    $c->stash->{rest} = {
	data => \@data,
	download_link => $download_link,
    };
}


sub make_R_trait_name {
    my $trait = shift;
    $trait =~ s/\%//g;
    $trait =~ s/\s/\_/g;
    $trait =~ s/\//\_/g;
    $trait =~ tr/ /./;
    $trait =~ tr/\//./;
    $trait =~ s/\:/\_/g;
    $trait =~ s/\|/\_/g;
    $trait =~ s/\-/\_/g;

    return $trait;
}

1;
