
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
    ## multiple values oare overriden by last one? "unknown_date"
    my ($op_name, $date, $stock_id, $cvterm_accession, $value);
    foreach my $line (@$contents) {
        my ($code, $time, $date) = split ",", $line;
        if ($code =~ m/^OP/) {
            my ($op, @undef) = split(/,/ , $code); #OP:Lukas
            ($op_name, undef) = split(/:/, $op) ;
        }
        if ($code =~m/^$identifier_prefix(\d+)/ ) {
            $stock_id = $1;
        }
        if ($code =~ m/^($db_name:\d+)\#(.*)/ ) {
            $cvterm_accession = $1;
            $value = $2;
            if ($value) {
                #do we allow multiple measurements per one plant per DAY ?
                $hashref->{$op_name}->{$date}->{$stock_id}->{$cvterm_accession} = $value;
            }
        }
        if ($code =~ m/^\#(.*)/) {
            $value = $1;
            $hashref->{$op_name}->{$date}->{$stock_id}->{$cvterm_accession} .= $value;
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
    ## $hashref->{$op_name}->{$date}->{$stock_id}->{$cvterm_accession} = $value;
    my @errors;
    foreach my $op (keys %$hashref) {
        #keys %{$hashref->{normal_enemies}}
        foreach my $date  (keys %{$hashref->{$op} } ) {
            foreach my $stock_id (keys %{$hashref->{$op}->{$date} } ) {
                #check if the stock exists
                my $stock = $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id } );
                if (!$stock) { push @errors, "Stock $stock_id does not exist in the database!\n"; }
                foreach my $cvterm_accession (keys %{$hashref->{$op}->{$date}->{$stock_id} } ) {
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
    }
    return @errors;
}

sub store {
    my $self = shift;
    my $schema = $self->schema;

}



###
1;#
###
