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
#    my $solgwas_tmp_output = $c->config->{cluster_shared_tempdir}."/solgwas_files";
#    mkdir $solgwas_tmp_output if ! -d $solgwas_tmp_output;
#    my ($tmp_fh, $tempfile) = tempfile(
#      "solgwas_download_XXXXX",
#      DIR=> $solgwas_tmp_output,
#    );
#    my $pheno_filepath = $tempfile . "_phenotype.txt";

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;
#    my $temppath = $solgwas_tmp_output . "/" . $tempfile;
    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
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
#    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_download_XXXXX");
    my $solgwas_tmp_output = $c->config->{cluster_shared_tempdir}."/solgwas_files";
    mkdir $solgwas_tmp_output if ! -d $solgwas_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "solgwas_download_XXXXX",
      DIR=> $solgwas_tmp_output,
    );
#    my $pheno_filepath = $tempfile . "_phenotype.txt";
    my $geno_filepath = $tempfile . "_genotype.txt";
    #my $tmp_dir = File::Spec->catfile($c->config->{basepath}, 'gwas_tmpdir');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
#    my $temppath = $c->config->{basepath}."/".$tempfile;
#    my $temppath = $c->config->{cluster_shared_tempdir}."/".$tempfile;
    my $temppath = $solgwas_tmp_output . "/" . $tempfile;
    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
#    my $phenotype_data_ref = $ds->retrieve_phenotypes();
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

    $ds -> retrieve_genotypes($protocol_id, $geno_filepath);
#    $ds-> @$trials_ref = retrieve_genotypes();
    my $newtrait = $trait_id;
    $newtrait =~ s/\s/\_/g;
    $newtrait =~ s/\//\_/g;
    print STDERR $newtrait . "\n";
    my $figure1file = $tempfile . "_" . $newtrait . "_figure1.png";
    my $figure2file = $tempfile . "_" . $newtrait . "_figure2.png";
    my $figure3file = $tempfile . "_" . $newtrait . "_figure3.png";
    my $figure4file = $tempfile . "_" . $newtrait . "_figure4.png";
    $trait_id =~ tr/ /./;
    $trait_id =~ tr/\//./;
#    my $clean_cmd = "rm /home/vagrant/cxgn/sgn/documents/tempfiles/solgwas_files/SolGWAS_Figure*.png";
#    system($clean_cmd);
#    my $geno_filepathGCTA = $tempfile . "_genotype_GCTA.txt"

    my $geno_filepath2 = $tempfile . "_genotype_edit.txt";
    my $edit_cmd = "sed -e '1 s/\^/row.names\t/' " . $geno_filepath . " > " . $geno_filepath2;
    system($edit_cmd);
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

#    my $cmd = "Rscript " . $c->config->{basepath} . "/R/solgwas/solgwas_genoPCA_script.R " . $geno_filepath3 . " " . $figure2file;
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
            $c->config->{basepath} . "/R/solgwas/solgwas_genoPCA_script.R",
            $geno_filepath3,
            $figure2file,
    );
    $cmd->alive;
    $cmd->is_cluster(1);
    $cmd->wait;
    my $figure_path = $c->{basepath} . "./documents/tempfiles/solgwas_files/";
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
    print STDERR $newtrait . "\n";
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
    print STDERR $trait_id . "\n";
    $trait_id =~ tr/\//./;
    print STDERR $trait_id . "\n";
#    my $clean_cmd = "rm /home/vagrant/cxgn/sgn/documents/tempfiles/solgwas_files/SolGWAS_Figure*.png";
#    system($clean_cmd);
#    my $geno_filepath2 = "." . $tempfile . "_genotype_edit.txt";
    my $geno_filepath_transpose = $tempfile . "_genotype_transpose.vcf";
    my $geno_filepath2 = $tempfile . "_genotype_edit.txt";
    my $edit_cmd = "sed -e '1 s/\^/row.names\t/' " . $geno_filepath . " > " . $geno_filepath2;
    system($edit_cmd);

#    my $geno_filepath3 = "." . $tempfile . "_genotype_edit_subset.txt";
    my $geno_filepath3 = $tempfile . "_genotype_edit_subset.txt";

# Transposition of genotype file to match vcf format
    open (INPUT, "<$geno_filepath2") || die "Cannot open INPUT file.\n";
    open(my $fh, '>', $geno_filepath_transpose);
    my $data   = [];
    my $t_data = [];
    while(<INPUT>){
        chomp;
        #skip lines without anything
        next if /^$/;
        #split lines on tabs
        my @s = split(/\t/);
        #store each line, which has been split on tabs
        #in the array reference as an array reference
        push(@{$data}, \@s);
    }

    #loop through array reference
    for my $row (@{$data}){
        #go through each array reference
        #each array element is each row of the data
        for my $col (0 .. $#{$row}){
            #each row of $t_data is an array reference
            #that is being populated with the $data columns
            push(@{$t_data->[$col]}, $row->[$col]);
        }
    }

    for my $row (@$t_data){
        my $line_to_print = '';
        for my $col (@{$row}){
            if (index($col, "_") != -1) {
                my @chr_pos = split /_/, $col;
                my $chr_num;
                ($chr_num = $chr_pos[0]) =~ s/[A-Z]//g;
                $line_to_print .= "$chr_num\t$chr_pos[1]\t$col\tA\tC\t100\tPASS\t.\t.\t";
            } elsif ($col eq 'row.names') {
                my @chr_pos = split /_/, $col;
                $line_to_print .= "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t";
            } else {
                my $col_num = $col + 0.0;
                if ($col_num < 0.5) {
                    $line_to_print .= "0\/0\t";
                } elsif (($col_num >= 0.5) && ($col_num <= 1.5)) {
                    $line_to_print .= "0\/1\t";
                } elsif (($col_num > 1.5) && ($col_num <= 2.0)) {
                    $line_to_print .= "1\/1\t";
                } else {
                    $line_to_print .= "$col\t";
                }
            }
        }
        $line_to_print =~ s/\t$//;
        print $fh "$line_to_print\n";
    }
    close $fh;

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

    close $filehandle_in;
    close $filehandle_out;

    # The following code modifying the phenotype file for gcta should be changed to not use system cmd
    # Attempt to change the phenotype file extracted, isolate the germplasmDbId and the phenotype values
    my $pheno_filepath2 = $tempfile . "_phenotype_mod.txt";
    my $pheno_cut_cmd = "cut -f 18,40 " . $pheno_filepath . " > " . $pheno_filepath2;
    system($pheno_cut_cmd);
    # Now modify again, to give properly formatted phenotype file for gcta
    my $pheno_filepath3 = $tempfile . "_phenotype_mod_gcta.txt";
    open my $filehandle_in_pheno,  "<", "$pheno_filepath2"  or die "Could not open $pheno_filepath2: $!\n";
    open my $filehandle_out_pheno, ">", "$pheno_filepath3" or die "Could not create $pheno_filepath3: $!\n";

    #    foreach my $item (@column_selection) {
            while ( my $line = <$filehandle_in_pheno> ) {

                my @first_item = (split /\s+/, $line);
                if ($first_item[0] eq "germplasmDbId") {
                    # continue, do nothing
                } elsif ($first_item[1] eq '') {
                    # if the phenotype value is empty exclude (i.e., do not print) the line
                } else {
                    print $filehandle_out_pheno "0\t$line";
                }
    #            $curr_line .= "\n";
            }

        close $filehandle_in_pheno;
        close $filehandle_out_pheno;

#    my $cmd = "Rscript " . $c->config->{basepath} . "/R/solgwas/solgwas_script.R " . $pheno_filepath . " " . $geno_filepath3 . " " . $trait_id . " " . $figure3file . " " . $figure4file . " " . $pc_check . " " . $kinship_check;
#    system($cmd);
    # my $cmd = CXGN::Tools::Run->new(
    #     {
    #         backend => $c->config->{backend},
    #         temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
    #         queue => $c->config->{'web_cluster_queue'},
    #         do_cleanup => 0,
    #         # don't block and wait if the cluster looks full
    #         max_cluster_jobs => 1_000_000_000,
    #     }
    # );
    # $cmd->run_cluster(
    #         "Rscript ",
    #         $c->config->{basepath} . "/R/solgwas/solgwas_script.R",
    #         $pheno_filepath,
    #         $geno_filepath3,
    #         $trait_id,
    #         $figure3file,
    #         $figure4file,
    #         $pc_check,
    #         $kinship_check,
    # );
    # $cmd->alive;
    # $cmd->is_cluster(1);
    # $cmd->wait;

    # $cmd->run_cluster(
    #         "gcta64 --bfile ~/Documents/gcta_1.92.0beta/test.bed --maf 0.05 --make-grm-bin --out ~/Documents/gcta_1.92.0beta/Kinship --thread-num 1 > ~/Documents/gcta_1.92.0beta/Kinship.log",
    # );
    # $cmd->alive;
    # $cmd->is_cluster(1);
    # $cmd->wait;
    my $vcf_header = $tempfile . "_vcfheader.txt";
    my $vcf_content = $tempfile . "_vcfcontent.txt";
    my $vcf_sorted_content = $tempfile . "_vcfsortedcontent.txt";
    my $sorted_vcf = $tempfile . "_genotype_transpose_sorted.vcf";

    # my $get_vcf_header = CXGN::Tools::Run->new(
    #     {
    #         backend => $c->config->{backend},
    #         temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
    #         queue => $c->config->{'web_cluster_queue'},
    #         do_cleanup => 0,
    #         # don't block and wait if the cluster looks full
    #         max_cluster_jobs => 1_000_000_000,
    #     }
    # );

    my $get_vcf_header = "grep '^#' " . $geno_filepath_transpose . " > " . $vcf_header;
    system($get_vcf_header);

    # $get_vcf_header->run_cluster(
    #     "grep '^#' " . $geno_filepath_transpose . " > " . $vcf_header,
    # );
    # $get_vcf_header->alive;
    # $get_vcf_header->is_cluster(1);
    # $get_vcf_header->wait;

    my $get_vcf_content = "grep -v '^#' " . $geno_filepath_transpose . " > " . $vcf_content;
    system($get_vcf_content);

    # my $get_vcf_content = CXGN::Tools::Run->new(
    #     {
    #         backend => $c->config->{backend},
    #         temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
    #         queue => $c->config->{'web_cluster_queue'},
    #         do_cleanup => 0,
    #         # don't block and wait if the cluster looks full
    #         max_cluster_jobs => 1_000_000_000,
    #     }
    # );

    # $get_vcf_content->run_cluster(
    #     "grep -v '^#' " . $geno_filepath_transpose . " > " . $vcf_content,
    # );
    # $get_vcf_content->alive;
    # $get_vcf_content->is_cluster(1);
    # $get_vcf_content->wait;

    my $sort_vcf_cmd = "sort -k1,1V -k2,2n " . $vcf_content . " > " . $vcf_sorted_content;
    system($sort_vcf_cmd);
    #
    # my $sort_vcf_cmd = CXGN::Tools::Run->new(
    #     {
    #         backend => $c->config->{backend},
    #         temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
    #         queue => $c->config->{'web_cluster_queue'},
    #         do_cleanup => 0,
    #         # don't block and wait if the cluster looks full
    #         max_cluster_jobs => 1_000_000_000,
    #     }
    # );
    #
    # $sort_vcf_cmd->run_cluster(
    #     "sort -k1,1V -k2,2n " . $vcf_content . " > " . $vcf_sorted_content,
    # );
    # $sort_vcf_cmd->alive;
    # $sort_vcf_cmd->is_cluster(1);
    # $sort_vcf_cmd->wait;

    my $assemble_sorted_vcf_cmd = "cat " . $vcf_header . " " . $vcf_sorted_content . " > " . $sorted_vcf;
    system($assemble_sorted_vcf_cmd);

    # my $assemble_sorted_vcf_cmd = CXGN::Tools::Run->new(
    #     {
    #         backend => $c->config->{backend},
    #         temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
    #         queue => $c->config->{'web_cluster_queue'},
    #         do_cleanup => 0,
    #         # don't block and wait if the cluster looks full
    #         max_cluster_jobs => 1_000_000_000,
    #     }
    # );
    #
    # $assemble_sorted_vcf_cmd->run_cluster(
    #     "cat " . $vcf_header . " " . $vcf_sorted_content . " > " . $sorted_vcf,
    # );
    # $assemble_sorted_vcf_cmd->alive;
    # $assemble_sorted_vcf_cmd->is_cluster(1);
    # $assemble_sorted_vcf_cmd->wait;


    my $vcf_cmd = CXGN::Tools::Run->new(
        {
            backend => $c->config->{backend},
            temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );
    # $cmd->run_cluster(
    #         "Rscript ",
    #         $c->config->{basepath} . "/R/solgwas/solgwas_script.R",
    #         $pheno_filepath,
    #         $geno_filepath3,
    #         $trait_id,
    #         $figure3file,
    #         $figure4file,
    #         $pc_check,
    #         $kinship_check,
    # );
    # $cmd->alive;
    # $cmd->is_cluster(1);
    # $cmd->wait;

    $vcf_cmd->run_cluster(
#            "plink2 --bfile ~/Documents/gcta_1.92.0beta/test.bed --maf 0.05 --make-grm-bin --out " . $tempfile ."_Kinship --thread-num 1 > " . $tempfile . "_Kinship.log",

#            "plink2 --vcf " . $geno_filepath_transpose . " --make-bed --chr-set 90 --allow-extra-chr --const-fid --out " . $tempfile,

            $solgwas_tmp_output . "/../../plink2 --vcf " . $sorted_vcf . " --make-bed --chr-set 90 --allow-extra-chr --const-fid --out " . $tempfile,

#            "plink2 --vcf " . $geno_filepath_transpose . " --allow-extra-chr --const-fid --maf 0.05 --recode A --out " . $tempfile,
    );
    $vcf_cmd->alive;
    $vcf_cmd->is_cluster(1);
    $vcf_cmd->wait;

    my $figure_path = $c->{basepath} . "./documents/tempfiles/solgwas_files/";
    copy($figure3file,$figure_path);
    copy($figure4file,$figure_path);
#    my $figure3basename = $figure3file;

#    $figure3basename =~ s/\/export\/prod\/tmp\/solgwas\_files\///;
    my $figure3basename = basename($figure3file);
    my $figure3file_response = "/documents/tempfiles/solgwas_files/" . $figure3basename;
    my $figure4basename = basename($figure4file);
    my $figure4file_response = "/documents/tempfiles/solgwas_files/" . $figure4basename;
#    $figure4file_response =~ s/\.\/static//;
    my $cmd2 = CXGN::Tools::Run->new(
        {
            backend => $c->config->{backend},
            temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );
    # To test, copied the test.* gcta files to export temp_base
    # Hardcoding gcta for testing only:
#    my $bfile = "test";
#    my $grm_out = $tempfile . "afp2apr2019";
    $cmd2->run_cluster(
            $solgwas_tmp_output . "/../../gcta64 --bfile",
#            $c->config->{cluster_shared_tempdir} . "/solgwas_files/" . $bfile,
            $tempfile,
            "--chr 4 --make-grm --out",
#            $c->config->{cluster_shared_tempdir} . "/solgwas_files/" . $grm_out,
            $tempfile,
    );
    $cmd2->alive;
    $cmd2->is_cluster(1);
    $cmd2->wait;

    my $cmd3 = CXGN::Tools::Run->new(
        {
            backend => $c->config->{backend},
            temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        }
    );
    # To test, copied the test.* gcta files to export temp_base
    # Hardcoding gcta for testing only:
    $cmd3->run_cluster(
            $solgwas_tmp_output . "/../../gcta64 --mlma",
            "--bfile",
#            $c->config->{cluster_shared_tempdir} . "/solgwas_files/" . $bfile,
            $tempfile,
            "--pheno",
#            $c->config->{cluster_shared_tempdir} . "/solgwas_files/test.phen",
            $pheno_filepath3,
            "--grm",
#            $c->config->{cluster_shared_tempdir} . "/solgwas_files/" . $grm_out,
            $tempfile,
            "--out",
#            $c->config->{cluster_shared_tempdir} . "/solgwas_files/afpGWAStest1",
            $tempfile,
    );
    $cmd3->alive;
    $cmd3->is_cluster(1);
    $cmd3->wait;

#    my $log10_cmd = "awk -F\"\t\" '{a = -log(\$9)/log(10); printf(\"%0.4f\n\", a)} afpGWAStest1.mlma > log10_afpGWAStest1.txt";
#    system($log10_cmd);
    # my $cmd4 = CXGN::Tools::Run->new(
    #     {
    #         backend => $c->config->{backend},
    #         temp_base => $c->config->{cluster_shared_tempdir} . "/solgwas_files",
    #         queue => $c->config->{'web_cluster_queue'},
    #         do_cleanup => 0,
    #         # don't block and wait if the cluster looks full
    #         max_cluster_jobs => 1_000_000_000,
    #     }
    # );
    # # To test, copied the test.* gcta files to export temp_base
    # # Hardcoding gcta for testing only:
    # $cmd4->run_cluster(
    #         "awk -F"\t" '{a = -log($16)/log(10); printf("%0.4f\n", a)}",
    #         $c->config->{cluster_shared_tempdir} . "/solgwas_files/afpGWAStest1.mlma > log10_afpGWAStest1.txt",
    # );
    # $cmd4->alive;
    # $cmd4->is_cluster(1);
    # $cmd4->wait;

    copy($c->config->{cluster_shared_tempdir} . "/solgwas_files/afpGWAStest1.mlma",$figure_path);

    $c->stash->{rest} = {
        figure3 => $figure3file_response,
        figure4 => $figure4file_response,
        dummy_response => $dataset_id,
        dummy_response2 => $trait_id,
    };
}

1;
