use strict;

package SGN::Controller::AJAX::GCPC;

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
use CXGN::Job;
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


# sub shared_phenotypes: Path('/ajax/gcpc/shared_phenotypes') : {
#     my $self = shift;
#     my $c = shift;
#     my $dataset_id = $c->req->param('dataset_id');
#     my $people_schema = $c->dbic_schema("CXGN::People::Schema");
#     my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
#     my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
#     my $traits = $ds->retrieve_traits();

#     $c->tempfiles_subdir("gcpc_files");
#     my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"gcpc_files/trait_XXXXX");
#     $people_schema = $c->dbic_schema("CXGN::People::Schema");
#     $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
#     my $temppath = $c->config->{basepath}."/".$tempfile;
#     my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes => 0);
#     my $phenotype_data_ref = $ds2->retrieve_phenotypes();

#     print STDERR Dumper($traits);
#     $c->stash->{rest} = {
#         options => $traits,
#         tempfile => $tempfile."_phenotype.txt",
# #        tempfile => $file_response,
#     };
# }


sub factors :Path('/ajax/gcpc/factors') Args(0) {
    my $self = shift;
    my $c = shift;

    my $dataset_id = $c->req->param('dataset_id');

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);


    $c->tempfiles_subdir("gcpc_files");
    my $gcpc_tmp_output = $c->config->{cluster_shared_tempdir}."/gcpc_files";
    mkdir $gcpc_tmp_output if ! -d $gcpc_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "gcpc_download_XXXXX",
      DIR=> $gcpc_tmp_output,
    );

    my $temppath =  $tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes=>0);

     $ds->retrieve_phenotypes();


    open(my $PF, "<", $temppath."_phenotype.txt") || die "Can't open pheno file $temppath"."_phenotype.txt";
    open(my $CLEAN, ">", $temppath."_phenotype.txt.clean") || die "Can't open pheno_filepath clean for writing";

    my $header = <$PF>;
    chomp($header);

    my @fields = split /\t/, $header;

    my @file_traits = @fields[ 39 .. @fields-1 ];
    my @other_headers = @fields[ 0 .. 38 ];

    #print STDERR "FIELDS: ".Dumper(\@file_traits);

    foreach my $t (@file_traits) {
	$t = make_R_trait_name($t);
    }

    #print STDERR "FILE TRAITS: ".Dumper(\@file_traits);

    my @new_header = (@other_headers, @file_traits);
    print $CLEAN join("\t", @new_header)."\n";

    while(<$PF>) {
	print $CLEAN $_;
    }


    my $pf = CXGN::Phenotypes::File->new( { file => $temppath."_phenotype.txt.clean" });


    my @factor_select;

    # only use if factor has multiple levels, start from appropriate hardcoded list
    #
    my @factors = qw | studyYear studyDesign plantingDate locationName replicate rowNumber colNumber|;
    foreach my $factor (@factors) {
	if ($pf->distinct_levels_for_factor($factor) > 1) {
    print STDERR "Processing factor $factor\n";

	    push @factor_select, "<h4 style=\"padding-left: 10px\">".$factor."</h4> \&emsp\;
      <input type = radio name=\"$factor\_factor\" value=\"fixed\"> fixed </input>\&emsp\;
      <input type = radio name=\"$factor\_factor\" value=\"random\"> random </input> \&emsp\;
      <input type = radio name=\"$factor\_factor\" value=\"None\"> None</input><br />";
	}

    }
    unshift @factor_select, "<b style=\"font-size:15px\">Select fixed and random factors to be included in the model</b></br>";
    push @factor_select, "<h4 style=\"padding-left: 10px\">germplasmName</h4> \&emsp\;
                          <input type = radio name=\"random\" value=\"random\" checked> random </input> \&emsp\;";

    print STDERR "FACTORS: ".Dumper(\@factors);
    print STDERR "FACTOR_SELECT: ".Dumper(\@factor_select);
print STDERR "factors in object: ".join(",",@{$pf->factors});
    $c->stash->{rest} = {html => \@factor_select} ;

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
    #my $factors = $c->req->param('factors');
    my @factors = ("studyYear", "programName" , "studyName", "studyDesign" , "plantingDate", "locationName",  "replicate" , "rowNumber",  "colNumber" , "germplasmName");
    #my %factor_param;
    my @fixed_factors;
    my @random_factors;

    foreach my $f (@factors) {
      if ($c->req->param($f."_factor") eq 'random' ) {

        push @random_factors,$f;
      }
      if ($c->req->param($f."_factor") eq 'fixed' ) {

        push @fixed_factors,$f;
      }

      #$factor_param{$f."_factor"} = $c->req->param($f."_factor");
    }
    my $fixed_factors = join(",",@fixed_factors);
    my $random_factors = join(",",@random_factors);

    print STDERR "DATASET_ID: $dataset_id\n";
    print STDERR "SELECTION INDEX ID: $sin_list_id\n";
    print STDERR "FIXED FACTORS: $fixed_factors\n";
    print STDERR "RANDOM FACTORS: $random_factors\n";

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $list = CXGN::List->new( { dbh => $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id)->storage->dbh() , list_id => $sin_list_id });
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

    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    #my $temppath = $stability_tmp_output . "/" . $tempfile;
    my $temppath =  $tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes=>0);


    # check if the plant_sex_variable_name is set in sgn_local.conf
    # and get the trait_ontolog_db_name as well as its associated cv.name.
    # retrieve .
    #
    my $plant_sex_variable_name = $c->config->{plant_sex_variable_name};
    my @cv_names = SGN::Model::Cvterm->get_cv_names_from_db_name($schema, $c->config->{trait_ontology_db_name});

    my $plant_sex_cvterm_id;
    my $plant_sex_variable_name_R = "";

    print STDERR "CVNAMES = ".Dumper(\@cv_names);
    if (@cv_names && $plant_sex_variable_name) {
	$plant_sex_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $plant_sex_variable_name, $cv_names[0])->cvterm_id();
    }

    my $accession_sex_scores;

    if ($plant_sex_variable_name && $plant_sex_cvterm_id) {
	my $accessions = $ds->accessions();

	print STDERR "ACCESSIONS: ".Dumper($accessions);

	my @accession_ids = map { $_->[0] } $accessions;
	$accession_sex_scores = $self->get_trait_for_accessions($c, $plant_sex_cvterm_id, \@accession_ids);
	$plant_sex_variable_name_R = make_R_trait_name($plant_sex_variable_name);   
    
    }
    else {
	print STDERR "NOT RETRIEVING sEX DATA with $plant_sex_variable_name, $plant_sex_cvterm_id\n";
    }

    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);

    #print STDERR "PHENOTYPES REF: ".Dumper($phenotype_data_ref);


    open(my $PF, "<", $pheno_filepath) || die "Can't open pheno file $pheno_filepath";
    open(my $CLEAN, ">", $pheno_filepath.".clean") || die "Can't open pheno_filepath clean for writing";

    my $header = <$PF>;
    chomp($header);

    my @fields = split /\t/, $header;

    my @file_traits = @fields[ 39 .. @fields-1 ];
    my @other_headers = @fields[ 0 .. 38 ];

    if ($plant_sex_cvterm_id) {
	print STDERR "Adding $plant_sex_variable_name to the file trait list...\n";
	push @file_traits, $plant_sex_variable_name;
    }

    print STDERR "FIELDS: ".Dumper(\@file_traits);

    foreach my $t (@file_traits) {
	$t = make_R_trait_name($t);
    }

    print STDERR "FILE TRAITS: ".Dumper(\@file_traits);

    my @new_header = (@other_headers, @file_traits);
    print $CLEAN join("\t", @new_header)."\n";

    my $last_index = scalar(@new_header)-1;

    while(<$PF>) {
	chomp;
	my @f = split /\t/;

	# add a column with the plant sex score if the cvterm is defined
	#
	if ($plant_sex_cvterm_id) {
	    my $acc = $f[18];
	    print STDERR "ACCESSION = $acc has score $accession_sex_scores->{$acc}\n";

	    if (defined($accession_sex_scores->{$acc})) { $f[$last_index]= $accession_sex_scores->{$acc}; }
	}
	print $CLEAN join("\t", @f)."\n";
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

    my $forbid_cache = 1;

    print STDERR "GENOFILE PATH = $geno_filepath\n";
    print STDERR "cache file path = ".$c->config->{cache_file_path}." CLUSTER SHARED TEMPDIR: ".$c->config->{cluster_shared_tempdir}."\n";


    my @accession_names = map { $_->[1] } @{$ds->retrieve_accessions()};

    print STDERR "ACCESSION NAME COUNT: ".scalar(@accession_names)."\n";
    print STDERR "FIRST 10: ".join(",", @accession_names[0..9])."\n";

    my $genotype_data_fh = $ds->retrieve_genotypes( $protocol->[0], $geno_filepath, $c->config->{cache_file_path}, $c->config->{cluster_shared_tempdir}, $c->config->{backend}, $c->config->{cluster_host},  $c->config->{'web_cluster_queue'}, $c->config->{basepath}, $forbid_cache);

    print STDERR "NOW SUBMITTING R JOB...\n";
    my $cmd_str = join(" ", (
        "Rscript ",
            $c->config->{basepath} . "/R/GCPC.R",
            $pheno_filepath.".clean",
            $geno_filepath,
            "'".$si_traits."'",
            "'".$si_weights."'",
            "'".$plant_sex_variable_name_R."'",
        "'".$fixed_factors."'",
        "'".$random_factors."'",
    ));
    my $cxgn_tools_run_config = {
        backend => $c->config->{backend},
        submit_host=>$c->config->{cluster_host},
        temp_base => $c->config->{cluster_shared_tempdir} . "/gcpc_files",
        queue => $c->config->{'web_cluster_queue'},
        do_cleanup => 0,
        # don't block and wait if the cluster looks full
        max_cluster_jobs => 1_000_000_000,
    };
    my $job = CXGN::Job->new({
        schema => $schema,
        people_schema => $people_schema, 
        sp_person_id => $sp_person_id,
        job_type => 'genomic_prediction',
        name => $ds->name().' GCPC',
        cmd => $cmd_str,
        cxgn_tools_run_config => $cxgn_tools_run_config,
        finish_logfile => $c->config->{job_finish_log},
        results_page => '/tools/gcpc'
    });
#     my $cmd = CXGN::Tools::Run->new($cxgn_tools_run_config);
#     $job_record->update_status("submitted");
#     $cmd->run_cluster(
# 	"Rscript ",
# 	$c->config->{basepath} . "/R/GCPC.R",
# 	$pheno_filepath.".clean",
# 	$geno_filepath,
# 	"'".$si_traits."'",
# 	"'".$si_weights."'",
# 	"'".$plant_sex_variable_name_R."'",
#   "'".$fixed_factors."'",
#   "'".$random_factors."'",
#   $job_record->generate_finish_timestamp_cmd()
#   );

    # while ($cmd->alive) {
	# sleep(1);
    # }

    $job->submit();

    while($job->alive()){
        sleep(1);
    }

    my $finished = $job->read_finish_timestamp();
	if (!$finished) {
		$job->update_status("failed");
	} else {
		$job->update_status("finished");
	}

#    my $figure_path = $c->config->{basepath} . "/static/documents/tempfiles/stability_files/";

    my @data;
    my @spl;
    my $basename;
    my $imagename;
    eval {
        open(my $F, "<", $pheno_filepath.".clean.out") || die "Can't open result file $pheno_filepath".".clean.out";
        my $header = <$F>;
        my @h = split(',', $header);
        foreach my $item (@h) {
            push  @spl, {title => $item};
        }
        print STDERR "Header: ".Dumper(\@spl);
        while (<$F>) {
	        chomp;
	        my @fields = split /\,/;
	        foreach my $f (@fields) { $f =~ s/\"//g; }
	        push @data, \@fields;
        }

        print STDERR "FORMATTED DATA: ".Dumper(\@data);

        $basename = basename($pheno_filepath.".clean.out");
        $imagename = basename($pheno_filepath.".clean.png");

        my $statsfile = $pheno_filepath.".clean.summary";
    
        copy($pheno_filepath.".clean.out", $c->config->{basepath}."/static/documents/tempfiles/gcpc_files/".$basename);

        copy($pheno_filepath.".clean.png", $c->config->{basepath}."/static/documents/tempfiles/gcpc_files/".$imagename);
    };
    if ($@){
        $c->stash->{rest} = { 
            error=> $@
        };
        return;
    }

    #print STDERR "FORMATTED DATA: ".Dumper(\@data);

    my $basename = basename($pheno_filepath.".clean.out");
    my $imagename = basename($pheno_filepath.".clean.png");

    my $statsfile = $pheno_filepath.".clean.summary";
    
    copy($pheno_filepath.".clean.out", $c->config->{basepath}."/static/documents/tempfiles/gcpc_files/".$basename);

    copy($pheno_filepath.".clean.png", $c->config->{basepath}."/static/documents/tempfiles/gcpc_files/".$imagename);
    
    my $download_url = '/documents/tempfiles/gcpc_files/'.$basename;
    my $histogram_image = '/documents/tempfiles/gcpc_files/'.$imagename;
    my $download_link = "<a href=\"$download_url\" download>Download Results</a>";

    $c->stash->{rest} = {
	data => \@data,
	header => \@spl,
	histogram => $histogram_image,
	download_link => $download_link,
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


sub get_trait_for_accessions {
    my $self = shift;
    my $c = shift;
    my $trait_id = shift;
    my $accessions = shift;

    print STDERR "GET TRAIT FOR ACCESSIONS...\n";
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    $c->tempfiles_subdir("gcpc_files");
    my $gcpc_tmp_output = $c->config->{cluster_shared_tempdir}."/gcpc_files";
    mkdir $gcpc_tmp_output if ! -d $gcpc_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
	"gcpc_trait_phenotypes_XXXXX",
      DIR=> $gcpc_tmp_output,
    );
    my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, quotes=>0);

    $ds->accessions($accessions);
    $ds->traits( [ $trait_id ]);

    my $phenotypes = $ds->retrieve_phenotypes();

    my $header = shift(@$phenotypes);

    my %accession_scores;

    foreach my $p (@$phenotypes) {
	my $accession_name = $p->[18];
	my $score = $p->[39];

	$accession_scores{$accession_name}->{$score}++;
    }

#    my @highest_accession_scores = ();
    my %highest_accession_scores = ();

    foreach my $acc (keys %accession_scores) {
	my $highest_score_count = 0;
	my $highest_score = 0;
	foreach my $score (keys %{$accession_scores{$acc}}) {
	    if ($accession_scores{$acc}->{$score} > $highest_score_count) {
		$highest_score_count = $accession_scores{$acc}->{$score};
		$highest_score = $score;
	    }
	}
	#push @highest_accession_scores, [ $acc, $highest_score ];
	$highest_accession_scores{$acc}=$highest_score;
    }

    #xprint STDERR "PHENOTYPES RETRIEVED: ".Dumper($phenotypes);

    print STDERR "SEXES: ".Dumper(\%highest_accession_scores);

    return \%highest_accession_scores;
}


1;
