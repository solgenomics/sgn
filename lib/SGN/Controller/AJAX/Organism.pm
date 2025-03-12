package SGN::Controller::AJAX::Organism;
use Moose;
use List::MoreUtils qw | any |;
use YAML::Any;
use JSON::Any;
use URI::Encode;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
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

  my @results = $s->search({ species => { ilike => '%'.$term.'%' }},
                           { rows => 15 },
                          )
                  ->get_column('species')
                  ->all;

  $c->stash->{rest} = \@results;

}


=head2 project_metadata

 Usage:        Action to update metadata information about sequencing
               projects
 Desc:         Stores the sequencing metadata for each accession in an
               organismprop, using a JSON data structure for storing the
               different fields.
 Side Effects: stores/updates/deletes metadata information

=cut

sub project_metadata :Chained('/organism/find_organism') :PathPart('metadata') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $action = $c->req->param('action');

    #object id is a combination of prop_id and organism_id, separated by a "-"
    my $organism = $c->stash->{organism};
    my ($prop_id, undef) = split "-", $c->req->param('object_id') || '';
    my $organism_id = $organism->organism_id;
    my $login_user_id = 0;
    my $login_user_can_modify = 0;

    $c->stash->{json} = JSON::Any->new();

    if($c->user()) {
        $login_user_id = $c->user()->get_object()->get_sp_person_id();
        $login_user_can_modify = $c->stash->{access}->grant( $login_user_id, "write", "stocks"); # any { $_ =~ /curator|sequencer|submitter/i } ($c->user()->roles());
    }

    # 1. get all the props associated with the organism
    # 2. if it is a view, render them all
    # 3. if it is an edit, render them, but render the selected prop_id as an editable
    # 4. if it is a store, store the selected prop_id, display everything as static
    # 5. if it is a delete, delete the selected prop_id, display everthing as static

    my $form;
    my $html = "";

    if (!$action) { $action = 'view'; }
    if ($login_user_can_modify && ($action ne 'view')) {
        if (!$login_user_id) {
            $self->status_bad_request( $c, message => 'Must be logged in to edit' );
            return;
        }
        if ($action eq 'confirm_delete') {
            $organism->search_related('organismprops',{ organismprop_id=>$prop_id })->delete;
        }

        if ($action eq 'store') {
            my $props = $c->req->parameters();
            my %props = $self->project_metadata_prop_list();
            my $store_props = {};
            foreach my $p (keys(%props )) {
                $store_props->{$p}=$props->{$p};
            }
            my $json = $c->stash->{json}->objToJson($store_props);

            $form = $self->metadata_form($c, $json, $prop_id, $organism_id);

            $form->process($c->req());

            if ($form->submitted_and_valid()) {
                if ($prop_id) {
                    my $prop = $organism->find_related( 'organismprops', {
                                   organismprop_id => $prop_id,
                               });
                    unless( $prop ) {
                        $self->status_bad_request(
                            $c, message =>
                            'no such organismprop',
                         );
                        return;
                    }
                    $prop->update({ value => $json });
                }
                else {
                    $organism->create_organismprops(
                        { 'organism_sequencing_metadata' => $json },
                        { autocreate => 1,
                          cv_name    => 'local',
                          definitions => { organism_sequencing_metadata => "metadata about this organism's sequencing status" },
                        },
                     );
                }
		$c->forward('/organism/invalidate_organism_tree_cache');
            }
            else {
                $self->status_bad_request( $c, message => 'Form is not valid' );
                return;
            }
        }
    }

    my @proplist = $self->get_organism_metadata_props( $c );

    foreach my $p (@proplist) {

        if (exists($p->{organismprop_id}) && defined $prop_id && $prop_id eq $p->{organismprop_id} && $action eq "edit") {
            if ($login_user_can_modify) {
                #make the form editable
                $form = $self->metadata_form($c, $p->{json}, $prop_id, $organism_id);
                $html .= $form->render();
                $html .= "<hr />\n";
            }
        }
        else {
            $html .= $self->metadata_static($c, $p->{json});
            $html .= "<hr />\n";
        }

        if ($login_user_can_modify) {
            # add appropriate edit and delete links
            $html .= "<a href=\"javascript:organismObjectName.setObjectId('$p->{organismprop_id}-$organism_id'); organismObjectName.printForm('edit'); \">Edit</a> <a href=\"javascript:organismObjectName.setObjectId('$p->{organismprop_id}-$organism_id'); organismObjectName.printDeleteDialog();\">Delete</a><hr />";

        }
    }

    if ($login_user_can_modify && $action eq 'new') {
        $form = $self->metadata_form($c, undef, undef, $organism_id);
        $html .= $form->render();
        $html .= qq | <br /><a href="javascript:organismObjectName.render();">Cancel</a><br /><br /> | ;
    }
    elsif ($login_user_can_modify) {
        $html .=  "<br /><a href=\"javascript:organismObjectName.setObjectId('-$organism_id' ); organismObjectName.printForm('new');\">New</a>";
    }

    if ( $action eq 'new' || $action eq 'view' || !$action || !$login_user_can_modify) {
        $self->status_ok(
            $c,
            entity => { login_user_id => $login_user_id,
                        editable_form_id => 'organism_project_metadata_form',
                        is_owner => $login_user_can_modify,
                        html => $html,
                      }
            );
    }
    elsif ($action eq 'store')  {
        $self->status_ok( $c, entity => [ 'success' ] );

    }
    else {

        ### get project metadata information for that organism
        $self->status_ok( $c, entity => {
            login_user_id => $login_user_id,
            editable_form_id => 'organism_project_metadata_form',
            is_owner => $login_user_can_modify,
            html => $html,
        });
    }
}

sub metadata_form {
    my ($self, $c, $json, $prop_id, $organism_id) = @_;

    my $data = {};
    if ($json) {
        #print STDERR "CONVERTING JSON...\n";
        $data = $c->stash->{json}->jsonToObj($json); }
    else {
        #print STDERR "No JSON data provided...\n";

    }

    my $object_id = ($prop_id || '')."-".$organism_id;
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
       name: object_id
       value: $object_id
YAML

 ;

    my %fields = $self->project_metadata_prop_list();

    foreach my $k (keys %fields) {

        $form->element( { type=>'Text', name=>$k, label=>$fields{$k}, value=>$data->{$k}, size=>30 });
    }


    return $form;
}

sub metadata_static {
    my $self = shift;
    my $c = shift;
    my $json = shift;

    if (!$json) { return; }

    my %props = %{$c->{stash}->{json}->jsonToObj($json)};

    my %fields = $self->project_metadata_prop_list();

    my $static = '<table>';

    foreach my $k (keys %fields) {
        no warnings 'uninitialized';
        $static .= '<tr><td>'.$fields{$k}.'</td><td>&nbsp;</td><td><b>'.$props{$k}.'</b></td></tr>';
    }

    $static .= '</table>';
    return $static;
}


=head2 project_metadata_prop_list()

defines the prop list as a hash. the key is the name of the property (stored in cvterm as a 'local' cv and referenced through 'type_id' and the value is the display text for that property.

=cut

sub project_metadata_prop_list {
    return ("genome_project_sequencing_center"    => "Sequencing Center",
            "genome_project_sequenced_accessions" => "Accession",
            "genome_project_dates"                => "Project start, end",
            "genome_project_funding_agencies"     => "Funding Agencies",
	    "genome_project_url"                  => "Project URL", 
            "genome_project_genbank_link"         => "Genbank link",
	    "genome_project_contact_person"       => "Contact (name, email)",
            "genome_project_seed_source"          => "Seed source",
	);

}

sub get_organism_metadata_props {
    my ( $self, $c ) = @_;

    my $props = $c->stash->{organism}
                  ->search_related('organismprops',
                       { 'type.name' => 'organism_sequencing_metadata' },
                       { join => 'type', prefetch => 'type' },
                     );

    return map
       { +{ organismprop_id => $_->organismprop_id, json => $_->value, name => $_->type->name } }
       $props->all;

}

=head2 verify_name

Public Path: /organism/verify_name

Verifies that a species name exists in the database.  Returns false if the species name is not found.

=cut

sub verify_name :Path('/organism/verify_name') :ActionClass('REST') {}

sub verify_name_GET :Args(0) {
  my ( $self, $c ) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $uri = URI::Encode->new();
  my $species_name = $uri->decode($c->req->param('species_name'));
  my $organism;
  $organism = $schema->resultset("Organism::Organism")->find({species => $species_name});
  if (!$organism) {
     $c->stash->{rest} = {error => "Species name $species_name not found." };
     return;
  }
  else {
    $c->stash->{rest} = {success => "1",};
  }

}




1;
