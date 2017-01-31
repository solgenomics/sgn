
use strict;

package SGN::Controller::AJAX::TrialComparison;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use CXGN::BreederSearch;


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

    my @trial_ids = $c->req->param('trial_id');
    my $cvterm_id = $c->req->param('cvterm_id');

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_sql = join ",", map { "\'$_\'" } @trial_ids;
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });
    my @data = $bs->get_extended_phenotype_info_matrix(undef,$trial_sql, undef);

    $c->tempfiles_subdir("compare_trials");

    print STDERR Dumper(\@data);
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"compare_trials/trial_phenotypes_download_XXXXX");
    foreach my $line (@data) { 
	my @columns = split "\t", $line;
	my $csv_line = join ",", @columns;
	print $fh $csv_line."\n";
    }
    
    system('R CMD BATCH', '--no-save', '--no-restore', "--args phenotype_file=\"$tempfile\" output_file=\"$tempfile.png\"", $c->config->{basepath}.'/R/'.'analyze_phenotype.r' );
    
    $c->stash->{rest} = { file => $tempfile, png => $tempfile.".png" };
}



1;
