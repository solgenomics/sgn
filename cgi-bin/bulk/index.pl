use strict;
use CatalystX::GlobalContext qw($c);
use SGN::I18N;
use HTML::Entities qw(encode_entities);
use CXGN::Page;
my $page=CXGN::Page->new("Sol Genomics Network","Tyler");
$page->header();
my SGN::I18N $bulk_index_i18n = eval { $c && $c->i18n };
my $bulk_index_link = encode_entities($bulk_index_i18n ? $bulk_index_i18n->p('lists_datasets.bulk.bulk_download', 'Bulk Download') : 'Bulk Download');
my $bulk_index_description = encode_entities($bulk_index_i18n ? $bulk_index_i18n->p('global.bulk.index.description', 'Download information for a list of identifiers, or for complete datasets with FTP.') : 'Download information for a list of identifiers, or for complete datasets with FTP.');
my $bulk_index_heading = encode_entities($bulk_index_i18n ? $bulk_index_i18n->p('global.bulk.index.heading', 'SGN Bulk') : 'SGN Bulk');
print <<END_HEREDOC;

     <br />
     <center>
     <table class="boxbgcolor2" width="100%" summary="">
     <tr>
     <td width="25%">&nbsp;</td>
     <td width="50%" class="left">
          <div class="boxcontent">
        
            <div class="subheading">
            <u>$bulk_index_heading</u>
            </div>
            <div class="boxsubcontent">
              <a href="/bulk/input.pl">$bulk_index_link</a> - $bulk_index_description
            </div>
       
          </div>
</td>
<td width="25%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC

$page->footer();
