use inc::Module::Install;

name 'Net-Server-SS-PreFork';
author 'Kazuho Oku';
version_from 'lib/Net/Server/SS/PreFork.pm';
abstract_from 'lib/Net/Server/SS/PreFork.pm';
license 'perl';

requires 'Net::Server';
requires 'Server::Starter' => 0.02;
test_requires 'LWP::Simple';
test_requires 'Test::TCP' => 0.06;
test_requires 'HTTP::Server::Simple::CGI';

auto_include;
auto_install;

WriteAll;
