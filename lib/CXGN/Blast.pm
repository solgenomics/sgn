
package CXGN::Blast;

=head1 NAME

CXGN::Blast - a BLAST database that we keep in stock and updated.

=head1 SYNOPSIS

  ### SIMPLE MECHANICS

  This object has been derived from CXGN::BlastDB (in cxgn-corelibs) and
  refactored to work with DBIx::Class (instead of Class::DBI) and Moose.

  The constructor now requires some additional arguments:

  my $db = CXGN::Blast->new( { blast_db_id => $x,
                                 sgn_schema => $s,
                                 dbpath => $p,
                               });

  (this standard constructor now replaces the previous from_id() constructor).

  my @dbs = CXGN::Blast->retrieve_all(); #get all blastDB objects

  #change the title of a blast db in memory
  $dbs[0]->title( 'Sequences from Tomatoes' );

  Updating the object in the database is not supported right now.

  #do a blast against this database
  CXGN::Tools::Run->run( 'blastall',
                         -m => 8,
                         -i => 'myseqs.seq',
                         -d => $dbs[0]->full_file_basename,
                         -p => 'blastn',
                         -e => '1e-10',
                         -o => 'myreport.m8.blast',
                       );

  ### NIFTY THINGS

  #does it need to be updated?
  print "univec needs updating\n" if $uv->needs_update;

  #list the files that are part of our univec DB
  my @uv_files = $uv->list_files;
  #returns ( '/data/shared/blast/databases/screening/vector/UniVec.nin',
  #	     '/data/shared/blast/databases/screening/vector/UniVec.nhr',
  #	     '/data/shared/blast/databases/screening/vector/UniVec.nsq',
  #	   )

  #how many sequences does it have in it?
  print "this copy of univec has ".$uv->sequence_count." sequences in it\n";

  #we've got an updated copy of univec here, let's format it and install it
  #in place
  $uv->format_from_file('new_univec.seq');

  #i'll plop another formatted copy of univec in my home dir too
  $bdb->dbpath('/home/rob/blast');
  $uv->format_from_file('new_univec.seq');
  #that will have done a mkpath -p /home/rob/blast/screening/vector,
  #then it will have put the Univec.nin, nhr, and nsq files there.

=head1 DESCRIPTION

This is a handle on a BLAST database we manage.  Each of
these objects corresponds to a row in the sgn.blast_db table and
a set of files in the filesystem. at a place specified by the
dbpath() accessor (see dbpath docs below).  This path defaults to
the value of the 'blast_db_path' configuration variable (see L<CXGN::Config>).

=head1 METHODS

=cut

use Moose;

use strict;
use Carp;
use File::Spec;
use File::Basename;
use File::Copy;
use File::Path;
use POSIX;

use List::MoreUtils qw/ uniq /;

use Memoize;

use CXGN::Tools::List qw/any min all max/;
use CXGN::Tools::Run;

use Bio::BLAST2::Database;

has 'sgn_schema' => ( isa => 'SGN::Schema',
		      is => 'ro',
		      required => 1,
    );

has 'blast_db_id' => ( isa => 'Int',
		       is => 'ro',
		       default => 0,
    );

has 'dbpath' => ( isa => 'Maybe[Str]',
		  is => 'rw',
		  required => 1,
   );

has 'file_base' => ( isa => 'Maybe[Str]',
		     is => 'rw',
    );

has 'title' => ( isa => 'Str',
		 is => 'rw',
		 default => '',
    );

has 'type' => ( isa => 'Maybe[Str]',
		is => 'rw',
    );

has 'source_url' => ( isa => 'Maybe[Str]',
		      is => 'rw',
		      default => '',
    );

has 'lookup_url' => (isa => 'Maybe[Str]',
		     is => 'rw',
		     default => '',
    );

has 'info_url' => ( isa => 'Maybe[Str]',
		    is => 'rw',
    );

has 'update_freq' => ( isa => 'Maybe[Str]',
		       is => 'rw',
    );

has 'index_seqs' => ( isa => 'Bool',
		      is => 'rw',
    );

has 'web_interface_visible' => ( isa => 'Bool',
				 is => 'rw',
    );

has 'description' => (isa => 'Maybe[Str]',
		      is => 'rw',
    );

has 'jbrowse_src' => (isa => 'Maybe[Str]',
		      is => 'rw',
    );




###our @column_names =
  # ('blast_db_id',  #-database serial number
  #  'file_base',    #-basename of the database files, with a path prepended,
  #                  # e.g. 'genbank/nr'
  #  'title',        #-title of the database, e.g. 'NCBI Non-redundant proteins'
  #  'type',         #-type, either 'protein' or 'nucleotide'
  #  'source_url',   #-the URL new copies of this database can be fetched from
  #  'lookup_url',   #-printf-style format string that can be used to generate
  #                  # a URL where a user can get more info on a sequence in
  #                  # this blast db
  #  'info_url',     #-URL that gives information about the contents of this DB
  #  'update_freq',  #-frequency of updating this blast database
  #  'index_seqs',   #- corresponds to formatdb's -o option.  Set true if formatdb
  #                  #  should be given a '-o T'.  This is used if you later want to
  #                  #  fetch specific sequences out of this blast db
  #  'web_interface_visible', #whether the blast web interface should display this DB
  #  'blast_db_group_id', #ID of the blast DB group this db belondgs to,
  #                       #if any.  used for displaying them in the web
  #                       #interface
  #  'description',  # text description of the database, display on the database details page
 ### );

sub BUILD {
    my $self = shift;

    if ($self->blast_db_id) {
	my $row = $self->sgn_schema()->resultset("BlastDb")->find( { blast_db_id => $self->blast_db_id() } );
	if (!$row) { die "The blast_db_id with the id ".$self->blast_db_id()." does not exist in this database\n"; }
	$self->file_base($row->file_base());
	$self->title($row->title());
	$self->type($row->type());
	$self->source_url($row->source_url());
	$self->lookup_url($row->lookup_url());
	$self->info_url($row->info_url());
	$self->update_freq($row->update_freq());
	$self->index_seqs($row->index_seqs());
	$self->web_interface_visible($row->web_interface_visible());
	$self->description($row->description());
	$self->jbrowse_src($row->jbrowse_src());
    }
    else {
	print STDERR "No blast_db_id provided. Creating empty object...\n";
    }
}

# class function

sub retrieve_all {
    my $class = shift;
    my $sgn_schema = shift;
    my $dbpath = shift;

    my @dbs = $class->search($sgn_schema, $dbpath);

    return @dbs;
}

sub search {
    my $class = shift;
    my $sgn_schema = shift;
    my $dbpath = shift;
    my %search = @_;

    my $rs = $sgn_schema->resultset("BlastDb")->search( { %search } );

    my @dbs = ();

    while (my $db = $rs->next()) {
	my $bdbo = CXGN::Blast->new( sgn_schema => $sgn_schema, dbpath => $dbpath, blast_db_id => $db->blast_db_id() );
	push @dbs, $bdbo;
    }
    return @dbs;
}

# =head2 from_id

## Note: replaced by standard moose constructor and blast_db_id arg

#   Usage: my $bdb = CXGN::BlastDB->from_id(12);
#   Desc : retrieve a BlastDB object using its ID number
#   Ret  : a BlastDB object for that id number, or undef if none found
#   Args : the id number of the object to retrieve
#   Side Effects: accesses the database

# =cut

# sub from_id {
#     shift->retrieve(@_);
#    }

#Only document title and type for external users of this module,
#some nicer wrappers will be provided for using the other information

=head2 title

  Usage: $db->title
  Desc : get/set the title of this blast DB object
  Ret  : string containing the title, e.g. 'NCBI Non-redundant proteins'
  Args : optional new value for the title

  Note: must run $db->update for changes to be written to the db, unless you've
  set $db->autoupdate.

=head2 type

  Usage: $db->type
  Desc : get the type of this blast db, whether it holds
         proteins or nucleotides
  Ret  : 'protein' or 'nucleotide'
  Args : optional new value for the type, either 'protein' or 'nucleotide'

  Note: must run $db->update for changes to be written to the db, unless you've
  set $db->autoupdate.

=head2 file_base

  Usage: $db->file_base;
  Desc : get/set the basename and path relative to 'blast_db_path' config var
  Ret  : the path and basename, e.g. 'genbank/nr' or 'screening/organelle/ATH_mitochondria'
  Args : (optional) new string containing subpath and basename
  Side Effects: none

  Note: must run $db->update for changes to be written to the db, unless you've
  set $db->autoupdate.

=cut

=head2 genomic_libraries_annotated

  Desc: get the L<CXGN::Genomic::Library> objects that are slated as using this
        blast database for annotation
  Args: none
  Ret : array of L<CXGN::Genomic::Library> objects

=cut

=head2 file_modtime

  Desc: get the earliest unix modification time of the database files
  Args: none
  Ret : unix modification time of the database files, or nothing if does not exist
  Side Effects:
  Example:

=cut

sub file_modtime {
    my $self = shift;
    return unless $self->_fileset;
    return $self->_fileset->file_modtime;
}

=head2 format_time

  Usage: my $time = $db->format_time;
  Desc : get the format time of these db files
  Ret  : the value time() would have returned when
         this database was last formatted, or undef
         if that could not be determined (like if the
         files aren't there)
  Args : none
  Side Effects: runs 'fastacmd' to extract the formatting
                time from the database files

  NOTE:  This function assumes that the computer that
         last formatted this database had the same time zone
         set as the computer we are running on.

=cut

sub format_time {
    my ($self) = @_;
    return unless $self->_fileset;
    return $self->_fileset->format_time;
}

=head2 full_file_basename

  Desc:
  Args: none
  Ret : full path to the blast database file basename,
  Side Effects: none
  Example:

     my $basename = $db->full_file_basename;
     #returns '/data/shared/blast/databases/genbank/nr'

=cut

sub full_file_basename {
    my $self = shift;

    return scalar File::Spec->catfile( $self->dbpath,
				       $self->file_base,
	);

}

=head2 list_files

  Usage: my @files = $db->list_files;
  Desc : get the list of files that belong to this blast database
  Ret  : list of full paths to all files belonging to this blast database,
  Args : none
  Side Effects: looks in the filesystem

=cut

sub list_files {
    my $self = shift;
    return unless $self->_fileset;
    $self->_fileset->list_files();
}

=head2 files_are_complete

  Usage: print "complete!" if $db->files_are_complete;
  Desc : tell whether this blast db has a complete set of files on disk
  Ret  : true if the set of files on disk looks complete,
         false if not
  Args : none
  Side Effects: lists files on disk

=cut

sub files_are_complete {
    my ($self) = @_;
    return unless $self->_fileset;
    return $self->_fileset->files_are_complete;
}

=head2 is_split

  Usage: print "that thing is split, yo" if $db->is_split;
  Desc : determine whether this database is in multiple parts
  Ret  : true if this database has been split into multiple
         files by formatdb (e.g. nr.00.pin, nr.01.pin, etc.)
  Args : none
  Side Effects: looks in filesystem

=cut

sub is_split {
    my ($self) = @_;
    return unless $self->_fileset;
    return $self->_fileset->is_split;
}

=head2 is_indexed

  Usage: $bdb->is_indexed
  Desc : checks whether this blast db is indexed on disk to support
         individual sequence retrieval.  note that this is different
         from index_seqs(), which is the flag of whether this db
         _should_ be indexed.
  Args : none
  Ret  : false if not on disk or not indexed, true if indexed

=cut

sub is_indexed {
    my ( $self ) = @_;
    return unless $self->_fileset;
    return $self->_fileset->files_are_complete && $self->_fileset->indexed_seqs;
}


=head2 sequences_count

  Desc: get the number of sequences in this blast database
  Args: none
  Ret : number of distinct sequences in this blast database, or undef
        if it could not be determined due to some error or other
  Side Effects: runs 'fastacmd' to get stats on the blast database file

=cut

sub sequences_count {
    my $self = shift;
    return unless $self->_fileset;
    return $self->_fileset->sequences_count;
}

=head2 is_contaminant_for

  This method doesn't work yet.

  Usage: my $is_contam = $bdb->is_contaminant_for($lib);
  Desc : return whether this BlastDB contains sequences
         from something that would be considered a contaminant
         in the given CXGN::Genomic::Library
  Ret  : 1 or 0
  Args : a CXGN::Genomic::Library object

=cut

#__PACKAGE__->has_many( _lib_annots => 'CXGN::Genomic::LibraryAnnotationDB' );
sub is_contaminant_for {
    my ($this,$lib) = @_;

    #return true if any arguments are true
    return any( map { $_->is_contaminant && $_->library_id == $lib } $this->_lib_annots);
}

=head2 needs_update

  Usage: print "you should update ".$db->title if $db->needs_update;
  Desc : check whether this blast DB needs to be updated
  Ret  : true if this database's files need an update or are missing,
         false otherwise
  Args : none
  Side Effects: runs format_time(), which runs `fastacmd`

=cut

sub needs_update {
    my ($self) = @_;

    #it of course needs an update if it is not complete
    return 1 unless $self->files_are_complete;

    my $modtime = $self->format_time();

    #if no modtime, files must not even be there
    return 1 unless $modtime;

    #manually updated DBs never _need_ updates if their
    #files are there
    return 0 if $self->update_freq eq 'manual';

    #also need update if it is set to be indexed but is not indexed
    return 1 if $self->index_seqs && ! $self->is_indexed;

    #figure out the maximum number of seconds we'll tolerate
    #the files being out of date
    my $max_time_offset = 60 * 60 * 24 * do { #figure out number of days
	if(    $self->update_freq eq 'daily'   ) {   1   }
	elsif( $self->update_freq eq 'weekly'  ) {   7   }
	elsif( $self->update_freq eq 'monthly' ) {   31  }
	else {
	    confess "invalid update_freq ".$self->update_freq;
	}
    };

    #subtract from modtime and make a decision
    return time-$modtime > $max_time_offset ? 1 : 0;
}


=head2 check_format_permissions

  Usage: $bdb->check_format_from_file() or die "cannot format!\n";
  Desc : check directory existence and file permissions to see if a
         format_from_file() is likely to succeed.  This is useful,
         for example, when you have a script that downloads some
         remote database and you'd like to check first whether
         we even have permissions to format before you take the
         time to download something.
  Args : none
  Ret  : nothing if everything looks good,
         otherwise a string error message summarizing the reason
         for failure
  Side Effects: reads from filesystem, may stat some files

=cut

sub check_format_permissions {
    my ($self,$ffbn) = @_;
    croak "ffbn arg is no longer supported, maybe you should just use a new Bio::BLAST2::Database object" if $ffbn;
    return unless $self->_fileset('write');
    return $self->_fileset('write')->check_format_permissions;
}

=head2 format_from_file

  Usage: $db->format_from_file('mysequences.seq');
  Desc : format this blast database from the given source file,
         into its proper place on disk, overwriting the files already
         present
  Ret  : nothing meaningful
  Args : filename containing sequences,
  Side Effects: runs 'formatdb' to format the given sequences,
                dies on failure

=cut

sub format_from_file {
    my ($self,$seqfile,$ffbn) = @_;
    $ffbn and croak "ffbn arg no longer supported.  maybe you should make a new Bio::BLAST2::Database object";

    $self->_fileset('write')
	->format_from_file( seqfile => $seqfile, indexed_seqs => $self->index_seqs, title => $self->title );
}

=head2 to_fasta

  Usage: my $fasta_fh = $bdb->to_fasta;
  Desc : get the contents of this blast database in FASTA format
  Ret  : an IO::Pipe filehandle, or nothing if it could not be opened
  Args : none
  Side Effects: runs 'fastacmd' in a forked process, cleaning up its output,
                and passing it to you

=cut

sub to_fasta {
    my ($self) = @_;
    return unless $self->_fileset;
    return $self->_fileset->to_fasta;
}

=head2 get_sequence

  Usage: my $seq = $bdb->get_sequence('LE_HBa0001A02');
  Desc : get a particular sequence from this db
  Args : sequence name to retrieve
  Ret  : Bio::PrimarySeqI object, or nothing if not found or
         if db does not exist
  Side Effects: dies on error, like if this db is not indexed

=cut

sub get_sequence {
    my ($self, $seqname) = @_;
    return unless $self->_fileset;
    return $self->_fileset->get_sequence($seqname);
}

=head2 dbpath

  Usage: $bdb->dbpath('/data/cluster/blast/databases');
  Desc : object method to get/set the location where all blast database
         files are expected to be found.  Defaults to the value of the
         CXGN configuration variable 'blast_db_path'.
  Ret  : the current base path
  Args : (optional) new base path
  Side Effects: gets/sets a piece of CLASS-WIDE data

=cut

#mk_classdata is from Class::Data::Inheritable.  good little module,
#you should look at it
#__PACKAGE__->mk_classdata( dbpath => CXGN::BlastDB::Config->load->{'blast_db_path'} );

=head2 identifier_url

  Usage: my $url = $db->identifier_url('some ident from this bdb');
  Desc : get a URL to look up more information on this identifier.
         first tries to make a URL using the lookup_url column in the
         sgn.blast_db table, then tries to use identifier_url() from
         L<CXGN::Tools::Identifiers>
  Args : the identifier to lookup, assumed
         to be from this blast db
  Ret : a URL, or undef if none could be found
  Side Effects: Example:

=cut

sub identifier_url {
    my ($self,$ident) = @_;
    $ident or croak 'must pass an identifier to link';

    return $self->lookup_url
	? sprintf($self->lookup_url,$ident)
	: do { require CXGN::Tools::Identifiers; CXGN::Tools::Identifiers::identifier_url($ident) };
}

# accessor that holds our encapsulated Bio::BLAST2::Database
memoize '_fileset',
    NORMALIZER => sub { #< need to take the full_file_basename (really the dbpath) into account for the memoization
	my $s = shift; join ',',$s,@_,$s->full_file_basename
};

sub _fileset {
my ($self,$write) = @_;
my $ffbn = $self->full_file_basename;
return Bio::BLAST2::Database->open( full_file_basename => $ffbn,
				   type => $self->type,
				   ($write ? ( write => 1,
					       create_dirs => 1,
				    )
				    :        (),
				   )
    );
}

=head1 MAINTAINER

  Original maintainer: Robert Buels
  Refactored by Lukas Nov 2016.

=head1 AUTHOR

Robert Buels, E<lt>rmb32@cornell.eduE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# package CXGN::BlastDB::Group;
# use strict;
# use English;
# use Carp;

# use base qw/CXGN::CDBI::Class::DBI Class::Data::Inheritable/;
# __PACKAGE__->table(__PACKAGE__->qualify_schema('sgn') . '.blast_db_group');

# #define our database columns with class::dbi
# our @primary_key_names = ('blast_db_group_id');

# our @column_names =
#   ('blast_db_group_id',
#    'name',
#    'ordinal'
#   );
# __PACKAGE__->columns(  Primary   => @primary_key_names, );
# __PACKAGE__->columns(  All       => @column_names,      );
# __PACKAGE__->columns(  Essential => @column_names,      );
# __PACKAGE__->sequence( __PACKAGE__->base_schema('sgn'). '.blast_db_group_blast_db_group_id_seq' );

# __PACKAGE__->has_many( blast_dbs => 'CXGN::BlastDB', {order_by => 'title'} );


####
1; # do not remove
####
