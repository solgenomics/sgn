
=head1 NAME

SGN::Controller::AJAX::Stock - a REST controller class to provide the
backend for objects linked with stocks

=head1 DESCRIPTION

Add new stock properties, stock dbxrefs and so on.. 

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>
Naama Menda <nm249@cornell.edu>


=cut

package SGN::Controller::AJAX::Stock;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


=head2 add_stockprop


L<Catalyst::Action::REST> action.

Stores a new stockprop in the database

=cut

sub add_stockprop : Local : ActionClass('REST') { }

sub add_stockprop_POST {
    my ( $self, $c ) = @_;
    my $response;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    if ( 1==1) {#any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles()) {
        my $req = $c->req;

        my $stock_id = $c->req->param('stock_id');
        my $propvalue  = $c->req->param('propvalue');
        my $type_id = $c->req->param('type_id');
        my ($existing_prop) = $schema->resultset("Stock::Stockprop")->search( {
            stock_id => $stock_id,
            type_id => $type_id,
            value => $propvalue, } );
        if ($existing_prop) { $response = { error=> 'type_id/propvalue '.$type_id." ".$propvalue." already associated" } ; 
        }else {

            my $prop_rs = $schema->resultset("Stock::Stockprop")->search( {
                stock_id => $stock_id,
                type_id => $type_id, } );
            my $rank = $prop_rs ? $prop_rs->get_column('rank')->max : -1 ;
            $rank++;

            try {
            $schema->resultset("Stock::Stockprop")->find_or_create( {
                stock_id => $stock_id,
                type_id => $type_id,
                value => $propvalue,
                rank => $rank, } );
            $response = { message => "stock_id $stock_id and type_id $type_id associated with value $propvalue", }
            } catch {
                $response = { error => "Failed: $_" }
            };
        }
        $c->{stash}->{rest} = $response;
    }
}


sub display_alleles : Local : ActionClass('REST') {}

sub display_alleles_GET :  {
}

1;
