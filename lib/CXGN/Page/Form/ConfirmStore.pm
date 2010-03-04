
=head1 NAME

CXGN::Page::Form::ConfirmStore.pm -- classes to deal with user-modifiable web forms

=head1 DESCRIPTION

This is a subclass of L<CXGN::Page::Form::Static>, and overrides the functions therein to generate editable components in the form. For more information, see L<CXGN::Page::Form::Static>.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=cut

use strict;
use CXGN::Page;
use CXGN::Page::Form::Static;
use CXGN::Page::Form::Editable;

package CXGN::Page::Form::ConfirmStore;

use base qw / CXGN::Page::Form::Editable /;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->set_static_form(CXGN::Page::Form::Static->new()) ;
	$self->set_reset_button_text("Reset");
	$self->set_submit_button_text("Store");
	$self->set_submit_method(); #use hardcoded default
	return $self;
}

=head2 is_editable

Whether the form can be filled in.

=cut

sub is_editable {
	return 0;
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
    
    #print STDERR "args hash before in the store function: \n";
#    while (my ($key, $value) = each(%args)) { print STDERR "$key $value\n"; }
    #print STDERR "STORING FORM DATA...\n";
    
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
	  my $message = $obj->exists_in_database();
	 if ($message) { 
	     my $text = "This object (" . ref($obj) . ") already seems to exist in the database and violates constraints. Please correct your input.";
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
               required fields: field_name.
 Side Effects:
 Example:

=cut

sub add_field { 

    my $self = shift;
    my %args = @_;
    $self->get_static_form->add_field(%args);
    my $field = CXGN::Page::Form::Hidden->new(%args);
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

    $self->get_static_form->add_textarea(%args);
    my $field = CXGN::Page::Form::Hidden->new(%args);
 
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
    $self->get_static_form->add_select(%args);
    my $select = CXGN::Page::Form::Hidden->new(%args);
 
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
    $self->get_static_form->add_hidden(%args);
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
    
    $self->get_static_form->add_checkbox(%args);
    my $checkbox = CXGN::Page::Form::Hidden->new(%args);
 
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
    
    $self->get_static_form->add_radio_list(%args);
    my $radio = CXGN::Page::Form::Hidden->new(%args);
 
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
    
    $self->get_static_form->add_multiselect(%args);
    my $radio = CXGN::Page::Form::Hidden->new(%args);
   
    $self->add_field_obj($radio);
}

sub get_form_start { 
    my $self = shift;
    return "<form method=\"" . $self->get_submit_method() . "\" action=\"\">"; #must have action parameter for xhtml 1.0+ -- Evan, 1/7/07
}

sub get_form_end { 
    my $self = shift;
    return "<input type=\"submit\" value=\"" . $self->get_submit_button_text() . "\" /> 
           
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

'get' or 'post' (case does not matter)

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
               more control on the appearance (you don't wan't the 
               new input field to appear with error messages).
 Side Effects:
 Example:

=cut

sub as_table_string { 
    my $self = shift;
    my $string = "";

   
    # the static form
    my $static= $self->get_static_form();
    
    $string .= $static->as_table_string();
       
    ### the confirmStore form:
    my %error_hash = $self->get_error_hash();
    my %html = $self->get_field_hash();
    my $has_required_field=0;

    $string .= $self->get_form_start();
    $string .=  qq { <table> };
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
    $string .= qq { </td></tr></table> };
    $string .= $self->get_form_end();
   
    $string .= $static->get_form_end();

    
    return $string;
}

=head2 get_static_form

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_static_form {
  my $self=shift;
  return $self->{static_form};

}

=head2 set_static_form

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_static_form {
  my $self=shift;
  $self->{static_form}=shift;
}



1;

