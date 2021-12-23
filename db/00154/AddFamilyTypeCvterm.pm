#!/usr/bin/env perl


=head1 NAME

 AddFamilyTypeCvterm

=head1 SYNOPSIS

mx-run AddFamilyTypeCvterm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds family_type stock_property cvterm
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddFamilyTypeCvterm;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds the 'family_type' stock_property cvterm

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


    print STDERR "INSERTING CV TERMS...\n";

    my $terms = {
        'stock_property' => [
            'family_type',
        ]
    };

	foreach my $t (keys %$terms){
		foreach (@{$terms->{$t}}){
			$schema->resultset("Cv::Cvterm")->create_with({
				name => $_,
				cv => $t
			});
		}
	}

    #add missing family_type stockprop
    my $family_name_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
    my $family_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,  'family_type', 'stock_property');
	my $family_name_rs = $schema->resultset("Stock::Stock")->search({type_id => $family_name_cvterm_id});
    if ($family_name_rs) {
        while(my $family = $family_name_rs->next()){
            my $family_id = $family->stock_id."\n";
            my $stored_family_type = $schema->resultset("Stock::Stockprop")->find({ stock_id => $family_id, type_id => $family_type_cvterm->cvterm_id()});
            if (!$stored_family_type) {
                $family->create_stockprops({$family_type_cvterm->name() => 'same_parents'});
            }
        }
    }

    print "You're done!\n";
}


####
1; #
####
