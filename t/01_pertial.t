package Template_Basic;
use strict;
use warnings;
use utf8;
use base 'Test::Class';
use Test::More;
use Test::Mojo;
use Mojolicious::Plugin::PlackMiddleware;

{
	my $ioh = Mojolicious::Plugin::PlackMiddleware::_PSGIInput->new('543');
	my $buf;
	$ioh->read($buf, 1);
	is($buf, '5');
	$ioh->read($buf, 1);
	is($buf, '4');
	$ioh->read($buf, 1);
	is($buf, '3');
	$ioh->read($buf, 1);
	is($buf, '');
}
{
	my $ioh = Mojolicious::Plugin::PlackMiddleware::_PSGIInput->new('543');
	my $buf;
	$ioh->read($buf, 2);
	is($buf, '54');
	$ioh->read($buf, 2);
	is($buf, '3');
	$ioh->read($buf, 2);
	is($buf, '');
}
{
	my $ioh = Mojolicious::Plugin::PlackMiddleware::_PSGIInput->new('abcde');
	my $buf;
	$ioh->read($buf, 2);
	is($buf, 'ab');
	$ioh->read($buf, 2, 3);
	is($buf, 'de');
}

plan tests => 9;

1;

__END__
