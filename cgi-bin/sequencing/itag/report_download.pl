use strict;
use warnings;

use File::Basename;

use CXGN::ITAG::Pipeline;
use CXGN::Page;

#use Data::Dumper;

my $page = CXGN::Page->new('Validation Report Download','Robert Buels');
my ($pipe,$batch,$atag,$filename,$valname) = $page->get_encoded_arguments('pipe','batch','atag','filename','valname');

my %content_types = ( gamexml => 'text/xml',
		      gff3 => 'text/plain',
		      gz => 'application/octet-stream',
		    );

$pipe = CXGN::ITAG::Pipeline->open(version => $pipe);
$batch = $pipe->batch($batch);
my $analysis = $pipe->analysis($atag);
my $cache_dir = "CXGN::ITAG::Pipeline::Analysis::OutputValidator::$valname"->cache_dir($analysis,$batch);
$filename =~ s|/\\||g; #remove all slashes and it should be safe from injection, I think
my $file = File::Spec->catfile($cache_dir,"$filename.report");
my ($format) = $file =~ /\.([^\.]+)?$/;
my $type = $content_types{$format} || 'text/plain';
my $basename = basename($file);
open my $f,$file or die "could not open '$file': $!";
print "Content-Type: $type\n";
print "Content-Disposition: attachment; filename=$basename\n";
print "\n";
print while <$f>;

