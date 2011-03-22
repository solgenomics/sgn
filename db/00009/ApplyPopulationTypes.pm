
package ApplyPopulationTypes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

sub init_patch {

    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'Adding explicit population types to stocks of type population';
    my @previous_requested_patches = ('LoadPhenomeInStock'); #ADD HERE
    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);
}

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
        my $cvterm_rs = $schema->resultset('Cv::Cvterm');
        my $f2_cvterm = $cvterm_rs->create_with( {
            name => 'f2 population',
            cv   => 'stock type', }
            );
        my $bc_cvterm = $cvterm_rs->create_with( {
            name => 'backcross population',
            cv   => 'stock type', }
            );
        my $mutant_cvterm = $cvterm_rs->create_with( {
            name => 'mutant population',
            cv   => 'stock type', }
            );
        my $population_stocks = $schema->resultset('Cv::Cvterm')->search( { 'me.name' => 'population' } )->
            search_related('stocks');
        while (my $population = $population_stocks->next) {
            my $population_name = $population->name;
            print "Looking at population $population_name..\n";
            if ( grep {  /F2/i  } ($population_name) ) {
                print "updating type to " . $f2_cvterm->name . "\n";
                $population->update( { type_id=>$f2_cvterm->cvterm_id } );
            }
            if ( grep {  /Backcross/i  } ($population_name) ) {
                print "updating type to " . $bc_cvterm->name . "\n";
                $population->update( { type_id=>$bc_cvterm->cvterm_id } );
            }
            if ( grep {  /mutant/i  } ($population_name) ) {
                print "updating type to " . $mutant_cvterm->name . "\n";
                $population->update( { type_id=>$mutant_cvterm->cvterm_id } );
            }
        }
        if ($self->trial) {
            print "Trial mode! Rolling back transaction\n\n";
            $schema->txn_rollback;
        }
        return 1;
    };

    try {
	$schema->txn_do($coderef);
	print "Data committed! \n";
    } catch {
	die "Load failed! " . $_ .  "\n" ;
    };

    print "You're done!\n";
}


####
1; #
####

