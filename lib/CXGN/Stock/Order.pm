
package CXGN::Stock::Order;

use Moose;

has 'people_schema' => ( isa => 'Ref', is => 'rw' );

has 'order_from_person_id' => ( isa => 'Int', is => 'rw' );

has 'order_to_person_id' => ( isa => 'Int', is => 'rw' );

has 'order_status' => ( isa => 'Str', is => 'rw' );

has 'comments' => ( isa => 'Str', is => 'rw') ;


sub BUILD {
    my $self = shift;
    my $args = shift;

    my $row = $args->people_schema->resultset('SpOrder')->find( { sp_order_id => $args->{sp_order_id} } );
    
}


# class functions
#

sub get_orders_by_person_id {
    my $class = shift;
    my $people_schema = shift;
    my $person_id = shift;
    
    my $rs = $people_schema->resultset('SpOrder')->search( { order_by_person_id => $person_id } );

    my @orders;
    
    while (my $row = $rs->next()) { 
	
	my $o = CXGN::Stock::Order->new( { sp_order_id => $row->sp_order_id() } );
	push @orders, $o;
    }

    return @orders;
}

sub get_orders_from_person_id {
    my $class = shift;
    my $people_schema = shift;
    my $person_id = shift;
    
    my $rs = $people_schema->resultset('SpOrder')->search( { order_to_person_id => $person_id } );

    my @orders;
    
    while (my $row = $rs->next()) { 
	
	my $o = CXGN::Stock::Order->new( { sp_order_id => $row->sp_order_id() } );
	push @orders, $o;
    }

    return @orders;
}

}

1;
