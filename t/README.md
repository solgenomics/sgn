-----------------------------------------------------------------------------
# Solgenomics Test Suite
-----------------------------------------------------------------------------

This is the SGN test suite, which helps us verify that code is working as it should.

Active Testing:

perl t/test_fixture.pl t/unit/
perl t/test_fixture.pl t/unit_fixture/
perl t/test_fixture.pl t/selenium2/

-----------------------------------------------------------------------------
#Active Tests
-----------------------------------------------------------------------------

## t/unit/Bio

Unit tests in the Bio::SecreTary::* namespace. These tests do not require a database to run.

## t/unit/CXGN

Unit tests in the CXGN::* namespace. These tests do not require a database to run.

## t/unit/pod

Tests related to POD documentation. These tests do not require a database to run.

## t/unit_fixture/CXGN

Unit fixture tests in the CXGN::* namespace. These test run against the fixture database.
These tests run directly against backend CXGN modules (most often Moose objects).

## t/unit_fixture/SGN

Unit fixture tests in the SGN::* namespace. These test run against the fixture database.
These tests run directly against backend SGN modules (most often Moose objects).

## t/unit_fixture/Controller

Unit fixture tests in the SGN::Controller::* namespace. These test run against the fixture database.
These tests run through URL requests to Catalyst::Controller modules.

## t/unit_fixture/AJAX

Unit fixture tests in the SGN::Controller::AJAX::* namespace. These test run against the fixture database.
These tests run through URL requests to Catalyst::Controller::REST modules.

## t/unit_fixture/Static

These tests check that static files are accessible from web services.

## t/selenium2

Integration tests, which use selenium2 to launch a web browser.
These tests are useful for testing client side javascript, but use of these tests has fallen short lately because of the slowness of selenium.

## t/live

Tests which run tests against live websites.



-----------------------------------------------------------------------------
#Test Environment
-----------------------------------------------------------------------------

## t/test_fixture.pl

Used to launch a test server and to load the fixture database. Also useful for testing entire directories at once.

## t/data/

Contains test data, such as test GFF3 files or test images. Used by the rest of the test suite.

## t/lib/

Libraries written for and to be used by the test suite, such as SGN::Test::Data.



-----------------------------------------------------------------------------
#Legacy Tests
-----------------------------------------------------------------------------

## t/SGN

Tests in the SGN::* namespace

## t/CXGN

Tests in the CXGN::* namespace

## t/legacy/integration/

This directory contains integration tests, which test how multiple peices of code interact,
as opposed to unit tests, which usually test a small piece of code in isolation.

## t/legacy/validate/

Validation tests, which run "html lint" tests to make sure our HTML validates, which is important
for making the website render properly and quickly in many browsers.
