=head1 NAME

SGN::Controller::AJAX::Marker - a REST controller class to provide the
backend for object linked with markers

=head1 DESCRIPTION

Add new marker properties, marker dbxrefs and so on.

=head1 AUTHOR

Clay Birkett <clb343@cornell.edu>

=cut

package SGN::Controller::AJAX::Marker;

use strict;
use Moose;
use CXGN::DB::Connection;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub add_markerprop_GET {
    my $self = shift;
    my $c = shift;
    return $self->add_stockprop_POST($c);
}

=head2 get_markerprops

 Usage:
 Desc:	Gets the markerprops of type type_id associated with a marker_name
 Ret:
 Args:

=cut

sub get_markerprops : Path('/marker/prop/get') : ActionClass('REST') { }

sub get_markerprops_GET {
    my ($self, $c) = @_;

    my @row;
    my $marker_id = $c->req->param("marker_id");
    my $marker_name = $c->req->param("marker_name");

    my $dbh = CXGN::DB::Connection->new();

    my @propinfo = ();
    my $data;

    my $q = "select cvterm_id from public.cvterm where name = 'vcf_snp_dbxref'";
    my $h = $dbh->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array(); 

    $q = "select value from nd_protocolprop where type_id = ?";
    $h = $dbh->prepare($q);
    $h->execute($type_id);
    while (@row = $h->fetchrow_array()) {
        $data = decode_json($row[0]);
	foreach (@{$data->{markers}}) {
	    if ($_->{marker_name} eq $marker_name) {
	        push @propinfo, { url => $data->{url}, type_name => $data->{dbxref}, marker_name => "$_->{marker_name}", xref_name => "$_->{xref_name}"};
            }
       }
    }

    $c->stash->{rest} = \@propinfo;

}

1;
