
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
    my $schema = $self->schema();

    my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession',
    });

    my $rs = $self->schema->resultset('Stock::Stock')->search({type_id => $accession_cvterm->cvterm_id});
    #my $rs = $self->schema->resultset('Stock::Stock')->search( { 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );
    my @accessions = ();



    while (my $row = $rs->next()) { 
	push @accessions, [ $row->stock_id, $row->name, $row->description ];
    }

    return \@accessions;
}

sub get_all_accession_groups { 
    my $self = shift;
    my $schema = $self->schema();

    my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession',
    });

    my $accession_group_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession_group',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession_group',
    });

    my $accession_group_member_cvterm = $schema->resultset("Cv::Cvterm")
	->create_with({
	    name   => 'accession_group_member_of',
	    cv     => 'stock relationship',
	    db     => 'null',
	    dbxref => 'accession_group_member_of',
		      });

    my $accession_groups_rs = $schema->resultset("Stock::Stock")->search({'type_id' => $accession_group_cvterm->cvterm_id()});

    my @accessions_by_group;

    while (my $group_row = $accession_groups_rs->next()) {
	my %group_info;
	$group_info{'name'}=$group_row->name();
	$group_info{'description'}=$group_row->description();
	$group_info{'stock_id'}=$group_row->stock_id();

	my $group_members = $schema->resultset("Stock::Stock") 
	    ->search({
		'object.stock_id'=> $group_row->stock_id(),
		'stock_relationship_subjects.type_id' => $accession_group_member_cvterm->cvterm_id()
		     }, {join => {'stock_relationship_subjects' => 'object'}, order_by => { -asc => 'name'}});

	my @accessions_in_group;
	while (my $group_member_row = $group_members->next()) {
	    my %accession_info;
	    $accession_info{'name'}=$group_member_row->name();
	    $accession_info{'description'}=$group_member_row->description();
	    $accession_info{'stock_id'}=$group_member_row->stock_id();

	    my $synonyms_rs;
	    $synonyms_rs = $group_member_row->search_related('stockprops', {'type.name' => 'synonym'}, { join => 'type' });
	    my @synonyms;
	    if ($synonyms_rs) {
		while (my $synonym_row = $synonyms_rs->next()) {
		    push @synonyms, $synonym_row->value();
		}
	    }
	    $accession_info{'synonyms'}=\@synonyms;
	}
	$group_info{'members'}=\@accessions_in_group;
	push @accessions_by_group, \%group_info;
    }

    return \@accessions_by_group;
}

1;
