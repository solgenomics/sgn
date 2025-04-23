use strict;
use warnings;

package SGN::Controller::AJAX::Solgwas;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use File::Spec qw | catfile|;
use File::Basename qw | basename |;
use File::Copy;
use CXGN::Dataset;
use CXGN::Dataset::File;
#use SGN::Model::Cvterm;
#use CXGN::List;
#use CXGN::List::Validate;
#use CXGN::Trial::Download;
#use CXGN::Phenotypes::PhenotypeMatrix;
#use CXGN::BreederSearch;
use CXGN::Tools::Run;
use CXGN::Job;
use Cwd qw(cwd);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );


sub shared_phenotypes: Path('/ajax/solgwas/shared_phenotypes') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $exclude_outliers = $c->req->param('dataset_trait_outliers');

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    my $traits = $ds->retrieve_traits();
    my @trait_info;
    foreach my $t (@$traits) {
	      my $tobj = CXGN::Cvterm->new({ schema=>$schema, cvterm_id => $t->[0] });
        push @trait_info, [ $tobj->cvterm_id(), $tobj->name()];
    }

    # my $solgwas_tmp_output = $c->config->{cluster_shared_tempdir}."/solgwas_files";
    # mkdir $solgwas_tmp_output if ! -d $solgwas_tmp_output;
    # my ($fh, $tempfile) = tempfile(
    # "trait_XXXXXX",
    #   DIR=> $solgwas_tmp_output,
    # );

    $c->tempfiles_subdir("solgwas_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"solgwas_files/trait_XXXXX");
    #my $tmp_dir = File::Spec->catfile($c->config->{basepath}, 'gwas_tmpdir');
#    my $solgwas_tmp_output = $c->config->{cluster_shared_tempdir}."/solgwas_files";
#    mkdir $solgwas_tmp_output if ! -d $solgwas_tmp_output;
#    my ($tmp_fh, $tempfile) = tempfile(
#      "solgwas_download_XXXXX",
#      DIR=> $solgwas_tmp_output,
#    );
#    my $pheno_filepath = $tempfile . "_phenotype.txt";

    my $temppath = $c->config->{basepath}."/".$tempfile;
#    my $temppath = $solgwas_tmp_output . "/" . $tempfile;
    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, exclude_dataset_outliers => $exclude_outliers, file_name => $temppath, quotes => 0);
    my $phenotype_data_ref = $ds2->retrieve_phenotypes();

#    my $phenotypes = $ds->retrieve_phenotypes();
#    my $trials_ref = $ds->retrieve_trials();
    print STDERR Dumper(@trait_info);
#    my @trials = @$trials_ref;

#    my $values_path = $c->{basepath} . "./documents/tempfiles/solgwas_files/";
#    copy($pheno_filepath,$values_path);

#    my $file_basename = basename($pheno_filepath);
#    my $file_response = "./documents/tempfiles/solgwas_files/" . $file_basename;
#    print STDERR $file_response . "\n";
#    my @co_pheno;
    $c->stash->{rest} = {
        options => \@trait_info,
        tempfile => $tempfile."_phenotype.txt",
#        tempfile => $file_response,
    };
}


sub extract_trait_data :Path('/ajax/solgwas/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/solgwas_files/".$file);
#    my $temppath = File::Spec->catfile($c->config->{cluster_shared_tempdir}, "static/documents/tempfiles/solgwas_files/".$file);
#    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/solgwas_files/solgwas_download_0bDQ5_phenotype.txt");
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
# add this for loop to remove the crop ontology codes from the keys (and the preceding pipes)
    for(my $n=0; $n <@keys; $n++) {
        if ($keys[$n] =~ /\|CO\_/) {
        $keys[$n] =~ s/\|CO\_.*//;
        }
    }
    my @data = ();

    while (<$F>) {
	chomp;

	my @fields = split "\t";
	my %line = ();
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

sub generate_pca: Path('/ajax/solgwas/generate_pca') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $trait_id = $c->req->param('trait_id');
    my $pc_check = $c->req->param('pc_check');
    my $kinship_check = $c->req->param('kinship_check');
	my $forbid_cache = defined($c->req->param('forbid_cache')) ? $c->req->param('forbid_cache') : 0;


    print STDERR $dataset_id;
    print STDERR $trait_id;
    $c->tempfiles_subdir("solgwas_files");
#    my ($fh, $tempfiletest) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_download_XXXXX");
    my $solgwas_tmp_output = $c->config->{cluster_shared_tempdir}."/solgwas_files";
    mkdir $solgwas_tmp_output if ! -d $solgwas_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "solgwas_download_XXXXX",
      DIR=> $solgwas_tmp_output,
    );
    #my $tmp_dir = File::Spec->catfile($c->config->{basepath}, 'gwas_tmpdir');
    my $pheno_filepath = $tempfile . "_phenotype.txt";
    my $geno_filepath = $tempfile . "_genotype.txt";
#    my $pheno_filepath = "." . $tempfile . "_phenotype.txt";
#    my $geno_filepath = "." . $tempfile . "_genotype.txt";
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
#    my $temppath = $c->config->{basepath}."/".$tempfile;
#    my $temppath = $c->config->{cluster_shared_tempdir}."/".$tempfile;
#    my $temppath = $solgwas_tmp_output . "/" . $tempfile;
    my $temppath = "/" . $tempfile;

#    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes => 0);

    ##    my $phenotype_data_ref = $ds->retrieve_phenotypes();
    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);
    my $protocols = $ds->retrieve_genotyping_protocols();
    my $protocol_id;
    foreach (@$protocols) {
        $protocol_id = $_->[0];
    }

#    my ($fh, $tempfile2) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_genotypes_download_XXXXX");
#    my $temppath2 = $c->config->{basepath}."/".$tempfile2;
#    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath2);
    #    $ds2 -> file_name => $temppath2;

    my $filehandle = $ds->retrieve_genotypes($protocol_id,$geno_filepath, $c->config->{cache_file_path}, $c->config->{cluster_shared_tempdir}, $c->config->{backend}, $c->config->{cluster_host}, $c->config->{'web_cluster_queue'}, $c->config->{basepath}, $forbid_cache);
#    my $base_filename = $$filehandle;
    print STDERR $filehandle . "\n";
#    print STDERR $base_filename . "\n";
#    $ds-> @$trials_ref = retrieve_genotypes();
    my $newtrait = $trait_id;
    $newtrait =~ s/\s/\_/g;
    $newtrait =~ s/\//\_/g;
    print STDERR $newtrait . "\n";
#    my $figure1file = "." . $tempfile . "_" . $newtrait . "_figure1.png";
#    my $figure2file = "." . $tempfile . "_" . $newtrait . "_figure2.png";
#    my $figure3file = "." . $tempfile . "_" . $newtrait . "_figure3.png";
#    my $figure4file = "." . $tempfile . "_" . $newtrait . "_figure4.png";
    my $tempfile2 = $tempfile;
    my $figure1file = $tempfile . "_" . $newtrait . "_figure1.png";
    my $figure2file = $tempfile . "_" . $newtrait . "_figure2.png";
    my $figure3file = $tempfile . "_" . $newtrait . "_figure3.png";
    my $figure4file = $tempfile . "_" . $newtrait . "_figure4.png";

    $trait_id =~ tr/ /./;
    $trait_id =~ tr/\//./;
#    my $clean_cmd = "rm /home/vagrant/cxgn/sgn/documents/tempfiles/solgwas_files/SolGWAS_Figure*.png";
#    system($clean_cmd);
    my $geno_filepath2 = $tempfile . "_genotype.txt";
#    my $geno_filepath2 = $base_filename . "_genotype_edit.txt";
#    my $edit_cmd = "sed -e '1 s/\^/row.names\t/' " . $base_filename . " > " . $geno_filepath2;
#    system($edit_cmd);
#    my $geno_filepath3 = "." . $tempfile . "_genotype_edit_subset.txt";
    my $geno_filepath3 = $tempfile . "_genotype_edit_subset.txt";

#    my $trim_cmd = "cut -f 1-50 " . $geno_filepath2 . " > " . $geno_filepath3;
#    system($trim_cmd);

#    open my $filehandle_in2,  "<", "$geno_filepath2"  or die "Could not open $geno_filepath2: $!\n";
    open my $filehandle_out, ">", "$geno_filepath2" or die "Could not create $geno_filepath2: $!\n";

    my $marker_total;

    while ( my $line = <$filehandle> ) {
        my @sample_line = (split /\s+/, $line);
        $marker_total = scalar(@sample_line);
        print $filehandle_out $line;
    }
    close $filehandle;
    close $filehandle_out;

#
# # Hardcoded number of markers to be selected - make this selectable by user?
#     my $markers_selected = 500;
# #    my @column_selection = (0,2);
# # Initialize column selection so the row.names are selected first
#     my @column_selection = (0);
#     my %columns_seen;
#     for (my $i=0; $i <= $markers_selected; $i++) {
#         my $random_current = int(rand($marker_total));
#         redo if $columns_seen{$random_current}++;
#         push @column_selection, $random_current;
#         print STDERR $random_current . "\n";
#     }
#
#     open my $filehandle_in, "<", "$geno_filepath2"  or die "Could not open $geno_filepath2: $!\n";
#     open my $filehandle_out2, ">", "$geno_filepath3" or die "Could not create $geno_filepath3: $!\n";
#
# #    foreach my $item (@column_selection) {
#     while ( my $line = <$filehandle_in> ) {
#         my $curr_line;
#         my @first_item = (split /\s+/, $line);
#         foreach my $item (@column_selection) {
#             $curr_line .= $first_item[$item] . "\t";
#         }
# #           $curr_line .= "\n";
#         print STDERR $curr_line . "\n";
#         print $filehandle_out2 "$curr_line\n";
#     }
#
#     close $filehandle_in;
#     close $filehandle_out2;

#    my $cmd = "Rscript " . $c->config->{basepath} . "/R/solgwas/solgwas_script.R " . $pheno_filepath . " " . $geno_filepath3 . " " . $trait_id . " " . $figure3file . " " . $figure4file . " " . $pc_check . " " . $kinship_check;
#    system($cmd);

    my $cmd = CXGN::Tools::Run->new(
        {
            backend => $c->config->{backend},
            submit_host => $c->config->{cluster_host},
            temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );
    $cmd->run_cluster(
            "Rscript ",
            $c->config->{basepath} . "/R/solgwas/solgwas_genoPCA_script.R",
            $geno_filepath2,
            $figure2file,
    );
    $cmd->is_cluster(1);
    $cmd->wait;


    my $figure_path = "./documents/tempfiles/solgwas_files/";
    copy($figure2file,$figure_path);

    my $figure2basename = basename($figure2file);
    my $figure2file_response = "/documents/tempfiles/solgwas_files/" . $figure2basename;

    $c->stash->{rest} = {
        figure2 => $figure2file_response,
        dummy_response => $dataset_id,
        dummy_response2 => $trait_id,
    };
}


sub generate_results: Path('/ajax/solgwas/generate_results') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $trait_id = $c->req->param('trait_id');
    my $pc_check = $c->req->param('pc_check');
    my $kinship_check = $c->req->param('kinship_check');
	my $forbid_cache = defined($c->req->param('forbid_cache')) ? $c->req->param('forbid_cache') : 0;
    my $exclude_outliers = $c->req->param('dataset_trait_outliers');

    print STDERR $dataset_id;
    print STDERR $trait_id;
    $c->tempfiles_subdir("solgwas_files");
#    my ($fh, $tempfiletest) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_download_XXXXX");
    my $solgwas_tmp_output = $c->config->{cluster_shared_tempdir}."/solgwas_files";
    mkdir $solgwas_tmp_output if ! -d $solgwas_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "solgwas_download_XXXXX",
      DIR=> $solgwas_tmp_output,
    );
    #my $tmp_dir = File::Spec->catfile($c->config->{basepath}, 'gwas_tmpdir');
    my $pheno_filepath = $tempfile . "_phenotype.txt";
    my $geno_filepath = $tempfile . "_genotype.txt";
#    my $pheno_filepath = "." . $tempfile . "_phenotype.txt";
#    my $geno_filepath = "." . $tempfile . "_genotype.txt";
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
#    my $temppath = $c->config->{basepath}."/".$tempfile;
##    my $temppath = $c->config->{cluster_shared_tempdir}."/".$tempfile;
    #    my $temppath = $solgwas_tmp_output . "/" . $tempfile;
    my $temppath = $tempfile;

#    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, exclude_dataset_outliers => $exclude_outliers, file_name => $temppath, quotes => 0);

##    my $phenotype_data_ref = $ds->retrieve_phenotypes();
    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);
    my $protocols = $ds->retrieve_genotyping_protocols();
    my $protocol_id;
    foreach (@$protocols) {
	$protocol_id = $_->[0];
    }

#    my ($fh, $tempfile2) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_genotypes_download_XXXXX");
#    my $temppath2 = $c->config->{basepath}."/".$tempfile2;
#    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath2);
    #    $ds2 -> file_name => $temppath2;

    my %chromList;
    my %posList;
    my $name;
    my @row;
    my $chrom;
    my $pos;
    my $q = "SELECT s.value->>'name', s.value->>'chrom', s.value->>'pos' from nd_protocolprop, jsonb_each(nd_protocolprop.value) s(key, value) where type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'vcf_map_details_markers') and nd_protocol_id = $protocol_id";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    while (@row = $sth->fetchrow_array) {
	$name = $row[0];
	$chromList{$name} = $row[1];
        $posList{$name} = $row[2];
    }

    my $filehandle = $ds->retrieve_genotypes($protocol_id,$geno_filepath, $c->config->{cache_file_path}, $c->config->{cluster_shared_tempdir}, $c->config->{backend}, $c->config->{cluster_host}, $c->config->{'web_cluster_queue'}, $c->config->{basepath}, $forbid_cache);
#    my $base_filename = $$filehandle;
    print STDERR $filehandle . "\n";
#    print STDERR $base_filename . "\n";
#    $ds-> @$trials_ref = retrieve_genotypes();
    my $newtrait = $trait_id;
    $newtrait =~ s/\s/\_/g;
    $newtrait =~ s/\//\_/g;
    $newtrait =~ s/[|%()]/\./g;
    print STDERR $newtrait . "\n";
#    my $figure1file = "." . $tempfile . "_" . $newtrait . "_figure1.png";
#    my $figure2file = "." . $tempfile . "_" . $newtrait . "_figure2.png";
#    my $figure3file = "." . $tempfile . "_" . $newtrait . "_figure3.png";
#    my $figure4file = "." . $tempfile . "_" . $newtrait . "_figure4.png";
    my $tempfile2 = $tempfile;
    my $figure1file = $tempfile . "_" . $newtrait . "_figure1.png";
    my $figure2file = $tempfile . "_" . $newtrait . "_figure2.png";
    my $figure3file = $tempfile . "_" . $newtrait . "_figure3.png";
    my $figure4file = $tempfile . "_" . $newtrait . "_figure4.png";
    my $gwasResultsPhenoCsv = $tempfile . "_" . $newtrait . "_gwasresults_pheno.csv";

    $trait_id =~ tr/ /./;
    $trait_id =~ tr/\//./;
#    my $clean_cmd = "rm /home/vagrant/cxgn/sgn/documents/tempfiles/solgwas_files/SolGWAS_Figure*.png";
#    system($clean_cmd);
    my $geno_filepath2 = $tempfile . "_genotype.txt";
#    my $geno_filepath2 = $base_filename . "_genotype_edit.txt";
#    my $edit_cmd = "sed -e '1 s/\^/row.names\t/' " . $base_filename . " > " . $geno_filepath2;
#    system($edit_cmd);
#    my $geno_filepath3 = "." . $tempfile . "_genotype_edit_subset.txt";
    my $geno_filepath3 = $tempfile . "_genotype_edit_subset.txt";

#    my $trim_cmd = "cut -f 1-50 " . $geno_filepath2 . " > " . $geno_filepath3;
#    system($trim_cmd);

    open my $filehandle_out, ">", "$geno_filepath2" or die "Could not create $geno_filepath2: $!\n";
    my $line = <$filehandle>;
    my @sample_line = (split /\t/, $line);
    splice(@sample_line, 1, 0, "chrom");
    splice(@sample_line, 2, 0, "pos");
    $line = join("\t", @sample_line);
    print $filehandle_out $line;
    my $marker_total;

    while ( my $line = <$filehandle> ) {
        @sample_line = split(/\t/, $line);
	if ($chromList{$sample_line[0]}) {
	    $chrom = $chromList{$sample_line[0]};
	} elsif ($sample_line[0] =~ /\_/) {
	    ($chrom, undef) = split /\_/, $sample_line[0];
	    print STDERR "Warning! no chrom data, using $chrom extracted from $sample_line[0]\n";
	} else {
	    $chrom = "";
	}
	if ($posList{$sample_line[0]}) {
	    $pos = $posList{$sample_line[0]};
	} elsif ($sample_line[0] =~ /\_/) {
	    (undef, $pos) = split /\_/, $sample_line[0];
	    print STDERR "Warning! No position data, using $pos extracted from $sample_line[0]\n";
	} else {
	    $pos = "";
	}
	splice(@sample_line, 1, 0, $chrom);
        splice(@sample_line, 2, 0, $pos);
        $line = join("\t", @sample_line);
        print $filehandle_out $line;
    }
    close $filehandle;
    close $filehandle_out;    

#
# # Hardcoded number of markers to be selected - make this selectable by user?
#     my $markers_selected = 500;
# #    my @column_selection = (0,2);
# # Initialize column selection so the row.names are selected first
#     my @column_selection = (0);
#     my %columns_seen;
#     for (my $i=0; $i <= $markers_selected; $i++) {
#         my $random_current = int(rand($marker_total));
#         redo if $columns_seen{$random_current}++;
#         push @column_selection, $random_current;
#         print STDERR $random_current . "\n";
#     }
#
#     open my $filehandle_in, "<", "$geno_filepath2"  or die "Could not open $geno_filepath2: $!\n";
#     open my $filehandle_out2, ">", "$geno_filepath3" or die "Could not create $geno_filepath3: $!\n";
#
# #    foreach my $item (@column_selection) {
#     while ( my $line = <$filehandle_in> ) {
#         my $curr_line;
#         my @first_item = (split /\s+/, $line);
#         foreach my $item (@column_selection) {
#             $curr_line .= $first_item[$item] . "\t";
#         }
# #           $curr_line .= "\n";
#         print STDERR $curr_line . "\n";
#         print $filehandle_out2 "$curr_line\n";
#     }
#
#     close $filehandle_in;
#     close $filehandle_out2;

#    my $cmd = "Rscript " . $c->config->{basepath} . "/R/solgwas/solgwas_script.R " . $pheno_filepath . " " . $geno_filepath3 . " " . $trait_id . " " . $figure3file . " " . $figure4file . " " . $pc_check . " " . $kinship_check;
#    system($cmd);

    my $cxgn_tools_run_config = {
            backend => $c->config->{backend},
            submit_host => $c->config->{cluster_host},
            temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        };
    my $cmd = CXGN::Tools::Run->new(
        $cxgn_tools_run_config
    );
    my $cmd_str = join(" ",(
        "Rscript ",
        $c->config->{basepath} . "/R/solgwas/solgwas_script.R",
        $pheno_filepath,
        $geno_filepath2,
        $trait_id,
        $figure3file,
        $figure4file,
        $pc_check,
        $kinship_check,
        $gwasResultsPhenoCsv
    ));

    my $user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $job = CXGN::Job->new({
        schema => $schema,
        people_schema => $people_schema,
        sp_person_id => $user,
        job_type => 'solGWAS_analysis',
        name => $ds->name().' solGWAS',
        cxgn_tools_run_config => $cxgn_tools_run_config,
        cmd => $cmd_str,
        finish_logfile => $c->config->{job_finish_log},
        results_page => '/tools/solgwas'
    });

    $job->submit();

    while($job->alive()){
        sleep(1);
    }

    # $job_record->update_status("submitted");

    # my $finish_timestamp_cmd = $job_record->generate_finish_timestamp_cmd();

    # $cmd->run_cluster(
    #         "Rscript ",
    #         $c->config->{basepath} . "/R/solgwas/solgwas_script.R",
    #         $pheno_filepath,
    #         $geno_filepath2,
    #         $trait_id,
    #         $figure3file,
    #         $figure4file,
    #         $pc_check,
    #         $kinship_check,
    #         $gwasResultsPhenoCsv,
    #         $finish_timestamp_cmd
    # );

    # $cmd->is_cluster(1);
    # $cmd->wait;

    my $finished = $job->read_finish_timestamp();
	if (!$finished) {
		$job->update_status("failed");
	} else {
		$job->update_status("finished");
	}

    my $figure_path = "./documents/tempfiles/solgwas_files/";
    copy($figure3file,$figure_path);
    copy($figure4file,$figure_path);
    copy($gwasResultsPhenoCsv,$figure_path);
#    my $figure3basename = $figure3file;

#    $figure3basename =~ s/\/export\/prod\/tmp\/solgwas\_files\///;
    my $figure3basename = basename($figure3file);
    my $figure3file_response = "/documents/tempfiles/solgwas_files/" . $figure3basename;
    my $figure4basename = basename($figure4file);
    my $figure4file_response = "/documents/tempfiles/solgwas_files/" . $figure4basename;
    my $gwasResultsCsvBasename = basename($gwasResultsPhenoCsv);
    my $gwasCsv_response = "/documents/tempfiles/solgwas_files/" . $gwasResultsCsvBasename;
#    $figure4file_response =~ s/\.\/static//;
    $c->stash->{rest} = {
        figure3         => $figure3file_response,
        figure4         => $figure4file_response,
        dummy_response  => $dataset_id,
        dummy_response2 => $trait_id,
        gwas_csv_response  => $gwasCsv_response,
    };
}

1;
