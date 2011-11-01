#!/usr/bin/env perl


=head1 NAME

 AddOrganismComments

=head1 SYNOPSIS

mx-run AddOrganismComments [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Removes unnecessary database constraint.

=head1 AUTHOR

    Lukas Mueller <lam87@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddOrganismComments;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => 'Removes unnecessary database constraint.' );


has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

ALTER TABLE sgn_people.forum_topic DROP CONSTRAINT chk_forum_topic_page_type;




EOSQL

print "You're done!\n";
}


####
1; #
####


# --     ALTER TABLE sgn_people.forum_topic ADD CONSTRAINT chk_forum_topic_page_type  CHECK (page_type::text = 'BAC'::text OR page_type::text = 'EST'::text OR page_type::text = 'unigene'::text OR page_type::text = 'marker'::text OR page_type::text = 'map'::text OR page_type::text = 'bac_end'::text OR page_type::text = ''::text OR page_type IS NULL OR page_type::text = 'locus'::text OR page_type::text = 'individual'::text OR page_type::text = 'pub'::text OR page_type::text = 'allele'::text OR page_type::text = 'stock'::text OR page_type::text = 'sample'::text OR page_type::text = 'organism');
