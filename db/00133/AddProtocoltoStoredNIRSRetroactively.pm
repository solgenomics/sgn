#!/usr/bin/env perl


=head1 NAME

AddProtocoltoStoredNIRSRetroactively

=head1 SYNOPSIS

mx-run AddProtocoltoStoredNIRSRetroactively [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch retroactively adds a protocol for the uploaded NIRS data
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddProtocoltoStoredNIRSRetroactively;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch retroactively adds a protocol for the uploaded NIRS data

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

    my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();
    my $high_dim_nirs_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    my %nirs_protocol_prop = (device_type => 'SCIO');

    my $protocol = $schema->resultset('NaturalDiversity::NdProtocol')->create({
        name => 'NIRS Protocol',
        type_id => $high_dim_nirs_protocol_cvterm_id,
        nd_protocolprops => [{type_id => $high_dim_nirs_protocol_prop_cvterm_id, value => encode_json \%nirs_protocol_prop}]
    });
    my $protocol_id = $protocol->nd_protocol_id();

    my $desc_q = "UPDATE nd_protocol SET description=? WHERE nd_protocol_id=?;";
    my $desc_dbh = $schema->storage->dbh()->prepare($desc_q);
    $desc_dbh->execute('Default NIRS protocol', $protocol_id);

    my $protocol_query = "INSERT INTO nd_experiment_protocol ( nd_experiment_id, nd_protocol_id) VALUES (?,?);";
    my $protocol_dbh = $schema->storage->dbh()->prepare($protocol_query);

    my $q = "SELECT nd_experiment_id
        FROM phenome.nd_experiment_md_json
        JOIN metadata.md_json USING(json_id)
        WHERE json_type='nirs_spectra';";
    my $dbh = $schema->storage->dbh()->prepare($q);
    $dbh->execute();
    while (my ($nd_experiment_id) = $dbh->fetchrow_array()) {
        $protocol_dbh->execute($nd_experiment_id, $protocol_id);
    }

    print "You're done!\n";
}


####
1; #
####
