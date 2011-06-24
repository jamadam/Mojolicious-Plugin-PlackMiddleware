package ForceCharset;

use strict;
use warnings;
use 5.008_001;

use parent qw(Plack::Middleware);
use Plack::Util;
use Plack::Util::Accessor qw(charset);
use Encode;

our $VERSION = '0.02';

sub call {
    my ($self, $env) = @_;
    $self->response_cb($self->app->($env), sub {
		my $res = shift;
        my $h = Plack::Util::headers($res->[1]);
		my $charset_from = 'UTF-8';
		my $charset_to = $self->charset;
        my $ct = $h->get('Content-Type');
		if ($ct =~ s{;?\s*charset=([^;\$]+)}{}) {
			$charset_from = $1;
		}
		if ($ct =~ qr{^text/(html|plain)}) {
			$h->set('Content-Type', $ct. ';charset='. $charset_to);
		}
		my $fixed_body = [];
		Plack::Util::foreach($res->[2], sub {
			Encode::from_to($_[0], $charset_from, $charset_to);
			push @$fixed_body, $_[0];
		});
		$res->[2] = $fixed_body;
		$h->set('Content-Length', length $fixed_body);
		return $res;
	});
}

1;
__END__
