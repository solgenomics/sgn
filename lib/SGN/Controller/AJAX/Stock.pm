
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
use CXGN::Phenome::Schema;

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
    if (  any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
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
    } else {  $c->stash->{rest} = { error => 'user does not have a curator/sequencer/submitter account' };
    }
}


sub add_stockprop_GET {
}

sub associate_locus:Path('/ajax/stock/associate_locus') :ActionClass('REST') {}

sub associate_locus_POST :Args(0) {
}
sub associate_locus_GET :Args(0) {
    my ( $self, $c ) = @_;
    my $stock_id = $c->req->param('object_id');
    ##my $allele_id = $c->req->param('allele_id');
    #Phytoene synthase 1 (psy1) Allele: 1
    #phytoene synthase 1 (psy1)
    my $locus_input = $c->req->param('loci');
    my ($locus_data, $allele_symbol) = split (/ Allele: / ,$locus_input);
    my $is_default = $allele_symbol ? 'f' : 't' ;
    $locus_data =~ m/(.*)\s\((.*)\)/ ;
    my $locus_name = $1;
    my $locus_symbol = $2;

    my ($allele) = $c->dbic_schema('CXGN::Phenome::Schema')
        ->resultset('Locus')
        ->search({
            locus_symbol => $locus_symbol,
                 } )
        ->search_related('alleles' , {
            allele_symbol => $allele_symbol,
            is_default => $is_default} );
    if (!$allele) {
        $c->stash->{rest} = { error => "no allele found for locus '$locus_data' (allele: '$allele_symbol'" };
        return;
    }
    my $stock = $c->dbic_schema('Bio::Chado::Schema' , 'sgn_chado')
        ->resultset("Stock::Stock")->find({stock_id => $stock_id } ) ;
    my  $allele_id = $allele->allele_id;
    if ( any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {

        print STDERR "Stock_id = $stock_id , stock= $stock , allele_id = $allele_id***************\n\n\n";
# if this fails, it will throw an acception and will (probably
        # rightly) be counted as a server error
        if ($stock && $allele_id) {
            $stock->create_stockprops(
                { 'sgn allele_id' => $allele->allele_id },
                { cv_name => 'local', allow_duplicate_values => 1, autocreate => 1 },
                );
            $c->stash->{rest} = ['success'];
            # need to update the loci div!!
            $self->display_alleles();
            return;
        }
        $c->stash->{rest} = { error => 'need both valid stock_id and allele_id for adding the stockprop! ' };
    }
}

sub display_alleles : Local : ActionClass('REST') {
    my ($self, $c) = @_;

}

sub display_alleles_GET :  {
}

1;
