
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
use CXGN::Trial::Folder;

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

    if ($empty) { unshift @$locations, [ "", "please select" ] }

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

    if ($empty) { unshift @$breeding_programs, [ "", "please select" ]; }

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

sub get_trial_folder_select : Path('/ajax/html/select/folders') Args(0) {
    my $self = shift;
    my $c = shift;

    my $breeding_program_id = $c->req->param("breeding_program_id");

    my $id = $c->req->param("id") || "folder_select";
    my $name = $c->req->param("name") || "folder_select";
    my $empty = $c->req->param("empty") || ""; # set if an empty selection should be present


    my @folders = CXGN::Trial::Folder->list(
	{
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    breeding_program_id => $breeding_program_id
	});

    if ($empty) {
	unshift @folders, [ 0, "None" ];
    }

    my $html = simple_selectbox_html(
	name => $name,
	id => $id,
	choices => \@folders,
	);

    $c->stash->{rest} = { select => $html };
}

sub get_trials_select : Path('/ajax/html/select/trials') Args(0) {
    my $self = shift;
    my $c = shift;

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } );

    my $breeding_program_id = $c->req->param("breeding_program_id");
    my $projects;
    if (!$breeding_program_id) {
      $projects = $p->get_breeding_programs();
    } else {
      push @$projects, [$breeding_program_id];
    }
    
    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";
    my @trials;
    foreach my $project (@$projects) {
      my ($field_trials, $cross_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
      foreach (@$field_trials) {
          push @trials, $_;
      }
      #foreach (@$cross_trials) {
        #  push @trials, $_;
      #}
      #foreach (@$genotyping_trials) {
        #  push @trials, $_;
      #}
    }

    #print STDERR Dumper \@trials;
    my $html = simple_selectbox_html(
        multiple => 1,
      name => $name,
      id => $id,
      choices => \@trials,
    );

    $c->stash->{rest} = { select => $html };
}

sub get_genotyping_protocols_select : Path('/ajax/html/select/genotyping_protocols') Args(0) {
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "gtp_select";
    my $name = $c->req->param("name") || "genotyping_protocol_select";
    my $empty = $c->req->param("empty") || "";
    my $default_gtp;
    my %gtps;

    my $gt_protocols = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_gt_protocols();

    if (@$gt_protocols) {
	$default_gtp = $c->config->{default_genotyping_protocol};
	%gtps = map { @$_[1] => @$_[0] } @$gt_protocols;

	if(!exists($gtps{$default_gtp}) && !($default_gtp =~ /^none$/)) {
	    die "The conf variable default_genotyping_protocol: \"$default_gtp\" does not match any protocols in the database. Set it in sgn_local.conf using a protocol name from the nd_protocol table, or set it to 'none' to silence this error.";
	}
    } else {
	$gt_protocols = ["No genotyping protocols found"];
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
