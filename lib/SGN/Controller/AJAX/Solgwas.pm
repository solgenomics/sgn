use strict;

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
use Cwd qw(cwd);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );


sub shared_phenotypes: Path('/ajax/solgwas/shared_phenotypes') : {
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

    # my $solgwas_tmp_output = $c->config->{cluster_shared_tempdir}."/solgwas_files";
    # mkdir $solgwas_tmp_output if ! -d $solgwas_tmp_output;
    # my ($fh, $tempfile) = tempfile(
    # "trait_XXXXXX",
    #   DIR=> $solgwas_tmp_output,
    # );

    $c->tempfiles_subdir("solgwas_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"solgwas_files/trait_XXXXX");
    #my $tmp_dir = File::Spec->catfile($c->config->{basepath}, 'gwas_tmpdir');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;
#    my $temppath = $solgwas_tmp_output."/".$tempfile;
    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
    my $phenotype_data_ref = $ds2->retrieve_phenotypes();

#    my $phenotypes = $ds->retrieve_phenotypes();
#    my $trials_ref = $ds->retrieve_trials();
    print STDERR Dumper(@trait_info);
#    my @trials = @$trials_ref;

#    my @co_pheno;
    $c->stash->{rest} = {
        options => \@trait_info,
        tempfile => $tempfile."_phenotype.txt",
    };
}


sub extract_trait_data :Path('/ajax/solgwas/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

#    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/solgwas_files/".$file);
    my $temppath = File::Spec->catfile($c->config->{cluster_shared_tempdir}, "static/documents/tempfiles/solgwas_files/".$file);
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

sub generate_pca: Path('/ajax/solgwas/generate_pca') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $trait_id = $c->req->param('trait_id');
    $c->tempfiles_subdir("solgwas_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_download_XXXXX");
    #my $tmp_dir = File::Spec->catfile($c->config->{basepath}, 'gwas_tmpdir');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
#    my $temppath = $c->config->{basepath}."/".$tempfile;
    my $temppath = $c->config->{cluster_shared_tempdir}."/".$tempfile;
    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
    my $phenotype_data_ref = $ds->retrieve_phenotypes();
#    my ($fh, $tempfile2) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_genotypes_download_XXXXX");
#    my $temppath2 = $c->config->{basepath}."/".$tempfile2;
#    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath2);
    #    $ds2 -> file_name => $temppath2;
    my $protocol_name = $c->config->{default_genotyping_protocol};
    my $protocol_id;
    my $row = $schema->resultset("NaturalDiversity::NdProtocol")->find( { name => $protocol_name});# just use find?
    if (defined($row)) {
	      $protocol_id = $row->nd_protocol_id();
    }

    $ds -> retrieve_genotypes($protocol_id);
#    $ds-> @$trials_ref = retrieve_genotypes();
    my $newtrait = $trait_id;
    $newtrait =~ s/\s/\_/g;
    $newtrait =~ s/\//\_/g;
    print STDERR $newtrait . "\n";
    my $figure1file = "." . $tempfile . "_" . $newtrait . "_figure1.png";
    my $figure2file = "." . $tempfile . "_" . $newtrait . "_figure2.png";
    my $figure3file = "." . $tempfile . "_" . $newtrait . "_figure3.png";
    my $figure4file = "." . $tempfile . "_" . $newtrait . "_figure4.png";
    my $pheno_filepath = "." . $tempfile . "_phenotype.txt";
    my $geno_filepath = "." . $tempfile . "_genotype.txt";
    $trait_id =~ tr/ /./;
    $trait_id =~ tr/\//./;
#    my $clean_cmd = "rm /home/vagrant/cxgn/sgn/documents/tempfiles/solgwas_files/SolGWAS_Figure*.png";
#    system($clean_cmd);
    my $geno_filepath2 = "." . $tempfile . "_genotype_edit.txt";
    my $edit_cmd = "sed -e '1 s/\^/row.names\t/' " . $geno_filepath . " > " . $geno_filepath2;
    system($edit_cmd);
    my $geno_filepath3 = "." . $tempfile . "_genotype_edit_subset.txt";
#    my $trim_cmd = "cut -f 1-50 " . $geno_filepath2 . " > " . $geno_filepath3;
#    system($trim_cmd);

    open my $filehandle_in,  "<", "$geno_filepath2"  or die "Could not open $geno_filepath2: $!\n";
    open my $filehandle_in2,  "<", "$geno_filepath2"  or die "Could not open $geno_filepath2: $!\n";
    open my $filehandle_out, ">", "$geno_filepath3" or die "Could not create $geno_filepath3: $!\n";

    my $marker_total;

    while ( my $line = <$filehandle_in2> ) {
        my @sample_line = (split /\s+/, $line);
        $marker_total = scalar(@sample_line);
    }
    close $filehandle_in2;
# Hardcoded number of markers to be selected - make this selectable by user?
    my $markers_selected = 500;
#    my @column_selection = (0,2);
# Initialize column selection so the row.names are selected first
    my @column_selection = (0);
    my %columns_seen;
    for (my $i=0; $i <= $markers_selected; $i++) {
        my $random_current = int(rand($marker_total));
        redo if $columns_seen{$random_current}++;
        push @column_selection, $random_current;
    }

#    foreach my $item (@column_selection) {
        while ( my $line = <$filehandle_in> ) {
            my $curr_line;
            my @first_item = (split /\s+/, $line);
            foreach my $item (@column_selection) {
                $curr_line .= $first_item[$item] . "\t";
            }
#            $curr_line .= "\n";
            print $filehandle_out "$curr_line\n";
        }
#    }
    close $filehandle_in;
    close $filehandle_out;

#    my $cmd = "Rscript " . $c->config->{basepath} . "/R/solgwas/solgwas_genoPCA_script.R " . $geno_filepath3 . " " . $figure2file;
#    system($cmd);
    my $cmd = CXGN::Tools::Run->new(
        {
            backend => $c->config->{backend},
            temp_base => $c->config->{basepath} . "/" . $c->tempfiles_subdir("solgwas_files"),
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );
    $cmd->run_cluster(
            "Rscript ",
            $c->config->{basepath} . "/R/solgwas/solgwas_genoPCA_script.R",
            $geno_filepath3,
            $figure2file,
    );
    $cmd->alive;
    $cmd->is_cluster(1);
    $cmd->wait;


    my $figure2file_response = $figure2file;
    $figure2file_response =~ s/\.\/static//;
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
    print STDERR $dataset_id;
    print STDERR $trait_id;
    $c->tempfiles_subdir("solgwas_files");
#    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_download_XXXXX");
    my $solgwas_tmp_output = $c->config->{cluster_shared_tempdir}."/solgwas_files";
    mkdir $solgwas_tmp_output if ! -d $solgwas_tmp_output;
##    my $prepdir = "mkdir " . $solgwas_tmp_output . " if ! -d " . $solgwas_tmp_output;
##    system($prepdir);
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
    my $temppath = $solgwas_tmp_output . "/" . $tempfile;

#    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);

##    my $phenotype_data_ref = $ds->retrieve_phenotypes();
    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);

#    my ($fh, $tempfile2) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_genotypes_download_XXXXX");
#    my $temppath2 = $c->config->{basepath}."/".$tempfile2;
#    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath2);
    #    $ds2 -> file_name => $temppath2;
    my $protocol_name = $c->config->{default_genotyping_protocol};
    my $protocol_id;
    my $row = $schema->resultset("NaturalDiversity::NdProtocol")->find( { name => $protocol_name});# just use find?
    if (defined($row)) {
	      $protocol_id = $row->nd_protocol_id();
    }

    $ds -> retrieve_genotypes($protocol_id,$geno_filepath);
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
#    my $geno_filepath2 = "." . $tempfile . "_genotype_edit.txt";
    my $geno_filepath2 = $tempfile . "_genotype_edit.txt";
    my $edit_cmd = "sed -e '1 s/\^/row.names\t/' " . $geno_filepath . " > " . $geno_filepath2;
    system($edit_cmd);
#    my $geno_filepath3 = "." . $tempfile . "_genotype_edit_subset.txt";
    my $geno_filepath3 = $tempfile . "_genotype_edit_subset.txt";

#    my $trim_cmd = "cut -f 1-50 " . $geno_filepath2 . " > " . $geno_filepath3;
#    system($trim_cmd);

    open my $filehandle_in,  "<", "$geno_filepath2"  or die "Could not open $geno_filepath2: $!\n";
    open my $filehandle_in2,  "<", "$geno_filepath2"  or die "Could not open $geno_filepath2: $!\n";
    open my $filehandle_out, ">", "$geno_filepath3" or die "Could not create $geno_filepath3: $!\n";

    my $marker_total;

    while ( my $line = <$filehandle_in2> ) {
        my @sample_line = (split /\s+/, $line);
        $marker_total = scalar(@sample_line);
    }
    close $filehandle_in2;
# Hardcoded number of markers to be selected - make this selectable by user?
    my $markers_selected = 500;
#    my @column_selection = (0,2);
# Initialize column selection so the row.names are selected first
    my @column_selection = (0);
    my %columns_seen;
    for (my $i=0; $i <= $markers_selected; $i++) {
        my $random_current = int(rand($marker_total));
        redo if $columns_seen{$random_current}++;
        push @column_selection, $random_current;
    }

#    foreach my $item (@column_selection) {
        while ( my $line = <$filehandle_in> ) {
            my $curr_line;
            my @first_item = (split /\s+/, $line);
            foreach my $item (@column_selection) {
                $curr_line .= $first_item[$item] . "\t";
            }
#            $curr_line .= "\n";
            print $filehandle_out "$curr_line\n";
        }
#    }
    close $filehandle_in;
    close $filehandle_out;

#    my $cmd = "Rscript " . $c->config->{basepath} . "/R/solgwas/solgwas_script.R " . $pheno_filepath . " " . $geno_filepath3 . " " . $trait_id . " " . $figure3file . " " . $figure4file . " " . $pc_check . " " . $kinship_check;
#    system($cmd);
    my $cmd = CXGN::Tools::Run->new(
        {
            backend => $c->config->{backend},
            temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );
    $cmd->run_cluster(
            "Rscript ",
            $c->config->{basepath} . "/R/solgwas/solgwas_script.R",
            $pheno_filepath,
            $geno_filepath3,
            $trait_id,
            $figure3file,
            $figure4file,
            $pc_check,
            $kinship_check,
    );
    $cmd->alive;
    $cmd->is_cluster(1);
    $cmd->wait;

    my $figure3file_response = $figure3file;
    my $figure4file_response = $figure4file;
    my $figure3basename = $figure3file_response;

    $figure3basename =~ s/\/export\/prod\/tmp\/solgwas\_files\///;
#    $figure4file_response =~ s/\.\/static//;
    print STDERR $figure3basename . "\n";
    $c->stash->{rest} = {
        figure3 => $figure3file_response,
        figure4 => $figure4file_response,
        dummy_response => $dataset_id,
        dummy_response2 => $trait_id,
    };
}

1;
