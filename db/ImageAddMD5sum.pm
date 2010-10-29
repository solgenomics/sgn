=head1 NAME

 ImageAddMD5sum.pm

=head1 SYNOPSIS

mx-run ImageAddMD5sum [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds a md5sum field to the metadata.md_image table.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Lukas Mueller <lam87@cornell.edu>
 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package ImageAddMD5sum;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'Testing a Moose dbpatch';
    my @previous_requested_patches = (); #ADD HERE

    $self->name($name);
    $self->description("Adds a md5sum field to the metadata.md_image table");
    $self->prereq(\@previous_requested_patches);

}

sub patch {
    my $self=shift;


    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";



    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

GRANT SELECT, UPDATE, INSERT, DELETE ON metadata.md_image TO web_usr;

ALTER TABLE metadata.md_image ADD COLUMN md5sum text

EOSQL


print "You're done!\n";

}


####
1; #
####
