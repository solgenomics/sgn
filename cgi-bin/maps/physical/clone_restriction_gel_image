use strict;
use warnings;

use Bio::Graphics::Gel;

use CXGN::Genomic::Clone;

use CXGN::Page;

my $page = CXGN::Page->new;

my ($clone_id,$enzyme,$fingerprint_id) = $page->get_encoded_arguments(qw/id enzyme fp_id/);
$fingerprint_id += 0; $clone_id += 0; #< enforce numericness

my $clone = CXGN::Genomic::Clone->retrieve($clone_id)
  or die "could not retrieve clone with id '$clone_id'";

my $is_frags = $clone->in_silico_restriction_fragment_sizes($enzyme);

my ($iv_frags) = grep {$_->[0] == $fingerprint_id && $_->[1] eq $enzyme } $clone->in_vitro_restriction_fragment_sizes($enzyme);

if($iv_frags) {
  shift @$iv_frags; shift @$iv_frags; #shift off the fingerprint id and enzyme name
}

$is_frags || $iv_frags
  or die "no restriction fragments available at all for this clone.  user should not have been directed here.";

#warn "drawing fragment\n";
my $gel = Bio::Graphics::Gel->new(
				  $iv_frags ? ('i.v.' => $iv_frags) : (),
				  $is_frags ? ('i.s.' => $is_frags) : (),
				   -min_frag => 1000,
				  -lane_length => 200,
				  -bandcolor => [0xff,0xc6,0x00],
				 );

print "Content-Type: image/png\n\n";
print $gel->img->png;

