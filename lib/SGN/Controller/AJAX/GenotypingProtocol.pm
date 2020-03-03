
=head1 NAME

SGN::Controller::AJAX::Search::GenotypingProtocol - a REST controller class to provide genotyping protocol search

=head1 DESCRIPTION


=head1 AUTHOR

=cut

package SGN::Controller::AJAX::GenotypingProtocol;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Login;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::MarkersSearch;
use JSON;
use CXGN::Tools::Run;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub genotyping_protocol_delete : Path('/ajax/genotyping_protocol/delete') : ActionClass('REST') { }

sub genotyping_protocol_delete_GET : Args(1) {
    my $self = shift;
    my $c = shift;
    my $protocol_id = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();

    my $q = "SELECT nd_experiment_id, genotype_id
        FROM genotype
        JOIN nd_experiment_genotype USING(genotype_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_protocol USING(nd_experiment_id)
        WHERE nd_protocol_id = $protocol_id AND nd_experiment.type_id = $geno_cvterm_id;
    ";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my %genotype_ids_and_nd_experiment_ids_to_delete;
    while (my ($nd_experiment_id, $genotype_id) = $h->fetchrow_array()) {
        push @{$genotype_ids_and_nd_experiment_ids_to_delete{genotype_ids}}, $genotype_id;
        push @{$genotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}}, $nd_experiment_id;
    }

    my $dir = $c->tempfiles_subdir('/genotype_data_delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'genotype_data_delete_nd_experiment_ids/fileXXXX');
    open (my $fh, ">", $temp_file_nd_experiment_id ) || die ("\nERROR: the file $temp_file_nd_experiment_id could not be found\n" );
        foreach (@{$phenotype_ids_and_nd_experiment_ids_to_delete->{nd_experiment_ids}}) {
            print $fh "$_\n";
        }
    close($fh);

    my $async_delete = CXGN::Tools::Run->new();
    $async_delete->run_async("perl $basepath/bin/delete_nd_experiment_entries.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -i $temp_file_nd_experiment_id");

}

1;

