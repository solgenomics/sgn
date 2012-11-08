
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
    is  => "rw",
    isa =>  'DBIx::Class::Schema',
    );


sub parse {
    my $self = shift;
    my ($contents , $identifier_prefix, $db_name ) = shift;
    my $hashref; #hashref of hashrefs for storing the uploaded data , to be used for checking the fields
    #$hashref->{$op_name}->{$date}->{$stock_name}->{$cvterm_id} = $value ;# multiple values oare overriden by last one? "unknown_date"
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
    $self->set_parsed_data($hashref);
}

sub verify {
    my $self = shift;
    #check is stock exists and if cvterm exists.
    #print error only if stocks do not exist and the cvterms
    my $data = $self->get_parsed_data;
    
    my @errors;
    return @errors;
}

sub store {
    my $self = shift;
    my $schema = $self->schema;

}

=head2 accessors get_parsed_data, set_parsed_data

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_parsed_data {
  my $self = shift;
  return $self->{parsed_data}; 
}

sub set_parsed_data {
  my $self = shift;
  $self->{parsed_data} = shift;
}



###
1;#
###
