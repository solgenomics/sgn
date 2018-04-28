use strict;

package SGN::Controller::AJAX::Solgwas;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use CXGN::Dataset;
use CXGN::Dataset::File;
#use SGN::Model::Cvterm;
#use CXGN::List;
#use CXGN::List::Validate;
#use CXGN::Trial::Download;
#use CXGN::Phenotypes::PhenotypeMatrix;
#use CXGN::BreederSearch;
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
    my $phenotypes = $ds->retrieve_phenotypes();
    my $trials_ref = $ds->retrieve_trials();
    print STDERR $dataset_id;
    my @trials = @$trials_ref;

    print STDERR Dumper($trials_ref);
    print STDERR Dumper($trials[2]);
    print STDERR Dumper($phenotypes);
    $self->get_shared_phenotypes($c, @trials);
    
}


sub get_shared_phenotypes {
    my $self = shift;
    my $c = shift;
    my @trials = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
#    print STDERR '@trials: '.Dumper(@trials);
    my $trials_string = "\'".join( "\',\'",@trials)."\'";
#    print STDERR '$trials_string: '.Dumper($trials_string);
    my @criteria = ['trials','traits'];
    my %dataref;
    my %queryref;
    $dataref{traits}->{trials} = $trials_string;
    # The following is not the correct line to use, since returns any traits phenotyped for any trial
    $queryref{traits}->{trials} = 0;
    # The following is the correct line that is needed, but current returns empty when using test set
    #$queryref{traits}->{trials} = 1;
#    print STDERR 'data: '.Dumper(\%dataref);
#    print STDERR 'query: '.Dumper(\%queryref);
    my $breedersearch =  CXGN::BreederSearch->new({"dbh"=>$c->dbc->dbh});
    my $results_ref = $breedersearch->metadata_query(@criteria, \%dataref, \%queryref);
#    print STDERR "Results: \n";
#    print STDERR Dumper($results_ref);
    $c->stash->{rest} = {
        options => $results_ref->{results},
        list_trial_count=> scalar(@trials),
        common_trait_count => scalar(@{$results_ref->{results}}),
    };
}

sub generate_results: Path('/ajax/solgwas/generate_results') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $trait_id = $c->req->param('trait_id');
    print STDERR $dataset_id;
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
    

#    my $cmd = "Rscript /home/vagrant/cxgn/sgn/static/documents/temp_test_solgwas/GWAS_Script.R";
#    system($cmd);
    
    
#    my $traits = $ds->retrieve_traits();
#    my $phenotypes = $ds->retrieve_phenotypes();
#    my $trials_ref = $ds->retrieve_trials();
#    print STDERR $dataset_id;
#    my @trials = @$trials_ref;

#    my $download = CXGN::Trial::Download->new({
#	bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
#	trial_list => \


    
    $c->stash->{rest} = {
        dummy_response => $dataset_id,
        dummy_response2 => $trait_id,
    };
}

1;
