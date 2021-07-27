package Bio::BLAST2::Database;
BEGIN {
  $Bio::BLAST2::Database::AUTHORITY = 'cpan:RBUELS';
}
BEGIN {
  $Bio::BLAST2::Database::VERSION = '0.4';
}
# ABSTRACT: work with formatted BLAST databases

use strict;
use warnings;

use POSIX;

use IO::Pipe;
use IPC::Cmd qw/ can_run /;

use Carp;
use Memoize;

use File::Basename;
use File::Copy;
use File::Path;
use File::Slurp qw/slurp/;
use File::Spec::Functions qw/ splitdir catdir devnull /;

use IPC::System::Simple 'systemx';

use List::Util qw/ min max /;
use List::MoreUtils qw/ all any /;

use Bio::BLAST2::Database::Seq;

use namespace::clean;


use base qw/ Class::Accessor::Fast /;



sub new { croak "use open(), not new()" }

sub open {
    my $class = shift;
    #validate the args
    @_ % 2 and croak 'invalid args to open()';
    my %args = @_;
    my %valid_keys = map {$_ => 1} qw( full_file_basename type write create_dirs );
    $valid_keys{$_} or croak "invalid param '$_' passed to open()" for keys %args;

    my $self = $class->SUPER::new(\%args);

    $self->full_file_basename or croak 'must provide a full_file_basename';

    unless( $self->type ) {
        $self->type( $self->_guess_type )
            or croak 'type not provided, and could not guess it';
    }

    if( $self->write ) {
        $self->create_dirs || -d dirname( $self->full_file_basename )
            or croak 'either directory must exist, or create_dirs must be set true';

        my $perm_error = $self->check_format_permissions;
        croak $perm_error if $perm_error;
    }

    # set some of our attrs from the existing files
    $self->_read_blastdbcmd_info;

    if( $self->write ) {
        return $self;
    } else {
        # open succeeds if all the files are there
        return $self if $self->files_are_complete;

        #carp "cannot open for reading, not a complete set of files:\n",
        #    map "  - $_\n", $self->list_files;
        return;
    }
}


__PACKAGE__->mk_accessors('full_file_basename');


__PACKAGE__->mk_accessors('create_dirs');


__PACKAGE__->mk_accessors('write');


__PACKAGE__->mk_accessors('title');


sub indexed_seqs { #< indexed_seqs is read-only externally
  my ($self,@args) = @_;
  croak 'indexed_seqs() is read-only' if @args;
  shift->_indexed_seqs;
}
__PACKAGE__->mk_accessors('_indexed_seqs');


sub type {
    my $self = shift;

    if( @_ ) {
        my $type = shift;
        !defined $type || $type eq 'nucleotide' || $type eq 'protein'
            or croak "invalid type '$type'";
        $self->{type} = $type;
    }

    return $self->{type};
}



sub to_fasta {
  my ($self) = @_;

  $self->_check_external_tools;

  my $pipe = IO::Pipe->new;
  if(my $pid = fork) {
    $pipe->reader;
    return $pipe;
  } elsif(defined $pid) {
    $pipe->writer;

    # #figure out the right -D flag to use, depending on blastdbcmd version
    #  my $d = do {
    #   my ($version) = `blastdbcmd -help` =~ /\s+blastdbcmd\s+([\d\.]+)/;
    #   if( _ver_cmp($version,'2.2.14') >= 0) {
    # 	'1'
    #   }
    #   else {
    # 	'T'
    #   }
    # };

    my $cmd = "blastdbcmd -db ".$self->full_file_basename." -entry 'all' |";
    CORE::open my $fh, "$cmd"
      or die "Could not run $cmd: $!\n";
    while (<$fh>) {
      if(/^>/) {
	#remove renamed idents for genbank-accessioned databases
	s/^>gnl\|\S+\s+/>/;
	#remove renamed idents for local-accessioned databases
	s/^>lcl\|/>/;
      }
      print $pipe $_;
    }
    close $pipe;
    POSIX::_exit(0);
  } else {
    die "could not fork: $!";
  }
}
sub _ver_cmp { #compares two version numbers like '2.2.10' and '2.2.14'
    my ($v1,$v2) = @_;
    my @v1 = split /\./,$v1;
    my @v2 = split /\./,$v2;
    for(my $i=0;$i<@v2||$i<@v1;$i++) {
        my $m1 = $v1[$i] || 0;
        my $m2 = $v2[$i] || 0;
        my $cmp = $m1 <=> $m2;
        return $cmp if $cmp;
	}
    return 0;
}

memoize('_check_external_tools');
sub _check_external_tools {

  my @missing;
  for my $tool ( qw/ blastdbcmd makeblastdb / ) {
      unless( can_run( $tool ) ) {
          push @missing, "External tool `$tool` not found in path.  Please install it.\n";
      }
  }

  croak @missing, "Please install missing tools before using ".__PACKAGE__.".\n"
    if @missing;

  return;
}


sub format_from_file {
  my ($self,%args) = @_;

  #validate arg keys
  my %valid_keys = map {$_ => 1} qw/seqfile title indexed_seqs/;
  $valid_keys{$_} or croak "invalid arg '$_'" foreach keys %args;

  my $seqfile    = $args{seqfile}
      or croak 'must provide seqfile';
  my $title      = $args{title};

  $self->_check_external_tools;

  #check whether the file looks like it's a fasta file
  CORE::open my $seqfh, '<', $seqfile
    or croak "Could not open '$seqfile' for reading: $!";
  while(<$seqfh>) {
    next unless /\S/; #go to first non-whitespace line
    croak "$seqfile does not seem to be a valid FASTA file (got line: $_)"
      unless /^\s*>\s*\S+/;
    last;
  }
  close $seqfh;

  unless( $self->write ) {
      if( my @files = $self->list_files ) {
          croak "cannot format from file, files are in the way:\n",map "  - $_\n",$self->list_files;
      }
  }

  #now run formatdb, formatting into files with a -blast-db-new
  #appended to the filebase, so the old databases are still available
  #while the format is running
  my $ffbn = $self->full_file_basename;
  my $new_ffbn = "$ffbn-blast-db-new";
  my (undef,$ffbn_subdir,undef) = fileparse($ffbn);
  #make sure the destination directories exist.  Create them if not.
  -d $ffbn_subdir or $self->create_dirs && mkpath([$ffbn_subdir])
    or croak "Could not make path '$ffbn_subdir': $!\n";
  unless( -d $ffbn_subdir ) {
      croak   $self->create_dirs ? "Could not create dir '$ffbn_subdir'"
            :                      "Directory '$ffbn_subdir' does not exist, and create_dirs not set\n";
  }
  -w $ffbn_subdir or croak "Directory '$ffbn_subdir' is not writable\n";

  systemx( 'formatdb',
           -i => $seqfile,
           -n => $new_ffbn,
           ($title ? (-t => $title) : ()),
           -l => devnull(),
           -o => $args{indexed_seqs}      ? 'T' : 'F',
           -p => $self->type eq 'protein' ? 'T' : 'F',
         );

  #now if it made an alias file, fix it up to remove the -blast-db-new
  #and the absolute paths, so that when we move it into place, it works
  if( my $aliasfile = do {
          my %exts = ( protein => '.pal', nucleotide => '.nal');
          my $n = $new_ffbn.$exts{$self->type};
          (-f $n) ? $n : undef;
      }
     ) {
    my $aliases = slurp($aliasfile);
    $aliases =~ s/-blast-db-new//g; #remove the new extension
    $aliases =~ s/$ffbn_subdir\/*//g; #remove absolute paths
    CORE::open my $a_fh, '>', $aliasfile or confess "Could not open $aliasfile for writing";
    print $a_fh $aliases;
    #closing not necessary for indirect filehandles in lexical variables
  }

  #list of files we will be replacing
  my @oldfiles = _list_files($ffbn,$self->type);

  #move the newly formatted files (almost) seamlessly into place
  foreach my $newfile ( sort (_list_files($new_ffbn,$self->type)) ) {
    my $dest = $newfile;
    $dest =~ s/-blast-db-new\./\./;

    #move it into the right place
    move( $newfile => $dest );

    #remove this file from the old files array if it's there,
    #since it has just been overwritten
    @oldfiles = grep { $_ ne $dest } @oldfiles;
  }

  #delete any old files that were not overwritten
  if(@oldfiles) {
    unlink @oldfiles;
    carp "WARNING: these files for database ".$self->full_file_basename." are no longer used and have been removed:\n",map {"-$_\n"} @oldfiles;
  }


  #and now reread our data from the new database
  $self->_read_blastdbcmd_info;
}


sub file_modtime {
  my $this = shift;
  my ($basename,$ext) = $this->full_file_basename;
  my $db_mtime = min( map { (stat($_))[9] } $this->list_files );
  return $db_mtime;
}




__PACKAGE__->mk_accessors('format_time');



sub check_format_permissions {
  my ($self) = @_;
  my $ffbn = $self->full_file_basename;

  my $err_str = '';

  #check the dir
  my $dir = dirname($ffbn);
  unless( $self->create_dirs ) {
    unless( -d $dir ) {
      $err_str .= "Directory '$dir' does not exist\n";
    }
    elsif( ! -w $dir ) {
      $err_str .= "Directory $dir exists, but is not writable\n";
    }
  } else {
    my @dirs = splitdir($dir);
    #use Data::Dumper;
    #die Dumper \@dirs;
    pop @dirs while @dirs && ! -d catdir(@dirs);
    my $d = catdir(@dirs);
    if( ! @dirs ) {
      $err_str .= "Entire directory tree for '$dir' does not exist!\n";
    }
    elsif(! -w $d ) {
      $err_str .= "Directory $d is not writable, cannot make dirs\n";
    }
  }


  #check writability of any  files that are already there
  my @files = $self->list_files();
  foreach (@files) {
    if( -f && !-w ) {
      $err_str .= "Blast DB component file $_ exists, but is not overwritable\n";
    }
  }
  return $err_str if $err_str;
  return;
}


sub is_split {
  my ($self) = @_;
  my $ffbn = $self->full_file_basename;
  return 1 if grep /^$ffbn\.\d{2,3}\.[np]\w\w$/,$self->list_files;
  return 0;
}


sub files_are_complete {
  my ($self) = @_;

  #list of files belonging to this db
  my @files = $self->list_files;

  #certainly not complete if fewer than 3 files
  return 0 unless @files >= 3;

  #assemble list of necessary extensions
  my @necessary_extensions = (qw/sq hr in/, #base database files
			      #add seqid indexes if called for
			      $self->indexed_seqs ? qw/sd si/ : (),
			     );

  #add protein/nucleotide prefix to extensions
  my $norp = $self->type eq 'protein' ? '.p' : '.n';
  $_ = $norp.$_ foreach @necessary_extensions;

  #deal with large, split databases
  if( $self->is_split ) {
    #if the database is split, add all of the fragment numbers to
    #the extensions we have to have

    #maximum index number of all fragments present
    my $max_frag_num = 0 + max( map { /\.(\d{2,3})\.[np]\w\w$/ ? $1 : 0 } @files);

    #make extensions with all of the necessary fragment numbers
    @necessary_extensions = map { my $ext = $_;
				  map {sprintf(".%02d$ext",$_)} (0..$max_frag_num)
				} @necessary_extensions;

    #also remember that we have to have an alias file for split dbs
    push @necessary_extensions, $norp.'al';
  }

  #now that we have our list of all the file extensions we need to have,
  #check if they are actually there
  my $ffbn = $self->full_file_basename;
  return all {
	       my $ext = $_;
	       (grep {$_ eq "$ffbn$ext"} @files) ? 1 : 0
	     } @necessary_extensions;
}


sub list_files {
  my $self = shift;
  croak "cannot list files without knowing the database type" unless $self->type;
  _list_files($self->full_file_basename, $self->type);
}
#our internal version of this function just takes a full file basename,
#and a db type, and returns all the files that go with that database
sub _list_files {
  my ($ffbn,$type) = @_;

  #file extensions for each type of blast database
  my %valid_extensions = ( protein     => [qw/.psq .phr .pin .psd .psi .pal .pnd .pni/],
			   nucleotide  => [qw/.nsq .nhr .nin .nsd .nsi .nal .nnd .nni/],
			 );

  #file extensions for _this_ database
  $valid_extensions{$type} or confess 'invalid type '.$type;
  my @search_extensions = @{$valid_extensions{$type}};

  #this gives us all files which have our basename, and one of the right search extensions
  my @myfiles =
    grep {
      my $file = $_;
      grep {$file =~ /^$ffbn(\.\d{2})?$_$/} @search_extensions
    } glob("$ffbn*");

  for (@myfiles) { -f or confess 'sanity check failed' };

  return @myfiles;
}


__PACKAGE__->mk_accessors('sequences_count');



sub get_sequence {
    my ($self, $seqname) = @_;

    croak "cannot call get_sequence on an incomplete database!"
        unless $self->files_are_complete;

    croak "cannot call get_sequence on a database that has not been indexed for retrieval!"
        unless $self->indexed_seqs;

    return Bio::BLAST2::Database::Seq->new(
        -bdb => $self,
        -id  => $seqname,
        );
}

# internal function to set the title, sequence count, type,
# format_time, and indexed_seqs from the set of files on disk and from
# the output of blastdbcmd
sub _read_blastdbcmd_info {
    my ($self) = @_;

    my @files = $self->list_files
        or return;

    $self->_check_external_tools;

    my $ffbn = $self->full_file_basename;
    my $cmd = "blastdbcmd -db $ffbn -info";
    my $blastdbcmd = `$cmd 2>&1`;
    print STDERR "BLASTDBCMD RETURNED: $blastdbcmd\n";

    my ($title) = $blastdbcmd =~ /Database:\s*([\s\S]+)sequences/
      or die "could not parse output of blastdbcmd (0):\n$blastdbcmd";
    $title =~ s/\s*[\d,]+\s*$//;

    my ($seq_cnt) = $blastdbcmd =~ /([\d,]+)\s*sequences/
      or die "could not parse output of blastdbcmd (1):\n$blastdbcmd";
    $seq_cnt =~ s/,//g;

    my ($datestr) =
        $blastdbcmd =~ m(
                     Date: \s* ( \w [\S\ ]+ \w )
                       \s+
                      )x
                          or die "could not parse output of blastdbcmd (2):\n$blastdbcmd";


    my $indexed = (any {/sd$/} @files) && (any {/si$/} @files);

    ### set our data
    $self->type( $self->_guess_type )
        or confess 'could not determine db type';

    ### type: $self->type

    $self->format_time( _parse_datestr($datestr) ); #< will die on failure
    $title =~ s/\s+$//;
    $self->title( $title );
    $self->_indexed_seqs( $indexed );
    $self->sequences_count( $seq_cnt );
}
sub _guess_type {
    my ($self) = @_;
    my $saved_type = $self->type;

    foreach my $guess (qw( protein nucleotide )) {
        $self->type( $guess );
        if( $self->files_are_complete ) {
            $self->type( $saved_type );
            return $guess;
        }
    }

    $self->type( $saved_type );
    return;
}
sub _parse_datestr {
    my ($datestr) = @_;
    my @split = split /\W+/,$datestr;
    my ($mon,$d,$y,$h,$min,$ampm) = @split
        or die "could not parse data string '$datestr'";

    #  warn "got $mon,$d,$y,$h,$min,$ampm\n";
    my %months = do{ my $n = 0; map { $_ => $n++ } qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/};
    exists $months{$mon} or return;
    $mon = $months{$mon};
    $h = 0 if $h == 12;
    $h += 12 if lc($ampm) eq 'pm';
    #warn "mktime $min,$h,$d,$mon,".($y-1900)."\n";
    my $time = mktime(0,$min,$h,$d,$mon,$y-1900,0,0,-1);
    #  warn "$datestr => ".ctime($time)."\n";
    return $time;
}

###
1;#do not remove
###

__END__
=pod

=encoding utf-8

=head1 NAME

Bio::BLAST2::Database - work with formatted BLAST databases, updated for new NCBI-Blast+ Debian package

=head1 SYNOPSIS

  use Bio::BLAST2::Database;

  # open an existing bdb for reading
  my $fs = Bio::BLAST2::Database->open(
               full_file_basename => '/path/to/my_bdb',
             );
  # will read from /path/to/my_bdb.nin, /path/to/my_bdb.nsq, etc

  my @filenames = $fs->list_files;

  #reopen it for writing
  $fs = Bio::BLAST2::Database->open(
            full_file_basename => '/path/to/my_bdb',
            write => 1,
          );

  # replace it with a different set of sequences
  $fs->format_from_file('myseqs.seq');

  # can also get some metadata about it
  print "db's title is ".$fs->title;
  print "db was last formatted on ".localtime( $fs->format_time );
  print "db file modification was ".localtime( $fs->file_modtime );

=head1 DESCRIPTION

Each object of this class represents an NCBI-formatted sequence
database on disk, which is a set of files, the exact structure of
which varies a bit with the type and size of the sequence set.

This is mostly an object-oriented wrapper for using NCBI's C<blastdbcmd>
and C<formatdb> tools.

=head1 ATTRIBUTES

=head2 full_file_basename

Full path to the blast database file basename.  This is the entire
path to the BLAST database files, except for the final suffixes
(C<.nin>, C<.nsq>, etc).

   my $basename = $db->full_file_basename;
   #returns '/data/shared/blast/databases/genbank/nr'

=head2 create_dirs

true/false flag for whether to create any necessary dirs at format time

=head2 write

true/false flag for whether to write any files that are in the way when formatted

=head2 title

title of this blast database, if set

=head2 indexed_seqs

return whether this blast database is indexed

=head2 type

accessor for type of blastdb.  must be set in new(), but open() looks
at the existing files and sets this

=head1 METHODS

=head2 open

  Usage: my $fs = Bio::BLAST2::Database->open({
                      full_file_basename => $ffbn,
                      write => 1,
                      create_dirs => 1,
                   });
  Desc : open a BlastDB with the given ffbn.
  Args : hashref of params as:
         {  full_file_basename => full path plus basename of files in this blastdb,
            type => 'nucleotide' or 'protein'
            write => default false, set true to write any files in the way,
            create_dirs => default false, set true to create any necessary directories
                           if formatted
         }
  Ret  : Bio::BLAST2::Database object
  Side Effects: none if no files are present at the given ffbn.  overwise,
                dies if files are present and write is not specified,
                or if dir does not exist and create_dirs was not specified
  Example:

=head2 to_fasta

  Usage: my $fasta_fh = $bdb->to_fasta;
  Desc : get the contents of this blast database in FASTA format
  Ret  : an IO::Pipe filehandle
  Args : none
  Side Effects: runs 'blastdbcmd' in a forked process, cleaning up its output,
                and passing it to you

=head2 format_from_file

  Usage: $db->format_from_file(seqfile => 'mysequences.seq');
  Desc : format this blast database from the given source file,
         into its proper place on disk, overwriting the files already
         present
  Ret  : nothing meaningful
  Args : hash-style list as:
          seqfile => filename containing sequences,
          title   => (optional) title for this blast database,
          indexed_seqs => (optional) if true, formats the database with
                          indexing (and sets indexed_seqs in this obj)
  Side Effects: runs 'formatdb' to format the given sequences,
                dies on failure

=head2 file_modtime

  Desc: get the earliest unix modification time of the database files
  Args: none
  Ret : unix modification time of the database files
  Side Effects:
  Example:

=head2 format_time

  Usage: my $time = $db->format_time;
  Desc : get the format time of these db files
  Ret  : the value time() would have returned when
         this database was last formatted, or undef
         if that could not be determined (like if the
         files aren't there)
  Args : none
  Side Effects: runs 'blastdbcmd' to extract the formatting
                time from the database files

  NOTE:  This function assumes that the computer that
         last formatted this database had the same time zone
         set as the computer we are running on.
         Also, the time returned by this function is rounded
         down to the minute, because blastdbcmd does not print
         the format time in seconds.

=head2 check_format_permissions

  Usage: $bdb->check_format_from_file() or die "cannot format!\n";
  Desc : check directory existence and file permissions to see if a
         format_from_file() is likely to succeed.  This is useful,
         for example, when you have a script that downloads some
         remote database and you'd like to check first whether
         we even have permissions to format before you take the
         time to download something.
  Args : (optional) alternate full file basename to write blast DB to
           e.g. '/tmp/mytempdir/tester_blast_db'
  Ret  : nothing if everything looks good,
         otherwise a string error message summarizing the reason
         for failure
  Side Effects: reads from filesystem, may stat some files

=head2 is_split

  Usage: print "that thing is split, yo" if $db->is_split;
  Desc : determine whether this database is in multiple parts
  Ret  : true if this database has been split into multiple
         files by formatdb (e.g. nr.00.pin, nr.01.pin, etc.)
  Args : none
  Side Effects: looks in filesystem

=head2 files_are_complete

  Usage: print "complete!" if $db->files_are_complete;
  Desc : tell whether this blast db has a complete set of files on disk
  Ret  : true if the set of files on disk looks complete,
         false if not
  Args : (optional) true value if the files should only be
         considered complete if the sequences are indexed for retrieval
  Side Effects: lists files on disk

=head2 list_files

  Usage: my @files = $db->list_files;
  Desc : get the list of files that belong to this blast database
  Ret  : list of full paths to all files belonging to this blast database,
  Args : none
  Side Effects: looks in the filesystem

=head2 sequences_count

  Desc: get the number of sequences in this blast database
  Args: none
  Ret : number of distinct sequences in this blast database, or undef
        if it could not be determined due to some error or other
  Side Effects: runs 'blastdbcmd' to get stats on the blast database file

=head2 get_sequence

  Usage: my $seq = $fs->get_sequence('LE_HBa0001A02');
  Desc : get a particular sequence from this db
  Args : sequence name to retrieve
  Ret  : Bio::PrimarySeqI-implementing object, or nothing if not found
  Side Effects: dies on error

=head1 BASE CLASS(ES)

L<Class::Accessor::Fast>

=head1 AUTHOR

Robert Buels <rmb32@cornell.edu>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Robert Buels.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

