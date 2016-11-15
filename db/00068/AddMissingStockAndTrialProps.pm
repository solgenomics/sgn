#!/usr/bin/env perl


=head1 NAME

 AddMissingStockAndTrialProps.pm

=head1 SYNOPSIS

mx-run AddMissingStockAndTrialProps [options] -H hostname -D dbname -u username

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch will retrieve plot names, trial name, and trial description from trials where props are missing. If it finds missing props in the names or description it will add them to the db.

=head1 AUTHOR

 Bryan Ellerbrock <bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddMissingStockAndTrialProps;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will retrieve plot names, trial name, and trial description from trials where props are missing. If it finds missing props in the names or description it will add them to the db.


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {

      my $q = "SELECT stock_id, stock.name FROM project join projectprop USING (project_id) join nd_experiment_project using(project_id) join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) WHERE projectprop.type_id IS DISTINCT FROM (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program') AND projectprop.type_id IS DISTINCT FROM (SELECT cvterm_id from cvterm where cvterm.name = 'trial_folder') AND stock_id NOT IN (select distinct stock_id from stockprop) group by 1,2";
      my $h = $self->dbh->prepare($q);
      $h->execute();

      while (my ($id, $name) = $h->fetchrow_array()) {

        my $r = $schema->resultset("Stock::Stock")->search({stock_id=> $id })->first();

        if (my ($plot) = $name =~ m/plot:([\d]+)_/) { #add plot_number
        	print STDERR "Matched plot number $plot in plot $name\n";
        	$r->create_stockprops({'plot number' => $plot}, {autocreate => 1});
        }
        if (my ($block) = $name =~ m/block:([\d]+)_/) { # add block_number
          print STDERR "Matched block number $block in plot $name\n";
          $r->create_stockprops({block => $block}, {autocreate => 1});
        }
        if (my ($rep) = $name =~ m/replicate:([\d]+)_/) { # add rep_number
          print STDERR "Matched replicate number $rep in plot $name\n";
          $r->create_stockprops({replicate => $rep}, {autocreate => 1});
        }
      }

      my $all_trial_rs = $schema->resultset('Project::Project')->search;
      my $year_cvterm_id = $schema->resultset("Cv::Cvterm")->search( {name => 'project year' }, )->first->cvterm_id;
      my $design_cvterm_id = $schema->resultset("Cv::Cvterm")->search( {name => 'design' }, )->first->cvterm_id;

      while (my $trial = $all_trial_rs->next) {
        my $trial_name = $trial->name;
        #my $trial_description = $trial->description;
        for ($trial_name) {
          if (my ($year) = $trial_name =~ m/([\d]{4})/) {

            my $set_year = $schema->resultset('Project::Projectprop')->find_or_create(
            {
              project_id => $trial->project_id,
              type_id => $year_cvterm_id,
              value => $year
            });
            print STDERR "Trial $trial_name year set to $year \n";
            my $set_design = $schema->resultset('Project::Projectprop')->find_or_create(
            {
              project_id => $trial->project_id,
              type_id => $design_cvterm_id,
              value => 'RCBD'
            });
            print STDERR "Trial $trial_name design set to RCBD \n";
          }
        }
      }

    };

    try {
        $schema->txn_do($coderef);

    } catch {
        die "Load failed! " . $_ .  "\n" ;
    };

    print "You're done!\n";
}


####
1; #
####
