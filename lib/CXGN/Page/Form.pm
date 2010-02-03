
package CXGN::Page::Form;


=head1 NAME

CXGN::Form.pm -- classes to deal with user-modifiable web forms

=head1 DESCRIPTION

The form classes can be used to generate forms that can be either static (non-editable) or editable and know how to save the data. They can also be used to validate form entry (see below).

=head2 Form generation and rendering

There are two form classes: CXGN::Page::Form::Static and CXGN::Page::Form::Editable. Editable inherits from static and so shared all the functions, some of which are overridden so that an editable form is generated instead of a static one.

All form elements are defined by classes that also occur in two versions: a static class and an editable class. For a form field, for example, the static class is CXGN::Page::Form::Field and the editable class is CXGN::Page::Form::EditableField, which inherits from the former. All field elements inherit from the abstract class CXGN::Page::Form::ElementI, which essentially defines and interface for form elements. 

The form classes have functions to add different form elements to the form. The functions in the Static form class will call the constructor for the static field element, and the Editable form class will call the constructor for the editable field element. It is therefore easy to change a static form to an editable one by just changing the call to the form constructor.

There are several ways in which forms can be rendered:

=over 5

=item (1)

Call the function as_table() on the form object. This will generate a simple table with field names and field values in the order they were added to the form object. 

=item (2)

The function get_field_hash() on the form object will return a hash with the field names as hash keys and the representation of the field as the value. In the case of an editable field, the value will be html for input boxes, for example. In the case of a static form, it will usually just be a text representation of the contents of the field.

=back

=head2 Form validation

When creating a form element, a "validate" parameter can be supplied, such as:

    $form->add_field( 
                     display_name=>"Name: ", 
                     field_name=>"name", 
                     length=>20, 
                     object=>$myobject, 
                     getter=>"get_name", setter=>"set_name", 
                     validate=>"string" 
                    );

This will make sure that a string type has been entered and will $form->validate() will return the field name as a hash key with an appropriate hash value if there is no input. Other input types are "integer", "number" (any number, including floats etc), and "token", which is a string without spaces or special characters.

Field lengths are not yet enforced but will be in the future. The error codes that are returned from the validate function are defined as globals in CXGN::Insitu::ElementI. 

Note that the function as_table() handles error conditions gracefully. It will print an error message next to the field when an error occurs. 

=head1 EXAMPLES

A simple form with an entry field for first and last name could be created as follows:


    if ($show_editable) { 
       $form = CXGN::Page::Form::Editable->new();
    }
    else { 
       $form=CXGN::Page::Form::Static->new();
    }
    $form->add_field(  display_name=>"First name:", field_name=>"first_name",
                       contents=>"Joe", length=>20, $object=>$person, 
                       getter=>"get_first_name", $setter=>"set_first_name" );

    $form->add_field(  display_name=>"Last name:", field_name=>"last_name",
                       contents=>"Sixpack", length=>20, $object=>$person, 
                       getter=>"get_last_name", $setter=>"set_last_name" );

    $page->header();

    $form->as_table();

    $page->footer();

To store the request from the form above, one could do the following:

%args = the apache get/post parameters as a hash

if ($action eq "store") { 
    $form->store(%args)
}

=head1 DB OBJECTS PROPERTIES

There are special requirements for the DB objects for some of the above functionality to work. Each DB object has to be represented by a Perl object (although it can map to several tables), and needs accessors for all the properties that can be specified in the add_field call. The DB function needs to implement a function called store() to store the object to the backstore.

An alternate way to represent the html would be to use the get_field_hash() function:

   my %fields = $form->get_field_hash();
   
   print $fields{FORM_START};
   print "Name: ".$fields{last_name}."<br />\n";
   print "First: ".$fields{first_name}."<br />\n";
   print $fields{FORM_END};


=head1 MORE INFORMATION, SEE ALSO

For more information, see CXGN::Page::Form::Static and CXGN::Page::Form::Editable 
For field definitions see the CXGN::Page::Form::ElementI interface.
Note that L<CXGN::Page::Form::SimpleFormPage> provides a framework for working with simple updatable forms. It knows how to handle input validation, editing, viewing, adding, and deleting database entries with the appropriate user access privilege checking. See L<CXGN::Page::Form::SimpleFormPage> for more information.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=cut


return 1;


# use strict;
# use Data::Dumper;
# use CXGN::Page::Form::Field;

# package CXGN::Page::Form::Static;

# =head2 new

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub new { 
#     my $class = shift;
#     my $self = bless {}, $class;

#     my $type = shift;
#     if ($type !~ /^editable$|^static$/i ) { 
# 	warn ("CXGN::Page::Form: No type parameter supplied, defaulting to static form\n");
#     }
#     if ($type=~/^editable$/i) { $self->set_form_editable(); }
#     if ($type=~/^static$/i) { $self->set_form_static(); }

#     return $self;
# }

# =head2 set_form_editable

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub set_form_editable {
#     my $self = shift;
#     $self->{type}="editable";
# }


# =head2 is_editable

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub is_editable { 
#     my $self = shift;
#     return ($self->get_form_type() eq "editable");
# }


# =head2 set_form_static

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut


# sub set_form_static {
#     my $self = shift;
#     $self->{type}="static";
# }


# =head2 is_static

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub is_static {
#     my $self = shift;
#     return ($self->get_form_type() eq "static");
# }



# =head2 get_form_type

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub get_form_type {
#     my $self = shift;
#     return $self->{type};
# }

# =head2 add_field

#  Usage:
#  Desc:
#  Ret:
#  Args:         display name, form name, content, length [int], 
#                object, getter, setter
#  Side Effects:
#  Example:

# =cut

# sub add_field { 
#     my $self = shift;
#     my $display_name = shift;
#     my $field_name = shift;
#     my $contents = shift;
#     my $length = shift;
#     my $object = shift;
#     my $getter = shift;
#     my $setter = shift;

#     if ($self->is_editable()) { 
# 	my $field=CXGN::Page::Form::EditableField->new($display_name, $field_name, $contents, $length, $object, $getter, $setter);
# 	$self->add_field($field);
#     }
#     if ($self->is_static()) { 
# 	my $field = CXGN::Page::Form::Field->new($display_name, $field_name, $contents, $length, $object, $getter, $setter);
# 	$self->add_field_obj($field);
#     }
# }

# =head2 add_field_obj

#  Usage:
#  Desc:         adds a field object to the form object. A field 
#                object can be anything that inherits from
#                CXGN::Page::Form::Element. Currently defined are
#                Field, Select, and Hidden, and their editable counter
#                parts EditableField, EditableSelect, EditableHidden.
#  Ret:
#  Args:
#  Side Effects: the field will be added to the form object. It will
#                be rendered in the order it was added to the object
#                when the function as_table is used.
#                It will also be returned with the function 
#                get_field_hash().
#  Example:

# =cut

# sub add_field_obj { 
#     my $self = shift;
#     my $field = shift;
#     if (!exists($self->{fields})) { $self->{fields}=(); }
#     push @{$self->{fields}}, $field;
# }   

# =head2 add_select

#  Usage:
#  Desc:
#  Ret:
#  Args:         display name, form name, content, length [int], 
#                object, getter, setter
#  Side Effects:
#  Example:

# =cut

# sub add_select { 
#     my $self = shift;

#     my $display_name = shift;
#     my $field_name = shift;
#     my $selected_id = shift;
#     my $field_len = shift;
#     my $object = shift;
#     my $getter =shift;
#     my $setter = shift;
#     my $select_list_ref = shift;
#     my $select_id_ref = shift;

#     my $select = undef;

#     if ($self->is_editable()) { 
# 	$select = CXGN::Page::Form::EditableSelect->new(
# 							$display_name, 
# 							$field_name, 
# 							$selected_id, 
# 							$field_len, 
# 							$object, 
# 							$getter, 
# 							$setter, 
# 							$select_list_ref, 
# 							$select_id_ref
# 							);
# 	$self->add_field_obj($select);
#     }

#     if ($self->is_static()) { 
    
# 	$select = CXGN::Page::Form::Select->new(
# 						$display_name, 
# 						$field_name, 
# 						$selected_id, 
# 						$field_len, 
# 						$object, 
# 						$getter, 
# 						$setter, 
# 						$select_list_ref, 
# 						$select_id_ref
# 						);
# 	$self->add_field_obj($select);
#     }
# }

# =head2 add_hidden

#  Usage:
#  Desc:         adds a hidden field to the form
#  Ret:
#  Args:         display name, form name, content, length [int], 
#                object, getter, setter.
#  Side Effects:
#  Example:

# =cut

# sub add_hidden {
#     my $self = shift;
#     my $display_name = shift;
#     my $field_name = shift;
#     my $selected_id = shift;
#     my $field_len = shift;
#     my $object = shift;
#     my $getter =shift;
#     my $setter = shift;
    
#     if ($self->is_editable()) { 
# 	my $hidden = CXGN::Form::Page::EditableHidden->new(
# 							   $display_name,
# 							   $field_name,
# 							   $selected_id,
# 							   $field_len,
# 							   $object,
# 							   $getter,
# 							   $setter
# 							   );
# 	$self->add_field_obj($hidden);
#     }
	


#     if ($self->is_static()) { 
# 	my $hidden = CXGN::Form::Page::Hidden->new(
# 						   $display_name,
# 						   $field_name,
# 						   $selected_id,
# 						   $field_len,
# 						   $object,
# 						   $getter,
# 						   $setter
# 						   );
# 	$self->add_field_obj($hidden);
#     }
# }
  				       
    
		 

# =head2 set_action

#  Usage:        $form->set_action("/cgi-bin/myscript.pl")
#  Desc:         sets the action parameter in the form.
#  Ret:          nothing
#  Args:         a name of a script the form should call.
#  Side Effects:
#  Example:

# =cut

# sub set_action { 
#     my $self = shift;
#     $self->{action}=shift;
# }

# =head2 get_action

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub get_action { 
#     my $self = shift;
#     if (!exists($self->{action})) { $self->{action}=""; }
#     return $self->{action};
# }

# =head2 get_fields

#  Usage:
#  Desc:         
#  Ret:          returns all the fields of the form, in the
#                order they were added to the list (an in the 
#                order they are rendered with as_table().
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub get_fields { 
#     my $self = shift;
#     if (!exists($self->{fields})) { @{$self->{fields}}=(); }
#     return @{$self->{fields}};
# }

# =head2 get_form_start

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut


# sub get_form_start { 
#     my $self = shift;
#     return "";
# }

# =head2 get_form_end

#  Usage:
#  Desc:         gets the ending definition of the 
#                form.
#  Ret:          a string representing the end of the form.
#  Args:
#  Side Effects:
#  Example:

# =cut


# sub get_form_end { 
#     my $self = shift;
#     return "";
# }

# =head2 get_field_hash

#  Usage:
#  Desc:         Returns a hash with the field names as keys
#                and the representation of the fields as values.
#                For 'static' fields, usually the field contents
#                are given, and for 'editable' fields, an input
#                box, drop down or other appropriate form element
#                is defined.
               
#                Two special hash keys are defined:
#                FORM_START can be used to render the start of the
#                           form.
#                FORM_END   can be used to render the end of the form.
#  Ret:          a hash (see above)
#  Args:         none
#  Side Effects: none
#  Example:      

# =cut

# sub get_field_hash { 
#     my $self = shift;
#     my %hash = ();
#     foreach my $f ($self->get_fields()) { 
# 	$hash{$f->get_field_name()} = $f->render();
#     }
    
#     $hash{FORM_START}=$self->get_form_start();
#     $hash{FORM_END} = $self->get_form_end();
    
#     return %hash;
# }

# # get_hidden_fields and set_hidden_fields are deprecated.
# =head2 get_hidden_fields

#  Usage:        DEPRECATED.
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub get_hidden_fields {
#   my $self=shift;
#   return $self->{hidden_fields};

# }

# =head2 set_hidden_fields

#  Usage:        DEPRECATED.
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub set_hidden_fields {
#   my $self=shift;
#   $self->{hidden_fields}=shift;
# }



# =head2 as_table

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub as_table {
#     my $self = shift;
    
#     print qq { <table> };
#     foreach my $f ($self->get_fields()) { 
# 	print "<tr><td>".($f->get_name())."</td><td width=\"20\">&nbsp;</td><td>".($f->get_contents())."</td></tr>\n";
#     }
#     print qq { </table> };
# }




# =head2 store

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub store { 
# `

# }

# sub _store_static { 
#     my $self = shift;
#     print STDERR "Static Form: Nothing saved.\n";
# }

# sub _store_editable { 
#     my $self = shift;
    


# }

# =head2 get_insert_id

#  Usage:        my $id = $form->last_insert_id($myobject)
#  Desc:
#  Ret:          the last insert id for the object in question
#  Args:         an object that was supplied as part of a field
#                using the add_field or similar function
#  Side Effects:
#  Example:      can be used to obtain the id of the database entity
#                when the store function is expected to yield an
#                insert into the database.

# =cut

# sub get_insert_id {
#     my $self=shift;
#     my $object = shift;
#     my $object_type = ref($object);
#     if (!exists($self->{insert_id}) || !exists($self->{insert_id}->{object_type})) { 
	
# 	print STDERR "last insert id for object_type $object_type unknown!\n";
#     }
#     else { 
# 	return $self->{insert_id}{object_type};
#     }
# }
    
# =head2 set_insert_id

#  Usage:        $form->set_insert_id($myobject, $last_id);
#  Desc:         used internally to set the last insert id for the 
#                object "myobject"
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub set_insert_id {
#   my $self=shift;
#   my $object = shift;
#   my $object_type = ref($object);
#   $self->{insert_id}->{object_type}=shift;
# }




