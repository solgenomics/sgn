# This page is used to test error-handling. if you try to view this
# script, the server should produce a friendly error message. -john

# This isn't actually a syntax error; it's not a syntactic property of
# the language that there's no such subroutine.

warn "I am about to explode intentionally!";
Intentional::Syntax::Error->explode('dont-fix');

