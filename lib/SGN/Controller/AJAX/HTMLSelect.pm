
=head1 SGN::Controller::AJAX::HTMLSelect - a resource to dynamically obtain html selects for a number of widely used data types

=head1 SYNOPSYS

get_location_select()

get_breeding_program_select()

get_year_select()



=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

package SGN::Controller::AJAX::HTMLSelect;

use Moose;

use Data::Dumper;
use CXGN::BreedersToolbox::Projects;
use CXGN::Page::FormattingHelpers qw | simple_selectbox_html |;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub get_location_select : Path('/ajax/html/select/locations') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "location_select";
    my $name = $c->req->param("name") || "location_select";
    my $empty = $c->req->param("empty") || "";

    my $locations = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_all_locations();
    
    my $html = simple_selectbox_html(
	name => $name,
	id => $id,
	choices => $locations,
	);
    $c->stash->{rest} = { select => $html };
}

sub get_breeding_program_select : Path('/ajax/html/select/breeding_programs') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $id = $c->req->param("id") || "breeding_program_select";
    my $name = $c->req->param("name") || "breeding_program_select";
    my $empty = $c->req->param("empty") || "";

    my $breeding_programs = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_breeding_programs();

    push @$breeding_programs, [ "", "please select" ];
    
    my $html = simple_selectbox_html(
	name => $name,
	id => $id,
	choices => $breeding_programs,
	);
    $c->stash->{rest} = { select => $html };
}

sub get_year_select : Path('/ajax/html/select/years') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "year_select";
    my $name = $c->req->param("name") || "year_select";
    my $empty = $c->req->param("empty") || "";
    
    my @years = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_all_years();

    my $html = simple_selectbox_html(
	name => $name,
	id => $id,
	choices => \@years,
	);
    $c->stash->{rest} = { select => $html };
}

sub get_genotyping_protocols_select : Path('/ajax/html/select/genotyping_protocols') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "gtp_select";
    my $name = $c->req->param("name") || "genotyping_protocol_select";
    my $empty = $c->req->param("empty") || "";
    
    my $gt_protocols = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_gt_protocols();

    my $default_gtp = $c->config->{default_genotyping_protocol};
    my %gtps = map { @$_[1] => @$_[0] } @$gt_protocols;

    if(!exists($gtps{$default_gtp})) {
	die "The default genotyping protocol: \"$default_gtp\" in sgn_local.conf doesn't match any protocols in the database";
    }

    my $html = simple_selectbox_html(
	name => $name,
	id => $id,
	choices => $gt_protocols,
	selected => $gtps{$default_gtp} 
	);
    $c->stash->{rest} = { select => $html };
}

1;
    
    
