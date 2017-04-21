
package SGN::Controller::Ontology;

use CXGN::Chado::Cvterm;
use CXGN::People::Roles;
use URI::FromHash 'uri';
use CXGN::Page::FormattingHelpers qw | simple_selectbox_html |;
use CXGN::Onto;

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
      $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
      return;
    }

    my @composable_cvs = split ",", $c->config->{composable_cvs};
    my $dbh = $c->dbc->dbh();
    my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') } );
    my %html_hash;
    foreach my $name (@composable_cvs) {
        $name =~ s/^\s+|\s+$//g; # remove whitespace
        if ($name eq 'time' || $name eq 'tod' || $name eq 'toy' || $name eq 'gen' ) {
            print STDERR "Skipping time-related cv\n";
            next;
        }
        my $cv_type = $name."_ontology";
        #print STDERR "cv_type = $cv_type\n";


        my @root_nodes = $onto->get_root_nodes($cv_type);
        #print STDERR "root nodes are: @root_nodes\n";
        if (scalar @root_nodes > 1) {
            #create simple selectbox of root_nodes
            my $id = $name."_root_select";
            my $name = $name."_root_select";
            my $default = 'Pick an ontology';
            if ($default) { unshift @root_nodes, [ '', $default ]; }
            my $html = simple_selectbox_html(
               name => $name,
               id => $id,
               choices => \@root_nodes
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
           my $multiple =  'true';

           my $html = simple_selectbox_html(
              name => $name,
              multiple => $multiple,
              id => $id,
              choices => \@components
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

    $c->stash->{composable_cvs} = $c->config->{composable_cvs};
    $c->stash->{allowed_combinations} = $c->config->{allowed_combinations};

    $c->stash->{user} = $c->user();
    $c->stash->{template} = '/ontology/compose_trait.mas';

}

1;
