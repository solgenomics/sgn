#!/usr/bin/perl
use strict;
use CXGN::Page;



my $page=CXGN::Page->new('');
$page->header('SGN: QTL/Trait data submission note');

my $email = 'sgn-feedback@sgn.cornell.edu';

my $note =<<HTML; 
<div>&nbsp;</div>
<div>&nbsp;</div>
<div align="center"><b>QTL data submission</b></div>
<div>&nbsp;</div>
<div>The online data submission protocol for the SGN QTL analysis tool is under development. 
If you would like to analyze your data with the QTL analyzer and share your qtl data with the solanaceae research community,  
please contact us using <a href=mailto:$email>$email</a> 
and we will contact you with details on the data format for submission. </div>
<div>&nbsp;</div>
<div>&nbsp;</div>
HTML

print $note;
$page->footer();
