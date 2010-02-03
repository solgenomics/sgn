# This page is used to test error-handling. if you try to view this
# script, the server should produce a friendly error message. -john

use CXGN::Page;
use Module::That::Doesnt::Exist;

quit("foo");
