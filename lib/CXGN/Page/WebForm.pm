package CXGN::Page::WebForm;
use strict;
use Carp;

use Digest::Crc32;
use Tie::Function;
use HTML::Entities;

use CXGN::Tools::List qw/distinct all/;

=head1 NAME

CXGN::Page::WebForm - a persistent HTML form

=head1 SYNOPSIS

  package MyWebForm;
  use base qw( CXGN::Page::WebForm );
  __PACKAGE__->template( <<EOHTML );
  Id:<input name="NAME_id"  value="VALUE_id" />
  Name:<input name="NAME_name"  value="VALUE_name" />
  EOHTML

  package main;

  my $form = MyWebForm->new;
  my $page = CXGN::Page->new('Some page','Rob Buels');
  $form->from_request( $page->get_all_encoded_arguments );

  print "you submitted the data ",
        '('.join(',',$form->data('id','name','something').")\n";
  #remember, data() returns a list of (val,val,val,...), not a scalar

  #prints whatever the value of w98e_id was in the POST
  #we got, where w98e is some arbitrary piece of
  #garbage this class uses to keep its parameters
  #to itself

  $form->set_data( id => 42, name => 'rob' );

  print '<form action="" method="post">',"\n",
         $form->to_html,
         '</form>'; #now print the auto-filled-in form

  #will print something like

  <form action="" method="post">
  Id:<input name="w98e_id" value="42" />
  Name:<input name="w98e_name" value="rob" />
  </form>

  #where w98e is an automatically generated identifier
  #that signifies that the values belong to the MyWebForm
  #package.

=head1 SUBCLASSES

  L<CXGN::Search::WWWQuery>

=head1 DESCRIPTION

This is an object representing a web form, which encodes
and decodes its parameter names such that it always knows
which parameters belong to it.  Use this as a base class
for making HTML forms that fill themselves in based on values
supplied from somewhere else.

=head1 PRIMARY FUNCTIONS

These are the primary functions provided by this class.

=cut

use base qw/ Class::Data::Inheritable /;

use Class::MethodMaker
  [ new  => [-init => 'new'],
    hash => ['_data'],
  ];

=head2 new

  Usage: my $form = MyWebForm->new;
  Desc : make a new form object
  Ret  : a new object
  Args : (optional) initial data, same format as set_data() below
  Side Effects: calls the init() method in this class to set up
                this object

=cut

sub init { #init() is called by Class::MethodMaker's new() method
  my $self = shift;
  if(@_) {
    $self->set_data(@_);
  }
}

=head2 template

  Note: this is a CLASS METHOD.

  Usage: MyForm->template(<<EOHTML);
    ID Number:<input type="text" name="NAME_id" value="VALUE_id" /><br />
    Name:<input type="text" name="NAME_name" value="VALUE_name" />
  EOHTML
  Desc : set the html template to use for this web form
  Ret  : the template you set
  Args : (optional) new template string to set for this class
  Side Effects: sets a piece of class data holding this template

=cut

#make a _template() class method to hold the data
__PACKAGE__->mk_classdata( '_template' );

#wrap the _template classdata in some error checking
sub template {
  my $class = shift;

  $_[0] && $_[0] =~ /<form\s/
    and croak "Do not include <form> elements in your to_html template";

  $class->_template(@_);
}

=head2 to_html

  Usage: print $myform->to_html
  Desc : fills in this class's HTML form template (set with template()
         above) with the properly uniqified names, and the values we have
         in this object, if any (e.g. from a previous from_request)

         If no template is defined, it makes a default one with whatever
         parameters and values are set in it, if any.
  Ret  : string of html
  Args : none
  Side Effects: none

  Subclass implementors might want to override this to generate
  their HTML in a more advanced way.

=cut

sub to_html {
  my ($self) = @_;
  @_ > 1 and croak "to_html takes no arguments"; #check args

  #get our class's template, or make a crappy default one
  #if one wasn't given
  my $template = (ref $self)->template
    || join("<br />\n",
	    map { my ($val) = $self->_data_index($_);
		  qq|<label for="NAME_$_">$_:</label>|
		    .qq|<input name="VALUE_$_" value="$val" />|
		} $self->_data_keys
	   )
    || __PACKAGE__.': no template defined, and no data to use for generating default template, so this is an empty template.  Maybe you should provide one.';

  #make a tied hash for uniqifying names
  tie my %uniq, 'Tie::Function', sub { $self->uniqify_name(@_) };
  #make a tied hash for looking up values in this object
  tie my %value, 'Tie::Function', sub { my $v = ($self->_data_index(@_))[0];
					 defined($v) ? encode_entities($v) : ''
				       };
  #plug the names and values into the template
  $template =~ s/(?<=\W)NAME_(\w+)(?=\W)/$uniq{$1}/g;
  $template =~ s/(?<=\W)VALUE_(\w+)(?=\W)/$value{$1}/g;

  #and return it
  return $template;
}

=head2 from_request

  Usage: $from->from_request( { bleh => 1, isa_monkey => 'rob'} );
  Desc: deserialize this query object from a an Apache request object
  Args: ref to a hash of parameters (like that returned from
        CXGN::Page->get_arguments() )  you can make your own with
        something like:

        $myform->from_request( CGI->new->Vars );

  Ret : not specified
  Side Effects: none

=cut

sub from_request {
  my ($self,$mungedparams) = @_;
  my %params = $self->_pick_out_my_params($mungedparams);
  $self->_data(%params);
}

=head2 data

  Usage: print "got form data (id,name)= ("
                .join(',',$form->data(qw/id name/))
                .")";
  Desc : get the values of one or more pieces of form data
  Ret  : list of corresponding values for the names you passed in
  Args : list of names of the data you want
  Side Effects: none

  NOTE: both the input and the output of this function are _lists_

=cut

#the secret internal writable accessor is _data, generated
#by Class::MethodMaker above
sub data {
  shift->_data_index(@_);
}

=head2 data_multiple

 Usage: my @stuff = $form->data_multiple('foolist');
 Desc : When a parameter may have multiple values (such as a
        multiple-select box) this returns the many values as a
        list. Supply only one argument, the name of the parameter.
 Ret  : List of values for the named parameter
 Args : The name of the parameter
 Side Effects: none

=cut

sub data_multiple {

  my ($self, $param) = @_;
  my ($thingy) = $self->data($param);

  return (split /\0/, $thingy);

}

=head2 set_data

  Usage: $form->set_data( id => 42, name => 'rob')
  Desc : set data in this form
  Ret  : nothing meaningful
  Args : hash-style list of values to set, like
         (id => 42, name => 'rob')
  Side Effects: sets object data

=cut

sub set_data {
  shift->_data_set(@_);
}

=head2 same_data_as

  Usage: print 'yep' if $form_obj_1->same_data_as( $form_obj_2 );
  Desc : object method, returns true if the given form object
         contains the same data as this one.
  Args : a WebForm object
  Ret  : true if the objects are the same, false otherwise

=cut

sub same_data_as {
  my ($self,$other) = @_;

  # true of course if they are the same object
  return 1 if $self == $other;

  # check if they have the same number of data items set
  return unless $self->_data_count == $other->_data_count;

  # check if they have the same data item names set
  my @keys = distinct $self->_data_keys, $other->_data_keys;

  return unless $self->_data_count == scalar @keys;

  # now we know they have the same data item names,
  # check that they have the same data values
  return all map {
    $self->_data_index($_) eq $self->_data_index($_)
  } @keys;
}


=head1 HELPER FUNCTIONS

These functions may be useful for developers who subclass this.

=head2 _pick_out_my_params

  Desc: given a hash of names and values from a GET or POST request, pick
        out the variables in the request that belong to us, that is,
        that were generated by an object of the same class as this one.
  Args: reference to a hash containing name => value pairs
  Ret : hash of parameters that, based on the encoding of their names,
        belong to this object, as:
          ( unmunged name => value,
            unmunged name => value,
          )
  Side Effects: none

=cut

sub _pick_out_my_params {

  my ($this,$mungedparams) = @_;

  ref $mungedparams eq 'HASH'
    or croak 'Argument to from_request must be a hash ref (got a '.(ref $mungedparams).')';

  my %unmunged; #params that belong to us, unmunged

  #find all the params that belong to us
  while(my ($mungedname,$value) = each %$mungedparams) {
   if( my $name = $this->de_uniqify_name($mungedname) ) {
      $unmunged{$name} = $value;
    }
  }

  return %unmunged;
}

=head2 uniqify_name

  Desc: method to munge the name of a form field such that
        it will almost certainly not collide with other things in
        the same GET or POST request
  Args: unmunged name
  Ret : munged name

=cut

sub uniqify_name {
  shift->_prefix.shift
}

#generate this class's prefix used for uniqifying parameter names
our %_params_prefix_cache;
our $crc = Digest::Crc32->new;
sub _prefix {
  my ($this) = @_;
  $this = ref $this if ref $this;
  $_params_prefix_cache{$this} ||= sprintf('w%x_',$crc->strcrc32($this) & 0xfff);
}

=head2 de_uniqify_name

  Desc: method to convert form field names made with uniqify_name above
        back into the name you actually want to use
  Args: munged name
  Ret : unmunged name, or undef if the name passed was not munged in the correct way

  Used in _pick_out_my_params().

=cut

sub de_uniqify_name {
  my ($this,$html)  = @_;
  my $prefix = $this->_prefix();
  my ($ret) = $html =~ /^$prefix(.+)/;
  $ret;
}

=head2 make_pname

  Desc: convenience method, makes a hash in the calling package called
        %pname that you can use instead of uniqify_name (see example)
  Args: none
  Ret : nothing
  Example:
    __PACKAGE__->make_pname;
    our %pname;
    sub to_html {
      return <<EOH;
         <form><input name="$pname{foo}" value="" /></form>
      EOH
    }

=cut

sub make_pname {
  my ($class) = @_;
  $class = ref $class if ref $class;
  no strict;
  tie %{$class.'::pname'}, 'Tie::Function' => sub { $class->uniqify_name(@_) };
}

=head1 AUTHOR(S)

    Robert Buels

=cut

###
1;#do not remove
###
