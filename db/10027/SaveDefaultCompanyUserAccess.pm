#!/usr/bin/env perl


=head1 NAME

 SaveDefaultCompanyUserAccess

=head1 SYNOPSIS

mx-run SaveDefaultCompanyUserAccess [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch saves default access for users in the default company (e.g. janedoe has curator_access in ImageBreed)
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Nick Morales<nm529@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package SaveDefaultCompanyUserAccess;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
use Data::Dumper;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch saves default access for users in the default company (e.g. janedoe has curator_access in ImageBreed)

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
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );


    my $user_access_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'user_access', 'company_person_type')->cvterm_id();
    my $submitter_access_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'submitter_access', 'company_person_type')->cvterm_id();
    my $curator_access_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'curator_access', 'company_person_type')->cvterm_id();

    my %type_map = (
        $user_access_type_id => 'user_access',
        $submitter_access_type_id => 'submitter_access',
        $curator_access_type_id => 'curator_access'
    );

    my $q0 = "UPDATE sgn_people.private_company_sp_person SET type_id=? WHERE sp_person_id=?;";
    my $h0 = $schema->storage->dbh()->prepare($q0);

    my $q = "SELECT s.sp_person_id, r.name
        FROM sgn_people.sp_person_roles AS s
        JOIN sgn_people.sp_roles AS r ON(s.sp_role_id=r.sp_role_id)
        WHERE s.sp_person_id=?
        ORDER BY r.sp_role_id ASC LIMIT 1;";
    my $h = $schema->storage->dbh()->prepare($q);

    my $q1 = "SELECT sp_person_id FROM sgn_people.sp_person;";
    my $h1 = $schema->storage->dbh()->prepare($q1);
    $h1->execute();
    while ( my($sp_person_id) = $h1->fetchrow_array()) {
        $h->execute($sp_person_id);
        my ($sp_person_id, $role) = $h->fetchrow_array();

        my $access_type_id;
        if ($role eq 'curator') {
            $access_type_id = $curator_access_type_id;
        }
        elsif ($role eq 'submitter') {
            $access_type_id = $submitter_access_type_id;
        }
        else {
            $access_type_id = $user_access_type_id;
        }
        print STDERR Dumper [$sp_person_id, $role, $type_map{$access_type_id}];
        $h0->execute($access_type_id, $sp_person_id);
    }

    my $q0_v = "SELECT sp_role_id FROM sgn_people.sp_roles WHERE name='vendor';";
    my $h0_v = $schema->storage->dbh()->prepare($q0_v);
    $h0_v->execute();
    my ($vendor_role_id) = $h0_v->fetchrow_array();

    my $q0_v1 = "SELECT sp_person_id FROM sgn_people.sp_person WHERE username='janedoe';";
    my $h0_v1 = $schema->storage->dbh()->prepare($q0_v1);
    $h0_v1->execute();
    my ($janedoe_sp_person_id) = $h0_v1->fetchrow_array();

    if ($janedoe_sp_person_id) {
        my $q_vendor = "INSERT INTO sgn_people.sp_person_roles (sp_person_id, sp_role_id) VALUES (?,?);";
        my $h_vendor = $schema->storage->dbh()->prepare($q_vendor);
        $h_vendor->execute($janedoe_sp_person_id, $vendor_role_id);
    }

    print "You're done!\n";
}


####
1; #
####
