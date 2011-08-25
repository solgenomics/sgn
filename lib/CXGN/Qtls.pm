use strict;

package CXGN::Qtls;

use CXGN::Qtls::Result;
use CXGN::Qtls::Query;

use base qw/CXGN::Search::DBI::Simple CXGN::Search::WWWSearch/;


__PACKAGE__->creates_result('CXGN::Qtls::Result');
__PACKAGE__->uses_query('CXGN::Qtls::Query');

###
1;#do not remove
###

