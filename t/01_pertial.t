package Template_Basic;
use strict;
use warnings;
use utf8;
use Test::More;
use Test::Mojo;
use Mojolicious::Plugin::PlackMiddleware;

use Test::More tests => 9;

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

1;

__END__
