
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

has 'schema' => (
    is  => 'rw',
    isa =>  'DBIx::Class::Schema',
    );

has 'parsed_data' => (
    is => 'rw'
    );

sub parse {
    my $self = shift;
    my ($contents , $identifier_prefix, $db_name ) = shift;
    my $hashref; #hashref of hashrefs for storing the uploaded data , to be used for checking the fields
    ## multiple values are overriden by last one? "unknown_date"
    my ($op_name, $project_id, $location_id, $stock_id, $cvterm_accession, $value);
    foreach my $line (@$contents) {
        my ($code, $time, $date) = split ",", $line;
        if ($code =~ m/^O/) { #operator name
            ($op_name, undef) = split(/:/, $code) ;
        }
        if ($code =~ m/^P/) { #project_id
            ($project_id, undef) = split(/:/, $code) ;
        }
        if ($code =~ m/^L/) { #nd_geolocation_id
            ($location_id, undef) = split(/:/, $code) ;
        }
        if ($code =~m/^$identifier_prefix(\d+)/ ) {
            $stock_id = $1;
        }
        if ($code =~ m/^($db_name:\d+)\#(.*)/ ) {
            $cvterm_accession = $1;
            $value = $2;
            if ($value) {
                #do we allow multiple measurements per one plant per DAY ?
                $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{time}  = $time;
                $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{value} = $value;
            }
        }
        if ($code =~ m/^\#(.*)/) { #this is for values types using the keypad, or by scanning multiples
            $value = $1;
            $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{time}  = $time; #replace the time to the latest recorded
            $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{value} .= $value; #build the value string
        }
        #OP:Lukas, 12:16:46, 12/11/2012
        #DATE:2012/11/12, 12:16:48, 12/11/2012
        #CB38783, 12:17:54, 12/11/2012
        #CO:0000109#0, 12:18:06, 12/11/2012
        #CO:0000108#1, 12:18:51, 12/11/2012
        #CO:0000014#5, 12:19:08, 12/11/2012
        #CB38784, 12:19:22, 12/11/2012
        #CO:0000109#1, 12:19:54, 12/11/2012
        #CO:0000108#1, 12:20:05, 12/11/2012
        #CO:0000014#4, 12:20:12, 12/11/2012
        ##1, 12:20:35, 12/11/2012
        ##2, 12:21:01, 12/11/2012
    }
    $self->parsed_data($hashref);
}

sub verify {
    my $self = shift;
    my $schema = $self->schema;
    #check is stock exists and if cvterm exists.
    #print error only if stocks do not exist and the cvterms
    my $hashref = $self->parsed_data;
    ##  $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{time} = $time, ->{value} = $value
    my @errors;
    foreach my $key (keys %$hashref) {
        my ($op, $project_id, $location_id, $date) = split /\t/, $key;
        if (!$project_id) { push @errors, "Did not scan a project name, will generate a new 'UNKNOWN' project"; }
        if (!$location_id) { push @errors, "Did not scan a location, will generate a new 'UNKNOWN' location"; }
        foreach my $stock_id (keys %{$hashref->{$key}->{$date} } ) {
            #check if the stock exists
            my $stock = $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id } );
            if (!$stock) { push @errors, "Stock $stock_id does not exist in the database!\n"; }
            foreach my $cvterm_accession (keys %{$hashref->{$key}->{$stock_id} } ) {
                my ($db_name, $accession) = split (/:/, $cvterm_accession);
                if (!$db_name) { push @errors, "could not find valid db_name in accession $cvterm_accession\n";}
                if (!$accession) { push @errors, "Could not find valid cvterm accession in $cvterm_accession\n";}
                #check if the cvterm exists
                my $db = $schema->resultset("General::Db")->search(
                    { name => $db_name, } );
                if ($db) {
                    my $dbxref = $db->search_related("dbxrefs", { accession => $accession, });
                    if ($dbxref) {
                        my $cvterm = $dbxref->search_related("cvterm")->single;
                        if (!$cvterm) { push @errors, "NO cvterm found in the database for accession $cvterm_accession!\n"; }
                    } else {
                        push @errors, "No dbxref found for cvterm accession $accession\n";
                    }
                } else {
                    push @errors , "db_name $db_name does not exist in the database! \n";
                }
            }
        }
    }
    return @errors;
}

sub store {
    my $self = shift;
    my $schema = $self->schema;
    my $hashref = $self->parsed_data;
    my $coderef = sub {
        # find the cvterm for a phenotyping experiment
        my $pheno_cvterm = $schema->resultset('Cv::Cvterm')->create_with(
            { name   => 'phenotyping experiment',
              cv     => 'experiment type',
              db     => 'null',
              dbxref => 'phenotyping experiment',
            });
        ##
        ##  $hashref->{$op_name . "\t" . $project_id . "\t" . $location_id . "\t" . $date}->{$stock_id}->{$cvterm_accession}->{time} = $time, ->{value} = $value
        foreach my $key (keys %$hashref) {
            my ($op, $project_id, $location_id, $date) = split /\t/, $key;
            foreach my $stock_id (keys %{$hashref->{$key} } ) {
                #check if the stock exists
                foreach my $cvterm_accession (keys %{$hashref->{$key}->{$stock_id} } ) {
                    my $time = $hashref->{$key}->{$stock_id}->{$cvterm_accession}->{time};
                    my $value = $hashref->{$key}->{$stock_id}->{$cvterm_accession}->{value};
                    my ($db_name, $accession) = split (/:/, $cvterm_accession);
                    my $db = $schema->resultset("General::Db")->search(
                        { name => $db_name, } );
                    if ($db) {
                        my $dbxref = $db->search_related("dbxrefs", { accession => $accession, });
                        if ($dbxref) {
                            my $cvterm = $dbxref->search_related("cvterm")->single;
                            #now get the value and store the whole thing in the database!
                            my $stock = $self->schema->resultset("Stock::Stock")->find( { stock_id => $stock_id});
                            my $location;
                            if ($location_id) {
                                $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find(
                                    { nd_geoloation_id => $location_id } );
                            } else {
                                $location = "Unknown location";
                                $location_id = $schema->resultset("NaturalDiversity::NdGeolocation")->find_or_create(
                                    {
                                        description => $location,
                                    } )->get_column('nd_geolocation_id') ;
                            }
                            if (!$project_id) {
                                $project_id = $schema->resultset("Project::Project")->find_or_create(
                                    {
                                        name => "Unknown project ($date)",
                                        description => "Plants assayed at $location in date $date",
                                    } )->get_column('project_id') ;
                            }
                            ###store a new nd_experiment. One experiment per stock
                            my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create(
                                {
                                    nd_geolocation_id => $location_id,
                                    type_id => $pheno_cvterm->cvterm_id(),
                                } );
                            #link to the project
                            $experiment->find_or_create_related('nd_experiment_projects', {
                                project_id => $project_id
                                                                } );
                            #link the experiment to the stock
                            $experiment->find_or_create_related('nd_experiment_stocks' , {
                                stock_id => $stock_id,
                                type_id  =>  $pheno_cvterm->cvterm_id(),
                                                                });
                            #the date and time string is a property of the nd_experiment
                            $experiment->create_nd_experimentprops(
                                { date => $date } ,
                                { autocreate => 1 , cv_name => 'local' }
                                );
                            $experiment->create_nd_experimentprops(
                                { time => $time } ,
                                { autocreate => 1 , cv_name => 'local' }
                                );
                            my $uniquename = "Stock: " . $stock_id . ", trait: " . $cvterm->name . " date: $date" . " barcode operator = $op" ;
                            my $phenotype = $cvterm->find_or_create_related(
                                "phenotype_cvalues", {
                                    observable_id => $cvterm->cvterm_id,
                                    value => $value ,
                                    uniquename => $uniquename,
                                });
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
    return $error;
}

###
1;#
###
