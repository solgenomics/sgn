use strict;

package SGN::Controller::AJAX::Stability;

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
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );


sub shared_phenotypes: Path('/ajax/stability/shared_phenotypes') : {
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

    
    $c->tempfiles_subdir("stability_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"stability_files/trait_XXXXX");
    $people_schema = $c->dbic_schema("CXGN::People::Schema");
    $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;
    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
    my $phenotype_data_ref = $ds2->retrieve_phenotypes();

    print STDERR Dumper(@trait_info);
    $c->stash->{rest} = {
        options => \@trait_info,
        tempfile => $tempfile."_phenotype.txt",
#        tempfile => $file_response,
    };
}


sub extract_trait_data :Path('/ajax/stability/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "/tmp/vagrant/SGN-site/stability_files/".$file);
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

sub generate_results: Path('/ajax/stability/generate_results') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $trait_id = $c->req->param('trait_id');
    print STDERR $dataset_id;
    print STDERR $trait_id;
    $c->tempfiles_subdir("stability_files");
    my $stability_tmp_output = $c->config->{cluster_shared_tempdir}."/stability_files";
    mkdir $stability_tmp_output if ! -d $stability_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "stability_download_XXXXX",
      DIR=> $stability_tmp_output,
    );

    my $pheno_filepath = $tempfile . "_phenotype.txt";

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $temppath = $stability_tmp_output . "/" . $tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);

    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);

    my $newtrait = $trait_id;
    $newtrait =~ s/\s/\_/g;
    $newtrait =~ s/\//\_/g;
    print STDERR $newtrait . "\n";

    my $figure3file = $tempfile . "_" . $newtrait . "_figure3.png";
    my $figure4file = $tempfile . "_" . $newtrait . "_figure4.png";

    $trait_id =~ tr/ /./;
    $trait_id =~ tr/\//./;


   # my $cmd = "Rscript " . $c->config->{basepath} . "/R/stability/2_blup_rscript.R " . $pheno_filepath . " " . $trait_id;
   # system($cmd);
    my $cmd = CXGN::Tools::Run->new(
        {
            backend => $c->config->{backend},
            submit_host => $c->config->{cluster_host},
            temp_base => $c->config->{cluster_shared_tempdir} . "/stability_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );
    $cmd->run_cluster(
            "Rscript ",
            $c->config->{basepath} . "/R/stability/ammi_script.R",
            $pheno_filepath
    );
    $cmd->alive;
    $cmd->is_cluster(1);
    $cmd->wait;

     my $figure_path = $c->{basepath} . "./documents/tempfiles/stability_files/";
    copy($figure3file,$figure_path);
    copy($figure4file,$figure_path);
#    my $figure3basename = $figure3file;

#    $figure3basename =~ s/\/export\/prod\/tmp\/solgwas\_files\///;
    my $figure3basename = basename($figure3file);
    my $figure3file_response = "/documents/tempfiles/stability_files/" . $figure3basename;
    my $figure4basename = basename($figure4file);
    my $figure4file_response = "/documents/tempfiles/stability_files/" . $figure4basename;
#    $figure4file_response =~ s/\.\/static//;
    $c->stash->{rest} = {
        figure3 => $figure3file_response,
        figure4 => $figure4file_response,
        dummy_response => $dataset_id,
        dummy_response2 => $trait_id,
    };
}

    # my $figure_path = $c->{basepath} . "./documents/tempfiles/h2_files/";
