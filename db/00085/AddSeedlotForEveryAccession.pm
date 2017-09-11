#!/usr/bin/env perl


=head1 NAME

 AddSeedlotForEveryAccession.pm

=head1 SYNOPSIS

mx-run AddSeedlotForEveryAccession [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch inserts a seedlot for every accession.


This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Nick Morales<nm529@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddSeedlotForEveryAccession;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Update cassava_trait db prefix

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

	my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
	my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $accession_rs = $schema->resultset("Stock::Stock")->search({
		type_id=>$accession_type_id
	});
	
	my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
		type_id=>$seedlot_type_id
	});
	my %existing_seedlots;
	while(my $r=$seedlot_rs->next){
		$existing_seedlots{$r->uniquename}++;
	}

	my $breeding_program_id = $schema->resultset("Project::Project")->find({name=>'IITA'})->project_id();

	while (my $r = $accession_rs->next()){
		my $accession_uniquename = $r->uniquename;
		my $accession_stock_id = $r->stock_id;
		my $seedlot_uniquename = $accession_uniquename."_001";
		
		if(exists($existing_seedlots{$seedlot_uniquename})){
			next;
		}
	
		my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
		$sl->uniquename($seedlot_uniquename);
		$sl->location_code("NA");
		$sl->accession_stock_ids([$accession_stock_id]);
		#$sl->organization_name();
		#$sl->population_name($population_name);
		$sl->breeding_program_id($breeding_program_id);
		$sl->check_name_exists(0);
		#TO DO
		#$sl->cross_id($cross_id);
		my $seedlot_id = $sl->store();

		my $timestamp = localtime();
		my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
		$transaction->factor(1);
		$transaction->from_stock([$accession_stock_id, $accession_uniquename]);
		$transaction->to_stock([$seedlot_id, $seedlot_uniquename]);
		$transaction->amount("1");
		$transaction->timestamp($timestamp);
		$transaction->description("Auto generated seedlot from accession");
		$transaction->operator('nmorales');
		$transaction->store();
	}
	

    print "You're done!\n";
}


####
1; #
####
