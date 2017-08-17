
use strict;

package SGN::Controller::AJAX::TrialComparison;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use CXGN::Dataset;
use SGN::Model::Cvterm;
use CXGN::List;
use CXGN::List::Validate;
use CXGN::Trial::Download;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BreederSearch;
use Cwd qw(cwd);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);


# /ajax/trial/compare?trial_id=345&trial_id=4848&trial_id=38484&cvterm_id=84848

sub compare_trail_list_data_test : Path('/ajax/trial/compare_list_data_test') : ActionClass('REST') {}

sub compare_trail_list_data_test_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $result = `python bin/test/TrialComparisonFakeDataGen.py`;#`python TrialComparison_test.py`;
    my $cvterm_id = "TEST_TEST";
    $c->stash->{rest} = { csv => $result, cvterm_id => $cvterm_id};
}

sub compare_trail_list_data : Path('/ajax/trial/compare_list_data') : ActionClass('REST') {}

sub compare_trail_list_data_GET : Args(0) {
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");

    my $user = $c->user();

    if (!$user) {
        $c->stash->{rest} = { error => "Must be logged in to use functionality associated with lists." };
        return;
    }

    my $user_id = $user->get_object()->get_sp_person_id();

    print STDERR "USER ID : $user_id\n";

    if (!$list_id) {
        $c->stash->{rest} = { error => "Error: No list_id provided." };
        return;
    }

    my $cvterm_id = $c->req->param("cvterm_id");

    if (!$cvterm_id) {
        $c->stash->{rest} = { error => "Error: No cvterm_id provided." };
        return;
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $v = CXGN::List::Validate->new();
    my $r = $v->validate($schema, "trial", $list_id);

    if ($r->{missing}) {
        $c->stash->{rest} = { error => "Not all trials could be found in the database." };
        return;
    }

    my $dbh = $schema->storage()->dbh();
    my $tl = CXGN::List->new({ dbh => $dbh, list_id => $list_id, owner => $user_id });

    if (! $tl) {
        $c->stash->{rest} = { error => "The specified list does not exist, is not owned by you, or is not a trial list" };
        return;
    }

    my $trials = $tl->elements();

    my $trial_id_rs = $schema->resultset("Project::Project")->search( { name => { in => [ @$trials ]} });

    my @trial_ids = map { $_->project_id() } $trial_id_rs->all();

    if (@trial_ids < 2) {
        $c->stash->{rest} = { error => "One or both trials are not found in the database. Please try again." };
        return;
    }

    my $csv_loc = $self->make_csv($c, $cvterm_id, @trial_ids);
    my $csv = read_file($c->config->{basepath}."/".$csv_loc);
    $c->stash->{rest} = { csv => $csv, cvterm_id => $cvterm_id };
}

sub make_csv {
    my $self = shift;
    my $c = shift;
    my $cvterm_id = shift;
    my @trial_ids = @_;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    $c->tempfiles_subdir("compare_trials");

     my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"compare_trials/trial_phenotypes_download_XXXXX");

    my $temppath = $c->config->{basepath}."/".$tempfile;

    my $download = CXGN::Trial::Download->new({
        bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
        trial_list => \@trial_ids,
        trait_list => [ $cvterm_id ],
        filename => $temppath,
        format => 'TrialPhenotypeCSV',
        data_level => 'plot', #'plot' or 'plant' or 'all'. CXGN::Dataset would default to 'plot'
        search_type=> 'complete', #'complete' or 'fast'. CXGN::Dataset would default to 'fast'
        has_header => 0
    });
    my $error = $download->download();
    my $errorfile = $temppath.".err";
    if (-e $errorfile) {
        my $error = read_file($errorfile);
        $c->stash->{rest} = { error => $error };
        return;
    }
    my $file = $tempfile.""; # convert from object to string
    return ($tempfile);
}

sub common_traits : Path('/ajax/trial/common_traits') : ActionClass('REST') {}

sub common_traits_GET : Args(0) {
    my $self = shift;
    my $c = shift;

    my @trials = $c->req->param("trial_id");

    $self->get_common_traits($c, @trials);
}


sub get_common_traits {
    my $self = shift;
    my $c = shift;
    my @trials = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    print STDERR '@trials: '.Dumper(@trials);
    my $trials_string = "\'".join( "\',\'",@trials)."\'";
    print STDERR '$trials_string: '.Dumper($trials_string);
    my @criteria = ['trials','traits'];
    my %dataref;
    my %queryref;
    $dataref{traits}->{trials} = $trials_string;
    $queryref{traits}->{trials} = 1;
    print STDERR 'data: '.Dumper(\%dataref);
    print STDERR 'query: '.Dumper(\%queryref);
    my $breedersearch =  CXGN::BreederSearch->new({"dbh"=>$c->dbc->dbh});
    my $results_ref = $breedersearch->metadata_query(@criteria, \%dataref, \%queryref);
    print STDERR "Results: \n";
    #print STDERR Dumper($results_ref);
    $c->stash->{rest} = {
    	options => $results_ref->{results},
      list_trial_count=> scalar(@trials),
      common_trait_count => scalar(@{$results_ref->{results}}),
    };
}

1;
