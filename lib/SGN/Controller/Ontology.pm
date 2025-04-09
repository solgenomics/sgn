
package SGN::Controller::Ontology;

use CXGN::Chado::Cvterm;
use CXGN::People::Roles;
use URI::FromHash 'uri';
use CXGN::Page::FormattingHelpers qw | simple_selectbox_html |;
use CXGN::Onto;
use Data::Dumper;

use Moose;

BEGIN { extends 'Catalyst::Controller' };
with 'Catalyst::Component::ApplicationAttribute';


sub onto_browser : Path('/tools/onto') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $root_nodes = $c->config->{onto_root_namespaces};
    my @namespaces = split ",", $root_nodes;
    foreach my $n (@namespaces) {
	$n =~ s/\s*(\w+)\s*\(.*\)/$1/g;
	print STDERR "Adding node $n\n";
    }
    #$c->stash->{root_nodes} = $c->req->param("root_nodes");
    $c->stash->{root_nodes} = join " ", @namespaces;
    $c->stash->{db_name} = $c->req->param("db_name");
    $c->stash->{expand} = $c->req->param("expand");

    $c->stash->{template} = '/ontology/standalone.mas';

}

sub compose_trait : Path('/tools/compose') :Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
      # redirect to login page
      $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
      return;
    }

    my @composable_cvs = split ",", $c->config->{composable_cvs};
    my $dbh = $c->dbc->dbh();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id) } );
    my %html_hash;
    foreach my $name (@composable_cvs) {
        $name =~ s/^\s+|\s+$//g; # remove whitespace
        if ($name eq 'time' || $name eq 'tod' || $name eq 'toy' || $name eq 'gen' || $name eq 'evt' ) {
            print STDERR "Skipping time-related cv\n";
            next;
        }
        my $cv_type = $name."_ontology";
        #print STDERR "cv_type = $cv_type\n";


        my @root_nodes = $onto->get_root_nodes($cv_type);
        #print STDERR Dumper \@root_nodes;
        if (scalar @root_nodes > 1) {
            #create simple selectbox of root_nodes
            my $id = $name."_root_select";
            my $name = $name."_root_select";
            my $html = simple_selectbox_html(
               name => $name,
               id => $id,
               choices => \@root_nodes,
               size => '10',
               default => 'Pick an Ontology'
            );
            #put html in hash
            $html_hash{$cv_type} = $html;
        }
        else {
            my $cv_id = $root_nodes[0][0];
           my @components = $onto->get_terms($cv_id);

           my $id = $name."_select";
           my $name = $name."_select";
           my $default = 0;
           if ($default) { unshift @components, [ '', $default ]; }

           my $html = simple_selectbox_html(
              name => $name,
              multiple => 1,
              id => $id,
              choices => \@components,
              size => '10'
           );
           #put html in hash
           $html_hash{$cv_type} = $html;
       }
    }

    $c->stash->{object_select} = $html_hash{'object_ontology'};
    $c->stash->{attribute_select} = $html_hash{'attribute_ontology'};
    $c->stash->{method_select} = $html_hash{'method_ontology'};
    $c->stash->{unit_select} = $html_hash{'unit_ontology'};
    $c->stash->{trait_select} = $html_hash{'trait_ontology'};
    $c->stash->{meta_select} = $html_hash{'meta_ontology'};

    $c->stash->{composable_cvs} = $c->config->{composable_cvs};
    $c->stash->{composable_cvs_allowed_combinations} = $c->config->{composable_cvs_allowed_combinations};
    $c->stash->{composable_tod_root_cvterm} = $c->config->{composable_tod_root_cvterm};
    $c->stash->{composable_toy_root_cvterm} = $c->config->{composable_toy_root_cvterm};
    $c->stash->{composable_gen_root_cvterm} = $c->config->{composable_gen_root_cvterm};
    $c->stash->{composable_evt_root_cvterm} = $c->config->{composable_evt_root_cvterm};
    $c->stash->{composable_meta_root_cvterm} = $c->config->{composable_meta_root_cvterm};
    $c->stash->{user} = $c->user();
    $c->stash->{template} = '/ontology/compose_trait.mas';

}

1;
