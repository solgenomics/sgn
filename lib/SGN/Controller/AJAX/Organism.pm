
use strict;

package SGN::Controller::AJAX::Organism;

use Moose;
use List::MoreUtils qw | any |;
use YAML::Any;
use JSON::Any;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );


=head2 autocomplete

Public Path: /organism/autocomplete

Autocomplete an organism species name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.

=cut

sub autocomplete :Path('/organism/autocomplete') :ActionClass('REST') {}

sub autocomplete_GET :Args(0) {
  my ( $self, $c ) = @_;

  my $term = $c->req->param('term');
  # trim and regularize whitespace
  $term =~ s/(^\s+|\s+)$//g;
  $term =~ s/\s+/ /g;

  my $s = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
                  ->resultset('Organism::Organism');
#  my $s = $c->stash->{organism_set};

  my @results = $s->search({ species => { ilike => '%'.$term.'%' }},
                           { rows => 15 },
                          )
                  ->get_column('species')
                  ->all;

  $c->stash->{rest} = \@results;

}


sub project_metadata :Chained('/organism/find_organism') :PathPart('metadata') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $action = $c->req->param('action');
    my $object_id = $c->req->param('object_id');
    my $prop_id = $c->req->param('prop_id');

    my $login_user_id = 0;
    my $login_user_can_modify = 0;


    $c->stash->{json} = JSON::Any->new();

    if($c->user()) { 
	$login_user_id = $c->user()->get_object()->get_sp_person_id();
	$login_user_can_modify = any { $_ =~ /curator|sequencer|submitter/i } ($c->user()->roles());

    }

    # 1. get all the props associated with the organism
    # 2. if it is a view, render them all
    # 3. if it is an edit, render them, but render the selected prop_id as an editable
    # 4. if it is a store, store the selected prop_id, display everything as static
    # 5. if it is a delete, delete the selected prop_id, display everthing as static
    
    # get all the props!

    my %props = $self->get_organism_metadata_props($c); # contains JSON strings

    my $html = "TEST";

    print STDERR "GENERATING FORM...\n";

    my $form;
    foreach my $k (keys %props) { 
	if ($prop_id == $props{organismprop_id} && $action eq "edit") { 
	    $form = $self->metadata_form($c, $prop_id);
	    $html .= $form->render_html();
	}
	else { 
	    $html .= $self->metadata_static();
	}



    }

    
#    if ($action eq 'store') {
#        %props = %{$c->request->parameters()};
#	
#    }

    my $html;
    my $error;

    if ($login_user_can_modify && ($action eq 'edit' || $action eq 'store')) {
        if (!$login_user_id) {
            $error .= 'Must be logged in to edit';
        }
     
        if ($action eq 'store') {

	    $form = $self->metadata_form($c, $prop_id);
	    print STDERR "STORING...\n";
	    
	    print STDERR join (", ", (keys(%{$c->request()->parameters}), ":", values(%{$c->req->parameters})))."\n";


            $form->process($c->req());
	    print STDERR "FORM PROCESSED.\n";
            if ($form->submitted_and_valid()) {
		print STDERR "FORM IS VALID...\n";
		my $store_props = {};

		my $props = $c->req->parameters();
		print STDERR "blabla\n";
		my %props = $self->project_metadata_prop_list();
		foreach my $p (keys(%props )) { 
		    print STDERR "Dealing with $p...\n";
		    $store_props->{$p}=$props{$p};
		}
		
		print STDERR "CALCULATED PROPS...\n";
		my $json = $c->stash->{json}->objToJson($store_props);

		#add cvterm if it does not exist
		$c->stash->{organism_rs}->first()->create_organismprops( 
		    { 'organism_metadata' => $json }, 
		    { autocreate=>1, 
		      cv_name => 'local', 
		      allow_duplicate_values => 0 
		    });
		
		my $cvterm_row = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')->resultset('Cv::Cvterm')->search( { organismprop_id=>$prop_id  } )->first();
		my $op = $c->stash->{organism_rs}->first()->organismprops({ type_id=>$cvterm_row->cvterm_id });
		if ($op >  0) {
		    $op->update( { value=>$json });
		}
	    }
	    else { 
		print "FORM IS NOT VALID...\n";
	    }
	}
    }

    if ( $action eq 'new') {
	print STDERR "ACTION = new\n";
	$form = $self->metadata_form($c, $prop_id);
	print STDERR "Rendering Form...\n";
	$html .= $form->render();
    }

    if ( $action eq 'new' || $action eq 'view' || !$action || !$login_user_can_modify) {
	print STDERR "CONSTRUCTING JSON RESPONSE...\n";
        $c->stash->{rest} = { login_user_id => $login_user_id,
                              editable_form_id => 'organism_project_metadata_form',
                              is_owner => $login_user_can_modify,
                              html => $html,
        };
    }
    elsif ($action eq 'store')  {
        $c->stash->{rest} = [ 'success' ];

    }
    else {

    ### get project metadata information for that organism

        $c->stash->{rest} = { login_user_id => $login_user_id,
                              editable_form_id => 'organism_project_metadata_form',
                              is_owner => $login_user_can_modify,
                              html => $html,


        };
    }
}


sub metadata_form { 
    my ($self, $c, $json, $prop_id) = @_;
    print STDERR "METADATA_FORM\n";
    my $data = {};
    print STDERR "JSON = '$json'\n";
    if ($json) { 
	print STDERR "CONVERTING JSON...\n";
	$data = $c->stash->{json}->jsonToObj($json); }
    else { 
	print STDERR "No JSON data provided...\n";

    }

##    print "JSON data for form: ". (Data::Dumper->Dump($data))."\n";
    print STDERR "Yeah!\n";

    my $prop_id;
    if (exists($data->{prop_id})) { 
	$prop_id = $data->{prop_id};
    }
    print STDERR "CREATING FORM FU...\n";
    my $form = HTML::FormFu->new(Load(<<YAML));
  method: POST
  attributes:
   name: organism_project_metadata_form
   id: organism_project_metadata_form
  elements:
     - type: Hidden
       name: action
       value: store
       
     - type: Hidden
       name: prop_id
       value: $prop_id
YAML
 
 ;
    print STDERR "DONE.\n";
    my %fields = $self->project_metadata_prop_list();
    foreach my $k (keys %fields) {
	print STDERR "processing $k\n";

	$form->element( { type=>'Text', name=>$k, label=>$fields{$k}, value=>$data->{$k}, size=>30 });
    }
    
    return $form;
}

sub static_html {
    my $self = shift;
    my $c = shift;
    my $json = shift;
    
    if (!$json) { return; }
    print STDERR "formatting static html for metadata: $json\n";
    my $props = %{$c->{stash}->{json}->jsonToObj($json)};

    my %fields = $self->project_metadata_prop_list();

    my $static = '<table>';

    foreach my $k (keys %fields) {
	print STDERR "Rendering $k ($fields{$k})\n";
        $static .= '<tr><td>'.$fields{$k}.'</td><td>&nbsp;</td><td><b>'.$props->{$k}.'</b></td></tr>';
    }
    
    $static .= '</table>';
    return $static;
}


=head2 project_metadata_prop_list()

defines the prop list as a hash. the key is the name of the property (stored in cvterm as a 'local' cv and referenced through 'type_id' and the value is the display text for that property.

=cut

sub project_metadata_prop_list {
    return ("genome_project_sequencing_center"    => "Sequencing Center",
            "genome_project_sequenced_accessions" => "Sequenced Accession(s)",
            "genome_project_dates"                => "Project start, end",
            "genome_project_funding_agencies"     => "Funding Agencies" );

}

sub get_organism_metadata_props {
    my $self = shift;
    my $c = shift;

    my %props;

###    my $props_rs = $c->stash->{organism_rs}->search_related( 'organismprops' );

    my $sth = $c->dbc->dbh->prepare("SELECT organismprop.organismprop_id, organismprop.value, cvterm.name FROM organismprop join cvterm on (type_id=cvterm_id) where organism_id=? and cvterm.name='organism_metadata'");
    $sth->execute($c->stash->{organism_id});
    while (my ($organism_prop_id, $value, $name) = $sth->fetchrow_array()) {
        $props{$organism_prop_id} = $value;
    }


    return %props;
}
