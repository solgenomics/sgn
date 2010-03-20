package Bio::Graphics::Browser2::Plugin::CreateBlastDB;
# $Id: CreateBlastDB.pm,v 1.1 2003-11-17 22:01:38 markwilkinson Exp $



=head1 NAME

Bio::Graphics::Browser2::Plugin::CreateBlastDB -- a plugin that creates a Blast-formatted database from a Bio::DB::GFF database

=head1 SYNOPSIS

 in 0X.organism.conf:
     
 [CreateBlastDB:plugin]
 formatdb_executable = /usr/local/BLAST/formatdb
 blast_db_folder = /home/username/my/blast_db/folder 
 blast_db_name = myname.fas

=head1 DESCRIPTION

This Gbrowse plugin will take a sequence database, extract all sequences
in it, and create a Blast-formatted database in the folder configured in
the 0X.organism.conf file

You must, of course, have the NCBI Blast suite of programs installed,
you must have configured the plugin to be visible, and you must
set two parameters in the 0X.organism.conf file:
    [CreateBlastDB:plugin]
     formatdb_executable = /usr/local/BLAST/formatdb
     blast_db_folder = /home/username/my/blast_db/folder 
     blast_db_name = myname.fas


=cut


use strict;
use Bio::Graphics::Browser2::Plugin;
use Bio::Graphics::Feature;
use DBI;
use CGI qw(:standard *table);

use vars '$VERSION','@ISA', '$formatdb', '$outdir', '$dbname';
$VERSION = '0.15';

@ISA = qw(Bio::Graphics::Browser2::Plugin);

sub name { "Blast Database" }

sub description {
  p("This will dump EVERY sequence out of the Bio::DB::GFF database and then run a BLAST formatdb on these sequences. ",
    "This, of course, requires that you have the Blast binaries installed and configured in your 0X.organism.conf file.").
  p("This plugin was written by Mark Wilkinson.");
}

sub type { 'dumper' }

sub mime_type {
    return "text/html";
}

sub init {
    my $self = shift;
    my $conf = $self->browser_config;
    $formatdb = $conf->plugin_setting('formatdb_executable');
    $outdir = $conf->plugin_setting('blast_db_folder');
    $dbname = $conf->plugin_setting('blast_db_name');
    $outdir || die "No Configured Blast Database Folder";
    die "Blast Database Folder $outdir does not exist" unless (-e $outdir);
    die "Blast Database Folder $outdir is not a folder" unless (-d $outdir);
    
    open OUT, ">$outdir/$dbname" || die "can't create/overwrite fasta file $outdir/$dbname: $!\n";
}

sub config_defaults {
  my $self = shift;
  return { };
}

# we have no stable configuration
# sub reconfigure { }

sub configure_form {
  my $self = shift;
    return "<h2>nothing to configure</h2>"
}

sub dump {
    my $self = shift;
    my $segment = shift;
    my $db    = $self->database or die "I do not have a database";
    my $dbh   = $db->features_db;
    my $sth = $dbh->prepare("select fref,foffset,fdna from fdna order by fref,foffset") or die "Couldn't prepare ",$db->errstr;
    $sth->execute or die "Couldn't execute ",$db->errstr;
    my ($current_ref,$offset,$dna,@results);

    while (my ($ref,$off,$d) = $sth->fetchrow_array) {
        if (!defined($current_ref)) {
            $dna    = '';
            $current_ref = $ref
        }
        if ($current_ref ne $ref) {
            open OUT, ">>$outdir/$dbname" || die "can't open fasta file $outdir/$dbname for writing: $!\n";
            print OUT ">$ref\n$dna\n\n";
            $dna = '';
            close OUT;
        }
        $current_ref = $ref;
        $dna    .= lc $d;
    }
    print "<h3>Executing $formatdb -t 'Bio::DB::GFF Blast Database' -i $outdir/$dbname -p F -o T -a F</h3>";
    my $res = system ("$formatdb -t 'Bio::DB::GFF Blast Database' -i $outdir/$dbname -p F -o T -a F");
    unless ($res == -1){
        print "<h3>Blast Database Created Successfully</h3>";
    } else {
        print "Database Formatting Failed:  $!\n";
    }
}

1;
