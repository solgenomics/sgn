

use CXGN::Page::Form::Checkbox;
use CXGN::Page::Form::EditableMultiSelect;
use CXGN::Page::Form::EditableTextArea;
use CXGN::Page::Form::MultiSelect;
use CXGN::Page::Form::Static;
use CXGN::Page::Form::ConfirmStore;
use CXGN::Page::Form::EditablePasswordField;
use CXGN::Page::Form::ElementI;
use CXGN::Page::Form::PasswordField;
use CXGN::Page::Form::TextArea;
use CXGN::Page::Form::EditableCheckbox;
use CXGN::Page::Form::Editable;
use CXGN::Page::Form::Field;
use CXGN::Page::Form::RadioList;
use CXGN::Page::Form::EditableField;
use CXGN::Page::Form::EditableRadioList;
use CXGN::Page::Form::Hidden;
use CXGN::Page::Form::Select;
use CXGN::Page::Form::EditableHidden;
use CXGN::Page::Form::EditableSelect;
use CXGN::Page::Form::Label;             
use CXGN::Page::Form::SimpleFormPage;


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
