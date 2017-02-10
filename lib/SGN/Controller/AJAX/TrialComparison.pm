
use strict;

package SGN::Controller::AJAX::TrialComparison;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use CXGN::Dataset;
use SGN::Model::Cvterm;


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

    my $trial_1 = $c->req->param('trial_1');
    my $trial_2 = $c->req->param('trial_2');
    my $cvterm_id = $c->req->param('cvterm_id');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_id_rs = $schema->resultset("Project::Project")->search( { name => { in => [ $trial_1, $trial_2 ]} });

    my @trial_ids = map { $_->project_id() } $trial_id_rs->all();

    if (@trial_ids < 2) { 
	$c->stash->{rest} = { error => "One or both trials are not found in the database. Please try again." };
	return;
    }


 #   my $cv_name = $c->config->{trait_ontology_db_name};
    
#    my $cv_term_id = SGN::Model::Cvterm->get_cvterm_row($schema, $cvterm, $cv_name);

    my $ds = CXGN::Dataset->new( people_schema => $c->dbic_schema("CXGN::People::Schema"), schema => $schema);
    
    $ds->trials( [ @trial_ids ]);
    $ds->traits( [ $cvterm_id ]);
    
    my $data = $ds->retrieve_phenotypes();

    $c->tempfiles_subdir("compare_trials");

    print STDERR Dumper($data);
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"compare_trials/trial_phenotypes_download_XXXXX");
    foreach my $line (@$data) { 
	my @columns = split "\t", $line;
	my $csv_line = join ",", @columns;
	print $fh $csv_line."\n";
    }
    my $temppath = $c->config->{basepath}."/".$tempfile;

    print STDERR "RUNNING R SCRIPT... ";
    system('R', 'CMD', 'BATCH', '--no-save', '--no-restore', "--args phenotype_file=\"$temppath\" output_file=\"$temppath.png\"", $c->config->{basepath}.'/R/'.'analyze_phenotype.r', 'analyze_phenotype_output.txt' );
    print STDERR "Done.\n";

    my $errorfile = $temppath.".err";
    if (-e $errorfile) { 
	print STDERR "ERROR FILE EXISTS! $errorfile\n";
	my $error = read_file($errorfile);
	$c->stash->{rest} = { error => $error };
	return;
    }

    $c->stash->{rest} = { file => $tempfile, png => $tempfile.".png" };
}

sub common_traits : Path('/ajax/trial/common_traits') : ActionClass('REST') {}

sub common_traits_GET : Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $trial_1 = $c->req->param("trial_1");
    my $trial_2 = $c->req->param("trial_2");

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_id_rs = $schema->resultset("Project::Project")->search( { name => { in => [ $trial_1, $trial_2 ]} });
    my @trial_ids = map { $_->project_id() } $trial_id_rs->all();

    my $ds = CXGN::Dataset->new( people_schema => $c->dbic_schema("CXGN::People::Schema"), schema => $schema);
    
    $ds->trials( [ @trial_ids ]);

    my $traits = $ds->retrieve_traits();

    print STDERR "Traits:\n";
    print STDERR Dumper($traits);
    
    my @options;
    foreach my $t (@$traits) { 
	push @options, [ $t->[0], $t->[1] ];
    }

    $c->stash->{rest} = { options => \@options };


    }

1;
