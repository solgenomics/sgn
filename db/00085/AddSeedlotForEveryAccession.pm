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
use CXGN::BreedersToolbox::Projects;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Update cassava_trait db prefix

has '+prereq' => (
	default => sub {
        ['AddSeedlotCurrentCountCvterm'],
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

	# If the patch is unable to determine to which breeding program the new seedlot belongs to, the new seedlot will be assigned to this default breeding program. Please change it here in the file to match your database.
	my $userdefined_default_breeding_program = 'test';
	my $default_breeding_program_id = $schema->resultset('Project::Project')->find({name=>$userdefined_default_breeding_program})->project_id();

	# FIRST, ADDS current_count property to seedlots already in database.
	print STDOUT "Adding current_count to any existing seedlots in database\n";

	my %existing_seedlots;
	while(my $r=$seedlot_rs->next){
		$existing_seedlots{$r->uniquename}++;

		my $sl = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$r->stock_id);
		$sl->set_current_count_property();
	}

	# SECOND, DETERMINES which breeding program an accession has been used most in. This will be used to assign the seedlot later on.
	print STDOUT "Determining which breeding program an accession has been used most in. This will be used to assign the seedlot later on.\n";

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

	# THIRD, DETERMINES if an accession has an organization associated that is actually a breeding program. If so, this breeding program will be assigned to the new seedlot.
	print STDOUT "Determining if an accession has an organization associated that is actually a breeding program. If so, this breeding program will be assigned to the new seedlot.\n";

	my $p = CXGN::BreedersToolbox::Projects->new({schema=>$schema});
	my $breeding_programs = $p->get_breeding_programs();
	my %available_breeding_program_names;
	foreach (@$breeding_programs){
		$available_breeding_program_names{$_->[1]}++;
	}
	
	my $organization_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'organization', 'stock_property')->cvterm_id();
	my $organization_accession_rs = $schema->resultset("Stock::Stock")->search(
		{
			'me.type_id'=>$accession_type_id,
			'stockprops.type_id'=>$organization_cvterm_id
		},
		{
			'join'=>{'stockprops'=>'type'},
			'+select'=>['stockprops.value'],
			'+as'=>['organization']
		}
	);
	my %accession_organization_hash;
	while (my $r=$organization_accession_rs->next){
		my $organization = $r->get_column('organization');
		if (exists($available_breeding_program_names{$organization})){
			$accession_organization_hash{$r->uniquename} = $organization;
		}
	}


	# THIRD, CREATES a seedlot for every accession in the database. Attempts to assign breeding program to seedlot based on accession's usage or accession's organization. If neither of these are found, then USERDEFINED default is assigned.
	print STDOUT "Creating seedlots\n";

	my $full_accession_rs = $schema->resultset("Stock::Stock")->search({
		type_id=>$accession_type_id
	});

	while (my $r = $full_accession_rs->next){
		my $accession_uniquename = $r->uniquename;
		my $accession_stock_id = $r->stock_id;
		my $seedlot_uniquename = $accession_uniquename."_001";

		if(exists($existing_seedlots{$seedlot_uniquename})){
			next;
		}

		my $seedlot_bp_id;
		if (exists($accession_organization_hash{$accession_uniquename})){
			$seedlot_bp_id = $accession_organization_hash{$accession_uniquename};
		} elsif (exists($highest_accession_bp_hash{$accession_uniquename})){
			$seedlot_bp_id = $highest_accession_bp_hash{$accession_uniquename};
		} else {
			$seedlot_bp_id = $default_breeding_program_id;
		}

		my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
		$sl->uniquename($seedlot_uniquename);
		$sl->location_code("NA");
		$sl->accession_stock_id($accession_stock_id);
		#$sl->organization_name();
		#$sl->population_name($population_name);
		$sl->breeding_program_id($seedlot_bp_id);
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
        $transaction->weight_gram("1");
		$transaction->timestamp($timestamp);
		$transaction->description("Auto generated seedlot from accession. DbPatch 00085");
		$transaction->operator('nmorales');
		$transaction->store();
		$sl->set_current_count_property();
        $sl->set_current_weight_property();
	}
	

	print "You're done!\n";
}


####
1; #
####
