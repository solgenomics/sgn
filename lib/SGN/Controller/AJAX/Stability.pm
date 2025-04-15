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
use CXGN::Job;
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


sub shared_phenotypes: Path('/ajax/stability/shared_phenotypes') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    my $traits = $ds->retrieve_traits();
    
    $c->tempfiles_subdir("stability_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"stability_files/trait_XXXXX");
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
sub get_method: Path('/ajax/Stability/get_method') : {
    my $self = shift;
    my $c = shift;
    my $method_1 = $c->req->param('method_id');
    print STDERR Dumper($method_1);
    $method_id = $method_1;
    print "The vairable method_id is $method_id \n";
}

my $imput_id;
sub get_imput: Path('/ajax/Stability/get_imput') : {
    my $self = shift;
    my $c = shift;
    $imput_id = $c->req->param('imput_id');
    print STDERR Dumper($imput_id);
    print "Will the data be imputed? $imput_id \n";
}

sub extract_trait_data :Path('/ajax/stability/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/stability_files/".$file);
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
  my %line;
  for(my $n=0; $n <@keys; $n++) {
      if (exists($fields[$n]) && defined($fields[$n])) {
    $line{$keys[$n]}=$fields[$n];
      }
  }
  #print STDERR Dumper(\%line);
  push @data, \%line;
    }

    $c->stash->{rest} = { data => \@data, trait => $trait};
}


sub generate_results: Path('/ajax/stability/generate_results') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $imput_id = $c->req->param('imput_id');
    my $method = $c->req->param('method_id');
    my $trait_id = $c->req->param('trait_id');
    my $exclude_outliers = $c->req->param('dataset_trait_outliers');
    print STDERR "DATASET_ID: $dataset_id\n";
    print STDERR "TRAIT ID: $trait_id\n";
    print STDERR "Method: ".Dumper($method);

    $c->tempfiles_subdir("stability_files");
    my $stability_tmp_output = $c->config->{cluster_shared_tempdir}."/stability_files";
    mkdir $stability_tmp_output if ! -d $stability_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "stability_XXXXX",
      DIR=> $stability_tmp_output,
    );

    my $pheno_filepath = $tempfile . "_phenotype.txt";
    
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    #my $temppath = $stability_tmp_output . "/" . $tempfile;
    my $temppath =  $tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, exclude_dataset_outliers => $exclude_outliers, exclude_phenotype_outlier => $exclude_outliers,file_name => $temppath, quotes => 0);

    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);

    my $newtrait = $trait_id;
    $newtrait =~ s/\s/\_/g;
    $newtrait =~ s/\//\_/g;
    $trait_id =~ tr/ /./;
    $trait_id =~ tr/\//./;

    my $jsonFile = $tempfile . "_" . "json";
    my $graphFile = $tempfile . "_" . "graph.json";
    my $messageFile = $tempfile . "_" . "message.txt";
    my $jsonSummary = $tempfile . "_" . "summary.json";

    $trait_id =~ tr/ /./;
    $trait_id =~ tr/\//./;

    my $cxgn_tools_run_config = {
            backend => $c->config->{backend},
            submit_host=>$c->config->{cluster_host},
            temp_base => $c->config->{cluster_shared_tempdir} . "/stability_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
    };
    my $cmd_str = join(" ",(
        "Rscript ",
        $c->config->{basepath} . "/R/stability/ammi_script.R",
        $pheno_filepath,
        $trait_id,
        $imput_id,
        $method,
        $jsonFile,
        $graphFile,
        $messageFile,
        $jsonSummary
    ));
    my $user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $job_record = CXGN::Job->new({
        schema => $schema,
        people_schema => $people_schema,
        sp_person_id => $user,
        name => $ds->name()." stability analysis",
        job_type => 'phenotypic_analysis',
        cmd => $cmd_str,
        cxgn_tools_run_config => $cxgn_tools_run_config,
        finish_logfile => $c->config->{job_finish_log}
    });

    my $cmd = CXGN::Tools::Run->new($cxgn_tools_run_config);
    $job_record->update_status("submitted");

    $cmd->run_cluster(
            "Rscript ",
            $c->config->{basepath} . "/R/stability/ammi_script.R",
            $pheno_filepath,
            $trait_id,
            $imput_id,
            $method,
            $jsonFile,
            $graphFile,
            $messageFile,
            $jsonSummary,
            $job_record->generate_finish_timestamp_cmd()
    );

    while ($cmd->alive) { 
	sleep(1);
    }

    my $finished = $job_record->read_finish_timestamp();
	if (!$finished) {
		$job_record->update_status("failed");
	} else {
		$job_record->update_status("finished");
	}

    my $figure_path = $c->config->{basepath} . "/static/documents/tempfiles/stability_files/";

    copy($messageFile, $figure_path);
    copy($jsonFile, $figure_path);
    copy($graphFile, $figure_path);
    copy($jsonSummary, $figure_path);


    my $messageFileBasename = basename($messageFile);
    my $messageFile_response = "/documents/tempfiles/stability_files/" . $messageFileBasename;

    my $graphFileBasename = basename($graphFile);
    my $graphFile_response = "/documents/tempfiles/stability_files/" . $graphFileBasename;

    my $jsonFileBasename = basename($jsonFile);
    my $jsonFile_response = "/documents/tempfiles/stability_files/" . $jsonFileBasename;

    my $jsonSummaryBasename = basename($jsonSummary);
    my $jsonSummary_response = "/documents/tempfiles/stability_files/" . $jsonSummaryBasename;
    

    $c->stash->{rest} = {
        myMessage => $messageFile_response,
        myGraph => $graphFile_response,
        JSONfile => $jsonFile_response,
        JSONsummary => $jsonSummary_response,
        dummy_response => $dataset_id
    };
}

1

