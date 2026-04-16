#!/usr/bin/env perl

=head1 NAME

AddTimeOntologyYear.pm

=head1 SYNOPSIS

mx-run AddTimeOntologyYear [options] [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - Adds new cvterm for time ontology: year

=head1 AUTHOR

Katherine Eaton

=head1 COPYRIGHT & LICENSE

Copyright 2025 University of Alberta

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddTimeOntologyYear;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
Adds new cvterms for time ontology age in years: year 1-100.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDERR "INSERTING CV TERMS...\n";

    my $age_in_years_rs = $schema->resultset("Cv::Cvterm")->create_with(
        { name => "time in years", definition=> "years", cv => 'cxgn_time_ontology' });
    my $age_in_years_cvterm_id = $age_in_years_rs->cvterm_id();
    my $is_a_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is_a', 'relationship')->cvterm_id();

    foreach my $year (1..100) {
        my $year_rs = $schema->resultset("Cv::Cvterm")->create_with({ name => "year $year", cv => 'cxgn_time_ontology' });
        my $year_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "year $year", 'cxgn_time_ontology')->cvterm_id();
        $schema->resultset("Cv::CvtermRelationship")->create({
            type_id    => $is_a_cvterm_id,
            subject_id => $year_rs->cvterm_id(),
            object_id  => $age_in_years_cvterm_id
        });
    }

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

-- change the db reference from null (2) to TIME (304)
-- the TIME ontology ends at accession 480, so we will start these at 480
update dbxref
set
  db_id = (select db_id from db where name = 'TIME'),
  accession = lpad((split_part(accession,' ', 2)::int + 481)::text, 7, '0')
where accession like 'autocreated:year %';

-- change the relationships
update cvterm_relationship
set
  object_id = (select cvterm_id from cvterm where name = 'time of year')
where subject_id in (select cvterm_id from cvterm where name like '%year %');

EOSQL

    print "You're done!\n";
}

####
1; #
####
