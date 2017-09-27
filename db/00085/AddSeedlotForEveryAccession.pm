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
use Data::Dumper;

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
	my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
	my $exp_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
	my $bp_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
		type_id=>$seedlot_type_id
	});
	my %existing_seedlots;
	while(my $r=$seedlot_rs->next){
		$existing_seedlots{$r->uniquename}++;
	}

	my $accession_rs = $schema->resultset("Stock::Stock")->search(
		{
			'me.type_id'=>$accession_type_id,
			'stock_relationship_objects.type_id'=>$plot_of_type_id,
			'nd_experiment.type_id'=>$exp_type_id,
			'project_relationship_subject_projects.type_id'=>$bp_rel_type_id
		},
		{
			join=>{'stock_relationship_objects'=>{'subject'=>{'nd_experiment_stocks'=>{'nd_experiment'=>{'nd_experiment_projects'=>{'project'=>{'project_relationship_subject_projects'=>'object_project'}}}}}}},
			'+select'=>['object_project.project_id', 'object_project.name'],
			'+as'=>['bp_id', 'bp_name']
		}
	);
	my %accession_bp_hash;
	my %accession_hash;
	while(my $r=$accession_rs->next){
		$accession_bp_hash{$r->uniquename}->{$r->get_column('bp_id')}++;
		$accession_hash{$r->uniquename} = $r->stock_id;
	}
	my %highest_accession_bp_hash;
	while(my($k,$v) = each %accession_bp_hash){
		my %v = %$v;
		my @bp_ids = sort { $v{$a} <=> $v{$b} } keys %v;
		my $most_used = $bp_ids[-1];
		$highest_accession_bp_hash{$k} = $most_used;
	}
	#print STDERR Dumper \%highest_accession_bp_hash;
	

	while (my ($k,$v) = each %accession_hash){
		my $accession_uniquename = $k;
		my $accession_stock_id = $v;
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
		$sl->breeding_program_id($highest_accession_bp_hash{$accession_uniquename});
		$sl->check_name_exists(0);
		#TO DO
		#$sl->cross_id($cross_id);
		my $return = $sl->store();
		my $seedlot_id = $return->{seedlot_id};

		my $timestamp = localtime();
		my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
		$transaction->factor(1);
		$transaction->from_stock([$accession_stock_id, $accession_uniquename]);
		$transaction->to_stock([$seedlot_id, $seedlot_uniquename]);
		$transaction->amount("1");
		$transaction->timestamp($timestamp);
		$transaction->description("Auto generated seedlot from accession. DbPatch 00085");
		$transaction->operator('nmorales');
		$transaction->store();
        $sl->set_current_count_property();
	}
	

    print "You're done!\n";
}


####
1; #
####
