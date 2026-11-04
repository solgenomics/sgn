=head1 NAME

SGN::Controller::Variant

=head1 DESCRIPTION

Controller for pages related to genotype markers (those stored in nd_protocolprop 
and summarized in the marker materialized view).

=cut

package SGN::Controller::Variant;

use strict;
use SGN::I18N ();
use Moose;
use CXGN::Marker::SearchMatView;

BEGIN { extends 'Catalyst::Controller' }


#
# VARIANT DETAIL PAGE
#
# PATH: /variant/{variant_name}/details
#   - Get variant details
#   - Stash the variant's marker information
#   - Display variant detail page
#
sub get_variant_details: Chained('get_variant') PathPart('details') :Args(0) {
    my ( $self, $c ) = @_;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $variant_name = $c->stash->{variant_name};

    # Get variant details
    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    my $variant_details = $msearch->query({ variant => $variant_name });
    my $markers = $variant_details->{'variants'}->{$variant_name};

    # No markers found
    if ( !$markers ) {
        $c->stash->{template} = "generic_message.mas";
	    my SGN::I18N $variant_ui_i18n = SGN::I18N::translate($c);
        $c->stash->{message} = "<strong>" . SGN::I18N::translate($variant_ui_i18n, "unassigned.variant.empty.title", "No Markers Found", undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }) . "</strong>" . SGN::I18N::translate($variant_ui_i18n, "unassigned.variant.empty.variant_prefix", " for variant ", undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }) . $variant_name . "<br />" . SGN::I18N::translate($variant_ui_i18n, "unassigned.variant.empty.explanation", "You can view and search for markers from the ", undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }) . "<a href='/search/variants'>" . SGN::I18N::translate($variant_ui_i18n, "unassigned.variant.empty.search_link", "Marker Search Page", undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }) . "</a>";
        $c->detach();
    }

    $c->stash->{markers} = $markers;
    $c->stash->{template} = '/markers/genotyped/variant_details.mas';
}


# 
# PATH: /variant/{variant_name}
#   - Stash variant_name
#
sub get_variant: Chained('/') PathPart('variant') :CaptureArgs(1) {
    my ( $self, $c, $variant ) = @_;
    $c->stash->{variant_name} = $variant;
}




1;