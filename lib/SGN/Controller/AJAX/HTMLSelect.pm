
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
use Scalar::Util qw | looks_like_number |;
use CXGN::Trial;
use CXGN::Trial::Folder;
use SGN::Model::Cvterm;
use CXGN::Chado::Stock;

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

    my $default = $c->req->param("default") || @$locations[0]->[0];

    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => $locations,
      selected => $default
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

    my $default = $c->req->param("default") || @$breeding_programs[0]->[0];
    if ($empty) { unshift @$breeding_programs, [ "", "please select" ]; }

    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => $breeding_programs,
      selected => $default
    );
    $c->stash->{rest} = { select => $html };
}

sub get_year_select : Path('/ajax/html/select/years') Args(0) {
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "year_select";
    my $name = $c->req->param("name") || "year_select";
    my $empty = $c->req->param("empty") || "";
    my $auto_generate = $c->req->param("auto_generate") || "";

    my @years;
    if ($auto_generate) {
      my $next_year = 1901 + (localtime)[5];
      my $oldest_year = $next_year - 30;
      @years = sort { $b <=> $a } ($oldest_year..$next_year);
    }
    else {
      @years = sort { $b <=> $a } CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_all_years();
    }

    my $default = $c->req->param("default") || $years[1];

    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => \@years,
      selected => $default
    );
    $c->stash->{rest} = { select => $html };
}

sub get_trial_folder_select : Path('/ajax/html/select/folders') Args(0) {
    my $self = shift;
    my $c = shift;

    my $breeding_program_id = $c->req->param("breeding_program_id");
    my $folder_for_trials = 1 ? $c->req->param("folder_for_trials") eq 'true' : 0;
    my $folder_for_crosses = 1 ? $c->req->param("folder_for_crosses") eq 'true' : 0;

    my $id = $c->req->param("id") || "folder_select";
    my $name = $c->req->param("name") || "folder_select";
    my $empty = $c->req->param("empty") || ""; # set if an empty selection should be present


    my @folders = CXGN::Trial::Folder->list({
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    breeding_program_id => $breeding_program_id,
        folder_for_trials => $folder_for_trials,
        folder_for_crosses => $folder_for_crosses
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

sub get_trial_type_select : Path('/ajax/html/select/trial_types') Args(0) {
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "trial_type_select";
    my $name = $c->req->param("name") || "trial_type_select";
    my $empty = $c->req->param("empty") || ""; # set if an empty selection should be present

    my @types = CXGN::Trial::get_all_project_types($c->dbic_schema("Bio::Chado::Schema"));

    if ($empty) {
        unshift @types, [ '', "None" ];
    }

    my $default = $c->req->param("default") || $types[0]->[0];

    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => \@types,
      selected => $default
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
    my $size = $c->req->param("size");
    my $empty = $c->req->param("empty") || "";
    my @trials;
    foreach my $project (@$projects) {
      my ($field_trials, $cross_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
      foreach (@$field_trials) {
          push @trials, $_;
      }
    }
    @trials = sort @trials;

    if ($empty) { unshift @trials, [ "", "Please select a trial" ]; }

    my $html = simple_selectbox_html(
      multiple => 1,
      name => $name,
      id => $id,
      size => $size,
      choices => \@trials,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_traits_select : Path('/ajax/html/select/traits') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trial_id = $c->req->param('trial_id') || 'all';
    my $stock_id = $c->req->param('stock_id') || 'all';
    my $stock_type = $c->req->param('stock_type') . 's' || 'none';
    my $data_level = $c->req->param('data_level') || 'all';
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    if ($data_level eq 'all') {
        $data_level = '';
    }

    my @traits;
    if (($trial_id eq 'all') && ($stock_id eq 'all')) {
      my $bs = CXGN::BreederSearch->new( { dbh=> $c->dbc->dbh() } );
      my $status = $bs->test_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass});
      if ($status->{'error'}) {
        $c->stash->{rest} = { error => $status->{'error'}};
        return;
      }
      my $query = $bs->metadata_query([ 'traits' ], {}, {});
      @traits = @{$query->{results}};
      #print STDERR "Traits: ".Dumper(@traits)."\n";
    } elsif (looks_like_number($stock_id)) {
        my $stock = CXGN::Chado::Stock->new($schema, $stock_id);
        my @trait_list = $stock->get_trait_list();
        foreach (@trait_list){
            my @val = ($_->[0], $_->[2]."|".$_->[1]);
            push @traits, \@val;
        }
    } elsif (looks_like_number($trial_id)) {
      my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$trial_id});
      my $traits_assayed = $trial->get_traits_assayed($data_level);
      foreach (@$traits_assayed) {
          my @val = ($_->[0], $_->[1]);
          push @traits, \@val;
      }
    }

    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";

    my $html = simple_selectbox_html(
      multiple => 1,
      name => $name,
      id => $id,
      choices => \@traits,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_crosses_select : Path('/ajax/html/select/crosses') Args(0) {
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
    my $size = $c->req->param("size");
    my @crosses;
    foreach my $project (@$projects) {
      my ($field_trials, $cross_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
      foreach (@$cross_trials) {
          push @crosses, $_;
      }
    }
    @crosses = sort @crosses;

    my $html = simple_selectbox_html(
      multiple => 1,
      name => $name,
      id => $id,
      size => $size,
      choices => \@crosses,
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


sub ontology_children_select : Path('/ajax/html/select/ontology_children') Args(0) {
    my ($self, $c) = @_;
    my $parent_node_cvterm = $c->request->param("parent_node_cvterm");
    my $rel_cvterm = $c->request->param("rel_cvterm");
    my $rel_cv = $c->request->param("rel_cv");

    my $select_name = $c->request->param("selectbox_name");
    my $select_id = $c->request->param("selectbox_id");

    my $empty = $c->request->param("empty") || '';

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $parent_node_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $parent_node_cvterm)->cvterm_id();
    my $rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $rel_cvterm, $rel_cv)->cvterm_id();

    my $ontology_children_ref = $schema->resultset("Cv::CvtermRelationship")->search({type_id => $rel_cvterm_id, object_id => $parent_node_cvterm_id})->search_related('subject');
    my @ontology_children;
    while (my $child = $ontology_children_ref->next() ) {
        my $dbxref_info = $child->search_related('dbxref');
        my $accession = $dbxref_info->first()->accession();
        my $db_info = $dbxref_info->search_related('db');
        my $db_name = $db_info->first()->name();
        push @ontology_children, [$child->name."|".$db_name.":".$accession, $child->name."|".$db_name.":".$accession];
    }

    @ontology_children = sort { $a->[1] cmp $b->[1] } @ontology_children;
    if ($empty) {
        unshift @ontology_children, [ 0, "None" ];
    }

    my $html = simple_selectbox_html(
        name => $select_name,
        id => $select_id,
        choices => \@ontology_children,
    );
    $c->stash->{rest} = { select => $html };
}

1;
