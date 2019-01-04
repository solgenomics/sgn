use strict;

package SGN::Controller::AJAX::Solgwas;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use File::Spec qw | catfile|;
use File::Basename qw | basename |;
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
#	push @trait_info, [$tobj->name()];
    }
    my $phenotypes = $ds->retrieve_phenotypes();
    my $trials_ref = $ds->retrieve_trials();
    print STDERR Dumper(@trait_info);
    my @trials = @$trials_ref;
#    my @pheno_vals = @$phenotypes[0];
#    print STDERR Dumper($traits);
    #print STDERR Dumper($trials_ref);
    #print STDERR Dumper($trials[2]);
#    print STDERR Dumper(@pheno_vals);
#    print STDERR Dumper($pheno_vals[5]);
    my @co_pheno;
#    for my $i (0..19) {
#	if (index($pheno_vals[0][$i], "CO_") != -1) {
#            print STDERR Dumper($pheno_vals[0][$i]);
#	    push @co_pheno, $pheno_vals[0][$i];

 #       }
#

  #  }

   # print STDERR Dumper(@co_pheno);

    #print STDERR Dumper($phenotypes);
#    $self->get_shared_phenotypes($c, @pheno_vals);
    $c->stash->{rest} = {
        options => \@trait_info,
    };
}


sub get_shared_phenotypes {
    my $self = shift;
    my $c = shift;
    #    my @trials = @_;
    my @phenotype_header = @_;
#    my $schema = $c->dbic_schema("Bio::Chado::Schema");
#    print STDERR '@trials: '.Dumper(@trials);
#    my $trials_string = "\'".join( "\',\'",@trials)."\'";
#    print STDERR '$trials_string: '.Dumper($trials_string);
#    my @criteria = ['trials','traits'];
#    my %dataref;
#    my %queryref;
#    $dataref{traits}->{trials} = $trials_string;
    # The following is not the correct line to use, since returns any traits phenotyped for any trial
#    $queryref{traits}->{trials} = 0;
    # The following is the correct line that is needed, but current returns empty when using test set
    #$queryref{traits}->{trials} = 1;
#    print STDERR 'data: '.Dumper(\%dataref);
#    print STDERR 'query: '.Dumper(\%queryref);
#    my $breedersearch =  CXGN::BreederSearch->new({"dbh"=>$c->dbc->dbh});
#    my $results_ref = $breedersearch->metadata_query(@criteria, \%dataref, \%queryref);
#    print STDERR "Results: \n";
#    print STDERR Dumper($results_ref);
    for my $i (@phenotype_header) {
        print STDERR Dumper($phenotype_header[$i]);
#        print $i."\n";
    }
#    $c->stash->{rest} = {
#        options => $results_ref->{results},
#        list_trial_count=> scalar(@trials),
#        common_trait_count => scalar(@{$results_ref->{results}}),
#    };
}

sub extract_trait_data: Path('/ajax/solgwas/extract_trait_data') : {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/solgwas/".$file);
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
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"solgwas_files/solgwas_download_XXXXX");
    #my $tmp_dir = File::Spec->catfile($c->config->{basepath}, 'gwas_tmpdir');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;
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

#    my $cmd = "Rscript " . $c->config->{basepath} . "/R/solgwas/solgwas_script.R " . $pheno_filepath . " " . $geno_filepath3 . " " . $trait_id . " " . $figure1file . " " . $figure2file . " " . $figure3file . " " . $figure4file . " " . $pc_check . " " . $kinship_check;
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
            $c->config->{basepath} . "/R/solgwas/solgwas_script.R",
            $pheno_filepath,
            $geno_filepath3,
            $trait_id,
            $figure1file,
            $figure2file,
            $figure3file,
            $figure4file,
            $pc_check,
            $kinship_check,
    );

#    my $traits = $ds->retrieve_traits();
#    my $phenotypes = $ds->retrieve_phenotypes();
#    my $trials_ref = $ds->retrieve_trials();
#    print STDERR $dataset_id;
#    my @trials = @$trials_ref;

#    my $download = CXGN::Trial::Download->new({
#	bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
#	trial_list => \

    my $figure1file_response = $figure1file;
    my $figure2file_response = $figure2file;
    my $figure3file_response = $figure3file;
    my $figure4file_response = $figure4file;
    print STDERR Dumper($figure2file_response);
    $figure1file_response =~ s/\.\/static//;
    $figure2file_response =~ s/\.\/static//;
    $figure3file_response =~ s/\.\/static//;
    $figure4file_response =~ s/\.\/static//;
    print STDERR Dumper($figure2file_response);
    $c->stash->{rest} = {
        figure1 => $figure1file_response,
        figure2 => $figure2file_response,
        figure3 => $figure3file_response,
        figure4 => $figure4file_response,
        dummy_response => $dataset_id,
        dummy_response2 => $trait_id,
    };
}

1;
