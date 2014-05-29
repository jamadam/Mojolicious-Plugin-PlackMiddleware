package Template_Basic;
use strict;
use warnings;
use utf8;
use Test::More;
use Test::Mojo;
use Mojolicious::Plugin::PlackMiddleware;

use Test::More tests => 10;

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

{
    my $psgi_res = [
        200,
        [a => 1, a => 2, b => 3, c => 4],
        [],
    ];
    
    my $mojo_res =
        Mojolicious::Plugin::PlackMiddleware::psgi_res_to_mojo_res($psgi_res);
    
    is_deeply(
        $mojo_res->headers->to_hash(1), {a =>[[1],[2]], b => [[3]], c => [[4]]});
}

1;

__END__
