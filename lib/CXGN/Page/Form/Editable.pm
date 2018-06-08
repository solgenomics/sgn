
=head1 NAME

CXGN::Page::Form::Editable.pm -- classes to deal with user-modifiable web forms

=head1 DESCRIPTION

This is a subclass of L<CXGN::Page::Form::Static>, and overrides the functions therein to generate editable components in the form. For more information, see L<CXGN::Page::Form::Static>.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=cut

use strict;
use CXGN::Page;
use CXGN::Page::Form::Static;
use CXGN::Page::Form::EditableField;
use CXGN::Page::Form::EditableSelect;
use CXGN::Page::Form::EditableHidden;
use CXGN::Page::Form::EditableTextArea;
use CXGN::Page::Form::EditableCheckbox;
use CXGN::Page::Form::EditablePasswordField;
use CXGN::Page::Form::EditableRadioList;
use CXGN::Page::Form::EditableMultiSelect;

package CXGN::Page::Form::Editable;

use base qw / CXGN::Page::Form::Static /;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	my $args=shift;
	$self->set_form_id($args->{form_id}); #optional. Set a form id. Required for javasctipt forms
	$self->set_no_buttons($args->{no_buttons}); #optional. Used in javascript forms, which should generate their own 'store' and 'reset form' buttons.
	$self->set_reset_button_text("Reset form");
	$self->set_submit_button_text("Store");
	$self->set_submit_method(); #use hardcoded default

	return $self;
}

=head2 is_editable

Whether the form can be filled in.

=cut

sub is_editable {
	return 1;
}

=head2 propagate_input

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub propagate_input {
    my $self = shift;
    my %args = @_;
    
    my %distinct_objects = ();
    # propagate the input to the form object
    #

    foreach my $f ($self->get_fields()) { 
	my $setter = $f->get_object_setter();
	
	#print STDERR "FUNCTION: " .$setter." field contents: ".($args{$f->get_field_name()})." field name: ".$f->get_field_name()." getter: ".$f->get_object_getter()." setter: ".$f->get_object_setter()."\n";
	
	if ($setter)
	{
		if($f->is_store_enabled())
		{
			$f->get_object()->$setter($args{$f->get_field_name()});
		}
		$f->set_store_enabled(1); #must be re-disabled at each visit to the form
	    my $object = $f->get_object();
	    my $object_type = ref($object);
	    $distinct_objects{$object_type}=$f->get_object(); #can only have one object of a given type associated with a given form
	}
    }
    $self->set_distinct_objects(%distinct_objects);
    
}

=head2 get_distinct_objects

 Usage:
 Desc:         stores a hash of distinct objects in the form
               which will be used to call store on.
               The hash keys are object types and the values are
               the actual objects.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_distinct_objects {
  my $self=shift;
  return %{$self->{distinct_objects}};
}

=head2 set_distinct_objects

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:      

=cut

sub set_distinct_objects {
  my $self=shift;
  my %distinct_objects = @_;
  %{$self->{distinct_objects}}=%distinct_objects;
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

#    $self->propagate_input(%args); #think this is unnecessary, and leaving it in would mess up SimpleFormPage::validate_parameters_before_store() -- Evan, 1 / 15 / 07
    my %error_hash = ();
    foreach my $f ($self->get_fields()) { 
	my $error =  $f->validate();
	#print STDERR "validate ".$f->get_field_name()." - error $error\n";
	if ($error) { 
	    $error_hash{$f->get_field_name()}=$error;
	}
    }
    $self->set_error_hash(%error_hash);
    return %error_hash;
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
    my %args = @_;
      
    $self->propagate_input(%args);
   
  
    
    # commit the changes to the database using the store method on
    # each object
    #
    #print STDERR "STORING OBJECT...\n";
    
    my %distinct_objects = $self->get_distinct_objects();
    

    # check the uniqueness constraints of the object
    #
    foreach my $k (keys(%distinct_objects)) {
		my $obj = $distinct_objects{$k};
      if ($obj->can("exists_in_database")) { 
	  	my $message = $obj->exists_in_database; #message is optional
	 if ($message) { 
	 	my $text = 	"This object (" . ref($distinct_objects{$k}) . ") already seems to exist in the database and violates constraints. Please correct your input.\n";
		$message = "" unless ($message =~ /[a-zA-Z]/);
 	    CXGN::Page->new()->message_page($text, $message);
	}
      }
    }
    foreach my $k (keys %distinct_objects) { 
	#print STDERR " DUMP:" .Data::Dumper::Dumper($distinct_objects{$k});
	#print STDERR " STORING OBJECT: ".ref($distinct_objects{$k})."\n";
	my $id = $distinct_objects{$k}->store();
	$self->set_insert_id($k, $id);
    }
}

=head2 add_field

 Usage:
 Desc:
 Ret:
 Args:         a hash with the following keys:
                screen_name
                field_name
                contents
                length
                object
                getter
                setter
                set_if
                validate
                autocomplete
               required fields: field_name.
 Side Effects:
 Example:

=cut

sub add_field { 

    my $self = shift;
    my %args = @_;
    my $field = CXGN::Page::Form::EditableField->new(%args);
    if(exists $args{validate})
    {
    	$field->set_validate($args{validate});
    }
    if (!exists($self->{fields})) { $self->{fields}=(); }
    push @{$self->{fields}}, $field;
}

=head2 add_password_field

 Usage:
 Desc:
 Ret:
 Args:         a hash with the following keys:
                screen_name
                field_name
                contents
                length
                object
                getter
                setter
					 set_if
					 validate
               required fields: field_name.
 Side Effects:
 Example:

=cut

sub add_password_field { 

    my $self = shift;
    my %args = @_;
    my $field = CXGN::Page::Form::EditablePasswordField->new(%args);
    if(exists $args{validate})
    {
    	$field->set_validate($args{validate});
    }
    if (!exists($self->{fields})) { $self->{fields}=(); }
    push @{$self->{fields}}, $field;
}

=head2 function add_textarea

  Synopsis:	
  Arguments:    a hash with the following keys:
                screen_name
                field_name
                contents
                length
                object
                getter
                setter
					 set_if
					 validate
                required fields: field_name.
  Returns:	
  Side effects:	
  Description:	

=cut

sub add_textarea {
    my $self = shift;
    my %args = @_;
    my $field = CXGN::Page::Form::EditableTextArea->new(%args);
    if(exists $args{validate})
    {
    	$field->set_validate($args{validate});
    }
    $self->add_field_obj($field);
}

=head2 add_select

 Usage:
 Desc:
 Ret:
 Args:         display_name
               field_name
               contents
               length
               object
               getter
               setter
					set_if
					validate
               select_list_ref 
               select_id_list_ref

 Side Effects:
 Example:

=cut

sub add_select { 
    my $self = shift;
    my %args = @_;
    
    #foreach my $k (keys %args) { print "Args to add_select $k, $args{$k}\n<br />"; }
    my $select = CXGN::Page::Form::EditableSelect->new(%args);
    if(exists $args{validate})
    {
    	$select->set_validate($args{validate});
    }
    if (!exists($self->{fields})) { $self->{fields}=(); }
    push @{$self->{fields}}, $select;
}

=head2 add_hidden

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub add_hidden {
    my $self = shift;
    my %args = @_;
    
    my $hidden = CXGN::Page::Form::EditableHidden->new(%args);
    if(exists $args{validate})
    {
    	$hidden->set_validate($args{validate});
    }
    $self->add_field_obj($hidden);
}

=head2 add_checkbox

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub add_checkbox
{
    my $self = shift;
    my %args = @_;
    
    my $checkbox = CXGN::Page::Form::EditableCheckbox->new(%args);
    $self->add_field_obj($checkbox);
}

=head2 add_radio_list

 Usage:
 Desc:         
 Ret:
 Args:         
 Side Effects:
 Example:

=cut

sub add_radio_list
{
	my $self = shift;
    my %args = @_;

    my $radio = CXGN::Page::Form::EditableRadioList->new(%args);
    $self->add_field_obj($radio);
}

=head2 add_multiselect

 Usage:
 Desc:         
 Ret:
 Args:         
 Side Effects:
 Example:

=cut

sub add_multiselect
{
	my $self = shift;
    my %args = @_;

    my $radio = CXGN::Page::Form::EditableMultiSelect->new(%args);
    $self->add_field_obj($radio);
}

sub get_form_start {
     my $self = shift;

    return "<form id =\"" . $self->get_form_id() . "\" method=\"" . $self->get_submit_method() . "\" action=\"\">"; #must have action parameter for xhtml 1.0+ -- Evan, 1/7/07
}

sub get_form_end {
    my $self = shift;
    return "</form>" if $self->get_no_buttons();
    return "<input type=\"submit\" value=\"" . $self->get_submit_button_text() . "\" />
            <input type=\"reset\" value=\"" . $self->get_reset_button_text() . "\" />
            </form>";
}

=head2 get_submit_method

'get' or 'post'

=cut

sub get_submit_method
{
	my $self = shift;
	return $self->{form_submit_method};
}

=head2 set_submit_method

'get' or 'post' (case doesn't matter)

default is 'get' if no or invalid argument

=cut

sub set_submit_method
{
	my ($self, $method) = @_;
	$method = 'get' if(!defined($method) or $method !~ /^get|post$/i);
	$self->{form_submit_method} = lc($method); #lowercase
}

sub get_reset_button_text
{
	my $self = shift;
	return $self->{reset_button_text};
}

=head2 set_reset_button_text

Args: new button text (default is 'reset form')
 
[1 / 9 / 07] Not currently possible to remove the reset button.

=cut

sub set_reset_button_text
{
	my ($self, $text) = @_;
	$self->{reset_button_text} = $text;
}

sub get_submit_button_text
{
	my $self = shift;
	return $self->{submit_button_text};
}

=head2 set_submit_button_text

 Args: new button text (default is 'store')
 
=cut

sub set_submit_button_text
{
	my ($self, $text) = @_;
	$self->{submit_button_text} = $text;
}

=head2 as_table_string

 Usage:
 Desc:
 Ret:
 Args:         
	       Note: as table does not call validate itself to give some
               more control on the appearance (you don't want the 
               new input field to appear with error messages).
 Side Effects:
 Example:

=cut

sub as_table_string {
    my $self = shift;
    my $string = "";

    my %error_hash = $self->get_error_hash();
    
    my %html = $self->get_field_hash();
    
    my $has_required_field=0;
    $string .= $self->get_form_start();
    $string .=  qq {  <br/><div class="panel panel-defaut"><table class="table"> };
    foreach my $f ($self->get_fields()) { 
	my $error = "";
	if (exists($error_hash{$f->get_field_name()})) { 
	    $error=$self->get_error_message($error_hash{$f->get_field_name()})."<br />";
	    
	}
	my $required_field = "";
	if ($f->get_validate()) {
	    $required_field = qq { <font color="red">*</font> };
	    $has_required_field=1;
	}

	# print everything except the hidden fields
	#
	if (ref($f)!~/hidden/i) { 	    
	    $string .= "<tr><td>$error".($f->get_display_name())."$required_field</td><td width=\"20\">&nbsp;</td><td>".($html{$f->get_field_name()})."</td></tr>\n";
	    
	}
    }
 
    $string .= qq { <tr><td colspan="3" align="center"> };

    # print the hidden fields
    #
    foreach my $f ($self->get_fields()) { 
	if (ref($f)=~/hidden/i) { 
	    $string .= $html{$f->get_field_name()};
	}
    }
    if ($has_required_field) { 
	$string .= qq { (<font color="red">*</font> denotes required field.)<br /><br /> };
    }
    $string .= qq { </td></tr></table></div> };
    $string .= $self->get_form_end();
    return $string;

}

return 1;
