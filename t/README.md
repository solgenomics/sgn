# Solgenomics Test Suite

This is the SGN test suite, which helps us verify that code is working as it should.

Explanation of directories:

## t/data/

Contains test data, such as test GFF3 files or test images. Used by the rest of the test suite.

## t/integration/

This directory contains integration tests, which test how multiple peices of code interact,
as opposed to unit tests, which usually test a small piece of code in isolation.

## t/lib/

Libraries written for and to be used by the test suite, such as SGN::Test::Data.

## t/validate/

Validation tests, which run "html lint" tests to make sure our HTML validates, which is important
for making the website render properly and quickly in many browsers.
