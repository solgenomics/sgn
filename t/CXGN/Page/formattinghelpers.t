use strict;
use warnings;

use Test::More;


use CXGN::Page::FormattingHelpers;

# check that the @EXPORT_OK does not contain mythical things
CXGN::Page::FormattingHelpers->import(
    @CXGN::Page::FormattingHelpers::EXPORT_OK
  );

# test info_section_html
{ my $i = info_section_html( title => 'Foo', subtitle => 'noggin', contents => 'Zizzle zozz' );
  like( $i, $_ ) for qr/Foo/, qr/noggin/, qr/Zizzle zozz/;
}


done_testing;
