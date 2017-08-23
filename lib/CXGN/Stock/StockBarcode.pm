
package CXGN::Stock::StockBarcode;


=head1 NAME

CXGN::Stock::StockBarcode - an object to handle SGN stock data uploaded from barcode reader

=head1 USAGE

 my $sb = CXGN::Stock::StockBarcode->new({ schema => $schema} );


=head1 DESCRIPTION


=head1 AUTHORS

 Naama Menda (nm249@cornell.edu)

=cut


use strict;
use warnings;
use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;

has 'schema' => (
    is  => 'rw',
    isa =>  'DBIx::Class::Schema',
    );

has 'parsed_data' => (
    is => 'rw'
    );

has 'parse_errors' => (
    is => 'rw'
    );

has 'verify_errors' => (
    is => 'rw'
    );
has 'warnings' => (
    is => 'rw'
    );
has 'store_error' => (
    is => 'rw'
    );
has 'store_message' => (
    is => 'rw'
    );

sub parse {
    my $self = shift;
    my @errors;
    my ($contents , $identifier_prefix, $db_name ) = @_;
    print STDERR "Identifier prefix = $identifier_prefix, db_name = $db_name\n";
    my $hashref; #hashref of hashrefs for storing the uploaded data , to be used for checking the fields
    ## multiple values are kept
    my ($op_name, $project_id, $location_id, $stock_id, $cvterm_accession, $value, $date, $count);
    foreach my $line (@$contents) {
        chomp $line;
	$line =~ s/\r//g;
        $line =~ s/\s+/ /g;
        my ($code, $quantity_not_used, $time, $unused_date) = split ",", $line;
	$code =~ s/^\s+|\s+$//g;
	if ($code =~ m/^O/) { #operator name
            (undef, $op_name) = split(/:/, $code) ;
            print STDERR "FOUND operator name $op_name\n";
        }
        if ($code =~ m/^D/) {
            (undef, $date) = split(/:/, $code); #this date overrides the date recorded in each line
        }
        if ($code =~ m/^P/) { #project_id
            print STDERR "Found project $code\n";
            (undef, $project_id) = split(/:/, $code) ;
        }
        if ($code =~ m/^L/) { #nd_geolocation_id
            print STDERR "Found location $code \n";
            (undef, $location_id) = split(/:/, $code) ;
        }
        if ($code =~ m/^$identifier_prefix(\d+)/ ) {
            print STDERR "Found stock $code\n";
            $stock_id = $1;
        }
        if ($code =~ m/^($db_name:\d+)/ ) {
            print STDERR "Found cvterm : $code \n";
            $cvterm_accession = $code;

        }
        ################################
        #values are recorded only manualy and not from the barcode.
        ##################################
            #if ( defined($value) && ($value ne '') ) { #need to include 0
            #    print STDERR " **** parse ... parsing : $op_name \t $project_id \t $location_id \t $date .. stock_id = $stock_id accession = $cvterm_accession time = $time, value = $value \n\n";
            #    #do we allow multiple measurements per one plant per DAY ?
            #    $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{time}  = $time;
            #    $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{value} = $value;
            #}
        ########################################
        # values are typed  using the keypad.
        if ($code =~ m/^\d+\.?\d*/) {
            $count++;
            print "Found keypad entry $code \n";
            $value = $code;
            $hashref->{join("\t", $op_name , $project_id , $location_id , $date , $count)}->{$stock_id}->{$cvterm_accession}->{time}  = $time; #replace the time to the latest recorded
            $hashref->{join("\t", $op_name , $project_id , $location_id , $date, $count)}->{$stock_id}->{$cvterm_accession}->{value} = $value; # one value per line.
        }
        if ($code !~ /^O|^P|^L|^D|^$identifier_prefix|^$db_name:\d+|^\d/ ) {
            print STDERR  "Cannot find code ' $code ' in the database! \n\n";
            push @errors, " Data ' $code ' cannot be stored in the database! \n Please check your barcode input\n";
        }

        #O:Lukas, 12:16:46, 12/11/2012
        #P:1, 12:16:46, 12/11/2012
        #L:1, 12:16:46, 12/11/2012
        #D:2012/11/12, 12:16:48, 12/11/2012
        #CB38783, 12:17:54, 12/11/2012
        #CO_334:0000109#0, 12:18:06, 12/11/2012
        #CO_334:0000108#1, 12:18:51, 12/11/2012
        #CO_334:0000014#5, 12:19:08, 12/11/2012
        #CB38784, 12:19:22, 12/11/2012
        #CO_334:0000109#1, 12:19:54, 12/11/2012
        #CO_334:0000108#1, 12:20:05, 12/11/2012
        #CO_334:0000014#4, 12:20:12, 12/11/2012
        ##1, 12:20:35, 12/11/2012
        ##2, 12:21:01, 12/11/2012
    }
    $self->parsed_data($hashref);
    $self->parse_errors(\@errors);
}

sub verify {
    my $self = shift;
    my $schema = $self->schema;
    #check is stock exists and if cvterm exists.
    #print error only if stocks do not exist and the cvterms
    my $hashref = $self->parsed_data;
    ##  $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{time} = $time, ->{value} = $value
    my @errors;
    my @verify;
    my @warnings;
    foreach my $key (keys %$hashref) {
        my ($op, $project_id, $location_id, $date, $count) = split(/\t/, $key);
        print STDERR "***** verify found key $key !!!!!!!\n\n";
        print STDERR "verify :  ... . . . .op = $op, project_id = $project_id, location_id = $location_id, date = $date\n\n";
        if (!$project_id) { push @warnings, "Did not scan a project name, will generate a new 'UNKNOWN' project"; }
        if (!$location_id) { push @warnings, "Did not scan a location, will generate a new 'UNKNOWN' location"; }
        foreach my $stock_id (keys %{$hashref->{$key} } ) {
            #check if the stock exists
            print STDERR "verify .. Looking for stock_id $stock_id\n";
            my $stock = $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id } );
            if (!$stock) { push @errors, "Stock $stock_id does not exist in the database!\n"; }
            foreach my $cvterm_accession (keys %{$hashref->{$key}->{$stock_id} } ) {
                #push @verify 
                print STDERR "verify ... Looking for accession $cvterm_accession..\n";
                my ($db_name, $accession) = split (/:/, $cvterm_accession);
                if (!$db_name) { push @errors, "could not find valid db_name in accession $cvterm_accession\n";}
                if (!$accession) { push @errors, "Could not find valid cvterm accession in $cvterm_accession\n";}
                #check if the cvterm exists
                my $db = $schema->resultset("General::Db")->search(
                    { 'me.name' => $db_name } );
		if ($db->count) {
                    my $dbxref = $db->search_related('dbxrefs', { accession => $accession } );

                    if ($dbxref->count) {
                        my $cvterm = $dbxref->search_related("cvterm", {} )->single;
                        if (!$cvterm) { push @errors, "NO cvterm found in the database for accession $cvterm_accession!\n db_name = '" .  $db_name  . "' , accession = '" .  $accession . "' \n";
			}
                    } else {
                        push @errors, "No dbxref found for cvterm accession $accession\n";
                    }
                } else {
                    push @errors , "db_name $db_name does not exist in the database! \n";
                }
            }
        }
    }
    $self->warnings(\@warnings);
    foreach my $err (@errors) {
        print STDERR " *!*!*!error = $err\n";
    }
    $self->verify_errors(\@errors);
}

sub store {
    my $self = shift;
    my $schema = $self->schema;
    my $hashref = $self->parsed_data;
    my $message;

    my $coderef = sub {
        # find the cvterm for a phenotyping experiment
        my $pheno_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type');

        print STDERR " ***store: phenotyping experiment cvterm = " . $pheno_cvterm->cvterm_id . "\n";
        ##
        ##  $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{time} = $time, ->{value} = $value
        foreach my $key (keys %$hashref) {
            my ($op, $project_id, $location_id, $date, $count) = split /\t/, $key;
            print STDERR " *** store: op = $op, project_id = $project_id, location_id = $location_id, date = $date\n";
            foreach my $stock_id (keys %{$hashref->{$key} } ) {
                print STDERR " *** store: loading information for stock $stock_id \n";
                foreach my $cvterm_accession (keys %{$hashref->{$key}->{$stock_id} } ) {
                    print STDERR " ** store: cvterm_accession = $cvterm_accession\n";
                    my $time = $hashref->{$key}->{$stock_id}->{$cvterm_accession}->{time};
                    my $value = $hashref->{$key}->{$stock_id}->{$cvterm_accession}->{value};
                    print STDERR " ** store: time = $time, value = $value\n";
                    my ($db_name, $accession) = split (/:/, $cvterm_accession);
                    my $db = $schema->resultset("General::Db")->search(
                        {'me.name' => $db_name, } );
                    print STDERR " ** store: found db $db_name , accession = $accession \n";
                    if ($db) {
                        my $dbxref = $db->search_related("dbxrefs", { accession => $accession, });
                        if ($dbxref) {
                            my $cvterm = $dbxref->search_related("cvterm")->single;
                            #now get the value and store the whole thing in the database!
                            my $stock = $self->schema->resultset("Stock::Stock")->find( { stock_id => $stock_id});
                            my $stock_name = $stock->name;
                            my ($location, $project);
                            if ($location_id) {
                                $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find(
                                    { nd_geolocation_id => $location_id } );
                            } else {
                                my $location_desc = "Unknown location";
                                $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find_or_create(
                                    {
                                        description => $location,
                                    } );
                                $location_id = $location->get_column('nd_geolocation_id') ;
                                print STDERR " ** store loaded location " . $location->description . "\n" ;
                            }
                            if (!$project_id) {
                                $project = $schema->resultset("Project::Project")->find_or_create(
                                    {
                                        name => "Unknown project ($date)",
                                        description => "Plants assayed at " . $location->description . " in date $date",
                                    } );
                                $project_id = $project->project_id ;
                                print STDERR " ** store: loaded new project " . $project->name . "\n";
                            }
                            print STDERR " ** store: location = $location_id, project = $project_id\n";
                            ###store a new nd_experiment. One experiment per stock
                            my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create(
                                {
                                    nd_geolocation_id => $location_id,
                                    type_id => $pheno_cvterm->cvterm_id(),
                                } );
                            print STDERR " ** store: created new experiment " . $experiment->nd_experiment_id . "\n";
                            #link to the project
                            $experiment->find_or_create_related('nd_experiment_projects', {
                                project_id => $project_id
                                                                } );
                            print STDERR " ** store: linking experiment " . $experiment->nd_experiment_id . " with project $project_id \n";
                            #link the experiment to the stock
                            $experiment->find_or_create_related('nd_experiment_stocks' , {
                                stock_id => $stock_id,
                                type_id  =>  $pheno_cvterm->cvterm_id,
                                                                });
                            print STDERR " ** store: linking experiment " . $experiment->nd_experiment_id . " to stock $stock_id \n";
                            #the date and time string is a property of the nd_experiment
                            $experiment->create_nd_experimentprops(
                                { date => $date } ,
                                { autocreate => 1 , cv_name => 'local' }
                                );
                            $experiment->create_nd_experimentprops(
                                { time => $time } ,
                                { autocreate => 1 , cv_name => 'local' }
                                );
                            print STDERR " ***  store: created cvtermprops for date ($date) and time ($time)\n";
                            my $uniquename = "Stock: " . $stock_id . ", trait: " . $cvterm->name . " date: $date" . " barcode operator = $op" ;
                            my $phenotype = $cvterm->find_or_create_related(
                                "phenotype_cvalues", {
                                    observable_id => $cvterm->cvterm_id,
                                    value => $value ,
                                    uniquename => $uniquename,
                                });
                            print STDERR " ** store: added phenotype value $value , observable = " . $cvterm->name ." uniquename = $uniquename \n";
                            #link the phenotpe to the experiment
                            $experiment->find_or_create_related('nd_experiment_phenotypes' , {
                                phenotype_id => $phenotype->phenotype_id });
                            $message .= "Added phenotype: trait= " . $cvterm->name . ", value = $value, to stock " . qq|<a href="/stock/$stock_id/view">$stock_name</a><br />| ;
                        }
                    }
                }
            }
        }
    };
    my $error;
    try {
        $schema->txn_do($coderef);
        $error = "Store completed!";
    } catch {
        # Transaction failed
        $error =  "An error occured! Cannot store data! <br />" . $_ . "\n";
    };
    $self->store_error($error);
    $self->store_message($message);
}

###
1;#
###
