use strict;

package SGN::Controller::AJAX::Heritability;

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


sub shared_phenotypes: Path('/ajax/heritability/shared_phenotypes') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    my $traits = $ds->retrieve_traits();
    my @trait_info;
    foreach my $t (@$traits) {
          my $tobj = CXGN::Cvterm->new({ schema=>$schema, cvterm_id => $t });
        push @trait_info, [ $tobj->cvterm_id(), $tobj->name()];
    }

    $c->tempfiles_subdir("heritability_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"heritability_files/trait_XXXXX");

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;
    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes => 0);
    my $phenotype_data_ref = $ds2->retrieve_phenotypes();

    print STDERR Dumper(@trait_info);
    $c->stash->{rest} = {
        options => \@trait_info,
        tempfile => $tempfile."_phenotype.txt",
    };
}



sub extract_trait_data :Path('/ajax/heritability/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/heritability_files/".$file);
    print STDERR Dumper($temppath);

    my $F;
    if (! open($F, "<", $temppath)) {
	$c->stash->{rest} = { error => "Can't find data." };
	return;
    }

    my $header = <$F>;
    chomp($header);
    print STDERR Dumper($header);
    my @keys = split("\t", $header);
    print STDERR Dumper($keys[1]);
    for(my $n=0; $n <@keys; $n++) {
        if ($keys[$n] =~ /\|CO\_/) {
        $keys[$n] =~ s/\|CO\_.*//;
        }
    }
    my @data = ();

    while (<$F>) {
	chomp;

	my @fields = split "\t";
	my %line = {};
	for(my $n=0; $n <@keys; $n++) {
	    if (exists($fields[$n]) && defined($fields[$n])) {
		$line{$keys[$n]}=$fields[$n];
	    }
	}
    print STDERR Dumper(\%line);
	push @data, \%line;
    }

    $c->stash->{rest} = { data => \@data, trait => $trait};
}

sub generate_results: Path('/ajax/heritability/generate_results') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $trait_id = $c->req->param('trait_id');
    print"****************************************************************************\n";
    print"The dataset is $dataset_id\n";
    print STDERR $dataset_id;
    print STDERR $trait_id;
    $c->tempfiles_subdir("heritability_files");
    my $heritability_tmp_output = $c->config->{cluster_shared_tempdir}."/heritability_files";
    mkdir $heritability_tmp_output if ! -d $heritability_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "h2_download_XXXXX",
      DIR=> $heritability_tmp_output,
    );

    my $pheno_filepath = $tempfile . "_phenotype.txt";
    

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $temppath = $heritability_tmp_output . "/" . $tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes => 0);

    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);

    
    my $h2File = $tempfile . "_" . "h2File.png";
    my $figure3file = $tempfile . "_" . "figure3.png";
    my $figure4file = $tempfile . "_" . "figure4.png";

    $trait_id =~ tr/ /./;
    $trait_id =~ tr/\//./;

    my $cmd = CXGN::Tools::Run->new({
            backend => $c->config->{backend},
            submit_host=>$c->config->{cluster_host},
            temp_base => $c->config->{cluster_shared_tempdir} . "/heritability_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        });

        print STDERR Dumper $pheno_filepath;

    # my $job;
    $cmd->run_cluster(
            "Rscript ",
            $c->config->{basepath} . "/R/heritability/h2_blup_rscript.R",
            $pheno_filepath,
            $trait_id,
            $figure3file,
            $figure4file,
            $h2File
    );
    $cmd->alive;
    $cmd->is_cluster(1);
    $cmd->wait;

    # my $newpath = $c -> {basepath} . "/home/production/cxgn/sgn/documents/tempfiles/heritability_files";
    # copy($h2File,$newpath) or die "Copy failed: $!";
    # copy($figure3file,$newpath) or die "Copy failed: $!";
    # copy($figure4file,$newpath) or die "Copy failed: $!";
   
    my $figure_path = $c->{basepath} . "./documents/tempfiles/heritability_files/";
    copy($h2File, $figure_path);
    copy($figure3file, $figure_path);
    copy($figure4file, $figure_path);

    my $figure_path = $c->{basepath} . "./documents/tempfiles/heritability_files/";

    
    my $h2Filebasename = basename($h2File);
    my $h2File_response = "/documents/tempfiles/heritability_files/" . $h2Filebasename;

    my $figure3basename = basename($figure3file);
    my $figure3_response = "/documents/tempfiles/heritability_files/" . $figure3basename;
    
    my $figure4basename = basename($figure4file);
    my $figure4_response = "/documents/tempfiles/heritability_files/" . $figure4basename;


    print $h2File_response;
        
    $c->stash->{rest} = {
        h2Table => $h2File_response,
        figure3 => $figure3_response,
        figure4 => $figure4_response,
        dummy_response => $dataset_id
        # dummy_response2 => $trait_id,
    };
}

1

