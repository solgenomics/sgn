
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

my $spatial_check;
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
#spatial_checking method
sub spatial_checking: Path('/ajax/spatial_model/spatial_checking') Args(1) { # Args(1) is the trial id
    my $self = shift; # $self is the controller object
    my $c = shift; # $c is the Catalyst context object
    my $trial_id = shift; # $trial_id is the trial id

    my $people_schema = $c->dbic_schema("CXGN::People::Schema"); # get the people schema
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado"); # get the chado schema

    my $file = $c->req->param("file"); # get the file name
    my $si_traits = $c->req->param("si_traits"); # get the spatial interaction traits

    $c->tempfiles_subdir("spatial_model_files"); # set the tempfiles subdir to spatial model files
    my $spatial_model_tmp_output = $c->config->{cluster_shared_tempdir}."/spatial_model_files"; # get the spatial model temp output directory
    print STDERR "spatial_model_tmp_output: $spatial_model_tmp_output\n";
    mkdir $spatial_model_tmp_output if ! -d $spatial_model_tmp_output; # create the spatial model temp output directory if it doesn't exist
    my ($tmp_fh, $tempfile) = tempfile(
      "spatial_model_download_XXXXX",
      DIR=> $spatial_model_tmp_output,
    );
    print STDERR "tempfile: $tempfile\n";

    my $pheno_filepath = $tempfile . "_phenotype.txt"; # create the phenotype file path
    print STDERR "pheno_filepath: $pheno_filepath\n";

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
	$c->config->{basepath} . "/R/spatial_checking.R",
	$pheno_filepath.".clean",
	"'".$si_traits."'",

	);

    while ($cmd->alive) {
	sleep(1);
    }


     #getting the results
    my @data;

    open($spatial_check, "<", $pheno_filepath.".clean.spatialchecking") || die "Can't open result file $pheno_filepath".".clean.spatialchecking";
    my $header = <$spatial_check>;
    my @h = split(/\s+/, $header);
    #my @h = split(',', $header);
    my @spl;
    foreach my $item (@h) {
    push  @spl, {title => $item};
  }
    print STDERR "Header: ".Dumper(\@spl);
    while (<$spatial_check>) {
	chomp;
	my @fields = split /\s+/;
	foreach my $f (@fields) { $f =~ s/\"//g; }
	push @data, \@fields;
    }
    # print STDERR "FORMATTED DATA: ".Dumper(\@data);

    my $basename = basename($pheno_filepath.".clean.spatialchecking");

    copy($pheno_filepath.".clean.spatialchecking", $c->config->{basepath}."/static/documents/tempfiles/spatial_model_files/".$basename);

    my $download_url = '/documents/tempfiles/spatial_model_files/'.$basename;
    my $download_link = "<a href=\"$download_url\">Download Results</a>";
    $c->stash->{rest} = { 
            data => \@data,
            headers => \@spl,
            basenamesp => $basename,
    };

}

sub generate_results: Path('/ajax/spatial_model/generate_results') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $basenamesp = $c -> req -> param("basenamesp");

    print STDERR "TRIAL_ID: $trial_id\n";

    $c->tempfiles_subdir("spatial_model_files"); # set the tempfiles subdir to spatial model files
    my $spatial_model_tmp_output = $c->config->{cluster_shared_tempdir}."/spatial_model_files"; # get the spatial model temp output directory
    print STDERR "spatial_model_tmp_output: $spatial_model_tmp_output\n";
    mkdir $spatial_model_tmp_output if ! -d $spatial_model_tmp_output; # create the spatial model temp output directory if it doesn't exist
    my ($tmp_fh, $tempfile) = tempfile(
      "spatial_model_download_XXXXX",
      DIR=> $spatial_model_tmp_output,
    );
    print STDERR "tempfile: $tempfile\n";

    #my $temppath = $c->config->{basepath}."/".$tempfile;
    #print STDERR "temppath: $temppath\n";

    my $pheno_filepath = $tempfile . "_phenotype.txt"; # create the phenotype file path
    

    print STDERR "pheno_filepath: $pheno_filepath\n";

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
    $spatial_check,

	);

    while ($cmd->alive) {
	sleep(1);
    }

    #getting the blue results
    my @data;

    open(my $F, "<", $pheno_filepath.".clean.blues") || die "Can't open result file $pheno_filepath".".clean.blues";
    my $header = <$F>;
    my @h = split(/\s+/, $header);
    #my @h = split(',', $header);
    my @spl;
    foreach my $item (@h) {
    push  @spl, {title => $item};
  }
    print STDERR "Header: ".Dumper(\@spl);
    while (<$F>) {
	chomp;
	my @fields = split /\s+/;
	foreach my $f (@fields) { $f =~ s/\"//g; }
	push @data, \@fields;
    }

    # print STDERR "FORMATTED DATA: ".Dumper(\@data);

    my $basename = basename($pheno_filepath.".clean.blues");

    copy($pheno_filepath.".clean.blues", $c->config->{basepath}."/static/documents/tempfiles/spatial_model_files/".$basename);

    my $download_url = '/documents/tempfiles/spatial_model_files/'.$basename;
    my $download_link = "<a href=\"$download_url\">Download Results</a>";




    ##getting with fitted results
    my @data_fitted;

    open(my $F_fitted, "<", $pheno_filepath.".clean.fitted") || die "Can't open result file $pheno_filepath".".clean.fitted";
    my $header_fitted = <$F_fitted>;
    my @h_fitted = split(/\s+/, $header_fitted);
    #my @h = split(',', $header);
    my @spl_fitted;
    foreach my $item_fitted (@h_fitted) {
    push  @spl_fitted, {title => $item_fitted};
  }
    print STDERR "Header: ".Dumper(\@spl_fitted);
    while (<$F_fitted>) {
	chomp;
	my @fields_fitted = split /\s+/;
	foreach my $f_fitted (@fields_fitted) { $f_fitted =~ s/\"//g; }
	push @data_fitted, \@fields_fitted;
    }

    # print STDERR "FORMATTED DATA: ".Dumper(\@data);

    my $basename = basename($pheno_filepath.".clean.fitted");

    copy($pheno_filepath.".clean.fitted", $c->config->{basepath}."/static/documents/tempfiles/spatial_model_files/".$basename);

    my $download_url_fitted = '/documents/tempfiles/spatial_model_files/'.$basename;
    my $download_link_fitted = "<a href=\"$download_url\">Download Fitted values</a>";

    #getting the AIC results
    my @data_AIC;

    open(my $F_AIC, "<", $pheno_filepath.".clean.AIC") || die "Can't open result file $pheno_filepath".".clean.AIC";
    my $header_AIC = <$F_AIC>;
    my @h_AIC = split(/\s+/, $header_AIC);
    #my @h = split(',', $header);
    my @spl_AIC;
    foreach my $item_AIC (@h_AIC) {
    push  @spl_AIC, {title => $item_AIC};
  }
    print STDERR "Header: ".Dumper(\@spl_AIC);
    while (<$F_AIC>) {
	chomp;
	my @fields_AIC = split /\s+/;
	foreach my $f_AIC (@fields_AIC) { $f_AIC =~ s/\"//g; }
	push @data_AIC, \@fields_AIC;
    }

    my $basename = basename($pheno_filepath.".clean.AIC");

    copy($pheno_filepath.".clean.AIC", $c->config->{basepath}."/static/documents/tempfiles/spatial_model_files/".$basename);

    my $download_url_AIC = '/documents/tempfiles/spatial_model_files/'.$basename;
    my $download_link_AIC = "<a href=\"$download_url_AIC\">Download Results</a>";


    $c->stash->{rest} = {
	data => \@data,
    headers => \@spl,
	download_link => $download_link,
    data_fitted => \@data_fitted,
    headers_fitted => \@spl_fitted,
    download_link_fitted => $download_link_fitted,
    data_AIC => \@data_AIC,
    headers_AIC => \@spl_AIC,
    download_link_AIC => $download_link_AIC,
    };
}


sub make_R_trait_name {
    my $trait = shift;

    if ($trait =~ /^\d/) {
	$trait = "X".$trait;
    }
    $trait =~ s/\&/\_/g;
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
