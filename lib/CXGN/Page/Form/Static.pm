
=head1 NAME

CXGN::Form.pm -- classes to deal with user-modifiable web forms

=head1 DESCRIPTION

This class implements a "static" - or non-editable version - of a web form. This is used to display the information to users who have no edit privileges.

The counterpart to this class is L<CXGN::Page::Form::Editable>, which implements the editable version. 

Both Editable and Static implement the same interface (which is not yet formally defined, TO DO!).

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=cut


use strict;

package CXGN::Page::Form::Static;

use Data::Dumper;
use CXGN::Page::Form::Field;
use CXGN::Page::Form::Select;
use CXGN::Page::Form::Hidden;
use CXGN::Page::Form::Label;
use CXGN::Page::Form::TextArea;
use CXGN::Page::Form::Checkbox;
use CXGN::Page::Form::PasswordField;
use CXGN::Page::Form::RadioList;
use CXGN::Page::Form::MultiSelect;

=head2 new

 Usage:        $form = CXGN::Page::Form::Static->new($args_ref);
 Desc:         constructor of a form object
 Args:         a hashref with the optional fields:
                 form_id: the id of the form (required for forms
                          that work with javascript)
                          (See jslib/CXGN/Page/Form/JSFormPage.js)
 Side Effects: 
 Example:

=cut

sub new { 
    my $class = shift;
    my $args = shift;
    
    my $self = bless {}, $class;
    $self->set_form_id($args->{form_id});
    return $self;
}

=head2 is_editable

Whether the form can be filled in.

=cut

sub is_editable
{
	return 0;
}

=head2 add_field_obj

 Usage:
 Desc:         adds a field object to the form object. A field 
               object can be anything that inherits from
               CXGN::Page::Form::ElementI.
 Ret:
 Args:
 Side Effects: the field will be added to the form object. It will
               be rendered in the order it was added to the object
               when the function as_table is used.
               It will also be returned with the function 
               get_field_hash().
 Example:

=cut

sub add_field_obj { 
    my $self = shift;
    my $field = shift;
    if (!exists($self->{fields})) { $self->{fields}=(); }
    push @{$self->{fields}}, $field;
}

=head2 get_field_obj_by_name

Args: a string that was used as the 'field_name' parameter for some field
Ret: a field object with the given name, or undef if none exists

=cut

sub get_field_obj_by_name
{
	my ($self, $name) = @_;
	return undef unless exists($self->{fields});
	foreach my $obj (@{$self->{fields}})
	{
		return $obj if $obj->get_field_name() eq $name;
	}
	return undef;
}

=head2 add_field

 Usage:
 Desc:
 Ret:
 Args:         display name, form name, content, length [int], 
               object, getter, setter, set_if, validate, formatting 
 Side Effects:
 Example:

=cut

sub add_field { 
    my $self = shift;
    my %args = @_;
    my $field = CXGN::Page::Form::Field->new(%args);
    $self->add_field_obj($field);
}

=head2 add_password_field

 Usage:
 Desc:
 Ret:
 Args:         display name, form name, content, length [int], 
               object, getter, setter, set_if
 Side Effects:
 Example:

=cut

sub add_password_field { 
    my $self = shift;
    my %args = @_;
    my $field = CXGN::Page::Form::PasswordField->new(%args);
    $self->add_field_obj($field);
}

=head2 function add_textarea
    
  Usage: 
  Desc:
  Ret:
  Args:
  Side Effects:
  Example:
  
=cut

sub add_textarea {
    my $self = shift;
    my %args = @_;
    my $field = CXGN::Page::Form::TextArea->new(%args);
    $self->add_field_obj($field);
}


=head2 add_label

 Usage:
 Desc:         Adds a static label that will always be rendered 
               just as a string.
 Ret:        
 Args:         hash with keys field_name and contents
 Side Effects: will be rendered on form in as_table function, for example.
 Example:

=cut

sub add_label {
    my $self = shift;
    my %args = @_;

    my $label = CXGN::Page::Form::Label->new(%args);

    $self->add_field_obj($label);
}

=head2 add_select

 Usage:
 Desc:
 Ret:
 Args:         display name, form name, content, length [int], 
               object, getter, setter, select_list_ref, select_id_list_ref
 Side Effects:
  Description: select_list_ref is a reference to a list containing the names
               of the options in the pull down menu, select_id_list_ref contains
               the corresponding ids for each option.

=cut


sub add_select { 
    my $self = shift;
    my %args = @_;
    
    my $select = CXGN::Page::Form::Select->new(%args);
    $self->add_field_obj($select);
}


=head2 add_hidden

 Usage:
 Desc:         adds a hidden field to the form
 Ret:
 Args:         anonymous hash with field names:
               display name, form name, contents, length [int], 
               object, getter, setter
 Side Effects:
 Example:

=cut

sub add_hidden {
    my $self = shift;
    my %args = @_;

    my $hidden = CXGN::Page::Form::Hidden->new(%args);
    $self->add_field_obj($hidden);
}

=head2 add_checkbox

 Usage:
 Desc:         adds a checkbox to the form
 Ret:
 Args:         anonymous hash with field names:
               display name, form name, contents, selected, object, getter, setter.
 Side Effects:
 Example:

=cut

sub add_checkbox {
    my $self = shift;
    my %args = @_;

    my $checkbox = CXGN::Page::Form::Checkbox->new(%args);
    $self->add_field_obj($checkbox);
}

=head2 add_radio_list

 Usage:
 Desc:         adds a matched set of radio buttons to the form, in the color of your choice
 Ret:
 Args:         anonymous hash with field names:
               display name, form name, choices, labels, contents, object, getter, setter.
 Side Effects:
 Example:

=cut

sub add_radio_list
{
	my $self = shift;
    my %args = @_;

    my $radio = CXGN::Page::Form::RadioList->new(%args);
    $self->add_field_obj($radio);
}

=head2 add_multiselect

 Usage:
 Desc:         adds a select box with multiple selections allowed to the form
 Ret:
 Args:         anonymous hash with field names:
               display name, form name, choices, labels, contents, object, getter, setter.
 Side Effects:
 Example:

=cut

sub add_multiselect
{
	my $self = shift;
    my %args = @_;

    my $radio = CXGN::Page::Form::MultiSelect->new(%args);
    $self->add_field_obj($radio);
}

=head2 set_action

 Usage:        $form->set_action("/cgi-bin/myscript.pl")
 Desc:         sets the action parameter in the form.
 Ret:          nothing
 Args:         a name of a script the form should call.
 Side Effects:
 Example:

=cut

sub set_action { 
    my $self = shift;
    $self->{action}=shift;
}

=head2 get_action

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_action { 
    my $self = shift;
    if (!exists($self->{action})) { $self->{action}=""; }
    return $self->{action};
}

=head2 get_fields

 Usage:
 Desc:         
 Ret:          returns all the fields of the form, in the
               order they were added to the list (and in the 
               order they are rendered with as_table().
 Args:
 Side Effects:
 Example:

=cut

sub get_fields { 
    my $self = shift;
    if (!exists($self->{fields})) { @{$self->{fields}}=(); }
    return @{$self->{fields}};
}

=head2 get_form_start

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut


sub get_form_start { 
    my $self = shift;
    return "";
}

=head2 get_form_end

 Usage:
 Desc:         gets the ending definition of the 
               form.
 Ret:          a string representing the end of the form.
 Args:
 Side Effects:
 Example:

=cut

sub get_form_end { 
    my $self = shift;
    return "";
}

=head2 get_field_hash

 Usage:
 Desc:         Returns a hash with the field names as keys
               and the representation of the fields as values.
               For 'static' fields, usually the field contents
               are given, and for 'editable' fields, an input
               box, drop down or other appropriate form element
               is defined.
               
               Two special hash keys are defined:
               FORM_START can be used to render the start of the
                          form.
               FORM_END   can be used to render the end of the form.
 Ret:          a hash (see above)
 Args:         none
 Side Effects: none
 Example:      

=cut

sub get_field_hash { 
    my $self = shift;
    my %hash = ();
    foreach my $f ($self->get_fields()) { 
	$hash{$f->get_field_name()} = $f->render();
    }
    $hash{FORM_START}=$self->get_form_start();
    $hash{FORM_END} = $self->get_form_end();
    
    return %hash;
}


=head2 get_error_hash

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_error_hash {
  my $self=shift;
  if (!exists($self->{error_hash})) { %{$self->{error_hash}} = (); }
  return %{$self->{error_hash}};

}

=head2 set_error_hash

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_error_hash {
  my $self=shift;
  %{$self->{error_hash}}=@_;
}


=head2 validate

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub validate {
    my $self = shift;
    my %args = @_;
}

=head2 from_request

 Usage:        $form->from_request(%args)
 Desc:         populates the form contents from 
               the hash %args. The keys of the hash
               must map to field names, and the values 
               of the hash will be the field contents.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub from_request {
    my $self = shift;
    my %args = @_;
    foreach my $f ($self->get_fields())
    {
	my $field_name = $f->get_field_name();
	if (exists($args{$field_name}))
	{
	    $f->set_from_external($args{$field_name});
	}
    }
}

=head2 from_database

 Usage:        $form->from_database()
 Desc:         populates the form from the database
               using the getter functions and object references
               from the field object.
 Ret:          nothing
 Args:
 Side Effects: object contents will be filled in as values
               in the corresponding fields when form is 
               displayed.
 Example:

=cut

sub from_database {
    my $self = shift;
    foreach my $f ($self->get_fields()) { 
	my $getter = $f->get_object_getter();
	my $object = $f->get_object();
	if ($object && $getter) { 
	    my $contents = $object->$getter();
	    $f->set_from_external($contents);
	}
    }
}

=head2 fields_from_database

 Usage: Be careful; this bypasses ElementI::set_from_external()
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_fields_from_database {
    my $self = shift;
    my %fields=();

    foreach my $f ($self->get_fields()) { 
	my $getter = $f->get_object_getter();
	my $object = $f->get_object();
	my $field_name = $f->get_field_name();
	if ($object && $getter) { 
	    my $contents = $object->$getter();
	    $fields{$field_name}=$contents;
	}
    }
    return %fields;

}



=head2 as_table

 Usage:
 Desc:
 Ret:
 Args: 
 Side Effects:
 Example:

=cut

sub as_table {
    my $self = shift;
    print $self->as_table_string();
}

=head2 as_table_string

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub as_table_string {
    my $self = shift;
    my $string = qq { <br/><div class="panel panel-default"><table class="table table-hover"> };
    foreach my $f ($self->get_fields()) { 
	if (ref($f)!~/hidden/i) { 
	    $string .=  "<tr><td>".($f->get_display_name || '')."</td><td><b>".($f->render || '')."</b></td></tr>\n";
	}
    }
    $string .= qq { </table></div> };
    return $string;
}




sub get_error_message { 
    my $self = shift;
    my $error = shift;
    print  $CXGN::Page::Form::INPUT_REQUIRED_ERROR."\n";

    if ($error == $CXGN::Page::Form::ElementI::INPUT_REQUIRED_ERROR) { 
	return qq { <font color="red">Input required</font>\n };
    }
    if ($error == $CXGN::Page::Form::ElementI::INTEGER_REQUIRED_ERROR) { 
	return qq { <font color="red">Integer required</font>\n };
    }
    if ($error == $CXGN::Page::Form::ElementI::NUMBER_REQUIRED_ERROR) { 
	return qq { <font color="red">Number required</font>\n };
    }
    if ($error == $CXGN::Page::Form::ElementI::TOKEN_REQUIRED_ERROR) { 
	return qq { <font color="red">Token required. No spaces or special characters are allowed.\n</font>\n };
    }
    if ($error == $CXGN::Page::Form::ElementI::LENGTH_EXCEEDED_ERROR) { 
	return qq { <font color="red">Field length limit exceeded.\n</font> };
    }
    if ($error == $CXGN::Page::Form::ElementI::DATE_REQUIRED_ERROR) { 
	return qq { <font color="red">Date required</font> };
    }
    if ($error == $CXGN::Page::Form::ElementI::UNIQUE_REQUIRED_ERROR) { 
	return qq { <font color="red">Unique input required</font> };
    }
    if ($error == $CXGN::Page::Form::ElementI::ALLELE_SYMBOL_REQUIRED_ERROR) { 
	return qq { <font color="red">Allele symbol required XXX-NN</font> };
    }
    if ($error) { return qq { <font color="red">Unknown error [$error]\n</font> }; }
}


=head2 store

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub store {
    my $self = shift;
}

=head2 get_insert_id

 Usage:        my $id = $form->last_insert_id($myobject)
 Desc:
 Ret:          the last insert id for the object in question
 Args:         an object that was supplied as part of a field
               using the add_field or similar function
 Side Effects:
 Example:      can be used to obtain the id of the database entity
               when the store function is expected to yield an
               insert into the database.

=cut

sub get_insert_id {
    my $self=shift;
    my $object = shift;
    my $object_type = ref($object);
    if (!exists($self->{insert_id}) || !exists($self->{insert_id}->{object_type})) { 
	
    }
    else { 
	return $self->{insert_id}{object_type};
    }
}
    
=head2 set_insert_id

 Usage:        $form->set_insert_id($myobject, $last_id);
 Desc:         used internally to set the last insert id for the 
               object "myobject"
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_insert_id {
  my $self=shift;
  my $object = shift;
  my $object_type = ref($object);
  $self->{insert_id}->{object_type}=shift;
}

=head2 get_template

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_template {
  my $self=shift;
  return $self->{template};

}

=head2 set_template

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_template {
  my $self=shift;
  $self->{template}=shift;
}

=head2 parse_template

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub parse_template {
    my $self = shift;
    
    foreach my $f ($self->get_fields()) { 
    }


}

=head2 accessors get_form_id, set_form_id

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_form_id {
  my $self = shift;
  return $self->{form_id}; 
}

sub set_form_id {
  my $self = shift;
  $self->{form_id} = shift;
}


=head2 accessors get_no_buttons, set_no_buttons

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_no_buttons {
  my $self = shift;
  return $self->{no_buttons}; 
}

sub set_no_buttons {
  my $self = shift;
  $self->{no_buttons} = shift;
}

return 1;
