
use strict;

package SGN::Controller::AJAX::Organism;

use Moose;
use List::MoreUtils qw | any |;
use YAML::Any;

BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config( 
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );



=head2 sol100_image_tag

=cut

sub sol100_image_tag :Path('/organism/sol100/image_tag') :ActionClass('REST') {}

sub sol100_image_tag_GET { 
    my ($self, $c) = @_;

}

=head2 add_sol100_organism

Public Path: /organism/sol100/add_organism

POST target to add an organism to the set of sol100 organisms.  Takes
one param, C<species>, which is the exact string species name in the
DB.

After adding, redirects to C<view_sol100>.

=cut

sub add_sol100_organism :Path('/organism/sol100/add_organism') :ActionClass('REST') {}

sub add_sol100_organism_POST { 
    my ( $self, $c ) = @_;

    my $species = $c->req->param("species");
 #   my $property = $c->req->param("property");
    my $value    = $c->req->param("value");

    

    my $organism = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
                     ->resultset('Organism::Organism')
                     ->search({ species => { ilike => $c->req->body_parameters->{species} }})
                     ->single;



    # if this fails, it will throw an acception and will (probably
    # rightly) be counted as a server error
    $organism->create_organismprops(
        { 'sol100' => 1 },
        { autocreate => 1 },
       );

#    if ($property && $value) { 
#	$organism->create_organismprops(
#	    { $property => $value },
#	    { autocreate => 1 },
#	    );

    
    $c->forward("SGN::Controller::Organism", 'invalidate_organism_tree_cache', ['sol100']);
    
    $c->stash->{rest} = [ 'success' ];

    #$c->res->redirect($c->uri_for_action('/organism/view_sol100'));
}


=head2 add_organism_prop

=cut

sub add_organism_prop:Path('/ajax/organism/add_prop') :ActionClass('REST') {}

sub add_organism_prop_GET :Args(0) {
  my ( $self, $c ) = @_;
  
  my $organism_id = $c->req->param("organism_id");
  my $prop = $c->req->param("prop");
  my $value    = $c->req->param("value");

  print STDERR "PROP: $prop\n";

  if (any { $prop eq $_ } $self->organism_prop_keys()) { 
      
      my $organism = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
	  ->resultset('Organism::Organism')
	  ->search({ organism_id => $organism_id })
	  ->single;

      if (!$organism) { 
	  $c->stash->{rest} = { error => "no organism found for organism_id '$organism_id'" };
	  return;
      }
      
      if ($prop && $value) { 
	  $organism->create_organismprops(
	      { $prop => $value },
	      { autocreate => 1 },
	      );
	  $c->stash->{rest} = ['success'];
	  
	  return;
      
      }
      $c->stash->{rest} = { error => 'need both property and value parameters' };
      
      
  }
  else { 
      $c->stash->{rest} = { error => 'illegal organism prop' };
  }
}

sub organism_prop_keys { 
    my $self = shift;

    return ('Sequencing facility', 'Accessions', 'Project Leader', 'sol100');
}



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

    my $login_user_id = 0;
    my $login_user_can_modify = 0;

    if($c->user()) { 
	$login_user_id = $c->user()->get_object()->get_sp_person_id();
	$login_user_can_modify = any { $_ =~ /curator|sequence/i } ($c->user()->roles());
    }
    my %props; 
    if ($action eq 'edit' || $action eq 'view' || !$action) { 
	%props = $self->get_project_metadata_props($c);
    }
    if ($action eq 'store') { 
	%props = %{$c->request->parameters()};
    }

    my $html;
    my $error;

    if ($login_user_can_modify && ($action eq 'edit' || $action eq 'store')) { 
	if (!$login_user_id) { 
	    $error .= 'Must be logged in to edit';
	}
	my $form = HTML::FormFu->new(Load(<<YAML));
method: POST
attributes:
    name: organism_project_metadata_form
    id: organism_project_metadata_form
elements:
  - type: Hidden
    name: action
    value: store

YAML

;
	foreach my $k ($self->project_metadata_prop_list()) {
	    $form->element( { type=>'Text', name=>$k, label=>$k, value=>$props{$k}, size=>30 });
	}
	
	$html = $form->render();
	if ($action eq 'store') { 

	    print STDERR "STORING FORM....\n\n";

	    $form->process($c->req);
	    
	    print STDERR "FORM PROCESSED.\n";

	    if ($form->submitted_and_valid()) { 
		print STDERR "FORM VALID!!!!\n\n";
		foreach my $k ($self->project_metadata_prop_list()) { 
		    my $value = $c->request->param($k);
		    if (defined($value)) { 
			my $cvterm_row = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')->resultset('Cv::Cvterm')->search( { name=>$k  } )->first();
			if ($cvterm_row) { 
			    my $op = $c->stash->{organism_rs}->first()->organismprops({ type_id=>$cvterm_row->cvterm_id });
			    if ($op) { 
				$op->update( { value=>$value });
			    }
			    else { 
				$c->stash->{organism_rs}->first()->create_organismprops( { $k => $c->request->param($k) }, { autocreate=>1, cv_name => 'local', allow_duplicate_values => 0 });
			    }
			}
		    }
		}
	    }
	    


	}
	
	
    }



    if ( $action eq 'view' || !$action || !$login_user_can_modify) { 
	$html = $self->static_html(%props);
	$c->stash->{rest} = { login_user_id => $login_user_id,
			      editable_form_id => 'organism_project_metadata_from',
			      is_owner => $login_user_can_modify,
			      html => $self->static_html(%props),
			      
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

sub static_html { 
    my $self = shift;
    my %props = @_;
    my $static = '<table>';
	foreach my $k ($self->project_metadata_prop_list()) { 
	    $static .= '<tr><td>'.$k.'</td><td>&nbsp;</td><td><b>'.$props{$k}.'</b></td></tr>';
	}
	$static .= '</table>';
    return $static;
}


sub project_metadata_prop_list { 
    return ("Sequencing Center", "Sequenced Accession(s)", "Project start", "Project end");
}

sub get_project_metadata_props { 
    my $self = shift;
    my $c = shift;

    my %props;
  
###    my $props_rs = $c->stash->{organism_rs}->search_related( 'organismprops' );

    my $sth = $c->dbc->dbh->prepare('SELECT organismprop.value, cvterm.name FROM organismprop join cvterm on (type_id=cvterm_id) where organism_id=?');
    $sth->execute($c->stash->{organism_id});
    while (my ($value, $name) = $sth->fetchrow_array()) { 
	$props{$name} = $value;
    }
    

    return %props;
}
