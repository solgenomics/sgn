
use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw | page_title_html |;

my $page = CXGN::Page->new();

$page->header();

my $title = page_title_html("China to sequence tomato chromosome 11");

print <<HTML;

<br /><br />
Sept 17, 2007<br /><br />

<center>
<table width="400">
<tr><td>

Announcement

$title

At the 4. International SOL conference, Prof Sanwen Huang from the Institute of Vegetables and Flowers, Chinese Academy of Agricultural Sciences (IVF-CAAS) announced that China will sequence tomato chromosome 11. <br /><br />The commitment will be a joint effort of four institutions in China, i.e., Labs of Dr. Huang and Dr. Yongchen Du in IVF-CAAS, Lab of Dr. Zhibiao Ye in Huazhong Agricultural University, Lab of Dr. Wencai Yang in China Agri. University, and Lab of Dr. Guoping Wang in South China Agri. University. IVF-CAAS is also responsible for the sequencing of potato chromosome 10 and 11. <br /><br /> A comparative sequencing approach will be applied to uncover the similarity and divergency of euchromatin part of chromosome 11 of potato and tomato. Chinese Ministry of Agriculture is supporting the initiative with a seed fund.

</td></tr></table>
</center>


<br /><br />

HTML

$page ->footer();
