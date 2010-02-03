#!/usr/bin/perl -w

use strict;
use CXGN::Page;
use CXGN::VHost;
use FileHandle;
use IPC::Open3;
use Bio::Tools::Primer3;
use Bio::Tools::Run::Primer3;
use Bio::SeqIO;
use File::Temp qw/tempfile/;

our $page = CXGN::Page->new( "Primer3 Output", "Adri" );

&website("Primer3 is currently unavailable.") && exit();






my $vhost_conf = CXGN::VHost->new();

my $documents = '/documents/primer3/';

my %SEQ_LIBRARY = (
    'NONE'              => '',
    'HUMAN'             => $page->path_to($documents."human.txt"),
    'RODENT_AND_SIMPLE' => $page->path_to($documents."rodent_and_simple.txt"),
    'RODENT'            => $page->path_to($documents."rodent.txt"),
    'DROSOPHILA'        => $page->path_to($documents."drosophila.txt"),
);

my $r = Apache2::RequestUtil->request;
$r->content_type("text/html");
if ( $r->method() ne "POST" ) { post_only($page) }

my $req = Apache2::Request->new($r);

my $query = $req->body;

&check_library($query->{PRIMER_MISPRIMING_LIBRARY});
#my $library = &check_library($query->{PRIMER_MISPRIMING_LIBRARY});
#$query->{PRIMER_MISPRIMING_LIBRARY} = $library;

my %input;
#my %input  = &process_query($query);

# there's got to be a better way to handle this..
# primer3 requires a physical file, though
my ($seq_fh, $seq_filename) = tempfile( "p3XXXXXX",
					DIR=> $vhost_conf->get_conf('cluster_shared_tempdir'),
					);
print $seq_fh $query->{SEQUENCE};

my ($out_fh, $out_filename) = tempfile( "p3XXXXXX",
					DIR=> $vhost_conf->get_conf('cluster_shared_tempdir'),
					);
close $seq_fh;
close $out_fh;

# it seems to want a different sort of file.. but where do the parameters come from then?
my $seqio = Bio::SeqIO->new(-file=>$seq_filename);
my $seq = $seqio->next_seq;

my $primer3 = Bio::Tools::Run::Primer3->new(-seq => $seq,
					    -outfile => $out_filename,
					    -path => "primer3_core");

#$primer3->add_targets(key=>value);
# example: set the maximum and minimum Tm of the primer
#$primer3->add_targets('PRIMER_MIN_TM'=>56, 'PRIMER_MAX_TM'=>90);
# need to go through and view list of possible args and take them on previous page..

unless ($primer3->executable) {
    &error("primer3 can not be found. Is it installed?");
}

# what are the arguments, and what do they mean?
#my $args = $primer3->arguments;
#my $string;
#foreach my $key (keys %{$args}) { $string .= "<p>$key\t $$args{$key}</p>" }
#&error($string);

# design the primers. This runs primer3 and returns a
# Bio::Tools::Run::Primer3 object with the results
my $results = $primer3->run;

# TODO!
if (!$results->{number_of_results}) { &website(&no_primers_found) }
else { &website("There were $results->{number_of_results} primers.") }






sub process_query {

    my $v;
    my $warning = " ";

    my %input;

# TODO

    return %input;
}



sub no_primers_found {

    my $text = <<EOF;

</pre>

<h4>No Acceptable primers Were Found</h4>

The statistics below should indicate why no acceptable
primers were found. Try relaxing various parameters, including the
self-complementarity parameters and max and min oligo melting
temperatures.  For example, for very A-T-rich regions you might
have to increase maximum primer size or decrease minimum melting
temperature.

<pre>

EOF

    return $text;

}

sub website {

    my ( $results, $warning ) = @_;

    $results = "..." if ( !$results );

    $page->header( "Primer3 Output", "Primer3 Output" );

    print <<EOF;

    <p>$warning</p>

    <pre>$results</pre>

EOF

    $page->footer();

}

sub post_only {

    $page->header();

    print <<EOF;


    <h4>Primer3 Interface Error</h4>

    <p>Primer3 subsystem can only accept HTTP POST requests</p>

EOF

    $page->footer();
    exit(0);
}

sub error {

    my $reason = shift;

    $page->header();

    print <<EOF;

    <h4>Primer3 Watch Error</h4>

    <p>$reason</p>

EOF

    $page->footer();
    exit(0);
}

sub check_library {
    my $library = shift;

    return if ($library eq 'NONE');

    my $lib_file = $SEQ_LIBRARY{$library};

    if (!$lib_file) { &error("Invalid mispriming library: $library.") }
    if (! -r $lib_file) { &error("Cannot find data file for mispriming library $library.") }    

    return $lib_file;
}























# what is all this?
#     my $cline;

#     my $found = 1;

#     while ( $cline = $childout->getline ) {
#         $cline =~ s/>/&gt;/g;
#         $cline =~ s/</&lt;/g;
#         if ( $cline =~
# /(.*)(start) (\s*\S+) (\s*\S+) (\s*\S+) (\s*\S+) (\s*\S+|) (\s*\S+) (\s*\S+)/
#           )
#         {

#             my (
#                 $margin, $starth, $lenh, $tmh, $gch,
#                 $anyh,   $threeh, $reph, $seqh
#             ) = ( $1, $2, $3, $4, $5, $6, $7, $8, $9 );

#             my $help = "results_help.pl";

#             $cline =
#                 $margin
#               . "<a href=\"$help#PRIMER_START\">$starth</a> "
#               . "<a href=\"$help#PRIMER_LEN\">$lenh</a> "
#               . "<a href=\"$help#PRIMER_TM\">$tmh</a> "
#               . "<a href=\"$help#PRIMER_GC\">$gch</a> "
#               . "<a href=\"$help#PRIMER_ANY\">$anyh</a> "
#               . "<a href=\"$help#PRIMER_THREE\">$threeh</a> "
#               . "<a href=\"$help#PRIMER_REPEAT\">$reph</a> "
#               . "<a href=\"$help#PRIMER_OLIGO_SEQ\">$seqh</a> " . "\n";
#         }
#         $cline =~ s/INTERNAL OLIGO/HYB OLIGO     /;
#         $cline =~ s/INTERNAL OLIGO/HYB OLIGO/;
#         $cline =~ s/Intl/Hyb /;

#         if ( $cline =~ /NO PRIMERS FOUND/ ) {
#             $found = 0;
#         }
#         elsif ( $cline =~ /^Statistics/ && !$found ) {
#             $results .= &no_primers_found() . $cline;
#         }
#         elsif ( $cline =~ /^PRIMER PICKING RESULTS FOR\s*$/ ) {
#         }
#         else {
#             $results .= $cline;
#         }
#     }

#     waitpid $primer3_pid, 0;

#     if ( $? != 0 && $? != 64512 ) {    # 64512 == -4

#         my $error =
#             "There is a configuration error or an unexpected internal error "
#           . "in the primer3 program. The child process for primer3 was reaped "
#           . "with a non-0 termination status of $?.<br />";

#         foreach ( keys(%$query) ) {
#             $v = $query->{$_};
#             $error .= "$_=$v<br />";
#         }

#         $error .= "COMMAND WAS: $cmd<br />EXACT input WAS: @input";

#         &error($error);

#     }

#     elsif ($print_input) {
#         my ( $user, $system, $cuser, $csystem ) = times;

#         my $text =
#             "TIMES: user=$user sys=$system cuser=$cuser csys=$csystem<br /> "
#           . "COMMAND WAS: $cmd<br /> "
#           . "EXACT input WAS: @input";

#         &error($text);
#     }

#     &website( $results, $warning );

# }




# sub add_start_len_list($$$) {
#     my ( $list_string, $list, $plus ) = @_;
#     my $sp = $list_string ? ' ' : '';
#     for (@$list) {
#         $list_string .= ( $sp . ( $_->[0] + $plus ) . "," . $_->[1] );
#         $sp = ' ';
#     }
#     return $list_string;
# }

# sub read_sequence_markup($@) {
#     my ( $s, @delims ) = @_;

#     # E.g. ['/','/'] would be ok in @delims, but
#     # no two pairs in @delims may share a character.
#     my @out = ();
#     for (@delims) {
#         push @out, &read_sequence_markup_1_delim( $s, $_, @delims );
#     }
#     return @out;
# }

# sub read_sequence_markup_1_delim($$@) {
#     my ( $s, $d, @delims ) = @_;
#     my ( $d0, $d1 ) = @$d;
#     my $other_delims = '';
#     for (@delims) {
#         next if $_->[0] eq $d0 and $_->[1] eq $d1;
#         &error("Programming error") if $_->[0] eq $d0;
#         &error("Programming error") if $_->[1] eq $d1;
#         $other_delims .= '\\' . $_->[0] . '\\' . $_->[1];
#     }
#     if ($other_delims) {
#         $s =~ s/[$other_delims]//g;
#     }

#     # $s now contains only the delimters of interest.
#     my @s = split( //, $s );
#     my ( $c, $pos ) = ( 0, 0 );
#     my @out;
#     my $len;
#     while (@s) {
#         $c = shift(@s);
#         next if ( $c eq ' ' );    # Already used delimeters are set to ' '
#         if ( $c eq $d0 ) {
#             $len = len_to_delim( $d0, $d1, \@s );
#             return undef if ( !defined $len );
#             push @out, [ $pos, $len ];
#         }
#         elsif ( $c eq $d1 ) {

#             # There is a closing delimiter with no opening
#             # delimeter, an input error.
#             &error(
#                 "ERROR IN SEQUENCE: closing delimiter $d1 not preceded by $d0");
#         }
#         else { $pos++; }
#     }
#     return \@out;
# }

# sub len_to_delim($$$) {
#     my ( $d0, $d1, $s ) = @_;
#     my $i;
#     my $len = 0;
#     for $i ( 0 .. $#{$s} ) {
#         if ( $s->[$i] eq $d0 ) { }
#         elsif ( $s->[$i] eq $d1 ) {
#             $s->[$i] = ' ';
#             return $len;
#         }
#         else { $len++ }
#     }

#     &error("ERROR IN SEQUENCE: closing delimiter $d1 did not follow $d0");
# }




