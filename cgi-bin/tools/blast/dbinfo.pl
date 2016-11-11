
#### Note: This script is deprecated. The functionality was moved to
####       SGN::Controller::Blast

use strict;
use warnings;

use POSIX;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html info_table_html commify_number truncate_string/;

use List::Util qw/sum/;

use CXGN::BlastDB;

my $page = CXGN::Page->new('Page Internal Name','Robert Buels');

$page->header(('BLAST Database Details') x 2);


print <<EOH;
<div style="margin: 2em">This page provides details for each of the BLAST sequence sets available at SGN.</div>
EOH


my @groups = map {
  my $grp = $_;
  if( my @dbs = grep $_->file_modtime, $grp->blast_dbs( web_interface_visible => 't') ) {
    [$grp->name, @dbs ]
  } else {
    ()
  }
} CXGN::BlastDB::Group->search_like(name => '%',{order_by => 'ordinal, name'});

if( my @ungrouped = grep $_->file_modtime, CXGN::BlastDB->search( blast_db_group_id => undef, web_interface_visible => 't', {order_by => 'title'} ) ) {
  push @groups, ['Other', @ungrouped ];
}

my $grpcount = @groups;
my $dbcount = sum(map scalar(@$_),@groups)-$grpcount;
print <<EOH;
<div style="margin: 0.5em 0.2em; text-align: right; font-weight: bold">Viewing $dbcount databases in $grpcount categories.</div>
EOH

foreach my $groupspec (@groups) {
  my ($groupname,@dbs) = @$groupspec;
#   print info_section_html( title => $groupname,
# 			   contents => join '', map info_html($_), @dbs,
# 			 );

  print info_html($_,$groupname) foreach @dbs;
}

$page->footer;

######### SUBROUTINES ########


sub info_html {
  my ($db,$groupname) = @_;

  my $timestamp = $db->file_modtime
    or return;

  my $timestamp_str = strftime('%m-%d-%y %R GMT',gmtime $db->file_modtime);
  if( $db->needs_update ) {
    $timestamp_str = qq|<span style="background: #c22; padding: 3px; color: white">$timestamp_str (needs update)</span>|;
  }
  my $update_freq = $db->update_freq;

  return info_section_html( title => $db->title.'<a name="'.$db->file_base.'"></a>',
			    subtitle => "<b>Category:</b> $groupname",
			    is_subsection => 0,
			    contents =>
			    info_table_html(
					    'Sequence Type' => $db->type,
					    'Sequence Count' => commify_number($db->sequences_count),
					    'Current as of ' => $timestamp_str,
					    'Update Frequency' => $update_freq,
					     __multicol => 5,
					     __border => 0,
					   )
			    .info_table_html(
					     $db->info_url ? ('Source Information' => '<a href="'.$db->info_url.'">'.truncate_string($db->info_url,40).'</a>') : (),
					     $db->source_url ? ('FASTA Sequences' => '<a href="'.$db->source_url.'">'.truncate_string($db->source_url,40).'</a>') : (),
					     __multicol => 2,
					    __border => 0,
					   )
			    .info_table_html(
					     'Description' => $db->description || '<span class="ghosted">Not available</span>',
					    __border => 0,
					   ),

			  );
}
