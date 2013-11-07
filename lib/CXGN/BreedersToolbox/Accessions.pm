
package CXGN::BreedersToolbox::Accessions;

=head1 NAME

CXGN::BreedersToolbox::Accessions - functions for managing accessions

=head1 USAGE

 my $accession_manager = CXGN::BreedersToolbox::Accessons->new(schema=>$schema);

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;

has 'schema' => ( isa => 'Bio::Chado::Schema',
                  is => 'rw');

sub get_all_accessions { 
    my $self = shift;
    my $rs = $self->schema->resultset('Stock::Stock')->all();
    #my $rs = $self->schema->resultset('Stock::Stock')->search( { 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );
    my @accessions = ();
    while (my $row = $rs->next()) { 
	push @accessions, [ $row->stock_id, $row->name, $row->description ];
    }

    return \@projects;
}


1;
