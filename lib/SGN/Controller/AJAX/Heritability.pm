use strict;

package SGN::Controller::AJAX::Heritability;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use File::Spec;
use File::Basename qw | basename |;
use File::Copy;
use CXGN::Dataset;
use CXGN::Dataset::File;
use SGN::Model::Cvterm;
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


sub shared_phenotypes: Path('/ajax/heritability/shared_phenotypes') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');

    my $exclude_outliers = $c->req->param('dataset_trait_outliers');

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    my $traits = $ds->retrieve_traits();
    my @trait_info;
    foreach my $t (@$traits) {
          my $tobj = CXGN::Cvterm->new({ schema=>$schema, cvterm_id => $t->[0] });
        push @trait_info, [ $tobj->cvterm_id(), $tobj->name()];
    }

    $c->tempfiles_subdir("heritability_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"heritability_files/trait_XXXXX");

    my $temppath = $c->config->{basepath}."/".$tempfile;
    print STDERR "***** temppath = $temppath\n";
    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, exclude_dataset_outliers => $exclude_outliers, exclude_phenotype_outlier => $exclude_outliers, file_name => $temppath, quotes => 0);
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

sub generate_results: Path('/ajax/heritability/generate_results') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $trait_id = $c->req->param('trait_id');

    print STDERR "The dataset is $dataset_id\n";
    print STDERR $dataset_id;
    print STDERR $trait_id;


    my $exclude_outliers = $c->req->param('dataset_trait_outliers');

    $c->tempfiles_subdir("heritability_files");
    my $heritability_tmp_output = $c->config->{cluster_shared_tempdir}."/heritability_files";
    mkdir $heritability_tmp_output if ! -d $heritability_tmp_output;
    print STDERR "heritability_files subdir = $heritability_tmp_output\n";
    my ($tmp_fh, $tempfile) = tempfile(
      "h2_download_XXXXX",
      DIR=> $heritability_tmp_output,
    );

    print STDERR "TEMPFILE NOW = $tempfile\n";

    my $pheno_filepath = $tempfile . "_phenotype.txt";

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    #my $temppath = $heritability_tmp_output . "/" . $tempfile;
    my $temppath = $tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, exclude_dataset_outliers => $exclude_outliers, exclude_phenotype_outlier => $exclude_outliers, file_name => $temppath, quotes => 0);

    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);



    my $h2File = $tempfile . "_" . "h2File.json";
    my $h2CsvFile = $tempfile . "_" . "h2CsvFile.csv";
    my $errorFile = $tempfile . "_" . "error.txt";


    # The HTTP API accepts the numeric option ID and the browser's legacy name.
    # Resolve both through the same extended-name helper as PhenotypeMatrix.
    my $trait_header = eval {
        _resolve_trait_header($schema, $ds->retrieve_traits(),
            $phenotype_data_ref->[0] || [], $trait_id);
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        return;
    }

    my $cxgn_tools_run_config = {
        backend => $c->config->{backend},
        submit_host=>$c->config->{cluster_host},
        temp_base => $c->config->{cluster_shared_tempdir} . "/heritability_files",
        queue => $c->config->{'web_cluster_queue'},
        do_cleanup => 0,
        # don't block and wait if the cluster looks full
        max_cluster_jobs => 1_000_000_000,
    };
    my $cmd_str = join(" ", map { _shell_quote($_) } (
        "Rscript",
        $c->config->{basepath} . "/R/heritability/h2_blup_rscript.R",
        $pheno_filepath,
        $trait_header,
        $h2File,
        $h2CsvFile,
        $errorFile
    ));

    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};
    my $basepath = $c->config->{basepath};

    my $job = CXGN::Job->new({
        schema => $schema,
        people_schema => $people_schema,
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        basepath => $basepath,

        sp_person_id => $sp_person_id,
        job_type => 'heritability_analysis',
        name => $ds->name().' heritability analysis',
        cmd => $cmd_str,
        cxgn_tools_run_config => $cxgn_tools_run_config,
        results_page =>  '/tools/heritability'
    });
    # my $cmd = CXGN::Tools::Run->new($cxgn_tools_run_config);

    #     print STDERR Dumper $pheno_filepath;

    # # my $job;
    # $job_record->update_status("submitted");
    # $cmd->run_cluster(
    #         "Rscript ",
    #         $c->config->{basepath} . "/R/heritability/h2_blup_rscript.R",
    #         $pheno_filepath,
    #         $trait_id,
    #         $h2File,
    #         $h2CsvFile,
    #         $errorFile,
    #         $job_record->generate_finish_timestamp_cmd()
    # );
    # $cmd->alive;
    # $cmd->is_cluster(1);
    # $cmd->wait;

    $job->submit();

    while ($job->alive()) {
        sleep(1);
    }

    my $finished = $job->retrieve_finish_timestamp();
	if (!$finished) {
		$job->update_status("failed");
	} else {
		$job->update_status("finished");
	}

    my $figure_path = $c->{basepath} . "./documents/tempfiles/heritability_files/";
    copy($h2File, $figure_path);
    copy($h2CsvFile, $figure_path);


    my $h2Filebasename = basename($h2File);
    my $h2File_response = "/documents/tempfiles/heritability_files/" . $h2Filebasename;

    my $h2CsvFilebasename = basename($h2CsvFile);
    my $h2CsvFile_response = "/documents/tempfiles/heritability_files/" . $h2CsvFilebasename;

    my $errors;
    if ( -e $errorFile ) {
        open my $fh, '<', $errorFile or die "Can't open error file $!";
        $errors = do { local $/; <$fh> };
    }

    $c->stash->{rest} = {
        h2Table => $h2File_response,
        dummy_response => $dataset_id,
        error => $errors,
        h2CsvTable => $h2CsvFile_response
    };
}

# Resolve identity before R performs its existing presentation normalization.
# Never infer an ID from a header suffix or choose one of two equal trait names.
sub _resolve_trait_header {
    my ($schema, $traits, $headers, $selected) = @_;
    die "A selected trait is required.\n" if !defined($selected) || $selected eq '';
    my %matches;
    for my $trait (@$traits) {
        my ($id, $name) = @$trait;
        next if !defined($id);
        if ($selected eq "$id" || (defined($name) && $selected eq $name)) {
            $matches{$id} = 1;
        }
    }
    die "The selected trait was not found in the dataset.\n" if !keys(%matches);
    die "The selected trait is ambiguous in the dataset.\n" if keys(%matches) > 1;
    my ($id) = keys %matches;
    my $header = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $id, 'extended');
    die "The selected trait has no declared phenotype header.\n"
        if !defined($header) || $header eq '';
    my @columns = grep { defined($_) && $_ eq $header } @$headers;
    die "The selected trait header was not found in the phenotype data.\n" if !@columns;
    die "The selected trait header is ambiguous in the phenotype data.\n" if @columns > 1;
    return $header;
}

# Keep every raw header (including composed traits and quotes) one shell argument.
sub _shell_quote {
    my $value = shift;
    my @parts = split(/'/, $value, -1);
    return "'" . join("'\"'\"'", @parts) . "'";
}

1
