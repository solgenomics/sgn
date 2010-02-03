package CXGN::Page::UserPrefs;
use strict;
use base qw/CXGN::Page::Session/;

=head1 NAME

 CXGN::Page::UserPrefs

=head1 Description

 A module for handling user preferences (setting and retrieving) using a long ( <= 4KB ) cookie string in the user table.  This module MUST be used BEFORE HTTP Headers are sent to the browser, cuz we got cookies to set, cuz.

 WARNING: unix epoch time comparison is used, so implementation of this code on a Macintosh server will require some changes!! [search for time()]

 This module has been re-organized to use CXGN::Page::Session as the base 

=head1 AUTHOR

 Chris Carpita <ccarpita@gmail.com>

=head1 Instance Methods

=cut

our @VALID_KEYS = qw/
	cdsSeqDisp
	cdsSpaceSwap
	genomicSeqDisp
	GOcollapse
	propertiesCollapse
	proteinInfoCollapse
	protSeqDisp
	searchHighlight
	sp_person_id
	TAIRannotationCollapse
	timestamp
	last_blast_db_file_base
/;

our $COOKIE_NAME = 'user_prefs';
our $DB_SCHEMA = 'sgn_people';
our $DB_TABLE = 'sp_person';
our $DB_COLUMN = 'user_prefs';
our $ID_COLUMN = 'sp_person_id';
our $ID = undef;


=head2 set_pref($name, $value)

	Usage: $handle->set_pref('skin', 'aqua'); # not a real setting ;)
	Sets the proper value in the preferences hash.  To actually update this in the database, call $handle->save();

=cut

sub set_pref {
	my $self = shift;
	my ($name, $value) = @_;
	$self->alter_setting($name, $value);
}

=head2 get_pref($name)
	
	Usage: $handle->get_pref('searchHidden');
	Returns the preference value.  We will use this one a lot ;)

=cut

sub get_pref {
	my $self = shift;
	my $name = shift;
	$self->get_setting($name);
}	

####
1;###
####
