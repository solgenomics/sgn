
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




sub compare_trials : Path('/ajax/trial/compare') : ActionClass('REST') {}

sub compare_trials_GET : Args(0) { 
    my $self = shift;
    my $c = shift;

    my @trial_names = $c->req->param('trial_name');

    print STDERR "TRIAL NAMES: ".(join ",",@trial_names);
    my $cvterm_id = $c->req->param('cvterm_id');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_id_rs = $schema->resultset("Project::Project")->search( { name => { in => [ @trial_names ]} });

    my @trial_ids = map { $_->project_id() } $trial_id_rs->all();

    print STDERR "TRIAL IDS: ".(join ",",@trial_ids)."\n";

    if (@trial_ids < 2) { 
	$c->stash->{rest} = { error => "One or both trials are not found in the database. Please try again." };
	return;
    }

    print STDERR "CVTERM_ID = ".$cvterm_id."\n";
    if (!$cvterm_id || $cvterm_id eq "undefined") { 
	print STDERR "No cvterm supplied!\n";
	$c->stash->{rest} = { error => "No cvterm_id supplied." };
	return;
    }

    my ($file, $png, $errorfile) = $self->make_graph($c, $cvterm_id, @trial_ids);
    $c->stash->{rest} = { file => $file, png => $png };
}

sub compare_trial_list : Path('/ajax/trial/compare_list') : ActionClass('REST') {}

sub compare_trial_list_GET : Args(0) { 
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

    my ($file, $png, $errorfile) = $self->make_graph($c, $cvterm_id, @trial_ids);
    $c->stash->{rest} = { file => $file, png => $png };
}
    


sub make_graph { 
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






    print STDERR "RUNNING R SCRIPT... ";
    system('R', 'CMD', 'BATCH', '--no-save', '--no-restore', "--args phenotype_file=\"$temppath\" output_file=\"$temppath.png\"", $c->config->{basepath}.'/R/'.'analyze_phenotype.r', $temppath."_output.txt" );
    print STDERR "Done.\n";

    my $errorfile = $temppath.".err";
    if (-e $errorfile) { 
	print STDERR "ERROR FILE EXISTS! $errorfile\n";
	my $error = read_file($errorfile);
	$c->stash->{rest} = { error => $error };
	return;
    }
    print STDERR "NO ERROR FILE, RETURNING DATA...\n";
    my $file = $tempfile.""; # convert from object to string
    return ( $file, $tempfile.".png", $errorfile );
    print STDERR "returning...\n";
}

sub common_traits : Path('/ajax/trial/common_traits') : ActionClass('REST') {}

sub common_traits_GET : Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my @trials = $c->req->param("trial_name");

    $self->get_common_traits($c, @trials);
}


sub get_common_traits { 
    my $self = shift;
    my $c = shift;
    my @trials = @_;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_id_rs = $schema->resultset("Project::Project")->search( { name => { in => [ @trials ]} });
    my @trial_ids = map { $_->project_id() } $trial_id_rs->all();
    
    my @trait_lists;
    my @trial_objects;
    foreach my $t (@trial_ids) { 
	my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $t });
	push @trial_objects, $trial;
	my $traits = $trial->get_traits_assayed();
	push @trait_lists, $traits;
    }
    
    my @common_traits = @{$trait_lists[0]};

    for(my $i=1; $i<@trait_lists; $i++ ) { 
	my @local_common = ();
	for(my $n=0; $n<@common_traits; $n++) { 
	    for(my $m=0; $m<@{$trait_lists[$i]}; $m++) { 
		if ($common_traits[$n]->[0] == $trait_lists[$i][$m]->[0]) { 
		    push @local_common, $common_traits[$n];
		}
	    }
	}
	@common_traits = @local_common;
    }

    my $common_trait_count = scalar(@common_traits);
    
    my @common_accessions = ();

    foreach my $t (@trial_objects) { 
	my $accessions = $t->get_accessions();
	push @common_accessions, $accessions;
    }
    
    my @total_accessions;
    my @previous_accessions = @{$common_accessions[0]};
    for(my $i = 1; $i<@common_accessions; $i++) { 
 	my @previous_accession_names = map { $_->{accession_name} } @previous_accessions;
 	my @accession_names = map { $_->{accession_name} } @{$common_accessions[$i]};
	
	my $list = List::Compare->new(\@previous_accession_names, \@accession_names);
	
	@previous_accessions = $list->get_intersection();
	@total_accessions = $list->get_union();
    }
    
    @common_accessions = @previous_accessions;
    my $common_accession_count = scalar(@common_accessions);
    my $total_accession_count = scalar(@total_accessions);
       
    my @options;
    foreach my $t (@common_traits) { 
	push @options, [ $t->[0], $t->[1] ];
    }
    $c->stash->{rest} = { 
	options => \@options ,
	common_accession_count => $common_accession_count,
        common_trait_count => $common_trait_count,
	total_accession_count => $total_accession_count,
    };
}

1;
