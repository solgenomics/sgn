use strict;

package SGN::Controller::AJAX::Nirs;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
# use File::Slurp;
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
# use Path::Tiny qw(path);
use Cwd qw(cwd);
use JSON::Parse 'parse_json';
use JSON::XS;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );

sub shared_phenotypes: Path('/ajax/Nirs/shared_phenotypes') : {
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

    
    $c->tempfiles_subdir("nirs_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"nirs_files/trait_XXXXX");
    $people_schema = $c->dbic_schema("CXGN::People::Schema");
    $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;
    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
    my $phenotype_data_ref = $ds2->retrieve_phenotypes();

    my $trials_ref = $ds2->retrieve_trials();
    my @trials = @$trials_ref;

    my $dbh = $c->dbc->dbh();
    my @trial_name= ();
    foreach my $name (@trials){
        my $sql = "SELECT trial_name from public.trials where trial_id=?;";

        my $fh_db= $dbh->prepare($sql);    
        $fh_db->execute($name);
        while (my @trl = $fh_db->fetchrow_array()) {
            push @trial_name, @trl;
        }
    }

    print STDERR Dumper(@trait_info);
    print STDERR Dumper(@trial_name);
    $c->stash->{rest} = {
        options => \@trait_info,
        trialname => \@trial_name,
        tempfile => $tempfile."_phenotype.txt",
    };
}

sub get_training_study: Path('/ajax/Nirs/get_training_study') : {
    my $self = shift;
    my $c = shift;
    my $train_id = $c->req->param('train_id');
    print STDERR Dumper($train_id);

}

sub get_test_study: Path('/ajax/Nirs/get_test_study') : {
    my $self = shift;
    my $c = shift;
    my $test_id = $c->req->param('test_id');
    print STDERR Dumper($test_id);

}

sub get_cross_validation: Path('/ajax/Nirs/get_cross_validation') : {
    my $self = shift;
    my $c = shift;
    my $crossv_id = $c->req->param('cv_id');
    print STDERR Dumper($crossv_id);
    print "The cv_id is $crossv_id \n";

}

sub get_niter: Path('/ajax/Nirs/get_niter') : {
    my $self = shift;
    my $c = shift;
    my $niter_id = $c->req->param('niter_id');
    print STDERR Dumper($niter_id);

}

sub get_algorithm: Path('/ajax/Nirs/get_algorithm') : {
    my $self = shift;
    my $c = shift;
    my $algo_id = $c->req->param('algorithm_id');
    print STDERR Dumper($algo_id);
}

sub get_tune: Path('/ajax/Nirs/get_tune') : {
    my $self = shift;
    my $c = shift;
    my $tune_id = $c->req->param('tune_id');
    print STDERR Dumper($tune_id);

}

sub extract_trait_data :Path('/ajax/Nirs/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file"); # where is this in the html form?
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/nirs_files/".$file);
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

sub generate_results: Path('/ajax/Nirs/generate_results') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $trait_id = $c->req->param('trait_id');
    print STDERR $dataset_id;
    print STDERR $trait_id;

    $c->tempfiles_subdir("nirs_files");
    my $nirs_tmp_output = $c->config->{cluster_shared_tempdir}."/nirs_files";
    mkdir $nirs_tmp_output if ! -d $nirs_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
      "nirs_download_XXXXX",
      DIR=> $nirs_tmp_output,
    );

    my $pheno_filepath = $tempfile . "_phenotype.txt";
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $nirs_tmp_output . "/" . $tempfile;
    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
    my $phenotype_data_ref = $ds->retrieve_phenotypes($pheno_filepath);

    my @plot_name;
    open(my $f, '<', $pheno_filepath) or die;

    while (my $line = <$f>){
        my @elements = split ' ', $line;
        # print join "\t", $elements[25];
        # print "\n";
        push @plot_name, $elements[25];
    }
    close($f);
    
    my ($fh, $filename) = tempfile(
      "nirs_XXXXX",
      DIR=> $nirs_tmp_output,
      SUFFIX => "_spectra",
      EXLOCK => 0
    );

    my $dbh = $c->dbc->dbh();
    my @rawjson = ();
	my @rawplot = ();
    foreach my $name (@plot_name){
        my $sql = "SELECT
				      jsonb_pretty(cast(json->>'spectra' AS jsonb)) AS nirs_spectra
					FROM metadata.md_json
					JOIN phenome.nd_experiment_md_json USING(json_id)
					JOIN nd_experiment_stock USING(nd_experiment_id)
					JOIN stock using(stock_id) where stock.uniquename=?;";
    	
        my $fh_db= $dbh->prepare($sql);    
        $fh_db->execute($name);
        while (my @spt = $fh_db->fetchrow_array()) {
            push @rawjson, @spt;
            print $fh @spt;
            # print $fh;
          }

         my $unitname = "SELECT
				    		stock.uniquename AS observationUnitId
				                FROM metadata.md_json
				                JOIN phenome.nd_experiment_md_json USING(json_id)
				                JOIN nd_experiment_stock USING(nd_experiment_id)
				                JOIN stock using(stock_id) where stock.uniquename=?;";
 		my $fh_db2= $dbh->prepare($unitname);    
        $fh_db2->execute($name);
        while (my @spt2 = $fh_db2->fetchrow_array()) {
        	push @rawplot, @spt2;
          }
        
    }
my $j;
my @formated = ();
for($j=0; $j < @rawjson; $j++){
	print "The number is $j \n";
}
my $limit;
my $i;
if($j==1){
    $i = 0;
    push @formated, "[\n{\"observationUnitId\":\"$rawplot[$i]\",\"nirs_spectra\":$rawjson[$i]\n}\n]\n";
    } elsif($j>1){
        $limit = ($j-1);
    for($i = 0; $i < @rawjson; $i++) {
        if($i==0){
        	push @formated, "[\n{\"observationUnitId\":\"$rawplot[$i]\",\"nirs_spectra\":$rawjson[$i]\n},";
        }elsif($i<$limit){
        	push @formated, "{\"observationUnitId\":\"$rawplot[$i]\",\"nirs_spectra\":$rawjson[$i]\n},";
        }
        if($i==$limit){
        	push @formated, "{\"observationUnitId\":\"$rawplot[$i]\",\"nirs_spectra\":$rawjson[$i]\n}\n\]\n";
        }
    }
}

open(my $outfile, '>', $filename.".json");
foreach my $data (@formated){
	print $outfile $data;
}

close($outfile);

    # my $phenotype_data_ref2 = $h->retrieve_phenotypes($pheno_filepath);

    # my $figure3file = $tempfile . "_" . "figure3.png";
    # my $figure4file = $tempfile . "_" . "figure4.png";
    my $pheno_name; # args[1]
    my $preprocessing_boolean = $c->req->param('preprocessing_bool'); # args[2]
    my $num_iterations = $c->req->param('niter'); # args[3]
    my $modelmethod = $c->req->param('model_alg'); # args[4]
    my $tune_length = $c->req->param('tunelen'); # args[5]
    my $rf_var_imp = $c->req->param('rf_var_imp'); # args[6]
    my $cv_scheme = $c->req->param('cv_id'); # args[7]
    # my $pheno_filepath = $tempfile . "_phenotype.txt"; # args[8]
    my $trainset_filepath = $filename . "json"; # args[8]
    # my $trainset_filepath, # args[9]
    my $testset_filepath, # args[9]
    my $trial1_filepath, # args[10]
    my $trial2_filepath, # args[11]
    my $trial3_filepath, # args[12]
    my $nirs_output_filepath = $tempfile . "_" . "nirsResults.txt"; # args[13]


    my $cmd = CXGN::Tools::Run->new({
            backend => $c->config->{backend},
            temp_base => $c->config->{cluster_shared_tempdir} . "/nirs_files",
            queue => $c->config->{'web_cluster_queue'},
            do_cleanup => 0,
            # don't block and wait if the cluster looks full
            max_cluster_jobs => 1_000_000_000,
        });

        print STDERR Dumper $pheno_filepath;

    # my $job;
    $cmd->run_cluster(
            "Rscript ",
            $c->config->{basepath} . "/R/Nirs/nirs.R",
            $pheno_name, # args[1]
            $preprocessing_boolean, # args[2]
            $num_iterations, # args[3]
            $modelmethod, # args[4]
            $tune_length, # args[5]
            $rf_var_imp, # args[6]
            $cv_scheme, # args[7]
            $pheno_filepath, # args[8]
            $testset_filepath, # args[9]
            $trial1_filepath, # args[10]
            $trial2_filepath, # args[11]
            $trial3_filepath, # args[12]
            $nirs_output_filepath # args[13]
    );
    $cmd->alive;
    $cmd->is_cluster(1);
    $cmd->wait;

   # TODO 
    my $figure_path = $c->{basepath} . "./documents/tempfiles/nirs_files/";
    copy($modelmethod, $figure_path);
    copy($tune_length, $figure_path);
    copy($cv_scheme, $figure_path);

    my $h2Filebasename = basename($modelmethod);
    my $h2File_response = "/documents/tempfiles/nirs_files/" . $h2Filebasename;
    
    my $figure3basename = basename($tune_length);
    my $figure3_response = "/documents/tempfiles/nirs_files/" . $figure3basename;
    
    my $figure4basename = basename($cv_scheme);
    my $figure4_response = "/documents/tempfiles/nirs_files/" . $figure4basename;


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
