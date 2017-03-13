package SGN::Controller::Phenotypes;

=head1 NAME

SGN::Controller::Phenotypes - Catalyst controller for pages dealing with
phenotypes submission and associating them with project, experiments, and stock accessions.

=cut

use Moose;
use namespace::autoclean;
use YAML::Any qw/LoadFile/;

use URI::FromHash 'uri';
use List::Compare;
use File::Temp qw / tempfile /;
use File::Slurp;
use JSON::Any;

use CXGN::Chado::Stock;
use SGN::View::Stock qw/stock_link stock_organisms stock_types/;


BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);
sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

has 'default_page_size' => (
    is      => 'ro',
    default => 20,
);

=head1 PUBLIC ACTIONS

=head2 submission_guidelines

Public path: /phenotype/submission_guide

Display the phenotype submission guidelines page

=cut

sub submission_guidelines :Path('/phenotype/submission_guide') Args(0) {
    my ($self, $c) = @_;
    $c->stash(template => '/phenotypes/submission_guide.mas');

}

sub delete_uploaded_phenotype_files : Path('/breeders/phenotyping/delete/') Args(1) {
     my $self  =shift;
     my $c = shift;
     my $json = new JSON;
     my $file_id = shift;
     my $decoded;
     if ($file_id){
		 $decoded = $json->allow_nonref->utf8->decode($file_id);
     }
	#print STDERR Dumper($file_id);
	print "File ID: $file_id\n"; 
     my $dbh = $c->dbc->dbh();
     #my $h = $dbh->prepare("delete from metadata.md_files where file_id=?;");
     my $h = $dbh->prepare("UPDATE metadata.md_metadata SET obsolete = 1 where metadata_id IN (SELECT metadata_id from metadata.md_files where file_id=?);");
     $h->execute($decoded);
     print STDERR "Phenotype file successfully made obsolete.\n";

	my $delete_md_files_q = "CREATE TEMP TABLE nd_experiment_ids_to_delete AS SELECT nd_experiment_id FROM phenome.nd_experiment_md_files join nd_experiment using(nd_experiment_id) join nd_experiment_phenotype using(nd_experiment_id) join phenotype using(phenotype_id) where file_id =?;

		DELETE FROM phenome.nd_experiment_md_files where nd_experiment_id IN (SELECT nd_experiment_id FROM nd_experiment_ids_to_delete);
		DELETE FROM nd_experiment where nd_experiment_id IN (SELECT nd_experiment_id FROM nd_experiment_ids_to_delete);
	";
	my $h = $dbh->prepare($delete_md_files_q);
	$h->execute($decoded);
	print STDERR "Deleted all phenotype datapoints saved in the database that originated from the file. ".$h->rows." \n";

	$c->response->redirect('/breeders/phenotyping');
}

#
return 1;
#
